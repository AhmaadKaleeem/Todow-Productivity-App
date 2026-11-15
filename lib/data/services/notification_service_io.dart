import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqf;
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

typedef NotificationTapHandler = void Function(String? payload, String? action);

// ─────────────────────────────────────────────────────────────────────────────
// Background action handler — TOP-LEVEL required by flutter_local_notifications.
// Runs in its own Dart isolate (no Riverpod / Flutter widgets available).
// Opens sqflite directly to perform Complete / Snooze writes immediately,
// so the DB is already updated before the user opens the app.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(
    NotificationResponse response) async {
  final taskId = response.payload;
  final action = response.actionId;
  if (taskId == null || action == null) return;

  debugPrint('[BG] Notification action "$action" for task $taskId');

  try {
    await _BgActionRunner.run(taskId: taskId, action: action);
  } catch (e) {
    // Never crash the background isolate — the foreground re-sync at next
    // launch will reconcile any state that couldn't be written here.
    debugPrint('[BG] Background action failed: $e');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimal DB helper for the background isolate.
// Only the tables / columns needed for Complete and Snooze are touched.
// ─────────────────────────────────────────────────────────────────────────────
class _BgActionRunner {
  static Future<void> run({
    required String taskId,
    required String action,
  }) async {
    // Open the same DB file the main isolate uses.
    final dbsPath = await sqf.getDatabasesPath();
    final dbPath = p.join(dbsPath, 'todow.db');
    final db = await sqf.openDatabase(dbPath);

    try {
      switch (action) {
        case 'complete':
          await _completeTask(db, taskId);
          _stopNativeAlarm();
        case 'snooze':
          await _snoozeTask(db, taskId);
          _stopNativeAlarm();
        case 'dismiss':
          _stopNativeAlarm();
          debugPrint('[BG] Alarm stopped for task $taskId');
      }
    } finally {
      await db.close();
    }
  }

  static void _stopNativeAlarm() {
    try {
      const MethodChannel('com.example.todow/alarm_native')
          .invokeMethod('stopAlarm');
    } catch (_) {}
  }

  // Mark task completed and remove all its pending reminders.
  static Future<void> _completeTask(sqf.Database db, String taskId) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'tasks',
      {'status': 'completed', 'updated_at': now},
      where: 'id = ?',
      whereArgs: [taskId],
    );
    final rows = await db.query(
      'scheduled_reminders',
      columns: ['notification_id'],
      where: 'task_id = ? AND notification_id IS NOT NULL',
      whereArgs: [taskId],
    );
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    for (final row in rows) {
      final id = row['notification_id'] as int?;
      if (id != null) await plugin.cancel(id);
    }
    await db.delete(
      'scheduled_reminders',
      where: 'task_id = ? AND status IN (?, ?)',
      whereArgs: [taskId, 'pending', 'snoozed'],
    );
    debugPrint('[BG] Task $taskId marked completed.');
  }

  // Snooze the active reminder by 15 minutes and post a replacement
  // notification so the user sees confirmation without opening the app.
  static Future<void> _snoozeTask(sqf.Database db, String taskId) async {
    // Read the active reminder for this task.
    final rows = await db.query(
      'scheduled_reminders',
      where: "task_id = ? AND status IN ('pending', 'snoozed')",
      whereArgs: [taskId],
      orderBy: 'scheduled_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      debugPrint(
          '[BG] No active reminder found for task $taskId — skipping snooze.');
      return;
    }

    final snoozedUntil = DateTime.now().add(const Duration(minutes: 15));
    final reminderId = rows.first['id'] as String;
    final notifId = (rows.first['notification_id'] as int?) ??
        reminderId.hashCode.abs() % 2147483647;

    await db.update(
      'scheduled_reminders',
      {
        'status': 'snoozed',
        'snoozed_until': snoozedUntil.toIso8601String(),
        'scheduled_at': snoozedUntil.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reminderId],
    );

    // Read the task title for the replacement notification.
    final taskRows = await db.query(
      'tasks',
      columns: ['title'],
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    final title = taskRows.isNotEmpty
        ? (taskRows.first['title'] as String? ?? 'Task')
        : 'Task';

    // Schedule the replacement notification directly from the background isolate.
    await _scheduleSnoozeNotification(
      taskId: taskId,
      title: title,
      notifId: notifId,
      fireAt: snoozedUntil,
    );
    debugPrint('[BG] Task $taskId snoozed until $snoozedUntil.');
  }

  static Future<void> _scheduleSnoozeNotification({
    required String taskId,
    required String title,
    required int notifId,
    required DateTime fireAt,
    bool isAlarm = false,
    String soundKey = 'alarm_sound',
  }) async {
    // Initialise timezone for the background isolate.
    tz_data.initializeTimeZones();
    try {
      final tz.Location loc =
          tz.getLocation(await FlutterTimezone.getLocalTimezone());
      tz.setLocalLocation(loc);
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(const InitializationSettings(android: androidInit));

    final channelId = isAlarm
        ? (soundKey == 'alarm_sound'
            ? NotificationServiceImpl.channelAlarm
            : '${NotificationServiceImpl.channelAlarm}_$soundKey')
        : NotificationServiceImpl.channelNormal;

    final hour = fireAt.hour;
    final minute = fireAt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final snoozeTiming = 'Snoozed · Due $h12:$minute $period';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        isAlarm ? 'Task Alarms' : 'Reminders',
        channelDescription: isAlarm
            ? 'High-priority task alarms that ring continuously'
            : 'Task reminder notifications',
        importance: Importance.max,
        priority: Priority.max,
        ongoing: isAlarm,
        autoCancel: !isAlarm,
        showWhen: false,
        color: const Color(0xFF0EA5E9),
        subText: null,
        sound: isAlarm ? RawResourceAndroidNotificationSound(soundKey) : null,
        audioAttributesUsage: isAlarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        category: isAlarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        fullScreenIntent: isAlarm,
        additionalFlags: isAlarm ? Int32List.fromList(<int>[4]) : null,
        styleInformation: BigTextStyleInformation(
          snoozeTiming,
          contentTitle: title,
          summaryText: null,
          htmlFormatContent: false,
          htmlFormatContentTitle: false,
        ),
        actions: isAlarm
            ? const [
                AndroidNotificationAction('complete', 'Done',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('snooze', 'Snooze 10m',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('dismiss', 'Stop Alarm',
                    showsUserInterface: false, cancelNotification: true),
              ]
            : const [
                AndroidNotificationAction('complete', 'Done',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('snooze', 'Snooze 10m',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('open', 'Open',
                    showsUserInterface: true, cancelNotification: true),
              ],
      ),
    );

    final tzScheduled = tz.TZDateTime.from(fireAt, tz.local);
    final androidPlugin = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exact = await androidPlugin?.canScheduleExactNotifications() ?? true;
    await plugin.zonedSchedule(
      notifId,
      title,
      snoozeTiming,
      tzScheduled,
      details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: taskId,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl({this.onAction});

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final NotificationTapHandler? onAction;
  bool _exactAlarmsAvailable = true;

  static const channelNormal = 'reminders';
  static const channelConstant = 'constant_reminders';
  static const channelAlarm = 'alarms_v4';
  static const channelSilent = 'reminders_silent';
  static const channelBeep = 'reminders_beep';
  static const channelVibration = 'reminders_vibration';

  static const List<String> alarmSoundKeys = [
    'alarm_sound',
    'alarm_classic',
    'alarm_gentle',
    'alarm_urgent',
  ];

  static String _formatTimingContext({
    required String? label,
    required DateTime? dueAt,
    required bool isConstant,
  }) {
    String dueTimeStr = '';
    if (dueAt != null) {
      final hour = dueAt.hour;
      final minute = dueAt.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      dueTimeStr = ' · $h12:$minute $period';
    }

    if (isConstant) {
      return 'Still pending$dueTimeStr';
    }

    if (label == null || label.trim().isEmpty) {
      return 'Due now$dueTimeStr';
    }

    final lower = label.trim().toLowerCase();
    if (lower == 'at deadline') {
      return 'Deadline reached$dueTimeStr';
    }
    if (lower == 'daily reminder') {
      return 'Daily reminder$dueTimeStr';
    }
    if (lower == 'snoozed') {
      return 'Snoozed$dueTimeStr';
    }
    if (lower.endsWith('before')) {
      final duration =
          label.trim().substring(0, label.trim().length - 6).trim();
      return 'Due in $duration$dueTimeStr';
    }

    return '$label$dueTimeStr';
  }

  @override
  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint('Device timezone reported: $timeZoneName');
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('Timezone set to: ${tz.local.name}');
    } catch (e) {
      debugPrint(
          'Could not initialize timezone: $e — falling back to Asia/Karachi (+05:00)');
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      // Foreground / app-open tap/action handler.
      onDidReceiveNotificationResponse: (response) {
        onAction?.call(response.payload, response.actionId);
      },
      // Background / terminated action handler — must be a top-level function.
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      _exactAlarmsAvailable =
          await androidPlugin?.canScheduleExactNotifications() ?? true;

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelNormal,
          'Reminders',
          description: 'Task reminder notifications',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelSilent,
          'Silent reminders',
          description: 'Task reminders without sound or vibration',
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelBeep,
          'Beep reminders',
          description: 'Task reminders with a short notification sound',
          importance: Importance.high,
          playSound: true,
          enableVibration: false,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelVibration,
          'Sound and vibration reminders',
          description: 'Task reminders with sound and vibration',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          channelConstant,
          'Constant Reminders',
          description: 'Persistent reminders until task is completed',
          importance: Importance.max,
        ),
      );

      // Delete legacy alarm channels so Android system updates to the new alarm sound and audio attributes
      try {
        await androidPlugin?.deleteNotificationChannel('alarms');
        await androidPlugin?.deleteNotificationChannel('alarms_v2');
        await androidPlugin?.deleteNotificationChannel('alarms_v3');
      } catch (_) {}

      // Create alarm channels for each selectable sound (Android channel sound cannot change once created)
      final soundLabels = {
        'alarm_sound': 'Default Alarm',
        'alarm_classic': 'Classic Digital',
        'alarm_gentle': 'Gentle Chime',
        'alarm_urgent': 'Urgent Radar',
      };

      for (final soundKey in alarmSoundKeys) {
        final channelId = soundKey == 'alarm_sound'
            ? channelAlarm
            : '${channelAlarm}_$soundKey';
        final soundLabel = soundLabels[soundKey] ?? 'Alarm';
        await androidPlugin?.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            'Task Alarms ($soundLabel)',
            description: 'High-priority task alarms that ring continuously',
            importance: Importance.max,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(soundKey),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400, 1000]),
          ),
        );
      }
    }
  }

  @override
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notificationsAllowed =
          await android?.requestNotificationsPermission() ?? false;
      if (!notificationsAllowed) return false;
      if (await android?.canScheduleExactNotifications() == false) {
        await android?.requestExactAlarmsPermission();
        _exactAlarmsAvailable =
            await android?.canScheduleExactNotifications() ?? false;
      }
      await android?.requestFullScreenIntentPermission();
      return true;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<bool> hasPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  @override
  Future<int> scheduleTaskReminder({
    required Task task,
    required DateTime scheduledAt,
    required int notificationId,
    required bool isConstant,
    String? label,
    bool ringAsAlarm = false,
    ReminderAlertBehavior alertBehavior =
        ReminderAlertBehavior.soundAndVibration,
    bool repeatDaily = false,
  }) async {
    final alarmMode = ringAsAlarm;
    final repeated =
        alertBehavior == ReminderAlertBehavior.repeated || isConstant;
    final isInsistent = alarmMode || repeated;
    final isNativeAlarm = alarmMode && Platform.isAndroid;

    final soundKey = task.reminderPlan.alarmSoundId.isNotEmpty
        ? task.reminderPlan.alarmSoundId
        : 'alarm_sound';

    if (isNativeAlarm && scheduledAt.isAfter(DateTime.now())) {
      await _plugin.cancel(notificationId);
      await const MethodChannel('com.example.todow/alarm_native').invokeMethod(
        'scheduleAlarm',
        {
          'notificationId': notificationId,
          'triggerAt': scheduledAt.millisecondsSinceEpoch,
          'taskId': task.id,
          'taskTitle': task.title,
          'taskDescription': task.description,
          'soundName': soundKey,
        },
      );
      return notificationId;
    }

    final channel = alarmMode
        ? (soundKey == 'alarm_sound'
            ? channelAlarm
            : '${channelAlarm}_$soundKey')
        : isConstant
            ? channelConstant
            : switch (alertBehavior) {
                ReminderAlertBehavior.silent => channelSilent,
                ReminderAlertBehavior.beep => channelBeep,
                _ => channelVibration,
              };

    final title = task.title;
    final timingLine = _formatTimingContext(
      label: label,
      dueAt: task.dueAt,
      isConstant: isConstant,
    );
    final hasDescription = task.description.trim().isNotEmpty;

    // Collapsed body: single-line summary with timing and optional description snippet
    final collapsedBody = hasDescription
        ? '$timingLine — ${task.description.trim()}'
        : timingLine;

    // Expanded body: dynamic multi-line formatting with clean separation
    final expandedBody = hasDescription
        ? '$timingLine\n\n${task.description.trim()}'
        : timingLine;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        alarmMode
            ? 'Task Alarms'
            : (isConstant ? 'Constant Reminders' : 'Reminders'),
        channelDescription: alarmMode
            ? 'High-priority task alarms that ring continuously'
            : 'Task reminder notifications',
        importance: isInsistent ? Importance.max : Importance.high,
        priority: isInsistent ? Priority.max : Priority.high,
        ongoing: isInsistent,
        autoCancel: !isInsistent,
        showWhen:
            false, // Prevents Android adding confusing relative timestamps like "now"

        // Full-screen intent (alarm-style UI overlay) — only for alarm mode.
        fullScreenIntent: alarmMode,

        // FLAG_INSISTENT (bit 4 = decimal 4) makes the alarm audio repeat continuously until dismissed/snoozed.
        additionalFlags: isInsistent ? Int32List.fromList(<int>[4]) : null,

        category: alarmMode
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        audioAttributesUsage: alarmMode
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        sound: alarmMode ? RawResourceAndroidNotificationSound(soundKey) : null,
        visibility: NotificationVisibility.public,
        playSound: alertBehavior != ReminderAlertBehavior.silent,
        enableVibration:
            alertBehavior == ReminderAlertBehavior.soundAndVibration ||
                alarmMode ||
                repeated,
        vibrationPattern: alarmMode
            ? Int64List.fromList([0, 800, 400, 800, 400, 1000])
            : null,

        // Brand accent colour on the notification icon badge (Azure).
        color: const Color(0xFF0EA5E9),

        // Keep subText null so OEM launchers display the clean app name "Todow" instead of duplicating timestamps
        subText: null,

        // Dynamic BigTextStyle: expands cleanly to accommodate all lines without clipping
        styleInformation: BigTextStyleInformation(
          expandedBody,
          contentTitle: title,
          summaryText: null,
          htmlFormatContent: false,
          htmlFormatContentTitle: false,
        ),

        actions: alarmMode
            ? const [
                AndroidNotificationAction('complete', 'Done',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('snooze', 'Snooze 10m',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('dismiss', 'Stop Alarm',
                    showsUserInterface: false, cancelNotification: true),
              ]
            : const [
                AndroidNotificationAction('complete', 'Done',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('snooze', 'Snooze 10m',
                    showsUserInterface: true, cancelNotification: true),
                AndroidNotificationAction('open', 'Open',
                    showsUserInterface: true, cancelNotification: true),
              ],
      ),
      iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true),
    );

    debugPrint(
      'Scheduling notification #$notificationId "$title" for '
      '${scheduledAt.toIso8601String()} '
      '(now: ${DateTime.now().toIso8601String()}, tz: ${tz.local.name})',
    );

    if (scheduledAt.isBefore(DateTime.now())) {
      // Past / overdue — fire immediately.
      if (isNativeAlarm) {
        await const MethodChannel('com.example.todow/alarm_native')
            .invokeMethod('startAlarm', {
          'taskId': task.id,
          'taskTitle': task.title,
          'taskDescription': task.description,
          'soundName': soundKey,
        });
        return notificationId;
      }
      await _plugin.show(notificationId, title, collapsedBody, details,
          payload: task.id);
    } else {
      final tzScheduled = tz.TZDateTime.from(scheduledAt, tz.local);
      try {
        await _plugin.zonedSchedule(
          notificationId,
          title,
          collapsedBody,
          tzScheduled,
          details,
          androidScheduleMode: _exactAlarmsAvailable
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
        );
      } catch (e) {
        if (_exactAlarmsAvailable) {
          _exactAlarmsAvailable = false;
          try {
            await _plugin.zonedSchedule(
              notificationId,
              title,
              collapsedBody,
              tzScheduled,
              details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              payload: task.id,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents:
                  repeatDaily ? DateTimeComponents.time : null,
            );
          } catch (e2) {
            debugPrint('[ERR-NOTIF] Inexact fallback schedule failed: $e2');
          }
        } else {
          debugPrint('[ERR-NOTIF] Notification schedule failed: $e');
        }
      }
    }
    return notificationId;
  }

  @override
  Future<void> cancelNotification(int notificationId) async {
    if (Platform.isAndroid) {
      await const MethodChannel('com.example.todow/alarm_native').invokeMethod(
        'cancelAlarm',
        {'notificationId': notificationId},
      );
    }
    await _plugin.cancel(notificationId);
  }

  @override
  Future<void> cancelAllForTask(
      String taskId, List<int> notificationIds) async {
    for (final id in notificationIds) {
      await cancelNotification(id);
    }
  }

  @override
  Future<void> scheduleConstantFollowUp({
    required Task task,
    required int notificationId,
    Duration interval = const Duration(minutes: 15),
  }) =>
      scheduleTaskReminder(
        task: task,
        scheduledAt: DateTime.now().add(interval),
        notificationId: notificationId,
        isConstant: true,
        label: 'Still pending',
        ringAsAlarm: task.reminderPlan.ringAsAlarm,
      );
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqf;
import 'package:todow/domain/models/task.dart';
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
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
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
        case 'snooze':
          await _snoozeTask(db, taskId);
      }
    } finally {
      await db.close();
    }
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
      debugPrint('[BG] No active reminder found for task $taskId — skipping snooze.');
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
  }) async {
    // Initialise timezone for the background isolate.
    tz_data.initializeTimeZones();
    try {
      final tz.Location loc = tz.getLocation(await FlutterTimezone.getLocalTimezone());
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

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Reminders',
        channelDescription: 'Task reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFF97316),
        subText: 'Snoozed',
        actions: [
          AndroidNotificationAction('complete', 'Complete',
              showsUserInterface: true),
          AndroidNotificationAction('snooze', 'Snooze 15m',
              showsUserInterface: true),
          AndroidNotificationAction('open', 'Open', showsUserInterface: true),
        ],
      ),
    );

    final tzScheduled = tz.TZDateTime.from(fireAt, tz.local);
    try {
      await plugin.zonedSchedule(
        notifId,
        title,
        null,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: taskId,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await plugin.zonedSchedule(
        notifId,
        title,
        null,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: taskId,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}

class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl({this.onAction});

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final NotificationTapHandler? onAction;

  static const channelNormal = 'reminders';
  static const channelConstant = 'constant_reminders';
  static const channelAlarm = 'alarms';

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
          channelConstant,
          'Constant Reminders',
          description: 'Persistent reminders until task is completed',
          importance: Importance.max,
        ),
      );

      // Alarm channel: max importance, full vibration pattern.
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          channelAlarm,
          'Alarms',
          description: 'Full-screen task alarms',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        ),
      );
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
      }
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
  }) async {
    final channel =
        ringAsAlarm ? channelAlarm : (isConstant ? channelConstant : channelNormal);

    final title = task.title;
    final timeContext = label ?? (isConstant ? 'Still pending' : 'Due now');
    final hasDescription = task.description.isNotEmpty;

    // Body: description when present, otherwise null (clean single-line look).
    final body = hasDescription ? task.description : null;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        isConstant ? 'Constant Reminders' : 'Reminders',
        channelDescription: 'Task reminder notifications',
        importance: ringAsAlarm || isConstant ? Importance.max : Importance.high,
        priority: ringAsAlarm || isConstant ? Priority.max : Priority.high,
        ongoing: isConstant || ringAsAlarm,
        autoCancel: !isConstant && !ringAsAlarm,

        // Full-screen intent (alarm-style UI overlay) — only for alarm mode.
        fullScreenIntent: ringAsAlarm,

        // FLAG_INSISTENT (bit 4 = decimal 4) makes the alarm ring continuously.
        additionalFlags: ringAsAlarm ? Int32List.fromList(<int>[4]) : null,

        category: ringAsAlarm
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.reminder,
        audioAttributesUsage: ringAsAlarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        visibility: NotificationVisibility.public,

        // Brand accent colour on the notification icon badge.
        color: const Color(0xFFF97316),

        // subText shows the context label (e.g. "1 day before") next to the
        // app name — no need to repeat it in the body or summary.
        subText: timeContext,

        // Only expand when there is actual content to show.
        // Remove summaryText repetition — subText already carries the context.
        styleInformation: hasDescription
            ? BigTextStyleInformation(
                task.description,
                contentTitle: title,
                htmlFormatContent: false,
                htmlFormatContentTitle: false,
              )
            : null,

        actions: const [
          AndroidNotificationAction('complete', 'Complete',
              showsUserInterface: true),
          AndroidNotificationAction('snooze', 'Snooze 15m',
              showsUserInterface: true),
          AndroidNotificationAction('open', 'Open',
              showsUserInterface: true),
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
      await _plugin.show(notificationId, title, body, details,
          payload: task.id);
    } else {
      final tzScheduled = tz.TZDateTime.from(scheduledAt, tz.local);
      try {
        await _plugin.zonedSchedule(
          notificationId,
          title,
          body,
          tzScheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: task.id,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('Exact alarm unavailable, falling back to inexact: $e');
        await _plugin.zonedSchedule(
          notificationId,
          title,
          body,
          tzScheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: task.id,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
    return notificationId;
  }

  @override
  Future<void> cancelNotification(int notificationId) =>
      _plugin.cancel(notificationId);

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

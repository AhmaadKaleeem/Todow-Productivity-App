import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/enums.dart';

enum NotificationAction { complete, snooze, openTask }

abstract class NotificationService {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<bool> hasPermissions();

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
  });

  Future<void> cancelNotification(int notificationId);
  Future<void> cancelAllForTask(String taskId, List<int> notificationIds);

  /// Reschedules constant reminder at [interval] until task is handled.
  Future<void> scheduleConstantFollowUp({
    required Task task,
    required int notificationId,
    Duration interval = const Duration(minutes: 15),
  });
}

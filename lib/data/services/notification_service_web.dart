import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/services/notification_service.dart';

typedef NotificationTapHandler = void Function(String? payload, String? action);

/// Browser notifications are not scheduled by the native plugin on web.
/// Reminder state still persists and can be surfaced in the app UI.
class NotificationServiceImpl implements NotificationService {
  NotificationServiceImpl({this.onAction});

  final NotificationTapHandler? onAction;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<bool> hasPermissions() async => false;

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
  }) async =>
      notificationId;

  @override
  Future<void> cancelNotification(int notificationId) async {}

  @override
  Future<void> cancelAllForTask(
      String taskId, List<int> notificationIds) async {}

  @override
  Future<void> scheduleConstantFollowUp({
    required Task task,
    required int notificationId,
    Duration interval = const Duration(minutes: 15),
  }) async {}
}

import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/timetable_entry.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/reminders/reminder_calculator.dart';
import 'package:todow/domain/repositories/task_repository.dart';
import 'package:todow/domain/repositories/timetable_repository.dart';
import 'package:todow/domain/services/notification_service.dart';
import 'package:todow/domain/services/reminder_scheduler.dart';

class ReminderSchedulerImpl implements ReminderScheduler {
  ReminderSchedulerImpl(this._tasks, this._timetable, this._notifications);

  final TaskRepository _tasks;
  final TimetableRepository _timetable;
  final NotificationService _notifications;

  int _notificationIdFor(String reminderId) =>
      reminderId.hashCode.abs() % 2147483647;

  @override
  Future<void> syncTaskReminders(Task task) async {
    // Always fetch the existing reminders so we can diff against them.
    final existing = await _tasks.getRemindersForTask(task.id);

    if (task.isCompleted || task.isArchived || task.dueAt == null) {
      await cancelTaskReminders(task.id);
      return;
    }

    final timetable = task.reminderPlan.flexibleReminder
        ? await _timetable.getAll()
        : const <TimetableEntry>[];

    final schedule = ReminderCalculator.buildSchedule(task, timetable: timetable);
    final persisted = <ScheduledReminder>[];

    // Build a lookup from stable reminder-string-id → existing DB row.
    final existingMap = {for (final r in existing) r.id: r};

    // Seed with ALL existing OS notification IDs (as stored integers).
    // We'll remove the ones we want to keep; everything left gets cancelled.
    final idsToCancel = existing
        .map((r) => r.notificationId)
        .whereType<int>()
        .toSet();

    for (var reminder in schedule) {
      final notifId = _notificationIdFor(reminder.id);
      final old = existingMap[reminder.id];

      // Preserve a HANDLED reminder only when the scheduled time hasn't
      // changed.  If the user edits the due date the time will differ, so
      // we fall through and reschedule with the new time.
      if (old != null &&
          old.status == ReminderStatus.handled &&
          old.scheduledAt.isAtSameMomentAs(reminder.scheduledAt)) {
        persisted.add(old);
        // This notif was already cancelled when it fired — don't cancel again.
        idsToCancel.remove(old.notificationId);
        idsToCancel.remove(notifId);
        continue;
      }

      // Preserve a SNOOZED reminder's wake-up time if the due date is the
      // same.  If the due date changed, treat it as a fresh reminder.
      if (old != null &&
          old.status == ReminderStatus.snoozed &&
          old.snoozedUntil != null &&
          old.scheduledAt.isAtSameMomentAs(reminder.scheduledAt)) {
        reminder = reminder.copyWith(
          status: ReminderStatus.snoozed,
          snoozedUntil: old.snoozedUntil,
          scheduledAt: old.snoozedUntil,
        );
      }

      // Remove from cancel-set BEFORE scheduling so a replace on the same
      // notifId doesn't cancel the freshly scheduled alarm.
      idsToCancel.remove(notifId);
      if (old?.notificationId != null) idsToCancel.remove(old!.notificationId);

      await _notifications.scheduleTaskReminder(
        task: task,
        scheduledAt: reminder.scheduledAt,
        notificationId: notifId,
        isConstant: false,
        label: reminder.label,
        ringAsAlarm: task.reminderPlan.ringAsAlarm,
        alertBehavior: task.reminderPlan.alertBehavior,
        repeatDaily: reminder.repeatDaily,
      );
      persisted.add(reminder.copyWith(notificationId: notifId));
    }

    if (task.hasConstantReminder) {
      final firstAt = schedule.isNotEmpty
          ? schedule.first.scheduledAt
          : DateTime.now().add(const Duration(minutes: 1));
      final interval = Duration(
        minutes: task.reminderPlan.constantIntervalMinutes.clamp(1, 1440),
      );
      var scheduledAt =
          firstAt.isAfter(DateTime.now()) ? firstAt : DateTime.now();

      // Queue a day of native alarms so delivery continues while Flutter is
      // stopped. Completion cancels the persisted chain; the next app launch
      // replenishes it for tasks that remain pending.
      for (var index = 0; index < 96; index++) {
        final constantId = 'constant-${task.id}-$index';
        final notifId = _notificationIdFor(constantId);
        final constantAt = _nextAllowedConstantTime(task, scheduledAt);
        idsToCancel.remove(notifId);
        await _notifications.scheduleTaskReminder(
          task: task,
          scheduledAt: constantAt,
          notificationId: notifId,
          isConstant: true,
          label: 'Constant reminder',
          ringAsAlarm: task.reminderPlan.ringAsAlarm,
          alertBehavior: task.reminderPlan.alertBehavior ==
                  ReminderAlertBehavior.soundAndVibration
              ? ReminderAlertBehavior.repeated
              : task.reminderPlan.alertBehavior,
        );
        persisted.add(
          ScheduledReminder(
            id: constantId,
            taskId: task.id,
            scheduledAt: constantAt,
            status: ReminderStatus.pending,
            kind: ReminderKind.constant,
            notificationId: notifId,
            label: 'Constant reminder',
          ),
        );
        scheduledAt = constantAt.add(interval);
      }
    }

    // Cancel any OS alarms that are no longer in the new schedule.
    for (final id in idsToCancel) {
      await _notifications.cancelNotification(id);
    }

    await _tasks.saveReminders(task.id, persisted);
  }

  @override
  Future<void> cancelTaskReminders(String taskId) async {
    final existing = await _tasks.getRemindersForTask(taskId);
    final ids = existing
        .where((r) => r.notificationId != null)
        .map((r) => r.notificationId!)
        .toList();
    await _notifications.cancelAllForTask(taskId, ids);
    await _tasks.saveReminders(taskId, const []);
  }

  @override
  Future<void> snoozeReminder(
    ScheduledReminder reminder,
    Duration duration,
  ) async {
    if (reminder.notificationId != null) {
      await _notifications.cancelNotification(reminder.notificationId!);
    }
    final task = await _tasks.getById(reminder.taskId);
    if (task == null) return;

    final snoozedUntil = DateTime.now().add(duration);
    final notifId = _notificationIdFor('${reminder.id}-snooze');
    await _notifications.scheduleTaskReminder(
      task: task,
      scheduledAt: snoozedUntil,
      notificationId: notifId,
      isConstant: reminder.kind == ReminderKind.constant,
      label: 'Snoozed',
      ringAsAlarm: task.reminderPlan.ringAsAlarm,
      alertBehavior: task.reminderPlan.alertBehavior,
      repeatDaily: reminder.repeatDaily,
    );
    await _tasks.updateReminder(
      reminder.copyWith(
        status: ReminderStatus.snoozed,
        snoozedUntil: snoozedUntil,
        scheduledAt: snoozedUntil,
        notificationId: notifId,
      ),
    );
  }

  @override
  Future<void> markReminderHandled(String reminderId) async {
    final all = await _tasks.getActiveReminders();
    final match = all.where((r) => r.id == reminderId).firstOrNull;
    if (match == null) return;
    if (match.notificationId != null) {
      await _notifications.cancelNotification(match.notificationId!);
    }
    await _tasks.updateReminder(
      match.copyWith(status: ReminderStatus.handled),
    );
  }

  @override
  Future<void> rescheduleConstantReminder(Task task) async {
    if (!task.hasConstantReminder || task.isCompleted) return;
    final constant = (await _tasks.getRemindersForTask(task.id))
        .where((r) => r.kind == ReminderKind.constant && r.isActive)
        .firstOrNull;
    if (constant?.notificationId == null) return;

    await _notifications.scheduleConstantFollowUp(
      task: task,
      notificationId: constant!.notificationId!,
      interval: Duration(minutes: task.reminderPlan.constantIntervalMinutes),
    );
  }

  @override
  Future<void> recoverPendingReminders() async {
    final activeReminders = await _tasks.getActiveReminders();
    if (activeReminders.isEmpty) return;

    final now = DateTime.now();
    final missedTaskIds = <String>{};

    for (final r in activeReminders) {
      if (r.scheduledAt.isBefore(now)) {
        missedTaskIds.add(r.taskId);
      }
    }

    if (missedTaskIds.isEmpty) return;

    for (final taskId in missedTaskIds) {
      final task = await _tasks.getById(taskId);
      if (task == null || task.isCompleted || task.isArchived) continue;
      await syncTaskReminders(task);
    }
  }

  DateTime _nextAllowedConstantTime(Task task, DateTime candidate) {
    final start = task.reminderPlan.quietHoursStartMinutes;
    final end = task.reminderPlan.quietHoursEndMinutes;
    if (start == null || end == null) return candidate;

    var result = candidate;
    for (var i = 0; i < 2; i++) {
      final minutes = result.hour * 60 + result.minute;
      final inQuietHours = start < end
          ? minutes >= start && minutes < end
          : minutes >= start || minutes < end;
      if (!inQuietHours) return result;
      result = start < end || minutes >= start
          ? DateTime(result.year, result.month, result.day + 1, end ~/ 60,
              end % 60)
          : DateTime(
              result.year, result.month, result.day, end ~/ 60, end % 60);
    }
    return result;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/timetable_entry.dart';

abstract final class ReminderCalculator {
  /// Computes scheduled reminder times from a task due date and reminder plan.
  ///
  /// Rules:
  /// - All future reminders are included as-is.
  /// - Past reminders are collapsed: at most ONE is kept (the deadline offset if
  ///   present, otherwise the most-recently-scheduled past offset). This prevents
  ///   multiple immediate notifications from firing for a single overdue task.
  static List<ScheduledReminder> buildSchedule(
    Task task, {
    DateTime? now,
    List<TimetableEntry> timetable = const [],
  }) {
    if (task.isCompleted || task.isArchived) {
      return const [];
    }

    final reference = now ?? DateTime.now();
    final future = <ScheduledReminder>[];
    final past   = <ScheduledReminder>[];

    final dailyMinutes = task.reminderPlan.dailyReminderMinutes;
    if (dailyMinutes != null) {
      var scheduledAt = DateTime(
        reference.year,
        reference.month,
        reference.day,
        dailyMinutes ~/ 60,
        dailyMinutes % 60,
      );
      if (!scheduledAt.isAfter(reference)) {
        scheduledAt = scheduledAt.add(const Duration(days: 1));
      }
      future.add(ScheduledReminder(
        id: '${task.id}-daily',
        taskId: task.id,
        scheduledAt: scheduledAt,
        status: ReminderStatus.pending,
        kind: ReminderKind.daily,
        label: 'Daily reminder',
        repeatDaily: true,
      ));
    }

    final dueAt = task.dueAt;
    if (dueAt == null) return future;

    for (final offset in task.reminderPlan.allOffsets) {
      var scheduledAt = applyOffset(dueAt, offset);

      if (task.reminderPlan.flexibleReminder && timetable.isNotEmpty) {
        scheduledAt = _deferIfInClass(scheduledAt, timetable);
      }

      final idSuffix = offset.atDeadline
          ? 'deadline'
          : 'rel-${offset.days}-${offset.hours}-${offset.minutes}';

      final reminder = ScheduledReminder(
        id: '${task.id}-$idSuffix',
        taskId: task.id,
        scheduledAt: scheduledAt,
        status: ReminderStatus.pending,
        kind: offset.atDeadline
            ? ReminderKind.atDeadline
            : ReminderKind.relative,
        label: offset.label,
      );

      // Cutoff: 1 minute ago so a just-fired reminder isn't re-fired.
      if (scheduledAt.isBefore(reference.subtract(const Duration(minutes: 1)))) {
        past.add(reminder);
      } else {
        future.add(reminder);
      }
    }

    // Collapse all past reminders into a single one to avoid notification spam.
    // Prefer the deadline offset; otherwise take the most recently scheduled.
    if (past.isNotEmpty) {
      final single = past.firstWhere(
        (r) => r.kind == ReminderKind.atDeadline,
        orElse: () {
          past.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
          return past.first;
        },
      );
      future.add(single);
    }

    future.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return future;
  }

  static DateTime applyOffset(DateTime dueAt, ReminderOffset offset) {
    if (offset.atDeadline) return dueAt;
    return dueAt.subtract(
      Duration(days: offset.days, hours: offset.hours, minutes: offset.minutes),
    );
  }

  static bool isEscalationWindow(DateTime dueAt, DateTime reminderTime) {
    final diff = dueAt.difference(reminderTime);
    return diff <= const Duration(hours: 3);
  }

  static DateTime _deferIfInClass(DateTime time, List<TimetableEntry> classes) {
    var deferred = time;
    bool changed;
    do {
      changed = false;
      for (final cls in classes) {
        final matchesDay = (cls.repeatWeekly && cls.weekday.index == deferred.weekday - 1) || 
            (!cls.repeatWeekly && cls.scheduledDate?.year == deferred.year && cls.scheduledDate?.month == deferred.month && cls.scheduledDate?.day == deferred.day);

        if (matchesDay) {
          final start = DateTime(deferred.year, deferred.month, deferred.day, cls.startTime.hour, cls.startTime.minute);
          final end = DateTime(deferred.year, deferred.month, deferred.day, cls.endTime.hour, cls.endTime.minute);
          
          if (!deferred.isBefore(start) && deferred.isBefore(end)) {
            deferred = end.add(const Duration(minutes: 5));
            changed = true;
          }
        }
      }
    } while (changed);
    return deferred;
  }
}

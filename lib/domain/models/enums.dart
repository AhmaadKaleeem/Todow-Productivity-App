enum TaskStatus { inbox, active, completed, archived }

enum TaskPriority { none, low, medium, high, critical }

enum TaskSourceType { local, gmail, classroom, airUniversity, calendar }

enum ReminderPreset { normal, assignment, critical, daily, custom }

enum ReminderAlertBehavior {
  silent,
  beep,
  soundAndVibration,
  fullScreen,
  repeated,
}

enum ReminderStatus { pending, fired, snoozed, handled, cancelled }

enum ReminderKind { relative, absolute, atDeadline, daily, constant }

enum FocusPreset { study, coding, assignment, reading, deepWork, flow }

enum FocusSessionStatus { idle, running, paused, ended }

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

enum TimetableKind { university, personal }

extension WeekdayExt on Weekday {
  int get dartWeekday => index + 1;

  static Weekday fromDartWeekday(int day) => Weekday.values[day - 1];

  String get shortLabel {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index];
  }

  String get fullLabel {
    const labels = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return labels[index];
  }
}

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.none:
        return 'None';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.critical:
        return 'Critical';
    }
  }
}

extension ReminderPresetExt on ReminderPreset {
  String get label {
    switch (this) {
      case ReminderPreset.normal:
        return 'Normal';
      case ReminderPreset.assignment:
        return 'Assignment';
      case ReminderPreset.critical:
        return 'Critical';
      case ReminderPreset.daily:
        return 'Daily';
      case ReminderPreset.custom:
        return 'Custom';
    }
  }
}

extension FocusPresetExt on FocusPreset {
  String get label {
    switch (this) {
      case FocusPreset.study:
        return 'Study';
      case FocusPreset.coding:
        return 'Coding';
      case FocusPreset.assignment:
        return 'Assignment';
      case FocusPreset.reading:
        return 'Reading';
      case FocusPreset.deepWork:
        return 'Deep Work';
      case FocusPreset.flow:
        return 'Ultradian';
    }
  }

  Duration get defaultDuration {
    switch (this) {
      case FocusPreset.study:
        return const Duration(minutes: 50);
      case FocusPreset.coding:
        return const Duration(minutes: 90);
      case FocusPreset.assignment:
        return const Duration(minutes: 90);
      case FocusPreset.reading:
        return const Duration(minutes: 45);
      case FocusPreset.deepWork:
        return const Duration(minutes: 120);
      case FocusPreset.flow:
        return const Duration(minutes: 90);
    }
  }

  Duration get restDuration {
    switch (this) {
      case FocusPreset.flow:
        return const Duration(minutes: 20);
      default:
        return const Duration(minutes: 5);
    }
  }
}

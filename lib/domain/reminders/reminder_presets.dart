import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';

abstract final class ReminderPresets {
  static const normal = [
    ReminderOffset(days: 1, hours: 0, minutes: 0),
    ReminderOffset(days: 0, hours: 0, minutes: 0, atDeadline: true),
  ];

  static const assignment = [
    ReminderOffset(days: 2, hours: 0, minutes: 0),
    ReminderOffset(days: 1, hours: 0, minutes: 0),
    ReminderOffset(days: 0, hours: 3, minutes: 0),
    ReminderOffset(days: 0, hours: 0, minutes: 30),
  ];

  static const critical = [
    ReminderOffset(days: 3, hours: 0, minutes: 0),
    ReminderOffset(days: 2, hours: 0, minutes: 0),
    ReminderOffset(days: 1, hours: 0, minutes: 0),
    ReminderOffset(days: 0, hours: 3, minutes: 0),
    ReminderOffset(days: 0, hours: 1, minutes: 0),
    ReminderOffset(days: 0, hours: 0, minutes: 30),
    ReminderOffset(days: 0, hours: 0, minutes: 0, atDeadline: true),
  ];

  static List<ReminderOffset> forPreset(ReminderPreset preset) {
    switch (preset) {
      case ReminderPreset.normal:
        return normal;
      case ReminderPreset.assignment:
        return assignment;
      case ReminderPreset.critical:
        return critical;
      case ReminderPreset.daily:
        return const [];
      case ReminderPreset.custom:
        return const [];
    }
  }

  static ReminderPlan defaultPlan(
      [ReminderPreset preset = ReminderPreset.normal]) {
    return ReminderPlan(
      preset: preset,
      offsets: forPreset(preset),
      constantReminder: false,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/reminders/reminder_presets.dart';

// â”€â”€ Pre-configured quick-add chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const _quickOffsets = [
  ReminderOffset(days: 0, hours: 0, minutes: 10),
  ReminderOffset(days: 0, hours: 0, minutes: 30),
  ReminderOffset(days: 0, hours: 1, minutes: 0),
  ReminderOffset(days: 0, hours: 3, minutes: 0),
  ReminderOffset(days: 1, hours: 0, minutes: 0),
  ReminderOffset(days: 2, hours: 0, minutes: 0),
  ReminderOffset(days: 3, hours: 0, minutes: 0),
  ReminderOffset(days: 0, hours: 0, minutes: 0, atDeadline: true),
];

String _fmtTime(int totalMinutes) {
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:${m.toString().padLeft(2, '0')} $ampm';
}

class RemindersSection extends StatelessWidget {
  const RemindersSection({
    super.key,
    required this.plan,
    this.dueAt,
    required this.onChanged,
    this.onSetDueDate,
  });

  final ReminderPlan plan;
  final DateTime? dueAt;
  final ValueChanged<ReminderPlan> onChanged;

  final VoidCallback? onSetDueDate;

  List<ReminderOffset> get _activeOffsets => plan.allOffsets;

  void _toggleOffset(ReminderOffset o) {
    final current = List<ReminderOffset>.from(plan.allOffsets);
    final idx = current.indexWhere((c) =>
        c.days == o.days &&
        c.hours == o.hours &&
        c.minutes == o.minutes &&
        c.atDeadline == o.atDeadline);

    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add(o);
    }
    _applyOffsets(current);
  }

  void _applyOffsets(List<ReminderOffset> offsets) {
    if (_matches(offsets, ReminderPresets.normal)) {
      onChanged(plan.copyWith(
          preset: ReminderPreset.normal,
          offsets: ReminderPresets.normal,
          customOffsets: const []));
    } else if (_matches(offsets, ReminderPresets.assignment)) {
      onChanged(plan.copyWith(
          preset: ReminderPreset.assignment,
          offsets: ReminderPresets.assignment,
          customOffsets: const []));
    } else if (_matches(offsets, ReminderPresets.critical)) {
      onChanged(plan.copyWith(
          preset: ReminderPreset.critical,
          offsets: ReminderPresets.critical,
          customOffsets: const []));
    } else {
      onChanged(plan.copyWith(
          preset: ReminderPreset.custom,
          offsets: const [],
          customOffsets: offsets));
    }
  }

  bool _matches(List<ReminderOffset> a, List<ReminderOffset> b) {
    if (a.length != b.length) return false;
    for (final oa in a) {
      if (!b.any((ob) =>
          oa.days == ob.days &&
          oa.hours == ob.hours &&
          oa.minutes == ob.minutes &&
          oa.atDeadline == ob.atDeadline)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _addCustom(
    BuildContext context, {
    ReminderOffset? editing,
  }) async {
    final results = await showModalBottomSheet<List<ReminderOffset>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomReminderSheet(
        dueAt: dueAt,
        onSetDueDate: onSetDueDate,
        initialOffset: editing,
      ),
    );
    if (results != null && results.isNotEmpty) {
      final current = List<ReminderOffset>.from(plan.allOffsets);
      if (editing != null) {
        current.removeWhere((offset) =>
            offset.days == editing.days &&
            offset.hours == editing.hours &&
            offset.minutes == editing.minutes &&
            offset.atDeadline == editing.atDeadline);
      }
      for (final r in results) {
        final exists = current.any((c) =>
            c.days == r.days &&
            c.hours == r.hours &&
            c.minutes == r.minutes &&
            c.atDeadline == r.atDeadline);
        if (!exists) current.add(r);
      }
      _applyOffsets(current);
    }
  }

  void _selectPreset(ReminderPreset preset) {
    if (preset == ReminderPreset.daily) {
      onChanged(plan.copyWith(
        preset: preset,
        offsets: const [],
        customOffsets: const [],
        dailyReminderMinutes: plan.dailyReminderMinutes ?? 8 * 60,
      ));
      return;
    }
    onChanged(plan.copyWith(
      preset: preset,
      offsets: ReminderPresets.forPreset(preset),
      customOffsets: const [],
    ));
  }

  Future<void> _pickDailyTime(BuildContext context) async {
    final initial = plan.dailyReminderMinutes != null
        ? TimeOfDay(
            hour: plan.dailyReminderMinutes! ~/ 60,
            minute: plan.dailyReminderMinutes! % 60)
        : const TimeOfDay(hour: 8, minute: 0);

    final t = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => _timePickerTheme(ctx, child),
    );
    if (t != null) {
      onChanged(plan.copyWith(dailyReminderMinutes: t.hour * 60 + t.minute));
    }
  }

  Future<void> _pickQuietHour(
    BuildContext context, {
    required bool start,
  }) async {
    final current =
        start ? plan.quietHoursStartMinutes : plan.quietHoursEndMinutes;
    final initial = current == null
        ? (start
            ? const TimeOfDay(hour: 22, minute: 0)
            : const TimeOfDay(hour: 7, minute: 0))
        : TimeOfDay(hour: current ~/ 60, minute: current % 60);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => _timePickerTheme(ctx, child),
    );
    if (selected == null) return;
    final minutes = selected.hour * 60 + selected.minute;
    onChanged(start
        ? plan.copyWith(quietHoursStartMinutes: minutes)
        : plan.copyWith(quietHoursEndMinutes: minutes));
  }

  Widget _timePickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.action,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
            secondary: AppColors.action,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppColors.background,
            dialBackgroundColor: AppColors.surface,
            dialHandColor: AppColors.action,
            dialTextColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
            hourMinuteTextColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.action
                  : AppColors.textSecondary,
            ),
            hourMinuteColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.action.withValues(alpha: 0.15)
                  : AppColors.surface,
            ),
            dayPeriodTextColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.action
                  : AppColors.textSecondary,
            ),
            dayPeriodColor: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.action.withValues(alpha: 0.15)
                  : AppColors.surface,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            entryModeIconColor: AppColors.textSecondary,
            cancelButtonStyle: ButtonStyle(
                foregroundColor:
                    WidgetStateProperty.all(AppColors.textSecondary)),
            confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStateProperty.all(AppColors.action)),
          ),
        ),
        child: child!,
      );

  DateTime? _nextReminderAt() {
    final now = DateTime.now();
    final candidates = <DateTime>[];
    if (dueAt != null) {
      for (final offset in _activeOffsets) {
        final at = offset.atDeadline
            ? dueAt!
            : dueAt!.subtract(Duration(
                days: offset.days,
                hours: offset.hours,
                minutes: offset.minutes,
              ));
        if (at.isAfter(now)) candidates.add(at);
      }
    }
    if (plan.dailyReminderMinutes case final minutes?) {
      var at =
          DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      candidates.add(at);
    }
    candidates.sort();
    return candidates.isEmpty ? null : candidates.first;
  }

  String _scheduleTime(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    final today = DateUtils.isSameDay(date, DateTime.now());
    final tomorrow = DateUtils.isSameDay(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );
    final day = today
        ? 'Today'
        : tomorrow
            ? 'Tomorrow'
            : localizations.formatMediumDate(date);
    return '$day · ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasDailyReminder = plan.dailyReminderMinutes != null;
    final hasOffsets = _activeOffsets.isNotEmpty;
    final enabled = hasDailyReminder || (hasOffsets && dueAt != null);
    final needsDueDate = hasOffsets && dueAt == null && !hasDailyReminder;
    final nextReminder = _nextReminderAt();
    final presets = <(ReminderPreset, String, String)>[
      (ReminderPreset.normal, 'Normal', '1 day · due'),
      (ReminderPreset.assignment, 'Assignment', '2 days · 1 day · 3 hr'),
      (ReminderPreset.critical, 'Critical', '3 days · 2 days · 1 day'),
      (ReminderPreset.daily, 'Daily', 'Every day'),
      (ReminderPreset.custom, 'Custom', 'Choose times'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Task reminders',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      enabled
                          ? nextReminder == null
                              ? 'On · No upcoming reminder'
                              : 'Next · ${_scheduleTime(context, nextReminder)}'
                          : needsDueDate
                              ? 'Choose a due date to activate these times'
                              : 'Off · No reminders scheduled',
                      style: TextStyle(
                        color: enabled
                            ? AppColors.action
                            : AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (needsDueDate)
                      TextButton(
                        onPressed: onSetDueDate,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(48, 44),
                          alignment: Alignment.centerLeft,
                        ),
                        child: const Text('Choose due date'),
                      ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeColor: AppColors.action,
                onChanged: (value) {
                  if (!value) {
                    onChanged(plan.copyWith(
                      preset: ReminderPreset.custom,
                      offsets: const [],
                      customOffsets: const [],
                      clearDailyReminder: true,
                    ));
                  } else if (!enabled) {
                    if (!hasOffsets && !hasDailyReminder) {
                      _selectPreset(ReminderPreset.normal);
                    }
                    if (dueAt == null && !hasDailyReminder) {
                      onSetDueDate?.call();
                    }
                  }
                },
              ),
            ],
          ),
        ),
        const Text(
          'TIMING',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (preset, label, detail) in presets)
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: InkWell(
                    onTap: () => _selectPreset(preset),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: plan.preset == preset
                                  ? AppColors.action
                                  : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            detail,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 2,
                            width: 34,
                            color: plan.preset == preset
                                ? AppColors.action
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Scheduled times',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Add reminder time',
              onSelected: (value) {
                if (value == 'custom') {
                  _addCustom(context);
                } else {
                  final index = int.parse(value);
                  _toggleOffset(_quickOffsets[index]);
                }
              },
              itemBuilder: (context) => [
                for (var i = 0; i < _quickOffsets.length; i++)
                  PopupMenuItem(
                    value: '$i',
                    child: Text(_quickOffsets[i].label),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'custom',
                  child: Text('Choose a specific time'),
                ),
              ],
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 18, color: AppColors.action),
                    const SizedBox(width: 4),
                    Text('Add time',
                        style: TextStyle(
                            color: AppColors.action,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_activeOffsets.isEmpty && !hasDailyReminder)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Choose a reminder time or select a timing above.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          for (final offset in _activeOffsets)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(offset.label,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          if (dueAt != null)
                            Text(
                              _scheduleTime(
                                context,
                                offset.atDeadline
                                    ? dueAt!
                                    : dueAt!.subtract(Duration(
                                        days: offset.days,
                                        hours: offset.hours,
                                        minutes: offset.minutes,
                                      )),
                              ),
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _addCustom(context, editing: offset),
                      child: const Text('Edit'),
                    ),
                    IconButton(
                      tooltip: 'Remove ${offset.label}',
                      onPressed: () => _toggleOffset(offset),
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                Divider(
                    height: 1,
                    color: AppColors.divider.withValues(alpha: 0.65)),
              ],
            ),
        const SizedBox(height: 20),
        _settingRow(
          title: 'Daily repeat',
          description: hasDailyReminder
              ? 'Every day at ${_fmtTime(plan.dailyReminderMinutes!)}'
              : 'Repeat this reminder at the same time each day',
          value: hasDailyReminder,
          onChanged: (value) {
            if (value) {
              _pickDailyTime(context);
            } else {
              onChanged(plan.copyWith(clearDailyReminder: true));
            }
          },
          onTap: hasDailyReminder ? () => _pickDailyTime(context) : null,
        ),
        _settingRow(
          title: 'Repeat until done',
          description: plan.constantReminder
              ? 'Every ${plan.constantIntervalMinutes} minutes'
              : 'Keep reminding me until I finish this task',
          value: plan.constantReminder,
          onChanged: (value) =>
              onChanged(plan.copyWith(constantReminder: value)),
          trailing: plan.constantReminder
              ? DropdownButton<int>(
                  value: plan.constantIntervalMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [5, 10, 15, 30, 60]
                      .map((minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text('${minutes}m'),
                          ))
                      .toList(),
                  onChanged: (minutes) {
                    if (minutes != null) {
                      onChanged(
                          plan.copyWith(constantIntervalMinutes: minutes));
                    }
                  },
                )
              : null,
        ),
        _settingRow(
          title: 'Wait until class ends',
          description: 'Send the reminder after your current class',
          value: plan.flexibleReminder,
          onChanged: (value) =>
              onChanged(plan.copyWith(flexibleReminder: value)),
        ),
        _settingRow(
          title: 'Quiet hours',
          description: 'Pause repeat reminders overnight',
          value: plan.quietHoursStartMinutes != null &&
              plan.quietHoursEndMinutes != null,
          onChanged: (value) => onChanged(value
              ? plan.copyWith(
                  quietHoursStartMinutes: 22 * 60,
                  quietHoursEndMinutes: 7 * 60,
                )
              : plan.copyWith(clearQuietHours: true)),
          trailing: plan.quietHoursStartMinutes != null &&
                  plan.quietHoursEndMinutes != null
              ? TextButton(
                  onPressed: () => _pickQuietHour(context, start: true),
                  child: Text(
                    '${_fmtTime(plan.quietHoursStartMinutes!)} – ${_fmtTime(plan.quietHoursEndMinutes!)}',
                  ),
                )
              : null,
        ),
        _settingRow(
          title: 'Ring as alarm',
          description: plan.ringAsAlarm
              ? 'Full-screen alarm with sound and vibration'
              : 'Use a standard notification',
          value: plan.ringAsAlarm,
          onChanged: (value) => onChanged(plan.copyWith(
            ringAsAlarm: value,
            alertBehavior: value
                ? ReminderAlertBehavior.soundAndVibration
                : ReminderAlertBehavior.beep,
          )),
          trailing: plan.ringAsAlarm
              ? DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: plan.alarmSoundId,
                    items: const [
                      DropdownMenuItem(
                          value: 'alarm_sound', child: Text('Default')),
                      DropdownMenuItem(
                          value: 'alarm_classic', child: Text('Classic')),
                      DropdownMenuItem(
                          value: 'alarm_gentle', child: Text('Gentle')),
                      DropdownMenuItem(
                          value: 'alarm_urgent', child: Text('Urgent')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(plan.copyWith(alarmSoundId: value));
                      }
                    },
                  ),
                )
              : null,
        ),
        if (plan.ringAsAlarm)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child: Text(
              'If alarms do not ring, allow Alarms & reminders in Android settings.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  Widget _settingRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
    VoidCallback? onTap,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(description,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing,
            Switch(
              value: value,
              activeColor: AppColors.action,
              onChanged: onChanged,
            ),
          ],
        ),
      );
}

// â”€â”€ Sub-widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _CustomReminderSheet extends StatefulWidget {
  final DateTime? dueAt;
  final VoidCallback? onSetDueDate;
  final ReminderOffset? initialOffset;
  const _CustomReminderSheet({
    this.dueAt,
    this.onSetDueDate,
    this.initialOffset,
  });

  @override
  State<_CustomReminderSheet> createState() => _CustomReminderSheetState();
}

class _CustomReminderSheetState extends State<_CustomReminderSheet> {
  bool _isAbsolute = false;

  // Relative mode state
  int _days = 0;
  int _hours = 0;
  int _mins = 15;

  // Absolute mode state
  late DateTime _selectedAbsolute;

  // Accumulated reminders for this session
  final List<ReminderOffset> _added = [];

  @override
  void initState() {
    super.initState();
    final initialOffset = widget.initialOffset;
    if (initialOffset != null) {
      _days = initialOffset.days;
      _hours = initialOffset.hours;
      _mins = initialOffset.minutes;
    }
    final base = widget.dueAt ?? DateTime.now();
    _selectedAbsolute = base.subtract(const Duration(minutes: 15));
    if (_selectedAbsolute.isBefore(DateTime.now())) {
      _selectedAbsolute = DateTime.now().add(const Duration(hours: 1));
    }
  }

  ReminderOffset _buildOffset() {
    if (_isAbsolute && widget.dueAt != null) {
      final diff = widget.dueAt!.difference(_selectedAbsolute);
      if (diff.isNegative) {
        return const ReminderOffset(
            days: 0, hours: 0, minutes: 0, atDeadline: true);
      }
      return ReminderOffset(
          days: diff.inDays,
          hours: diff.inHours.remainder(24),
          minutes: diff.inMinutes.remainder(60));
    }
    return ReminderOffset(
      days: _days,
      hours: _hours,
      minutes: _mins,
      atDeadline: _days == 0 && _hours == 0 && _mins == 0,
    );
  }

  void _addThis() {
    final o = _buildOffset();
    final exists = _added.any((a) =>
        a.days == o.days &&
        a.hours == o.hours &&
        a.minutes == o.minutes &&
        a.atDeadline == o.atDeadline);
    if (!exists) {
      setState(() {
        _added.add(o);
        // Reset relative for next input
        _days = 0;
        _hours = 0;
        _mins = 15;
      });
    }
  }

  void _removeAdded(int i) => setState(() => _added.removeAt(i));

  void _done() => Navigator.pop(context, List<ReminderOffset>.from(_added));

  @override
  Widget build(BuildContext context) {
    final canAdd = _isAbsolute
        ? widget.dueAt != null
        : (_days > 0 ||
            _hours > 0 ||
            _mins > 0 ||
            widget.initialOffset?.atDeadline == true);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              const Expanded(
                child: Text('Add Reminder',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5)),
              ),
              if (_added.isNotEmpty)
                TextButton(
                  onPressed: _done,
                  child: Text('Done (${_added.length})',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.action)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Mode toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _Tab(
                    label: 'Relative',
                    selected: !_isAbsolute,
                    onTap: () => setState(() => _isAbsolute = false)),
                _Tab(
                    label: 'Exact Date & Time',
                    selected: _isAbsolute,
                    onTap: () => setState(() => _isAbsolute = true)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isAbsolute
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildRelativePicker(),
            secondChild: _buildAbsolutePicker(),
          ),

          const SizedBox(height: 20),

          // Accumulated list
          if (_added.isNotEmpty) ...[
            const Text('Will add:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                  _added.length,
                  (i) => _AddedChip(
                        label: _added[i].label,
                        onRemove: () => _removeAdded(i),
                      )),
            ),
            const SizedBox(height: 16),
          ],

          // Action row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: canAdd ? _addThis : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                        color: canAdd ? AppColors.action : AppColors.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('+ Add This',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: canAdd
                              ? AppColors.action
                              : AppColors.textSecondary)),
                ),
              ),
              if (_added.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _done,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.action,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                        'Save ${_added.length} Reminder${_added.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelativePicker() {
    return Column(
      children: [
        _Stepper(
            label: 'Days before',
            value: _days,
            min: 0,
            max: 30,
            onChanged: (v) => setState(() => _days = v)),
        const SizedBox(height: 12),
        _Stepper(
            label: 'Hours before',
            value: _hours,
            min: 0,
            max: 23,
            onChanged: (v) => setState(() => _hours = v)),
        const SizedBox(height: 12),
        _Stepper(
            label: 'Minutes before',
            value: _mins,
            min: 0,
            max: 55,
            step: 5,
            onChanged: (v) => setState(() => _mins = v)),
      ],
    );
  }

  Widget _buildAbsolutePicker() {
    if (widget.dueAt == null) {
      return GestureDetector(
        onTap: () {
          Navigator.pop(context, <ReminderOffset>[]);
          widget.onSetDueDate?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.attention.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppColors.attention.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.attention.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.attention, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No due date set',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Tap to set a due date first',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.attention),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _selectedAbsolute.isBefore(DateTime.now())
                  ? DateTime.now()
                  : _selectedAbsolute,
              firstDate: DateTime.now(),
              lastDate: widget.dueAt!,
            );
            if (d != null) {
              setState(() => _selectedAbsolute = DateTime(d.year, d.month,
                  d.day, _selectedAbsolute.hour, _selectedAbsolute.minute));
            }
          },
          child: _PickerRow(
            label: 'Date',
            value:
                '${_selectedAbsolute.day}/${_selectedAbsolute.month}/${_selectedAbsolute.year}',
            icon: Icons.calendar_today_rounded,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(_selectedAbsolute),
              builder: (ctx, child) => _timePickerTheme(ctx, child),
            );
            if (t != null) {
              setState(() => _selectedAbsolute = DateTime(
                  _selectedAbsolute.year,
                  _selectedAbsolute.month,
                  _selectedAbsolute.day,
                  t.hour,
                  t.minute));
            }
          },
          child: _PickerRow(
            label: 'Time',
            value: TimeOfDay.fromDateTime(_selectedAbsolute).format(context),
            icon: Icons.access_time_rounded,
          ),
        ),
      ],
    );
  }

  Widget _timePickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.action,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          timePickerTheme: TimePickerThemeData(
            backgroundColor: AppColors.background,
            dialBackgroundColor: AppColors.surface,
            dialHandColor: AppColors.action,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
        ),
        child: child!,
      );
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.action : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary),
            ),
          ),
        ),
      );
}

class _AddedChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _AddedChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.action.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.action.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.action)),
            const SizedBox(width: 4),
            GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.close_rounded,
                    size: 13, color: AppColors.action)),
          ],
        ),
      );
}

class _PickerRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PickerRow(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary))),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.action)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      );
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _Stepper(
      {required this.label,
      required this.value,
      required this.min,
      required this.max,
      this.step = 1,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary))),
            _StepBtn(
                icon: Icons.remove_rounded,
                onTap: value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null),
            SizedBox(
              width: 48,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ),
            _StepBtn(
                icon: Icons.add_rounded,
                onTap: value < max
                    ? () => onChanged((value + step).clamp(min, max))
                    : null),
          ],
        ),
      );
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.action.withValues(alpha: 0.1)
              : AppColors.divider.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: active
                ? AppColors.action
                : AppColors.textSecondary.withValues(alpha: 0.4)),
      ),
    );
  }
}

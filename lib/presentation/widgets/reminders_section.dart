import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/reminders/reminder_presets.dart';

// ── Pre-configured quick-add chips ───────────────────────────────────────────

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
  /// Called when user taps "Set Due Date" from the no-due-date banner.
  final VoidCallback? onSetDueDate;

  List<ReminderOffset> get _activeOffsets => plan.allOffsets;

  bool _isSelected(ReminderOffset o) => _activeOffsets.any(
        (a) =>
            a.days == o.days &&
            a.hours == o.hours &&
            a.minutes == o.minutes &&
            a.atDeadline == o.atDeadline,
      );

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
      onChanged(plan.copyWith(preset: ReminderPreset.normal, offsets: ReminderPresets.normal, customOffsets: const []));
    } else if (_matches(offsets, ReminderPresets.assignment)) {
      onChanged(plan.copyWith(preset: ReminderPreset.assignment, offsets: ReminderPresets.assignment, customOffsets: const []));
    } else if (_matches(offsets, ReminderPresets.critical)) {
      onChanged(plan.copyWith(preset: ReminderPreset.critical, offsets: ReminderPresets.critical, customOffsets: const []));
    } else {
      onChanged(plan.copyWith(preset: ReminderPreset.custom, offsets: const [], customOffsets: offsets));
    }
  }

  bool _matches(List<ReminderOffset> a, List<ReminderOffset> b) {
    if (a.length != b.length) return false;
    for (final oa in a) {
      if (!b.any((ob) => oa.days == ob.days && oa.hours == ob.hours && oa.minutes == ob.minutes && oa.atDeadline == ob.atDeadline)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _addCustom(BuildContext context) async {
    final results = await showModalBottomSheet<List<ReminderOffset>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomReminderSheet(dueAt: dueAt, onSetDueDate: onSetDueDate),
    );
    if (results != null && results.isNotEmpty) {
      final current = List<ReminderOffset>.from(plan.allOffsets);
      for (final r in results) {
        final exists = current.any((c) => c.days == r.days && c.hours == r.hours && c.minutes == r.minutes && c.atDeadline == r.atDeadline);
        if (!exists) current.add(r);
      }
      _applyOffsets(current);
    }
  }

  void _selectPreset(ReminderPreset preset) {
    onChanged(plan.copyWith(
      preset: preset,
      offsets: ReminderPresets.forPreset(preset),
    ));
  }

  Future<void> _pickDailyTime(BuildContext context) async {
    final initial = plan.dailyReminderMinutes != null
        ? TimeOfDay(hour: plan.dailyReminderMinutes! ~/ 60, minute: plan.dailyReminderMinutes! % 60)
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
          (states) => states.contains(WidgetState.selected) ? Colors.white : AppColors.textPrimary,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.action : AppColors.textSecondary,
        ),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.action.withValues(alpha: 0.15) : AppColors.surface,
        ),
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.action : AppColors.textSecondary,
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.action.withValues(alpha: 0.15) : AppColors.surface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        entryModeIconColor: AppColors.textSecondary,
        cancelButtonStyle: ButtonStyle(foregroundColor: WidgetStateProperty.all(AppColors.textSecondary)),
        confirmButtonStyle: ButtonStyle(foregroundColor: WidgetStateProperty.all(AppColors.action)),
      ),
    ),
    child: child!,
  );

  @override
  Widget build(BuildContext context) {
    final hasDailyReminder = plan.dailyReminderMinutes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'REMINDERS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // ── Main card ─────────────────────────────────────────────────────────
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Preset selector ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Presets',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _PresetPill(label: 'Normal', sublabel: '1 day · deadline', selected: plan.preset == ReminderPreset.normal, onTap: () => _selectPreset(ReminderPreset.normal)),
                          const SizedBox(width: 8),
                          _PresetPill(label: 'Assignment', sublabel: '2d · 1d · 3h · 30m', selected: plan.preset == ReminderPreset.assignment, onTap: () => _selectPreset(ReminderPreset.assignment)),
                          const SizedBox(width: 8),
                          _PresetPill(label: 'Critical', sublabel: '3d · 2d · 1d · 3h', selected: plan.preset == ReminderPreset.critical, onTap: () => _selectPreset(ReminderPreset.critical)),
                          const SizedBox(width: 8),
                          _PresetPill(label: 'Custom', sublabel: 'Manual offsets', selected: plan.preset == ReminderPreset.custom, onTap: () => _selectPreset(ReminderPreset.custom)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _Divider(),

              // ── Active reminder chips ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Active Reminders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    if (_activeOffsets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'No reminders set. Add some below.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _activeOffsets.map((o) {
                          final fromPreset = ReminderPresets.forPreset(plan.preset).any(
                              (p) => p.days == o.days && p.hours == o.hours && p.minutes == o.minutes && p.atDeadline == o.atDeadline);
                          return _ActiveChip(
                            label: o.label,
                            fromPreset: fromPreset,
                            onRemove: () => _toggleOffset(o),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _Divider(),

              // ── Quick add chips ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add More', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._quickOffsets.map((o) {
                          final sel = _isSelected(o);
                          return _QuickChip(label: o.label, selected: sel, onTap: () => _toggleOffset(o));
                        }),
                        _QuickChip(
                          label: 'Custom...',
                          selected: false,
                          isSpecial: true,
                          onTap: () => _addCustom(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _Divider(),

              // ── Daily Reminder ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Daily Reminder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              SizedBox(height: 2),
                              Text('Fires every day at a fixed time', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Switch(
                          value: hasDailyReminder,
                          activeColor: AppColors.action,
                          inactiveTrackColor: AppColors.divider.withValues(alpha: 0.8),
                          inactiveThumbColor: AppColors.textSecondary,
                          onChanged: (val) {
                            if (val) {
                              _pickDailyTime(context);
                            } else {
                              onChanged(plan.copyWith(clearDailyReminder: true));
                            }
                          },
                        ),
                      ],
                    ),
                    if (hasDailyReminder) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pickDailyTime(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.action.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.action.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm_rounded, size: 18, color: AppColors.action),
                              const SizedBox(width: 10),
                              Text(
                                'Every day at ${_fmtTime(plan.dailyReminderMinutes!)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.action),
                              ),
                              const Spacer(),
                              const Text('Change', style: TextStyle(fontSize: 12, color: AppColors.action)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              _Divider(),

              // ── Constant reminder toggle ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Constant Reminder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Keeps pinging every 15 min until you complete the task',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: plan.constantReminder,
                      activeColor: AppColors.alert,
                      inactiveTrackColor: AppColors.divider.withValues(alpha: 0.8),
                      inactiveThumbColor: AppColors.textSecondary,
                      onChanged: (val) => onChanged(plan.copyWith(constantReminder: val)),
                    ),
                  ],
                ),
              ),

              _Divider(),

              // ── Flexible reminder toggle ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Flexible Reminder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Delays notifications until your current class finishes so you aren\'t disturbed',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: plan.flexibleReminder,
                      activeColor: AppColors.action,
                      inactiveTrackColor: AppColors.divider.withValues(alpha: 0.8),
                      inactiveThumbColor: AppColors.textSecondary,
                      onChanged: (val) => onChanged(plan.copyWith(flexibleReminder: val)),
                    ),
                  ],
                ),
              ),

              _Divider(),

              // ── Ring as Alarm toggle ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ring as Alarm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                            'Reminders will ring continuously at full volume until you dismiss them',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: plan.ringAsAlarm,
                      activeColor: AppColors.alert,
                      inactiveTrackColor: AppColors.divider.withValues(alpha: 0.8),
                      inactiveThumbColor: AppColors.textSecondary,
                      onChanged: (val) => onChanged(plan.copyWith(ringAsAlarm: val)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.divider.withValues(alpha: 0.4));
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.action : AppColors.background,
            border: selected ? null : Border.all(color: AppColors.divider, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: selected ? Colors.white.withValues(alpha: 0.7) : AppColors.textSecondary.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSpecial = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isSpecial;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.action.withValues(alpha: 0.12)
                : isSpecial
                    ? AppColors.decorNavy.withValues(alpha: 0.08)
                    : AppColors.background,
            border: Border.all(
              color: selected ? AppColors.action : isSpecial ? AppColors.decorNavy.withValues(alpha: 0.4) : AppColors.divider,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? AppColors.action : isSpecial ? AppColors.decorNavy : AppColors.textSecondary,
            ),
          ),
        ),
      );
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({
    required this.label,
    required this.fromPreset,
    required this.onRemove,
  });

  final String label;
  final bool fromPreset;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: fromPreset ? AppColors.attention.withValues(alpha: 0.1) : AppColors.action.withValues(alpha: 0.1),
          border: Border.all(
            color: fromPreset ? AppColors.attention.withValues(alpha: 0.4) : AppColors.action.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fromPreset ? AppColors.attention : AppColors.action),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close_rounded, size: 14, color: fromPreset ? AppColors.attention : AppColors.action),
            ),
          ],
        ),
      );
}

// ── Custom Reminder Sheet ─────────────────────────────────────────────────────

class _CustomReminderSheet extends StatefulWidget {
  final DateTime? dueAt;
  final VoidCallback? onSetDueDate;
  const _CustomReminderSheet({this.dueAt, this.onSetDueDate});

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
    final base = widget.dueAt ?? DateTime.now();
    _selectedAbsolute = base.subtract(const Duration(minutes: 15));
    if (_selectedAbsolute.isBefore(DateTime.now())) {
      _selectedAbsolute = DateTime.now().add(const Duration(hours: 1));
    }
  }

  ReminderOffset _buildOffset() {
    if (_isAbsolute && widget.dueAt != null) {
      final diff = widget.dueAt!.difference(_selectedAbsolute);
      if (diff.isNegative) return const ReminderOffset(days: 0, hours: 0, minutes: 0, atDeadline: true);
      return ReminderOffset(days: diff.inDays, hours: diff.inHours.remainder(24), minutes: diff.inMinutes.remainder(60));
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
    final exists = _added.any((a) => a.days == o.days && a.hours == o.hours && a.minutes == o.minutes && a.atDeadline == o.atDeadline);
    if (!exists) {
      setState(() {
        _added.add(o);
        // Reset relative for next input
        _days = 0; _hours = 0; _mins = 15;
      });
    }
  }

  void _removeAdded(int i) => setState(() => _added.removeAt(i));

  void _done() => Navigator.pop(context, List<ReminderOffset>.from(_added));

  @override
  Widget build(BuildContext context) {
    final canAdd = _isAbsolute ? widget.dueAt != null : (_days > 0 || _hours > 0 || _mins > 0);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
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
                child: Text('Add Reminder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5)),
              ),
              if (_added.isNotEmpty)
                TextButton(
                  onPressed: _done,
                  child: Text('Done (${_added.length})', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.action)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Mode toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _Tab(label: 'Relative', selected: !_isAbsolute, onTap: () => setState(() => _isAbsolute = false)),
                _Tab(label: 'Exact Date & Time', selected: _isAbsolute, onTap: () => setState(() => _isAbsolute = true)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Content
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isAbsolute ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: _buildRelativePicker(),
            secondChild: _buildAbsolutePicker(),
          ),

          const SizedBox(height: 20),

          // Accumulated list
          if (_added.isNotEmpty) ...[
            const Text('Will add:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_added.length, (i) => _AddedChip(
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
                    side: BorderSide(color: canAdd ? AppColors.action : AppColors.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('+ Add This', style: TextStyle(fontWeight: FontWeight.w600, color: canAdd ? AppColors.action : AppColors.textSecondary)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Save ${_added.length} Reminder${_added.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w600)),
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
        _Stepper(label: 'Days before', value: _days, min: 0, max: 30, onChanged: (v) => setState(() => _days = v)),
        const SizedBox(height: 12),
        _Stepper(label: 'Hours before', value: _hours, min: 0, max: 23, onChanged: (v) => setState(() => _hours = v)),
        const SizedBox(height: 12),
        _Stepper(label: 'Minutes before', value: _mins, min: 0, max: 55, step: 5, onChanged: (v) => setState(() => _mins = v)),
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
            border: Border.all(color: AppColors.attention.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.attention.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded, color: AppColors.attention, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No due date set', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    SizedBox(height: 2),
                    Text('Tap to set a due date first', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.attention),
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
              initialDate: _selectedAbsolute.isBefore(DateTime.now()) ? DateTime.now() : _selectedAbsolute,
              firstDate: DateTime.now(),
              lastDate: widget.dueAt!,
            );
            if (d != null) {
              setState(() => _selectedAbsolute = DateTime(d.year, d.month, d.day, _selectedAbsolute.hour, _selectedAbsolute.minute));
            }
          },
          child: _PickerRow(
            label: 'Date',
            value: '${_selectedAbsolute.day}/${_selectedAbsolute.month}/${_selectedAbsolute.year}',
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
              setState(() => _selectedAbsolute = DateTime(_selectedAbsolute.year, _selectedAbsolute.month, _selectedAbsolute.day, t.hour, t.minute));
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    child: child!,
  );
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.selected, required this.onTap});

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
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary),
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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.action)),
            const SizedBox(width: 4),
            GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 13, color: AppColors.action)),
          ],
        ),
      );
}

class _PickerRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PickerRow({required this.label, required this.value, required this.icon});

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
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.action)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
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

  const _Stepper({required this.label, required this.value, required this.min, required this.max, this.step = 1, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
            _StepBtn(icon: Icons.remove_rounded, onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null),
            SizedBox(
              width: 48,
              child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            _StepBtn(icon: Icons.add_rounded, onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null),
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
          color: active ? AppColors.action.withValues(alpha: 0.1) : AppColors.divider.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: active ? AppColors.action : AppColors.textSecondary.withValues(alpha: 0.4)),
      ),
    );
  }
}

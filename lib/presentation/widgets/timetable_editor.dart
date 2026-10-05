import 'dart:async';
import 'package:flutter/material.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/timetable_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/timetable_providers.dart';
import 'package:todow/presentation/providers/task_providers.dart';
import 'package:todow/core/theme/app_colors.dart';

Future<void> showTimetableEditor(
  BuildContext context, {
  TimetableEntry? entry,
  Weekday? initialWeekday,
  DateTime? initialDate,
  TimetableKind scheduleKind = TimetableKind.university,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TimetableEditorSheet(
      entry: entry,
      initialWeekday: initialWeekday,
      initialDate: initialDate,
      scheduleKind: scheduleKind,
    ),
  );
}

const List<Color> _kTimetableColors = [
  Color(0xFF1E3A8A), // deep navy
  Color(0xFF4F46E5), // indigo
  Color(0xFF0D9488), // teal
  Color(0xFFF59E0B), // amber
  Color(0xFFF472B6), // pink
  Color(0xFF059669), // emerald
  Color(0xFFFB7185), // coral-rose
  Color(0xFF7C3AED), // violet
  Color(0xFFEF4444), // red
];

class _TimetableEditorSheet extends ConsumerStatefulWidget {
  final TimetableEntry? entry;
  final Weekday? initialWeekday;
  final DateTime? initialDate;
  final TimetableKind scheduleKind;

  const _TimetableEditorSheet({
    this.entry,
    this.initialWeekday,
    this.initialDate,
    required this.scheduleKind,
  });

  @override
  ConsumerState<_TimetableEditorSheet> createState() => _TimetableEditorSheetState();
}

class _TimetableEditorSheetState extends ConsumerState<_TimetableEditorSheet> {
  late TextEditingController _course;
  late TextEditingController _instructor;
  late TextEditingController _room;
  late Weekday _weekday;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late DateTime _scheduledDate;
  late bool _repeatWeekly;
  String? _taskId;
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _course = TextEditingController(text: widget.entry?.courseName);
    _instructor = TextEditingController(text: widget.entry?.instructor);
    _room = TextEditingController(text: widget.entry?.room);
    _weekday = widget.entry?.weekday ??
        widget.initialWeekday ??
        Weekday.values[DateTime.now().weekday - 1];
    _start = widget.entry == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(widget.entry!.startTime);
    _end = widget.entry == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay.fromDateTime(widget.entry!.endTime);
    _scheduledDate =
        widget.entry?.scheduledDate ?? widget.initialDate ?? DateTime.now();
    _repeatWeekly =
        widget.entry?.repeatWeekly ?? widget.scheduleKind == TimetableKind.university;
    _taskId = widget.entry?.taskId;
    // ignore: deprecated_member_use
    _selectedColor = widget.entry?.colorValue ?? _kTimetableColors[0].value;
  }

  @override
  void dispose() {
    _course.dispose();
    _instructor.dispose();
    _room.dispose();
    super.dispose();
  }

  void _save() async {
    if (_course.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Please enter a name',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.textPrimary,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ));
      return;
    }
    final now = DateTime.now();
    final startTime = DateTime(
        now.year, now.month, now.day, _start.hour, _start.minute);
    final endTime =
        DateTime(now.year, now.month, now.day, _end.hour, _end.minute);
    final controller = ref.read(timetableProvider.notifier);

    try {
      if (widget.entry == null) {
        await controller.add(
          courseName: _course.text.trim(),
          instructor: _instructor.text.trim(),
          weekday: _weekday,
          scheduleKind: widget.scheduleKind,
          scheduledDate: widget.scheduleKind == TimetableKind.personal && !_repeatWeekly
              ? _scheduledDate
              : null,
          repeatWeekly: _repeatWeekly,
          taskId: _taskId,
          colorValue: _selectedColor,
          startTime: startTime,
          endTime: endTime,
          room: _room.text.trim(),
        );
      } else {
        await controller.updateEntry(TimetableEntry(
          id: widget.entry!.id,
          courseName: _course.text.trim(),
          instructor: _instructor.text.trim(),
          weekday: _weekday,
          scheduleKind: widget.entry!.scheduleKind,
          startTime: startTime,
          endTime: endTime,
          room: _room.text.trim().isEmpty ? null : _room.text.trim(),
          colorValue: _selectedColor,
          scheduledDate: widget.scheduleKind == TimetableKind.personal && !_repeatWeekly
              ? _scheduledDate
              : null,
          repeatWeekly: _repeatWeekly,
          taskId: _taskId,
          category: widget.entry!.category,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      debugPrint('[ERR-TT-01] Failed to save class: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
            "We couldn't save this class. Please check your inputs and try again.",
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.textPrimary,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUni = widget.scheduleKind == TimetableKind.university;
    final titleText = widget.entry == null
        ? (isUni ? 'Add Class' : 'Add Activity')
        : (isUni ? 'Edit Class' : 'Edit Activity');

    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: EdgeInsets.only(top: mq.padding.top + 40),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable Body
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, viewInsets + 100),
                  children: [
                    // Title Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _course,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: isUni ? 'Course name' : 'Activity name',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondaryOpacity(0.4)),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Color Selection
                    const Text('COLOR',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: Row(
                        children: _kTimetableColors.map((color) {
                          // ignore: deprecated_member_use
                          final isSelected = _selectedColor == color.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              // ignore: deprecated_member_use
                              onTap: () => setState(() => _selectedColor = color.value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(color: AppColors.textPrimary, width: 3)
                                      : null,
                                  boxShadow: isSelected
                                      ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))]
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Day & Time
                    const Text('WHEN',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 12),

                    // Day Selector
                    if (isUni || _repeatWeekly) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: Weekday.values.map((day) {
                            final isSelected = _weekday == day;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _weekday = day),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.textPrimary : AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: isSelected ? AppColors.textPrimary : AppColors.divider),
                                  ),
                                  child: Text(
                                    day.fullLabel.substring(0, 1),
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (!isUni) ...[
                      GestureDetector(
                        onTap: () => setState(() => _repeatWeekly = !_repeatWeekly),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _repeatWeekly ? AppColors.action : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _repeatWeekly ? AppColors.action : AppColors.divider),
                              ),
                              child: _repeatWeekly
                                  ? const Center(
                                      child: Text('✓',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12)))
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Text('Repeat every week',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_repeatWeekly) ...[
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _scheduledDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (date != null) {
                              setState(() {
                                _scheduledDate = date;
                                _weekday = WeekdayExt.fromDartWeekday(date.weekday);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Date',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondaryOpacity(0.8))),
                                Text(
                                  '${_scheduledDate.year}-${_scheduledDate.month.toString().padLeft(2, '0')}-${_scheduledDate.day.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Time Selectors
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final value = await showTimePicker(
                                  context: context, initialTime: _start);
                              if (value != null) setState(() => _start = value);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondaryOpacity(0.7))),
                                  const SizedBox(height: 4),
                                  Text(_start.format(context),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final value = await showTimePicker(
                                  context: context, initialTime: _end);
                              if (value != null) setState(() => _end = value);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('End',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondaryOpacity(0.7))),
                                  const SizedBox(height: 4),
                                  Text(_end.format(context),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Details
                    const Text('DETAILS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 12),

                    // Location Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: TextField(
                        controller: _room,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: isUni ? 'Location or Room' : 'Place (optional)',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondaryOpacity(0.6)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes / Instructor Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: TextField(
                        controller: _instructor,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: isUni ? 'Instructor' : 'Notes (optional)',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondaryOpacity(0.6)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Linked Task (Personal only)
                    if (!isUni) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _taskId,
                            isExpanded: true,
                            hint: Text('Link a task (optional)',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondaryOpacity(0.6))),
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('No linked task')),
                              ...(ref.read(tasksProvider).valueOrNull ?? []).map((task) =>
                                  DropdownMenuItem<String?>(
                                      value: task.id,
                                      child: Text(task.title,
                                          overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (value) => setState(() => _taskId = value),
                          ),
                        ),
                      ),
                    ],
              // Floating Save Button
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, viewInsets > 0 ? viewInsets + 16 : 24),
                        child: GestureDetector(
                          onTap: _save,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: Color(_selectedColor),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Color(_selectedColor).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.entry == null ? 'Create ${isUni ? 'class' : 'activity'}' : 'Save changes',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

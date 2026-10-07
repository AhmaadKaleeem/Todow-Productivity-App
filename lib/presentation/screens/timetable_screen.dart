import 'dart:async';
import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/core/utils/date_format.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/domain/models/timetable_entry.dart';
import 'package:todow/presentation/providers/timetable_providers.dart';
import 'package:todow/presentation/providers/task_providers.dart';

import 'package:todow/presentation/screens/timetable_import_screen.dart';
import 'package:todow/presentation/widgets/timetable_editor.dart';
import 'package:todow/presentation/widgets/timetable_semantics.dart';
import 'package:todow/presentation/widgets/beautiful_back_button.dart';

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

const Color _kUniversityFallback = Color(0xFF1E3A8A); // deep navy
const Color _kPersonalFallback = Color(0xFF059669); // emerald

Color getEntryColor(TimetableEntry entry) {
  if (entry.colorValue != null) return Color(entry.colorValue!);
  return _kTimetableColors[entry.id.hashCode.abs() % _kTimetableColors.length];
}

enum _TimetableView { week, day }

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> with WidgetsBindingObserver {
  late Weekday _selectedDay;
  late DateTime _selectedDate;
  TimetableKind _selectedKind = TimetableKind.university;
  _TimetableView _view = _TimetableView.day;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _selectedDay = WeekdayExt.fromDartWeekday(DateTime.now().weekday);
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_scheduleNextUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _scheduleNextUpdate();
  }

  void _scheduleNextUpdate() {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {});

    final now = DateTime.now();
    final entries = ref.read(timetableForDayProvider((day: _selectedDay, kind: _selectedKind)));
    
    if (_view == _TimetableView.day && entries.isNotEmpty && _selectedDate.year == now.year && _selectedDate.day == now.day) {
      final lastEntry = entries.last;
      final end = DateTime(now.year, now.month, now.day, lastEntry.endTime.hour, lastEntry.endTime.minute);
      if (now.isAfter(end)) {
        _shiftDay(1);
        return; 
      }
    }

    DateTime? nextWake;
    for (final e in entries) {
      final start = DateTime(now.year, now.month, now.day, e.startTime.hour, e.startTime.minute);
      if (now.isBefore(start) && (nextWake == null || start.isBefore(nextWake))) nextWake = start;
    }
    
    int delayMs = 3600000;
    final primary = _primaryIndex(entries, _selectedDay);
    if (primary != null && _isCurrent(entries[primary])) {
      delayMs = 60000 - (now.second * 1000 + now.millisecond);
    } else if (nextWake != null) {
      delayMs = nextWake.difference(now).inMilliseconds;
    }
    
    if (delayMs > 0) {
      _timer = Timer(Duration(milliseconds: delayMs), _scheduleNextUpdate);
    }
  }

  Future<void> _delete(
      TimetableNotifier controller, TimetableEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.scheduleKind == TimetableKind.personal
            ? 'Delete this activity?'
            : 'Delete this class?'),
        content: Text(
            '${entry.courseName} will be removed from ${entry.weekday.fullLabel} in your ${_scheduleName(entry.scheduleKind).toLowerCase()} timetable.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(entry.scheduleKind == TimetableKind.personal
                  ? 'Keep activity'
                  : 'Keep class')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await controller.delete(entry.id);
  }

  void _openImport() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TimetableImportScreen(scheduleKind: _selectedKind),
      ));

  Future<void> _edit(TimetableEntry entry) => showTimetableEditor(
        context,
        entry: entry,
        scheduleKind: entry.scheduleKind,
      );

  Future<void> _createTaskFromEntry(TimetableEntry entry) async {
    if (entry.taskId != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This timetable item is already linked to a task.')));
      return;
    }
    final date = entry.scheduledDate ?? DateTime.now();
    final dueAt = DateTime(date.year, date.month, date.day, entry.endTime.hour,
        entry.endTime.minute);
    final task = await ref.read(tasksProvider.notifier).createTask(
          title: entry.courseName,
          description: entry.instructor,
          dueAt: dueAt,
          category: entry.category ?? 'Personal timetable',
        );
    if (!mounted) return;
    await ref.read(timetableProvider.notifier).updateEntry(TimetableEntry(
          id: entry.id,
          courseName: entry.courseName,
          instructor: entry.instructor,
          weekday: entry.weekday,
          startTime: entry.startTime,
          endTime: entry.endTime,
          scheduleKind: entry.scheduleKind,
          room: entry.room,
          colorValue: entry.colorValue,
          category: entry.category,
          scheduledDate: entry.scheduledDate,
          repeatWeekly: entry.repeatWeekly,
          taskId: task.id,
        ));
  }

  int? _primaryIndex(List<TimetableEntry> entries, Weekday day) {
    final now = DateTime.now();
    if (day != WeekdayExt.fromDartWeekday(now.weekday) ||
        _selectedDate.year != now.year ||
        _selectedDate.month != now.month ||
        _selectedDate.day != now.day) {
      return null;
    }
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final start = DateTime(now.year, now.month, now.day, entry.startTime.hour,
          entry.startTime.minute);
      final end = DateTime(now.year, now.month, now.day, entry.endTime.hour,
          entry.endTime.minute);
      if (!now.isBefore(start) && now.isBefore(end)) return i;
      if (start.isAfter(now)) return i;
    }
    return null;
  }

  void _shiftDay(int amount) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: amount));
      _selectedDay = WeekdayExt.fromDartWeekday(_selectedDate.weekday);
      _scheduleNextUpdate();
    });
  }

  Future<void> _copyUniversityEntries() async {
    final controller = ref.read(timetableProvider.notifier);
    final source = ref.read(timetableEntriesForKindProvider(TimetableKind.university));
    if (source.isEmpty) {
      _showCopyFeedback(
        'Add university classes before copying them.',
        icon: Icons.info_outline_rounded,
        color: AppColors.attention,
      );
      return;
    }
    final personal = ref.read(timetableEntriesForKindProvider(TimetableKind.personal));
    var copied = 0;
    for (final entry in source) {
      if (personal.any((item) =>
          item.courseName == entry.courseName &&
          item.weekday == entry.weekday &&
          item.startTime.hour == entry.startTime.hour &&
          item.startTime.minute == entry.startTime.minute)) {
        continue;
      }
      await controller.add(
          courseName: entry.courseName,
          instructor: entry.instructor,
          weekday: entry.weekday,
          startTime: entry.startTime,
          endTime: entry.endTime,
          scheduleKind: TimetableKind.personal,
          room: entry.room);
      copied++;
    }
    if (mounted) {
      _showCopyFeedback(
        copied == 0
            ? 'University classes are already in Personal.'
            : '$copied ${copied == 1 ? 'class' : 'classes'} copied from University to Personal. You can edit them there.',
        icon: copied == 0
            ? Icons.check_circle_outline_rounded
            : Icons.copy_all_rounded,
        color: AppColors.action,
      );
    }
  }

  void _showCopyFeedback(
    String message, {
    required IconData icon,
    required Color color,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final today = WeekdayExt.fromDartWeekday(DateTime.now().weekday);
    final rawEntries = ref.watch(timetableForDayProvider((day: _selectedDay, kind: _selectedKind)));
    final entries = rawEntries
        .where((entry) =>
            entry.repeatWeekly ||
            (entry.scheduledDate!.year == _selectedDate.year &&
                entry.scheduledDate!.month == _selectedDate.month &&
                entry.scheduledDate!.day == _selectedDate.day))
        .toList();
    final primaryIndex = _primaryIndex(entries, _selectedDay);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leadingWidth: 86,
        leading: const Center(child: Padding(padding: EdgeInsets.only(left: 16), child: BeautifulBackButton())),
        title: const Text('Timetable'),
        actions: [
          IconButton(
              onPressed: _openImport,
              icon: const Icon(Icons.file_upload_outlined),
              tooltip: 'Import timetable'),
          IconButton(
              onPressed: () => showTimetableEditor(
                    context,
                    initialWeekday: _selectedDay,
                    initialDate: _selectedDate,
                    scheduleKind: _selectedKind,
                  ),
              icon: const Icon(Icons.add),
              tooltip: _selectedKind == TimetableKind.personal
                  ? 'Add activity'
                  : 'Add class'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          // Kind selector — University (navy) / Personal (violet)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TabButton(
                    label: 'University',
                    selected: _selectedKind == TimetableKind.university,
                    selectedColor: _kUniversityFallback,
                    onTap: () => setState(
                        () => _selectedKind = TimetableKind.university),
                  ),
                ),
                Expanded(
                  child: _TabButton(
                    label: 'Personal',
                    selected: _selectedKind == TimetableKind.personal,
                    selectedColor: _kPersonalFallback,
                    onTap: () =>
                        setState(() => _selectedKind = TimetableKind.personal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedKind == TimetableKind.university
                    ? 'University'
                    : 'Personal',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: _selectedKind == TimetableKind.university
                        ? _kUniversityFallback
                        : _kPersonalFallback),
              ),
              const SizedBox(height: 5),
              Text(
                _selectedKind == TimetableKind.university
                    ? 'Weekly repeating schedule'
                    : 'Your own schedule for classes, study, and activities',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              if (_selectedKind == TimetableKind.personal) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _copyUniversityEntries(),
                    icon: const Icon(Icons.content_copy_rounded, size: 16),
                    label: const Text('Copy university classes here'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPersonalFallback,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ViewModeButton(
                        label: 'Week',
                        selected: _view == _TimetableView.week,
                        onTap: () =>
                            setState(() => _view = _TimetableView.week),
                      ),
                    ),
                    Expanded(
                      child: _ViewModeButton(
                        label: 'Day',
                        selected: _view == _TimetableView.day,
                        onTap: () => setState(() => _view = _TimetableView.day),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() {
                _selectedDay = today;
                _selectedDate = DateTime.now();
                _view = _TimetableView.day;
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          if (_view == _TimetableView.day) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                IconButton(
                    onPressed: () => _shiftDay(-1),
                    tooltip: 'Previous day',
                    icon: const Icon(Icons.chevron_left_rounded,
                        color: AppColors.textSecondary)),
                Expanded(
                    child: Center(
                        child: Text(
                            _selectedKind == TimetableKind.personal
                                ? '${_selectedDay.fullLabel} · ${_selectedDate.month}/${_selectedDate.day}'
                                : _selectedDay.fullLabel,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: AppColors.textPrimary)))),
                IconButton(
                    onPressed: () => _shiftDay(1),
                    tooltip: 'Next day',
                    icon: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              _EmptyDay(
                isToday: _selectedDay == today,
                onAdd: () => showTimetableEditor(
                  context,
                  initialWeekday: _selectedDay,
                  initialDate: _selectedDate,
                  scheduleKind: _selectedKind,
                ),
              )
            else
              ...entries.indexed.map((item) => _ClassCard(
                    entry: item.$2,
                    emphasis:
                        item.$1 == primaryIndex ? _currentState(item.$2) : null,
                    isPast: _isPast(item.$2, _selectedDate),
                    onEdit: () => _edit(item.$2),
                    onDelete: () => _delete(ref.read(timetableProvider.notifier), item.$2),
                    onCreateTask: () => _createTaskFromEntry(item.$2),
                  )),
          ] else ...[
            for (final day in Weekday.values)
              _WeekdaySection(
                day: day,
                entries: _entriesForWeekday(day),
                isPastList: _entriesForWeekday(day).map((e) => _isPast(e, DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).subtract(Duration(days: _selectedDate.weekday - 1)).add(Duration(days: day.index)))).toList(),
                primaryIndex:
                    _primaryIndex(_entriesForWeekday(day), day),
                onOpenDay: () => setState(() {
                  _selectedDay = day;
                  final offset = day.index - _selectedDay.index;
                  _selectedDate = _selectedDate.add(Duration(days: offset));
                  _selectedDay = day;
                  _view = _TimetableView.day;
                }),
              ),
          ],
        ],
      ),
    );
  }

  String? _currentState(TimetableEntry entry) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, entry.startTime.hour,
        entry.startTime.minute);
    final end = DateTime(
        now.year, now.month, now.day, entry.endTime.hour, entry.endTime.minute);
    return !now.isBefore(start) && now.isBefore(end) ? 'NOW' : 'NEXT';
  }

  bool _isCurrent(TimetableEntry entry) {
    final now = DateTime.now();
    if (_selectedDate.year != now.year || _selectedDate.month != now.month || _selectedDate.day != now.day) return false;
    final start = DateTime(now.year, now.month, now.day, entry.startTime.hour, entry.startTime.minute);
    final end = DateTime(now.year, now.month, now.day, entry.endTime.hour, entry.endTime.minute);
    return !now.isBefore(start) && now.isBefore(end);
  }

  bool _isPast(TimetableEntry entry, DateTime dateOfEntry) {
    final now = DateTime.now();
    if (dateOfEntry.year != now.year || dateOfEntry.month != now.month || dateOfEntry.day != now.day) return false;
    final end = DateTime(now.year, now.month, now.day, entry.endTime.hour, entry.endTime.minute);
    return now.isAfter(end);
  }

  List<TimetableEntry> _entriesForWeekday(Weekday day) {
    final weekStart =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
            .subtract(Duration(days: _selectedDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    return ref.watch(timetableForDayProvider((day: day, kind: _selectedKind))).where((entry) {
      final date = entry.scheduledDate;
      return entry.repeatWeekly ||
          (date != null && !date.isBefore(weekStart) && date.isBefore(weekEnd));
    }).toList();
  }
}

String _scheduleName(TimetableKind kind) =>
    kind == TimetableKind.university ? 'University' : 'Personal';

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  const _ViewModeButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 36,
        decoration: BoxDecoration(
          color: selected ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _WeekdaySection extends StatelessWidget {
  const _WeekdaySection({
    required this.day,
    required this.entries,
    required this.primaryIndex,
    required this.onOpenDay,
    required this.isPastList,
  });

  final Weekday day;
  final List<TimetableEntry> entries;
  final int? primaryIndex;
  final VoidCallback onOpenDay;
  final List<bool> isPastList;

  @override
  Widget build(BuildContext context) {
    final isToday = day == WeekdayExt.fromDartWeekday(DateTime.now().weekday);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isToday)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0EA5E9),
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      day.fullLabel,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isToday
                              ? const Color(0xFF0EA5E9)
                              : AppColors.textPrimary),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: onOpenDay,
                  child: Text(
                    '${entries.length} ${entries.length == 1 ? 'class' : 'classes'} →',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryOpacity(0.75)),
                  ),
                ),
              ],
            ),
          ),
          if (entries.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    InkWell(
                      onTap: onOpenDay,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 68,
                              child: Text(
                                  AppDateFormat.time(entries[i].startTime),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: i == primaryIndex
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      decoration: isPastList[i] ? TextDecoration.lineThrough : null,
                                      color: isPastList[i] ? AppColors.textSecondaryOpacity(0.5) : AppColors.textPrimary)),
                            ),
                            Container(
                              width: 4,
                              height: 28,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    getEntryColor(entries[i]),
                                    getEntryColor(entries[i])
                                        .withValues(alpha: 0.25),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entries[i].courseName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: i == primaryIndex
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          decoration: isPastList[i] ? TextDecoration.lineThrough : null,
                                          color: isPastList[i] ? AppColors.textSecondaryOpacity(0.5) : AppColors.textPrimary)),
                                  Text(
                                      timetableTypeLabel(entries[i].category,
                                          entries[i].scheduleKind),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  if (entries[i].room?.trim().isNotEmpty ==
                                      true)
                                    Text(entries[i].room!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                AppColors.textSecondaryOpacity(
                                                    0.7))),
                                ],
                              ),
                            ),
                            if (i == primaryIndex)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: timetableTypeColor(entries[i].category,
                                          entries[i].scheduleKind)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _isCurrent(entries[i]) ? 'NOW' : 'NEXT',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.textPrimary),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('No classes scheduled',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryOpacity(0.7))),
            ),
        ],
      ),
    );
  }

  bool _isCurrent(TimetableEntry entry) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, entry.startTime.hour,
        entry.startTime.minute);
    final end = DateTime(
        now.year, now.month, now.day, entry.endTime.hour, entry.endTime.minute);
    return !now.isBefore(start) && now.isBefore(end);
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard(
      {required this.entry,
      required this.emphasis,
      required this.onEdit,
      required this.onDelete,
      required this.onCreateTask,
      this.isPast = false});

  final TimetableEntry entry;
  final String? emphasis;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCreateTask;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final accentColor = getEntryColor(entry);
    final isPrimary = emphasis != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 68,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppDateFormat.time(entry.startTime),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                        color: isPast ? AppColors.textSecondaryOpacity(0.5) : accentColor)),
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(AppDateFormat.time(entry.endTime),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                // Richer tint so each category reads as distinctly colored
                color: accentColor.withValues(alpha: isPrimary ? 0.13 : 0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withValues(alpha: isPrimary ? 0.35 : 0.22),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: null, // card is read-only; use ⋮ menu to edit
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(entry.courseName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                            decoration: isPast ? TextDecoration.lineThrough : null,
                                            color: isPast ? AppColors.textSecondaryOpacity(0.5) : AppColors.textPrimary)),
                                  ),
                                  if (emphasis == 'NOW')
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.decorNavy,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text('NOW',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                              color: Colors.white)),
                                    )
                                  else if (emphasis == 'NEXT')
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            accentColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('NEXT',
                                          style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.6,
                                              color: AppColors.textPrimary)),
                                    ),
                                ],
                              ),
                              if (entry.instructor.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(entry.instructor,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary)),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (entry.room?.trim().isNotEmpty == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppColors.divider),
                                      ),
                                      child: Text(
                                        entry.room!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  if (entry.category != null &&
                                      entry.category!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            accentColor.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        entry.category!,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: accentColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Class actions',
                          icon: Icon(Icons.more_vert_rounded,
                              size: 20,
                              color: AppColors.textSecondaryOpacity(0.7)),
                          onSelected: (action) {
                            if (action == 'edit') onEdit();
                            if (action == 'delete') onDelete();
                            if (action == 'task') onCreateTask();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                                value: 'edit',
                                child: Text(
                                    entry.scheduleKind == TimetableKind.personal
                                        ? 'Edit activity'
                                        : 'Edit class')),
                            if (entry.scheduleKind == TimetableKind.personal)
                              PopupMenuItem(
                                  value: 'task',
                                  enabled: entry.taskId == null,
                                  child: Text(entry.taskId == null
                                      ? 'Create task from activity'
                                      : 'Linked to task')),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                    entry.scheduleKind == TimetableKind.personal
                                        ? 'Delete activity'
                                        : 'Delete class',
                                    style: const TextStyle(
                                        color: AppColors.alert))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.isToday, required this.onAdd});

  final bool isToday;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            Text(isToday ? "You're all clear today" : "Nothing scheduled",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(
                isToday
                    ? 'Take a break or schedule something.'
                    : 'Add a class or personal activity.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondaryOpacity(0.8))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Add item',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/roadmap.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/presentation/features/roadmaps/roadmap_providers.dart';
import 'package:todow/presentation/features/tasks/task_editor_screen.dart';

enum TimeFilter { today, thisWeek, upcoming, all, custom }



class _CustomDateSelection {
  const _CustomDateSelection({this.range, this.dates = const {}});

  final DateTimeRange? range;
  final Set<DateTime> dates;
}

class TaskTimeView extends ConsumerStatefulWidget {
  const TaskTimeView(
      {required this.roadmapId, required this.topics, super.key});
  final String roadmapId;
  final List<Topic> topics;

  @override
  ConsumerState<TaskTimeView> createState() => _TaskTimeViewState();
}

class _TaskTimeViewState extends ConsumerState<TaskTimeView> {
  TimeFilter _filter = TimeFilter.all;
  List<Task> _tasks = [];
  bool _loading = true;
  DateTimeRange? _customRange;
  Set<DateTime> _customDates = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    final ctrl = ref.read(roadmapsProvider.notifier);

    DateTime? from;
    DateTime? to;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filter) {
      case TimeFilter.today:
        from = today;
        to = today.add(const Duration(days: 1, microseconds: -1));
      case TimeFilter.thisWeek:
        from = today;
        to = today.add(const Duration(days: 7, microseconds: -1));
      case TimeFilter.upcoming:
        from = today.add(const Duration(days: 7));
      case TimeFilter.all:
        break;
      case TimeFilter.custom:
        from = _customRange?.start;
        to = _customRange?.end
            .add(const Duration(days: 1))
            .subtract(const Duration(microseconds: 1));
    }

    var tasks =
        await ctrl.getTasksByRoadmap(widget.roadmapId, from: from, to: to);
    if (_filter == TimeFilter.custom && _customRange == null) {
      tasks = tasks.where((task) {
        final dueAt = task.dueAt;
        return dueAt != null &&
            _customDates.contains(DateUtils.dateOnly(dueAt));
      }).toList();
    }
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  void _setFilter(TimeFilter f) {
    if (f == TimeFilter.custom) {
      _chooseCustomDates();
      return;
    }
    if (_filter == f) return;
    setState(() => _filter = f);
    _loadTasks();
  }

  Future<void> _chooseCustomDates() async {
    final selection = await showModalBottomSheet<_CustomDateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomDatesSheet(
        initialRange: _customRange,
        initialDates: _customDates,
      ),
    );
    if (selection == null ||
        (selection.range == null && selection.dates.isEmpty)) {
      return;
    }
    setState(() {
      _customRange = selection.range;
      _customDates = selection.dates;
      _filter = TimeFilter.custom;
    });
    await _loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _FilterPill(
                  label: 'TODAY',
                  selected: _filter == TimeFilter.today,
                  onTap: () => _setFilter(TimeFilter.today)),
              _FilterPill(
                  label: 'THIS WEEK',
                  selected: _filter == TimeFilter.thisWeek,
                  onTap: () => _setFilter(TimeFilter.thisWeek)),
              _FilterPill(
                  label: 'UPCOMING',
                  selected: _filter == TimeFilter.upcoming,
                  onTap: () => _setFilter(TimeFilter.upcoming)),
              _FilterPill(
                  label: 'ALL',
                  selected: _filter == TimeFilter.all,
                  onTap: () => _setFilter(TimeFilter.all)),
              _FilterPill(
                label: _filter == TimeFilter.custom ? 'CUSTOM DATES' : 'CUSTOM',
                selected: _filter == TimeFilter.custom,
                onTap: _chooseCustomDates,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: AppColors.action)))
        else if (_tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40.0),
            child: Text('No scheduled tasks for this period.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _TopicTaskGroups(
              key: ValueKey(_filter),
              tasks: _tasks,
              topics: widget.topics,
              onTaskTap: (task) async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TaskEditorScreen(task: task)));
                _loadTasks();
              },
            ),
          ),
      ],
    );
  }
}

class _CustomDatesSheet extends StatefulWidget {
  const _CustomDatesSheet({
    required this.initialRange,
    required this.initialDates,
  });

  final DateTimeRange? initialRange;
  final Set<DateTime> initialDates;

  @override
  State<_CustomDatesSheet> createState() => _CustomDatesSheetState();
}

class _CustomDatesSheetState extends State<_CustomDatesSheet> {
  late bool _rangeMode;
  late DateTimeRange? _range;
  late Set<DateTime> _dates;
  DateTime _month = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _rangeMode = widget.initialRange != null || widget.initialDates.isEmpty;
    _range = widget.initialRange;
    _dates = {...widget.initialDates};
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: 'Choose a date range',
    );
    if (range != null) setState(() => _range = range);
  }

  void _save() {
    if (_rangeMode && _range == null || !_rangeMode && _dates.isEmpty) return;
    Navigator.pop(
      context,
      _CustomDateSelection(
        range: _rangeMode ? _range : null,
        dates: _rangeMode ? const {} : _dates,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final cellCount = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;
    final canSave = _rangeMode ? _range != null : _dates.isNotEmpty;

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Choose dates',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FilterPill(
                      label: 'DATE RANGE',
                      selected: _rangeMode,
                      onTap: () => setState(() => _rangeMode = true),
                    ),
                  ),
                  Expanded(
                    child: _FilterPill(
                      label: 'INDIVIDUAL DAYS',
                      selected: !_rangeMode,
                      onTap: () => setState(() => _rangeMode = false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_rangeMode)
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(_range == null
                      ? 'Select a start and end date'
                      : '${_dateLabel(_range!.start)} – ${_dateLabel(_range!.end)}'),
                )
              else ...[
                Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        '${_month.year}-${_month.month.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() =>
                          _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (final day in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                      Expanded(
                        child: Center(
                          child: Text(day,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cellCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7, mainAxisExtent: 42),
                  itemBuilder: (context, index) {
                    final day = index - firstWeekday + 1;
                    if (day < 1 || day > daysInMonth) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(_month.year, _month.month, day);
                    final selected = _dates.contains(date);
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: selected ? AppColors.action : Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => setState(() => selected
                              ? _dates.remove(date)
                              : _dates.add(date)),
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: Text('$day',
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (_dates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      for (final date in (_dates.toList()..sort()))
                        InputChip(
                          label: Text(_dateLabel(date)),
                          onDeleted: () => setState(() => _dates.remove(date)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: canSave ? _save : null,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.action,
                    foregroundColor: Colors.white),
                child: const Text('Show tasks'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _TopicTaskGroups extends StatelessWidget {
  const _TopicTaskGroups(
      {required super.key,
      required this.tasks,
      required this.topics,
      required this.onTaskTap});

  final List<Task> tasks;
  final List<Topic> topics;
  final ValueChanged<Task> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final grouped = {for (final topic in topics) topic.id: <Task>[]};
    final topicTitles = {for (final topic in topics) topic.id: topic.title};
    for (final task in tasks) {
      grouped.putIfAbsent(task.topicId ?? '', () => []).add(task);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry
              in grouped.entries.where((entry) => entry.value.isNotEmpty)) ...[
            Text(
              topicTitles[entry.key] ?? 'UNASSIGNED',
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            for (final task in entry.value) ...[
              _TimeTaskRow(task: task, onTap: () => onTaskTap(task)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TimeTaskRow extends StatelessWidget {
  const _TimeTaskRow({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: task.isCompleted
                      ? AppColors.action
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
}

class _FilterPill extends StatelessWidget {
  const _FilterPill(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.textPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        selected ? AppColors.textPrimary : AppColors.divider),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: selected ? AppColors.surface : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

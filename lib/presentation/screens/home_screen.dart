import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/core/utils/date_format.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/timetable_entry.dart';
import 'package:todow/presentation/providers/roadmap_providers.dart';
import 'package:todow/presentation/controllers/task_controller.dart';
import 'package:todow/presentation/screens/roadmap_list_screen.dart';
import 'package:todow/presentation/screens/task_editor_screen.dart';
import 'package:todow/presentation/screens/timetable_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/app_providers.dart';
import 'package:todow/presentation/providers/task_providers.dart';
import 'package:todow/presentation/providers/timetable_providers.dart';
import 'package:todow/presentation/widgets/corner_arc_decor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todow/domain/models/query.dart';
import 'package:todow/domain/date_labels.dart';
import 'package:todow/presentation/screens/app_shell.dart';

const _softShadow =
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2));

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _insertingBelowId;
  Map<String, int> _attachmentCounts = {};
  bool _isFilterExpanded = false;
  final _searchCtrl = TextEditingController();
  String? _username;
  int _taskLimit = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tc = context.read<TaskController>();
      await tc.loadTasks();
      final ids = tc.tasks.map((t) => t.id).toList();
      final counts = await tc.attachmentCounts(ids);
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _attachmentCounts = counts;
          _username = prefs.getString('username');
        });
        ref.read(notificationPermissionsProvider.notifier).requestPermissions();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool filterIsActive(TaskFilter f) =>
      f.status != TaskStatusFilter.open ||
      f.priorities.isNotEmpty ||
      f.due.isNotEmpty;

  Widget _sectionHeading(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.textSecondary)),
      );

  Widget _todayWork(TaskController controller) {
    final tasks = controller.todayTasks
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    final visible = tasks.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading("TODAY'S WORK"),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.decorPink.withValues(alpha: 0.28)),
              boxShadow: const [_softShadow]),
          child: tasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Nothing due today',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _TodayTaskRow(
                        task: visible[i],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  TaskEditorScreen(task: visible[i])),
                        ),
                        onComplete: () =>
                            controller.completeTask(visible[i].id),
                      ),
                      if (i < visible.length - 1)
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    if (tasks.length > visible.length) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () =>
                              AppShellScope.of(context).selectPage(1),
                          child: Text('View all ${tasks.length} tasks  →'),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _todayClasses() {
    final now = DateTime.now();
    final weekday = WeekdayExt.fromDartWeekday(now.weekday);
    final filter = (day: weekday, kind: TimetableKind.university);
    final classes = ref.watch(timetableForDayProvider(filter));
    
    var highlighted = -1;
    for (var i = 0; i < classes.length; i++) {
      final entry = classes[i];
      final start = DateTime(now.year, now.month, now.day, entry.startTime.hour,
          entry.startTime.minute);
      final end = DateTime(now.year, now.month, now.day, entry.endTime.hour,
          entry.endTime.minute);
      if (!now.isBefore(start) && now.isBefore(end)) {
        highlighted = i;
        break;
      }
      if (highlighted == -1 && start.isAfter(now)) highlighted = i;
    }

    void openTimetable() => AppShellScope.of(context).selectPage(3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading("TODAY'S CLASSES"),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.divider),
              boxShadow: const [_softShadow]),
          child: classes.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(children: [
                    const Expanded(
                        child: Text('No classes today',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary))),
                    TextButton(
                        onPressed: openTimetable,
                        child: const Text('View timetable  →')),
                  ]),
                )
              : Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: classes.length,
                      itemBuilder: (context, index) => _TodayClassRow(
                        entry: classes[index],
                        primary: index == highlighted,
                        // onTap removed
                        // entry removed
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                          onPressed: openTimetable,
                          child: const Text('View timetable  →')),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  String sortLabel(TaskSort s) {
    switch (s) {
      case TaskSort.manual:
        return 'Manual Order';
      case TaskSort.dueDateAsc:
        return 'Due Date (Earliest)';
      case TaskSort.dueDateDesc:
        return 'Due Date (Latest)';
      case TaskSort.priorityDesc:
        return 'Priority';
      case TaskSort.createdDesc:
        return 'Newest First';
      case TaskSort.titleAsc:
        return 'Title (A–Z)';
    }
  }

  void _showSortSheet(BuildContext context, TaskController tc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Text('Sort by',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 4),
                ...TaskSort.values.where((s) => s != TaskSort.manual).map((s) {
                  final selected = tc.sort == s;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(sortLabel(s),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.action
                                : AppColors.textPrimary)),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.action, size: 18)
                        : null,
                    onTap: () {
                      tc.setSort(s);
                      Navigator.pop(context);
                    },
                  );
                }),
                if (tc.sort != TaskSort.manual) ...[
                  const Divider(indent: 24, endIndent: 24, height: 24),
                  GestureDetector(
                    onTap: () {
                      tc.setSort(TaskSort.manual);
                      Navigator.pop(context);
                    },
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text('Clear sort',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary)),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskListItem(
      TaskController tc, List<Task> active, int i, bool isReorderable) {
    final taskRow = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaskRow(
                task: active[i],
                controller: tc,
                index: i,
                attachmentCount: _attachmentCounts[active[i].id] ?? 0,
                isFirst: i == 0,
                isLast: i == active.length - 1 && _insertingBelowId != active[i].id,
                onInsertRequested: () {
                  setState(() => _insertingBelowId = active[i].id);
                })
            .animate(delay: Duration(milliseconds: 460 + i * 55))
            .fadeIn(duration: 280.ms)
            .slideY(begin: 0.12, curve: Curves.easeOutCubic),
        if (_insertingBelowId == active[i].id)
          _InlineInsertField(
            aboveId: active[i].id,
            controller: tc,
            onDismissed: () => setState(() => _insertingBelowId = null),
            isLast: i == active.length - 1,
          ),
      ],
    );

    return GestureDetector(
      key: ValueKey(active[i].id),
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () {
        setState(() => _insertingBelowId = active[i].id);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: isReorderable
            ? ReorderableDelayedDragStartListener(
                index: i,
                child: taskRow,
              )
            : taskRow,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tasksProvider, (prev, next) {
      if (next.hasValue) {
        context.read<TaskController>().syncTasks(next.value!);
      }
    });
    final tc = context.watch<TaskController>();
    final allActive =
        tc.visibleTasks.where((t) => t.status == TaskStatus.active).toList();
    final active = allActive.take(_taskLimit).toList();
    final allCompleted = applyQuery(
        tc.tasks,
        SearchQuery(
            text: tc.query,
            filter: tc.filter.copyWith(status: TaskStatusFilter.completed),
            sort: tc.sort));
    final done = allCompleted;

    final roadmapCount = ref.watch(roadmapsProvider).valueOrNull?.length ?? 0;
    final featuredCategories = _featuredCategorySummaries(
      tc.tasks.where((task) => task.topicId == null),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const CornerArcDecor(corner: Alignment.topRight, scale: 1.2),
          SafeArea(
            bottom: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: () {
                if (active.isNotEmpty) {
                  setState(() => _insertingBelowId = active.last.id);
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TaskEditorScreen()));
                }
              },
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              () {
                                final hour = DateTime.now().hour;
                                final greeting = hour < 12
                                    ? 'Good morning'
                                    : hour < 17
                                        ? 'Good afternoon'
                                        : 'Good evening';
                                return (_username != null &&
                                        _username!.isNotEmpty)
                                    ? '$greeting,\n$_username'
                                    : 'Your\nProjects ($roadmapCount)';
                              }(),
                              style: const TextStyle(
                                  fontSize: 34,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -1),
                            ).animate().fadeIn().slideY(begin: 0.2),
                          ),
                          GestureDetector(
                            onTap: () =>
                                AppShellScope.of(context).toggleDrawer(),
                            behavior: HitTestBehavior.opaque,
                            child: const Padding(
                              padding: EdgeInsets.only(top: 6, left: 12),
                              child: Icon(Icons.menu_rounded,
                                  size: 26, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _HeroCard(
                        roadmapCount: roadmapCount,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const RoadmapListScreen()),
                        ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.08),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: featuredCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          const secondaryGradients = [
                            LinearGradient(
                                colors: [AppColors.action, Color(0xFF0284C7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            LinearGradient(
                                colors: [
                                  AppColors.decorPink,
                                  AppColors.decorCoral
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            LinearGradient(
                                colors: [
                                  AppColors.attention,
                                  AppColors.decorCoral
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                          ];
                          final category = featuredCategories[i];
                          final normalizedTitle = category.title.toLowerCase();
                          final gradientIndex = switch (normalizedTitle) {
                            'personal notes' || 'personal' => 0,
                            'study' => 1,
                            'daily tasks' => 2,
                            _ => i % secondaryGradients.length,
                          };
                          return _SecondaryCard(
                            category: category,
                            gradient: secondaryGradients[gradientIndex],
                          )
                              .animate()
                              .fadeIn(
                                  delay: Duration(milliseconds: 250 + i * 80))
                              .slideX(begin: 0.06, curve: Curves.easeOutExpo);
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(child: _todayWork(tc)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(child: _todayClasses()),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.search,
                                size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: tc.setQuery,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Search tasks...',
                                  hintStyle: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color:
                                          AppColors.textSecondaryOpacity(0.6)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (tc.query.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  tc.clearQuery();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.close,
                                      size: 18, color: AppColors.textSecondary),
                                ),
                              ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 8, 12),
                      child: Row(
                        children: [
                          const Expanded(
                              child: Text('ALL TASKS',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: AppColors.textSecondary))),
                          IconButton(
                            icon: Icon(Icons.filter_list,
                                size: 20,
                                color: _isFilterExpanded ||
                                        filterIsActive(tc.filter)
                                    ? AppColors.action
                                    : AppColors.textSecondary),
                            onPressed: () => setState(
                                () => _isFilterExpanded = !_isFilterExpanded),
                          ),
                          IconButton(
                            icon: Icon(Icons.sort,
                                size: 20,
                                color: tc.sort != TaskSort.manual
                                    ? AppColors.action
                                    : AppColors.textSecondary),
                            onPressed: () => _showSortSheet(context, tc),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms),
                  ),
                  if (_isFilterExpanded)
                    SliverToBoxAdapter(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 50,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          children: [
                            _FilterChip(
                              label: 'Open',
                              selected:
                                  tc.filter.status == TaskStatusFilter.open,
                              onTap: () => tc.setFilter(tc.filter.copyWith(
                                  status:
                                      tc.filter.status == TaskStatusFilter.open
                                          ? TaskStatusFilter.all
                                          : TaskStatusFilter.open)),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Completed',
                              selected: tc.filter.status ==
                                  TaskStatusFilter.completed,
                              onTap: () => tc.setFilter(tc.filter.copyWith(
                                  status: tc.filter.status ==
                                          TaskStatusFilter.completed
                                      ? TaskStatusFilter.all
                                      : TaskStatusFilter.completed)),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'High Priority',
                              selected: tc.filter.priorities
                                  .contains(TaskPriority.high),
                              onTap: () {
                                final p = Set.of(tc.filter.priorities);
                                p.contains(TaskPriority.high)
                                    ? p.remove(TaskPriority.high)
                                    : p.add(TaskPriority.high);
                                tc.setFilter(tc.filter.copyWith(priorities: p));
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Overdue',
                              selected:
                                  tc.filter.due.contains(DueFilter.overdue),
                              onTap: () {
                                final d = Set.of(tc.filter.due);
                                d.contains(DueFilter.overdue)
                                    ? d.remove(DueFilter.overdue)
                                    : d.add(DueFilter.overdue);
                                tc.setFilter(tc.filter.copyWith(due: d));
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Today',
                              selected: tc.filter.due.contains(DueFilter.today),
                              onTap: () {
                                final d = Set.of(tc.filter.due);
                                d.contains(DueFilter.today)
                                    ? d.remove(DueFilter.today)
                                    : d.add(DueFilter.today);
                                tc.setFilter(tc.filter.copyWith(due: d));
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'This Week',
                              selected:
                                  tc.filter.due.contains(DueFilter.thisWeek),
                              onTap: () {
                                final d = Set.of(tc.filter.due);
                                d.contains(DueFilter.thisWeek)
                                    ? d.remove(DueFilter.thisWeek)
                                    : d.add(DueFilter.thisWeek);
                                tc.setFilter(tc.filter.copyWith(due: d));
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'No Date',
                              selected:
                                  tc.filter.due.contains(DueFilter.noDate),
                              onTap: () {
                                final d = Set.of(tc.filter.due);
                                d.contains(DueFilter.noDate)
                                    ? d.remove(DueFilter.noDate)
                                    : d.add(DueFilter.noDate);
                                tc.setFilter(tc.filter.copyWith(due: d));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_isFilterExpanded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.all(8)),
                              onPressed: () {
                                tc.setFilter(TaskFilter.empty());
                              },
                              child: const Text('Clear filters',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.action)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (tc.loading)
                    const SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.action, strokeWidth: 2)))),
                  if (!tc.loading &&
                      active.isEmpty &&
                      (tc.query.isNotEmpty || filterIsActive(tc.filter)))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            const Text('No tasks match',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: tc.clearQuery,
                              child: const Text('Clear all filters',
                                  style: TextStyle(color: AppColors.action)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!tc.loading && active.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 4),
                        child: _EmptyTasksHint(
                                onAdd: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const TaskEditorScreen())))
                            .animate()
                            .fadeIn(delay: 350.ms, duration: 400.ms)
                            .scale(
                                begin: const Offset(0.92, 0.92),
                                curve: Curves.easeOutBack),
                      ),
                    ),
                  if (!tc.loading && active.isNotEmpty)
                    if (tc.sort != TaskSort.manual)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: Text(
                              'Sorted by ${sortLabel(tc.sort)}. Drag is disabled.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryOpacity(0.7))),
                        ),
                      ),
                  if (!tc.loading && active.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: tc.sort == TaskSort.manual
                          ? SliverReorderableList(
                              itemCount: active.length,
                              onReorder: tc.reorderTask,
                              proxyDecorator: (child, index, animation) =>
                                  Material(
                                      color: Colors.transparent,
                                      elevation: 0,
                                      child: child),
                              itemBuilder: (_, i) =>
                                  _buildTaskListItem(tc, active, i, true),
                            )
                          : SliverList.builder(
                              itemCount: active.length,
                              itemBuilder: (_, i) =>
                                  _buildTaskListItem(tc, active, i, false),
                            ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: _QuickAdd(controller: tc)
                          .animate()
                          .fadeIn(delay: 750.ms)
                          .slideY(begin: 0.3, curve: Curves.easeOutBack),
                    ),
                  ),
                  if (!tc.loading && allActive.length > _taskLimit)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _taskLimit += 10;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Load 10 more tasks', style: TextStyle(color: AppColors.action)),
                        ),
                      ),
                    ),
                  if (!tc.loading && done.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            tilePadding: EdgeInsets.zero,
                            title: Text('Completed (${done.length})',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary)),
                            iconColor: AppColors.textSecondary,
                            collapsedIconColor:
                                AppColors.textSecondaryOpacity(0.5),
                            children: [
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  for (int i = 0; i < done.length; i++)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Opacity(
                                        opacity: 0.65,
                                        child: _TaskRow(
                                            task: done[i],
                                            controller: tc,
                                            index: -1,
                                            attachmentCount:
                                                _attachmentCounts[done[i].id] ??
                                                    0,
                                            isFirst: i == 0,
                                            isLast: i == done.length - 1),
                                      ),
                                    ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [_softShadow],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _NavIcon(Icons.grid_view_rounded, true),
                      const SizedBox(width: 28),
                      const _NavIcon(Icons.check_circle_outline_rounded, false),
                      const SizedBox(width: 28),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const TaskEditorScreen())),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                              color: AppColors.action, shape: BoxShape.circle),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ),
                      const SizedBox(width: 28),
                      const _NavIcon(Icons.calendar_today_outlined, false),
                      const SizedBox(width: 28),
                      const _NavIcon(Icons.person_outline_rounded, false),
                    ],
                  ),
                ).animate().slideY(
                    begin: 1.5,
                    curve: Curves.easeOutBack,
                    duration: 800.ms,
                    delay: 500.ms),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────── HERO CARD ────────────────────────────────

class _HeroCard extends StatefulWidget {
  final int roadmapCount;
  final VoidCallback onTap;
  const _HeroCard({required this.roadmapCount, required this.onTap});
  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutExpo,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [_softShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Roadmaps',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Roadmap',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${widget.roadmapCount} ${widget.roadmapCount == 1 ? 'roadmap' : 'roadmaps'}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── SECONDARY CARD ──────────────────────────────

class _SecondaryCard extends StatelessWidget {
  final _CategorySummary category;
  final Gradient gradient;
  const _SecondaryCard({required this.category, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final progress = category.totalTasks == 0
        ? 0.0
        : category.completedTasks / category.totalTasks;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [_softShadow],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Category',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70)),
                ],
              ),
              const Spacer(),
              Text(category.title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5)),
              const SizedBox(height: 8),
              Text(
                '${category.completedTasks}/${category.totalTasks} tasks',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySummary {
  const _CategorySummary({
    required this.title,
    this.completedTasks = 0,
    this.totalTasks = 0,
  });

  final String title;
  final int completedTasks;
  final int totalTasks;
}

List<_CategorySummary> _featuredCategorySummaries(Iterable<Task> tasks) {
  final tasksByCategory = <String, List<Task>>{};
  final titlesByCategory = <String, String>{};
  for (final task in tasks) {
    final category = task.category?.trim();
    if (category == null ||
        category.isEmpty ||
        category.toLowerCase() == 'inbox') {
      continue;
    }
    final key = category.toLowerCase() == 'personal'
        ? 'personal notes'
        : category.toLowerCase();
    final title = switch (key) {
      'personal notes' => 'Personal Notes',
      'study' => 'Study',
      'daily tasks' => 'Daily Tasks',
      'master roadmap' => 'Master Roadmap',
      _ => category,
    };
    titlesByCategory.putIfAbsent(key, () => title);
    tasksByCategory.putIfAbsent(key, () => []).add(task);
  }

  for (final title in ['Personal Notes', 'Study']) {
    final key = title.toLowerCase();
    titlesByCategory.putIfAbsent(key, () => title);
    tasksByCategory.putIfAbsent(key, () => []);
  }

  final summaries = tasksByCategory.entries.map((entry) {
    final categoryTasks = entry.value;
    return _CategorySummary(
      title: titlesByCategory[entry.key]!,
      completedTasks: categoryTasks.where((task) => task.isCompleted).length,
      totalTasks: categoryTasks.length,
    );
  }).toList()
    ..sort((a, b) {
      final countOrder = b.totalTasks.compareTo(a.totalTasks);
      if (countOrder != 0) return countOrder;
      final aPriority = switch (a.title.toLowerCase()) {
        'personal notes' => 0,
        'study' => 1,
        _ => 2,
      };
      final bPriority = switch (b.title.toLowerCase()) {
        'personal notes' => 0,
        'study' => 1,
        _ => 2,
      };
      return aPriority != bPriority
          ? aPriority.compareTo(bPriority)
          : a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

  return summaries.take(2).toList();
}

// ──────────────────────────────── TASK ROW ───────────────────────────────────

class _TaskRow extends StatefulWidget {
  final Task task;
  final TaskController controller;
  final bool isFirst;
  final bool isLast;
  final int index;
  final int attachmentCount;
  final VoidCallback? onInsertRequested;
  const _TaskRow(
      {required this.task,
      required this.controller,
      required this.index,
      this.attachmentCount = 0,
      this.isFirst = false,
      this.isLast = false,
      this.onInsertRequested});
  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _ticking = false;
  bool _unticking = false;
  AnimationController? _strikeCtrl;
  Animation<double>? _strikeAnim;

  bool get _showAsCompleted =>
      (widget.task.isCompleted && !_unticking) || _ticking;

  @override
  void initState() {
    super.initState();
    final ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _strikeCtrl = ctrl;
    _strikeAnim = CurvedAnimation(parent: ctrl, curve: Curves.easeInOut);
    if (widget.task.isCompleted) ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_TaskRow old) {
    super.didUpdateWidget(old);
    if (widget.task.isCompleted && !old.task.isCompleted) {
      _strikeCtrl?.forward();
    } else if (!widget.task.isCompleted && old.task.isCompleted) {
      _strikeCtrl?.reverse();
      if (mounted) {
        setState(() {
          _ticking = false;
          _unticking = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _strikeCtrl?.dispose();
    super.dispose();
  }

  void _handleCircleTap() async {
    if (_ticking || _unticking) return;
    if (widget.task.isCompleted) {
      setState(() => _unticking = true);
      _strikeCtrl?.reverse();
      await Future.delayed(const Duration(milliseconds: 380));
      if (mounted) widget.controller.reopenTask(widget.task.id);
      return;
    }
    setState(() => _ticking = true);
    _strikeCtrl?.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) widget.controller.completeTask(widget.task.id);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TaskEditorScreen(task: widget.task)));
      },
      onDoubleTap: () {
        setState(() => _pressed = false);
        widget.onInsertRequested?.call();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Slidable(
          key: ValueKey(widget.task.id),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.44,
            children: [
              if (widget.task.isCompleted)
                CustomSlidableAction(
                  onPressed: (_) =>
                      widget.controller.reopenTask(widget.task.id),
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  child: const _SwipeActionTile(
                    icon: Icons.replay_rounded,
                    color: AppColors.action,
                  ),
                )
              else
                CustomSlidableAction(
                  onPressed: (_) =>
                      widget.controller.completeTask(widget.task.id),
                  backgroundColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  child: const _SwipeActionTile(
                    icon: Icons.check_rounded,
                    color: AppColors.attention,
                  ),
                ),
              CustomSlidableAction(
                onPressed: (_) async {
                  try {
                    await widget.controller.togglePinTask(widget.task.id);
                  } catch (e, st) {
                    if (!context.mounted) return;
                    debugPrint('[ERR-HOM-01] Failed to perform task action: $e\n$st');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("We couldn't perform this action. Please check your connection and try again.")),
                    );
                  }
                },
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                child: _SwipeActionTile(
                  icon: widget.task.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: AppColors.action,
                ),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.22,
            children: [
              CustomSlidableAction(
                onPressed: (_) async {
                  try {
                    await widget.controller.deleteTask(widget.task.id);
                  } catch (e, st) {
                    if (!context.mounted) return;
                    debugPrint('[ERR-HOM-02] Failed to delete task: $e\n$st');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("We couldn't delete this task. Please try again.")),
                    );
                  }
                },
                backgroundColor: Colors.transparent,
                padding: EdgeInsets.zero,
                child: const _SwipeActionTile(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.alert,
                ),
              ),
            ],
          ),
          child: Container(
            height: 76,
            padding: const EdgeInsets.only(left: 12, right: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 10,
                    offset: Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _handleCircleTap,
                  child: SizedBox(
                    width: 44,
                    height: 76,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _showAsCompleted
                              ? AppColors.action
                              : Colors.transparent,
                          border: Border.all(
                            color: _showAsCompleted
                                ? AppColors.action
                                : AppColors.textSecondaryOpacity(0.28),
                            width: 1.6,
                          ),
                        ),
                        child: _showAsCompleted
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _showAsCompleted
                                  ? AppColors.textSecondaryOpacity(0.38)
                                  : AppColors.textPrimary,
                            ),
                            child: Text(widget.task.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _strikeAnim ??
                                  const AlwaysStoppedAnimation(0),
                              builder: (_, __) => CustomPaint(
                                painter: _StrikePainter(
                                  progress: _strikeAnim?.value ?? 0,
                                  color: AppColors.textSecondaryOpacity(0.55),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.task.dueAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            relativeDueLabel(widget.task.dueAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.task.isOverdue
                                  ? AppColors.alert
                                  : AppColors.textSecondaryOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.task.category != null &&
                    widget.task.category!.isNotEmpty)
                  Flexible(
                    flex: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(widget.task.category!)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.task.category!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _getCategoryColor(widget.task.category!)),
                      ),
                    ),
                  ),
                if (widget.task.isPinned) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.push_pin, size: 14, color: AppColors.action),
                ],
                if (widget.attachmentCount > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.attach_file,
                      size: 14, color: AppColors.textSecondary),
                  if (widget.attachmentCount > 1) ...[
                    const SizedBox(width: 4),
                    Text('${widget.attachmentCount}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary)),
                  ],
                ],
                const SizedBox(width: 16),
                if (widget.index >= 0)
                  ReorderableDragStartListener(
                    index: widget.index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Icon(Icons.drag_indicator,
                            size: 20,
                            color: AppColors.textSecondaryOpacity(0.5)),
                      ),
                    ),
                  )
                else
                  Icon(Icons.drag_indicator,
                      size: 20, color: AppColors.textSecondaryOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('academic') || cat.contains('study')) {
      return AppColors.decorNavy;
    }
    if (cat.contains('health') || cat.contains('gym')) {
      return AppColors.decorCoral;
    }
    if (cat.contains('personal')) return AppColors.decorPink;
    return AppColors.action;
  }
}

// ────────────────────────────── QUICK ADD ────────────────────────────────────

class _QuickAdd extends StatefulWidget {
  final TaskController controller;
  const _QuickAdd({required this.controller});
  @override
  State<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends State<_QuickAdd> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TaskEditorScreen()));
    } else {
      widget.controller.createTask(title: text, category: 'Daily Tasks');
      _ctrl.clear();
      _focus.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [_softShadow],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Quick Add...',
                  hintStyle: TextStyle(
                      fontSize: 15, color: AppColors.textSecondaryOpacity(0.6)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                    color: AppColors.action, shape: BoxShape.circle),
                child: const Icon(Icons.add_rounded,
                    size: 24, color: AppColors.surface),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────── EMPTY STATE ─────────────────────────────────

class _EmptyTasksHint extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyTasksHint({required this.onAdd});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [_softShadow],
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('No tasks today',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              const Text('Tap to add your first task',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
}

// ──────────────────────────────── NAV ICON ───────────────────────────────────

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _NavIcon(this.icon, this.selected);
  @override
  Widget build(BuildContext context) => Icon(icon,
      size: 24,
      color: selected ? AppColors.textPrimary : AppColors.textSecondary);
}

// ─────────────────────────── SWIPE ACTION TILE ───────────────────────────────

class _SwipeActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SwipeActionTile({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      );
}

// ────────────────────────────── INLINE INSERT ──────────────────────────────────

class _InlineInsertField extends StatefulWidget {
  final String aboveId;
  final TaskController controller;
  final VoidCallback onDismissed;
  final bool isLast;

  const _InlineInsertField({
    required this.aboveId,
    required this.controller,
    required this.onDismissed,
    this.isLast = false,
  });

  @override
  State<_InlineInsertField> createState() => _InlineInsertFieldState();
}

class _InlineInsertFieldState extends State<_InlineInsertField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) {
      _submit();
    }
  }

  void _submit() {
    if (_submitted) return;
    _submitted = true;
    final text = _ctrl.text.trim();
    if (text.isNotEmpty) {
      widget.controller.insertTaskBelow(widget.aboveId, text);
    }
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _submitted = true;
          _ctrl.clear();
          widget.onDismissed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        height: 72,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.action.withValues(alpha: 0.6), width: 1.5),
          boxShadow: const [_softShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider, width: 2),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'New task...',
                  hintStyle: TextStyle(
                      fontSize: 15, color: AppColors.textSecondaryOpacity(0.6)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded,
                  color: AppColors.action, size: 20),
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayTaskRow extends StatelessWidget {
  const _TodayTaskRow({
    required this.task,
    required this.onTap,
    required this.onComplete,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    Color priorityColor;
    String priorityLabel;
    switch (task.priority) {
      case TaskPriority.high:
        priorityColor = AppColors.alert;
        priorityLabel = 'High';
        break;
      case TaskPriority.medium:
        priorityColor = AppColors.attention;
        priorityLabel = 'Medium';
        break;
      case TaskPriority.low:
      default:
        priorityColor = AppColors.action;
        priorityLabel = 'Low';
        break;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: AppColors.textPrimary),
                        ),
                      ),
                      if (task.priority == TaskPriority.high || task.priority == TaskPriority.medium)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priorityLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: priorityColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: AppColors.textSecondaryOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        'Due ${AppDateFormat.time(task.dueAt!)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondaryOpacity(0.9)),
                      ),
                      if (task.category != null && task.category!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text('·', style: TextStyle(color: AppColors.textSecondaryOpacity(0.6))),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            task.category!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondaryOpacity(0.9)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: onComplete,
              tooltip: 'Complete task',
              icon: const Icon(Icons.circle_outlined, color: AppColors.action),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayClassRow extends StatelessWidget {
  const _TodayClassRow({
    required this.entry,
    required this.primary,
    // required this.onTap,
  });

  final TimetableEntry entry;
  final bool primary;
  // final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, entry.startTime.hour,
        entry.startTime.minute);
    final end = DateTime(
        now.year, now.month, now.day, entry.endTime.hour, entry.endTime.minute);
    final current = !now.isBefore(start) && now.isBefore(end);
    final isPast = now.isAfter(end);

    final accentColor = getEntryColor(entry);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
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
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [accentColor, accentColor.withValues(alpha: 0.15)],
                          ),
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
                            decoration: isPast ? TextDecoration.lineThrough : null,
                            color: isPast ? AppColors.textSecondaryOpacity(0.5) : AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.04),
                      // removed
                      // removed
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.15),
                        // removed
                        // removed
                    ),
                  ),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    decoration: isPast ? TextDecoration.lineThrough : null,
                                    color: isPast ? AppColors.textSecondaryOpacity(0.5) : AppColors.textPrimary)),
                          ),
                          if (current)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.decorNavy,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('NOW',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: Colors.white)),
                            )
                        ],
                      ),
                      if (entry.instructor.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(entry.instructor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      if (entry.category != null && entry.category!.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              entry.category!,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ),
                      if (entry.room?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Icon removed
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(entry.room!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondaryOpacity(0.9))),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.action : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              selected ? null : Border.all(color: AppColors.divider, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.surface : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  final double progress;
  final Color color;
  const _StrikePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final y = size.height * 0.52;
    canvas.drawLine(Offset(0, y), Offset(size.width * progress, y), paint);
  }

  @override
  bool shouldRepaint(_StrikePainter old) => old.progress != progress;
}

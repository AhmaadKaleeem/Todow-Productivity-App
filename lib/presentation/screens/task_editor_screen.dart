import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/roadmap.dart';
import 'package:todow/domain/models/subtask.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/reminders/reminder_presets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/timetable_providers.dart';
import 'package:todow/presentation/providers/task_providers.dart';
import 'package:todow/presentation/providers/roadmap_providers.dart';
import 'package:todow/presentation/widgets/attachments_section.dart';
import 'package:todow/presentation/widgets/reminders_section.dart';
import 'package:todow/presentation/widgets/subtasks_section.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kRoadmaps = [
  'Assignment',
  'Quiz',
  'Paper',
  'Daily Tasks',
  'Personal Notes',
  'Study',
];

const _priorityMeta = {
  TaskPriority.none: (_PriorityMeta('None', null, Color(0x00000000))),
  TaskPriority.low:
      (_PriorityMeta('Low', Icons.arrow_downward_rounded, Color(0xFF22C55E))),
  TaskPriority.medium:
      (_PriorityMeta('Medium', Icons.remove_rounded, AppColors.attention)),
  TaskPriority.high:
      (_PriorityMeta('High', Icons.arrow_upward_rounded, Color(0xFFF97316))),
  TaskPriority.critical: (_PriorityMeta(
      'Critical', Icons.local_fire_department_rounded, AppColors.alert)),
};

class _PriorityMeta {
  const _PriorityMeta(this.label, this.icon, this.color);
  final String label;
  final IconData? icon;
  final Color color;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class TaskEditorScreen extends ConsumerStatefulWidget {
  final Task? task;
  final String? topicId;
  const TaskEditorScreen({super.key, this.task, this.topicId});
  @override
  ConsumerState<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends ConsumerState<TaskEditorScreen>
    with TickerProviderStateMixin {
  // State
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late TaskPriority _priority;
  DateTime? _dueAt;
  late final List<String> _roadmaps;
  late String _selectedRoadmap;
  late final List<String> _subjects;
  String? _selectedSubject;
  Task? _workingTask;
  Topic? _roadmapTopic;
  Roadmap? _roadmap;
  late List<Subtask> _subtasks;
  late ReminderPlan _reminderPlan;
  bool _isAddingToPersonalTimetable = false;
  bool _isOnPersonalTimetable = false;
  bool _canPop = false;

  // Expansion state for progressive disclosure
  bool _schedExpanded = false;
  bool _priorityExpanded = false;
  bool _projectExpanded = false;
  bool _remindersExpanded = false;
  bool _subtasksExpanded = false;
  bool _notesExpanded = false;

  // Animations
  late AnimationController _titleGrowCtrl;

  @override
  void initState() {
    super.initState();
    _workingTask = widget.task;
    final taskId = _workingTask?.id;
    _isOnPersonalTimetable = taskId != null &&
        (ref.read(timetableProvider).valueOrNull ?? []).any(
              (entry) =>
                  entry.taskId == taskId &&
                  entry.scheduleKind == TimetableKind.personal,
            );
    _title = TextEditingController(text: _workingTask?.title ?? '');
    _notes = TextEditingController(text: _workingTask?.description ?? '');
    _priority = _workingTask?.priority ?? TaskPriority.none;
    _dueAt = _workingTask?.dueAt;
    _roadmaps = List.of(_kRoadmaps);
    final allTasks = ref.read(tasksProvider).valueOrNull ?? [];
    for (final t in allTasks) {
      if (t.category != null && !_roadmaps.contains(t.category!)) {
        _roadmaps.add(t.category!);
      }
    }
    final cat = _workingTask?.category ?? _kRoadmaps.first;
    if (!_roadmaps.contains(cat)) _roadmaps.add(cat);
    _selectedRoadmap = cat;
    
    _subjects = ['None'];
    for (final t in allTasks) {
      if (t.subject != null && !_subjects.contains(t.subject!)) {
        _subjects.add(t.subject!);
      }
    }
    _selectedSubject = _workingTask?.subject;
    if (_selectedSubject != null && !_subjects.contains(_selectedSubject)) {
      _subjects.add(_selectedSubject!);
    }

    _subtasks = List.of(_workingTask?.subtasks ?? []);
    _reminderPlan = _workingTask?.reminderPlan ??
        ReminderPlan(
          preset: ReminderPreset.normal,
          offsets: ReminderPresets.forPreset(ReminderPreset.normal),
          constantReminder: false,
        );

    _titleGrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _loadRoadmapContext();

    // Pre-expand sections if editing
    if (_workingTask != null) {
      _schedExpanded = _dueAt != null;
      _priorityExpanded = _priority != TaskPriority.none;
      _remindersExpanded = true;
      _subtasksExpanded = _subtasks.isNotEmpty;
      _notesExpanded = (_workingTask?.description ?? '').isNotEmpty;
    }
  }

  bool get _isRoadmapTask =>
      widget.topicId != null || _workingTask?.topicId != null;

  Future<void> _loadRoadmapContext() async {
    final topicId = widget.topicId ?? _workingTask?.topicId;
    if (topicId == null) {
      return;
    }
    final controller = ref.read(roadmapsProvider.notifier);
    final topic = await controller.getTopic(topicId);
    final roadmap =
        topic == null ? null : await controller.getRoadmap(topic.roadmapId);
    if (mounted) {
      setState(() {
        _roadmapTopic = topic;
        _roadmap = roadmap;
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _titleGrowCtrl.dispose();
    super.dispose();
  }

  // ── Date/time helpers ────────────────────────────────────────────────────

  void _setQuickDate(int daysFromNow) {
    final base = DateTime.now().add(Duration(days: daysFromNow));
    final h = _dueAt?.hour ?? 9;
    final m = _dueAt?.minute ?? 0;
    setState(() => _dueAt = DateTime(base.year, base.month, base.day, h, m));
  }

  bool _isQuickDate(int days) {
    if (_dueAt == null) return false;
    final t = DateTime.now().add(Duration(days: days));
    return _dueAt!.year == t.year &&
        _dueAt!.month == t.month &&
        _dueAt!.day == t.day;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: _datePkrTheme,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: _dueAt != null
          ? TimeOfDay.fromDateTime(_dueAt!)
          : const TimeOfDay(hour: 9, minute: 0),
      builder: _datePkrTheme,
    );
    setState(() {
      _dueAt = t != null
          ? DateTime(d.year, d.month, d.day, t.hour, t.minute)
          : DateTime(d.year, d.month, d.day, 9, 0);
    });
  }

  Widget _datePkrTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.action,
            onPrimary: AppColors.surface,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      );

  String _fmtDate(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = d.hour;
    final m = d.minute;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final mStr = m.toString().padLeft(2, '0');
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day} · $h12:$mStr $ampm';
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<Task> _autoSave() async {
    if (_workingTask != null) return _workingTask!;
    final tc = ref.read(tasksProvider.notifier);
    final ttl = _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim();
    final task = await tc.createTask(
      title: ttl,
      description: _notes.text.trim(),
      priority: _priority,
      dueAt: _dueAt,
      category: _isRoadmapTask ? null : _selectedRoadmap,
      topicId: widget.topicId ?? _workingTask?.topicId,
      subtasks: _subtasks,
      reminderPlan: _reminderPlan,
    );
    // Sync the legacy TaskController used by HomeScreen (now handled automatically by home_screen listening to tasksProvider)
    setState(() {
      _workingTask = task;
      if (_title.text.trim().isEmpty) _title.text = 'Untitled';
    });
    return task;
  }

  Future<void> _addToPersonalTimetable() async {
    if (_isAddingToPersonalTimetable || _isOnPersonalTimetable) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Add a task name before scheduling it.',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.textPrimary,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ));
      return;
    }
    final date = _dueAt ??
        await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
        );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null || !mounted) return;
    setState(() => _isAddingToPersonalTimetable = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      final taskController = ref.read(tasksProvider.notifier);
      final task = _workingTask == null
          ? await _autoSave()
          : await taskController.updateTask(
              _workingTask!.copyWith(
                title: _title.text.trim(),
                description: _notes.text.trim(),
                priority: _priority,
                dueAt: _dueAt,
                clearDueAt: _dueAt == null,
                category: _isRoadmapTask ? null : _selectedRoadmap,
                topicId: widget.topicId,
                subtasks: _subtasks,
                reminderPlan: _reminderPlan,
              ),
            );
      if (!mounted) return;
      setState(() => _workingTask = task);
      final entries = ref.read(timetableProvider).valueOrNull ?? [];
      final alreadyScheduled = entries.any(
        (entry) =>
            entry.taskId == task.id &&
            entry.scheduleKind == TimetableKind.personal,
      );
      if (!alreadyScheduled) {
        final start =
            DateTime(date.year, date.month, date.day, time.hour, time.minute);
        await ref.read(timetableProvider.notifier).add(
          courseName: task.title,
          instructor: task.description,
          weekday: WeekdayExt.fromDartWeekday(date.weekday),
          startTime: start,
          endTime: start.add(const Duration(hours: 1)),
          scheduleKind: TimetableKind.personal,
          scheduledDate: date,
          repeatWeekly: false,
          category: task.topicId == null ? 'Task' : 'Roadmap',
          taskId: task.id,
        );
      }
      if (mounted) setState(() => _isOnPersonalTimetable = true);
    } catch (e, st) {
      debugPrint('[ERR-TSK-01] Failed to add task to timetable: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content:
              Text("We couldn't add this task to your timetable. Please check your schedule and try again."),
        ));
    } finally {
      if (mounted) setState(() => _isAddingToPersonalTimetable = false);
    }
  }

  void _save() {
    if (_title.text.trim().isNotEmpty) {
      final tc = ref.read(tasksProvider.notifier);
      if (_workingTask == null) {
        tc.createTask(
          title: _title.text.trim(),
          description: _notes.text.trim(),
          priority: _priority,
          dueAt: _dueAt,
          category: _isRoadmapTask ? null : _selectedRoadmap,
          subject: _selectedSubject,
          topicId: widget.topicId,
          subtasks: _subtasks,
          reminderPlan: _reminderPlan,
        );
      } else {
        tc.updateTask(_workingTask!.copyWith(
          title: _title.text.trim(),
          description: _notes.text.trim(),
          priority: _priority,
          dueAt: _dueAt,
          clearDueAt: _dueAt == null,
          category: _isRoadmapTask ? null : _selectedRoadmap,
          subject: _selectedSubject,
          clearSubject: _selectedSubject == null,
          topicId: widget.topicId,
          subtasks: _subtasks,
          reminderPlan: _reminderPlan,
        ));
      }
    }
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  // ── Project helpers ───────────────────────────────────────────────────────

  Color _projectColor(int i) {
    const c = [AppColors.decorNavy, AppColors.decorPink, AppColors.decorCoral];
    return c[i % c.length];
  }

  Future<void> _addNewProject() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('New Project',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Project name',
            hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.action)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.action,
                foregroundColor: AppColors.surface,
                shape: const StadiumBorder()),
            child: const Text('Add',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() {
        if (!_roadmaps.contains(name)) _roadmaps.add(name);
        _selectedRoadmap = name;
      });
    }
  }

  Future<void> _addNewSubject() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.surface,
        title: const Text('New Subject',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Subject name',
            hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.action)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.action,
                foregroundColor: AppColors.surface,
                shape: const StadiumBorder()),
            child: const Text('Add',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() {
        if (!_subjects.contains(name)) _subjects.add(name);
        _selectedSubject = name;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isNew = _workingTask == null;
    final hasTitle = _title.text.trim().isNotEmpty;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (did, _) {
        if (!did) _save();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              // ── Curved header panel ──────────────────────────────────────
              _CurvedHeader(
                isNew: isNew,
                dueAt: _dueAt,
                contextLabel: _isRoadmapTask
                    ? '${_roadmap?.title ?? 'Roadmap'} / ${_roadmapTopic?.title ?? 'Topic'}'
                    : _selectedRoadmap,
                isRoadmapTask: _isRoadmapTask,
                onClose: _save,
              ),

              // ── Scrollable body ──────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Title area ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppColors.divider.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _title,
                              onChanged: (_) => setState(() {}),
                              maxLines: null,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                hintText: 'What needs to be done?',
                                hintStyle: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.3),
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                            // ── Amber accent line (grows with title) ─────────────
                            const SizedBox(height: 12),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: hasTitle ? 48.0 : 28.0,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppColors.attention,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_isRoadmapTask)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _RoadmapTaskContext(
                          roadmap: _roadmap?.title ?? 'Roadmap task',
                          topic: _roadmapTopic?.title ?? 'Loading Topic…',
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ── Quick-access control strip ───────────────────────
                    _ControlStrip(
                      dueAt: _dueAt,
                      priority: _priority,
                      project: _selectedRoadmap,
                      remindersOn: _reminderPlan.allOffsets.isNotEmpty ||
                          _reminderPlan.constantReminder,
                      subtaskCount: _subtasks.length,
                      showProject: !_isRoadmapTask,
                      schedExpanded: _schedExpanded,
                      priorityExpanded: _priorityExpanded,
                      projectExpanded: _projectExpanded,
                      remindersExpanded: _remindersExpanded,
                      subtasksExpanded: _subtasksExpanded,
                      onSchedTap: () =>
                          setState(() => _schedExpanded = !_schedExpanded),
                      onPriorityTap: () => setState(
                          () => _priorityExpanded = !_priorityExpanded),
                      onProjectTap: () =>
                          setState(() => _projectExpanded = !_projectExpanded),
                      onRemindersTap: () => setState(
                          () => _remindersExpanded = !_remindersExpanded),
                      onSubtasksTap: () => setState(
                          () => _subtasksExpanded = !_subtasksExpanded),
                    ),

                    // ── Scheduling panel ─────────────────────────────────
                    _AnimatedSection(
                      visible: _schedExpanded,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _SchedulingPanel(
                          dueAt: _dueAt,
                          onPickDate: _pickDate,
                          onQuickDate: _setQuickDate,
                          isQuickDate: _isQuickDate,
                          onClear: () => setState(() => _dueAt = null),
                          fmtDate: _fmtDate,
                        ),
                      ),
                    ),

                    // ── Priority panel ───────────────────────────────────
                    _AnimatedSection(
                      visible: _priorityExpanded,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: _PriorityPanel(
                          priority: _priority,
                          onChanged: (p) => setState(() => _priority = p),
                        ),
                      ),
                    ),

                    // ── Project panel ────────────────────────────────────
                    if (!_isRoadmapTask)
                      _AnimatedSection(
                        visible: _projectExpanded,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _ProjectPanel(
                            roadmaps: _roadmaps,
                            selected: _selectedRoadmap,
                            colorFor: _projectColor,
                            onSelect: (r) =>
                                setState(() => _selectedRoadmap = r),
                            onAdd: _addNewProject,
                          ),
                        ),
                      ),

                    // ── Subject panel ────────────────────────────────────
                    if (!_isRoadmapTask && ['Assignment', 'Quiz', 'Paper'].contains(_selectedRoadmap))
                      _AnimatedSection(
                        visible: _projectExpanded,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: _ProjectPanel(
                            roadmaps: _subjects,
                            selected: _selectedSubject ?? 'None',
                            colorFor: _projectColor,
                            onSelect: (s) => setState(() => _selectedSubject = s == 'None' ? null : s),
                            onAdd: _addNewSubject,
                          ),
                        ),
                      ),

                    // ── Reminders panel ──────────────────────────────────
                    _AnimatedSection(
                      visible: _remindersExpanded,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: RemindersSection(
                          plan: _reminderPlan,
                          dueAt: _dueAt,
                          onChanged: (p) => setState(() => _reminderPlan = p),
                          onSetDueDate: () => setState(() {
                            _remindersExpanded = false;
                            _schedExpanded = true;
                          }),
                        ),
                      ),
                    ),

                    // ── Subtasks panel ───────────────────────────────────
                    _AnimatedSection(
                      visible: _subtasksExpanded,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: SubtasksSection(
                          subtasks: _subtasks,
                          onChanged: (v) => setState(() => _subtasks = v),
                        ),
                      ),
                    ),

                    // ── Notes / description ──────────────────────────────
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _NotesField(
                        controller: _notes,
                        expanded: _notesExpanded,
                        onExpand: () => setState(() => _notesExpanded = true),
                        onChanged: () => setState(() {}),
                      ),
                    ),

                    // ── Attachments ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: AttachmentsSection(
                          task: _workingTask, onAutoSave: _autoSave),
                    ),

                    // ── Add to personal timetable ────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Semantics(
                        button: true,
                        enabled: !_isAddingToPersonalTimetable &&
                            !_isOnPersonalTimetable,
                        label: _isOnPersonalTimetable
                            ? 'Added to personal timetable'
                            : 'Add to personal timetable',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Material(
                            color: AppColors.surface,
                            child: InkWell(
                              onTap: _isAddingToPersonalTimetable ||
                                      _isOnPersonalTimetable
                                  ? null
                                  : _addToPersonalTimetable,
                              child: SizedBox(
                                height: 52,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: _isOnPersonalTimetable
                                            ? 1
                                            : _isAddingToPersonalTimetable
                                                ? 0.72
                                                : 0,
                                      ),
                                      duration:
                                          const Duration(milliseconds: 520),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, progress, child) =>
                                          Align(
                                        alignment: Alignment.centerLeft,
                                        child: FractionallySizedBox(
                                          widthFactor: progress,
                                          heightFactor: 1,
                                          child: child,
                                        ),
                                      ),
                                      child: const ColoredBox(
                                          color: AppColors.action),
                                    ),
                                    Center(
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 220),
                                        transitionBuilder: (child, animation) =>
                                            FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.2),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        ),
                                        child: Text(
                                          _isOnPersonalTimetable
                                              ? 'Added to personal timetable'
                                              : _isAddingToPersonalTimetable
                                                  ? 'Adding to timetable…'
                                                  : 'Add to personal timetable',
                                          key: ValueKey((
                                            _isOnPersonalTimetable,
                                            _isAddingToPersonalTimetable,
                                          )),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            border: Border.all(
                                              color:
                                                  AppColors.action.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),

          // ── Sticky CTA ─────────────────────────────────────────────────
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                    top: BorderSide(
                        color: AppColors.divider.withValues(alpha: 0.6),
                        width: 1)),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: hasTitle ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasTitle ? AppColors.action : AppColors.divider,
                    foregroundColor:
                        hasTitle ? AppColors.surface : AppColors.textSecondary,
                    disabledBackgroundColor: AppColors.divider,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: hasTitle
                          ? AppColors.surface
                          : AppColors.textSecondary,
                    ),
                    child: Text(isNew ? 'Create task' : 'Save changes'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Curved header panel ───────────────────────────────────────────────────────

class _RoadmapTaskContext extends StatelessWidget {
  const _RoadmapTaskContext({required this.roadmap, required this.topic});

  final String roadmap;
  final String topic;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Roadmap context, $roadmap, $topic. This task stays in this Topic.',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.action.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.action.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.route_outlined, size: 20, color: AppColors.action),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(roadmap,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(topic,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.action),
          ],
        ),
      ),
    );
  }
}

class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader({
    required this.isNew,
    required this.dueAt,
    required this.contextLabel,
    required this.isRoadmapTask,
    required this.onClose,
  });

  final bool isNew;
  final DateTime? dueAt;
  final String contextLabel;
  final bool isRoadmapTask;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // Background cream + curved bottom edge
          CustomPaint(
            painter: _CurvedPanelPainter(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: Row(
                children: [
                  // Close button
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Page label
                  Text(
                    isNew ? 'New task' : 'Edit task',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isRoadmapTask ? Icons.lock_outline_rounded : Icons.circle,
                    color:
                        isRoadmapTask ? AppColors.action : AppColors.attention,
                    size: isRoadmapTask ? 16 : 8,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    contextLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvedPanelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.surfaceElevated;
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 20)
      ..quadraticBezierTo(
          size.width * 0.75, size.height, size.width * 0.5, size.height - 4)
      ..quadraticBezierTo(
          size.width * 0.25, size.height - 8, 0, size.height - 20)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Control strip ─────────────────────────────────────────────────────────────

class _ControlStrip extends StatelessWidget {
  const _ControlStrip({
    required this.dueAt,
    required this.priority,
    required this.project,
    required this.remindersOn,
    required this.subtaskCount,
    required this.showProject,
    required this.schedExpanded,
    required this.priorityExpanded,
    required this.projectExpanded,
    required this.remindersExpanded,
    required this.subtasksExpanded,
    required this.onSchedTap,
    required this.onPriorityTap,
    required this.onProjectTap,
    required this.onRemindersTap,
    required this.onSubtasksTap,
  });

  final DateTime? dueAt;
  final TaskPriority priority;
  final String project;
  final bool remindersOn;
  final int subtaskCount;
  final bool showProject;
  final bool schedExpanded,
      priorityExpanded,
      projectExpanded,
      remindersExpanded,
      subtasksExpanded;
  final VoidCallback onSchedTap,
      onPriorityTap,
      onProjectTap,
      onRemindersTap,
      onSubtasksTap;

  @override
  Widget build(BuildContext context) {
    final meta = _priorityMeta[priority]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Schedule chip
          _StripChip(
            label: dueAt != null ? _shortDate(dueAt!) : 'Schedule',
            active: schedExpanded || dueAt != null,
            activeColor: AppColors.action,
            onTap: onSchedTap,
          ),
          // Priority chip
          _StripChip(
            label: priority == TaskPriority.none
                ? 'Priority'
                : 'Priority - ${meta.label}',
            active: priorityExpanded || priority != TaskPriority.none,
            activeColor: meta.color == const Color(0x00000000)
                ? AppColors.action
                : meta.color,
            onTap: onPriorityTap,
          ),
          if (showProject)
            _StripChip(
              label: 'Category - $project',
              active: projectExpanded,
              activeColor: AppColors.decorNavy,
              onTap: onProjectTap,
            ),
          // Reminders chip
          _StripChip(
            label: remindersOn ? 'Reminders - On' : 'Reminders',
            active: remindersExpanded || remindersOn,
            activeColor: AppColors.attention,
            onTap: onRemindersTap,
          ),
          // Subtasks chip
          _StripChip(
            label: subtaskCount > 0
                ? '$subtaskCount subtask${subtaskCount == 1 ? '' : 's'}'
                : 'Subtasks',
            active: subtasksExpanded || subtaskCount > 0,
            activeColor: AppColors.decorCoral,
            onTap: onSubtasksTap,
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = d.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, $h12:$m $ampm';
  }
}

class _StripChip extends StatelessWidget {
  const _StripChip({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? activeColor.withValues(alpha: 0.10)
                : AppColors.surface,
            border: Border.all(
              color: active
                  ? activeColor.withValues(alpha: 0.35)
                  : AppColors.divider,
              width: active ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? []
                : const [
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1)),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Animated section wrapper ──────────────────────────────────────────────────

class _AnimatedSection extends StatelessWidget {
  const _AnimatedSection({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedCrossFade(
        duration: const Duration(milliseconds: 220),
        sizeCurve: Curves.easeInOutCubic,
        firstCurve: Curves.easeOut,
        secondCurve: Curves.easeIn,
        crossFadeState:
            visible ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        firstChild: child,
        secondChild: const SizedBox.shrink(),
      );
}

// ── Scheduling panel ──────────────────────────────────────────────────────────

class _SchedulingPanel extends StatelessWidget {
  const _SchedulingPanel({
    required this.dueAt,
    required this.onPickDate,
    required this.onQuickDate,
    required this.isQuickDate,
    required this.onClear,
    required this.fmtDate,
  });

  final DateTime? dueAt;
  final VoidCallback onPickDate;
  final void Function(int) onQuickDate;
  final bool Function(int) isQuickDate;
  final VoidCallback onClear;
  final String Function(DateTime) fmtDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick date row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickDateChip(
                      label: 'Today',
                      selected: isQuickDate(0),
                      onTap: () => onQuickDate(0),
                    ),
                    _QuickDateChip(
                      label: 'Tomorrow',
                      selected: isQuickDate(1),
                      onTap: () => onQuickDate(1),
                    ),
                    _QuickDateChip(
                      label: 'Pick date & time',
                      icon: Icons.calendar_month_rounded,
                      selected: dueAt != null && !isQuickDate(0) && !isQuickDate(1),
                      onTap: onPickDate,
                    ),
                  ],
                ),
              ),
              if (dueAt != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8), // align with first row of chips
                    child: Icon(Icons.close_rounded,
                        size: 18,
                        color: AppColors.textSecondary.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ],
          ),
          if (dueAt != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onPickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.action.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.action.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        size: 15, color: AppColors.action),
                    const SizedBox(width: 8),
                    Text(
                      fmtDate(dueAt!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.action,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.action : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? AppColors.action : AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 13,
                    color:
                        selected ? AppColors.surface : AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.surface : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Priority panel ────────────────────────────────────────────────────────────

class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({required this.priority, required this.onChanged});
  final TaskPriority priority;
  final ValueChanged<TaskPriority> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: TaskPriority.values.map((p) {
            final meta = _priorityMeta[p]!;
            final sel = priority == p;
            final col = meta.color == const Color(0x00000000)
                ? AppColors.textSecondary
                : meta.color;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        sel ? col.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel ? col : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(meta.icon ?? Icons.block_rounded,
                          size: 18,
                          color: sel
                              ? col
                              : AppColors.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 4),
                      Text(
                        meta.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel
                              ? col
                              : AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}

// ── Project panel ─────────────────────────────────────────────────────────────

class _ProjectPanel extends StatelessWidget {
  const _ProjectPanel({
    required this.roadmaps,
    required this.selected,
    required this.colorFor,
    required this.onSelect,
    required this.onAdd,
  });

  final List<String> roadmaps;
  final String selected;
  final Color Function(int) colorFor;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (int i = 0; i < roadmaps.length; i++)
              _ProjectChip(
                label: roadmaps[i],
                color: colorFor(i),
                selected: selected == roadmaps[i],
                onTap: () => onSelect(roadmaps[i]),
              ),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded,
                        size: 15, color: AppColors.textSecondary),
                    SizedBox(width: 4),
                    Text('New',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color : AppColors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check_rounded,
                    size: 13, color: AppColors.surface),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.surface : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Notes field ───────────────────────────────────────────────────────────────

class _NotesField extends StatelessWidget {
  const _NotesField({
    required this.controller,
    required this.expanded,
    required this.onExpand,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: expanded ? null : onExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        ),
        child: TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          onTap: onExpand,
          maxLines: expanded ? null : 2,
          minLines: expanded ? 3 : 1,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            fontWeight: FontWeight.w400,
            color:
                AppColors.textPrimary.withValues(alpha: expanded ? 1.0 : 0.85),
          ),
          decoration: InputDecoration(
            filled: false,
            hintText: 'Add notes, links, or extra context…',
            hintStyle: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary
                  .withValues(alpha: expanded ? 0.4 : 0.25),
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
    );
  }
}

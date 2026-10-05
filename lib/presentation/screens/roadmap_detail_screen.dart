import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/roadmap.dart';
import 'package:todow/domain/models/task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/roadmap_providers.dart';
import 'package:todow/presentation/screens/roadmap_import_screen.dart';
import 'package:todow/presentation/widgets/roadmap_spine_painter.dart';
import 'package:todow/presentation/widgets/topic_card.dart';
import 'package:todow/presentation/widgets/task_time_view.dart';

// Inline palette resolver — kept in sync with roadmap_list_screen palette.
const _kDetailPalette = [
  Color(0xFF1E3A8A),
  Color(0xFF0EA5E9),
  Color(0xFF0D9488),
  Color(0xFF059669),
  Color(0xFFF59E0B),
  Color(0xFFFB7185),
  Color(0xFFF472B6),
  Color(0xFF7C3AED),
  Color(0xFF4F46E5),
  Color(0xFFEF4444),
  Color(0xFF475569),
  Color(0xFFF59E0B),
];

Color _roadmapAccent(Roadmap r) {
  final idx = r.colorIndex >= 0
      ? r.colorIndex % _kDetailPalette.length
      : r.id.hashCode.abs() % _kDetailPalette.length;
  return _kDetailPalette[idx];
}

class RoadmapDetailScreen extends ConsumerStatefulWidget {
  const RoadmapDetailScreen({required this.roadmap, super.key});
  final Roadmap roadmap;

  @override
  ConsumerState<RoadmapDetailScreen> createState() => _RoadmapDetailScreenState();
}

class _RoadmapDetailScreenState extends ConsumerState<RoadmapDetailScreen>
    with SingleTickerProviderStateMixin {
  late Roadmap _roadmap;
  List<Topic> _topics = [];
  List<Task> _tasks = [];
  bool _loading = true;
  bool _dateView = false;
  String? _expandedTopicId;
  List<GlobalKey> _cardKeys = [];
  final _pathKey = GlobalKey();
  List<Rect> _cardBounds = [];
  late final AnimationController _routeAnimation;

  @override
  void initState() {
    super.initState();
    _roadmap = widget.roadmap;
    _routeAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _loadData();
  }

  @override
  void dispose() {
    _routeAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final ctrl = ref.read(roadmapsProvider.notifier);
    final topics = await ctrl.getTopics(_roadmap.id);
    final tasks = await ctrl.getTasksByRoadmap(_roadmap.id);
    if (!mounted) return;
    final routeChanged = topics.map((topic) => topic.id).join('|') !=
        _topics.map((topic) => topic.id).join('|');
    setState(() {
      _topics = topics;
      _tasks = tasks;
      _cardKeys = List.generate(topics.length, (_) => GlobalKey());
      if (routeChanged) {
        _cardBounds = [];
        _routeAnimation.value = 0;
      }
      _loading = false;
    });
    _scheduleGeometryUpdate();
  }

  void _scheduleGeometryUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _computeCardBounds());
  }

  void _computeCardBounds() {
    if (!mounted) return;
    final bounds = <Rect>[];
    final pathBox = _pathKey.currentContext?.findRenderObject() as RenderBox?;
    if (pathBox == null) return;

    for (final key in _cardKeys) {
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox;
        final position = box.localToGlobal(Offset.zero, ancestor: pathBox);
        bounds.add(position & box.size);
      }
    }
    if (mounted &&
        bounds.length == _cardKeys.length &&
        !_sameBounds(_cardBounds, bounds)) {
      final firstLayout = _cardBounds.isEmpty;
      setState(() {
        _cardBounds = bounds;
      });
      if (firstLayout || _routeAnimation.isDismissed) {
        _routeAnimation.forward(from: 0);
      }
    }
  }

  bool _sameBounds(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _reloadRoadmapTasks() async {
    final tasks =
        await ref.read(roadmapsProvider.notifier).getTasksByRoadmap(_roadmap.id);
    if (mounted) setState(() => _tasks = tasks);
  }

  Future<void> _exportRoadmap(bool excel) async {
    try {
      final tasks = await ref.read(roadmapsProvider.notifier)
          .getTasksByRoadmap(_roadmap.id);
      final rows = <List<String>>[
        const [
          'roadmap_title',
          'roadmap_description',
          'topic_title',
          'topic_description',
          'topic_order',
          'topic_status',
          'task_title',
          'task_description',
          'due_date',
          'due_time',
          'priority',
          'task_status',
          'reminder',
        ],
        for (final task in tasks)
          for (final topic
              in _topics.where((topic) => topic.id == task.topicId))
            [
              _roadmap.title,
              _roadmap.description ?? '',
              topic.title,
              topic.description ?? '',
              '${topic.orderIndex + 1}',
              topic.status.name,
              task.title,
              task.description,
              task.dueAt == null
                  ? ''
                  : '${task.dueAt!.year.toString().padLeft(4, '0')}-${task.dueAt!.month.toString().padLeft(2, '0')}-${task.dueAt!.day.toString().padLeft(2, '0')}',
              task.dueAt == null
                  ? ''
                  : '${task.dueAt!.hour.toString().padLeft(2, '0')}:${task.dueAt!.minute.toString().padLeft(2, '0')}',
              task.priority.name,
              task.status.name,
              const {'none', 'normal', 'assignment', 'critical'}
                      .contains(task.reminderPlan.preset.name)
                  ? task.reminderPlan.preset.name
                  : 'none',
            ],
      ];
      final extension = excel ? 'xlsx' : 'csv';
      final bytes = excel
          ? _xlsxBytes(rows)
          : Uint8List.fromList(utf8.encode(
              rows.map((row) => row.map(_csvCell).join(',')).join('\r\n'),
            ));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Roadmap',
        fileName: '${_roadmap.title}.$extension',
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Roadmap exported as $extension')),
      );
    } catch (e, st) {
      debugPrint('[ERR-RDM-01] Failed to export roadmap: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("We couldn't export this roadmap. Please check your storage permissions and try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _roadmapAccent(_roadmap);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.action))
          : CustomScrollView(
              slivers: [
                // ── Gradient header band ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(28)),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Toolbar row
                            Row(
                              children: [
                                _ToolbarButton(
                                  icon: Icons.arrow_back_rounded,
                                  label: 'Back',
                                  onTap: () => Navigator.pop(context),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    reverse: true,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _ToolbarButton(
                                          icon: Icons.upload_file_rounded,
                                          label: 'Import',
                                          onTap: () =>
                                              Navigator.of(context).push(
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const RoadmapImportScreen()),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _ToolbarMenu(
                                          onEdit: _editRoadmap,
                                          onExportCsv: () =>
                                              _exportRoadmap(false),
                                          onExportExcel: () =>
                                              _exportRoadmap(true),
                                          onDelete: _confirmDeleteRoadmap,
                                        ),
                                        const SizedBox(width: 8),
                                        _ToolbarButton(
                                          icon: Icons.add_rounded,
                                          label: 'Topic',
                                          isPrimary: true,
                                          accent: accent,
                                          onTap: _showCreateTopicDialog,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Roadmap title
                            Text(
                              _roadmap.title,
                              style: const TextStyle(
                                  fontSize: 26,
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.8),
                            ),
                            if (_roadmap.description?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 6),
                              Text(_roadmap.description!,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color:
                                          Colors.white.withValues(alpha: 0.8))),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Progress card ────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: _RoadmapProgress(
                        topics: _topics, tasks: _tasks, accent: accent),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                    child: _RoadmapModeSwitch(
                      dateView: _dateView,
                      accent: accent,
                      onChanged: (dateView) =>
                          setState(() => _dateView = dateView),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _dateView
                      ? TaskTimeView(roadmapId: _roadmap.id, topics: _topics)
                      : _topics.isEmpty
                          ? _EmptyRoadmap(
                              onAddTopic: _showCreateTopicDialog,
                            )
                          : Stack(
                              key: _pathKey,
                              children: [
                                if (_cardBounds.length == _topics.length)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedBuilder(
                                        animation: _routeAnimation,
                                        builder: (context, _) => CustomPaint(
                                          painter: RoadmapSpinePainter(
                                            cardBounds: _cardBounds,
                                            topics: _topics,
                                            accentColor: AppColors.action,
                                            progress: Curves.easeOutCubic
                                                .transform(
                                                    _routeAnimation.value),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                  child: NotificationListener<
                                      SizeChangedLayoutNotification>(
                                    onNotification: (_) {
                                      _scheduleGeometryUpdate();
                                      return false;
                                    },
                                    child: Column(
                                      children: [
                                        for (int i = 0; i < _topics.length; i++)
                                          SizeChangedLayoutNotifier(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 40),
                                              child: TopicCard(
                                                cardKey: _cardKeys[i],
                                                topic: _topics[i],
                                                roadmap: _roadmap,
                                                index: i,
                                                onTasksChanged:
                                                    _reloadRoadmapTasks,
                                                onEdit: () =>
                                                    _editTopic(_topics[i]),
                                                tasks: _tasks
                                                    .where((task) =>
                                                        task.topicId ==
                                                        _topics[i].id)
                                                    .toList(),
                                                tasksExpanded:
                                                    _expandedTopicId ==
                                                        _topics[i].id,
                                                onTasksExpanded: (expanded) {
                                                  setState(() =>
                                                      _expandedTopicId =
                                                          expanded
                                                              ? _topics[i].id
                                                              : null);
                                                  _scheduleGeometryUpdate();
                                                },
                                                onDelete: () =>
                                                    _confirmDeleteTopic(
                                                        _topics[i]),
                                                onStatusChanged:
                                                    (newStatus) async {
                                                  final updated = _topics[i]
                                                      .copyWith(
                                                          status: newStatus);
                                                  await ref.read(roadmapsProvider.notifier)
                                                      .updateTopic(updated);
                                                  _loadData();
                                                },
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
    );
  }

  void _showCreateTopicDialog() {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent top strip
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: _roadmapAccent(_roadmap),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Topic',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3)),
                  const Text('A stage in this roadmap',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Topic name',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: AppColors.divider)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: _roadmapAccent(_roadmap), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel',
                              style:
                                  TextStyle(color: AppColors.textSecondary))),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty) return;
                          await ref.read(roadmapsProvider.notifier).createTopic(
                              roadmapId: _roadmap.id,
                              title: title,
                              orderIndex: _topics.length);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _loadData();
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: _roadmapAccent(_roadmap),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteTopic(Topic topic) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete topic?'),
        content: Text(
            '“${topic.title}” will be removed. Its tasks will stay in Todow.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (delete != true || !mounted) return;
    await ref.read(roadmapsProvider.notifier).deleteTopic(topic.id);
    await _loadData();
  }

  Future<void> _editTopic(Topic topic) async {
    final edits = await showDialog<_PlanEdits>(
      context: context,
      builder: (_) => _PlanEditorDialog(
        entity: 'Topic',
        title: topic.title,
        description: topic.description ?? '',
        accent: _roadmapAccent(_roadmap),
      ),
    );
    if (edits != null && mounted) {
      await ref.read(roadmapsProvider.notifier).updateTopic(
            topic.copyWith(
              title: edits.title,
              description: edits.description,
              clearDescription: edits.description.isEmpty,
            ),
          );
      await _loadData();
    }
  }

  Future<void> _editRoadmap() async {
    final edits = await showDialog<_PlanEdits>(
      context: context,
      builder: (_) => _PlanEditorDialog(
        entity: 'Roadmap',
        title: _roadmap.title,
        description: _roadmap.description ?? '',
        accent: _roadmapAccent(_roadmap),
      ),
    );
    if (edits != null && mounted) {
      final edited = _roadmap.copyWith(
        title: edits.title,
        description: edits.description,
        clearDescription: edits.description.isEmpty,
      );
      await ref.read(roadmapsProvider.notifier).updateRoadmap(edited);
      if (mounted) setState(() => _roadmap = edited);
    }
  }

  Future<void> _confirmDeleteRoadmap() async {
    final deleteMode = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete roadmap?'),
        content: Text(
            '“${_roadmap.title}” will be removed. What do you want to do with its tasks?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, 1),
              child: const Text('Keep tasks')),
          TextButton(
              onPressed: () => Navigator.pop(context, 2),
              style: TextButton.styleFrom(foregroundColor: AppColors.alert),
              child: const Text('Delete all')),
        ],
      ),
    );
    if (deleteMode == null || deleteMode == 0 || !mounted) return;
    await ref.read(roadmapsProvider.notifier).deleteRoadmap(_roadmap.id, deleteTasks: deleteMode == 2);
    if (mounted) Navigator.of(context).pop();
  }
}

class _RoadmapModeSwitch extends StatelessWidget {
  const _RoadmapModeSwitch(
      {required this.dateView, required this.accent, required this.onChanged});

  final bool dateView;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _ModeOption(
              label: 'Roadmap',
              selected: !dateView,
              accent: accent,
              onTap: () => onChanged(false)),
          const SizedBox(width: 8),
          _ModeOption(
              label: 'By date',
              selected: dateView,
              accent: AppColors.action,
              onTap: () => onChanged(true)),
        ],
      );
}

class _ModeOption extends StatelessWidget {
  const _ModeOption(
      {required this.label,
      required this.selected,
      required this.accent,
      required this.onTap});

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? accent : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accent : accent.withValues(alpha: 0.24),
              ),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: TextStyle(
                    color: selected
                        ? (accent == AppColors.attention
                            ? AppColors.textPrimary
                            : Colors.white)
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

class _PlanEdits {
  const _PlanEdits(this.title, this.description);

  final String title;
  final String description;
}

class _PlanEditorDialog extends StatefulWidget {
  const _PlanEditorDialog({
    required this.entity,
    required this.title,
    required this.description,
    required this.accent,
  });

  final String entity;
  final String title;
  final String description;
  final Color accent;

  @override
  State<_PlanEditorDialog> createState() => _PlanEditorDialogState();
}

class _PlanEditorDialogState extends State<_PlanEditorDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.description);

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit ${widget.entity.toLowerCase()}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: _planFieldDecoration(
                    '${widget.entity} name', widget.accent),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: _planFieldDecoration(
                    'Description (optional)', widget.accent),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                      foregroundColor: widget.accent == AppColors.attention
                          ? AppColors.textPrimary
                          : Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    Navigator.pop(
      context,
      _PlanEdits(title, _description.text.trim()),
    );
  }
}

InputDecoration _planFieldDecoration(String label, Color accent) =>
    InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.accent,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.15);
    final fgColor =
        isPrimary ? (accent ?? AppColors.textPrimary) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: isPrimary
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: fgColor.withValues(alpha: 0.15),
          highlightColor: fgColor.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fgColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: fgColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarMenu extends StatelessWidget {
  const _ToolbarMenu({
    required this.onExportCsv,
    required this.onExportExcel,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onExportCsv;
  final VoidCallback onExportExcel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _ToolbarButton(
      icon: Icons.more_horiz_rounded,
      label: 'More',
      onTap: () {
        final renderBox = context.findRenderObject() as RenderBox;
        final offset = renderBox.localToGlobal(Offset.zero);
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + renderBox.size.height + 8,
            MediaQuery.of(context).size.width -
                offset.dx -
                renderBox.size.width,
            0,
          ),
          color: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          items: const [
            PopupMenuItem(value: 'edit', child: Text('Edit roadmap')),
            PopupMenuItem(value: 'csv', child: Text('Export CSV')),
            PopupMenuItem(value: 'excel', child: Text('Export Excel')),
            PopupMenuItem(value: 'delete', child: Text('Delete roadmap')),
          ],
        ).then((action) {
          if (action == 'csv') onExportCsv();
          if (action == 'excel') onExportExcel();
          if (action == 'edit') onEdit();
          if (action == 'delete') onDelete();
        });
      },
    );
  }
}

class _RoadmapProgress extends StatelessWidget {
  const _RoadmapProgress(
      {required this.topics, required this.tasks, required this.accent});

  final List<Topic> topics;
  final List<Task> tasks;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((t) => t.isCompleted).length;
    final progress = tasks.isEmpty ? 0.0 : completed / tasks.length;
    final pct = (progress * 100).round();
    final completedTopics =
        topics.where((t) => t.status == TopicStatus.completed).length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: accent,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'complete',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$completedTopics / ${topics.length} topics',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Animated progress bar
          TweenAnimationBuilder<double>(
            key: ValueKey(progress),
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$completed of ${tasks.length} tasks completed',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoadmap extends StatelessWidget {
  const _EmptyRoadmap({required this.onAddTopic});

  final VoidCallback onAddTopic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 28, 40, 40),
      child: Column(
        children: [
          const Text('No Topics yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Break this Roadmap into a few major stages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAddTopic,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Topic'),
          ),
        ],
      ),
    );
  }
}

Uint8List _xlsxBytes(List<List<String>> rows) {
  final sheetRows = [
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
      '<row r="${rowIndex + 1}">${[
        for (var columnIndex = 0;
            columnIndex < rows[rowIndex].length;
            columnIndex++)
          '<c r="${_excelColumn(columnIndex)}${rowIndex + 1}" t="inlineStr"><is><t xml:space="preserve">${_xmlEscape(rows[rowIndex][columnIndex])}</t></is></c>',
      ].join()}</row>',
  ].join();
  final files = <String, String>{
    '[Content_Types].xml':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>''',
    '_rels/.rels':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''',
    'xl/workbook.xml':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Roadmap" sheetId="1" r:id="rId1"/></sheets></workbook>''',
    'xl/_rels/workbook.xml.rels':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>''',
    'xl/worksheets/sheet1.xml':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$sheetRows</sheetData></worksheet>''',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final content = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, content.length, content));
  }
  final workbook = ZipEncoder().encode(archive);
  return Uint8List.fromList(workbook);
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

String _xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _excelColumn(int index) {
  var value = index + 1;
  var column = '';
  while (value > 0) {
    value--;
    column = String.fromCharCode(65 + value % 26) + column;
    value ~/= 26;
  }
  return column;
}

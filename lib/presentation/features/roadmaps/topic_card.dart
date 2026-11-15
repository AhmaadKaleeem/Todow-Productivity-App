import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/roadmap.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/presentation/features/tasks/task_editor_screen.dart';
import 'package:todow/presentation/features/tasks/task_providers.dart';

// Even index → card aligned left side; odd → right side.
// This drives the zigzag composition.
const _kActiveWidthFactor = 0.92;
const _kPendingWidthFactor = 0.80;
const _kCompletedWidthFactor = 0.76;

// Inline palette — mirrors roadmap_list_screen palette exactly.
const _kCardPalette = [
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

Color _accentFromRoadmap(Roadmap r) {
  final idx = r.colorIndex >= 0
      ? r.colorIndex % _kCardPalette.length
      : r.id.hashCode.abs() % _kCardPalette.length;
  return _kCardPalette[idx];
}

/// Lightens an accent by mixing toward white.
Color _lighten(Color c, double amt) => Color.lerp(c, Colors.white, amt)!;

/// Darkens an accent slightly.
Color _darken(Color c, double amt) =>
    Color.lerp(c, Colors.black, amt)!.withValues(alpha: c.a);

class TopicCard extends StatefulWidget {
  const TopicCard({
    required this.topic,
    required this.roadmap,
    required this.index,
    required this.onStatusChanged,
    required this.onTasksChanged,
    required this.onEdit,
    required this.onDelete,
    required this.tasks,
    required this.tasksExpanded,
    required this.onTasksExpanded,
    required this.cardKey,
    super.key,
  });

  final Topic topic;
  final Roadmap roadmap;
  final int index;
  final ValueChanged<TopicStatus> onStatusChanged;
  final VoidCallback onTasksChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<Task> tasks;
  final bool tasksExpanded;
  final ValueChanged<bool> onTasksExpanded;
  final GlobalKey cardKey;

  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  int get _completed => widget.tasks.where((t) => t.isCompleted).length;

  double get _progress {
    if (widget.topic.status == TopicStatus.completed) return 1;
    if (widget.tasks.isEmpty) return 0;
    return _completed / widget.tasks.length;
  }

  @override
  Widget build(BuildContext context) {
    final isLeft = widget.index.isEven;
    final status = widget.topic.status;
    final widthFactor = switch (status) {
      TopicStatus.active => _kActiveWidthFactor,
      TopicStatus.pending => _kPendingWidthFactor,
      TopicStatus.completed => _kCompletedWidthFactor,
    };
    final accent = _accentFromRoadmap(widget.roadmap);

    return ClipRect(
      child: AnimatedSize(
        key: widget.cardKey,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Align(
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              child: switch (status) {
                TopicStatus.active => _ActiveNode(
                    key: ValueKey('active-${widget.topic.id}'),
                    topic: widget.topic,
                    tasks: widget.tasks,
                    progress: _progress,
                    completed: _completed,
                    expanded: widget.tasksExpanded,
                    accent: accent,
                    onExpand: () {
                      widget.onTasksExpanded(!widget.tasksExpanded);
                    },
                    onTasksChanged: widget.onTasksChanged,
                    onStatusChanged: widget.onStatusChanged,
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                TopicStatus.completed => _CompletedNode(
                    key: ValueKey('completed-${widget.topic.id}'),
                    topic: widget.topic,
                    tasks: widget.tasks,
                    progress: _progress,
                    completed: _completed,
                    accent: accent,
                    onTap: () => widget.onStatusChanged(TopicStatus.active),
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
                TopicStatus.pending => _PendingNode(
                    key: ValueKey('pending-${widget.topic.id}'),
                    topic: widget.topic,
                    tasks: widget.tasks,
                    progress: _progress,
                    completed: _completed,
                    accent: accent,
                    onTap: () => widget.onStatusChanged(TopicStatus.active),
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── ACTIVE NODE ────────────────────────────────
// Largest, most dominant. Full gradient from roadmap accent, task list.

class _ActiveNode extends StatelessWidget {
  const _ActiveNode({
    super.key,
    required this.topic,
    required this.tasks,
    required this.progress,
    required this.completed,
    required this.expanded,
    required this.accent,
    required this.onExpand,
    required this.onTasksChanged,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  });

  final Topic topic;
  final List<Task> tasks;
  final double progress;
  final int completed;
  final bool expanded;
  final Color accent;
  final VoidCallback onExpand;
  final VoidCallback onTasksChanged;
  final ValueChanged<TopicStatus> onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final accentDark = _darken(accent, 0.22);
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NodeBadge(
                        label: 'CURRENT · ${_ordinal(topic.orderIndex)}',
                        color: Colors.white.withValues(alpha: 0.25),
                        textColor: Colors.white,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        topic.title,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.6,
                        ),
                      ),
                      if (topic.description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 6),
                        Text(
                          topic.description!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    _StatusButton(
                      tooltip: 'Mark ${topic.title} completed',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                      onTap: () => onStatusChanged(TopicStatus.completed),
                    ),
                    _TopicMenu(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Progress bar — always visible
            _NodeProgressBar(
              progress: progress,
              completed: completed,
              total: tasks.length,
              onDark: true,
            ),
            // Task list (expandable)
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 4),
              Divider(height: 32, color: Colors.white.withValues(alpha: 0.20)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onExpand,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Colors.white.withValues(alpha: 0.75),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        expanded ? 'Hide tasks' : 'Show ${tasks.length} tasks',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeOutCubic,
                crossFadeState: expanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    for (final task in tasks)
                      _TopicTaskRow(
                        task: task,
                        onChanged: onTasksChanged,
                        onDark: true,
                      ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 8),
            // Add task
            GestureDetector(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskEditorScreen(topicId: topic.id),
                  ),
                );
                onTasksChanged();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 17, color: Colors.white.withValues(alpha: 0.90)),
                    const SizedBox(width: 6),
                    Text(
                      'Add task',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.90),
                      ),
                    ),
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

// ─────────────────────────────── COMPLETED NODE ─────────────────────────────
// Smaller, quieter. Uses a tinted accent surface — settled, done.

class _CompletedNode extends StatelessWidget {
  const _CompletedNode({
    super.key,
    required this.topic,
    required this.tasks,
    required this.progress,
    required this.completed,
    required this.accent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Topic topic;
  final List<Task> tasks;
  final double progress;
  final int completed;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = _lighten(accent, 0.88);
    final border = accent.withValues(alpha: 0.28);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 148),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _NodeBadge(
                    label: 'COMPLETED · ${_ordinal(topic.orderIndex)}',
                    color: accent.withValues(alpha: 0.16),
                    textColor: _darken(accent, 0.1),
                    icon: Icons.check_rounded,
                  ),
                  const Spacer(),
                  _TopicMenu(onEdit: onEdit, onDelete: onDelete, onDark: false),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _darken(accent, 0.25),
                ),
              ),
              const SizedBox(height: 16),
              _NodeProgressBar(
                progress: progress,
                completed: completed,
                total: tasks.length,
                onDark: false,
                accent: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────── PENDING NODE ───────────────────────────────
// Medium. Softly tinted with the roadmap accent — visible but not dominant.

class _PendingNode extends StatelessWidget {
  const _PendingNode({
    super.key,
    required this.topic,
    required this.tasks,
    required this.progress,
    required this.completed,
    required this.accent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Topic topic;
  final List<Task> tasks;
  final double progress;
  final int completed;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bg = _lighten(accent, 0.94);
    final border = accent.withValues(alpha: 0.18);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 170),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _NodeBadge(
                    label: 'UP NEXT · ${_ordinal(topic.orderIndex)}',
                    color: accent.withValues(alpha: 0.12),
                    textColor: _darken(accent, 0.05),
                  ),
                  const Spacer(),
                  _TopicMenu(onEdit: onEdit, onDelete: onDelete, onDark: false),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                topic.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: _darken(accent, 0.3),
                ),
              ),
              if (topic.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  topic.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: accent.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _NodeProgressBar(
                progress: progress,
                completed: completed,
                total: tasks.length,
                onDark: false,
                accent: accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── SHARED WIDGETS ───────────────────────────────

class _NodeBadge extends StatelessWidget {
  const _NodeBadge({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeProgressBar extends StatelessWidget {
  const _NodeProgressBar({
    required this.progress,
    required this.completed,
    required this.total,
    required this.onDark,
    this.accent,
  });

  final double progress;
  final int completed;
  final int total;
  final bool onDark;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final barBg =
        onDark ? Colors.white.withValues(alpha: 0.22) : AppColors.divider;
    final barFg = onDark ? Colors.white : (accent ?? AppColors.attention);
    final textFg = onDark
        ? Colors.white.withValues(alpha: 0.80)
        : (accent?.withValues(alpha: 0.75) ?? AppColors.textSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: barBg,
                    valueColor: AlwaysStoppedAnimation(barFg),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: barFg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$completed / $total tasks',
          style: TextStyle(fontSize: 12, color: textFg),
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _TopicMenu extends StatelessWidget {
  const _TopicMenu(
      {required this.onEdit, required this.onDelete, this.onDark = true});

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool onDark;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        tooltip: 'Topic options',
        icon: Icon(Icons.more_horiz_rounded,
            color: onDark ? Colors.white70 : AppColors.textSecondary),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit topic')),
          PopupMenuItem(value: 'delete', child: Text('Delete topic')),
        ],
        onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
      );
}

class _TopicTaskRow extends ConsumerWidget {
  const _TopicTaskRow({
    required this.task,
    required this.onChanged,
    this.onDark = false,
  });

  final Task task;
  final VoidCallback onChanged;
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            IconButton(
              tooltip: task.isCompleted
                  ? 'Reopen ${task.title}'
                  : 'Complete ${task.title}',
              onPressed: () async {
                final ctrl = ref.read(tasksProvider.notifier);
                if (task.isCompleted) {
                  await ctrl.reopenTask(task.id);
                } else {
                  await ctrl.completeTask(task.id);
                }
                if (!context.mounted) return;
                onChanged();
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  task.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(task.isCompleted),
                  color: task.isCompleted
                      ? (onDark ? Colors.white : AppColors.action)
                      : (onDark
                          ? Colors.white.withValues(alpha: 0.65)
                          : AppColors.textSecondary),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TaskEditorScreen(task: task)),
                  );
                  if (!context.mounted) return;
                  onChanged();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: task.isCompleted
                          ? (onDark
                              ? Colors.white.withValues(alpha: 0.55)
                              : AppColors.textSecondary)
                          : (onDark ? Colors.white : AppColors.textPrimary),
                      decoration:
                          task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Task options',
              icon: Icon(Icons.more_vert_rounded,
                  size: 19,
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.65)
                      : AppColors.textSecondary),
              onSelected: (_) async {
                await ref.read(tasksProvider.notifier).deleteTask(task.id);
                if (!context.mounted) return;
                onChanged();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete task')),
              ],
            ),
          ],
        ),
      );
}

// Helpers
String _ordinal(int zeroIndex) => (zeroIndex + 1).toString().padLeft(2, '0');

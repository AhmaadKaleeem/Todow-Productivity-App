import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/subtask.dart';
import 'package:uuid/uuid.dart';

class SubtasksSection extends StatefulWidget {
  const SubtasksSection({
    super.key,
    required this.subtasks,
    required this.onChanged,
  });

  final List<Subtask> subtasks;
  final ValueChanged<List<Subtask>> onChanged;

  @override
  State<SubtasksSection> createState() => _SubtasksSectionState();
}

class _SubtasksSectionState extends State<SubtasksSection> {
  final _uuid = const Uuid();
  // Track which index was just added so we can autofocus it
  int? _newlyAddedIndex;

  void _addSubtask() {
    final newList = List<Subtask>.from(widget.subtasks);
    newList.add(Subtask(
      id: _uuid.v4(),
      taskId: '',
      title: '',
      isCompleted: false,
      sortOrder: newList.length,
    ));
    _newlyAddedIndex = newList.length - 1;
    widget.onChanged(newList);
  }

  void _updateSubtask(int index, Subtask updated) {
    final newList = List<Subtask>.from(widget.subtasks);
    newList[index] = updated;
    widget.onChanged(newList);
  }

  void _toggleSubtask(int index) {
    final newList = List<Subtask>.from(widget.subtasks);
    newList[index] =
        newList[index].copyWith(isCompleted: !newList[index].isCompleted);
    widget.onChanged(newList);
  }

  void _removeSubtask(int index) {
    final newList = List<Subtask>.from(widget.subtasks);
    newList.removeAt(index);
    widget.onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'SUBTASKS',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.5), width: 1),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 20,
                  offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              for (int i = 0; i < widget.subtasks.length; i++) ...[
                _SubtaskRow(
                  key: ValueKey(widget.subtasks[i].id),
                  subtask: widget.subtasks[i],
                  autofocus: _newlyAddedIndex == i,
                  onToggle: () => _toggleSubtask(i),
                  onChanged: (val) => _updateSubtask(i, val),
                  onDelete: () => _removeSubtask(i),
                  onSubmit: _addSubtask,
                ),
                Container(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
              ],
              InkWell(
                onTap: _addSubtask,
                borderRadius: widget.subtasks.isEmpty
                    ? BorderRadius.circular(24)
                    : const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: AppColors.action, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Add subtask',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.action),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubtaskRow extends StatefulWidget {
  const _SubtaskRow({
    super.key,
    required this.subtask,
    required this.autofocus,
    required this.onToggle,
    required this.onChanged,
    required this.onDelete,
    required this.onSubmit,
  });

  final Subtask subtask;
  final bool autofocus;
  final VoidCallback onToggle;
  final ValueChanged<Subtask> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;

  @override
  State<_SubtaskRow> createState() => _SubtaskRowState();
}

class _SubtaskRowState extends State<_SubtaskRow> {
  late TextEditingController _ctrl;
  late TextEditingController _descCtrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.subtask.title);
    _descCtrl = TextEditingController(text: widget.subtask.description);
    _focus = FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _descCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.subtask.isCompleted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.action : Colors.transparent,
                border: Border.all(
                    color: done ? AppColors.action : AppColors.divider,
                    width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 13, color: AppColors.surface)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  onChanged: (val) => widget.onChanged(widget.subtask.copyWith(title: val)),
                  onSubmitted: (_) => widget.onSubmit(),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: done ? AppColors.textSecondary : AppColors.textPrimary,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textSecondary,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    hintText: 'Subtask title…',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                TextField(
                  controller: _descCtrl,
                  onChanged: (val) => widget.onChanged(widget.subtask.copyWith(description: val)),
                  maxLines: null,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    hintText: 'Add description (optional)…',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w400),
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 8),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onDelete,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

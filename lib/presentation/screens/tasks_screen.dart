import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/core/utils/date_format.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/providers/task_providers.dart';

import 'package:todow/presentation/app.dart';
import 'package:todow/presentation/widgets/beautiful_back_button.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(visibleTasksProvider);
    
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 86,
        leading: const Center(child: Padding(padding: EdgeInsets.only(left: 16), child: BeautifulBackButton())),
        title: const Text('Tasks'),
        actions: [
          PopupMenuButton<TaskSort>(
            icon: const Icon(Icons.sort),
            onSelected: (sort) => ref.read(taskSortProvider.notifier).state = sort,
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: TaskSort.dueDateAsc, child: Text('Due soonest')),
              PopupMenuItem(
                  value: TaskSort.priorityDesc, child: Text('Priority')),
              PopupMenuItem(
                  value: TaskSort.createdDesc, child: Text('Recently added')),
              PopupMenuItem(value: TaskSort.titleAsc, child: Text('Title')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            controller: _search,
            onChanged: (val) => ref.read(taskSearchQueryProvider.notifier).state = val,
            decoration: const InputDecoration(
                hintText: 'Search tasks', prefixIcon: Icon(Icons.search)),
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text(err.toString())),
            data: (tasks) => tasks.isEmpty
                ? const AppEmptyState(
                    title: 'No tasks yet',
                    message: 'Capture the next thing you need to remember.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) =>
                        TaskRow(task: tasks[index]),
                  ),
          ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskEditorScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
    );
  }
}

class TaskRow extends ConsumerWidget {
  const TaskRow({required this.task, super.key});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tasksProvider.notifier);
    final dueColor =
        task.isOverdue ? AppColors.alert : AppColors.textSecondary;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        leading: IconButton(
          icon: Icon(
              task.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: task.isCompleted
                  ? AppColors.action
                  : AppColors.textSecondary),
          tooltip: task.isCompleted ? 'Reopen task' : 'Complete task',
          onPressed: () => task.isCompleted
              ? controller.reopenTask(task.id)
              : controller.completeTask(task.id),
        ),
        title: Text(task.title,
            style: TextStyle(
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null)),
        subtitle: Row(children: [
          if (task.dueAt != null)
            Text(AppDateFormat.dueLabel(task.dueAt),
                style: TextStyle(color: dueColor, fontSize: 12)),
          if (task.hasConstantReminder) ...[
            const SizedBox(width: 8),
            const Icon(Icons.notifications_active_outlined,
                size: 14, color: AppColors.alert)
          ],
          if (task.hasAttachments) ...[
            const SizedBox(width: 8),
            const Icon(Icons.attach_file, size: 14)
          ],
        ]),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskEditorScreen(task: task)));
            if (value == 'duplicate') await controller.duplicateTask(task.id);
            if (value == 'archive') await controller.archiveTask(task.id);
            if (value == 'delete') await controller.deleteTask(task.id);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            PopupMenuItem(value: 'archive', child: Text('Archive')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}



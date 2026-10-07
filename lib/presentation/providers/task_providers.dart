import 'dart:io';
import 'dart:isolate';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart' as open_filex;

import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/subtask.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/reminders/reminder_presets.dart';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/domain/models/query.dart';
import 'package:todow/data/services/thumbnail_generator.dart';
import 'package:todow/domain/attachment_limits.dart';
import 'package:todow/data/services/attachment_hasher.dart';
import 'package:todow/core/providers/service_providers.dart';

final taskSearchQueryProvider = StateProvider<String>((ref) => '');
final taskFilterProvider = StateProvider<TaskFilter>((ref) => TaskFilter.empty());
final taskSortProvider = StateProvider<TaskSort>((ref) => TaskSort.dueDateAsc);

final tasksProvider = AsyncNotifierProvider<TaskNotifier, List<Task>>(() => TaskNotifier());

class TaskNotifier extends AsyncNotifier<List<Task>> {
  static const _uuid = Uuid();

  @override
  Future<List<Task>> build() async {
    return ref.watch(taskRepositoryProvider).getAll();
  }

  Future<void> reload() async {
    final result = await AsyncValue.guard(() => ref.read(taskRepositoryProvider).getAll());
    state = result;
  }

  Future<Task?> getTask(String id) => ref.read(taskRepositoryProvider).getById(id);

  Future<Task> createTask({
    required String title,
    String description = '',
    TaskStatus status = TaskStatus.active,
    TaskPriority priority = TaskPriority.medium,
    int? sortOrder,
    DateTime? dueAt,
    DateTime? startAt,
    String? category,
    String? subject,
    String? topicId,
    List<String> tags = const [],
    ReminderPlan? reminderPlan,
    List<Subtask> subtasks = const [],
  }) async {
    if (title.trim().isEmpty) {
      throw TaskValidationException('Title is required.');
    }
    final now = DateTime.now();
    final plan = reminderPlan ?? ReminderPresets.defaultPlan();
    
    final currentTasks = state.valueOrNull ?? [];
    final int actualSortOrder = sortOrder ??
        (currentTasks.isEmpty
            ? 0
            : currentTasks.fold<int>(
                    0, (max, t) => t.sortOrder > max ? t.sortOrder : max) +
                1);

    final task = Task(
      id: _uuid.v4(),
      title: title.trim(),
      description: description.trim(),
      status: status,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      startAt: startAt,
      dueAt: dueAt,
      category: category,
      subject: subject,
      topicId: topicId,
      tags: tags,
      subtasks: subtasks,
      reminderPlan: plan,
      sortOrder: actualSortOrder,
    );
    final saved = await ref.read(taskRepositoryProvider).create(task);
    await ref.read(reminderSchedulerProvider).syncTaskReminders(saved);
    
    // Optimistic update
    state = AsyncValue.data([...(state.valueOrNull ?? []), saved]);
    
    // Background reload
    reload();
    return saved;
  }

  Future<Task> updateTask(Task task) async {
    if (task.title.trim().isEmpty) {
      throw TaskValidationException('Title is required.');
    }
    final updated = task.copyWith(updatedAt: DateTime.now());
    await ref.read(taskRepositoryProvider).update(updated);
    await ref.read(reminderSchedulerProvider).syncTaskReminders(updated);
    
    // Optimistic update
    final currentTasks = state.valueOrNull ?? [];
    final idx = currentTasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      final newTasks = List<Task>.from(currentTasks);
      newTasks[idx] = updated;
      state = AsyncValue.data(newTasks);
    } else {
      state = AsyncValue.data([...currentTasks, updated]);
    }
    
    // Background reload
    reload();
    return updated;
  }

  Future<void> completeTask(String id) async {
    final tasks = state.valueOrNull ?? [];
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = tasks[idx].copyWith(
      status: TaskStatus.completed,
      updatedAt: DateTime.now(),
    );
    
    // Optimistic update
    final newTasks = List<Task>.from(tasks);
    newTasks[idx] = updated;
    state = AsyncValue.data(newTasks);

    await ref.read(taskRepositoryProvider).update(updated);
    await ref.read(reminderSchedulerProvider).cancelTaskReminders(id);
  }

  Future<void> reopenTask(String id) async {
    final tasks = state.valueOrNull ?? [];
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = tasks[idx].copyWith(
      status: TaskStatus.active,
      updatedAt: DateTime.now(),
    );
    
    // Optimistic update
    final newTasks = List<Task>.from(tasks);
    newTasks[idx] = updated;
    state = AsyncValue.data(newTasks);

    await ref.read(taskRepositoryProvider).update(updated);
    await ref.read(reminderSchedulerProvider).syncTaskReminders(updated);
  }

  Future<void> archiveTask(String id) async {
    final tasks = state.valueOrNull ?? [];
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = tasks[idx].copyWith(
      status: TaskStatus.archived,
      updatedAt: DateTime.now(),
    );

    // Optimistic update
    final newTasks = List<Task>.from(tasks);
    newTasks[idx] = updated;
    state = AsyncValue.data(newTasks);

    await ref.read(taskRepositoryProvider).update(updated);
    await ref.read(reminderSchedulerProvider).cancelTaskReminders(id);
  }

  Future<void> deleteTask(String id) async {
    // Optimistic update
    final tasks = state.valueOrNull ?? [];
    state = AsyncValue.data(tasks.where((t) => t.id != id).toList());

    try {
      await ref.read(reminderSchedulerProvider).cancelTaskReminders(id);
    } catch (error) {
      debugPrint('Could not cancel reminders for deleted task $id: $error');
    }
    await ref.read(taskRepositoryProvider).delete(id);
    try {
      await ref.read(attachmentRepositoryProvider).deleteByTask(id);
      await ref.read(fileStorageProvider).deleteTaskFolder(id);
    } catch (error) {
      debugPrint('Could not remove attachments for task $id: $error');
    }
  }

  Future<void> togglePinTask(String id) async {
    final task = await ref.read(taskRepositoryProvider).getById(id);
    if (task == null) return;

    if (!task.isPinned) {
      final pinnedCount = (state.valueOrNull ?? []).where((t) => t.isPinned && !t.isCompleted).length;
      if (pinnedCount >= 5) {
        throw TaskValidationException('Maximum of 5 tasks can be pinned.');
      }
    }

    await updateTask(task.copyWith(isPinned: !task.isPinned));
  }

  Future<void> moveToInbox(String id) async {
    final task = await ref.read(taskRepositoryProvider).getById(id);
    if (task == null) return;
    await updateTask(task.copyWith(status: TaskStatus.inbox));
  }

  Future<void> activateFromInbox(String id) async {
    final task = await ref.read(taskRepositoryProvider).getById(id);
    if (task == null) return;
    await updateTask(task.copyWith(status: TaskStatus.active));
  }

  Future<void> duplicateTask(String id) async {
    final task = await ref.read(taskRepositoryProvider).getById(id);
    if (task == null) return;

    final newTaskId = _uuid.v4();
    final now = DateTime.now();

    final clonedSubtasks = task.subtasks
        .map((s) => Subtask(
              id: _uuid.v4(),
              taskId: newTaskId,
              title: s.title,
              isCompleted: false,
              sortOrder: s.sortOrder,
            ))
        .toList();

    final clonedTask = Task(
      id: newTaskId,
      title: task.title,
      description: task.description,
      status: TaskStatus.active,
      priority: task.priority,
      createdAt: now,
      updatedAt: now,
      startAt: task.startAt,
      dueAt: task.dueAt,
      category: task.category,
      tags: List.from(task.tags),
      subtasks: clonedSubtasks,
      attachments: const [],
      reminderPlan: task.reminderPlan,
      sourceType: task.sourceType,
      sourceId: task.sourceId,
    );

    final saved = await ref.read(taskRepositoryProvider).create(clonedTask);
    await ref.read(reminderSchedulerProvider).syncTaskReminders(saved);
    await reload();
  }

  Future<void> reorderTask(int oldIndex, int newIndex) async {
    final allTasks = List<Task>.from(state.valueOrNull ?? []);
    final active = allTasks.where((t) => t.status == TaskStatus.active).toList();
    if (oldIndex < newIndex) newIndex -= 1;
    final task = active.removeAt(oldIndex);
    active.insert(newIndex, task);
    
    // Update sortOrder in the active list
    for (int i = 0; i < active.length; i++) {
      if (active[i].sortOrder != i) {
        active[i] = active[i].copyWith(sortOrder: i, updatedAt: DateTime.now());
      }
    }

    // Merge active list back into allTasks
    final activeIds = active.map((t) => t.id).toSet();
    allTasks.removeWhere((t) => activeIds.contains(t.id));
    allTasks.addAll(active);
    
    // Optimistic update
    state = AsyncValue.data(allTasks);

    // Save to DB
    for (final updatedTask in active) {
      await ref.read(taskRepositoryProvider).update(updatedTask);
    }
  }

  Future<void> insertTaskBelow(String taskId, String newTitle) async {
    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Title cannot be empty');
    }

    final allTasks = state.valueOrNull ?? [];
    final active = allTasks.where((t) => t.status == TaskStatus.active).toList();
    final index = active.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final newTask = await createTask(
      title: trimmedTitle,
      sortOrder: index + 1,
    );

    for (int i = index + 1; i < active.length; i++) {
      if (active[i].id != newTask.id) {
        final updated = active[i].copyWith(sortOrder: i + 1, updatedAt: DateTime.now());
        await ref.read(taskRepositoryProvider).update(updated);
      }
    }
    await reload();
  }
}

class TaskValidationException implements Exception {
  TaskValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

final visibleTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasksAsync = ref.watch(tasksProvider);
  final query = ref.watch(taskSearchQueryProvider);
  final filter = ref.watch(taskFilterProvider);
  final sort = ref.watch(taskSortProvider);

  return tasksAsync.whenData((tasks) {
    return applyQuery(tasks, SearchQuery(text: query, filter: filter, sort: sort));
  });
});

final inboxTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  return ref.watch(tasksProvider).whenData((tasks) =>
      tasks.where((t) => t.status == TaskStatus.inbox && t.topicId == null).toList());
});

final activeTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  return ref.watch(tasksProvider).whenData((tasks) =>
      tasks.where((t) => t.status == TaskStatus.active).toList());
});

final overdueTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  return ref.watch(tasksProvider).whenData((tasks) =>
      tasks.where((t) => t.isOverdue && t.status == TaskStatus.active).toList());
});

final todayTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  return ref.watch(tasksProvider).whenData((tasks) =>
      tasks.where((t) => t.isDueToday && t.status == TaskStatus.active).toList());
});

final upcomingTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  return ref.watch(tasksProvider).whenData((tasks) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final upcoming = tasks.where((t) {
      if (t.dueAt == null || t.status != TaskStatus.active) return false;
      final dueDay = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      return dueDay.isAfter(tomorrow.subtract(const Duration(days: 1))) &&
          !t.isDueToday &&
          !t.isOverdue;
    }).toList();
    upcoming.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return upcoming;
  });
});

// Attachments Providers
final taskAttachmentsProvider = FutureProvider.family<List<Attachment>, String>((ref, taskId) {
  return ref.watch(attachmentRepositoryProvider).getByTask(taskId);
});

final taskAttachmentCountsProvider = FutureProvider.family<Map<String, int>, List<String>>((ref, taskIds) {
  return ref.watch(attachmentRepositoryProvider).countsByTaskIds(taskIds);
});

final taskAttachmentsNotifierProvider = Provider((ref) => TaskAttachmentsNotifier(ref));

class TaskAttachmentsNotifier {
  final Ref ref;
  static const _uuid = Uuid();

  TaskAttachmentsNotifier(this.ref);

  Future<void> renameAttachment(String attachmentId, String newFilename) async {
    final trimmed = newFilename.trim();
    if (trimmed.isEmpty) throw ArgumentError('Filename cannot be empty or whitespace');
    if (trimmed.contains('/') || trimmed.contains('\\')) throw ArgumentError('Filename cannot contain path separators');
    if (trimmed.length > 200) throw ArgumentError('Filename cannot exceed 200 characters');
    
    await ref.read(attachmentRepositoryProvider).updateFilename(attachmentId, trimmed);
    ref.invalidate(taskAttachmentsProvider);
  }

  Future<Attachment> attachFile(String taskId, String sourcePath, String filename, String mimeType) async {
    final file = File(sourcePath);
    final sizeBytes = await file.length();
    validateAttachment(filename, sizeBytes);

    final attachmentId = _uuid.v4();
    final contentHash = await hashFile(sourcePath);

    final dotIndex = filename.lastIndexOf('.');
    final ext = (dotIndex != -1 && dotIndex < filename.length - 1)
        ? filename.substring(dotIndex).toLowerCase()
        : '';
    await ref.read(fileStorageProvider).save(taskId, attachmentId, sourcePath, ext);

    if (mimeType.startsWith('image/')) {
      final thumbPath = ref.read(fileStorageProvider).thumbnailPath(taskId, attachmentId);
      await Isolate.run(() => ThumbnailGenerator().generate(
            sourcePath: sourcePath,
            outputPath: thumbPath,
          ));
    }

    final attachment = Attachment(
      id: attachmentId,
      taskId: taskId,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      contentHash: contentHash,
      syncState: AttachmentSyncState.localOnly,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await ref.read(attachmentRepositoryProvider).create(attachment);
    ref.invalidate(taskAttachmentsProvider(taskId));
    ref.invalidate(taskAttachmentCountsProvider);
    return attachment;
  }

  Future<void> removeAttachment(String attachmentId) async {
    final att = await ref.read(attachmentRepositoryProvider).getById(attachmentId);
    if (att == null) return;

    await ref.read(fileStorageProvider).delete(att.taskId, att.id);
    await ref.read(attachmentRepositoryProvider).delete(attachmentId);
    ref.invalidate(taskAttachmentsProvider(att.taskId));
    ref.invalidate(taskAttachmentCountsProvider);
  }

  Future<void> openAttachment(Attachment att) async {
    final path = await ref.read(fileStorageProvider).absolutePath(att.taskId, att.id);
    await open_filex.OpenFilex.open(path);
  }
}

import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/subtask.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/reminders/reminder_presets.dart';
import 'dart:io';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/domain/repositories/task_repository.dart';
import 'package:todow/domain/models/query.dart';
import 'package:todow/domain/repositories/attachment_repository.dart';
import 'package:todow/domain/services/file_storage.dart';
import 'package:todow/domain/services/reminder_scheduler.dart';
import 'dart:isolate';
import 'package:todow/data/services/thumbnail_generator.dart';
import 'package:todow/domain/attachment_limits.dart';
import 'package:todow/data/services/attachment_hasher.dart';
import 'package:uuid/uuid.dart';

import 'package:open_filex/open_filex.dart' as open_filex;

class TaskController extends ChangeNotifier {
  TaskController(
    this._repo,
    this._scheduler,
    this._attachmentRepo,
    this._fileStorage,
  );

  final TaskRepository _repo;
  final ReminderScheduler _scheduler;
  final AttachmentRepository _attachmentRepo;
  final FileStorage _fileStorage;
  static const _uuid = Uuid();

  List<Task> _allTasks = [];
  String _query = '';
  TaskFilter _filter = TaskFilter.empty();
  TaskSort _sort = TaskSort.dueDateAsc;
  String? _error;
  bool _loading = false;

  List<Task> get tasks => List.unmodifiable(_allTasks);
  List<Task> get visibleTasks => applyQuery(
      _allTasks, SearchQuery(text: _query, filter: _filter, sort: _sort));

  String get query => _query;
  TaskFilter get filter => _filter;
  TaskSort get sort => _sort;
  String? get error => _error;
  bool get loading => _loading;

  List<Task> get inboxTasks => _allTasks
      .where((t) => t.status == TaskStatus.inbox && t.topicId == null)
      .toList();

  List<Task> get activeTasks =>
      _allTasks.where((t) => t.status == TaskStatus.active).toList();

  List<Task> get overdueTasks => _allTasks
      .where((t) => t.isOverdue && t.status == TaskStatus.active)
      .toList();

  List<Task> get todayTasks => _allTasks
      .where((t) => t.isDueToday && t.status == TaskStatus.active)
      .toList();

  List<Task> get upcomingTasks {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return _allTasks.where((t) {
      if (t.dueAt == null || t.status != TaskStatus.active) return false;
      final dueDay = DateTime(t.dueAt!.year, t.dueAt!.month, t.dueAt!.day);
      return dueDay.isAfter(tomorrow.subtract(const Duration(days: 1))) &&
          !t.isDueToday &&
          !t.isOverdue;
    }).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  Future<void> loadTasks({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      _allTasks = await _repo.getAll();
    } catch (e) {
      if (!silent) _error = 'Could not load tasks. Please try again.';
    } finally {
      if (!silent) {
        _loading = false;
        notifyListeners();
      } else {
        notifyListeners();
      }
    }
  }

  void syncTasks(List<Task> newTasks) {
    _allTasks = newTasks;
    notifyListeners();
  }

  Timer? _queryDebounce;

  @override
  void dispose() {
    _queryDebounce?.cancel();
    super.dispose();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _queryDebounce?.cancel();
    _queryDebounce = Timer(const Duration(milliseconds: 150), () {
      _query = value;
      notifyListeners();
    });
  }

  void setFilter(TaskFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSort(TaskSort sort) {
    _sort = sort;
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    _filter = TaskFilter.empty();
    _sort = TaskSort.manual;
    notifyListeners();
  }

  Future<Task?> getTask(String id) => _repo.getById(id);

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
    bool skipReload = false,
  }) async {
    if (title.trim().isEmpty) {
      throw TaskValidationException('Title is required.');
    }
    final now = DateTime.now();
    final plan = reminderPlan ?? ReminderPresets.defaultPlan();
    final int actualSortOrder = sortOrder ??
        (_allTasks.isEmpty
            ? 0
            : _allTasks.fold<int>(
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
    final saved = await _repo.create(task);
    await _scheduler.syncTaskReminders(saved);
    
    _allTasks = [..._allTasks, saved];
    notifyListeners();
    
    if (!skipReload) await loadTasks(silent: true);
    return saved;
  }

  Future<Task> updateTask(Task task, {bool skipReload = false}) async {
    if (task.title.trim().isEmpty) {
      throw TaskValidationException('Title is required.');
    }
    final updated = task.copyWith(updatedAt: DateTime.now());
    await _repo.update(updated);
    await _scheduler.syncTaskReminders(updated);
    
    final idx = _allTasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      _allTasks[idx] = updated;
    } else {
      _allTasks = [..._allTasks, updated];
    }
    notifyListeners();
    
    if (!skipReload) await loadTasks(silent: true);
    return updated;
  }

  Future<void> completeTask(String id) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = _allTasks[idx].copyWith(
      status: TaskStatus.completed,
      updatedAt: DateTime.now(),
    );
    _allTasks[idx] = updated;
    notifyListeners();
    await _repo.update(updated);
    await _scheduler.cancelTaskReminders(id);
  }

  Future<void> reopenTask(String id) async {
    final idx = _allTasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = _allTasks[idx].copyWith(
      status: TaskStatus.active,
      updatedAt: DateTime.now(),
    );
    _allTasks[idx] = updated;
    notifyListeners();
    await _repo.update(updated);
    await _scheduler.syncTaskReminders(updated);
  }

  Future<void> archiveTask(String id) async {
    final task = await _repo.getById(id);
    if (task == null) return;
    final updated = task.copyWith(
      status: TaskStatus.archived,
      updatedAt: DateTime.now(),
    );
    await _repo.update(updated);
    await _scheduler.cancelTaskReminders(id);
    await loadTasks();
  }

  Future<void> deleteTask(String id) async {
    try {
      await _scheduler.cancelTaskReminders(id);
    } catch (error) {
      debugPrint('Could not cancel reminders for deleted task $id: $error');
    }
    await _repo.delete(id);
    _allTasks.removeWhere((task) => task.id == id);
    notifyListeners();
    try {
      await _attachmentRepo.deleteByTask(id);
      await _fileStorage.deleteTaskFolder(id);
    } catch (error) {
      debugPrint('Could not remove attachments for task $id: $error');
    }
    await loadTasks(silent: true);
  }

  Future<void> togglePinTask(String id) async {
    final task = await _repo.getById(id);
    if (task == null) return;

    if (!task.isPinned) {
      final pinnedCount = _allTasks.where((t) => t.isPinned && !t.isCompleted).length;
      if (pinnedCount >= 5) {
        throw TaskValidationException('Maximum of 5 tasks can be pinned.');
      }
    }

    await updateTask(task.copyWith(isPinned: !task.isPinned), skipReload: false);
  }

  Future<void> moveToInbox(String id) async {
    final task = await _repo.getById(id);
    if (task == null) return;
    await updateTask(task.copyWith(status: TaskStatus.inbox));
  }

  Future<void> activateFromInbox(String id) async {
    final task = await _repo.getById(id);
    if (task == null) return;
    await updateTask(task.copyWith(status: TaskStatus.active));
  }

  Future<void> duplicateTask(String id) async {
    final task = await _repo.getById(id);
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

    final saved = await _repo.create(clonedTask);
    await _scheduler.syncTaskReminders(saved);
    await loadTasks();
  }

  Future<List<ScheduledReminder>> activeReminders() =>
      _repo.getActiveReminders();

  Future<List<Attachment>> getAttachments(String taskId) =>
      _attachmentRepo.getByTask(taskId);

  String getThumbnailPath(String taskId, String attachmentId) =>
      _fileStorage.thumbnailPath(taskId, attachmentId);

  Future<void> renameAttachment(String attachmentId, String newFilename) async {
    final trimmed = newFilename.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Filename cannot be empty or whitespace');
    }
    if (trimmed.contains('/') || trimmed.contains('\\')) {
      throw ArgumentError('Filename cannot contain path separators');
    }
    if (trimmed.length > 200) {
      throw ArgumentError('Filename cannot exceed 200 characters');
    }
    await _attachmentRepo.updateFilename(attachmentId, trimmed);
  }

  Future<Map<String, int>> attachmentCounts(List<String> taskIds) =>
      _attachmentRepo.countsByTaskIds(taskIds);

  Future<Attachment> attachFile(String taskId, String sourcePath,
      String filename, String mimeType) async {
    final file = File(sourcePath);
    final sizeBytes = await file.length();

    validateAttachment(filename, sizeBytes);

    final attachmentId = _uuid.v4();
    final contentHash = await hashFile(sourcePath);

    final dotIndex = filename.lastIndexOf('.');
    final ext = (dotIndex != -1 && dotIndex < filename.length - 1)
        ? filename.substring(dotIndex).toLowerCase()
        : '';
    await _fileStorage.save(taskId, attachmentId, sourcePath, ext);

    if (mimeType.startsWith('image/')) {
      final thumbPath = _fileStorage.thumbnailPath(taskId, attachmentId);
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

    await _attachmentRepo.create(attachment);
    await loadTasks();
    return attachment;
  }

  Future<void> removeAttachment(String attachmentId) async {
    final att = await _attachmentRepo.getById(attachmentId);
    if (att == null) return;

    await _fileStorage.delete(att.taskId, att.id);
    await _attachmentRepo.delete(attachmentId);
    await loadTasks();
  }

  Future<void> openAttachment(Attachment att) async {
    final path = await _fileStorage.absolutePath(att.taskId, att.id);
    await open_filex.OpenFilex.open(path);
  }

  Future<void> reorderTask(int oldIndex, int newIndex) async {
    final active = List.of(activeTasks);
    if (oldIndex < newIndex) newIndex -= 1;
    final task = active.removeAt(oldIndex);
    active.insert(newIndex, task);
    for (int i = 0; i < active.length; i++) {
      if (active[i].sortOrder != i) {
        await updateTask(active[i].copyWith(sortOrder: i), skipReload: true);
      }
    }
    await loadTasks();
  }

  Future<void> insertTaskBelow(String taskId, String newTitle) async {
    final trimmedTitle = newTitle.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Title cannot be empty');
    }

    final active = List.of(activeTasks);
    final index = active.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final newTask = await createTask(
      title: trimmedTitle,
      sortOrder: index + 1,
    );

    for (int i = index + 1; i < active.length; i++) {
      if (active[i].id != newTask.id) {
        await updateTask(active[i].copyWith(sortOrder: i + 1),
            skipReload: true);
      }
    }
    await loadTasks();
  }
}

class TaskValidationException implements Exception {
  TaskValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/repositories/attachment_repository.dart';
import 'package:todow/domain/repositories/task_repository.dart';
import 'package:todow/domain/services/file_storage.dart';
import 'package:todow/domain/services/reminder_scheduler.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';


import 'package:todow/domain/models/reminder.dart';

class MockTaskRepository implements TaskRepository {
  final Map<String, Task> _tasks = {};
  @override
  Future<Task> create(Task task) async {
    _tasks[task.id] = task;
    return task;
  }
  @override
  Future<void> delete(String id) async => _tasks.remove(id);
  @override
  Future<List<Task>> getAll({TaskStatus? status, String? query, List<String>? tags}) async => _tasks.values.toList();
  @override
  Future<List<ScheduledReminder>> getActiveReminders() async => [];
  @override
  Future<List<ScheduledReminder>> getRemindersForTask(String taskId) async => [];
  @override
  Future<void> saveReminders(String taskId, List<ScheduledReminder> reminders) async {}
  @override
  Future<void> updateReminder(ScheduledReminder reminder) async {}
  @override
  Future<Task?> getById(String id) async => _tasks[id];
  @override
  Future<Task> update(Task task) async {
    _tasks[task.id] = task;
    return task;
  }
  // Ignore others
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAttachmentRepository implements AttachmentRepository {
  List<String> deletedTaskIds = [];
  List<Attachment> attachments = [];
  
  @override
  Future<void> deleteByTask(String taskId) async {
    deletedTaskIds.add(taskId);
    attachments.removeWhere((a) => a.taskId == taskId);
  }
  @override
  Future<List<Attachment>> getByTask(String taskId) async => attachments.where((a) => a.taskId == taskId).toList();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFileStorage implements FileStorage {
  List<String> deletedTaskFolders = [];
  @override
  Future<void> deleteTaskFolder(String taskId) async {
    deletedTaskFolders.add(taskId);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockReminderScheduler implements ReminderScheduler {
  @override
  Future<void> cancelTaskReminders(String taskId) async {}
  @override
  Future<void> recoverPendingReminders() async {}
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('deleteTask(id) cascades to attachmentRepository and fileStorage', () async {
    final taskRepo = MockTaskRepository();
    final attRepo = MockAttachmentRepository();
    final fileStorage = MockFileStorage();
    
    // We mock AttachmentService to pass it? No, the spec wants TaskController to call these directly or through a service.
    // If the controller takes AttachmentRepository and FileStorage directly:
    final controller = TaskController(
      taskRepo,
      MockReminderScheduler(),
      attRepo, // Assuming we pass these or a service wrapper
      fileStorage, // We will update the constructor of TaskController
    );

    final taskId = 'task-1';
    await taskRepo.create(Task(
      id: taskId,
      title: 'test',
      description: '',
      status: TaskStatus.active,
      priority: TaskPriority.medium,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      tags: [],
    ));
    
    attRepo.attachments.add(Attachment(
      id: 'att-1',
      taskId: taskId,
      filename: 'f.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 100,
      contentHash: 'a'*64,
      syncState: AttachmentSyncState.localOnly,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));

    await controller.deleteTask(taskId);

    expect(attRepo.deletedTaskIds, contains(taskId));
    expect(fileStorage.deletedTaskFolders, contains(taskId));
    
    final remaining = await controller.getAttachments(taskId);
    expect(remaining, isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/subtask.dart';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';
import 'package:todow/domain/repositories/task_repository.dart';
import 'package:todow/domain/services/reminder_scheduler.dart';
import 'package:todow/domain/repositories/attachment_repository.dart';
import 'package:todow/domain/services/file_storage.dart';
import 'package:todow/domain/models/reminder.dart';

class MockTaskRepository implements TaskRepository {
  final Map<String, Task> _tasks = {};

  @override
  Future<Task> create(Task task) async {
    _tasks[task.id] = task;
    return task;
  }

  @override
  Future<Task?> getById(String id) async => _tasks[id];

  @override
  Future<List<Task>> getAll(
      {TaskStatus? status, String? query, List<String>? tags}) async {
    var list = _tasks.values.toList();
    if (status != null) list = list.where((t) => t.status == status).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<Task> update(Task task) async {
    _tasks[task.id] = task;
    return task;
  }

  @override
  Future<void> delete(String id) async {
    _tasks.remove(id);
  }

  @override
  Future<List<ScheduledReminder>> getActiveReminders() async => [];

  @override
  Future<List<ScheduledReminder>> getRemindersForTask(String taskId) async =>
      [];

  @override
  Future<void> saveReminders(
      String taskId, List<ScheduledReminder> reminders) async {}

  @override
  Future<void> updateReminder(ScheduledReminder reminder) async {}
}

class MockReminderScheduler implements ReminderScheduler {
  @override
  Future<void> syncTaskReminders(Task task) async {}
  @override
  Future<void> cancelTaskReminders(String taskId) async {}
  Future<void> cancelAll() async {}
  @override
  Future<void> markReminderHandled(String reminderId) async {}
  @override
  Future<void> rescheduleConstantReminder(Task task) async {}
  @override
  Future<void> snoozeReminder(
      ScheduledReminder reminder, Duration duration) async {}
  @override
  Future<void> recoverPendingReminders() async {}
}

class MockAttachmentRepository implements AttachmentRepository {
  final Map<String, Attachment> _attachments = {};

  @override
  Future<Attachment> create(Attachment a) async {
    _attachments[a.id] = a;
    return a;
  }

  @override
  Future<List<Attachment>> getByTask(String taskId) async =>
      _attachments.values.where((a) => a.taskId == taskId).toList();
  @override
  Future<Attachment?> getById(String id) async => _attachments[id];
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteByTask(String taskId) async {}
  @override
  Future<int> countByTask(String taskId) async => 0;
  @override
  Future<Map<String, int>> countsByTaskIds(List<String> ids) async => {};
  @override
  Future<void> updateFilename(String id, String newFilename) async {
    final a = _attachments[id];
    if (a != null) {
      _attachments[id] = a.copyWith(filename: newFilename);
    }
  }

  @override
  Future<List<Attachment>> getAll() async => _attachments.values.toList();
}

class MockFileStorage implements FileStorage {
  @override
  Future<String> save(String taskId, String attachmentId, String sourcePath,
          String extension) async =>
      '';
  @override
  Future<void> delete(String taskId, String attachmentId) async {}
  @override
  Future<void> deleteTaskFolder(String taskId) async {}
  @override
  Future<String> absolutePath(String taskId, String attachmentId) async => '';
  @override
  String thumbnailPath(String taskId, String attachmentId) => 'dummy.jpg';
}

void main() {
  test('inbox excludes tasks assigned to roadmap topics', () async {
    final repo = MockTaskRepository();
    final now = DateTime(2026);
    Task inboxTask(String id, {String? topicId}) => Task(
          id: id,
          title: id,
          description: '',
          status: TaskStatus.inbox,
          priority: TaskPriority.medium,
          createdAt: now,
          updatedAt: now,
          topicId: topicId,
        );
    await repo.create(inboxTask('inbox-task'));
    await repo.create(inboxTask('roadmap-task', topicId: 'topic-1'));
    final controller = TaskController(
      repo,
      MockReminderScheduler(),
      MockAttachmentRepository(),
      MockFileStorage(),
    );

    await controller.loadTasks();

    expect(controller.inboxTasks.map((task) => task.id), ['inbox-task']);
  });

  test('createTask persists its optional topic assignment', () async {
    final controller = TaskController(
      MockTaskRepository(),
      MockReminderScheduler(),
      MockAttachmentRepository(),
      MockFileStorage(),
    );

    final task = await controller.createTask(
      title: 'Read linked material',
      topicId: 'topic-1',
    );

    expect(task.topicId, 'topic-1');
  });

  test(
      'duplicateTask creates a copy of the task with a new ID and active status',
      () async {
    final mockRepo = MockTaskRepository();
    final mockScheduler = MockReminderScheduler();
    final mockAttachments = MockAttachmentRepository();
    final mockFileStorage = MockFileStorage();

    final controller = TaskController(
        mockRepo, mockScheduler, mockAttachments, mockFileStorage);

    // Seed mock repo with original task
    final original = Task(
      id: '1',
      title: 'Buy milk',
      description: '',
      status: TaskStatus.completed,
      priority: TaskPriority.high,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      dueAt: DateTime(2025),
      subtasks: [
        Subtask(
            id: 's1',
            taskId: '1',
            title: 'Go to store',
            isCompleted: true,
            sortOrder: 0)
      ],
      reminderPlan: ReminderPlan(
          preset: ReminderPreset.normal, offsets: [], constantReminder: false),
    );
    await mockRepo.create(original);

    // Perform duplication
    await controller.duplicateTask('1');

    // Verify results
    final tasks = await mockRepo.getAll();
    expect(tasks.length, 2, reason: 'A new task should be created');

    final duplicate = tasks.firstWhere((t) => t.id != '1');
    expect(duplicate.title, 'Buy milk', reason: 'Title should match');
    expect(duplicate.dueAt, original.dueAt, reason: 'Due date should match');
    expect(duplicate.priority, TaskPriority.high,
        reason: 'Priority should match');
    expect(duplicate.isCompleted, false,
        reason: 'Status defaults to active (incomplete)');
    expect(duplicate.subtasks.length, 1, reason: 'Subtasks should be cloned');
    expect(duplicate.subtasks.first.isCompleted, false,
        reason: 'Cloned subtasks are reset to incomplete');
    expect(duplicate.subtasks.first.id, isNot('s1'),
        reason: 'Cloned subtasks have new IDs');
    expect(duplicate.subtasks.first.taskId, duplicate.id,
        reason: 'Cloned subtasks point to new task ID');
  });
}

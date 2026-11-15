import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todow/data/local/app_database.dart';
import 'package:todow/data/local/attachment_repository_impl.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';
import 'package:todow/domain/repositories/task_repository.dart';
import 'package:todow/domain/services/file_storage.dart';
import 'package:todow/domain/services/reminder_scheduler.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/reminder.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/attachment.dart';

// Dummy mocks for dependencies
class MockTaskRepo implements TaskRepository {
  @override
  Future<Task> create(Task task) async => task;
  @override
  Future<Task?> getById(String id) async => null;
  @override
  Future<List<Task>> getAll({TaskStatus? status, String? query, List<String>? tags}) async => [];
  @override
  Future<Task> update(Task task) async => task;
  @override
  Future<void> delete(String id) async {}
  
  @override
  Future<List<ScheduledReminder>> getActiveReminders() async => [];
  @override
  Future<List<ScheduledReminder>> getRemindersForTask(String taskId) async => [];
  @override
  Future<void> saveReminders(String taskId, List<ScheduledReminder> reminders) async {}
  @override
  Future<void> updateReminder(ScheduledReminder reminder) async {}
}

class MockFileStorage implements FileStorage {
  @override
  Future<String> absolutePath(String taskId, String attachmentId) async => '';
  @override
  Future<void> delete(String taskId, String attachmentId) async {}
  @override
  Future<void> deleteTaskFolder(String taskId) async {}
  @override
  Future<String> save(String taskId, String attachmentId, String sourcePath, String extension) async => '';
  @override
  String thumbnailPath(String taskId, String attachmentId) => '';
}

class MockReminderScheduler implements ReminderScheduler {
  @override
  Future<void> cancelTaskReminders(String taskId) async {}
  @override
  Future<void> snoozeReminder(ScheduledReminder reminder, Duration duration) async {}
  @override
  Future<void> syncTaskReminders(Task task) async {}
  @override
  Future<void> markReminderHandled(String id) async {}
  @override
  Future<void> rescheduleConstantReminder(Task task) async {}
  @override
  Future<void> recoverPendingReminders() async {}
}

void main() {
  late AppDatabase db;
  late AttachmentRepositoryImpl repo;
  late TaskController controller;
  late Attachment testAttachment;

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await AppDatabase.open(inMemoryDatabasePath);
    repo = AttachmentRepositoryImpl(db.db);
    
    controller = TaskController(
      MockTaskRepo(),
      MockReminderScheduler(),
      repo,
      MockFileStorage(),
    );

    final now = DateTime.now();
    testAttachment = Attachment(
      id: 'att-1',
      taskId: 'task-1',
      filename: 'old.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 100,
      contentHash: 'a' * 64,
      syncState: AttachmentSyncState.localOnly,
      createdAt: now,
      updatedAt: now,
    );
    await repo.create(testAttachment);
  });

  tearDown(() async {
  });

  test('renameAttachment with empty string throws ArgumentError', () async {
    await expectLater(
      () => controller.renameAttachment('att-1', ''),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('renameAttachment with whitespace-only string throws ArgumentError', () async {
    await expectLater(
      () => controller.renameAttachment('att-1', '   '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('renameAttachment with ".." throws ArgumentError', () async {
    await expectLater(
      () => controller.renameAttachment('att-1', 'a/../b'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('renameAttachment with "a/b.pdf" throws ArgumentError', () async {
    await expectLater(
      () => controller.renameAttachment('att-1', 'a/b.pdf'),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      () => controller.renameAttachment('att-1', 'a\\b.pdf'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('renameAttachment with valid "New name.pdf" updates the DB and updated_at, leaves content_hash unchanged', () async {
    final before = await repo.getById('att-1');
    expect(before!.filename, 'old.pdf');

    await Future.delayed(const Duration(milliseconds: 10)); // Ensure time diff
    await controller.renameAttachment('att-1', 'New name.pdf');

    final after = await repo.getById('att-1');
    expect(after!.filename, 'New name.pdf');
    expect(after.contentHash, before.contentHash);
    expect(after.updatedAt.isAfter(before.updatedAt), isTrue);
  });
}

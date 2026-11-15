import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todow/core/providers/service_providers.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/presentation/features/tasks/task_editor_screen.dart';

import 'task_controller_test.dart';

class _FailingTaskRepo extends MockTaskRepository {
  @override
  Future<Task> update(Task task) async {
    throw Exception('Simulated database failure');
  }
}

void main() {
  testWidgets('TaskEditorScreen saves edits and pops cleanly without getting stuck', (tester) async {
    final mockRepo = MockTaskRepository();
    final mockScheduler = MockReminderScheduler();
    final mockAttachmentRepo = MockAttachmentRepository();
    final mockStorage = MockFileStorage();

    final existingTask = Task(
      id: 'task-101',
      title: 'Original Title',
      description: 'Original Description',
      status: TaskStatus.active,
      priority: TaskPriority.medium,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await mockRepo.create(existingTask);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(mockRepo),
          reminderSchedulerProvider.overrideWithValue(mockScheduler),
          attachmentRepositoryProvider.overrideWithValue(mockAttachmentRepo),
          fileStorageProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskEditorScreen(task: existingTask),
                      ),
                    );
                  },
                  child: const Text('Open Editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Open editor
    await tester.tap(find.text('Open Editor'));
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Original Title'), findsOneWidget);

    // Edit title
    await tester.enterText(find.byType(TextField).first, 'Updated Title');
    await tester.pump();

    // Tap "Save changes"
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // Screen should have popped back to home
    expect(find.text('Open Editor'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);

    // Verify repository was updated
    final updated = await mockRepo.getById('task-101');
    expect(updated?.title, 'Updated Title');
  });

  testWidgets('TaskEditorScreen handles error gracefully and does not remain stuck', (tester) async {
    final failingRepo = _FailingTaskRepo();
    final mockScheduler = MockReminderScheduler();
    final mockAttachmentRepo = MockAttachmentRepository();
    final mockStorage = MockFileStorage();

    final existingTask = Task(
      id: 'task-102',
      title: 'Task Before Failure',
      description: 'Description',
      status: TaskStatus.active,
      priority: TaskPriority.medium,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(failingRepo),
          reminderSchedulerProvider.overrideWithValue(mockScheduler),
          attachmentRepositoryProvider.overrideWithValue(mockAttachmentRepo),
          fileStorageProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: TaskEditorScreen(task: existingTask),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Save changes"
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    // Error snackbar should be visible and button re-enabled (not stuck in loading)
    expect(find.text('Could not save changes. Please try again.'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });
}

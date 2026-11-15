import 'package:flutter_test/flutter_test.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';
import '../../widget/task_controller_test.dart'; 

void main() {
  test('insertTaskBelow inserts a new task at the correct order', () async {
    final mockRepo = MockTaskRepository();
    final controller = TaskController(mockRepo, MockReminderScheduler(), MockAttachmentRepository(), MockFileStorage());
    
    final taskA = await controller.createTask(title: 'Task A');
    await controller.createTask(title: 'Task C'); 
    
    // Insert B below A
    await controller.insertTaskBelow(taskA.id, 'Task B');
    
    final tasks = controller.activeTasks;
    expect(tasks[0].title, 'Task A');
    expect(tasks[1].title, 'Task B');
    expect(tasks[2].title, 'Task C');
  });
  test('insertTaskBelow with empty string throws ArgumentError', () async {
    final mockRepo = MockTaskRepository();
    final controller = TaskController(mockRepo, MockReminderScheduler(), MockAttachmentRepository(), MockFileStorage());
    
    final taskA = await controller.createTask(title: 'Task A');
    
    expect(
      () => controller.insertTaskBelow(taskA.id, ''),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('insertTaskBelow trims whitespace from title', () async {
    final mockRepo = MockTaskRepository();
    final controller = TaskController(mockRepo, MockReminderScheduler(), MockAttachmentRepository(), MockFileStorage());
    
    final taskA = await controller.createTask(title: 'Task A');
    await controller.insertTaskBelow(taskA.id, '  Task B  ');
    
    expect(controller.activeTasks[1].title, 'Task B');
  });

  test('insertTaskBelow with whitespace-only string throws ArgumentError', () async {
    final mockRepo = MockTaskRepository();
    final controller = TaskController(mockRepo, MockReminderScheduler(), MockAttachmentRepository(), MockFileStorage());
    
    final taskA = await controller.createTask(title: 'Task A');
    
    expect(
      () => controller.insertTaskBelow(taskA.id, '   '),
      throwsA(isA<ArgumentError>()),
    );
  });
}

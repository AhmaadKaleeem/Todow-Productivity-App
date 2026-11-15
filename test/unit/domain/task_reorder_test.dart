import 'package:flutter_test/flutter_test.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';
import '../../widget/task_controller_test.dart'; // To reuse mocks if needed

void main() {
  test('reorderTask updates order of tasks correctly', () async {
    final mockRepo = MockTaskRepository();
    final controller = TaskController(mockRepo, MockReminderScheduler(), MockAttachmentRepository(), MockFileStorage());
    
    await controller.createTask(title: 'Task A'); // order 0
    await controller.createTask(title: 'Task B'); // order 1
    await controller.createTask(title: 'Task C'); // order 2
    
    await controller.reorderTask(0, 2); // Move A below B
    
    final tasks = controller.activeTasks;
    expect(tasks[0].title, 'Task B');
    expect(tasks[1].title, 'Task A');
    expect(tasks[2].title, 'Task C');
  });
}

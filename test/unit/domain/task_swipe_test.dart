import 'package:flutter_test/flutter_test.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';
import '../../widget/task_controller_test.dart';

void main() {
  test('Swipe actions trigger complete and delete via domain methods', () async {
    final mockRepo = MockTaskRepository();
    final controller = TaskController(mockRepo, MockReminderScheduler(), MockAttachmentRepository(), MockFileStorage());
    
    final task = await controller.createTask(title: 'Task to swipe');
    expect(controller.activeTasks.length, 1);
    
    // Complete
    await controller.completeTask(task.id);
    expect(controller.activeTasks.length, 0);
    expect(controller.tasks.first.status, TaskStatus.completed);
    
    // Delete
    await controller.deleteTask(task.id);
    expect(controller.tasks.length, 0);
  });
}

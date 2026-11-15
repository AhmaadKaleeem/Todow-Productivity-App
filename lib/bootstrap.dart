import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:todow/data/local/app_database.dart';
import 'package:todow/data/local/focus_repository_impl.dart';
import 'package:todow/data/local/task_repository_impl.dart';
import 'package:todow/data/local/timetable_repository_impl.dart';
import 'package:todow/data/local/attachment_repository_impl.dart';
import 'package:todow/data/services/app_blocking_service_stub.dart';
import 'package:todow/data/services/file_storage_impl.dart';
import 'package:todow/data/services/orphan_cleanup.dart';
import 'package:todow/data/services/focus_service_impl.dart';
import 'package:todow/data/services/notification_service_impl.dart';
import 'package:todow/data/services/reminder_scheduler_impl.dart';
import 'package:todow/domain/repositories/focus_repository.dart';
import 'package:todow/domain/repositories/task_repository.dart';
import 'package:todow/domain/repositories/timetable_repository.dart';
import 'package:todow/domain/repositories/attachment_repository.dart';
import 'package:todow/domain/services/app_blocking_service.dart';
import 'package:todow/domain/services/file_storage.dart';
import 'package:todow/domain/services/focus_service.dart';
import 'package:todow/domain/services/notification_service.dart';
import 'package:todow/domain/services/reminder_scheduler.dart';
import 'package:todow/domain/repositories/roadmap_repository.dart';

import 'package:todow/presentation/features/focus/focus_controller.dart';
import 'package:todow/presentation/features/tasks/task_controller.dart';

import 'package:todow/data/local/roadmap_repository_impl.dart';

class AppServices {
  AppServices({
    required this.taskRepository,
    required this.timetableRepository,
    required this.focusRepository,
    required this.roadmapRepository,
    required this.topicRepository,
    required this.roadmapTaskRepository,
    required this.roadmapImportRepository,
    required this.notificationService,
    required this.reminderScheduler,
    required this.attachmentRepository,
    required this.fileStorage,
    required this.focusService,
    required this.appBlockingService,
    required this.taskController,
    required this.focusController,
  });

  final TaskRepository taskRepository;
  final TimetableRepository timetableRepository;
  final FocusRepository focusRepository;
  final RoadmapRepository roadmapRepository;
  final TopicRepository topicRepository;
  final RoadmapTaskRepository roadmapTaskRepository;
  final RoadmapImportRepository roadmapImportRepository;
  final NotificationService notificationService;
  final ReminderScheduler reminderScheduler;
  final AttachmentRepository attachmentRepository;
  final FileStorage fileStorage;
  final FocusService focusService;
  final AppBlockingService appBlockingService;
  final TaskController taskController;
  final FocusController focusController;
}

Future<AppServices> bootstrap() async {
  final db = await AppDatabase.open();
  final taskRepo = TaskRepositoryImpl(db);
  final timetableRepo = TimetableRepositoryImpl(db);
  final focusRepo = FocusRepositoryImpl(db);
  final attachmentRepo = AttachmentRepositoryImpl(db.db);
  final appDirPath = kIsWeb ? '' : (await getApplicationDocumentsDirectory()).path;
  final fileStorage = FileStorageImpl(kIsWeb ? '/dummy' : p.join(appDirPath, 'attachments'));

  if (!kIsWeb) {
    await migrateAttachmentPaths(attachmentRepo, p.join(appDirPath, 'attachments'));
  }

  final appBlocking = AppBlockingServiceStub();

  // H3: Use an explicit handler so the notification callback never captures
  // a `late` variable that may not yet be initialised when the callback fires.
  final actionHandler = _NotificationActionHandler(taskRepo);

  final notifications = NotificationServiceImpl(
    onAction: actionHandler.handle,
  );

  await notifications.initialize();

  final reminderScheduler = ReminderSchedulerImpl(taskRepo, timetableRepo, notifications);
  await reminderScheduler.recoverPendingReminders();

  final focusService = FocusServiceImpl(focusRepo, appBlocking);
  await focusService.restoreActiveSession();

  await cleanupOrphanedAttachments(taskRepo);

  final taskController = TaskController(
    taskRepo,
    reminderScheduler,
    attachmentRepo,
    fileStorage,
  );

  // Inject the controller and scheduler into the handler now that both exist.
  actionHandler.taskController = taskController;
  actionHandler.reminderScheduler = reminderScheduler;

  final focusController = FocusController(focusService);


  await taskController.loadTasks();

  final roadmapRepo = RoadmapRepositoryImpl(db);
  final topicRepo = TopicRepositoryImpl(db);
  final roadmapTaskRepo = RoadmapTaskRepositoryImpl(db);
  final roadmapImportRepo = RoadmapImportRepositoryImpl(db);


  return AppServices(
    taskRepository: taskRepo,
    timetableRepository: timetableRepo,
    focusRepository: focusRepo,
    roadmapRepository: roadmapRepo,
    topicRepository: topicRepo,
    roadmapTaskRepository: roadmapTaskRepo,
    roadmapImportRepository: roadmapImportRepo,
    notificationService: notifications,
    reminderScheduler: reminderScheduler,
    attachmentRepository: attachmentRepo,
    fileStorage: fileStorage,
    focusService: focusService,
    appBlockingService: appBlocking,
    taskController: taskController,
    focusController: focusController,
  );
}

/// Holds references to app services needed to handle notification actions.
/// References are set after construction so neither side needs `late` captures.
class _NotificationActionHandler {
  _NotificationActionHandler(this._taskRepo);

  final TaskRepository _taskRepo;
  TaskController? taskController;
  ReminderScheduler? reminderScheduler;

  Future<void> handle(String? payload, String? action) async {
    if (payload == null) return;
    final tc = taskController;
    final rs = reminderScheduler;
    // If services aren't ready yet (very early callback), silently drop.
    if (tc == null || rs == null) {
      debugPrint('Notification action "$action" received before services ready, ignoring.');
      return;
    }
    final task = await _taskRepo.getById(payload);
    if (task == null) return;
    if (Platform.isAndroid) {
      try {
        const MethodChannel('com.example.todow/alarm_native')
            .invokeMethod('stopAlarm');
      } catch (_) {}
    }
    switch (action) {
      case 'complete':
        await tc.completeTask(task.id);
      case 'snooze':
        final reminders = await _taskRepo.getRemindersForTask(task.id);
        final active = reminders.where((r) => r.isActive).firstOrNull;
        if (active != null) {
          await rs.snoozeReminder(active, const Duration(minutes: 15));
        }
      case 'dismiss':
        debugPrint('Alarm dismissed for task ${task.id}');
        break;
      case 'open':
      default:
        break;
    }
  }
}


extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

Future<void> migrateAttachmentPaths(
    AttachmentRepository repo, String rootPath) async {
  final all = await repo.getAll();
  for (final att in all) {
    final oldPath = p.join(rootPath, att.taskId, '${att.id}_${att.filename}');
    
    // Compute extension with dot
    final originalName = att.filename;
    final dotIndex = originalName.lastIndexOf('.');
    final ext = (dotIndex != -1 && dotIndex < originalName.length - 1)
        ? originalName.substring(dotIndex).toLowerCase()
        : '';
        
    final newPath = p.join(rootPath, att.taskId, '${att.id}$ext');
    
    final oldFile = File(oldPath);
    final newFile = File(newPath);
    
    final oldExists = oldFile.existsSync();
    final newExists = newFile.existsSync();
    
    if (oldExists && !newExists) {
      oldFile.renameSync(newPath);
    } else if (oldExists && newExists) {
      debugPrint('Both old and new attachment paths exist for ${att.id}');
    } else if (!oldExists && !newExists) {
      debugPrint('Orphaned attachment ${att.id} has no file on disk');
    }
  }
}

import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/focus_activity_template.dart';
import 'package:todow/domain/models/task.dart';

abstract class FocusService {
  FocusSession? get currentSession;
  Stream<FocusSession?> get sessionStream;

  Future<FocusSession> startSession({
    Task? task,
    required FocusPreset preset,
    Duration? duration,
    FocusActivityTemplate? activity,
    List<String>? allowedApps,
  });

  Future<FocusSession> pauseSession();
  Future<FocusSession> resumeSession();
  Future<FocusSession> endSession();
  Future<void> restoreActiveSession();
}

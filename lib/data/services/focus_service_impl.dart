import 'dart:async';

import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/focus_activity_template.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/repositories/focus_repository.dart';
import 'package:todow/domain/services/app_blocking_service.dart';
import 'package:todow/domain/services/focus_service.dart';
import 'package:uuid/uuid.dart';

class FocusServiceImpl implements FocusService {
  FocusServiceImpl(this._repo, this._appBlocking);

  final FocusRepository _repo;
  final AppBlockingService _appBlocking;
  static const _uuid = Uuid();

  FocusSession? _current;
  final _controller = StreamController<FocusSession?>.broadcast();

  @override
  FocusSession? get currentSession => _current;

  @override
  Stream<FocusSession?> get sessionStream => _controller.stream;

  @override
  Future<void> restoreActiveSession() async {
    _current = await _repo.getActiveSession();
    _controller.add(_current);
  }

  @override
  Future<FocusSession> startSession({
    Task? task,
    required FocusPreset preset,
    Duration? duration,
    FocusActivityTemplate? activity,
    List<String>? allowedApps,
  }) async {
    if (_current != null &&
        (_current!.status == FocusSessionStatus.running ||
            _current!.status == FocusSessionStatus.paused)) {
      await endSession();
    }

    final apps =
        allowedApps ?? const ['Chrome', 'Calculator', 'Drive', 'Notes'];

    final session = FocusSession(
      id: _uuid.v4(),
      taskId: task?.id,
      taskTitle: task?.title ?? 'Focus session',
      preset: activity?.visualPreset ?? preset,
      plannedDuration: duration ?? preset.defaultDuration,
      startedAt: DateTime.now(),
      status: FocusSessionStatus.running,
      allowedApps: apps,
      activityTemplateId: activity?.id,
      activityName: activity?.name,
      activityGroup: activity?.groupName,
      activitySubgroup: activity?.subgroupName,
      mixedEnvironment: activity != null && activity.visualPreset == null,
    );

    _current = await _repo.saveSession(session);
    if (await _appBlocking.isSupported()) {
      await _appBlocking.setAllowedApps(apps);
      await _appBlocking.enableBlocking();
    }
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<FocusSession> pauseSession() async {
    final session = _current;
    if (session == null || session.status != FocusSessionStatus.running) {
      throw FocusServiceException('No running session to pause.');
    }
    final elapsed = session.elapsedAt(DateTime.now());
    _current = await _repo.saveSession(
      session.copyWith(
        status: FocusSessionStatus.paused,
        pausedAt: DateTime.now(),
        elapsedBeforePause: elapsed,
      ),
    );
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<FocusSession> resumeSession() async {
    final session = _current;
    if (session == null || session.status != FocusSessionStatus.paused) {
      throw FocusServiceException('No paused session to resume.');
    }
    _current = await _repo.saveSession(
      FocusSession(
        id: session.id,
        taskId: session.taskId,
        taskTitle: session.taskTitle,
        preset: session.preset,
        plannedDuration: session.plannedDuration,
        startedAt: DateTime.now(),
        status: FocusSessionStatus.running,
        elapsedBeforePause: session.elapsedBeforePause,
        allowedApps: session.allowedApps,
        activityTemplateId: session.activityTemplateId,
        activityName: session.activityName,
        activityGroup: session.activityGroup,
        activitySubgroup: session.activitySubgroup,
        mixedEnvironment: session.mixedEnvironment,
      ),
    );
    _controller.add(_current);
    return _current!;
  }

  @override
  Future<FocusSession> endSession() async {
    final session = _current;
    if (session == null) {
      throw FocusServiceException('No active session to end.');
    }
    await _appBlocking.disableBlocking();
    _current = await _repo.saveSession(
      session.copyWith(
        status: FocusSessionStatus.ended,
        endedAt: DateTime.now(),
      ),
    );
    _controller.add(null);
    final ended = _current!;
    _current = null;
    return ended;
  }
}

class FocusServiceException implements Exception {
  FocusServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

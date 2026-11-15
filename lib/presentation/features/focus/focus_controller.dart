import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/focus_activity_template.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/services/focus_service.dart';

class FocusController extends ChangeNotifier {
  FocusController(this._service) {
    _subscription = _service.sessionStream.listen((session) {
      _session = session;
      notifyListeners();
    });
    _session = _service.currentSession;
  }

  final FocusService _service;
  StreamSubscription<FocusSession?>? _subscription;
  FocusSession? _session;

  FocusSession? get session => _session;

  Duration elapsed(DateTime now) => _session?.elapsedAt(now) ?? Duration.zero;

  Duration remaining(DateTime now) =>
      _session?.remainingAt(now) ?? Duration.zero;

  Future<void> start({
    Task? task,
    required FocusPreset preset,
    Duration? duration,
    FocusActivityTemplate? activity,
  }) async {
    await _service.startSession(
      task: task,
      preset: preset,
      duration: duration,
      activity: activity,
    );
  }

  Future<void> pause() async {
    await _service.pauseSession();
  }

  Future<void> resume() async {
    await _service.resumeSession();
  }

  Future<void> end() async {
    await _service.endSession();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

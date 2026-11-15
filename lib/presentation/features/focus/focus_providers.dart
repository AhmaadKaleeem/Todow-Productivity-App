import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/providers/service_providers.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/focus_activity_template.dart';
import 'package:todow/domain/models/task.dart';

class FocusNotifier extends Notifier<FocusSession?> {
  @override
  FocusSession? build() {
    final service = ref.watch(focusServiceProvider);

    // Subscribe to stream updates
    final subscription = service.sessionStream.listen((session) {
      state = session;
    });

    ref.onDispose(() => subscription.cancel());

    // Initial state
    return service.currentSession;
  }

  Duration elapsed(DateTime now) => state?.elapsedAt(now) ?? Duration.zero;

  Duration remaining(DateTime now) => state?.remainingAt(now) ?? Duration.zero;

  Future<void> start({
    Task? task,
    required FocusPreset preset,
    Duration? duration,
    FocusActivityTemplate? activity,
  }) async {
    await ref.read(focusServiceProvider).startSession(
          task: task,
          preset: preset,
          duration: duration,
          activity: activity,
        );
  }

  Future<void> pause() async {
    await ref.read(focusServiceProvider).pauseSession();
  }

  Future<void> resume() async {
    await ref.read(focusServiceProvider).resumeSession();
  }

  Future<void> end() async {
    await ref.read(focusServiceProvider).endSession();
  }
}

final focusSessionProvider = NotifierProvider<FocusNotifier, FocusSession?>(
  FocusNotifier.new,
);

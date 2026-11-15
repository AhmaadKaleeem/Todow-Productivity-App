import 'package:flutter_test/flutter_test.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_session.dart';
import 'package:todow/domain/models/focus_timeline.dart';

void main() {
  test('keeps elapsed focus time when a paused session ends', () {
    final startedAt = DateTime(2026, 9, 18, 10);
    final session = FocusSession(
      id: 'focus-1',
      taskId: 'task-1',
      taskTitle: 'Study',
      preset: FocusPreset.study,
      plannedDuration: const Duration(minutes: 50),
      startedAt: startedAt,
      status: FocusSessionStatus.ended,
      endedAt: startedAt.add(const Duration(minutes: 20)),
      elapsedBeforePause: const Duration(minutes: 12),
    );

    expect(session.elapsedAt(startedAt), const Duration(minutes: 32));
  });

  test('maps different durations to the same proportional animation phase', () {
    final shortStart = DateTime(2026, 9, 18, 10);
    final longStart = DateTime(2026, 9, 18, 10);
    final short = FocusSession(
      id: 'short',
      taskId: null,
      taskTitle: 'Short',
      preset: FocusPreset.coding,
      plannedDuration: const Duration(minutes: 15),
      startedAt: shortStart,
      status: FocusSessionStatus.running,
    );
    final long = FocusSession(
      id: 'long',
      taskId: null,
      taskTitle: 'Long',
      preset: FocusPreset.coding,
      plannedDuration: const Duration(minutes: 120),
      startedAt: longStart,
      status: FocusSessionStatus.running,
    );

    final shortTimeline = FocusTimeline.fromSession(
      short,
      shortStart.add(const Duration(minutes: 9)),
    );
    final longTimeline = FocusTimeline.fromSession(
      long,
      longStart.add(const Duration(minutes: 72)),
    );

    expect(shortTimeline.phase, FocusAnimationPhase.progression);
    expect(longTimeline.phase, FocusAnimationPhase.progression);
    expect(shortTimeline.progress, closeTo(longTimeline.progress, 0.001));
    expect(shortTimeline.phaseProgress,
        closeTo(longTimeline.phaseProgress, 0.001));
  });

  test('short and long sessions reach timeline phases at different times', () {
    final start = DateTime(2026, 9, 18, 10);
    final short = FocusSession(
      id: 'short',
      taskId: null,
      taskTitle: 'Short',
      preset: FocusPreset.coding,
      plannedDuration: const Duration(minutes: 15),
      startedAt: start,
      status: FocusSessionStatus.running,
    );
    final long = FocusSession(
      id: 'long',
      taskId: null,
      taskTitle: 'Long',
      preset: FocusPreset.coding,
      plannedDuration: const Duration(minutes: 120),
      startedAt: start,
      status: FocusSessionStatus.running,
    );

    final shortTimeline =
        FocusTimeline.fromSession(short, start.add(const Duration(minutes: 1)));
    final longTimeline =
        FocusTimeline.fromSession(long, start.add(const Duration(minutes: 1)));

    expect(shortTimeline.phase, FocusAnimationPhase.settling);
    expect(longTimeline.phase, FocusAnimationPhase.entry);
    expect(shortTimeline.remaining, const Duration(minutes: 14));
    expect(longTimeline.remaining, const Duration(minutes: 119));
  });

  test('persists custom durations and every activity identifier', () {
    for (final preset in FocusPreset.values) {
      final session = FocusSession(
        id: 'custom-${preset.name}',
        taskId: null,
        taskTitle: preset.label,
        preset: preset,
        plannedDuration: const Duration(minutes: 73),
        startedAt: DateTime(2026, 9, 18, 10),
        status: FocusSessionStatus.running,
      );

      final restored = FocusSession.fromMap(session.toMap());
      expect(restored.preset, preset);
      expect(restored.plannedDuration, const Duration(minutes: 73));
    }
  });

  test('freezes timeline progress while paused', () {
    final startedAt = DateTime(2026, 9, 18, 10);
    final session = FocusSession(
      id: 'paused',
      taskId: null,
      taskTitle: 'Paused',
      preset: FocusPreset.reading,
      plannedDuration: const Duration(minutes: 60),
      startedAt: startedAt,
      status: FocusSessionStatus.paused,
      elapsedBeforePause: const Duration(minutes: 20),
    );

    final timeline = FocusTimeline.fromSession(
      session,
      startedAt.add(const Duration(hours: 2)),
    );

    expect(timeline.progress, closeTo(1 / 3, 0.001));
    expect(timeline.phase, FocusAnimationPhase.deepFocus);
  });

  test(
      'resumes from stored elapsed time and completes at the selected duration',
      () {
    final resumedAt = DateTime(2026, 9, 18, 11);
    final session = FocusSession(
      id: 'resumed',
      taskId: null,
      taskTitle: 'Build feature',
      preset: FocusPreset.coding,
      plannedDuration: const Duration(minutes: 60),
      startedAt: resumedAt,
      status: FocusSessionStatus.running,
      elapsedBeforePause: const Duration(minutes: 20),
    );

    final afterBackgroundReturn = FocusTimeline.fromSession(
      session,
      resumedAt.add(const Duration(minutes: 30)),
    );
    final completed = FocusTimeline.fromSession(
      session,
      resumedAt.add(const Duration(minutes: 40)),
    );

    expect(afterBackgroundReturn.progress, closeTo(5 / 6, 0.001));
    expect(afterBackgroundReturn.remaining, const Duration(minutes: 10));
    expect(afterBackgroundReturn.phase, FocusAnimationPhase.progression);
    expect(completed.progress, 1);
    expect(completed.remaining, Duration.zero);
    expect(completed.phase, FocusAnimationPhase.completion);
  });
}

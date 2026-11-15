import 'focus_session.dart';

enum FocusAnimationPhase {
  entry,
  settling,
  deepFocus,
  progression,
  finalPhase,
  completion,
}

class FocusTimeline {
  const FocusTimeline({
    required this.phase,
    required this.progress,
    required this.phaseProgress,
    required this.remaining,
    required this.plannedDuration,
  });

  final FocusAnimationPhase phase;
  final double progress;
  final double phaseProgress;
  final Duration remaining;
  final Duration plannedDuration;

  static const preview = FocusTimeline(
    phase: FocusAnimationPhase.deepFocus,
    progress: 0.34,
    phaseProgress: 0.46,
    remaining: Duration(minutes: 90),
    plannedDuration: Duration(minutes: 90),
  );

  factory FocusTimeline.fromSession(FocusSession session, DateTime now) {
    final progress = session.progressAt(now).clamp(0.0, 1.0);
    final phase = _phaseFor(progress);
    final bounds = _boundsFor(phase);
    final phaseProgress = bounds.$2 == bounds.$1
        ? 1.0
        : ((progress - bounds.$1) / (bounds.$2 - bounds.$1)).clamp(0.0, 1.0);

    return FocusTimeline(
      phase: phase,
      progress: progress,
      phaseProgress: phaseProgress,
      remaining: session.remainingAt(now),
      plannedDuration: session.plannedDuration,
    );
  }

  static FocusAnimationPhase _phaseFor(double progress) {
    if (progress >= 1) return FocusAnimationPhase.completion;
    if (progress >= 0.88) return FocusAnimationPhase.finalPhase;
    if (progress >= 0.55) return FocusAnimationPhase.progression;
    if (progress >= 0.16) return FocusAnimationPhase.deepFocus;
    if (progress >= 0.05) return FocusAnimationPhase.settling;
    return FocusAnimationPhase.entry;
  }

  static (double, double) _boundsFor(FocusAnimationPhase phase) =>
      switch (phase) {
        FocusAnimationPhase.entry => (0.0, 0.05),
        FocusAnimationPhase.settling => (0.05, 0.16),
        FocusAnimationPhase.deepFocus => (0.16, 0.55),
        FocusAnimationPhase.progression => (0.55, 0.88),
        FocusAnimationPhase.finalPhase => (0.88, 1.0),
        FocusAnimationPhase.completion => (1.0, 1.0),
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_activity.dart';
import 'package:todow/domain/models/focus_timeline.dart';
import 'package:todow/presentation/widgets/focus_activity_scene.dart';

FocusTimeline _timeline(FocusAnimationPhase phase, double progress) =>
    FocusTimeline(
      phase: phase,
      progress: progress,
      phaseProgress: 0.5,
      remaining: const Duration(minutes: 20),
      plannedDuration: const Duration(minutes: 60),
    );

void main() {
  group('FocusActivityScene', () {
    test('defines an environment for every selectable activity', () {
      expect(FocusActivityDefinition.values.length, FocusPreset.values.length);
      expect(
        FocusActivityDefinition.values
            .map((value) => value.environment)
            .toSet(),
        hasLength(FocusActivityDefinition.values.length),
      );
      expect(
        FocusActivityDefinition.values
            .map((value) => value.workSurface)
            .toSet(),
        hasLength(FocusActivityDefinition.values.length),
      );
      for (final category in FocusActivityCategory.values) {
        if (category == FocusActivityCategory.userActivities) continue;
        expect(FocusActivityDefinition.inCategory(category), isNotEmpty);
      }
      for (final preset in FocusPreset.values) {
        expect(FocusActivityDefinition.forActivity(preset).activity, preset);
      }
    });

    testWidgets('renders every activity without errors', (tester) async {
      for (final preset in FocusPreset.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusActivityScene(
                preset: preset,
                timeline: _timeline(FocusAnimationPhase.deepFocus, 0.35),
                isRunning: true,
                compact: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FocusActivityScene), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('labels each duration-scaled phase', (tester) async {
      const phases = {
        FocusAnimationPhase.entry: (0.02, 'ENTERING'),
        FocusAnimationPhase.settling: (0.10, 'SETTLING'),
        FocusAnimationPhase.deepFocus: (0.35, 'DEEP FOCUS'),
        FocusAnimationPhase.progression: (0.70, 'IN RHYTHM'),
        FocusAnimationPhase.finalPhase: (0.94, 'CLOSING'),
        FocusAnimationPhase.completion: (1.0, 'COMPLETE'),
      };

      for (final entry in phases.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusActivityScene(
                preset: FocusPreset.coding,
                timeline: _timeline(entry.key, entry.value.$1),
                isRunning: true,
                compact: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(entry.value.$2), findsOneWidget);
      }
    });

    testWidgets('removes spatial transition when reduced motion is enabled',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: FocusActivityScene(
                preset: FocusPreset.reading,
                timeline: FocusTimeline.preview,
                isRunning: false,
                compact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FocusActivityScene), findsOneWidget);
    });
  });
}

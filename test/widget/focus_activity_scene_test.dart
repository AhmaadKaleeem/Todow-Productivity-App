import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/presentation/widgets/focus_activity_scene.dart';

void main() {
  group('FocusActivityScene', () {
    testWidgets('renders all activity presets without errors', (tester) async {
      for (final preset in FocusPreset.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FocusActivityScene(
                preset: preset,
                progress: 0.35,
                isRunning: true,
              ),
            ),
          ),
        );

        expect(find.byType(FocusActivityScene), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      }
    });

    testWidgets('renders correct stage labels as progress evolves', (tester) async {
      // 1. Starting phase (< 0.15)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FocusActivityScene(
              preset: FocusPreset.coding,
              progress: 0.05,
              isRunning: true,
            ),
          ),
        ),
      );
      expect(find.text('ENTERING ZONE'), findsOneWidget);
      expect(find.text('CODING ENVIRONMENT'), findsOneWidget);

      // 2. Early phase (0.15 - 0.50)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FocusActivityScene(
              preset: FocusPreset.assignment,
              progress: 0.30,
              isRunning: true,
            ),
          ),
        ),
      );
      expect(find.text('STEADY FOCUS'), findsOneWidget);
      expect(find.text('ASSIGNMENT WORKSPACE'), findsOneWidget);

      // 3. Mid phase (0.50 - 0.85)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FocusActivityScene(
              preset: FocusPreset.reading,
              progress: 0.65,
              isRunning: true,
            ),
          ),
        ),
      );
      expect(find.text('DEEP WORK'), findsOneWidget);
      expect(find.text('ACTIVE READING'), findsOneWidget);

      // 4. Near completion (>= 0.85)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FocusActivityScene(
              preset: FocusPreset.deepWork,
              progress: 0.90,
              isRunning: true,
            ),
          ),
        ),
      );
      expect(find.text('FINAL SPRINT'), findsOneWidget);
      expect(find.text('DEEP WORK FLOW'), findsOneWidget);
    });
  });
}

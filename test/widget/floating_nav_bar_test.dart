import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/presentation/app_shell.dart';

void main() {
  group('FloatingNavBar', () {
    testWidgets('renders all 5 navigation controls with correct UI', (tester) async {
      int? selectedIndex;
      bool drawerToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FloatingNavBar(
                currentIndex: 0,
                isDrawerOpen: false,
                onSelect: (index) => selectedIndex = index,
                onToggleDrawer: () => drawerToggled = true,
              ),
            ),
          ),
        ),
      );

      // Verify all 5 icons exist
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

      // Verify active tab (Home at index 0) has textPrimary color
      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.grid_view_rounded));
      expect(homeIcon.color, AppColors.textPrimary);

      // Verify inactive tabs have textSecondary color
      final tasksIcon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded));
      expect(tasksIcon.color, AppColors.textSecondary);

      // Tap Tasks tab (index 1)
      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
      expect(selectedIndex, 1);

      // Tap Timetable tab (index 3)
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      expect(selectedIndex, 3);

      // Tap Person tab
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      expect(drawerToggled, true);
    });

    testWidgets('reflects active state when index or drawer state changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FloatingNavBar(
                currentIndex: 1,
                isDrawerOpen: false,
                onSelect: (_) {},
                onToggleDrawer: () {},
              ),
            ),
          ),
        ),
      );

      // Index 1 (Tasks) should be selected
      final tasksIcon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded));
      expect(tasksIcon.color, AppColors.textPrimary);

      final homeIcon = tester.widget<Icon>(find.byIcon(Icons.grid_view_rounded));
      expect(homeIcon.color, AppColors.textSecondary);

      // Re-pump with drawer open
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FloatingNavBar(
                currentIndex: 1,
                isDrawerOpen: true,
                onSelect: (_) {},
                onToggleDrawer: () {},
              ),
            ),
          ),
        ),
      );

      // Person icon should now be selected
      final personIcon = tester.widget<Icon>(find.byIcon(Icons.person_outline_rounded));
      expect(personIcon.color, AppColors.textPrimary);

      // When drawer is open, other tabs should be textSecondary
      final tasksIconWhileDrawerOpen = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded));
      expect(tasksIconWhileDrawerOpen.color, AppColors.textSecondary);
    });
  });
}

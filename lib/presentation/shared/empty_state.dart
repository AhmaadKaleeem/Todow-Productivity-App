
import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';


class AppEmptyState extends StatelessWidget {
  const AppEmptyState({required this.title, required this.message, super.key});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary))
          ])));
}


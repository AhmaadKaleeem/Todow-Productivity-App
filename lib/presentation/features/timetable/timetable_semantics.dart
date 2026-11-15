import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';

String timetableTypeLabel(String? category, TimetableKind kind) =>
    category?.trim().isNotEmpty == true
        ? category!.trim()
        : kind == TimetableKind.university
            ? 'Lecture'
            : 'Activity';

Color timetableTypeColor(String? category, TimetableKind kind) {
  switch (category?.trim().toLowerCase()) {
    case 'lecture':
    case 'class':
      return AppColors.action;
    case 'lab':
    case 'study':
    case 'academic':
    case 'roadmap':
      return AppColors.decorNavy;
    case 'tutorial':
    case 'work':
      return AppColors.attention;
    case 'seminar':
    case 'appointment':
    case 'personal':
      return AppColors.decorPink;
    case 'exam':
    case 'task':
      return AppColors.decorCoral;
    case 'workshop':
      return AppColors.decorCoral;
    default:
      return kind == TimetableKind.personal
          ? AppColors.decorPink
          : AppColors.action;
  }
}

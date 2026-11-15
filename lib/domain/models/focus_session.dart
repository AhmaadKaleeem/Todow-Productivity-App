import 'package:todow/domain/models/enums.dart';

class FocusSession {
  const FocusSession({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.preset,
    required this.plannedDuration,
    required this.startedAt,
    required this.status,
    this.pausedAt,
    this.endedAt,
    this.elapsedBeforePause = Duration.zero,
    this.allowedApps = const [],
    this.activityTemplateId,
    this.activityName,
    this.activityGroup,
    this.activitySubgroup,
    this.mixedEnvironment = false,
  });

  final String id;
  final String? taskId;
  final String taskTitle;
  final FocusPreset preset;
  final Duration plannedDuration;
  final DateTime startedAt;
  final FocusSessionStatus status;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final Duration elapsedBeforePause;
  final List<String> allowedApps;
  final String? activityTemplateId;
  final String? activityName;
  final String? activityGroup;
  final String? activitySubgroup;
  final bool mixedEnvironment;

  Duration elapsedAt(DateTime now) {
    if (status == FocusSessionStatus.paused) {
      return elapsedBeforePause;
    }
    if (status == FocusSessionStatus.ended && endedAt != null) {
      return endedAt!.difference(startedAt) + elapsedBeforePause - _pauseGap();
    }
    return now.difference(startedAt) - _pauseGap() + elapsedBeforePause;
  }

  Duration _pauseGap() => Duration.zero;

  Duration remainingAt(DateTime now) {
    final remaining = plannedDuration - elapsedAt(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double progressAt(DateTime now) {
    if (plannedDuration.inSeconds == 0) return 0;
    return (elapsedAt(now).inSeconds / plannedDuration.inSeconds).clamp(0, 1);
  }

  FocusSession copyWith({
    FocusSessionStatus? status,
    DateTime? pausedAt,
    DateTime? endedAt,
    Duration? elapsedBeforePause,
    List<String>? allowedApps,
    String? activityTemplateId,
    String? activityName,
    String? activityGroup,
    String? activitySubgroup,
    bool? mixedEnvironment,
  }) {
    return FocusSession(
      id: id,
      taskId: taskId,
      taskTitle: taskTitle,
      preset: preset,
      plannedDuration: plannedDuration,
      startedAt: startedAt,
      status: status ?? this.status,
      pausedAt: pausedAt ?? this.pausedAt,
      endedAt: endedAt ?? this.endedAt,
      elapsedBeforePause: elapsedBeforePause ?? this.elapsedBeforePause,
      allowedApps: allowedApps ?? this.allowedApps,
      activityTemplateId: activityTemplateId ?? this.activityTemplateId,
      activityName: activityName ?? this.activityName,
      activityGroup: activityGroup ?? this.activityGroup,
      activitySubgroup: activitySubgroup ?? this.activitySubgroup,
      mixedEnvironment: mixedEnvironment ?? this.mixedEnvironment,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'task_id': taskId,
        'task_title': taskTitle,
        'preset': preset.name,
        'planned_seconds': plannedDuration.inSeconds,
        'started_at': startedAt.toIso8601String(),
        'status': status.name,
        'paused_at': pausedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'elapsed_before_pause_seconds': elapsedBeforePause.inSeconds,
        'allowed_apps': allowedApps.join(','),
        'activity_template_id': activityTemplateId,
        'activity_name': activityName,
        'activity_group': activityGroup,
        'activity_subgroup': activitySubgroup,
        'mixed_environment': mixedEnvironment ? 1 : 0,
      };

  factory FocusSession.fromMap(Map<String, Object?> map) => FocusSession(
        id: map['id']! as String,
        taskId: map['task_id'] as String?,
        taskTitle: map['task_title']! as String,
        preset: FocusPreset.values.byName(map['preset']! as String),
        plannedDuration: Duration(seconds: map['planned_seconds']! as int),
        startedAt: DateTime.parse(map['started_at']! as String),
        status: FocusSessionStatus.values.byName(map['status']! as String),
        pausedAt: map['paused_at'] != null
            ? DateTime.parse(map['paused_at']! as String)
            : null,
        endedAt: map['ended_at'] != null
            ? DateTime.parse(map['ended_at']! as String)
            : null,
        elapsedBeforePause: Duration(
          seconds: map['elapsed_before_pause_seconds'] as int? ?? 0,
        ),
        allowedApps: (map['allowed_apps'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        activityTemplateId: map['activity_template_id'] as String?,
        activityName: map['activity_name'] as String?,
        activityGroup: map['activity_group'] as String?,
        activitySubgroup: map['activity_subgroup'] as String?,
        mixedEnvironment: (map['mixed_environment'] as int? ?? 0) != 0,
      );
}

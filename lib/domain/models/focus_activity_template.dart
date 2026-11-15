import 'package:todow/domain/models/enums.dart';

class FocusActivityTemplate {
  const FocusActivityTemplate({
    required this.id,
    required this.name,
    required this.defaultDurationMinutes,
    this.groupName,
    this.subgroupName,
    this.visualPresetName,
  });

  final String id;
  final String name;
  final String? groupName;
  final String? subgroupName;
  final int defaultDurationMinutes;
  final String? visualPresetName;

  FocusPreset? get visualPreset {
    for (final preset in FocusPreset.values) {
      if (preset.name == visualPresetName) return preset;
    }
    final text = [name, groupName, subgroupName]
        .whereType<String>()
        .join(' ')
        .toLowerCase();
    const aliases = <String, FocusPreset>{
      'code': FocusPreset.coding,
      'coding': FocusPreset.coding,
      'debug': FocusPreset.debugging,
      'architecture': FocusPreset.architecture,
      'system design': FocusPreset.systemDesign,
      'machine learning': FocusPreset.aiMlResearch,
      'ai research': FocusPreset.aiMlResearch,
      'database': FocusPreset.databaseEngineering,
      'study': FocusPreset.study,
      'reading': FocusPreset.reading,
      'lecture': FocusPreset.lecture,
      'exam': FocusPreset.examPreparation,
      'math': FocusPreset.mathematics,
      'research paper': FocusPreset.researchPapers,
      'writing': FocusPreset.writing,
      'design': FocusPreset.designing,
      'drawing': FocusPreset.drawing,
      'music': FocusPreset.musicComposition,
      'brainstorm': FocusPreset.brainstorming,
      'meeting': FocusPreset.meeting,
      'planning': FocusPreset.planning,
      'documentation': FocusPreset.documentation,
      'project management': FocusPreset.projectManagement,
      'journal': FocusPreset.journaling,
      'language': FocusPreset.languageLearning,
      'meditation': FocusPreset.meditation,
      'reflection': FocusPreset.reflection,
      'data analysis': FocusPreset.dataAnalysis,
      'problem solving': FocusPreset.problemSolving,
      'financial analysis': FocusPreset.financialAnalysis,
      'technical research': FocusPreset.technicalResearch,
    };
    for (final entry in aliases.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    for (final preset in FocusPreset.values) {
      if (text.contains(preset.label.toLowerCase())) return preset;
    }
    return null;
  }

  String get categoryLabel => [groupName, subgroupName]
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .join(' · ');

  FocusActivityTemplate copyWith({
    String? name,
    String? groupName,
    String? subgroupName,
    int? defaultDurationMinutes,
    String? visualPresetName,
  }) =>
      FocusActivityTemplate(
        id: id,
        name: name ?? this.name,
        groupName: groupName ?? this.groupName,
        subgroupName: subgroupName ?? this.subgroupName,
        defaultDurationMinutes:
            defaultDurationMinutes ?? this.defaultDurationMinutes,
        visualPresetName: visualPresetName ?? this.visualPresetName,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'group_name': groupName,
        'subgroup_name': subgroupName,
        'default_duration_minutes': defaultDurationMinutes,
        'visual_preset_name': visualPresetName,
      };

  factory FocusActivityTemplate.fromJson(Map<String, Object?> json) =>
      FocusActivityTemplate(
        id: json['id']! as String,
        name: json['name']! as String,
        groupName: json['group_name'] as String?,
        subgroupName: json['subgroup_name'] as String?,
        defaultDurationMinutes: json['default_duration_minutes']! as int,
        visualPresetName: json['visual_preset_name'] as String?,
      );
}

class FocusActivitySettings {
  const FocusActivitySettings({
    this.customActivities = const [],
    this.defaultDurations = const {},
  });

  final List<FocusActivityTemplate> customActivities;
  final Map<String, int> defaultDurations;

  int durationFor(FocusPreset preset) =>
      defaultDurations[preset.name] ?? preset.defaultDuration.inMinutes;

  FocusActivitySettings copyWith({
    List<FocusActivityTemplate>? customActivities,
    Map<String, int>? defaultDurations,
  }) =>
      FocusActivitySettings(
        customActivities: customActivities ?? this.customActivities,
        defaultDurations: defaultDurations ?? this.defaultDurations,
      );

  Map<String, Object?> toJson() => {
        'custom_activities':
            customActivities.map((item) => item.toJson()).toList(),
        'default_durations': defaultDurations,
      };

  factory FocusActivitySettings.fromJson(Map<String, Object?> json) =>
      FocusActivitySettings(
        customActivities: (json['custom_activities'] as List<Object?>? ?? [])
            .map((item) => FocusActivityTemplate.fromJson(
                Map<String, Object?>.from(item! as Map)))
            .toList(),
        defaultDurations: Map<String, int>.from(
          json['default_durations'] as Map? ?? const {},
        ),
      );
}

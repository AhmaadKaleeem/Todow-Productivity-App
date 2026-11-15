import 'package:todow/domain/models/enums.dart';

enum FocusActivityCategory {
  development('Technical'),
  learning('Learning'),
  creativeWork('Creative'),
  professionalWork('Work'),
  personalGrowth('Personal'),
  analyticalWork('Technical'),
  userActivities('My activities');

  const FocusActivityCategory(this.label);

  final String label;
}

class FocusActivityDefinition {
  const FocusActivityDefinition({
    required this.activity,
    required this.category,
    required this.environment,
  });

  final FocusPreset activity;
  final FocusActivityCategory category;
  final String environment;

  static const values = <FocusActivityDefinition>[
    FocusActivityDefinition(
        activity: FocusPreset.coding,
        category: FocusActivityCategory.development,
        environment: 'A quiet editor, terminal and desk lamp.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.debugging,
        category: FocusActivityCategory.development,
        environment: 'A narrowed trace beside a diagnostic console.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.architecture,
        category: FocusActivityCategory.development,
        environment: 'A layered system map with connected components.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.systemDesign,
        category: FocusActivityCategory.development,
        environment: 'A service topology with deliberate flow paths.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.aiMlResearch,
        category: FocusActivityCategory.development,
        environment: 'A research board of model, data and evaluation.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.databaseEngineering,
        category: FocusActivityCategory.development,
        environment: 'A schema desk with linked tables and query plan.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.study,
        category: FocusActivityCategory.learning,
        environment: 'A study desk with prompt cards and open notes.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.reading,
        category: FocusActivityCategory.learning,
        environment: 'An open folio in soft window light.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.lecture,
        category: FocusActivityCategory.learning,
        environment:
            'A lecture page organized around speaker, notes and key ideas.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.examPreparation,
        category: FocusActivityCategory.learning,
        environment: 'A quiet paper, answer area and review margin.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.mathematics,
        category: FocusActivityCategory.learning,
        environment: 'A ruled mathematics page with an active derivation.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.researchPapers,
        category: FocusActivityCategory.learning,
        environment: 'A paper margin linked to methods and findings.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.writing,
        category: FocusActivityCategory.creativeWork,
        environment: 'An uncluttered manuscript page with room to think.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.designing,
        category: FocusActivityCategory.creativeWork,
        environment: 'A design board with layout frames and measured spacing.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.drawing,
        category: FocusActivityCategory.creativeWork,
        environment: 'A sketchbook, construction lines and a graphite study.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.musicComposition,
        category: FocusActivityCategory.creativeWork,
        environment: 'A score beside a restrained piano-roll phrase.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.brainstorming,
        category: FocusActivityCategory.creativeWork,
        environment: 'A spacious ideation board with grouped notes.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.assignment,
        category: FocusActivityCategory.professionalWork,
        environment: 'A brief, evidence sheet and ordered checklist.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.deepWork,
        category: FocusActivityCategory.professionalWork,
        environment: 'A pared-back desk with one clear working surface.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.meeting,
        category: FocusActivityCategory.professionalWork,
        environment: 'A shared agenda with a focused decision area.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.planning,
        category: FocusActivityCategory.professionalWork,
        environment: 'A time-blocked weekly plan with open capacity.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.documentation,
        category: FocusActivityCategory.professionalWork,
        environment: 'A structured document with linked sections.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.projectManagement,
        category: FocusActivityCategory.professionalWork,
        environment: 'A milestone board with dependency lines and owners.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.flow,
        category: FocusActivityCategory.professionalWork,
        environment: 'A settled workspace with a clear recovery horizon.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.journaling,
        category: FocusActivityCategory.personalGrowth,
        environment: 'A private journal with generous paper and a pen.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.languageLearning,
        category: FocusActivityCategory.personalGrowth,
        environment: 'A bilingual notebook pairing phrases and meaning.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.meditation,
        category: FocusActivityCategory.personalGrowth,
        environment: 'A still horizon with a soft, grounded seat.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.reflection,
        category: FocusActivityCategory.personalGrowth,
        environment: 'A reflective page with observation and next step.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.dataAnalysis,
        category: FocusActivityCategory.analyticalWork,
        environment: 'A restrained plot, distribution and observation log.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.problemSolving,
        category: FocusActivityCategory.analyticalWork,
        environment: 'A problem map from constraint to candidate solution.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.financialAnalysis,
        category: FocusActivityCategory.analyticalWork,
        environment: 'A ledger, scenario columns and a balanced scale.',
    ),
    FocusActivityDefinition(
        activity: FocusPreset.technicalResearch,
        category: FocusActivityCategory.analyticalWork,
        environment: 'A source map joining question, evidence and conclusion.',
    ),
  ];

  static FocusActivityDefinition forActivity(FocusPreset activity) =>
      values.firstWhere((definition) => definition.activity == activity);

  static List<FocusActivityDefinition> inCategory(
    FocusActivityCategory category,
  ) =>
      values.where((definition) => definition.category == category).toList();
}

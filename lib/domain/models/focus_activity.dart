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
    required this.description,
    required this.environment,
    required this.workSurface,
  });

  final FocusPreset activity;
  final FocusActivityCategory category;
  final String description;
  final String environment;
  final String workSurface;

  static const values = <FocusActivityDefinition>[
    FocusActivityDefinition(
        activity: FocusPreset.coding,
        category: FocusActivityCategory.development,
        description: 'Build a feature or refine a codebase.',
        environment: 'A quiet editor, terminal and desk lamp.',
        workSurface: 'EDITOR  ·  TERMINAL  ·  BUILD'),
    FocusActivityDefinition(
        activity: FocusPreset.debugging,
        category: FocusActivityCategory.development,
        description: 'Trace a fault from symptom to cause.',
        environment: 'A narrowed trace beside a diagnostic console.',
        workSurface: 'TRACE  ·  INSPECT  ·  VERIFY'),
    FocusActivityDefinition(
        activity: FocusPreset.architecture,
        category: FocusActivityCategory.development,
        description: 'Shape modules, boundaries and interfaces.',
        environment: 'A layered system map with connected components.',
        workSurface: 'MODULES  ·  CONTRACTS  ·  BOUNDARIES'),
    FocusActivityDefinition(
        activity: FocusPreset.systemDesign,
        category: FocusActivityCategory.development,
        description: 'Design services, data flow and trade-offs.',
        environment: 'A service topology with deliberate flow paths.',
        workSurface: 'REQUESTS  ·  SERVICES  ·  STORAGE'),
    FocusActivityDefinition(
        activity: FocusPreset.aiMlResearch,
        category: FocusActivityCategory.development,
        description: 'Explore models, methods and experiments.',
        environment: 'A research board of model, data and evaluation.',
        workSurface: 'DATA  ·  MODEL  ·  EVALUATION'),
    FocusActivityDefinition(
        activity: FocusPreset.databaseEngineering,
        category: FocusActivityCategory.development,
        description: 'Model, query and tune data systems.',
        environment: 'A schema desk with linked tables and query plan.',
        workSurface: 'SCHEMA  ·  QUERY  ·  INDEX'),
    FocusActivityDefinition(
        activity: FocusPreset.study,
        category: FocusActivityCategory.learning,
        description: 'Review course material and build recall.',
        environment: 'A study desk with prompt cards and open notes.',
        workSurface: 'RETRIEVE  ·  CHECK  ·  KEEP'),
    FocusActivityDefinition(
        activity: FocusPreset.reading,
        category: FocusActivityCategory.learning,
        description: 'Read a chapter slowly and attentively.',
        environment: 'An open folio in soft window light.',
        workSurface: 'READ  ·  TRACE  ·  CONNECT'),
    FocusActivityDefinition(
        activity: FocusPreset.lecture,
        category: FocusActivityCategory.learning,
        description: 'Follow a lecture and capture its structure.',
        environment:
            'A lecture page organized around speaker, notes and key ideas.',
        workSurface: 'LISTEN  ·  NOTE  ·  RECALL'),
    FocusActivityDefinition(
        activity: FocusPreset.examPreparation,
        category: FocusActivityCategory.learning,
        description: 'Practice retrieval under exam conditions.',
        environment: 'A quiet paper, answer area and review margin.',
        workSurface: 'RECALL  ·  ANSWER  ·  REVIEW'),
    FocusActivityDefinition(
        activity: FocusPreset.mathematics,
        category: FocusActivityCategory.learning,
        description: 'Work through proofs, exercises or derivations.',
        environment: 'A ruled mathematics page with an active derivation.',
        workSurface: 'GIVEN  ·  DERIVE  ·  PROVE'),
    FocusActivityDefinition(
        activity: FocusPreset.researchPapers,
        category: FocusActivityCategory.learning,
        description: 'Read papers and connect claims to evidence.',
        environment: 'A paper margin linked to methods and findings.',
        workSurface: 'CLAIM  ·  METHOD  ·  EVIDENCE'),
    FocusActivityDefinition(
        activity: FocusPreset.writing,
        category: FocusActivityCategory.creativeWork,
        description: 'Draft, revise or shape a piece of writing.',
        environment: 'An uncluttered manuscript page with room to think.',
        workSurface: 'DRAFT  ·  SHAPE  ·  REVISE'),
    FocusActivityDefinition(
        activity: FocusPreset.designing,
        category: FocusActivityCategory.creativeWork,
        description: 'Explore composition, hierarchy and interaction.',
        environment: 'A design board with layout frames and measured spacing.',
        workSurface: 'COMPOSE  ·  TEST  ·  REFINE'),
    FocusActivityDefinition(
        activity: FocusPreset.drawing,
        category: FocusActivityCategory.creativeWork,
        description: 'Draw studies, forms or a finished piece.',
        environment: 'A sketchbook, construction lines and a graphite study.',
        workSurface: 'OBSERVE  ·  BLOCK  ·  DETAIL'),
    FocusActivityDefinition(
        activity: FocusPreset.musicComposition,
        category: FocusActivityCategory.creativeWork,
        description: 'Develop a musical phrase or arrangement.',
        environment: 'A score beside a restrained piano-roll phrase.',
        workSurface: 'MOTIF  ·  PHRASE  ·  ARRANGE'),
    FocusActivityDefinition(
        activity: FocusPreset.brainstorming,
        category: FocusActivityCategory.creativeWork,
        description: 'Generate ideas, then find useful connections.',
        environment: 'A spacious ideation board with grouped notes.',
        workSurface: 'IDEAS  ·  CLUSTERS  ·  THREADS'),
    FocusActivityDefinition(
        activity: FocusPreset.assignment,
        category: FocusActivityCategory.professionalWork,
        description: 'Move a deliverable from question to revision.',
        environment: 'A brief, evidence sheet and ordered checklist.',
        workSurface: 'QUESTION  ·  EVIDENCE  ·  DRAFT'),
    FocusActivityDefinition(
        activity: FocusPreset.deepWork,
        category: FocusActivityCategory.professionalWork,
        description: 'Protect attention for one demanding outcome.',
        environment: 'A pared-back desk with one clear working surface.',
        workSurface: 'ONE THING  ·  STAY WITH IT'),
    FocusActivityDefinition(
        activity: FocusPreset.meeting,
        category: FocusActivityCategory.professionalWork,
        description: 'Listen, contribute and record decisions.',
        environment: 'A shared agenda with a focused decision area.',
        workSurface: 'AGENDA  ·  DECISIONS  ·  ACTIONS'),
    FocusActivityDefinition(
        activity: FocusPreset.planning,
        category: FocusActivityCategory.professionalWork,
        description: 'Turn priorities into a realistic next sequence.',
        environment: 'A time-blocked weekly plan with open capacity.',
        workSurface: 'PRIORITY  ·  SEQUENCE  ·  CAPACITY'),
    FocusActivityDefinition(
        activity: FocusPreset.documentation,
        category: FocusActivityCategory.professionalWork,
        description: 'Explain a system clearly for its next reader.',
        environment: 'A structured document with linked sections.',
        workSurface: 'CONTEXT  ·  STEPS  ·  REFERENCE'),
    FocusActivityDefinition(
        activity: FocusPreset.projectManagement,
        category: FocusActivityCategory.professionalWork,
        description: 'Coordinate work, dependencies and delivery.',
        environment: 'A milestone board with dependency lines and owners.',
        workSurface: 'SCOPE  ·  DEPENDENCIES  ·  DELIVERY'),
    FocusActivityDefinition(
        activity: FocusPreset.flow,
        category: FocusActivityCategory.professionalWork,
        description: 'Work for 90 minutes, then take a real 20-minute break.',
        environment: 'A settled workspace with a clear recovery horizon.',
        workSurface: 'FOCUS  90 MIN  ·  RECOVER  20 MIN'),
    FocusActivityDefinition(
        activity: FocusPreset.journaling,
        category: FocusActivityCategory.personalGrowth,
        description: 'Put thoughts into words without editing yourself.',
        environment: 'A private journal with generous paper and a pen.',
        workSurface: 'NOTICE  ·  NAME  ·  UNLOAD'),
    FocusActivityDefinition(
        activity: FocusPreset.languageLearning,
        category: FocusActivityCategory.personalGrowth,
        description: 'Practice vocabulary, listening or conversation.',
        environment: 'A bilingual notebook pairing phrases and meaning.',
        workSurface: 'HEAR  ·  RETRIEVE  ·  USE'),
    FocusActivityDefinition(
        activity: FocusPreset.meditation,
        category: FocusActivityCategory.personalGrowth,
        description: 'Stay with the breath and return gently.',
        environment: 'A still horizon with a soft, grounded seat.',
        workSurface: 'ARRIVE  ·  BREATHE  ·  RETURN'),
    FocusActivityDefinition(
        activity: FocusPreset.reflection,
        category: FocusActivityCategory.personalGrowth,
        description: 'Review an experience and choose what to carry forward.',
        environment: 'A reflective page with observation and next step.',
        workSurface: 'NOTICE  ·  LEARN  ·  CARRY FORWARD'),
    FocusActivityDefinition(
        activity: FocusPreset.dataAnalysis,
        category: FocusActivityCategory.analyticalWork,
        description: 'Inspect data, patterns and uncertainty.',
        environment: 'A restrained plot, distribution and observation log.',
        workSurface: 'MEASURE  ·  COMPARE  ·  EXPLAIN'),
    FocusActivityDefinition(
        activity: FocusPreset.problemSolving,
        category: FocusActivityCategory.analyticalWork,
        description: 'Break an ambiguous problem into testable parts.',
        environment: 'A problem map from constraint to candidate solution.',
        workSurface: 'DEFINE  ·  TEST  ·  SOLVE'),
    FocusActivityDefinition(
        activity: FocusPreset.financialAnalysis,
        category: FocusActivityCategory.analyticalWork,
        description: 'Compare assumptions, scenarios and outcomes.',
        environment: 'A ledger, scenario columns and a balanced scale.',
        workSurface: 'ASSUMPTIONS  ·  SCENARIOS  ·  OUTCOME'),
    FocusActivityDefinition(
        activity: FocusPreset.technicalResearch,
        category: FocusActivityCategory.analyticalWork,
        description: 'Investigate a technical question across sources.',
        environment: 'A source map joining question, evidence and conclusion.',
        workSurface: 'QUESTION  ·  SOURCES  ·  FINDING'),
  ];

  static FocusActivityDefinition forActivity(FocusPreset activity) =>
      values.firstWhere((definition) => definition.activity == activity);

  static List<FocusActivityDefinition> inCategory(
    FocusActivityCategory category,
  ) =>
      values.where((definition) => definition.category == category).toList();
}

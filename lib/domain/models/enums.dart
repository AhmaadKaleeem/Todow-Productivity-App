enum TaskStatus { inbox, active, completed, archived }

enum TaskPriority { none, low, medium, high, critical }

enum TaskSourceType { local, gmail, classroom, airUniversity, calendar }

enum ReminderPreset { normal, assignment, critical, daily, custom }

enum ReminderAlertBehavior {
  silent,
  beep,
  soundAndVibration,
  fullScreen,
  repeated,
}

enum ReminderStatus { pending, fired, snoozed, handled, cancelled }

enum ReminderKind { relative, absolute, atDeadline, daily, constant }

enum FocusPreset {
  study,
  coding,
  assignment,
  reading,
  deepWork,
  flow,
  debugging,
  architecture,
  systemDesign,
  aiMlResearch,
  databaseEngineering,
  lecture,
  examPreparation,
  mathematics,
  researchPapers,
  writing,
  designing,
  drawing,
  musicComposition,
  brainstorming,
  meeting,
  planning,
  documentation,
  projectManagement,
  journaling,
  languageLearning,
  meditation,
  reflection,
  dataAnalysis,
  problemSolving,
  financialAnalysis,
  technicalResearch,
}

enum FocusSessionStatus { idle, running, paused, ended }

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

enum TimetableKind { university, personal }

extension WeekdayExt on Weekday {
  int get dartWeekday => index + 1;

  static Weekday fromDartWeekday(int day) => Weekday.values[day - 1];

  String get shortLabel {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[index];
  }

  String get fullLabel {
    const labels = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return labels[index];
  }
}

extension TaskPriorityExt on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.none:
        return 'None';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.critical:
        return 'Critical';
    }
  }
}

extension ReminderPresetExt on ReminderPreset {
  String get label {
    switch (this) {
      case ReminderPreset.normal:
        return 'Normal';
      case ReminderPreset.assignment:
        return 'Assignment';
      case ReminderPreset.critical:
        return 'Critical';
      case ReminderPreset.daily:
        return 'Daily';
      case ReminderPreset.custom:
        return 'Custom';
    }
  }
}

extension FocusPresetExt on FocusPreset {
  String get label {
    switch (this) {
      case FocusPreset.study:
        return 'Study';
      case FocusPreset.coding:
        return 'Coding';
      case FocusPreset.assignment:
        return 'Assignment';
      case FocusPreset.reading:
        return 'Reading';
      case FocusPreset.deepWork:
        return 'Deep Work';
      case FocusPreset.flow:
        return 'Ultradian';
      case FocusPreset.debugging:
        return 'Debugging';
      case FocusPreset.architecture:
        return 'Software Architecture';
      case FocusPreset.systemDesign:
        return 'System Design';
      case FocusPreset.aiMlResearch:
        return 'AI / ML Research';
      case FocusPreset.databaseEngineering:
        return 'Database Engineering';
      case FocusPreset.lecture:
        return 'Lecture';
      case FocusPreset.examPreparation:
        return 'Exam Preparation';
      case FocusPreset.mathematics:
        return 'Mathematics';
      case FocusPreset.researchPapers:
        return 'Research Papers';
      case FocusPreset.writing:
        return 'Writing';
      case FocusPreset.designing:
        return 'Designing';
      case FocusPreset.drawing:
        return 'Drawing';
      case FocusPreset.musicComposition:
        return 'Music Composition';
      case FocusPreset.brainstorming:
        return 'Brainstorming';
      case FocusPreset.meeting:
        return 'Meeting';
      case FocusPreset.planning:
        return 'Planning';
      case FocusPreset.documentation:
        return 'Documentation';
      case FocusPreset.projectManagement:
        return 'Project Management';
      case FocusPreset.journaling:
        return 'Journaling';
      case FocusPreset.languageLearning:
        return 'Language Learning';
      case FocusPreset.meditation:
        return 'Meditation';
      case FocusPreset.reflection:
        return 'Reflection';
      case FocusPreset.dataAnalysis:
        return 'Data Analysis';
      case FocusPreset.problemSolving:
        return 'Problem Solving';
      case FocusPreset.financialAnalysis:
        return 'Financial Analysis';
      case FocusPreset.technicalResearch:
        return 'Technical Research';
    }
  }

  Duration get defaultDuration {
    switch (this) {
      case FocusPreset.study:
        return const Duration(minutes: 50);
      case FocusPreset.coding:
        return const Duration(minutes: 90);
      case FocusPreset.assignment:
        return const Duration(minutes: 90);
      case FocusPreset.reading:
        return const Duration(minutes: 45);
      case FocusPreset.deepWork:
        return const Duration(minutes: 120);
      case FocusPreset.flow:
        return const Duration(minutes: 90);
      case FocusPreset.debugging:
      case FocusPreset.architecture:
      case FocusPreset.systemDesign:
      case FocusPreset.aiMlResearch:
      case FocusPreset.databaseEngineering:
      case FocusPreset.lecture:
      case FocusPreset.researchPapers:
      case FocusPreset.writing:
      case FocusPreset.designing:
      case FocusPreset.drawing:
      case FocusPreset.musicComposition:
      case FocusPreset.brainstorming:
      case FocusPreset.meeting:
      case FocusPreset.planning:
      case FocusPreset.documentation:
      case FocusPreset.projectManagement:
      case FocusPreset.journaling:
      case FocusPreset.languageLearning:
      case FocusPreset.reflection:
      case FocusPreset.dataAnalysis:
      case FocusPreset.problemSolving:
      case FocusPreset.financialAnalysis:
      case FocusPreset.technicalResearch:
        return const Duration(minutes: 50);
      case FocusPreset.examPreparation:
      case FocusPreset.mathematics:
        return const Duration(minutes: 45);
      case FocusPreset.meditation:
        return const Duration(minutes: 20);
    }
  }

  Duration get restDuration {
    switch (this) {
      case FocusPreset.flow:
        return const Duration(minutes: 20);
      default:
        return const Duration(minutes: 5);
    }
  }
}

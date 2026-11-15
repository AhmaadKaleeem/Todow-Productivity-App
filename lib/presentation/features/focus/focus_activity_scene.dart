import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/focus_activity.dart';
import 'package:todow/domain/models/focus_timeline.dart';

class FocusActivityScene extends StatelessWidget {
  const FocusActivityScene({
    super.key,
    required this.preset,
    required this.timeline,
    required this.isRunning,
    this.compact = false,
    this.activityLabel,
    this.mixedEnvironment = false,
    this.accent,
  });

  final FocusPreset preset;
  final FocusTimeline timeline;
  final bool isRunning;
  final bool compact;
  final String? activityLabel;
  final bool mixedEnvironment;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final activity = FocusActivityDefinition.forActivity(preset);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final transitionDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 420);
    final entryDuration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 600);

    return Semantics(
      label: '${activityLabel ?? preset.label} environment',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: entryDuration,
        curve: Curves.easeOutCubic,
        builder: (context, entry, child) => Transform.translate(
          offset: Offset(0, reduceMotion ? 0 : (1 - entry) * 6),
          child: Opacity(
            opacity: reduceMotion ? 1 : 0.84 + entry * 0.16,
            child: child,
          ),
        ),
        child: Container(
          width: double.infinity,
          height: compact ? 168 : double.infinity,
          decoration: BoxDecoration(
            color: _surfaceColor(activity.category),
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(compact ? 18 : 0),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: transitionDuration,
            reverseDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: reduceMotion
                  ? child
                  : SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.012),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
            ),
            child: CustomPaint(
              key: ValueKey(
                  '${preset.name}:${timeline.phase.name}:${activityLabel ?? ''}:$mixedEnvironment'),
              painter: _FocusEnvironmentPainter(
                preset: preset,
                timeline: timeline,
                reducedMotion: reduceMotion,
                mixedEnvironment: mixedEnvironment,
                accent: accent,
              ),
              child: Stack(
                children: [
                  if (compact)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.94),
                          border: Border(
                            top: BorderSide(
                              color: AppColors.divider.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                        child: Text(
                          activity.environment,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusEnvironmentPainter extends CustomPainter {
  const _FocusEnvironmentPainter({
    required this.preset,
    required this.timeline,
    required this.reducedMotion,
    required this.mixedEnvironment,
    required this.accent,
  });

  final FocusPreset preset;
  final FocusTimeline timeline;
  final bool reducedMotion;
  final bool mixedEnvironment;
  final Color? accent;

  @override
  void paint(Canvas canvas, Size size) {
    final activity = FocusActivityDefinition.forActivity(preset);
    final phase = timeline.phase;
    final progress = reducedMotion ? 0.0 : timeline.progress;
    final background = _surfaceColor(activity.category);
    final sceneAccent = accent ?? _activityAccent(preset);

    canvas.drawColor(background, BlendMode.src);
    if (mixedEnvironment) {
      _paintDefaultMix(canvas, size, progress, sceneAccent);
    } else {
      _paintActivity(canvas, size, progress, sceneAccent);
    }
    if (phase == FocusAnimationPhase.completion) {
      _paintCompletion(canvas, size, sceneAccent);
    }
  }

  void _paintActivity(
    Canvas canvas,
    Size size,
    double progress,
    Color accent,
  ) {
    switch (preset) {
      case FocusPreset.coding:
        _paintCoding(canvas, size, progress, accent);
      case FocusPreset.debugging:
        _paintDebugging(canvas, size, progress, accent);
      case FocusPreset.architecture:
        _paintArchitecture(canvas, size, progress, accent);
      case FocusPreset.systemDesign:
        _paintSystemDesign(canvas, size, progress, accent);
      case FocusPreset.aiMlResearch:
        _paintAiResearch(canvas, size, progress, accent);
      case FocusPreset.databaseEngineering:
        _paintDatabase(canvas, size, progress, accent);
      case FocusPreset.study:
        _paintStudy(canvas, size, progress, accent);
      case FocusPreset.reading:
        _paintReading(canvas, size, progress, accent);
      case FocusPreset.lecture:
        _paintLecture(canvas, size, progress, accent);
      case FocusPreset.examPreparation:
        _paintExam(canvas, size, progress, accent);
      case FocusPreset.mathematics:
        _paintMathematics(canvas, size, progress, accent);
      case FocusPreset.researchPapers:
        _paintPaper(canvas, size, progress, accent);
      case FocusPreset.writing:
        _paintWriting(canvas, size, progress, accent);
      case FocusPreset.designing:
        _paintDesign(canvas, size, progress, accent);
      case FocusPreset.drawing:
        _paintDrawing(canvas, size, progress, accent);
      case FocusPreset.musicComposition:
        _paintMusic(canvas, size, progress, accent);
      case FocusPreset.brainstorming:
        _paintBrainstorm(canvas, size, progress, accent);
      case FocusPreset.assignment:
        _paintAssignment(canvas, size, progress, accent);
      case FocusPreset.deepWork:
        _paintDeepWork(canvas, size, progress, accent);
      case FocusPreset.flow:
        _paintUltradian(canvas, size, progress, accent);
      case FocusPreset.meeting:
        _paintMeeting(canvas, size, progress, accent);
      case FocusPreset.planning:
        _paintPlanning(canvas, size, progress, accent);
      case FocusPreset.documentation:
        _paintDocumentation(canvas, size, progress, accent);
      case FocusPreset.projectManagement:
        _paintProjectBoard(canvas, size, progress, accent);
      case FocusPreset.journaling:
        _paintJournal(canvas, size, progress, accent);
      case FocusPreset.languageLearning:
        _paintLanguage(canvas, size, progress, accent);
      case FocusPreset.meditation:
        _paintMeditation(canvas, size, progress, accent);
      case FocusPreset.reflection:
        _paintReflection(canvas, size, progress, accent);
      case FocusPreset.dataAnalysis:
        _paintDataAnalysis(canvas, size, progress, accent);
      case FocusPreset.problemSolving:
        _paintProblemSolving(canvas, size, progress, accent);
      case FocusPreset.financialAnalysis:
        _paintFinancialAnalysis(canvas, size, progress, accent);
      case FocusPreset.technicalResearch:
        _paintTechnicalResearch(canvas, size, progress, accent);
    }
  }

  void _paintDefaultMix(
      Canvas canvas, Size size, double progress, Color accent) {
    final editor =
        _panel(canvas, size, 0.09, 0.24, 0.34, 0.39, const Color(0xFF29363B));
    _text(canvas, 'WORKSPACE', Offset(editor.left + 10, editor.top + 13),
        const Color(0xFFDCE5E3), 8);
    _lines(canvas, editor, 0.10, 0.24, 0.76, 4, 14, const Color(0xFFB8D5D5));
    final page =
        _card(canvas, size, 0.48, 0.25, 0.20, 0.38, const Color(0xFFFFFCF5));
    _text(
        canvas, 'WORK NOTES', Offset(page.left + 8, page.top + 14), accent, 7);
    _lines(canvas, page, 0.12, 0.32, 0.72, 5, 13, const Color(0xFFBEB4A3));
    _node(canvas, size, 0.19, 0.69, 'IDEA', accent);
    _node(canvas, size, 0.39, 0.69, 'NEXT', const Color(0xFF718477));
    _connector(canvas, Offset(size.width * 0.25, size.height * 0.69),
        Offset(size.width * 0.32, size.height * 0.69), accent, true);
  }

  void _paintCoding(Canvas canvas, Size size, double progress, Color accent) {
    final editor =
        _panel(canvas, size, 0.09, 0.22, 0.43, 0.47, const Color(0xFF26323A));
    _text(canvas, 'main.dart', Offset(editor.left + 12, editor.top + 14),
        const Color(0xFFDCE5E3), 10);
    _lines(canvas, editor, 0.09, 0.23, 0.78, 7, 12, const Color(0xFFB8D5D5));
    final terminal =
        _panel(canvas, size, 0.54, 0.42, 0.16, 0.27, const Color(0xFF34434A));
    _text(canvas, 'TERMINAL', Offset(terminal.left + 8, terminal.top + 12),
        const Color(0xFFA5C1B9), 8);
    _lines(canvas, terminal, 0.10, 0.36, 0.74, 3, 11, const Color(0xFFA5C1B9));
    _progressCaret(canvas, editor, progress, accent);
  }

  void _paintDebugging(
      Canvas canvas, Size size, double progress, Color accent) {
    final trace =
        _panel(canvas, size, 0.11, 0.23, 0.36, 0.46, const Color(0xFF28353B));
    _text(canvas, 'STACK TRACE', Offset(trace.left + 12, trace.top + 14),
        const Color(0xFFC5D2CF), 9);
    _lines(canvas, trace, 0.08, 0.25, 0.78, 6, 16, const Color(0xFFB2C4C1));
    final diagnosis =
        _panel(canvas, size, 0.50, 0.31, 0.20, 0.33, const Color(0xFFF4EEE2));
    _text(canvas, 'CAUSE', Offset(diagnosis.left + 10, diagnosis.top + 14),
        const Color(0xFF84745D), 8);
    _text(canvas, 'input → state',
        Offset(diagnosis.left + 10, diagnosis.top + 40), accent, 10);
    _text(canvas, 'INSPECT', Offset(diagnosis.left + 10, diagnosis.bottom - 18),
        const Color(0xFF6F7A6B), 8);
    _underline(canvas, diagnosis, progress, accent);
  }

  void _paintArchitecture(
      Canvas canvas, Size size, double progress, Color accent) {
    final labels = ['UI', 'DOMAIN', 'DATA'];
    for (var i = 0; i < labels.length; i++) {
      final rect = _card(canvas, size, 0.12 + i * 0.19,
          0.31 + (i.isOdd ? 0.07 : 0), 0.14, 0.20, const Color(0xFFF7F3E9));
      _text(canvas, labels[i], Offset(rect.left + 8, rect.center.dy - 4),
          const Color(0xFF53645E), 8);
      if (i < labels.length - 1) {
        _connector(
            canvas,
            rect.centerRight,
            Offset(rect.right + size.width * 0.05, rect.center.dy + 10),
            accent,
            progress > i * 0.35);
      }
    }
    _text(
        canvas,
        'CONTRACTS  ·  BOUNDARIES',
        Offset(size.width * 0.13, size.height * 0.63),
        const Color(0xFF728278),
        8);
  }

  void _paintSystemDesign(
      Canvas canvas, Size size, double progress, Color accent) {
    final nodes = [
      (0.12, 0.37, 'CLIENT'),
      (0.34, 0.27, 'API'),
      (0.34, 0.51, 'QUEUE'),
      (0.56, 0.27, 'SERVICE'),
      (0.56, 0.51, 'WORKER'),
      (0.74, 0.40, 'STORE'),
    ];
    for (var i = 0; i < nodes.length - 1; i++) {
      final a = Offset(size.width * nodes[i].$1, size.height * nodes[i].$2);
      final b =
          Offset(size.width * nodes[i + 1].$1, size.height * nodes[i + 1].$2);
      _connector(canvas, a, b, accent, progress > i / nodes.length);
    }
    for (final node in nodes) {
      _node(canvas, size, node.$1, node.$2, node.$3, accent);
    }
  }

  void _paintAiResearch(
      Canvas canvas, Size size, double progress, Color accent) {
    final labels = ['DATA', 'MODEL', 'EVAL'];
    for (var i = 0; i < 3; i++) {
      final x = 0.10 + i * 0.21;
      final rect =
          _card(canvas, size, x, 0.31, 0.16, 0.24, const Color(0xFFF5F1E7));
      _text(canvas, labels[i], Offset(rect.left + 9, rect.top + 17), accent, 8);
      if (i == 1) {
        for (var j = 0; j < 4; j++) {
          canvas.drawCircle(
              Offset(rect.left + 14 + j * 10, rect.bottom - 18 - (j % 2) * 9),
              2,
              Paint()..color = const Color(0xFF869A8A));
        }
      } else {
        _lines(canvas, rect, 0.12, 0.45, 0.65, 3, 11, const Color(0xFFAFB6A8));
      }
      if (i < 2) {
        _connector(
            canvas,
            rect.centerRight,
            Offset(rect.right + size.width * 0.05, rect.center.dy),
            accent,
            progress > i * 0.4);
      }
    }
  }

  void _paintDatabase(Canvas canvas, Size size, double progress, Color accent) {
    for (var table = 0; table < 2; table++) {
      final rect = _card(canvas, size, 0.12 + table * 0.25, 0.25 + table * 0.10,
          0.20, 0.31, const Color(0xFFF6F2E8));
      _text(canvas, table == 0 ? 'TASK' : 'REMINDER',
          Offset(rect.left + 8, rect.top + 12), accent, 8);
      for (var row = 0; row < 3; row++) {
        canvas.drawLine(
            Offset(rect.left + 6, rect.top + 30 + row * 20),
            Offset(rect.right - 6, rect.top + 30 + row * 20),
            Paint()..color = const Color(0xFFD8D4C8));
      }
    }
    _connector(canvas, Offset(size.width * 0.32, size.height * 0.50),
        Offset(size.width * 0.37, size.height * 0.55), accent, progress > 0.25);
    final query =
        _panel(canvas, size, 0.54, 0.36, 0.17, 0.24, const Color(0xFF34434A));
    _text(canvas, 'QUERY PLAN', Offset(query.left + 8, query.top + 13),
        const Color(0xFFB9D5CB), 8);
    _lines(canvas, query, 0.08, 0.47, 0.74, 3, 11, const Color(0xFFB9D5CB));
  }

  void _paintStudy(Canvas canvas, Size size, double progress, Color accent) {
    for (var i = 0; i < 3; i++) {
      final rect = _card(canvas, size, 0.13 + i * 0.17,
          0.28 + (i.isOdd ? 0.03 : 0), 0.13, 0.30, const Color(0xFFFFFCF5));
      _text(canvas, ['?', 'A', '✓'][i], Offset(rect.left + 14, rect.top + 15),
          i == 2 ? const Color(0xFF66836F) : accent, 18);
      _lines(canvas, rect, 0.08, 0.77, 0.68, 2, 7, const Color(0xFFC9D2C7));
    }
  }

  void _paintReading(Canvas canvas, Size size, double progress, Color accent) {
    final leftPage =
        _card(canvas, size, 0.13, 0.24, 0.26, 0.40, const Color(0xFFFFFCF2));
    final rightPage =
        _card(canvas, size, 0.39, 0.24, 0.26, 0.40, const Color(0xFFFFFCF2));
    _text(canvas, 'CHAPTER 04', Offset(leftPage.left + 14, leftPage.top + 14),
        const Color(0xFF7D705F), 8);
    _lines(canvas, leftPage, 0.09, 0.32, 0.78, 4, 10, const Color(0xFFBEB4A3));
    _lines(canvas, rightPage, 0.09, 0.32, 0.78, 4, 10, const Color(0xFFBEB4A3));
    final marker = leftPage.left + leftPage.width + rightPage.width * progress;
    canvas.drawRect(
        Rect.fromLTWH(marker, leftPage.top - 4, 3, leftPage.height + 8),
        Paint()..color = accent.withValues(alpha: 0.7));
  }

  void _paintLecture(Canvas canvas, Size size, double progress, Color accent) {
    final slide =
        _panel(canvas, size, 0.10, 0.22, 0.34, 0.42, const Color(0xFFE7E9E2));
    _text(canvas, 'LECTURE NOTES', Offset(slide.left + 12, slide.top + 13),
        const Color(0xFF6B796F), 8);
    _lines(canvas, slide, 0.10, 0.31, 0.76, 4, 11, const Color(0xFFAAB4A8));
    final notes =
        _card(canvas, size, 0.50, 0.28, 0.19, 0.38, const Color(0xFFFFFCF5));
    _text(
        canvas, 'KEY IDEAS', Offset(notes.left + 9, notes.top + 15), accent, 8);
    _lines(canvas, notes, 0.12, 0.40, 0.72, 3, 10, const Color(0xFFBEB4A3));
    _underline(canvas, notes, progress, accent);
  }

  void _paintExam(Canvas canvas, Size size, double progress, Color accent) {
    final sheet =
        _card(canvas, size, 0.14, 0.18, 0.38, 0.56, const Color(0xFFFFFCF6));
    _text(canvas, 'PRACTICE PAPER', Offset(sheet.left + 14, sheet.top + 14),
        const Color(0xFF786B5E), 8);
    final rowStep = (sheet.height - 36) / 5;
    for (var i = 0; i < 5; i++) {
      final y = sheet.top + 27 + (i + 0.5) * rowStep;
      canvas.drawCircle(
          Offset(sheet.left + 15, y),
          4,
          Paint()
            ..color = const Color(0xFFC9C0B2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      canvas.drawLine(Offset(sheet.left + 28, y), Offset(sheet.right - 12, y),
          Paint()..color = const Color(0xFFD7DED9));
    }
  }

  void _paintMathematics(
      Canvas canvas, Size size, double progress, Color accent) {
    final page =
        _card(canvas, size, 0.13, 0.18, 0.48, 0.56, const Color(0xFFFFFCF6));
    _text(canvas, 'f(x) = x² + 2x + 1', Offset(page.left + 16, page.top + 20),
        const Color(0xFF65766B), 13);
    _text(canvas, '∴  f(x) = (x + 1)²', Offset(page.left + 16, page.top + 48),
        accent, 12);
    _text(canvas, 'DERIVATION', Offset(page.left + 16, page.top + 66),
        const Color(0xFF8A8175), 9);
    _underline(canvas, page, progress, accent);
  }

  void _paintPaper(Canvas canvas, Size size, double progress, Color accent) {
    final page =
        _card(canvas, size, 0.15, 0.18, 0.36, 0.60, const Color(0xFFFFFCF6));
    _text(canvas, 'RESULTS', Offset(page.left + 16, page.top + 18),
        const Color(0xFF786B5E), 8);
    _lines(canvas, page, 0.10, 0.30, 0.74, 6, 12, const Color(0xFFB8B1A6));
    final margin =
        _card(canvas, size, 0.53, 0.26, 0.16, 0.42, const Color(0xFFE8ECE5));
    _text(canvas, 'CLAIM', Offset(margin.left + 8, margin.top + 14), accent, 8);
    _text(canvas, 'METHOD', Offset(margin.left + 8, margin.top + 34),
        const Color(0xFF6D7D70), 8);
    _text(canvas, 'EVIDENCE', Offset(margin.left + 8, margin.bottom - 15),
        const Color(0xFF6D7D70), 8);
    _progressCaret(canvas, margin, progress, accent);
  }

  void _paintWriting(Canvas canvas, Size size, double progress, Color accent) {
    final page =
        _card(canvas, size, 0.15, 0.18, 0.48, 0.60, const Color(0xFFFFFCF6));
    _text(canvas, 'Untitled draft', Offset(page.left + 18, page.top + 20),
        const Color(0xFF756A5D), 9);
    _lines(canvas, page, 0.11, 0.33, 0.74, 5, 11, const Color(0xFFB9B1A4));
    canvas.drawLine(
        Offset(page.left + 18, page.bottom - 12),
        Offset(page.left + 18 + page.width * (0.25 + progress * 0.53),
            page.bottom - 12),
        Paint()
          ..color = accent
          ..strokeWidth = 2);
  }

  void _paintDesign(Canvas canvas, Size size, double progress, Color accent) {
    for (var i = 0; i < 3; i++) {
      final frame = _card(canvas, size, 0.12 + i * 0.18, 0.20 + i % 2 * 0.04,
          0.15, 0.42, const Color(0xFFFFFCF6));
      canvas.drawRect(
          Rect.fromLTWH(frame.left + 8, frame.top + 12, frame.width - 16, 24),
          Paint()
            ..color = [
              const Color(0xFFDDE6E1),
              const Color(0xFFEADFCF),
              const Color(0xFFE0E3EA)
            ][i]);
      _lines(canvas, frame, 0.12, 0.62, 0.70, 2, 8, const Color(0xFFBEB4A3));
    }
    _text(canvas, 'GRID  ·  TYPE  ·  SPACE',
        Offset(size.width * 0.12, size.height * 0.72), accent, 8);
  }

  void _paintDrawing(Canvas canvas, Size size, double progress, Color accent) {
    final paper =
        _card(canvas, size, 0.13, 0.21, 0.40, 0.48, const Color(0xFFFFFCF6));
    final center = Offset(
        paper.left + paper.width * 0.54, paper.top + paper.height * 0.48);
    final radius = paper.width * 0.27;
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = accent.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF969183)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    canvas.drawLine(
        Offset(center.dx - radius, center.dy + radius * 0.4),
        Offset(center.dx + radius, center.dy - radius * 0.3),
        Paint()
          ..color = const Color(0xFFAAA28F)
          ..strokeWidth = 1);
    _text(canvas, 'FORM STUDY', Offset(paper.left + 12, paper.bottom - 16),
        const Color(0xFF7C7468), 8);
  }

  void _paintMusic(Canvas canvas, Size size, double progress, Color accent) {
    final score =
        _card(canvas, size, 0.11, 0.18, 0.42, 0.56, const Color(0xFFFFFCF6));
    final staffStep = (score.height - 30) / 4;
    for (var i = 0; i < 5; i++) {
      final y = score.top + 16 + i * staffStep;
      canvas.drawLine(Offset(score.left + 12, y), Offset(score.right - 12, y),
          Paint()..color = const Color(0xFFC8C0B3));
    }
    for (var i = 0; i < 5; i++) {
      final x = score.left + 35 + i * 28;
      final y = score.top + 81 - (i % 3) * 13;
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 8, height: 5),
          Paint()..color = const Color(0xFF756A5D));
      canvas.drawLine(
          Offset(x + 4, y),
          Offset(x + 4, y - 24),
          Paint()
            ..color = const Color(0xFF756A5D)
            ..strokeWidth = 1);
    }
    _text(
        canvas,
        'MOTIF  →  PHRASE  →  ARRANGEMENT',
        Offset(size.width * 0.12, size.height * 0.75),
        const Color(0xFF766E62),
        8);
  }

  void _paintBrainstorm(
      Canvas canvas, Size size, double progress, Color accent) {
    for (var i = 0; i < 5; i++) {
      final x = 0.12 + (i % 3) * 0.17;
      final y = 0.27 + (i ~/ 3) * 0.21 + (i.isOdd ? 0.025 : 0);
      final card =
          _card(canvas, size, x, y, 0.13, 0.15, const Color(0xFFFFFCF5));
      _lines(canvas, card, 0.12, 0.28, 0.62, 2, 12, const Color(0xFFB4A58E));
    }
    for (var i = 0; i < 4; i++) {
      _connector(
          canvas,
          Offset(size.width * (0.2 + i * 0.13), size.height * 0.4),
          Offset(size.width * (0.27 + i * 0.1), size.height * 0.54),
          accent,
          i / 4 < progress);
    }
  }

  void _paintAssignment(
      Canvas canvas, Size size, double progress, Color accent) {
    final sheet =
        _card(canvas, size, 0.13, 0.16, 0.40, 0.62, const Color(0xFFFFFCF6));
    _text(canvas, 'ARGUMENT / OUTLINE', Offset(sheet.left + 16, sheet.top + 14),
        const Color(0xFF766B5E), 8);
    const labels = ['Question', 'Evidence', 'Reasoning', 'Draft', 'Revise'];
    for (var i = 0; i < labels.length; i++) {
      final y = sheet.top + 30 + i * 14;
      canvas.drawCircle(
          Offset(sheet.left + 17, y),
          5,
          Paint()
            ..color = const Color(0xFFC9C0B2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3);
      _text(canvas, labels[i], Offset(sheet.left + 31, y - 5),
          const Color(0xFF746B5D), 9);
    }
  }

  void _paintDeepWork(Canvas canvas, Size size, double progress, Color accent) {
    final sheet =
        _card(canvas, size, 0.15, 0.20, 0.44, 0.58, const Color(0xFFFAF8EF));
    _text(canvas, 'ONE THING', Offset(sheet.left + 18, sheet.top + 19),
        const Color(0xFF786D5E), 9);
    canvas.drawLine(
        Offset(sheet.left + 18, sheet.top + 48),
        Offset(sheet.right - 18, sheet.top + 48),
        Paint()
          ..color = const Color(0xFFBFC0B2)
          ..strokeWidth = 2);
    canvas.drawLine(
        Offset(sheet.left + 18, sheet.top + 68),
        Offset(sheet.left + 18 + sheet.width * 0.35, sheet.top + 68),
        Paint()
          ..color = accent
          ..strokeWidth = 3);
    _text(canvas, 'ONE THING', Offset(sheet.left + 18, sheet.bottom - 15),
        const Color(0xFF7E8C7A), 9);
  }

  void _paintUltradian(
      Canvas canvas, Size size, double progress, Color accent) {
    final strip =
        _card(canvas, size, 0.12, 0.25, 0.52, 0.47, const Color(0xFFE8ECE5));
    final workWidth = strip.width * 0.82;
    canvas.drawRect(Rect.fromLTWH(strip.left + 8, strip.top + 28, workWidth, 9),
        Paint()..color = accent.withValues(alpha: 0.28));
    canvas.drawRect(
        Rect.fromLTWH(strip.left + 8, strip.top + 28, workWidth * progress, 9),
        Paint()..color = accent);
    canvas.drawRect(
        Rect.fromLTWH(
            strip.left + 8 + workWidth, strip.top + 28, strip.width * 0.15, 9),
        Paint()..color = const Color(0xFFD8C6A4));
    _text(canvas, 'FOCUS  ${timeline.plannedDuration.inMinutes} MIN',
        Offset(strip.left + 10, strip.top + 52), const Color(0xFF52675B), 8);
    _text(
        canvas,
        'RECOVER  ${preset.restDuration.inMinutes} MIN',
        Offset(strip.left + strip.width * 0.63, strip.top + 52),
        const Color(0xFF8A7659),
        8);
  }

  void _paintMeeting(Canvas canvas, Size size, double progress, Color accent) {
    final agenda =
        _card(canvas, size, 0.12, 0.20, 0.24, 0.58, const Color(0xFFFFFCF5));
    _text(
        canvas, 'AGENDA', Offset(agenda.left + 12, agenda.top + 17), accent, 8);
    _lines(canvas, agenda, 0.15, 0.34, 0.68, 5, 12, const Color(0xFFBEB4A3));
    final decision =
        _card(canvas, size, 0.43, 0.28, 0.23, 0.36, const Color(0xFFE8ECE5));
    _text(canvas, 'DECISION', Offset(decision.left + 12, decision.top + 17),
        const Color(0xFF62756A), 8);
    _lines(canvas, decision, 0.12, 0.42, 0.68, 3, 10, const Color(0xFFABB5A9));
    _progressCaret(canvas, decision, progress, accent);
  }

  void _paintPlanning(Canvas canvas, Size size, double progress, Color accent) {
    final left = size.width * 0.12;
    final right = size.width * 0.66;
    for (var lane = 0; lane < 3; lane++) {
      final y = size.height * (0.32 + lane * 0.12);
      canvas.drawLine(
          Offset(left, y),
          Offset(right, y),
          Paint()
            ..color = const Color(0xFFC9C5B8)
            ..strokeWidth = 2);
      final x = left + (right - left) * progress * (1 - lane * 0.08);
      canvas.drawCircle(Offset(x, y), 6,
          Paint()..color = lane == 0 ? accent : const Color(0xFF87978A));
    }
    _text(canvas, 'PRIORITY', Offset(left, size.height * 0.65),
        const Color(0xFF6F7C70), 8);
    _text(canvas, 'CAPACITY', Offset(right - 55, size.height * 0.65),
        const Color(0xFF6F7C70), 8);
  }

  void _paintDocumentation(
      Canvas canvas, Size size, double progress, Color accent) {
    final page =
        _card(canvas, size, 0.13, 0.18, 0.47, 0.62, const Color(0xFFFFFCF6));
    _text(canvas, 'SYSTEM GUIDE', Offset(page.left + 15, page.top + 14),
        const Color(0xFF766B5E), 8);
    for (var section = 0; section < 3; section++) {
      final y = page.top + 31 + section * 22;
      _text(
          canvas,
          ['Context', 'Procedure', 'Reference'][section],
          Offset(page.left + 15, y),
          section / 3 < progress ? accent : const Color(0xFF7B756C),
          9);
      canvas.drawLine(
          Offset(page.left + 15, y + 14),
          Offset(page.right - 13, y + 14),
          Paint()..color = const Color(0xFFD8D2C6));
    }
  }

  void _paintProjectBoard(
      Canvas canvas, Size size, double progress, Color accent) {
    for (var lane = 0; lane < 3; lane++) {
      final rect = _card(canvas, size, 0.11 + lane * 0.19, 0.20, 0.16, 0.58,
          const Color(0xFFE8ECE5));
      _text(canvas, ['READY', 'ACTIVE', 'DONE'][lane],
          Offset(rect.left + 8, rect.top + 12), const Color(0xFF637268), 7);
      for (var card = 0; card < 2; card++) {
        final y = rect.top + 25 + card * 34;
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(rect.left + 6, y, rect.width - 12, 27),
                const Radius.circular(3)),
            Paint()..color = const Color(0xFFFFFCF5));
        canvas.drawLine(
            Offset(rect.left + 12, y + 12),
            Offset(rect.right - 10, y + 12),
            Paint()..color = const Color(0xFFBEB9AC));
      }
    }
    _connector(canvas, Offset(size.width * 0.28, size.height * 0.48),
        Offset(size.width * 0.49, size.height * 0.48), accent, progress > 0.45);
  }

  void _paintJournal(Canvas canvas, Size size, double progress, Color accent) {
    final page =
        _card(canvas, size, 0.15, 0.18, 0.42, 0.62, const Color(0xFFFFFCF3));
    canvas.drawLine(
        Offset(page.left + 23, page.top + 10),
        Offset(page.left + 23, page.bottom - 10),
        Paint()..color = const Color(0xFFE4B9AA));
    _text(canvas, 'Dear journal,', Offset(page.left + 35, page.top + 19),
        const Color(0xFF877966), 9);
    _lines(canvas, page, 0.23, 0.34, 0.69, 5, 12, const Color(0xFFB9AF9F));
    canvas.drawLine(
        Offset(page.left + 35, page.bottom - 10),
        Offset(page.left + 35 + page.width * progress * 0.56, page.bottom - 10),
        Paint()
          ..color = accent
          ..strokeWidth = 1.4);
  }

  void _paintLanguage(Canvas canvas, Size size, double progress, Color accent) {
    final source =
        _card(canvas, size, 0.13, 0.24, 0.23, 0.40, const Color(0xFFE7ECE5));
    final phrase =
        _card(canvas, size, 0.41, 0.24, 0.23, 0.40, const Color(0xFFFFFCF5));
    _text(canvas, 'BUENOS DÍAS', Offset(source.left + 10, source.top + 16),
        const Color(0xFF617467), 9);
    _text(canvas, 'GOOD MORNING', Offset(phrase.left + 9, phrase.top + 16),
        accent, 8);
    _text(
        canvas,
        progress > 0.5 ? 'retrieve' : 'listen',
        Offset(source.left + 10, source.bottom - 14),
        const Color(0xFF8A8175),
        8);
    _connector(canvas, source.centerRight,
        Offset(phrase.left, phrase.center.dy), accent, progress > 0.35);
  }

  void _paintMeditation(
      Canvas canvas, Size size, double progress, Color accent) {
    final horizon = size.height * 0.48;
    canvas.drawRect(
        Rect.fromLTWH(
            size.width * 0.10, horizon, size.width * 0.58, size.height * 0.13),
        Paint()..color = const Color(0xFFDDE5DF));
    canvas.drawLine(
        Offset(size.width * 0.10, horizon),
        Offset(size.width * 0.68, horizon),
        Paint()
          ..color = const Color(0xFF9CAFA5)
          ..strokeWidth = 1);
    canvas.drawCircle(Offset(size.width * 0.39, size.height * 0.37),
        size.width * 0.022, Paint()..color = accent.withValues(alpha: 0.55));
    _text(
        canvas,
        'NOTICE  ·  BREATHE  ·  RETURN',
        Offset(size.width * 0.17, size.height * 0.64),
        const Color(0xFF74867C),
        8);
    final seat = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.34, size.height * 0.72, size.width * 0.14, 6),
        const Radius.circular(5));
    canvas.drawRRect(seat, Paint()..color = const Color(0xFF9D8D76));
  }

  void _paintReflection(
      Canvas canvas, Size size, double progress, Color accent) {
    final lineY = size.height * 0.48;
    canvas.drawLine(
        Offset(size.width * 0.13, lineY),
        Offset(size.width * 0.64, lineY),
        Paint()
          ..color = const Color(0xFFBDB6A9)
          ..strokeWidth = 2);
    for (var i = 0; i < 3; i++) {
      final x = size.width * (0.20 + i * 0.20);
      canvas.drawCircle(
          Offset(x, lineY), 7, Paint()..color = const Color(0xFFBDB6A9));
      _text(canvas, ['NOTICE', 'LEARN', 'NEXT'][i], Offset(x - 20, lineY + 20),
          const Color(0xFF726E64), 8);
    }
    final note =
        _card(canvas, size, 0.24, 0.27, 0.29, 0.15, const Color(0xFFFFFCF5));
    _lines(canvas, note, 0.12, 0.34, 0.7, 2, 13, const Color(0xFFBEB4A3));
  }

  void _paintDataAnalysis(
      Canvas canvas, Size size, double progress, Color accent) {
    final plot =
        _card(canvas, size, 0.11, 0.22, 0.39, 0.45, const Color(0xFFFFFCF6));
    final gridStep = (plot.height - 36) / 3;
    for (var i = 0; i < 4; i++) {
      final y = plot.top + 18 + i * gridStep;
      canvas.drawLine(Offset(plot.left + 20, y), Offset(plot.right - 8, y),
          Paint()..color = const Color(0xFFE1DDD3));
    }
    final points = [
      (0.19, 0.55),
      (0.25, 0.47),
      (0.31, 0.49),
      (0.37, 0.37),
      (0.44, 0.33)
    ];
    for (var i = 0; i < points.length; i++) {
      final point =
          Offset(size.width * points[i].$1, size.height * points[i].$2);
      if (i > 0) {
        _connector(
            canvas,
            Offset(
                size.width * points[i - 1].$1, size.height * points[i - 1].$2),
            point,
            accent,
            progress > i / points.length);
      }
      canvas.drawCircle(point, 3, Paint()..color = accent);
    }
    final note =
        _card(canvas, size, 0.54, 0.31, 0.16, 0.28, const Color(0xFFE8ECE5));
    _text(canvas, 'OBSERVE', Offset(note.left + 10, note.top + 17),
        const Color(0xFF637268), 8);
    _lines(canvas, note, 0.14, 0.40, 0.6, 2, 10, const Color(0xFFAFB6A8));
  }

  void _paintProblemSolving(
      Canvas canvas, Size size, double progress, Color accent) {
    _node(canvas, size, 0.18, 0.43, 'PROBLEM', accent);
    _node(canvas, size, 0.40, 0.30, 'CONSTRAINT', const Color(0xFF778A7B));
    _node(canvas, size, 0.40, 0.57, 'HYPOTHESIS', const Color(0xFF778A7B));
    _node(canvas, size, 0.64, 0.43, 'SOLUTION', accent);
    _connector(canvas, Offset(size.width * 0.25, size.height * 0.43),
        Offset(size.width * 0.35, size.height * 0.30), accent, progress > 0.2);
    _connector(canvas, Offset(size.width * 0.25, size.height * 0.43),
        Offset(size.width * 0.35, size.height * 0.57), accent, progress > 0.35);
    _connector(canvas, Offset(size.width * 0.47, size.height * 0.30),
        Offset(size.width * 0.59, size.height * 0.43), accent, progress > 0.55);
    _connector(canvas, Offset(size.width * 0.47, size.height * 0.57),
        Offset(size.width * 0.59, size.height * 0.43), accent, progress > 0.75);
  }

  void _paintFinancialAnalysis(
      Canvas canvas, Size size, double progress, Color accent) {
    final table =
        _card(canvas, size, 0.12, 0.20, 0.48, 0.58, const Color(0xFFFFFCF5));
    _text(
        canvas, 'SCENARIO', Offset(table.left + 11, table.top + 14), accent, 8);
    final rowStep = (table.height - 44) / 4;
    for (var row = 0; row < 4; row++) {
      final y = table.top + 31 + row * rowStep;
      canvas.drawLine(Offset(table.left + 10, y), Offset(table.right - 10, y),
          Paint()..color = const Color(0xFFE0D9CD));
      for (var col = 0; col < 3; col++) {
        final barWidth = table.width * (0.14 + (((row + col) % 3) * 0.06));
        canvas.drawRect(
            Rect.fromLTWH(
                table.left + 14 + col * table.width * 0.29, y - 5, barWidth, 4),
            Paint()..color = col == 1 ? accent : const Color(0xFFB8B5A8));
      }
    }
    _text(canvas, 'COMPARE ASSUMPTIONS',
        Offset(table.left + 11, table.bottom - 11), const Color(0xFF7B756C), 7);
  }

  void _paintTechnicalResearch(
      Canvas canvas, Size size, double progress, Color accent) {
    _node(canvas, size, 0.17, 0.43, 'QUESTION', accent);
    const sources = ['DOCS', 'PAPER', 'TEST'];
    for (var i = 0; i < sources.length; i++) {
      final y = 0.27 + i * 0.16;
      _node(canvas, size, 0.42, y, sources[i], const Color(0xFF718477));
      _connector(canvas, Offset(size.width * 0.24, size.height * 0.43),
          Offset(size.width * 0.36, size.height * y), accent, progress > i / 4);
    }
    _node(canvas, size, 0.66, 0.43, 'FINDING', accent);
    _connector(canvas, Offset(size.width * 0.49, size.height * 0.27),
        Offset(size.width * 0.60, size.height * 0.43), accent, progress > 0.55);
    _connector(canvas, Offset(size.width * 0.49, size.height * 0.59),
        Offset(size.width * 0.60, size.height * 0.43), accent, progress > 0.75);
  }

  void _paintCompletion(Canvas canvas, Size size, Color accent) {
    final lineY = size.height * 0.70;
    canvas.drawLine(
      Offset(size.width * 0.12, lineY),
      Offset(size.width * 0.68, lineY),
      Paint()
        ..color = accent.withValues(alpha: 0.42)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, lineY),
      4,
      Paint()..color = accent,
    );
  }

  Rect _panel(Canvas canvas, Size size, double x, double y, double w, double h,
      Color color) {
    final rect = Rect.fromLTWH(
        size.width * x, size.height * y, size.width * w, size.height * h);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color);
    return rect;
  }

  Rect _card(Canvas canvas, Size size, double x, double y, double w, double h,
      Color color) {
    final rect = Rect.fromLTWH(
        size.width * x, size.height * y, size.width * w, size.height * h);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = const Color(0x18000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    return rect;
  }

  void _node(Canvas canvas, Size size, double x, double y, String label,
      Color accent) {
    final rect = Rect.fromCenter(
        center: Offset(size.width * x, size.height * y),
        width: size.width * 0.13,
        height: size.height * 0.09);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = const Color(0xFFF7F4EA));
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..color = accent.withValues(alpha: 0.56)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    _text(canvas, label, Offset(rect.left + 4, rect.center.dy - 4),
        const Color(0xFF5F6D63), 6.5);
  }

  void _connector(Canvas canvas, Offset a, Offset b, Color color, bool active) {
    canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color.withValues(alpha: active ? 0.7 : 0.24)
          ..strokeWidth = 1.2);
  }

  void _lines(
    Canvas canvas,
    Rect rect,
    double x,
    double y,
    double width,
    int count,
    double gap,
    Color color,
  ) {
    for (var i = 0; i < count; i++) {
      final start = Offset(
          rect.left + rect.width * x, rect.top + rect.height * y + i * gap);
      final end = Offset(
        (start.dx + rect.width * width).clamp(rect.left + 2, rect.right - 5),
        start.dy,
      );
      if (start.dy < rect.bottom - 4) {
        canvas.drawLine(
            start,
            end,
            Paint()
              ..color = color
              ..strokeWidth = 1);
      }
    }
  }

  void _text(
      Canvas canvas, String text, Offset offset, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 280);
    painter.paint(canvas, offset);
  }

  void _underline(Canvas canvas, Rect rect, double progress, Color accent) {
    canvas.drawLine(
        Offset(rect.left + 8, rect.bottom - 8),
        Offset(rect.left + 8 + (rect.width - 16) * progress, rect.bottom - 8),
        Paint()
          ..color = accent
          ..strokeWidth = 2);
  }

  void _progressCaret(Canvas canvas, Rect rect, double progress, Color accent) {
    final x = rect.left + rect.width * 0.3;
    canvas.drawRect(
        Rect.fromLTWH(x, rect.top + 30, 2, 10), Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _FocusEnvironmentPainter oldDelegate) =>
      oldDelegate.preset != preset ||
      oldDelegate.timeline.progress != timeline.progress ||
      oldDelegate.timeline.phase != timeline.phase ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.mixedEnvironment != mixedEnvironment ||
      oldDelegate.accent != accent;
}

Color _surfaceColor(FocusActivityCategory category) => switch (category) {
      FocusActivityCategory.development => const Color(0xFFE9EEF0),
      FocusActivityCategory.learning => const Color(0xFFF3EDE1),
      FocusActivityCategory.creativeWork => const Color(0xFFF2EAE4),
      FocusActivityCategory.professionalWork => const Color(0xFFECEFE8),
      FocusActivityCategory.personalGrowth => const Color(0xFFF1EEE5),
      FocusActivityCategory.analyticalWork => const Color(0xFFE8ECE8),
      FocusActivityCategory.userActivities => const Color(0xFFE9EEF0),
    };

Color _activityAccent(FocusPreset preset) => switch (preset) {
      FocusPreset.coding ||
      FocusPreset.databaseEngineering =>
        const Color(0xFF328A77),
      FocusPreset.debugging ||
      FocusPreset.problemSolving =>
        const Color(0xFFAF6758),
      FocusPreset.architecture ||
      FocusPreset.systemDesign =>
        const Color(0xFF567F9A),
      FocusPreset.aiMlResearch ||
      FocusPreset.researchPapers ||
      FocusPreset.technicalResearch =>
        const Color(0xFF667B91),
      FocusPreset.study ||
      FocusPreset.lecture ||
      FocusPreset.examPreparation ||
      FocusPreset.mathematics =>
        const Color(0xFF6C8196),
      FocusPreset.reading ||
      FocusPreset.journaling ||
      FocusPreset.writing =>
        const Color(0xFFB57556),
      FocusPreset.designing ||
      FocusPreset.drawing ||
      FocusPreset.musicComposition ||
      FocusPreset.brainstorming =>
        const Color(0xFF9A718C),
      FocusPreset.assignment ||
      FocusPreset.deepWork ||
      FocusPreset.flow ||
      FocusPreset.planning ||
      FocusPreset.documentation ||
      FocusPreset.projectManagement =>
        const Color(0xFF718574),
      FocusPreset.meeting ||
      FocusPreset.reflection ||
      FocusPreset.languageLearning =>
        const Color(0xFFB18454),
      FocusPreset.meditation => const Color(0xFF69877F),
      FocusPreset.dataAnalysis ||
      FocusPreset.financialAnalysis =>
        const Color(0xFF4D8A83),
    };

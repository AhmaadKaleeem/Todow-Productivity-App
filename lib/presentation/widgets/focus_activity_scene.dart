import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';

/// Dynamic, activity-specific animated canvas for Focus Mode.
///
/// Renders custom, non-emoji visual environments that adapt to both:
/// 1. The selected activity ([FocusPreset]: coding, assignment, reading, deepWork, study)
/// 2. The session timer progress ([progress]: starting, early, mid, near completion).
class FocusActivityScene extends StatefulWidget {
  const FocusActivityScene({
    super.key,
    required this.preset,
    required this.progress,
    required this.isRunning,
    this.compact = false,
  });

  final FocusPreset preset;
  final double progress;
  final bool isRunning;
  final bool compact;

  @override
  State<FocusActivityScene> createState() => _FocusActivitySceneState();
}

class _FocusActivitySceneState extends State<FocusActivityScene>
    with TickerProviderStateMixin {
  late final AnimationController _loopController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant FocusActivityScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning && !_loopController.isAnimating) {
      _loopController.repeat();
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRunning && _loopController.isAnimating) {
      _loopController.stop();
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _loopController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 120.0 : 154.0;

    return Container(
      width: double.infinity,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: Listenable.merge([_loopController, _pulseController]),
          builder: (context, _) {
            final t = _loopController.value;
            final p = _pulseController.value;

            return Stack(
              children: [
                // Activity-specific CustomPainter canvas
                Positioned.fill(
                  child: CustomPaint(
                    painter: _resolveActivityPainter(
                      preset: widget.preset,
                      progress: widget.progress,
                      time: t,
                      pulse: p,
                      isRunning: widget.isRunning,
                    ),
                  ),
                ),

                // Top activity & timer stage badge
                Positioned(
                  top: 10,
                  left: 14,
                  right: 14,
                  child: Row(
                    children: [
                      _buildActivityTag(widget.preset),
                      const Spacer(),
                      _buildStageBadge(widget.progress),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActivityTag(FocusPreset preset) {
    final (label, icon) = switch (preset) {
      FocusPreset.coding => ('CODING ENVIRONMENT', Icons.terminal_rounded),
      FocusPreset.assignment => ('ASSIGNMENT WORKSPACE', Icons.edit_document),
      FocusPreset.reading => ('ACTIVE READING', Icons.menu_book_rounded),
      FocusPreset.deepWork => ('DEEP WORK FLOW', Icons.grain_rounded),
      FocusPreset.study => ('STUDY SESSION', Icons.hourglass_top_rounded),
      FocusPreset.flow => ('ULTRADIAN CYCLE · 90/20', Icons.waves_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.action),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageBadge(double progress) {
    final (stageLabel, color) = progress >= 0.85
        ? ('FINAL SPRINT', AppColors.attention)
        : progress >= 0.50
            ? ('DEEP WORK', AppColors.action)
            : progress >= 0.15
                ? ('STEADY FOCUS', const Color(0xFF0D9488))
                : ('ENTERING ZONE', AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        stageLabel,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }

  CustomPainter _resolveActivityPainter({
    required FocusPreset preset,
    required double progress,
    required double time,
    required double pulse,
    required bool isRunning,
  }) {
    return switch (preset) {
      FocusPreset.coding => _CodingScenePainter(
          progress: progress,
          time: time,
          pulse: pulse,
          isRunning: isRunning,
        ),
      FocusPreset.assignment => _AssignmentScenePainter(
          progress: progress,
          time: time,
          pulse: pulse,
          isRunning: isRunning,
        ),
      FocusPreset.reading => _ReadingScenePainter(
          progress: progress,
          time: time,
          pulse: pulse,
          isRunning: isRunning,
        ),
      FocusPreset.deepWork => _DeepWorkScenePainter(
          progress: progress,
          time: time,
          pulse: pulse,
          isRunning: isRunning,
        ),
      FocusPreset.study => _StudyScenePainter(
          progress: progress,
          time: time,
          pulse: pulse,
          isRunning: isRunning,
        ),
      FocusPreset.flow => _DeepWorkScenePainter(
          progress: progress,
          time: time,
          pulse: pulse,
          isRunning: isRunning,
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. CODING SCENE PAINTER: Terminal IDE, typing code blocks, cursor blink,
// and progress-responsive build status.
// ─────────────────────────────────────────────────────────────────────────────

class _CodingScenePainter extends CustomPainter {
  _CodingScenePainter({
    required this.progress,
    required this.time,
    required this.pulse,
    required this.isRunning,
  });

  final double progress;
  final double time;
  final double pulse;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final termRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(14, 38, size.width - 28, size.height - 48),
      const Radius.circular(12),
    );

    // Terminal dark card
    final termBg = Paint()..color = const Color(0xFF1E2430);
    canvas.drawRRect(termRect, termBg);

    // Terminal header dots
    final dotPaintRed = Paint()..color = const Color(0xFFEF4444);
    final dotPaintAmber = Paint()..color = const Color(0xFFF59E0B);
    final dotPaintGreen = Paint()..color = const Color(0xFF22C55E);

    canvas.drawCircle(const Offset(26, 50), 3.5, dotPaintRed);
    canvas.drawCircle(const Offset(36, 50), 3.5, dotPaintAmber);
    canvas.drawCircle(const Offset(46, 50), 3.5, dotPaintGreen);

    // Code lines configuration based on progress
    final codeLines = progress < 0.15
        ? const [
            ('// Booting focus environment...', Color(0xFF64748B)),
            ('fn init_flow() -> Ready {', Color(0xFF38BDF8)),
            ('    setup_workspace();', Color(0xFFE2E8F0)),
            ('}', Color(0xFF38BDF8)),
          ]
        : progress < 0.50
            ? const [
                ('class ActiveSprint {', Color(0xFF38BDF8)),
                ('    val focus = uninterrupted();', Color(0xFFFCD34D)),
                ('    fun build() = focus.execute()', Color(0xFF86EFAC)),
                ('}', Color(0xFF38BDF8)),
              ]
            : progress < 0.85
                ? const [
                    ('while (in_zone) {', Color(0xFF38BDF8)),
                    ('    solve_algorithm();', Color(0xFFFCD34D)),
                    ('    refactor_clean_code();', Color(0xFF86EFAC)),
                    ('}', Color(0xFF38BDF8)),
                  ]
                : const [
                    ('// Build Successful: 100% Tests Pass', Color(0xFF4ADE80)),
                    ('fun finish() {', Color(0xFF38BDF8)),
                    ('    commit(status: COMPLETED);', Color(0xFF86EFAC)),
                    ('}', Color(0xFF38BDF8)),
                  ];

    double y = 64;
    for (int i = 0; i < codeLines.length; i++) {
      final (text, color) = codeLines[i];
      // Simulated typing width based on loop time
      final typingProgress = isRunning
          ? ((time * 2.5) - (i * 0.4)).clamp(0.0, 1.0)
          : 1.0;

      final length = (text.length * typingProgress).toInt().clamp(0, text.length);
      final displayText = text.substring(0, length);

      final textSpan = TextSpan(
        text: displayText,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(26, y));

      // Animated blinking cursor on the active line
      if (i == (time * codeLines.length).toInt().clamp(0, codeLines.length - 1) &&
          pulse > 0.4 &&
          isRunning) {
        final cursorPaint = Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 2;
        final cursorX = 26 + textPainter.width + 2;
        canvas.drawLine(Offset(cursorX, y + 2), Offset(cursorX, y + 12), cursorPaint);
      }

      y += 16;
    }
  }

  @override
  bool shouldRepaint(covariant _CodingScenePainter old) =>
      old.time != time || old.progress != progress || old.pulse != pulse;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. ASSIGNMENT SCENE PAINTER: Ruled notebook paper, animated writing strokes,
// margin rule, and dynamic task completion checkmarks.
// ─────────────────────────────────────────────────────────────────────────────

class _AssignmentScenePainter extends CustomPainter {
  _AssignmentScenePainter({
    required this.progress,
    required this.time,
    required this.pulse,
    required this.isRunning,
  });

  final double progress;
  final double time;
  final double pulse;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final sheetRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(14, 38, size.width - 28, size.height - 48),
      const Radius.circular(12),
    );

    // Warm notebook paper sheet
    final paperPaint = Paint()..color = const Color(0xFFFAF7F2);
    canvas.drawRRect(sheetRect, paperPaint);

    final borderPaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(sheetRect, borderPaint);

    // Left red margin line
    final marginPaint = Paint()
      ..color = const Color(0xFFFCA5A5)
      ..strokeWidth = 1.2;
    canvas.drawLine(
      const Offset(50, 38),
      Offset(50, size.height - 10),
      marginPaint,
    );

    // Ruled horizontal lines
    final linePaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.6)
      ..strokeWidth = 0.9;

    final startY = 56.0;
    final lineSpacing = 16.0;
    final lineCount = 5;

    for (int i = 0; i < lineCount; i++) {
      final y = startY + (i * lineSpacing);
      canvas.drawLine(Offset(22, y), Offset(size.width - 22, y), linePaint);

      // Checkbox on margin
      final isCompletedStep = progress >= ((i + 1) / lineCount);
      final checkRect = Rect.fromLTWH(32, y - 9, 8, 8);
      final checkBorder = Paint()
        ..color = isCompletedStep ? AppColors.action : AppColors.textSecondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(checkRect, const Radius.circular(2)),
        checkBorder,
      );

      if (isCompletedStep) {
        final fillPaint = Paint()..color = AppColors.action;
        canvas.drawRRect(
          RRect.fromRectAndRadius(checkRect.deflate(1.5), const Radius.circular(1.5)),
          fillPaint,
        );
      }

      // Animated ink stroke simulation across lines
      final activeLine = isRunning ? ((time * lineCount).floor() % lineCount) : -1;
      final strokeLength = isCompletedStep
          ? (size.width - 90)
          : (i == activeLine ? (time * (size.width - 90)) : 0.0);

      if (strokeLength > 0) {
        final inkPaint = Paint()
          ..color = const Color(0xFF1E3A8A).withValues(alpha: 0.75)
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;

        final path = Path();
        path.moveTo(60, y - 4);
        // Subtle wavy handwriting line
        for (double x = 60; x < 60 + strokeLength; x += 12) {
          final waveY = (y - 4) + math.sin((x / 10) + (time * 5)) * 1.5;
          path.lineTo(x, waveY);
        }
        canvas.drawPath(path, inkPaint);
      }
    }

    // Stylus / Pen Tip indicator on current line
    if (isRunning) {
      final penLine = (time * lineCount).floor() % lineCount;
      final penY = startY + (penLine * lineSpacing) - 5;
      final penX = 60 + (time * (size.width - 100));

      final penPaint = Paint()..color = AppColors.action;
      canvas.drawCircle(Offset(penX, penY), 3, penPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AssignmentScenePainter old) =>
      old.time != time || old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. READING SCENE PAINTER: Open book with curved 3D pages, flowing bookmark,
// and chapter progress beam.
// ─────────────────────────────────────────────────────────────────────────────

class _ReadingScenePainter extends CustomPainter {
  _ReadingScenePainter({
    required this.progress,
    required this.time,
    required this.pulse,
    required this.isRunning,
  });

  final double progress;
  final double time;
  final double pulse;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final topY = 46.0;
    final bottomY = size.height - 18;
    final bookWidth = (size.width - 60) / 2;

    // Gentle page breathing flutter curve
    final flutter = isRunning ? math.sin(time * 2 * math.pi) * 3 : 0.0;

    // Left Page (Curved open book)
    final leftPath = Path()
      ..moveTo(centerX, topY + 4)
      ..quadraticBezierTo(centerX - (bookWidth / 2), topY - 2 + flutter, centerX - bookWidth, topY)
      ..lineTo(centerX - bookWidth, bottomY)
      ..quadraticBezierTo(centerX - (bookWidth / 2), bottomY - 3 + flutter, centerX, bottomY + 4)
      ..close();

    // Right Page
    final rightPath = Path()
      ..moveTo(centerX, topY + 4)
      ..quadraticBezierTo(centerX + (bookWidth / 2), topY - 2 - flutter, centerX + bookWidth, topY)
      ..lineTo(centerX + bookWidth, bottomY)
      ..quadraticBezierTo(centerX + (bookWidth / 2), bottomY - 3 - flutter, centerX, bottomY + 4)
      ..close();

    final pagePaint = Paint()..color = const Color(0xFFFFFFFF);
    final pageShadow = Paint()
      ..color = const Color(0x12000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawPath(leftPath, pageShadow);
    canvas.drawPath(rightPath, pageShadow);
    canvas.drawPath(leftPath, pagePaint);
    canvas.drawPath(rightPath, pagePaint);

    // Spine shading
    final spinePaint = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 2;
    canvas.drawLine(Offset(centerX, topY + 2), Offset(centerX, bottomY + 4), spinePaint);

    // Simulated book text lines on left & right pages
    final textLinePaint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.3)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final y = topY + 16 + (i * 14);
      // Left lines
      canvas.drawLine(
        Offset(centerX - bookWidth + 12, y),
        Offset(centerX - 12, y),
        textLinePaint,
      );
      // Right lines
      canvas.drawLine(
        Offset(centerX + 12, y),
        Offset(centerX + bookWidth - 12, y),
        textLinePaint,
      );
    }

    // Active reading eye guide bar on right page
    final readingY = topY + 16 + (((time * 4) % 4) * 14);
    final guidePaint = Paint()
      ..color = AppColors.action.withValues(alpha: 0.18)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX + 14, readingY),
      Offset(centerX + bookWidth - 14, readingY),
      guidePaint,
    );

    // Floating Ribbon Bookmark (Azure)
    final bookmarkX = centerX + 18 + (progress * 20);
    final ribbonPaint = Paint()
      ..color = AppColors.action
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(bookmarkX, topY - 6),
      Offset(bookmarkX, topY + 36 + (pulse * 4)),
      ribbonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadingScenePainter old) =>
      old.time != time || old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. DEEP WORK SCENE PAINTER: Atomic focus lattice, orbital nodes,
// and harmonic resonance flow.
// ─────────────────────────────────────────────────────────────────────────────

class _DeepWorkScenePainter extends CustomPainter {
  _DeepWorkScenePainter({
    required this.progress,
    required this.time,
    required this.pulse,
    required this.isRunning,
  });

  final double progress;
  final double time;
  final double pulse;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final baseRadius = 38.0;

    // Glowing core nucleus
    final nucleusGlow = Paint()
      ..color = AppColors.action.withValues(alpha: 0.18 + (pulse * 0.12))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 18 + (pulse * 4), nucleusGlow);

    final nucleusSolid = Paint()..color = AppColors.action;
    canvas.drawCircle(center, 8, nucleusSolid);

    // Orbit 1: Elliptical horizontal
    final orbitPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(time * math.pi);

    final rect1 = Rect.fromCenter(center: Offset.zero, width: baseRadius * 2.8, height: baseRadius * 1.4);
    canvas.drawOval(rect1, orbitPaint);

    // Orbit 2: Angled ellipse
    canvas.rotate(math.pi / 3);
    final rect2 = Rect.fromCenter(center: Offset.zero, width: baseRadius * 2.8, height: baseRadius * 1.4);
    canvas.drawOval(rect2, orbitPaint);

    // Orbiting focus nodes
    final nodePaint = Paint()..color = AppColors.attention;
    final nodeAngle = time * 2 * math.pi;
    final node1X = (baseRadius * 1.4) * math.cos(nodeAngle);
    final node1Y = (baseRadius * 0.7) * math.sin(nodeAngle);
    canvas.drawCircle(Offset(node1X, node11Y(node1Y)), 4.5, nodePaint);

    canvas.restore();

    // Progress resonance rings expanding outward
    if (progress > 0.2) {
      final waveRadius = baseRadius + (progress * 28);
      final wavePaint = Paint()
        ..color = AppColors.attention.withValues(alpha: (1.0 - progress).clamp(0.1, 0.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, waveRadius, wavePaint);
    }
  }

  double node11Y(double y) => y;

  @override
  bool shouldRepaint(covariant _DeepWorkScenePainter old) =>
      old.time != time || old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. STUDY SCENE PAINTER: Geometric hourglass, cascading sand micro-particles,
// and accumulated knowledge mound at the base.
// ─────────────────────────────────────────────────────────────────────────────

class _StudyScenePainter extends CustomPainter {
  _StudyScenePainter({
    required this.progress,
    required this.time,
    required this.pulse,
    required this.isRunning,
  });

  final double progress;
  final double time;
  final double pulse;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final topY = 44.0;
    final bottomY = size.height - 18;
    final height = bottomY - topY;
    final midY = topY + (height / 2);
    final bulbWidth = 32.0;

    // Geometric hourglass glass frame
    final glassPath = Path()
      ..moveTo(centerX - bulbWidth, topY)
      ..lineTo(centerX + bulbWidth, topY)
      ..lineTo(centerX + 4, midY)
      ..lineTo(centerX + bulbWidth, bottomY)
      ..lineTo(centerX - bulbWidth, bottomY)
      ..lineTo(centerX - 4, midY)
      ..close();

    final glassPaint = Paint()
      ..color = AppColors.surfaceElevated
      ..style = PaintingStyle.fill;
    canvas.drawPath(glassPath, glassPaint);

    final framePaint = Paint()
      ..color = AppColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawPath(glassPath, framePaint);

    // Sand remaining in top bulb (decreases as progress increases)
    final topSandFraction = (1.0 - progress).clamp(0.05, 1.0);
    final topSandY = topY + ((1.0 - topSandFraction) * (midY - topY - 4));
    final topSandPath = Path()
      ..moveTo(centerX - (bulbWidth * topSandFraction), topSandY)
      ..lineTo(centerX + (bulbWidth * topSandFraction), topSandY)
      ..lineTo(centerX + 3, midY)
      ..lineTo(centerX - 3, midY)
      ..close();

    final sandPaint = Paint()..color = AppColors.attention;
    canvas.drawPath(topSandPath, sandPaint);

    // Falling sand stream through the neck
    if (isRunning && progress < 1.0) {
      final streamPaint = Paint()
        ..color = AppColors.attention.withValues(alpha: 0.8)
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(centerX, midY), Offset(centerX, bottomY - 6), streamPaint);

      // Micro particles in stream
      final particlePaint = Paint()..color = Colors.white;
      final particleY = midY + ((time * (bottomY - midY - 6)));
      canvas.drawCircle(Offset(centerX, particleY), 1.2, particlePaint);
    }

    // Sand accumulated in bottom bulb (increases with progress)
    final bottomSandHeight = (bottomY - midY - 6) * progress;
    final bottomMoundY = bottomY - bottomSandHeight;
    final bottomMoundWidth = (bulbWidth * (progress.clamp(0.15, 1.0)));

    final bottomSandPath = Path()
      ..moveTo(centerX - bottomMoundWidth, bottomY)
      ..quadraticBezierTo(centerX, bottomMoundY, centerX + bottomMoundWidth, bottomY)
      ..close();

    final accumPaint = Paint()..color = AppColors.attention.withValues(alpha: 0.9);
    canvas.drawPath(bottomSandPath, accumPaint);

    // Caps top and bottom
    final capPaint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX - bulbWidth - 4, topY), Offset(centerX + bulbWidth + 4, topY), capPaint);
    canvas.drawLine(Offset(centerX - bulbWidth - 4, bottomY), Offset(centerX + bulbWidth + 4, bottomY), capPaint);
  }

  @override
  bool shouldRepaint(covariant _StudyScenePainter old) =>
      old.time != time || old.progress != progress;
}

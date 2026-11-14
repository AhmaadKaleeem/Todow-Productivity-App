import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/enums.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant FocusActivityScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final shouldAnimate =
        widget.isRunning && !MediaQuery.disableAnimationsOf(context);
    if (shouldAnimate && !_ambientController.isAnimating) {
      _ambientController.repeat();
    } else if (!shouldAnimate && _ambientController.isAnimating) {
      _ambientController.stop();
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.compact ? 132.0 : 168.0;
    return Semantics(
      label: '${widget.preset.label} focus environment',
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: _surfaceColor(widget.preset),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: _ambientController,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FieldDeskPainter(
                    preset: widget.preset,
                    progress: widget.progress.clamp(0, 1),
                    time: _ambientController.value,
                    isRunning: widget.isRunning,
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 12,
                child: _SceneLabel(text: _activityLabel(widget.preset)),
              ),
              Positioned(
                right: 14,
                top: 12,
                child: _SceneLabel(
                  text: _stageLabel(widget.progress),
                  accent: _stageColor(widget.progress),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _activityLabel(FocusPreset preset) => switch (preset) {
        FocusPreset.coding => 'CODING ENVIRONMENT',
        FocusPreset.assignment => 'ASSIGNMENT WORKSPACE',
        FocusPreset.reading => 'ACTIVE READING',
        FocusPreset.deepWork => 'DEEP WORK FLOW',
        FocusPreset.study => 'STUDY SESSION',
        FocusPreset.flow => 'ULTRADIAN CYCLE · 90/20',
      };

  String _stageLabel(double progress) => progress >= 0.85
      ? 'FINAL SPRINT'
      : progress >= 0.50
          ? 'DEEP WORK'
          : progress >= 0.15
              ? 'STEADY FOCUS'
              : 'ENTERING ZONE';

  Color _stageColor(double progress) => progress >= 0.85
      ? AppColors.attention
      : progress >= 0.50
          ? AppColors.action
          : progress >= 0.15
              ? const Color(0xFF0D9488)
              : AppColors.textSecondary;
}

class _SceneLabel extends StatelessWidget {
  const _SceneLabel({required this.text, this.accent = AppColors.textPrimary});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF6),
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
}

Color _surfaceColor(FocusPreset preset) => switch (preset) {
      FocusPreset.coding => const Color(0xFFE9EEF0),
      FocusPreset.reading => const Color(0xFFF3EDE1),
      FocusPreset.assignment => const Color(0xFFF5EFE6),
      FocusPreset.study => const Color(0xFFECEFE8),
      FocusPreset.deepWork || FocusPreset.flow => const Color(0xFFE9ECE8),
    };

class _FieldDeskPainter extends CustomPainter {
  const _FieldDeskPainter({
    required this.preset,
    required this.progress,
    required this.time,
    required this.isRunning,
  });

  final FocusPreset preset;
  final double progress;
  final double time;
  final bool isRunning;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = _surfaceColor(preset);
    canvas.drawRect(Offset.zero & size, background);

    final deskPaint = Paint()..color = const Color(0xFFE1D8C9);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.74, size.width, size.height * 0.26),
      deskPaint,
    );

    final windowPaint = Paint()..color = const Color(0xFFD8E5E8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            size.width * 0.68, 28, size.width * 0.22, size.height * 0.44),
        const Radius.circular(4),
      ),
      windowPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.79, 28),
      Offset(size.width * 0.79, size.height * 0.72),
      Paint()..color = const Color(0xFFB7C7C9),
    );

    switch (preset) {
      case FocusPreset.coding:
        _paintCodingDesk(canvas, size);
      case FocusPreset.reading:
        _paintReadingDesk(canvas, size);
      case FocusPreset.assignment:
        _paintAssignmentDesk(canvas, size);
      case FocusPreset.study:
        _paintStudyDesk(canvas, size);
      case FocusPreset.deepWork || FocusPreset.flow:
        _paintDeepWorkDesk(canvas, size);
    }

    _paintProgressMarker(canvas, size);
  }

  void _paintCodingDesk(Canvas canvas, Size size) {
    final monitor = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          size.width * 0.10, 36, size.width * 0.50, size.height * 0.46),
      const Radius.circular(5),
    );
    canvas.drawRRect(monitor, Paint()..color = const Color(0xFF26323A));
    canvas.drawRRect(
      monitor.deflate(7),
      Paint()..color = const Color(0xFF35464E),
    );
    _paintLines(
      canvas,
      Offset(size.width * 0.15, 58),
      size.width * 0.39,
      const Color(0xFFB8D5D5),
      7,
      12,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.31, size.height * 0.60, 12, 12),
      Paint()..color = const Color(0xFF66757A),
    );
    canvas.drawRect(
      Rect.fromLTWH(
          size.width * 0.22, size.height * 0.71, size.width * 0.28, 4),
      Paint()..color = const Color(0xFF9AA7A8),
    );
    if (isRunning) {
      final cursorX = size.width * 0.15 + (size.width * 0.32 * _phase());
      canvas.drawRect(
        Rect.fromLTWH(cursorX, 58 + ((progress * 6).floor() % 7) * 12, 2, 8),
        Paint()..color = AppColors.action,
      );
    }
  }

  void _paintReadingDesk(Canvas canvas, Size size) {
    final book = Path()
      ..moveTo(size.width * 0.12, size.height * 0.68)
      ..lineTo(size.width * 0.48, size.height * 0.58)
      ..lineTo(size.width * 0.84, size.height * 0.68)
      ..lineTo(size.width * 0.48, size.height * 0.79)
      ..close();
    canvas.drawPath(book, Paint()..color = const Color(0xFFFFFCF2));
    final rule = Paint()
      ..color = const Color(0xFFD9D0C0)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * 0.64 + i * 8;
      canvas.drawLine(
          Offset(size.width * 0.19, y), Offset(size.width * 0.45, y - 5), rule);
      canvas.drawLine(
          Offset(size.width * 0.52, y - 5), Offset(size.width * 0.77, y), rule);
    }
    final bookmarkX = size.width * (0.50 + progress * 0.25);
    canvas.drawLine(
      Offset(bookmarkX, size.height * 0.60),
      Offset(bookmarkX, size.height * 0.75),
      Paint()
        ..color = const Color(0xFFB86B4B)
        ..strokeWidth = 3,
    );
  }

  void _paintAssignmentDesk(Canvas canvas, Size size) {
    final sheet = Rect.fromLTWH(
      size.width * 0.12,
      34,
      size.width * 0.54,
      size.height * 0.52,
    );
    canvas.drawRect(sheet, Paint()..color = const Color(0xFFFFFCF6));
    canvas.drawLine(
      Offset(size.width * 0.22, sheet.top),
      Offset(size.width * 0.22, sheet.bottom),
      Paint()
        ..color = const Color(0xFFE8B1A5)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 5; i++) {
      final y = sheet.top + 28 + i * 20;
      canvas.drawLine(
        Offset(size.width * 0.28, y),
        Offset(size.width * 0.59, y),
        Paint()..color = const Color(0xFFD7DED9),
      );
      final checked = progress >= (i + 1) / 5;
      canvas.drawRect(
        Rect.fromLTWH(size.width * 0.15, y - 6, 9, 9),
        Paint()
          ..color = checked ? AppColors.action : const Color(0xFFB9C1BA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (checked) {
        canvas.drawLine(
          Offset(size.width * 0.15, y - 1),
          Offset(size.width * 0.154, y + 3),
          Paint()
            ..color = AppColors.action
            ..strokeWidth = 2,
        );
        canvas.drawLine(
          Offset(size.width * 0.154, y + 3),
          Offset(size.width * 0.162, y - 4),
          Paint()
            ..color = AppColors.action
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _paintStudyDesk(Canvas canvas, Size size) {
    final cardPaint = Paint()..color = const Color(0xFFFFFCF5);
    for (var i = 0; i < 3; i++) {
      final x = size.width * 0.14 + i * 42;
      final y = 44.0 + (i.isEven ? 4 : 0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 34, 54), const Radius.circular(3)),
        cardPaint,
      );
      _paintLines(
          canvas, Offset(x + 7, y + 13), 20, const Color(0xFFC9D2C7), 3, 10);
    }
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.69),
      Offset(size.width * 0.60, size.height * 0.69),
      Paint()
        ..color = const Color(0xFF7C8A7B)
        ..strokeWidth = 2,
    );
  }

  void _paintDeepWorkDesk(Canvas canvas, Size size) {
    final notebook = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          size.width * 0.14, 42, size.width * 0.48, size.height * 0.47),
      const Radius.circular(3),
    );
    canvas.drawRRect(notebook, Paint()..color = const Color(0xFFFAF8EF));
    canvas.drawLine(
      Offset(size.width * 0.22, 42),
      Offset(size.width * 0.22, size.height * 0.49),
      Paint()
        ..color = const Color(0xFFB9A88D)
        ..strokeWidth = 2,
    );
    _paintLines(
      canvas,
      Offset(size.width * 0.28, 68),
      size.width * 0.25,
      const Color(0xFFB8B8A7),
      5,
      18,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.60),
      13,
      Paint()..color = const Color(0xFFD2B48C),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.70, size.height * 0.62, 4, 25),
      Paint()..color = const Color(0xFF9C7E5D),
    );
  }

  void _paintProgressMarker(Canvas canvas, Size size) {
    final markerX = size.width * (0.12 + progress * 0.48);
    canvas.drawLine(
      Offset(markerX, size.height * 0.84),
      Offset(markerX, size.height * 0.91),
      Paint()
        ..color = AppColors.attention
        ..strokeWidth = 2,
    );
  }

  void _paintLines(
    Canvas canvas,
    Offset start,
    double width,
    Color color,
    int count,
    double gap,
  ) {
    for (var i = 0; i < count; i++) {
      final length = width * (0.62 + ((i * 13) % 31) / 100);
      canvas.drawLine(
        Offset(start.dx, start.dy + i * gap),
        Offset(start.dx + length, start.dy + i * gap),
        Paint()
          ..color = color
          ..strokeWidth = 1.2,
      );
    }
  }

  double _phase() =>
      isRunning ? (0.5 + 0.5 * math.sin(time * math.pi * 2)) : 0.5;

  @override
  bool shouldRepaint(covariant _FieldDeskPainter oldDelegate) =>
      oldDelegate.preset != preset ||
      oldDelegate.progress != progress ||
      oldDelegate.time != time ||
      oldDelegate.isRunning != isRunning;
}

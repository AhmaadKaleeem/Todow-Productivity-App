import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';

class CornerArcDecor extends StatelessWidget {
  final Alignment corner;
  final double scale;

  const CornerArcDecor({
    super.key,
    this.corner = Alignment.topLeft,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _ArcPainter(corner: corner, scale: scale)),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Alignment corner;
  final double scale;
  const _ArcPainter({required this.corner, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final origin = _origin(size);
    final (start, sweep) = _angles();
    
    final double outerRadius = corner == Alignment.topLeft ? 120.0 : 140.0;
    final double middleRadius = corner == Alignment.topLeft ? 80.0 : 90.0;
    final double innerRadius = corner == Alignment.topLeft ? 48.0 : 56.0;

    for (final (radius, color) in [
      (outerRadius * scale, AppColors.surfaceElevated),
      (middleRadius * scale, const Color(0xFFF5BED5)), // decorPink at 40% over background
      (innerRadius * scale, AppColors.decorCoral),
    ]) {
      canvas.drawArc(
        Rect.fromCircle(center: origin, radius: radius),
        start, sweep, true,
        Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true,
      );
    }
  }

  Offset _origin(Size s) => switch (corner) {
    Alignment.topRight    => Offset(s.width, 0),
    Alignment.bottomLeft  => Offset(0, s.height),
    Alignment.bottomRight => Offset(s.width, s.height),
    _                     => Offset.zero,
  };

  (double, double) _angles() => switch (corner) {
    Alignment.topRight    => (math.pi / 2,  math.pi / 2),
    Alignment.bottomLeft  => (-math.pi / 2, math.pi / 2),
    Alignment.bottomRight => (math.pi,      math.pi / 2),
    _                     => (0,            math.pi / 2),
  };

  @override
  bool shouldRepaint(_ArcPainter old) => old.corner != corner || old.scale != scale;
}

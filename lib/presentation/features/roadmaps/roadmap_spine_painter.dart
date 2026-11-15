import 'package:flutter/material.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/roadmap.dart';

enum _Side { left, right }

_Side _sideFor(int index) => index.isEven ? _Side.left : _Side.right;

class RoadmapSpinePainter extends CustomPainter {
  RoadmapSpinePainter({
    required this.cardBounds,
    required this.topics,
    required this.accentColor,
    required this.progress,
  });

  final List<Rect> cardBounds;
  final List<Topic> topics;
  final Color accentColor;
  final double progress; // 0..1 draw-on progress

  @override
  void paint(Canvas canvas, Size size) {
    if (cardBounds.length < 2) return;

    for (int i = 0; i < cardBounds.length - 1; i++) {
      final segProgress =
          ((progress * (cardBounds.length - 1)) - i).clamp(0.0, 1.0);
      if (segProgress <= 0) continue;

      final from = cardBounds[i];
      final to = cardBounds[i + 1];
      final fromSide = _sideFor(i);
      final toSide = _sideFor(i + 1);
      final status = topics[i].status;

      final paint = _paintFor(status)
        ..strokeWidth = status == TopicStatus.active ? 5 : 4;

      // Exit point: bottom-center of current card.
      final exit = from.bottomCenter;
      // Entry point: top-center of next card.
      final entry = to.topCenter;

      final path = _buildPath(exit, entry, fromSide, toSide, from, to);
      _drawSegment(
        canvas,
        path,
        Paint()
          ..color = AppColors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
        segProgress,
      );
      _drawSegment(canvas, path, paint, segProgress);

      if (segProgress >= 1.0) {
        // Midpoint node dot
        final midT = 0.5;
        final metric = path.computeMetrics().first;
        final midPt =
            metric.getTangentForOffset(metric.length * midT)?.position;
        if (midPt != null) {
          canvas.drawCircle(midPt, 8, Paint()..color = AppColors.surface);
          canvas.drawCircle(midPt, 5, Paint()..color = paint.color);
          canvas.drawCircle(midPt, 2, Paint()..color = AppColors.surface);
        }
        // Arrowhead near entry
        _drawArrow(canvas, entry, paint.color);
      }
    }
  }

  // Build the connector path between two cards with a zigzag S-curve.
  Path _buildPath(
    Offset exit,
    Offset entry,
    _Side fromSide,
    _Side toSide,
    Rect fromRect,
    Rect toRect,
  ) {
    final path = Path();
    path.moveTo(exit.dx, exit.dy);

    final vGap = entry.dy - exit.dy;

    if (fromSide == toSide) {
      // Same side: simple S-curve with cubic bezier
      final cp1 = Offset(exit.dx, exit.dy + vGap * 0.45);
      final cp2 = Offset(entry.dx, entry.dy - vGap * 0.45);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, entry.dx, entry.dy);
    } else {
      // Opposite sides: right-angle path with rounded corners
      // Go straight down a bit, then cross horizontally, then down into next card.
      const cornerR = 18.0;
      final dropDown = vGap * 0.35;
      final crossY = exit.dy + dropDown;

      // Determine cross direction
      final goRight = toSide == _Side.right;
      final crossX = entry.dx;

      // Segment 1: straight down from exit
      path.lineTo(exit.dx, crossY - cornerR);

      // Corner 1: curve from vertical to horizontal
      if (goRight) {
        path.arcToPoint(
          Offset(exit.dx + cornerR, crossY),
          radius: const Radius.circular(cornerR),
          clockwise: true,
        );
        // Horizontal cross
        path.lineTo(crossX - cornerR, crossY);
        // Corner 2: curve from horizontal to vertical
        path.arcToPoint(
          Offset(crossX, crossY + cornerR),
          radius: const Radius.circular(cornerR),
          clockwise: false,
        );
      } else {
        path.arcToPoint(
          Offset(exit.dx - cornerR, crossY),
          radius: const Radius.circular(cornerR),
          clockwise: false,
        );
        // Horizontal cross
        path.lineTo(crossX + cornerR, crossY);
        // Corner 2: curve from horizontal to vertical
        path.arcToPoint(
          Offset(crossX, crossY + cornerR),
          radius: const Radius.circular(cornerR),
          clockwise: true,
        );
      }

      // Straight down into the next card
      path.lineTo(entry.dx, entry.dy);
    }

    return path;
  }

  void _drawSegment(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    if (t >= 1.0) {
      canvas.drawPath(path, paint);
      return;
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
  }

  void _drawArrow(Canvas canvas, Offset tip, Color color) {
    // Small filled triangle pointing down
    const size = 7.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size, tip.dy - size * 1.4)
      ..lineTo(tip.dx + size, tip.dy - size * 1.4)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Paint _paintFor(TopicStatus status) {
    return switch (status) {
      TopicStatus.active => Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      TopicStatus.completed => Paint()
        ..color = AppColors.attention.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
      TopicStatus.pending => Paint()
        ..color = accentColor.withValues(alpha: 0.48)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    };
  }

  @override
  bool shouldRepaint(covariant RoadmapSpinePainter oldDelegate) =>
      oldDelegate.cardBounds != cardBounds ||
      oldDelegate.topics != topics ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.progress != progress;
}

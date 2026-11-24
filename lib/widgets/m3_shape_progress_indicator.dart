import 'dart:math' as math;
import 'package:flutter/material.dart';

/// M3ShapeChangingProgressIndicator renders a Google Material 3 Expressive
/// shape-morphing rotating indicator. It continuously cycles through an
/// 8-lobed flower/squircle, rounded square, diamond, and soft circle while
/// smoothly spinning and pulsing colors.
class M3ShapeChangingProgressIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const M3ShapeChangingProgressIndicator({
    super.key,
    this.size = 36.0,
    this.color,
    this.strokeWidth = 3.5,
  });

  @override
  State<M3ShapeChangingProgressIndicator> createState() =>
      _M3ShapeChangingProgressIndicatorState();
}

class _M3ShapeChangingProgressIndicatorState
    extends State<M3ShapeChangingProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.color ?? Theme.of(context).colorScheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _M3MorphingPainter(
            progress: _controller.value,
            color: effectiveColor,
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}

class _M3MorphingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;
  final double strokeWidth;

  _M3MorphingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Rotation angle: 2 full rotations per animation cycle with ease-in-out steps
    final rotationAngle = progress * 2 * math.pi * 1.5;

    // Morph cycle: 0 -> 1 -> 2 -> 3 -> 0
    final morphPhase = (progress * 4) % 4;
    final stage = morphPhase.floor();
    final t = morphPhase - stage;
    // Smooth cosine interpolation
    final smoothT = 0.5 - 0.5 * math.cos(t * math.pi);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    final path = Path();
    const int points = 120;

    for (int i = 0; i <= points; i++) {
      final theta = (i / points) * 2 * math.pi;

      // Shape definitions via polar radius r(theta)
      // Shape 0: 4-leaf clover / rounded flower
      final r0 = radius * (0.82 + 0.18 * math.cos(4 * theta));

      // Shape 1: Rounded squircle / square
      final cos4 = math.cos(4 * theta);
      final r1 = radius * (0.85 + 0.15 * cos4);

      // Shape 2: Diamond / rotated pill
      final cos2 = math.cos(2 * theta);
      final r2 = radius * (0.80 + 0.20 * cos2);

      // Shape 3: Soft circle with gentle pulsation
      final r3 = radius * 0.94;

      double currentR;
      switch (stage) {
        case 0:
          currentR = _lerp(r0, r1, smoothT);
          break;
        case 1:
          currentR = _lerp(r1, r2, smoothT);
          break;
        case 2:
          currentR = _lerp(r2, r3, smoothT);
          break;
        default:
          currentR = _lerp(r3, r0, smoothT);
          break;
      }

      final x = currentR * math.cos(theta);
      final y = currentR * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Subtle breathing scale
    final scale = 0.92 + 0.08 * math.sin(progress * 2 * math.pi);
    canvas.scale(scale, scale);

    // Glow / background soft fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Main stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
    canvas.restore();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _M3MorphingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}


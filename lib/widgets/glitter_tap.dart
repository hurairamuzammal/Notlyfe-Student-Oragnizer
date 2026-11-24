import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interactive wrapper that provides a sparkling Material 3 glitter ripple,
/// a subtle bouncy scale micro-interaction, and optional sparkle particle burst on tap.
class GlitterTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final bool enableScaleBounce;
  final bool enableGlitterBurst;

  const GlitterTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.splashColor,
    this.enableScaleBounce = true,
    this.enableGlitterBurst = false,
  });

  @override
  State<GlitterTap> createState() => _GlitterTapState();
}

class _GlitterTapState extends State<GlitterTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  final List<_GlitterParticle> _particles = [];
  Offset _tapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spawnParticles(Offset position) {
    if (!widget.enableGlitterBurst) return;
    _tapPosition = position;
    _particles.clear();
    final random = math.Random();
    for (int i = 0; i < 8; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final speed = 15.0 + random.nextDouble() * 25.0;
      _particles.add(
        _GlitterParticle(
          dx: math.cos(angle) * speed,
          dy: math.sin(angle) * speed,
          size: 2.0 + random.nextDouble() * 3.5,
          color: Colors.amberAccent.withValues(alpha: 0.8),
        ),
      );
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enableScaleBounce) {
      _controller.forward();
    }
    _spawnParticles(details.localPosition);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enableScaleBounce) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enableScaleBounce) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        splashFactory: InkSparkle.splashFactory, // Android 12+ glitter noise ripple
        splashColor: widget.splashColor ??
            theme.colorScheme.primary.withValues(alpha: 0.18),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap != null
            ? () {
                HapticFeedback.lightImpact();
                widget.onTap!();
              }
            : null,
        onLongPress: widget.onLongPress,
        child: widget.child,
      ),
    );

    if (widget.enableScaleBounce) {
      content = ScaleTransition(
        scale: _scaleAnimation,
        child: content,
      );
    }

    if (widget.enableGlitterBurst && _particles.isNotEmpty) {
      content = CustomPaint(
        foregroundPainter: _GlitterPainter(_particles, _tapPosition, _controller.value),
        child: content,
      );
    }

    return content;
  }
}

class _GlitterParticle {
  final double dx;
  final double dy;
  final double size;
  final Color color;

  _GlitterParticle({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
  });
}

class _GlitterPainter extends CustomPainter {
  final List<_GlitterParticle> particles;
  final Offset origin;
  final double progress;

  _GlitterPainter(this.particles, this.origin, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || particles.isEmpty) return;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = p.color.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0));
      final center = Offset(origin.dx + p.dx * progress, origin.dy + p.dy * progress);
      canvas.drawCircle(center, p.size * (1.0 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlitterPainter oldDelegate) => true;
}


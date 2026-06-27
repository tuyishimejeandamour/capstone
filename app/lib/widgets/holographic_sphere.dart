import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A premium, custom-painted glowing sphere that rotates, pulses, and floats
/// gently. Uses solid-color layering with blend modes (no gradients).
class HolographicSphere extends StatefulWidget {
  final double size;
  const HolographicSphere({super.key, this.size = 180});

  @override
  State<HolographicSphere> createState() => _HolographicSphereState();
}

class _HolographicSphereState extends State<HolographicSphere>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    // Floating motion
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Rotation of inner highlight
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatController, _rotationController]),
      builder: (context, child) {
        final floatOffset = math.sin(_floatController.value * math.pi * 2) * 8.0;
        final pulseScale = 1.0 + math.sin(_floatController.value * math.pi * 2) * 0.04;
        final rotationRad = _rotationController.value * math.pi * 2;

        return SizedBox(
          width: widget.size + 40,
          height: widget.size + 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The floating glowing sphere
              Transform.translate(
                offset: Offset(0, floatOffset),
                child: Transform.scale(
                  scale: pulseScale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3BE2B0).withValues(alpha: 0.22),
                          blurRadius: 48,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFF926BFF).withValues(alpha: 0.10),
                          blurRadius: 36,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _GlowingSpherePainter(rotation: rotationRad),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Subtly blurred ground shadow
              SizedBox(
                width: widget.size * 0.6,
                height: 10,
                child: CustomPaint(
                  painter: _ShadowPainter(scale: 1.0 - (_floatController.value - 0.5).abs() * 0.12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowingSpherePainter extends CustomPainter {
  final double rotation;

  _GlowingSpherePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.5;

    // Layer 1: Deep forest green solid base
    final basePaint = Paint()..color = const Color(0xFF0B1E12);
    canvas.drawCircle(center, radius, basePaint);

    // Layer 2: Soft mint glow from top-left (specular highlight, solid + blur)
    final highlightPaint = Paint()
      ..color = const Color(0xFF3BE2B0).withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawCircle(
      center + Offset(
        math.cos(rotation) * w * 0.18 - w * 0.15,
        math.sin(rotation) * h * 0.18 - h * 0.15,
      ),
      radius * 0.65,
      highlightPaint,
    );

    // Layer 3: Violet inner core glow
    final violetPaint = Paint()
      ..color = const Color(0xFF926BFF).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(
      center + Offset(
        math.cos(rotation + math.pi) * w * 0.12,
        math.sin(rotation + math.pi) * h * 0.12,
      ),
      radius * 0.5,
      violetPaint,
    );

    // Layer 4: Mint rim edge (outer ring)
    final rimPaint = Paint()
      ..color = const Color(0xFF3BE2B0).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius - 1.5, rimPaint);

    // Layer 5: Glass crescent highlight stroke (top-left edge)
    final crescentPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final crescentPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        -math.pi * 0.75,
        math.pi * 0.5,
      );
    canvas.drawPath(crescentPath, crescentPaint);

    // Layer 6: Floating spark particles
    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(
      center + Offset(math.cos(rotation * 2) * w * 0.1, math.sin(rotation * 2) * h * 0.1),
      3.0,
      sparkPaint,
    );
    canvas.drawCircle(
      center + Offset(math.cos(rotation * 1.5 + 1) * w * 0.15, -math.sin(rotation * 1.5 + 1) * h * 0.15),
      1.5,
      sparkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowingSpherePainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

class _ShadowPainter extends CustomPainter {
  final double scale;
  _ShadowPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.35 * scale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 0.9 * scale,
        height: h * 0.8 * scale,
      ),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ShadowPainter oldDelegate) {
    return oldDelegate.scale != scale;
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A premium, custom-painted holographic iridescent sphere that rotates,
/// pulses, and floats gently. Replicates Screen 2 of the reference mockups.
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

    // Rotation of gradients
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
                          color: const Color(0xFF926BFF).withValues(alpha: 0.28),
                          blurRadius: 48,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFF3BE2B0).withValues(alpha: 0.12),
                          blurRadius: 36,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _HolographicSpherePainter(rotation: rotationRad),
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

class _HolographicSpherePainter extends CustomPainter {
  final double rotation;

  _HolographicSpherePainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final radius = w * 0.5;

    // Draw solid back layer to prevent background transparency bleedthrough
    final solidBack = Paint()..color = const Color(0xFF0F141F);
    canvas.drawCircle(center, radius, solidBack);

    // 1. Layer 1: Iridescent Holographic Base Gradient
    // Rotates slowly with rotation parameter
    final baseGradient = RadialGradient(
      center: Alignment(
        math.cos(rotation) * 0.4 - 0.2,
        math.sin(rotation) * 0.4 - 0.2,
      ),
      radius: 0.9,
      colors: [
        const Color(0xFFE2B0FF).withValues(alpha: 0.95), // Holographic Pink/Lavender
        const Color(0xFF926BFF).withValues(alpha: 0.8),  // Pastel Purple
        const Color(0xFF3BE2B0).withValues(alpha: 0.65), // Pastel Cyan/Mint
        const Color(0xFF673AB7).withValues(alpha: 0.4),  // Warm Violet
        const Color(0xFF0C101A).withValues(alpha: 0.98), // Deep Outer space
      ],
      stops: const [0.0, 0.28, 0.55, 0.82, 1.0],
    );
    final basePaint = Paint()..shader = baseGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawCircle(center, radius, basePaint);

    // 2. Layer 2: Glowing Specular Highlight (Simulating 3D glass reflection)
    final highlightGradient = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.5,
      colors: [
        Colors.white.withValues(alpha: 0.85),
        Colors.white.withValues(alpha: 0.35),
        Colors.white.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.4, 1.0],
    );
    final highlightPaint = Paint()
      ..shader = highlightGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(center, radius, highlightPaint);

    // 3. Layer 3: Cyan Edge Rim Glow (Refraction on the dark side)
    final rimGradient = RadialGradient(
      center: const Alignment(0.4, 0.4),
      radius: 0.75,
      colors: [
        const Color(0xFF3BE2B0).withValues(alpha: 0.0),
        const Color(0xFF3BE2B0).withValues(alpha: 0.3),
        const Color(0xFF3BE2B0).withValues(alpha: 0.85),
      ],
      stops: const [0.65, 0.85, 1.0],
    );
    final rimPaint = Paint()
      ..shader = rimGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..blendMode = BlendMode.screen;
    canvas.drawCircle(center, radius, rimPaint);

    // 4. Layer 4: Glass Sphere Specular Crescent Reflection (Top Edge Curve)
    final crescentPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    final crescentPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        -math.pi * 0.75,
        math.pi * 0.5,
      );
    canvas.drawPath(crescentPath, crescentPaint);

    // 5. Layer 5: Glowing Center Spark core (Simulating floating particles inside)
    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center + Offset(math.cos(rotation * 2) * w * 0.1, math.sin(rotation * 2) * h * 0.1), 3.0, sparkPaint);
    canvas.drawCircle(center + Offset(math.cos(rotation * 1.5 + 1) * w * 0.15, -math.sin(rotation * 1.5 + 1) * h * 0.15), 1.5, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant _HolographicSpherePainter oldDelegate) {
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

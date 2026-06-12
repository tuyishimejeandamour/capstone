import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A premium, custom-painted vector robot mascot that floats up and down
/// and casts a dynamic shadow on the ground.
class FloatingRobot extends StatefulWidget {
  final double size;
  const FloatingRobot({super.key, this.size = 200});

  @override
  State<FloatingRobot> createState() => _FloatingRobotState();
}

class _FloatingRobotState extends State<FloatingRobot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Compute floating offset using sine wave
        final floatOffset = math.sin(_controller.value * math.pi * 2) * 12.0;
        final shadowScale = 1.0 - (_controller.value - 0.5).abs() * 0.15;

        return SizedBox(
          width: widget.size,
          height: widget.size + 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The floating robot
              Transform.translate(
                offset: Offset(0, floatOffset - 10),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _RobotPainter(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Dynamic shadow on the ground
              SizedBox(
                width: widget.size * 0.7,
                height: 12,
                child: CustomPaint(
                  painter: _ShadowPainter(scale: shadowScale),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headPaint = Paint()..color = Colors.white;
    final darkScreenPaint = Paint()..color = const Color(0xFF1E1E2C);
    
    final eyePaint = Paint()
      ..color = const Color(0xFFFF52C5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final jointPaint = Paint()..color = const Color(0xFFDCDCE5);
    final glowPaint = Paint()
      ..color = const Color(0xFF926BFF).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    // Dynamic centers
    final headCenter = Offset(w * 0.5, h * 0.38);
    final headWidth = w * 0.65;
    final headHeight = h * 0.36;

    // 1. Draw glowing background behind the robot
    canvas.drawCircle(headCenter, w * 0.45, glowPaint);

    // 2. Draw Ears / Side Antennas
    final leftAntennaPath = Path()
      ..moveTo(w * 0.15, h * 0.34)
      ..lineTo(w * 0.1, h * 0.3)
      ..lineTo(w * 0.1, h * 0.42)
      ..close();
    canvas.drawPath(leftAntennaPath, jointPaint);
    canvas.drawCircle(Offset(w * 0.1, h * 0.3), 4, eyePaint);

    final rightAntennaPath = Path()
      ..moveTo(w * 0.85, h * 0.34)
      ..lineTo(w * 0.9, h * 0.3)
      ..lineTo(w * 0.9, h * 0.42)
      ..close();
    canvas.drawPath(rightAntennaPath, jointPaint);
    canvas.drawCircle(Offset(w * 0.9, h * 0.3), 4, eyePaint);

    // 3. Draw Body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.74), width: w * 0.48, height: h * 0.34),
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(bodyRect, headPaint);

    // Draw chest glowing panel
    final chestPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF926BFF), Color(0xFF3BE2B0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCenter(center: Offset(w * 0.5, h * 0.74), width: w * 0.28, height: h * 0.14));
    
    final chestRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.74), width: w * 0.28, height: h * 0.14),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(chestRect, chestPaint);

    // Draw little cute logo/symbol on the chest (a psychology icon or cross/heart shape)
    final symbolPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(w * 0.5, h * 0.74), w * 0.035, symbolPaint);

    // 4. Draw Arms
    final leftShoulder = Offset(w * 0.22, h * 0.7);
    final rightShoulder = Offset(w * 0.78, h * 0.7);

    // Left Arm (rounded capsule)
    final leftArmRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.18, h * 0.76), width: w * 0.08, height: h * 0.2),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(leftArmRect, headPaint);
    canvas.drawCircle(leftShoulder, w * 0.05, jointPaint);

    // Right Arm (rounded capsule)
    final rightArmRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.82, h * 0.76), width: w * 0.08, height: h * 0.2),
      Radius.circular(w * 0.04),
    );
    canvas.drawRRect(rightArmRect, headPaint);
    canvas.drawCircle(rightShoulder, w * 0.05, jointPaint);

    // 5. Draw Neck joint
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.56), width: w * 0.18, height: h * 0.08),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, jointPaint);

    // 6. Draw Head
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: headCenter, width: headWidth, height: headHeight),
      Radius.circular(w * 0.15),
    );
    canvas.drawRRect(headRect, headPaint);

    // 7. Draw Screen Face (Dark screen)
    final screenWidth = headWidth * 0.86;
    final screenHeight = headHeight * 0.78;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: headCenter, width: screenWidth, height: screenHeight),
      Radius.circular(w * 0.09),
    );
    canvas.drawRRect(screenRect, darkScreenPaint);

    // 8. Draw Cute Glowing Eyes (2 circles)
    final leftEyeCenter = Offset(headCenter.dx - screenWidth * 0.26, headCenter.dy - screenHeight * 0.05);
    final rightEyeCenter = Offset(headCenter.dx + screenWidth * 0.26, headCenter.dy - screenHeight * 0.05);
    
    // Glowing circles for eyes
    canvas.drawCircle(leftEyeCenter, w * 0.045, eyePaint);
    canvas.drawCircle(rightEyeCenter, w * 0.045, eyePaint);
    
    // Catch light in eyes
    final catchLightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(leftEyeCenter - Offset(w * 0.012, w * 0.012), w * 0.015, catchLightPaint);
    canvas.drawCircle(rightEyeCenter - Offset(w * 0.012, w * 0.012), w * 0.015, catchLightPaint);

    // 9. Draw Cute Smile (curved arc)
    final mouthPaint = Paint()
      ..color = const Color(0xFFFF52C5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final mouthRect = Rect.fromCenter(
      center: Offset(headCenter.dx, headCenter.dy + screenHeight * 0.18),
      width: screenWidth * 0.22,
      height: screenHeight * 0.14,
    );
    canvas.drawArc(mouthRect, 0, math.pi, false, mouthPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShadowPainter extends CustomPainter {
  final double scale;
  _ShadowPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()
      ..color = const Color(0xFF000000).withValues(alpha: 0.4 * scale)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Draw dynamic oval shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.5),
        width: w * 0.95 * scale,
        height: h * 0.85 * scale,
      ),
      shadowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ShadowPainter oldDelegate) {
    return oldDelegate.scale != scale;
  }
}

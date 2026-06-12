import 'dart:math' as math;
import 'package:flutter/material.dart';

class AudioWaveVisualizer extends StatefulWidget {
  final bool isListening;
  final Color waveColor;

  const AudioWaveVisualizer({
    super.key,
    required this.isListening,
    this.waveColor = const Color(0xFF3BE2B0), // Soothing mint/teal
  });

  @override
  State<AudioWaveVisualizer> createState() => _AudioWaveVisualizerState();
}

class _AudioWaveVisualizerState extends State<AudioWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isListening) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AudioWaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isListening && _controller.isAnimating) {
      _controller.stop();
    }
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
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 120),
          painter: _WavePainter(
            animationValue: _controller.value,
            isListening: widget.isListening,
            color: widget.waveColor,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double animationValue;
  final bool isListening;
  final Color color;

  _WavePainter({
    required this.animationValue,
    required this.isListening,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final double width = size.width;
    final double height = size.height;
    final double midY = height / 2;

    if (!isListening) {
      // Draw a simple flat resting line with slight organic noise
      final path = Path();
      path.moveTo(0, midY);
      path.lineTo(width, midY);
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, linePaint);
      return;
    }

    // Draw three layers of transparent overlapping sine waves
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      path.moveTo(0, height);

      // Unique properties for each wave layer to create complex organic motion
      final double waveFrequency = (0.01 + (layer * 0.005));
      final double speedMultiplier = (1.5 + (layer * 0.5));
      final double waveHeight = 25.0 - (layer * 6.0);
      final double phaseShift = (layer * math.pi / 2);

      for (double x = 0; x <= width; x += 3) {
        final double t = animationValue * 2 * math.pi * speedMultiplier + phaseShift;
        final double y = midY +
            math.sin(x * waveFrequency + t) *
                waveHeight *
                math.sin(x / width * math.pi); // Envelope to taper ends

        if (x == 0) {
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      path.lineTo(width, height);
      path.close();

      // Fade layers differently for premium glassmorphic depth
      paint.color = color.withValues(alpha: 0.08 + (0.05 * (3 - layer)));
      canvas.drawPath(path, paint);

      // Draw outlines for each wave for added aesthetic glow
      final strokePaint = Paint()
        ..color = color.withValues(alpha: 0.2 + (0.15 * layer))
        ..strokeWidth = 1.5 - (layer * 0.3)
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isListening != isListening ||
        oldDelegate.color != color;
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;

class DnaLoadingAnimation extends StatefulWidget {
  final double width;
  final double height;

  const DnaLoadingAnimation({
    Key? key,
    this.width = 200,
    this.height = 60,
  }) : super(key: key);

  @override
  State<DnaLoadingAnimation> createState() => _DnaLoadingAnimationState();
}

class _DnaLoadingAnimationState extends State<DnaLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: DnaPainter(
              animation: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class DnaPainter extends CustomPainter {
  final double animation;

  DnaPainter({
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height * 0.12;
    final helixWidth = size.width * 0.85;
    final helixHeight = size.height * 0.7;

    // Professional gradient colors for DNA strands
    final List<Color> gradient1Colors = [
      const Color(0xFF667eea), // Purple-blue
      const Color(0xFF764ba2), // Deep purple
      const Color(0xFFF093FB), // Light purple-pink
    ];

    final List<Color> gradient2Colors = [
      const Color(0xFF4facfe), // Bright blue
      const Color(0xFF00f2fe), // Cyan
      const Color(0xFF43e97b), // Green-cyan
    ];

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF667eea).withOpacity(0.3),
          const Color(0xFF4facfe).withOpacity(0.3),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Draw 12 pairs of DNA dots for longer helix
    for (int i = 0; i < 12; i++) {
      final progress = (i / 12) + animation;
      final xPos = (i / 11) * helixWidth - helixWidth / 2;

      // Calculate helix positions (horizontal orientation)
      final angle1 = progress * 2 * math.pi;
      final angle2 = angle1 + math.pi;

      final x = center.dx + xPos;
      final y1 = center.dy + math.sin(angle1) * (helixHeight / 2);
      final y2 = center.dy + math.sin(angle2) * (helixHeight / 2);

      final point1 = Offset(x, y1);
      final point2 = Offset(x, y2);

      // Calculate opacity based on z-position for depth effect
      final z1 = math.cos(angle1);
      final z2 = math.cos(angle2);

      final opacity1 = (z1 + 1) / 2;
      final opacity2 = (z2 + 1) / 2;

      // Draw connecting line only when dots are close
      if ((y1 - y2).abs() < helixHeight * 0.8) {
        canvas.drawLine(point1, point2, linePaint);
      }

      // Create gradient for strand 1 (purple gradient)
      final gradientColor1 = _getGradientColor(gradient1Colors, progress % 1.0);
      final paint1 = Paint()
        ..shader = RadialGradient(
          colors: [
            gradientColor1.withOpacity(0.9 + opacity1 * 0.1),
            gradientColor1.withOpacity(0.5 + opacity1 * 0.5),
          ],
        ).createShader(
          Rect.fromCircle(
            center: point1,
            radius: radius * (0.7 + opacity1 * 0.3),
          ),
        )
        ..style = PaintingStyle.fill;

      // Create gradient for strand 2 (blue-cyan gradient)
      final gradientColor2 = _getGradientColor(gradient2Colors, (progress + 0.5) % 1.0);
      final paint2 = Paint()
        ..shader = RadialGradient(
          colors: [
            gradientColor2.withOpacity(0.9 + opacity2 * 0.1),
            gradientColor2.withOpacity(0.5 + opacity2 * 0.5),
          ],
        ).createShader(
          Rect.fromCircle(
            center: point2,
            radius: radius * (0.7 + opacity2 * 0.3),
          ),
        )
        ..style = PaintingStyle.fill;

      // Draw dots with gradient and glow effect
      canvas.drawCircle(
        point1,
        radius * (0.7 + opacity1 * 0.3),
        paint1,
      );

      canvas.drawCircle(
        point2,
        radius * (0.7 + opacity2 * 0.3),
        paint2,
      );

      // Add glow effect
      final glowPaint1 = Paint()
        ..color = gradientColor1.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final glowPaint2 = Paint()
        ..color = gradientColor2.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(
        point1,
        radius * (0.9 + opacity1 * 0.3),
        glowPaint1,
      );

      canvas.drawCircle(
        point2,
        radius * (0.9 + opacity2 * 0.3),
        glowPaint2,
      );
    }
  }

  Color _getGradientColor(List<Color> colors, double position) {
    if (colors.isEmpty) return Colors.white;
    if (colors.length == 1) return colors[0];

    final segmentSize = 1.0 / (colors.length - 1);
    final segmentIndex = (position / segmentSize).floor().clamp(0, colors.length - 2);
    final segmentProgress = (position - segmentIndex * segmentSize) / segmentSize;

    return Color.lerp(
      colors[segmentIndex],
      colors[segmentIndex + 1],
      segmentProgress,
    )!;
  }

  @override
  bool shouldRepaint(DnaPainter oldDelegate) => true;
}
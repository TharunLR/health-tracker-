import 'package:flutter/material.dart';
import 'calz_ai_coach_sheet.dart';

class CalzMascotWidget extends StatelessWidget {
  const CalzMascotWidget({
    super.key,
    this.starPoints = 0,
    this.size = 180,
    this.showBadge = true,
    this.onTap,
  });

  final int starPoints;
  final double size;
  final bool showBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => CalzAICoachSheet.show(context),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Sleek Modern 3D AI Health Emblem & Mascot Logo
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A59), Color(0xFFFF5252), Color(0xFFFF9100)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A59).withValues(alpha: 0.35),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner Glass Ring
                Container(
                  width: size * 0.86,
                  height: size * 0.86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),

                // Health Pulse Line & AI Spark Emblem
                CustomPaint(
                  size: Size(size * 0.65, size * 0.65),
                  painter: _HealthLogoPainter(),
                ),

                // Mascot Eyes
                Positioned(
                  top: size * 0.28,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEye(size),
                      SizedBox(width: size * 0.12),
                      _buildEye(size),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Star Points Badge on top right
          if (showBadge)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF111111), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(2, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$starPoints',
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFF111111),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEye(double parentSize) {
    return Container(
      width: parentSize * 0.08,
      height: parentSize * 0.11,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular( parentSize * 0.05),
      ),
      child: Center(
        child: Container(
          width: parentSize * 0.04,
          height: parentSize * 0.06,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _HealthLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final sparkPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;

    // Heart Pulse Line
    final path = Path();
    path.moveTo(0, size.height * 0.60);
    path.lineTo(size.width * 0.25, size.height * 0.60);
    path.lineTo(size.width * 0.38, size.height * 0.35);
    path.lineTo(size.width * 0.52, size.height * 0.85);
    path.lineTo(size.width * 0.68, size.height * 0.45);
    path.lineTo(size.width * 0.78, size.height * 0.60);
    path.lineTo(size.width, size.height * 0.60);

    canvas.drawPath(path, strokePaint);

    // AI Spark Star (Top Right)
    final spark = Path();
    final cx = size.width * 0.80;
    final cy = size.height * 0.25;
    final r = size.width * 0.12;

    spark.moveTo(cx, cy - r);
    spark.quadraticBezierTo(cx, cy, cx + r, cy);
    spark.quadraticBezierTo(cx, cy, cx, cy + r);
    spark.quadraticBezierTo(cx, cy, cx - r, cy);
    spark.quadraticBezierTo(cx, cy, cx, cy - r);
    spark.close();

    canvas.drawPath(spark, sparkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

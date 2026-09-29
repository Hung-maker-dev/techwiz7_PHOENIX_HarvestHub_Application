import 'package:flutter/material.dart';

class HarvestHubLogo extends StatelessWidget {
  const HarvestHubLogo({
    super.key,
    this.compact = false,
    this.showName = true,
  });

  final bool compact;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 56.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: const _HarvestMarkPainter(),
            child: const SizedBox.expand(),
          ),
        ),
        if (showName) ...[
          SizedBox(width: compact ? 8 : 12),
          Text(
            'HarvestHub',
            style: TextStyle(
              fontSize: compact ? 17 : 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _HarvestMarkPainter extends CustomPainter {
  const _HarvestMarkPainter();

  static const _leaf = Color(0xFF27834A);
  static const _leafLight = Color(0xFF61AA55);
  static const _tomato = Color(0xFFE85843);
  static const _carrot = Color(0xFFFF9E32);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas
      ..save()
      ..scale(scale);

    final background = Paint()..color = const Color(0xFFEAF5E8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(28),
      ),
      background,
    );

    final carrotPaint = Paint()..color = _carrot;
    final carrot = Path()
      ..moveTo(66, 39)
      ..cubicTo(78, 38, 86, 47, 82, 57)
      ..lineTo(70, 89)
      ..cubicTo(69, 94, 65, 94, 63, 89)
      ..lineTo(51, 56)
      ..cubicTo(47, 46, 55, 40, 66, 39)
      ..close();
    canvas.drawPath(carrot, carrotPaint);

    final carrotLine = Paint()
      ..color = const Color(0xFFFFD18A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(const Offset(58, 59), const Offset(64, 61), carrotLine)
      ..drawLine(const Offset(66, 73), const Offset(72, 75), carrotLine)
      ..drawLine(const Offset(63, 35), const Offset(58, 25),
          Paint()..color = _leafLight)
      ..drawLine(
          const Offset(68, 36), const Offset(70, 22), Paint()..color = _leaf)
      ..drawLine(const Offset(72, 38), const Offset(81, 29),
          Paint()..color = _leafLight);

    final leaf = Path()
      ..moveTo(17, 61)
      ..cubicTo(10, 37, 20, 16, 57, 12)
      ..cubicTo(60, 39, 48, 58, 17, 61)
      ..close();
    canvas.drawPath(leaf, Paint()..color = _leaf);
    final vein = Paint()
      ..color = const Color(0xFFDDF1D5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(17, 61), const Offset(49, 25), vein);

    canvas.drawCircle(const Offset(31, 73), 19, Paint()..color = _tomato);
    final calyx = Path()
      ..moveTo(31, 48)
      ..lineTo(35, 55)
      ..lineTo(43, 53)
      ..lineTo(39, 60)
      ..lineTo(43, 67)
      ..lineTo(34, 64)
      ..lineTo(29, 70)
      ..lineTo(28, 62)
      ..lineTo(20, 59)
      ..lineTo(28, 56)
      ..close();
    canvas.drawPath(calyx, Paint()..color = _leafLight);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HarvestMarkPainter oldDelegate) => false;
}

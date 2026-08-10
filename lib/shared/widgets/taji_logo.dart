import 'package:flutter/material.dart';

import '../../core/theme/taji_theme.dart';

class TajiLogo extends StatelessWidget {
  const TajiLogo({super.key, this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) {
    final textColor = light ? Colors.white : TajiColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: CustomPaint(painter: _TajiIconPainter(light: light)),
        ),
        const SizedBox(width: 8),
        Text(
          'taji',
          style: TextStyle(
            color: textColor,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.3,
          ),
        ),
      ],
    );
  }
}

class _TajiIconPainter extends CustomPainter {
  const _TajiIconPainter({required this.light});
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 64;
    final scaleY = size.height / 64;
    canvas.save();
    canvas.scale(scaleX, scaleY);

    final shell = Path()
      ..moveTo(32, 5.5)
      ..lineTo(54, 17.8)
      ..lineTo(54, 46.2)
      ..lineTo(32, 58.5)
      ..lineTo(10, 46.2)
      ..lineTo(10, 17.8)
      ..close();
    final shellPaint = Paint()
      ..shader = light
          ? null
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF168CFF), Color(0xFF0754D5)],
            ).createShader(const Rect.fromLTWH(10, 5.5, 44, 53))
      ..color = light ? Colors.white.withValues(alpha: .16) : Colors.white;
    canvas.drawShadow(shell, const Color(0x330754D5), 3, false);
    canvas.drawPath(shell, shellPaint);

    final inner = Path()
      ..moveTo(32, 10.8)
      ..lineTo(49.5, 20.6)
      ..lineTo(49.5, 43.4)
      ..lineTo(32, 53.2)
      ..lineTo(14.5, 43.4)
      ..lineTo(14.5, 20.6)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: light ? .42 : .28),
    );

    final mainStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(19.5, 23.2)
        ..lineTo(32, 16.3)
        ..lineTo(44.5, 23.2),
      mainStroke,
    );
    canvas.drawLine(const Offset(23, 27), const Offset(41, 27), mainStroke);
    canvas.drawLine(const Offset(32, 27), const Offset(32, 45.5), mainStroke);

    final sideStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = light
          ? Colors.white.withValues(alpha: .72)
          : const Color(0xFFA9D9FF);
    canvas.drawLine(const Offset(23, 35), const Offset(23, 43), sideStroke);
    canvas.drawLine(const Offset(41, 35), const Offset(41, 43), sideStroke);
    canvas.drawCircle(
      const Offset(32, 45.5),
      2,
      Paint()..color = light ? Colors.white : const Color(0xFF7CE6BC),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TajiIconPainter oldDelegate) =>
      oldDelegate.light != light;
}

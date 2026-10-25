import 'package:flutter/material.dart';
import 'package:nib_motion/nib_motion.dart';

/// The README mark drawn with NibMotion's path and transform primitives.
class NibMotionBrandMark extends StatelessWidget {
  const NibMotionBrandMark({super.key, this.loop = true});

  /// Set to false when capturing a settled still of the mark.
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final flourish = Path()
      ..moveTo(221, 228)
      ..cubicTo(202, 249, 172, 261, 139, 259)
      ..cubicTo(103, 257, 83, 270, 62, 257);

    return Semantics(
      label: 'A fountain pen nib drawing the NibMotion mark',
      image: true,
      child: SizedBox.square(
        dimension: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(66),
          child: Stack(
            children: [
              const Positioned.fill(child: CustomPaint(painter: _InkPainter())),
              Positioned.fill(
                child: NibDrawPath(
                  path: flourish,
                  strokeWidth: 7,
                  color: const Color(0xFF62C8DD),
                  duration: const Duration(milliseconds: 2200),
                  curve: Curves.easeInOutCubic,
                  repeat: loop,
                ),
              ),
              Positioned.fill(
                child: NibMotion(
                  initial: const NibAnim(x: 7, y: -9, rotate: .012),
                  animate: NibAnim.identity,
                  repeatAnimationInLoop: loop,
                  transition: const NibTransition(
                    duration: Duration(milliseconds: 2200),
                  ),
                  child: const CustomPaint(painter: _PenPainter()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  const _InkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 320);
    const full = Rect.fromLTWH(0, 0, 320, 320);
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF112836), Color(0xFF071A25)],
        ).createShader(full),
    );
    canvas.drawCircle(
      const Offset(158, 160),
      150,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x423A9DAB), Color(0x003A9DAB)],
        ).createShader(Rect.fromCircle(
          center: const Offset(158, 160),
          radius: 150,
        )),
    );
    final n = Path()
      ..moveTo(75, 232)
      ..lineTo(75, 89)
      ..moveTo(75, 89)
      ..cubicTo(125, 109, 172, 203, 221, 226)
      ..moveTo(221, 99)
      ..lineTo(221, 227);
    canvas.drawPath(
      n,
      Paint()
        ..color = const Color(0xAD052433)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      n,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA8EBED), Color(0xFF62C8DD), Color(0xFF268CAF)],
        ).createShader(full)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 31
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final brokenGlint = Path()
      ..moveTo(67, 187)
      ..lineTo(67, 108)
      ..moveTo(87, 111)
      ..cubicTo(105, 125, 121, 146, 137, 165)
      ..moveTo(150, 181)
      ..cubicTo(172, 207, 185, 218, 198, 222);
    canvas.drawPath(
      brokenGlint,
      Paint()
        ..color = const Color(0x8CDDF9ED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PenPainter extends CustomPainter {
  const _PenPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 320);
    final shaft = Path()
      ..moveTo(255, 65)
      ..lineTo(289, 84)
      ..quadraticBezierTo(293, 87, 291, 92)
      ..lineTo(267, 143)
      ..lineTo(235, 125)
      ..close();
    canvas.drawPath(shaft, Paint()..color = const Color(0xFF193B49));
    canvas.drawPath(
      shaft,
      Paint()
        ..color = const Color(0xFFD9EADD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final inset = Path()
      ..moveTo(263, 72)
      ..lineTo(285, 84)
      ..lineTo(261, 134)
      ..lineTo(241, 123)
      ..close();
    canvas.drawPath(inset, Paint()..color = const Color(0xFFE4EFE7));
    final nib = Path()
      ..moveTo(237, 126)
      ..quadraticBezierTo(225, 161, 222, 227)
      ..quadraticBezierTo(248, 205, 263, 149)
      ..lineTo(266, 143)
      ..close();
    canvas.drawPath(
      nib,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1CD), Color(0xFFD9B86C), Color(0xFF916C37)],
        ).createShader(const Rect.fromLTWH(220, 126, 46, 101)),
    );
    canvas.drawPath(
      nib,
      Paint()
        ..color = const Color(0xFFF6E4B3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
    final split = Path()
      ..moveTo(242, 141)
      ..cubicTo(236, 163, 230, 186, 225, 219);
    canvas.drawPath(
      split,
      Paint()
        ..color = const Color(0xFF8B693D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawCircle(
      const Offset(242, 163),
      4.7,
      Paint()..color = const Color(0xFF173D49),
    );
    canvas.drawCircle(
      const Offset(242, 163),
      4.7,
      Paint()
        ..color = const Color(0xFFF8E9C5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

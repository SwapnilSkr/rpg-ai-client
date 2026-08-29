import 'package:flutter/material.dart';

/// The Story Ink mark, drawn rather than blitted.
///
/// `assets/icons/ink-logo.png` is a full-colour render — a glossy nib inside a
/// deep-blue drop, wrapped in gold filigree and sparks. It is the right thing
/// at hero size and the wrong thing at 20pt: the detail collapses into mud, and
/// its blue is the only saturated colour anywhere in a shell built out of
/// obsidian and brass.
///
/// This keeps what the mark actually *is* — a drop with a pen nib in it — and
/// throws away everything that cannot survive being 20 pixels tall. It takes
/// the colour it is given, so it sits in brass on the top bar and can go
/// parchment or dim wherever else it is needed.
class InkMark extends StatelessWidget {
  final double size;
  final Color color;

  const InkMark({super.key, this.size = 20, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _InkMarkPainter(color)),
    );
  }
}

class _InkMarkPainter extends CustomPainter {
  final Color color;

  const _InkMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // The drop: a circle for the bulb, unioned with the crown that tapers up
    // to the point. Built as two shapes rather than one hand-tuned path so the
    // bulb stays a true circle at any size.
    final bulb = Path()..addOval(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.62), radius: w * 0.355),
    );
    final crown = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..cubicTo(w * 0.60, h * 0.24, w * 0.86, h * 0.42, w * 0.855, h * 0.64)
      ..lineTo(w * 0.145, h * 0.64)
      ..cubicTo(w * 0.14, h * 0.42, w * 0.40, h * 0.24, w * 0.5, h * 0.04)
      ..close();
    final drop = Path.combine(PathOperation.union, bulb, crown);

    canvas.drawPath(
      drop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.095
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // The nib, with the slit that makes it read as a pen rather than as a
    // triangle. evenOdd punches the slit out of the wedge in one fill, so at
    // sizes where the slit is under a pixel it simply closes up instead of
    // producing a seam.
    //
    // The slit runs past the apex on purpose. Stopping it short leaves an
    // island of brass below the gap, and the whole mark reads as an
    // exclamation point; carrying it through splits the nib into two tines,
    // which is what a nib actually looks like.
    final nib = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(w * 0.5, h * 0.87)
      ..lineTo(w * 0.30, h * 0.47)
      ..lineTo(w * 0.70, h * 0.47)
      ..close()
      ..addRect(
        Rect.fromLTRB(w * 0.458, h * 0.55, w * 0.542, h * 0.92),
      );
    canvas.drawPath(nib, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_InkMarkPainter old) => old.color != color;
}

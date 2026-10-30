import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quran_center/core/theme/design_tokens.dart';

/// The ayah-end marker of a mushaf: a scalloped medallion with an inner ring.
/// It is this app's one signature shape and carries a number, a letter or an
/// icon (levels, steps of the day, streaks).
class Rosette extends StatelessWidget {
  const Rosette({
    super.key,
    required this.child,
    this.size = 48,
    this.color = DesignTokens.primaryDarkGreen,
    this.ringColor,
    this.filled = true,
    this.petals = 12,
  });

  final Widget child;
  final double size;
  final Color color;

  /// Colour of the inner ring (defaults to a translucent white on filled ones).
  final Color? ringColor;

  /// false draws only the outline, for steps that are not reached yet.
  final bool filled;
  final int petals;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RosettePainter(color, ringColor, filled, petals),
        child: Center(child: child),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  _RosettePainter(this.color, this.ring, this.filled, this.petals);
  final Color color;
  final Color? ring;
  final bool filled;
  final int petals;

  Path _scallop(Offset c, double r) {
    final p = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final rr = r * (0.9 + 0.1 * math.cos(petals * t));
      final pt = Offset(c.dx + rr * math.cos(t), c.dy + rr * math.sin(t));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final outline = _scallop(c, r - 1);
    if (filled) {
      canvas.drawPath(outline, Paint()..color = color);
      canvas.drawCircle(
        c,
        r * 0.74,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, r * 0.05)
          ..color = ring ?? Colors.white.withValues(alpha: 0.55),
      );
    } else {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RosettePainter o) =>
      o.color != color || o.ring != ring || o.filled != filled || o.petals != petals;
}

/// A faint eight-point-star lattice (khatam) used behind headers.
class LatticePainter extends CustomPainter {
  const LatticePainter({this.color = Colors.white, this.opacity = 0.07, this.cell = 64});
  final Color color;
  final double opacity;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: opacity);
    final r = cell * 0.36;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        _star(canvas, Offset(x, y), r, paint);
        _star(canvas, Offset(x + cell / 2, y + cell / 2), r * 0.45, paint);
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path();
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.62;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), paint);
  }

  @override
  bool shouldRepaint(LatticePainter o) => o.color != color || o.opacity != opacity || o.cell != cell;
}

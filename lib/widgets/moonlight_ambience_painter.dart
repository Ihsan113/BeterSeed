import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Battery-friendly ambient layers: drifting foreground leaves, moonlit
/// reflective ripples and mist. No extra video or continuous downloads.
class MoonlightAmbiencePainter extends CustomPainter {
  const MoonlightAmbiencePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress * math.pi * 2;
    // Water glints follow slow periodic trajectories rather than spawning
    // abrupt particles when the controller repeats.
    for (var i = 0; i < 17; i++) {
      final x = size.width * (.18 + .62 * ((i * 13) % 17) / 17);
      final y = size.height * (.49 + .14 * ((i * 7) % 17) / 17);
      final alpha = .10 + .25 * (.5 + .5 * math.sin(t + i * .75));
      final length = 6.0 + 10 * (.5 + .5 * math.cos(t + i));
      canvas.drawLine(Offset(x-length/2, y), Offset(x+length/2, y),
          Paint()..color = const Color(0xFFD8E4FF).withValues(alpha: alpha)
                 ..strokeWidth = 1.15..strokeCap = StrokeCap.round);
    }
    // Gentle foreground leaves - anchored to scenery edge, no sudden jump.
    for (var i = 0; i < 12; i++) {
      final side = i.isEven ? 0.0 : 1.0;
      final x = side == 0 ? size.width * (.025 + .07 * (i % 4)) :
          size.width * (.91 + .055 * (i % 4) / 3);
      final y = size.height * (.15 + .62 * ((i * 7) % 13) / 13);
      final wind = math.sin(t + i * 1.12) * 7;
      canvas.save();
      canvas.translate(x+wind, y);
      canvas.rotate(math.sin(t + i) * .12);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero,
        width: 5 + (i % 3)*2, height: 12 + (i % 3)*2),
        Paint()..color = const Color(0xFF8899B7).withValues(alpha: .17));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MoonlightAmbiencePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

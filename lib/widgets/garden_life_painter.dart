import 'dart:math' as math;
import 'package:flutter/material.dart';

class FireflyPalette {
  const FireflyPalette({
    required this.glow,
    required this.spark,
    required this.core,
  });

  final Color glow;
  final Color spark;
  final Color core;

  static const warm = FireflyPalette(
    glow: Color(0xFFFFE39A),
    spark: Color(0xFFF8EDAC),
    core: Colors.white,
  );

  static const sakura = FireflyPalette(
    glow: Color(0xFFFFB1D6),
    spark: Color(0xFFFF8FBF),
    core: Color(0xFFFFE6F1),
  );

  static const prism = FireflyPalette(
    glow: Color(0xFFB98DFF),
    spark: Color(0xFFFFA8EC),
    core: Color(0xFFF7F6FF),
  );

  static const autumn = FireflyPalette(
    glow: Color(0xFFFFA34D),
    spark: Color(0xFFFFD38A),
    core: Color(0xFFFFF1C9),
  );
}

/// Lightweight looping fireflies for the garden background.
/// Butterfly motion is handled by image assets in the main Garden scene.
class GardenLifePainter extends CustomPainter {
  const GardenLifePainter(this.progress, {this.palette = FireflyPalette.warm});

  final double progress;
  final FireflyPalette palette;
  static const _tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = progress % 1;
    _paintFireflies(canvas, size, t);
  }

  void _paintFireflies(Canvas canvas, Size size, double t) {
    const count = 20;
    for (var i = 0; i < count; i++) {
      final u = ((i * 37 + 11) % 97) / 97.0;
      final v = ((i * 29 + 7) % 89) / 89.0;
      final phase = i * .91;
      final x = size.width * (.09 + .82 * u) +
          math.sin(_tau * (t * (1 + i % 2)) + phase) * (9 + i % 4 * 4);
      final y = size.height * (.16 + .70 * v) +
          math.cos(_tau * (t * (1 + i % 3)) + phase) * (11 + i % 3 * 4);
      final pulse = .5 + .5 * math.sin(_tau * (t * 9) + phase);
      final alpha = .42 + .48 * pulse;
      final radius = 1.8 + (i % 3) * .7;
      final point = Offset(x, y);
      final glowColor = palette == FireflyPalette.prism
          ? _colorCycle(i)
          : palette.glow;
      final sparkColor = palette == FireflyPalette.prism
          ? _sparkCycle(i)
          : palette.spark;
      final coreColor = palette == FireflyPalette.prism
          ? const Color(0xFFF7F6FF)
          : palette.core;

      canvas.drawCircle(
        point,
        radius * 6.0,
        Paint()
          ..color = glowColor.withValues(alpha: alpha * .24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        point,
        radius * 2.5,
        Paint()..color = sparkColor.withValues(alpha: alpha * .62),
      );
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = coreColor.withValues(alpha: alpha),
      );
    }
  }

  Color _colorCycle(int index) {
    const colors = <Color>[
      Color(0xFFFFD36E),
      Color(0xFF9CFFB8),
      Color(0xFF86D8FF),
      Color(0xFFFFA4DF),
      Color(0xFFB88DFF),
    ];
    return colors[index % colors.length];
  }

  Color _sparkCycle(int index) {
    const colors = <Color>[
      Color(0xFFFFF1B1),
      Color(0xFFE1FFD6),
      Color(0xFFD9F2FF),
      Color(0xFFFFD4EE),
      Color(0xFFE6D9FF),
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant GardenLifePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.palette != palette;
}

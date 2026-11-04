import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'garden_life_painter.dart';

/// Mirrors the small Canvas animation in BetterSeedLiveWallpaperService.
/// The captured base excludes these effects so there are no frozen duplicates.
class LiveWallpaperEffects extends CustomPainter {
  LiveWallpaperEffects(this.clock, this.butterfly, this.palette)
      : super(repaint: clock);
  final Animation<double> clock;
  final ui.Image butterfly;
  final FireflyPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 120;
    final unit = size.width / 390;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var i = 0; i < 16; i++) {
      final x = size.width * (.09 + .82 * ((i * 37 + 11) % 97) / 97) +
          math.sin(t * .35 + i) * 10 * unit;
      final y = size.height * (.16 + .70 * ((i * 29 + 7) % 89) / 89) +
          math.cos(t * .28 + i) * 12 * unit;
      final alpha = .35 + .5 * (.5 + .5 * math.sin(t * 1.4 + i));
      final radius = (1.3 + i % 3 * .4) * unit;
      canvas.drawCircle(Offset(x, y), radius * 4,
          paint..color = palette.glow.withValues(alpha: alpha * .16));
      canvas.drawCircle(Offset(x, y), radius * 1.8,
          paint..color = palette.spark.withValues(alpha: alpha * .5));
      canvas.drawCircle(Offset(x, y), radius,
          paint..color = palette.core.withValues(alpha: alpha));
    }
    paint.color = Colors.white;
    for (var i = 0; i < 3; i++) {
      final x =
          size.width * ([.22, .76, .52][i] + math.sin(t * .48 + i) * .025);
      final y =
          size.height * ([.42, .32, .65][i] + math.cos(t * .37 + i) * .02);
      final width = size.width * [.085, .075, .065][i];
      final height = width * butterfly.height / butterfly.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(math.sin(t * .6 + i) * .12);
      canvas.scale(.55 + .45 * math.sin(t * 3 + i).abs(), 1);
      canvas.drawImageRect(
          butterfly,
          Rect.fromLTWH(
              0, 0, butterfly.width.toDouble(), butterfly.height.toDouble()),
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(LiveWallpaperEffects oldDelegate) =>
      oldDelegate.butterfly != butterfly || oldDelegate.palette != palette;
}

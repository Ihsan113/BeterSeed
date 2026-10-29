import 'dart:math' as math;

import 'package:betterseed/logic/garden_scene_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Still wallpaper butterfly layout', () {
    test('premium butterfly skins keep three clearly separated sprites', () {
      const width = 1080.0;
      const height = 2400.0;
      for (final id in const [
        'cosmic_butterfly',
        'sakura_butterfly',
        'amber_butterfly',
      ]) {
        final layouts = GardenSceneGeometry.stillButterflies(id);
        expect(layouts, hasLength(3), reason: '$id should keep three butterflies');
        for (var i = 0; i < layouts.length; i++) {
          final a = layouts[i];
          final ax = a.anchorX * width;
          final ay = a.anchorY * height;
          expect(a.anchorX, inInclusiveRange(.15, .85));
          expect(a.anchorY, inInclusiveRange(.25, .70));
          for (var j = i + 1; j < layouts.length; j++) {
            final b = layouts[j];
            final bx = b.anchorX * width;
            final by = b.anchorY * height;
            final distance = math.sqrt(math.pow(ax - bx, 2) + math.pow(ay - by, 2));
            final minimum = (a.size + b.size) * 1.8;
            expect(
              distance,
              greaterThan(minimum),
              reason: '$id butterflies $i and $j are too close for a static wallpaper capture',
            );
          }
        }
      }
    });

    test('default still layout remains available', () {
      final layouts = GardenSceneGeometry.stillButterflies('default');
      expect(layouts, hasLength(3));
      expect(layouts.first.anchorX, closeTo(.22, .0001));
      expect(layouts.first.anchorY, closeTo(.42, .0001));
    });
  });
}

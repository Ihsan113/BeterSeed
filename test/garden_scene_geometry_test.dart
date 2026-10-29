import 'package:betterseed/logic/garden_scene_geometry.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tree contact stays fixed regardless of watering progress', () {
    for (final scene in <Size>[const Size(360, 560), const Size(420, 820)]) {
      final target = GardenSceneGeometry.rootTarget(scene);
      expect(target.dx, scene.width / 2);
      expect(target.dy, greaterThan(scene.height / 2));
      expect(target.dy, lessThan(scene.height));
      expect(GardenSceneGeometry.treeSize(scene), greaterThan(0));
    }
  });


  test('both calibrated planting grounds keep tree, soil and watering aligned', () {
    for (final scene in <Size>[const Size(320, 420), const Size(393, 640), const Size(600, 900)]) {
      for (final theme in PlantingGround.values) {
        final target = GardenSceneGeometry.rootTarget(scene, ground: theme);
        final soilBottom = GardenSceneGeometry.plantingPlaneBottom(scene, ground: theme);
        final soilHeight = GardenSceneGeometry.plantingPlaneHeight(scene);
        final soilCenterY = scene.height - soilBottom - soilHeight * .5;
        expect((target.dy - soilCenterY).abs(), lessThan(.01));
        expect(target.dx, scene.width / 2);
        expect(target.dy, greaterThan(scene.height / 2));
        expect(target.dy, lessThan(scene.height));
      }
    }
  });

  test('watering can nozzle follows the sprite rotation on every frame', () {
    const scene = Size(400, 600);
    final size = GardenSceneGeometry.wateringCanSize(scene);
    for (final progress in <double>[0.01, .25, .50, .75, .99]) {
      final center = GardenSceneGeometry.wateringCanCenter(scene, progress);
      final spout = GardenSceneGeometry.wateringSpout(scene, progress);
      expect((spout - center).distance, closeTo(size * .441, .1));
      expect(spout.dx, lessThan(center.dx));
      expect(spout.dy, greaterThan(0));
      expect(spout.dy, lessThan(scene.height));
    }
  });
}

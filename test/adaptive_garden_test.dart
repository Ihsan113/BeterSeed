import 'dart:io';

import 'package:betterseed/logic/garden_scene_geometry.dart';
import 'package:betterseed/widgets/adaptive_garden_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scenic image fills the screen without blur', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: AdaptiveGardenBackground(asset: 'assets/images/backgrounds/moonlight_premium.webp'),
    )));
    final sharp = tester.widget<Image>(find.byKey(const ValueKey('full-background')));
    expect(sharp.fit, BoxFit.cover);
    expect(find.byType(ImageFiltered), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Android home widget uses its gradient rather than photographic scenes', () {
    final xml = File('native/android/res/layout/betterseed_widget.xml').readAsStringSync();
    final native = File('native/android/kotlin/BetterSeedWidget.kt').readAsStringSync();
    expect(xml.contains('widget_scene_bg'), isFalse);
    expect(native.contains('widget_bg_moonlight'), isFalse);
    expect(native.contains('moonTreeArt[stage - 1]'), isTrue);
    expect(File('native/android/res/drawable/widget_background.xml').existsSync(), isTrue);
  });

  test('planting marker remains stable on several scene shapes', () {
    for (final scene in <Size>[const Size(320, 400), const Size(360, 540), const Size(600, 900)]) {
      for (final theme in PlantingGround.values) {
        final marker = GardenSceneGeometry.rootTarget(scene, ground: theme);
        final center = scene.height - GardenSceneGeometry.plantingPlaneBottom(scene, ground: theme)
            - GardenSceneGeometry.plantingPlaneHeight(scene) / 2;
        expect((marker.dy - center).abs(), lessThan(0.01));
        expect(marker.dx, scene.width / 2);
      }
    }
  });
}

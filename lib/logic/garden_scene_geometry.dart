import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Geometry shared by the tree, watering can, and water stream.
/// All positions are calculated in the SAME local scene coordinates.
enum PlantingGround { defaultGarden, moonlightGarden, sakuraGarden, autumnGarden, auroraGarden, mushroomGarden, cloudGarden, coralGarden, desertGarden, fairyGarden }

/// Saved for each background. dx/dy are fractions of the live Garden scene.
/// Positive dy moves the tree DOWN; scale keeps the sprite within sane limits.
class GardenTreePlacement {
  const GardenTreePlacement({this.dx = 0, this.dy = 0, this.scale = 1});
  final double dx;
  final double dy;
  final double scale;

  GardenTreePlacement copyWith({double? dx, double? dy, double? scale}) =>
      GardenTreePlacement(
        dx: (dx ?? this.dx).clamp(-.35, .35).toDouble(),
        dy: (dy ?? this.dy).clamp(-.35, .35).toDouble(),
        scale: (scale ?? this.scale).clamp(.65, 1.35).toDouble(),
      );

  Map<String, double> toJson() => {'dx': dx, 'dy': dy, 'scale': scale};

  factory GardenTreePlacement.fromJson(Object? data) {
    if (data is! Map) return const GardenTreePlacement();
    double read(String key, double fallback, double min, double max) {
      final value = data[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.toDouble().clamp(min, max).toDouble();
    }
    return GardenTreePlacement(
      dx: read('dx', 0, -.35, .35),
      dy: read('dy', 0, -.35, .35),
      scale: read('scale', 1, .65, 1.35),
    );
  }
}

class GardenSceneGeometry {
  const GardenSceneGeometry._();

  /// Shared butterfly sprite layout information.
  ///
  /// These normalized anchors intentionally keep the wallpaper capture stable:
  /// animated scenes can orbit around the anchors, while still captures use the
  /// anchors directly so the premium butterflies do not bunch together.
  static List<ButterflySpriteLayout> animatedButterflies() => const [
        ButterflySpriteLayout(
          anchorX: .22,
          anchorY: .42,
          size: 68,
          orbitX: 22,
          orbitY: 16,
          phase: 0,
          flip: false,
        ),
        ButterflySpriteLayout(
          anchorX: .76,
          anchorY: .37,
          size: 60,
          orbitX: 20,
          orbitY: 14,
          phase: 2.2,
          flip: true,
        ),
        ButterflySpriteLayout(
          anchorX: .63,
          anchorY: .62,
          size: 54,
          orbitX: 16,
          orbitY: 11,
          phase: 4.1,
          flip: false,
        ),
      ];

  static List<ButterflySpriteLayout> stillButterflies(String butterflyId) =>
      switch (butterflyId) {
        // Larger, more decorative premium butterflies need more breathing room
        // in the static wallpaper capture so all three remain clearly visible.
        'sakura_butterfly' => const [
            ButterflySpriteLayout(
              anchorX: .20,
              anchorY: .45,
              size: 62,
              phase: .35,
              flip: false,
            ),
            ButterflySpriteLayout(
              anchorX: .80,
              anchorY: .35,
              size: 58,
              phase: 2.45,
              flip: true,
            ),
            ButterflySpriteLayout(
              anchorX: .67,
              anchorY: .61,
              size: 50,
              phase: 4.55,
              flip: false,
            ),
          ],
        'amber_butterfly' => const [
            ButterflySpriteLayout(
              anchorX: .20,
              anchorY: .45,
              size: 62,
              phase: .35,
              flip: false,
            ),
            ButterflySpriteLayout(
              anchorX: .80,
              anchorY: .35,
              size: 58,
              phase: 2.45,
              flip: true,
            ),
            ButterflySpriteLayout(
              anchorX: .67,
              anchorY: .60,
              size: 50,
              phase: 4.55,
              flip: false,
            ),
          ],
        'cosmic_butterfly' => const [
            ButterflySpriteLayout(
              anchorX: .21,
              anchorY: .43,
              size: 64,
              phase: .2,
              flip: false,
            ),
            ButterflySpriteLayout(
              anchorX: .79,
              anchorY: .35,
              size: 58,
              phase: 2.35,
              flip: true,
            ),
            ButterflySpriteLayout(
              anchorX: .66,
              anchorY: .60,
              size: 52,
              phase: 4.3,
              flip: false,
            ),
          ],
        _ => const [
            ButterflySpriteLayout(
              anchorX: .22,
              anchorY: .42,
              size: 68,
              phase: 0,
              flip: false,
            ),
            ButterflySpriteLayout(
              anchorX: .76,
              anchorY: .37,
              size: 60,
              phase: 2.2,
              flip: true,
            ),
            ButterflySpriteLayout(
              anchorX: .63,
              anchorY: .62,
              size: 54,
              phase: 4.1,
              flip: false,
            ),
          ],
      };

  static double treeSize(Size scene) => math.min(scene.width * .74, scene.height * .72).clamp(88.0, 430.0).toDouble();

  /// Each theme has a calibrated planting marker, so no expensive/fragile
  /// image-recognition is needed on the phone. Both the tree and its effects
  /// resolve against the same local scene geometry.
  static double groundBottom(
    Size scene, {
    PlantingGround ground = PlantingGround.defaultGarden,
  }) {
    // Scene-space calibration: the visual root should meet the ground in both
    // standard and Focus modes. Values are fractions of the *tree scene*.
    final fraction = switch (ground) {
      PlantingGround.sakuraGarden => .14,
      PlantingGround.autumnGarden => .108,
      PlantingGround.moonlightGarden => .082,
      PlantingGround.auroraGarden => .12,
      PlantingGround.mushroomGarden => .09,
      PlantingGround.cloudGarden => .025,
      PlantingGround.coralGarden => .095,
      PlantingGround.desertGarden => .095,
      PlantingGround.fairyGarden => .10,
      PlantingGround.defaultGarden => .035,
    };
    return math.max(10.0, scene.height * fraction);
  }

  static double plantingPlaneHeight(Size scene) => math.max(24.0, treeSize(scene) * .15);

  /// The shadow plane is centered on the root target.
  static double plantingPlaneBottom(
    Size scene, {
    PlantingGround ground = PlantingGround.defaultGarden,
  }) =>
      groundBottom(scene, ground: ground) - treeSize(scene) * .045;

  /// A stable root/soil contact point that never changes during watering.
  static Offset rootTarget(
    Size scene, {
    PlantingGround ground = PlantingGround.defaultGarden,
  }) {
    final tree = treeSize(scene);
    return Offset(
      scene.width * .5,
      scene.height - groundBottom(scene, ground: ground) - tree * .03,
    );
  }

  static double treeVisualScale({PlantingGround ground = PlantingGround.defaultGarden}) =>
      ground == PlantingGround.sakuraGarden
          ? .92
          : ground == PlantingGround.autumnGarden
              ? .95
              : 1.0;

  static double treeBottomLift(
    double treeSize, {
    PlantingGround ground = PlantingGround.defaultGarden,
  }) =>
      ground == PlantingGround.sakuraGarden
          ? treeSize * .02
          : ground == PlantingGround.autumnGarden
              ? treeSize * .024
              : treeSize * .04;

  /// The rendered sprite bounds, shared by the live garden and editor outline.
  /// Placement remains relative to the live scene, even in a scaled preview.
  static Rect treeRect(
    Size scene, {
    PlantingGround ground = PlantingGround.defaultGarden,
    GardenTreePlacement placement = const GardenTreePlacement(),
  }) {
    final size = treeSize(scene) * treeVisualScale(ground: ground) * placement.scale;
    final bottom = groundBottom(scene, ground: ground) - treeBottomLift(size, ground: ground) - placement.dy * scene.height;
    return Rect.fromLTWH(
      (scene.width - size) / 2 + placement.dx * scene.width,
      scene.height - bottom - size,
      size,
      size,
    );
  }

  static double wateringCanSize(Size scene) => math.min(scene.width, scene.height) * .27;

  static Offset wateringCanCenter(Size scene, double progress) => Offset(
        scene.width * .77 + math.sin(progress * math.pi) * 10,
        scene.height * .23 + math.sin(progress * math.pi) * 6,
      );

  static double wateringCanAngle(double progress) => -.20 - .24 * math.sin(progress * math.pi);

  /// The nozzle is near the left-hand tip of the illustrated watering can.
  /// Apply the SAME rotation used on the can sprite.
  static Offset wateringSpout(Size scene, double progress, {Offset nozzle = const Offset(.06,.47)}) {
    final center = wateringCanCenter(scene, progress);
    final size = wateringCanSize(scene);
    final angle = wateringCanAngle(progress);
    final dx = size * (nozzle.dx - .5);
    final dy = size * (nozzle.dy - .5);
    return Offset(
      center.dx + dx * math.cos(angle) - dy * math.sin(angle),
      center.dy + dx * math.sin(angle) + dy * math.cos(angle),
    );
  }
}

class ButterflySpriteLayout {
  const ButterflySpriteLayout({
    required this.anchorX,
    required this.anchorY,
    required this.size,
    this.orbitX = 0,
    this.orbitY = 0,
    this.phase = 0,
    required this.flip,
  });

  final double anchorX;
  final double anchorY;
  final double size;
  final double orbitX;
  final double orbitY;
  final double phase;
  final bool flip;
}

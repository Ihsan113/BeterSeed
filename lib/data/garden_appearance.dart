import 'package:flutter/widgets.dart';
import '../logic/garden_scene_geometry.dart';
import '../widgets/garden_life_painter.dart';
import 'shop_loadout.dart';
import 'garden_pack_registry.dart';

class GardenAppearance {
  const GardenAppearance(this.loadout);
  final ShopLoadout loadout;
  static const stageFiles = [
    'seed',
    'sprout',
    'sapling',
    'young',
    'mature',
    'legendary'
  ];
  String treeAsset(int stage) => treeImages[stage.clamp(0, 5)];
  List<String> get treeImages =>
      GardenPackRegistry.forAsset('treeSkinId', loadout.treeSkinId).trees;
  LocalGardenPack get backgroundPack =>
      GardenPackRegistry.forAsset('backgroundId', loadout.backgroundId);
  String get background => backgroundPack.background;
  String? get video => backgroundPack.video;
  String get butterfly =>
      GardenPackRegistry.forAsset('butterflyId', loadout.butterflyId).butterfly;
  String get wateringCan =>
      GardenPackRegistry.forAsset('wateringCanId', loadout.wateringCanId)
          .wateringCan;
  Offset get spout => GardenPackRegistry.forAsset('wateringCanId', loadout.wateringCanId).spout;
  PlantingGround get ground => backgroundPack.ground;
  FireflyPalette get fireflies =>
      GardenPackRegistry.forAsset('fireflyId', loadout.fireflyId).fireflies;
}

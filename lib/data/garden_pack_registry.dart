import 'package:flutter/widgets.dart';
import 'shop_loadout.dart';
import '../logic/garden_scene_geometry.dart';
import '../widgets/garden_life_painter.dart';

/// APK-only asset registry. The server supplies commercial metadata, never paths.
class LocalGardenPack {
  const LocalGardenPack(
      {required this.id,
      required this.name,
      required this.loadout,
      required this.background,
      required this.treeFolder,
      required this.treeExtension,
      required this.butterfly,
      required this.wateringCan,
      this.video,
      this.thumbnail,
      this.ground = PlantingGround.defaultGarden,
      this.fireflies = FireflyPalette.warm,
      this.spout = const Offset(.06, .47)});
  final String id,
      name,
      background,
      treeFolder,
      treeExtension,
      butterfly,
      wateringCan;
  final String? video, thumbnail;
  final ShopLoadout loadout;
  final PlantingGround ground;
  final FireflyPalette fireflies;
  /// Normalized point at the spout lip on the square watering-can artwork.
  final Offset spout;
  List<String> get trees => [
        for (var i = 0; i < 6; i++)
          '$treeFolder/stage_${i}_${const [
            'seed',
            'sprout',
            'sapling',
            'young',
            'mature',
            'legendary'
          ][i]}.$treeExtension'
      ];
  List<String> get assets => [
        background,
        ...trees,
        butterfly,
        wateringCan,
        if (video != null) video!,
        if (thumbnail != null) thumbnail!
      ];
}

class GardenPackRegistry {
  static const appBuild = 58;
  static const packs = <LocalGardenPack>[
    LocalGardenPack(
        id: 'default',
        name: 'Original Garden',
        loadout: ShopLoadout.defaultPack,
        background: 'assets/images/backgrounds/enchanted_valley.webp',
        treeFolder: 'assets/images/trees',
        treeExtension: 'webp',
        butterfly: 'assets/images/effects/butterfly_realistic.png',
        wateringCan: 'assets/images/effects/watering_can_realistic.png',
        thumbnail: 'assets/images/shop/default_pack_thumb.webp'),
    LocalGardenPack(
        id: 'moonlight',
        name: 'Moonlight Night Pack',
        loadout: ShopLoadout.moonlightPack,
        background: 'assets/images/backgrounds/moonlight_premium.webp',
        treeFolder: 'assets/images/trees/skins/moonlight',
        treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_cosmic.png',
        wateringCan: 'assets/images/effects/watering_can_celestial.png',
        ground: PlantingGround.moonlightGarden,
        fireflies: FireflyPalette.prism,
        thumbnail: 'assets/images/shop/moonlight_pack_thumb.webp'),
    LocalGardenPack(
        id: 'sakura',
        name: 'Sakura Blossom Garden',
        loadout: ShopLoadout.sakuraPack,
        background: 'assets/images/backgrounds/sakura_garden.webp',
        treeFolder: 'assets/images/trees/skins/sakura',
        treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_sakura.png',
        wateringCan: 'assets/images/effects/watering_can_sakura.png',
        video: 'assets/videos/sakura_loop_5s.mp4',
        thumbnail: 'assets/images/shop/sakura_pack_thumbnail.webp',
        ground: PlantingGround.sakuraGarden,
        fireflies: FireflyPalette.sakura,
        spout: Offset(.14, .36)),
    LocalGardenPack(
        id: 'golden_autumn',
        name: 'Golden Autumn Garden',
        loadout: ShopLoadout.autumnPack,
        background: 'assets/images/backgrounds/golden_autumn_garden.webp',
        treeFolder: 'assets/images/trees/skins/golden_autumn',
        treeExtension: 'png',
        butterfly: 'assets/images/effects/amber_butterfly.png',
        wateringCan: 'assets/images/effects/maple_watering_can.png',
        video: 'assets/videos/autumn_garden_loopy_8s.mp4',
        thumbnail: 'assets/images/shop/golden_autumn_pack_thumb.webp',
        ground: PlantingGround.autumnGarden,
        fireflies: FireflyPalette.autumn,
        spout: Offset(.15, .35)),

    LocalGardenPack(
        id: 'aurora_crystal', name: 'Aurora Crystal Garden',
        loadout: const ShopLoadout(treeSkinId: 'aurora_crystal_tree', backgroundId: 'aurora_crystal_background', butterflyId: 'aurora_crystal_butterfly', wateringCanId: 'aurora_crystal_can', fireflyId: 'aurora_crystal_fireflies'),
        background: 'assets/images/backgrounds/aurora_crystal_garden.webp',
        treeFolder: 'assets/images/trees/skins/aurora_crystal', treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_aurora_crystal.png',
        wateringCan: 'assets/images/effects/watering_can_aurora_crystal.png',
        video: 'assets/videos/aurora_crystal_loop.mp4',
        thumbnail: 'assets/images/shop/aurora_crystal_pack_thumb.webp',
        ground: PlantingGround.auroraGarden, fireflies: FireflyPalette.prism,
        spout: Offset(.065,.43)),
    LocalGardenPack(
        id: 'enchanted_mushroom', name: 'Enchanted Mushroom Garden',
        loadout: const ShopLoadout(treeSkinId: 'enchanted_mushroom_tree', backgroundId: 'enchanted_mushroom_background', butterflyId: 'enchanted_mushroom_butterfly', wateringCanId: 'enchanted_mushroom_can', fireflyId: 'enchanted_mushroom_fireflies'),
        background: 'assets/images/backgrounds/enchanted_mushroom_garden.webp',
        treeFolder: 'assets/images/trees/skins/enchanted_mushroom', treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_enchanted_mushroom.png',
        wateringCan: 'assets/images/effects/watering_can_enchanted_mushroom.png',
        video: 'assets/videos/enchanted_mushroom_loop.mp4',
        thumbnail: 'assets/images/shop/enchanted_mushroom_pack_thumb.webp',
        ground: PlantingGround.mushroomGarden, fireflies: FireflyPalette.autumn,
        spout: Offset(.065,.33)),
    LocalGardenPack(
        id: 'celestial_cloud', name: 'Celestial Cloud Garden',
        loadout: const ShopLoadout(treeSkinId: 'celestial_cloud_tree', backgroundId: 'celestial_cloud_background', butterflyId: 'celestial_cloud_butterfly', wateringCanId: 'celestial_cloud_can', fireflyId: 'celestial_cloud_fireflies'),
        background: 'assets/images/backgrounds/celestial_cloud_garden.webp',
        treeFolder: 'assets/images/trees/skins/celestial_cloud', treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_celestial_cloud.png',
        wateringCan: 'assets/images/effects/watering_can_celestial_cloud.png',
        video: 'assets/videos/celestial_cloud_loop.mp4',
        thumbnail: 'assets/images/shop/celestial_cloud_pack_thumb.webp',
        ground: PlantingGround.cloudGarden, fireflies: FireflyPalette.prism,
        spout: Offset(.08,.43)),
    LocalGardenPack(
        id: 'ocean_coral', name: 'Ocean Coral Garden',
        loadout: const ShopLoadout(treeSkinId: 'ocean_coral_tree', backgroundId: 'ocean_coral_background', butterflyId: 'ocean_coral_butterfly', wateringCanId: 'ocean_coral_can', fireflyId: 'ocean_coral_fireflies'),
        background: 'assets/images/backgrounds/ocean_coral_garden.webp',
        treeFolder: 'assets/images/trees/skins/ocean_coral', treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_ocean_coral.png',
        wateringCan: 'assets/images/effects/watering_can_ocean_coral.png',
        video: 'assets/videos/ocean_coral_loop.mp4',
        thumbnail: 'assets/images/shop/ocean_coral_pack_thumb.webp',
        ground: PlantingGround.coralGarden, fireflies: FireflyPalette.prism,
        spout: Offset(.10,.43)),
    LocalGardenPack(
        id: 'desert_oasis', name: 'Desert Oasis Garden',
        loadout: const ShopLoadout(treeSkinId: 'desert_oasis_tree', backgroundId: 'desert_oasis_background', butterflyId: 'desert_oasis_butterfly', wateringCanId: 'desert_oasis_can', fireflyId: 'desert_oasis_fireflies'),
        background: 'assets/images/backgrounds/desert_oasis_garden.webp',
        treeFolder: 'assets/images/trees/skins/desert_oasis', treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_desert_oasis.png',
        wateringCan: 'assets/images/effects/watering_can_desert_oasis.png',
        video: 'assets/videos/desert_oasis_loop.mp4',
        thumbnail: 'assets/images/shop/desert_oasis_pack_thumb.webp',
        ground: PlantingGround.desertGarden, fireflies: FireflyPalette.autumn,
        spout: Offset(.06,.44)),
    LocalGardenPack(
        id: 'fairy_lantern', name: 'Fairy Lantern Garden',
        loadout: const ShopLoadout(treeSkinId: 'fairy_lantern_tree', backgroundId: 'fairy_lantern_background', butterflyId: 'fairy_lantern_butterfly', wateringCanId: 'fairy_lantern_can', fireflyId: 'fairy_lantern_fireflies'),
        background: 'assets/images/backgrounds/fairy_lantern_garden.webp',
        treeFolder: 'assets/images/trees/skins/fairy_lantern', treeExtension: 'png',
        butterfly: 'assets/images/effects/butterfly_fairy_lantern.png',
        wateringCan: 'assets/images/effects/watering_can_fairy_lantern.png',
        video: 'assets/videos/fairy_lantern_loop.mp4',
        thumbnail: 'assets/images/shop/fairy_lantern_pack_thumb.webp',
        ground: PlantingGround.fairyGarden, fireflies: FireflyPalette.sakura,
        spout: Offset(.12,.45)),
  ];
  static LocalGardenPack? find(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  static LocalGardenPack forAsset(String field, String id) {
    for (final p in packs) {
      if (p.loadout.toJson()[field] == id) return p;
    }
    return packs.first;
  }
}

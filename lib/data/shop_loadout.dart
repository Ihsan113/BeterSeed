import 'garden_pack_registry.dart';

/// Pack presets and independent Garden cosmetic combinations.
class ShopLoadout {
  const ShopLoadout({
    this.treeSkinId = 'default',
    this.backgroundId = 'default',
    this.butterflyId = 'default',
    this.wateringCanId = 'default',
    this.fireflyId = 'default',
  });
  final String treeSkinId;
  final String backgroundId;
  final String butterflyId;
  final String wateringCanId;
  final String fireflyId;

  static const defaultPack = ShopLoadout();
  static const moonlightPack = ShopLoadout(
    treeSkinId: 'moonlight_tree_skin',
    backgroundId: 'twilight_overlook',
    butterflyId: 'cosmic_butterfly',
    wateringCanId: 'celestial_watering_can',
    fireflyId: 'prism_fireflies',
  );

  static const sakuraPack = ShopLoadout(
    treeSkinId: 'sakura_tree_skin',
    backgroundId: 'sakura_garden',
    butterflyId: 'sakura_butterfly',
    wateringCanId: 'sakura_watering_can',
    fireflyId: 'sakura_fireflies',
  );

  static const autumnPack = ShopLoadout(
    treeSkinId: 'golden_autumn_tree_skin',
    backgroundId: 'golden_autumn_garden',
    butterflyId: 'amber_butterfly',
    wateringCanId: 'maple_watering_can',
    fireflyId: 'ember_fireflies',
  );

  static String? assetPackName(String id) {
    for (final p in GardenPackRegistry.packs) {
      if (p.loadout.toJson().values.contains(id)) return p.name;
    }
    return null;
  }

  ShopLoadout copyWith({
    String? treeSkinId,
    String? backgroundId,
    String? butterflyId,
    String? wateringCanId,
    String? fireflyId,
  }) =>
      ShopLoadout(
        treeSkinId: treeSkinId ?? this.treeSkinId,
        backgroundId: backgroundId ?? this.backgroundId,
        butterflyId: butterflyId ?? this.butterflyId,
        wateringCanId: wateringCanId ?? this.wateringCanId,
        fireflyId: fireflyId ?? this.fireflyId,
      );

  Map<String, String> toJson() => {
        'treeSkinId': treeSkinId,
        'backgroundId': backgroundId,
        'butterflyId': butterflyId,
        'wateringCanId': wateringCanId,
        'fireflyId': fireflyId,
      };

  static ShopLoadout fromMap(
    Map<String, dynamic> data, {
    bool moonlightOwned = false,
    bool sakuraOwned = false,
    bool autumnOwned = false,
    Set<String> ownedPacks = const {},
  }) {
    String permit(String key, Set<String> unlockedIds) {
      final value = data[key];
      if (value == null || value == 'default') return 'default';
      return GardenPackRegistry.packs.any((p) =>
              unlockedIds.contains(p.id) && p.loadout.toJson()[key] == value)
          ? value as String
          : 'default';
    }

    final owned = {
      'default',
      ...ownedPacks,
      if (moonlightOwned) 'moonlight',
      if (sakuraOwned) 'sakura',
      if (autumnOwned) 'golden_autumn'
    };

    return ShopLoadout(
      treeSkinId: permit('treeSkinId', owned),
      backgroundId: permit('backgroundId', owned),
      butterflyId: permit('butterflyId', owned),
      wateringCanId: permit('wateringCanId', owned),
      fireflyId: permit('fireflyId', owned),
    );
  }

  bool matches(ShopLoadout other) =>
      treeSkinId == other.treeSkinId &&
      backgroundId == other.backgroundId &&
      butterflyId == other.butterflyId &&
      wateringCanId == other.wateringCanId &&
      fireflyId == other.fireflyId;

  bool get isMixed => !GardenPackRegistry.packs.any((p) => matches(p.loadout));
  String get packId => GardenPackRegistry.forAsset('treeSkinId', treeSkinId).id;
}

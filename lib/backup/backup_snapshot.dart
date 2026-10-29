import '../data/shop_loadout.dart';
import '../data/garden_pack_registry.dart';
import 'dart:convert';

import '../data/habit.dart';
import '../logic/water_progress.dart';

/// Portable BetterSeed data. Audio and Android permissions are device-local.
/// Backups never enable notifications or purchase entitlements on another device.
class BackupSnapshot {
  const BackupSnapshot({
    required this.habits,
    required this.progress,
    required this.day,
    required this.packId,
    required this.ownedMoonlight,
    this.ownedSakura = false,
    this.ownedAutumn = false,
    this.cosmetics = const {},
    this.treePlacements = const {},
    required this.savedAtUtc,
  });

  static const version = 1;
  final List<Habit> habits;
  final WaterProgress progress;
  final String day;
  final String packId;
  final bool ownedMoonlight;
  final bool ownedSakura;
  final bool ownedAutumn;
  final Map<String, dynamic> cosmetics;
  final Map<String, dynamic> treePlacements;
  final DateTime savedAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': 'betterseed.backup',
        'version': version,
        'savedAtUtc': savedAtUtc.toUtc().toIso8601String(),
        'data': <String, dynamic>{
          'habits': habits.map((h) => h.toJson()).toList(),
          'progress': progress.toJson(),
          'day': day,
          'packId': packId,
          'ownedMoonlight': ownedMoonlight,
          'ownedSakura': ownedSakura,
          'ownedAutumn': ownedAutumn,
          'cosmetics': cosmetics,
          'treePlacements': treePlacements,
        },
      };

  /// Backup ownership flags are legacy hints, never proof of a purchase.
  ShopLoadout loadoutFor(Set<String> verifiedPacks) => cosmetics.isNotEmpty
      ? ShopLoadout.fromMap(cosmetics, ownedPacks: verifiedPacks)
      : verifiedPacks.contains(packId)
          ? GardenPackRegistry.find(packId)?.loadout ?? ShopLoadout.defaultPack
          : ShopLoadout.defaultPack;

  String encode() => jsonEncode(toJson());

  factory BackupSnapshot.decode(String source) {
    if (source.length > 4 * 1024 * 1024) {
      throw const FormatException('Backup exceeds the supported 4 MB limit');
    }
    final decoded = jsonDecode(source);
    if (decoded is! Map)
      throw const FormatException('Invalid backup structure');
    final json = Map<String, dynamic>.from(decoded);
    if (json['format'] != 'betterseed.backup' || json['version'] != version) {
      throw const FormatException('Unsupported BetterSeed backup version');
    }
    final savedAt = DateTime.tryParse(json['savedAtUtc'] as String? ?? '');
    if (savedAt == null) throw const FormatException('Backup date is invalid');
    if (json['data'] is! Map)
      throw const FormatException('Backup data is missing');
    final data = Map<String, dynamic>.from(json['data'] as Map);
    if (data['habits'] is! List || data['progress'] is! Map) {
      throw const FormatException('Backup habits or progress are invalid');
    }
    final rawHabits = data['habits'] as List;
    if (rawHabits.length > 2000)
      throw const FormatException('Too many habits in backup');
    final habits = <Habit>[];
    final ids = <String>{};
    for (final raw in rawHabits) {
      if (raw is! Map) throw const FormatException('Invalid habit entry');
      final habit = Habit.fromJson(Map<String, dynamic>.from(raw));
      if (habit.id.isEmpty ||
          habit.title.trim().isEmpty ||
          !ids.add(habit.id)) {
        throw const FormatException('Duplicate or invalid habit');
      }
      habits.add(habit);
    }
    final day = data['day'] as String? ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) {
      throw const FormatException('Invalid backup day');
    }
    final rawPack = data['packId'];
    final pack =
        rawPack is String && RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(rawPack)
            ? rawPack
            : 'default';
    final ownedMoonlight =
        data['ownedMoonlight'] == true || pack == 'moonlight';
    final ownedSakura = data['ownedSakura'] == true || pack == 'sakura';
    final ownedAutumn = data['ownedAutumn'] == true || pack == 'golden_autumn';
    return BackupSnapshot(
      habits: habits,
      progress: WaterProgress.fromJson(
          Map<String, dynamic>.from(data['progress'] as Map)),
      day: day,
      packId: pack,
      ownedMoonlight: ownedMoonlight,
      ownedSakura: ownedSakura,
      ownedAutumn: ownedAutumn,
      cosmetics: data['cosmetics'] is Map
          ? Map<String, dynamic>.from(data['cosmetics'] as Map)
          : const {},
      treePlacements: data['treePlacements'] is Map
          ? Map<String, dynamic>.from(data['treePlacements'] as Map)
          : const {},
      savedAtUtc: savedAt.toUtc(),
    );
  }
}

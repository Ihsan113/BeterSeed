import 'garden_test_helpers.dart';
import 'dart:convert';

import 'package:betterseed/audio/local_music_files.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/growth.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/main.dart';
import 'package:betterseed/widgets/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resetting plant growth preserves the complete water ledger', () {
    final p = WaterProgress(
      totalEarned: 8,
      totalSpent: 5,
      xp: 185,
      credited: {'2026-10-25': {'read', 'walk'}},
    );
    final before = p.toJson();
    p.resetTreeGrowth();
    expect(p.xp, 0);
    expect(p.treeStage, 0);
    expect(p.totalEarned, 8);
    expect(p.totalSpent, 5);
    expect(p.waterBalance, 3);
    expect(p.earnedOn('2026-10-25'), 2);
    expect(p.wasCredited('2026-10-25', 'read'), isTrue);
    expect(p.toJson()['credited'], before['credited']);
    final recovered = WaterProgress.fromJson(p.toJson());
    expect(recovered.xp, 0);
    expect(recovered.waterBalance, 3);
    expect(recovered.wasCredited('2026-10-25', 'read'), isTrue);
  });

  test('built-in Garden asset choices support independent combinations', () {
    final mix = ShopLoadout.defaultPack.copyWith(
      backgroundId: 'sakura_garden',
      wateringCanId: 'celestial_watering_can',
      butterflyId: 'sakura_butterfly',
      fireflyId: 'prism_fireflies',
    );
    expect(mix.isMixed, isTrue);
    expect(mix.treeSkinId, 'default');
    expect(mix.backgroundId, 'sakura_garden');
    expect(mix.wateringCanId, 'celestial_watering_can');
    expect(mix.butterflyId, 'sakura_butterfly');
    expect(mix.fireflyId, 'prism_fireflies');
    final loaded = ShopLoadout.fromMap(mix.toJson(),
      moonlightOwned: true, sakuraOwned: true);
    expect(loaded.toJson(), mix.toJson());
    expect(ShopLoadout.moonlightPack.isMixed, isFalse);
    expect(ShopLoadout.sakuraPack.isMixed, isFalse);
    expect(ShopLoadout.autumnPack.isMixed, isFalse);
  });

  test('SAF music adapter handles installed MP3, imported MP3 and cancel', () async {
    const channel = MethodChannel('betterseed/music_files');
    var cancel = false;
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      if (call.method == 'getImportedMp3') {
        return {'path': '/private/custom_background.mp3', 'name': 'My song.mp3'};
      }
      if (call.method == 'pickMp3') {
        return cancel ? null : {'path': '/private/custom_background.mp3', 'name': 'New music.mp3'};
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final installed = await LocalMusicFiles.installedMp3();
    expect(installed?.name, 'My song.mp3');
    expect(installed?.path, '/private/custom_background.mp3');
    expect((await LocalMusicFiles.importMp3())?.name, 'New music.mp3');
    cancel = true;
    expect(await LocalMusicFiles.importMp3(), isNull);
    expect(methods, ['getImportedMp3', 'pickMp3', 'pickMp3']);
  });

  testWidgets('Settings resets only tree XP, not checked habits or water', (tester) async {
    final day = todayLocalKey();
    final progress = WaterProgress(
      totalEarned: 6,
      totalSpent: 3,
      xp: 130,
      credited: {day: {'read'}},
    );
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      'betterseed_day_v1': day,
      'betterseed_water_progress_v3': jsonEncode(progress.toJson()),
      'betterseed_habits_v1': jsonEncode([
        (const Habit(id: 'read', title: 'Read', completed: true)).toJson(),
      ]),
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    final menu = find.byKey(const ValueKey('settings-menu-growth'));
    await tester.ensureVisible(menu);
    await tester.pump();
    await tester.tap(menu);
    await tester.pump();
    expect(find.byKey(const ValueKey('settings-reset-tree')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-reset-tree')));
    await tester.pump();
    expect(find.text('Reset plant growth?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-reset-tree')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    final after = WaterProgress.fromJson(
      Map<String, dynamic>.from(jsonDecode(
          prefs.getString('betterseed_water_progress_v3')!) as Map));
    expect(after.xp, 0);
    expect(after.totalEarned, 6);
    expect(after.totalSpent, 3);
    expect(after.waterBalance, 3);
    final habits = jsonDecode(prefs.getString('betterseed_habits_v1')!) as List;
    expect(habits.single['completed'], isTrue);
    expect(after.wasCredited(day, 'read'), isTrue);
    expect(tester.takeException(), isNull);
  });
}

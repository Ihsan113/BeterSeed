import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:betterseed/main.dart';
import 'package:betterseed/data/garden_pack_registry.dart';
import 'package:betterseed/data/pack_downloads.dart';
import 'package:betterseed/widgets/shop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'garden_test_helpers.dart';

class TestPaths extends PathProviderPlatform {
  TestPaths(this.directory, {this.ready});
  final Directory directory;
  final Completer<void>? ready;
  @override
  Future<String?> getApplicationSupportPath() async {
    await ready?.future;
    return directory.path;
  }
}

void installFixture(Directory support, String id) {
  final pack = GardenPackRegistry.find(id)!;
  final bytes = File('assets/images/trees/stage_0_seed.webp').readAsBytesSync();
  final dir = Directory('${support.path}/garden_packs/$id');
  for (final path
      in pack.assets.where((p) => !p.startsWith('assets/images/shop/'))) {
    final file = File('${dir.path}/$path');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }
  final data =
      (jsonDecode(File('assets/pack_downloads.json').readAsStringSync())
          as Map)['packs'][id];
  File('${dir.path}/installed.json').writeAsStringSync(
      jsonEncode({'revision': data['revision'], 'sha256': data['sha256']}));
}

Future<void> finishStorageWork(WidgetTester tester, Future<void> work) async {
  var done = false;
  final observed = work.then((_) => done = true);
  for (var i = 0; i < 150 && !done; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  expect(done, true, reason: 'Filesystem operation did not finish');
  await observed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('betterseed/device_features');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final temporaryDirectories = <Directory>[];
  tearDownAll(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (final directory in temporaryDirectories)
      if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  late Directory support;
  late PathProviderPlatform originalPaths;
  setUp(() {
    rootBundle.clear();
    support = Directory.systemTemp.createTempSync('betterseed-cdn-widget-');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = TestPaths(support);
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => 1);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      if (call.method == 'create') {
        messenger.setMockMethodCallHandler(
            MethodChannel(
                'xyz.luan/audioplayers/events/${(call.arguments as Map)['playerId']}'),
            (_) async => null);
      }
      return 1;
    });
  });
  tearDown(() {
    PathProviderPlatform.instance = originalPaths;
    messenger.setMockMethodCallHandler(channel, null);
    for (final pack in GardenPackRegistry.packs)
      GardenPackFiles.setRoot(pack.id, null);
    // Files are cleaned after all pending image decodes finish below.
    temporaryDirectories.add(support);
  });

  testWidgets(
      'late CDN scan refreshes widget with saved tree and growth stage, then removal clears the file',
      (tester) async {
    installFixture(support, 'sakura');
    final scanReady = Completer<void>();
    PathProviderPlatform.instance = TestPaths(support, ready: scanReady);
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      'betterseed_owned_sakura_v1': true,
      'betterseed_active_bundle_v1': 'sakura',
      'betterseed_xp_v1': 100,
    });
    final snapshots = <Map<dynamic, dynamic>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'updateWidget')
        snapshots.add(Map<dynamic, dynamic>.from(call.arguments as Map));
      return null;
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await pumpGardenTransition(tester);
    for (var i = 0; i < 80 && snapshots.isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(snapshots, isNotEmpty);
    expect(snapshots.last['theme'], 'default');
    expect(snapshots.last['stage'], 4);
    scanReady.complete();
    for (var i = 0; i < 80 && snapshots.last['theme'] != 'sakura'; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    final tree = GardenPackRegistry.find('sakura')!.trees[3];
    expect(snapshots.last['theme'], 'sakura');
    expect(snapshots.last['stage'], 4);
    expect(snapshots.last['treeAsset'], tree);
    expect(snapshots.last['treeFile'],
        '${support.path}/garden_packs/sakura/$tree');
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    final shop = tester.widget<BetterSeedShopPage>(
        find.byType(BetterSeedShopPage, skipOffstage: false));
    await finishStorageWork(
        tester, shop.downloads!.remove('sakura').then((_) {}));
    await pumpGardenTransition(tester);
    expect(snapshots.last['theme'], 'default');
    expect(snapshots.last['stage'], 4);
    expect(snapshots.last.containsKey('treeFile'), false);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('betterseed_owned_sakura_v1'),
        true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (var stage = 0; stage < 6; stage++) {
    testWidgets(
        'mixed garden widget uses the selected tree at growth stage ${stage + 1}',
        (tester) async {
      installFixture(support, 'sakura');
      installFixture(support, 'moonlight');
      SharedPreferences.setMockInitialValues({
        'betterseed_music_v2': false,
        'betterseed_sfx_v2': false,
        'betterseed_motion_v2': false,
        'betterseed_owned_sakura_v1': true,
        'betterseed_owned_moonlight_v1': true,
        'betterseed_active_bundle_v1': 'sakura',
        'betterseed_tree_skin_v1': 'moonlight_tree_skin',
        'betterseed_xp_v1': [0, 20, 50, 100, 180, 300][stage],
      });
      Map<dynamic, dynamic>? snapshot;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'updateWidget')
          snapshot = Map<dynamic, dynamic>.from(call.arguments as Map);
        return null;
      });
      await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
      await waitForGardenReady(tester);
      for (var i = 0; i < 100 && snapshot?['theme'] != 'moonlight'; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      final path = GardenPackRegistry.find('moonlight')!.trees[stage];
      expect(snapshot?['stage'], stage + 1);
      expect(snapshot?['theme'], 'moonlight');
      expect(snapshot?['treeAsset'], path);
      expect(snapshot?['treeFile'],
          '${support.path}/garden_packs/moonlight/$path');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets(
      'remove download requires confirmation, cancel keeps files and confirm keeps ownership',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    installFixture(support, 'moonlight');
    final downloads = PackDownloadService();
    await finishStorageWork(tester, downloads.initialize());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: BetterSeedShopPage(
                downloads: downloads, ownedPacks: const {'moonlight'}))));
    final remove = find.byKey(const ValueKey('shop-remove-moonlight'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(downloads.installed('moonlight'), true);
    await tester.tap(find.byKey(const ValueKey('pack-remove-cancel')));
    await tester.pumpAndSettle();
    expect(downloads.installed('moonlight'), true);
    expect(
        Directory('${support.path}/garden_packs/moonlight').existsSync(), true);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pack-remove-confirm')));
    for (var i = 0; i < 80 && downloads.installed('moonlight'); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(downloads.installed('moonlight'), false);
    expect(Directory('${support.path}/garden_packs/moonlight').existsSync(),
        false);
    expect(
        tester
            .widget<BetterSeedShopPage>(find.byType(BetterSeedShopPage))
            .ownedPacks,
        contains('moonlight'));
    expect(find.textContaining('You still own this pack'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    downloads.dispose();
  });
}

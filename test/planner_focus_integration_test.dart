import 'dart:async';
import 'dart:convert';
import 'package:betterseed/main.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/habit_manager_page.dart';
import 'package:betterseed/checklist/checklist_page.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/data/garden_appearance.dart';
import 'package:betterseed/data/garden_pack_registry.dart';
import 'package:betterseed/focus/focus_hud.dart';
import 'package:betterseed/focus/focus_session.dart';
import 'package:betterseed/statistics/statistics_page.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/widgets/local_pack_video_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'garden_test_helpers.dart';
import 'package:betterseed/widgets/garden_life_painter.dart';

class CountingVideo extends VideoPlayerPlatform {
  int created = 0, disposed = 0, playing = 0, paused = 0;
  final Map<int, StreamController<VideoEvent>> events = {};
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = ++created;
    events[id] = StreamController<VideoEvent>();
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int id) {
    scheduleMicrotask(() => events[id]!.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 5),
        size: const Size(400, 800))));
    return events[id]!.stream;
  }

  @override
  Future<void> dispose(int id) async {
    disposed++;
    await events.remove(id)?.close();
  }

  @override
  Future<void> play(int id) async {
    playing++;
  }

  @override
  Future<void> pause(int id) async {
    paused++;
  }

  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {
    if (value != 0) throw StateError('Garden video must remain muted');
  }

  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> seekTo(int id, Duration value) async {}
  @override
  Future<Duration> getPosition(int id) async => Duration.zero;
  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<void> setAllowBackgroundPlayback(bool value) async {}
  @override
  Widget buildView(int id) => const ColoredBox(color: Colors.green);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  var audioPlayers = 0;
  final systemModes = <Object?>[];
  setUp(() {
    audioPlayers = 0;
    systemModes.clear();
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events'
    ])
      messenger.setMockMethodCallHandler(
          MethodChannel(name), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      if (call.method == 'create') {
        audioPlayers++;
        final id = (call.arguments as Map)['playerId'];
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setEnabledSystemUIMode')
        systemModes.add(call.arguments);
      return null;
    });
  });
  tearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

  testWidgets(
      'global management persists archive/restore and leaves earned water unchanged',
      (tester) async {
    final now = DateTime.now(), day = checklistDay(DateTime.now());
    var data = ChecklistData(
        start: day,
        plan:
            const HabitPlan(type: 'duration', target: 10, activityMinute: 420));
    data =
        data.record(now, data.today(now).change(value: 10, focusSeconds: 600));
    final water = WaterProgress()..earnForHabit(day, 'read');
    SharedPreferences.setMockInitialValues({
      'betterseed_motion_v2': false,
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_day_v1': day,
      'betterseed_habits_v1': jsonEncode(
          [Habit(id: 'read', title: 'Read', checklist: data).toJson()]),
      'betterseed_water_progress_v3': jsonEncode(water.toJson()),
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('manage-habits')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('manage-habits')));
    await tester.pumpAndSettle();
    expect(find.byType(HabitManagerPage), findsOneWidget);
    Future<void> apply(String label) async {
      await tester
          .ensureVisible(find.byKey(const ValueKey('library-actions-read')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-actions-read')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pump(const Duration(milliseconds: 450));
      for (var i = 0;
          i < 80 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
    }

    await apply('Archive habits');
    final prefs = await SharedPreferences.getInstance();
    Habit stored() => Habit.fromJson(
        (jsonDecode(prefs.getString('betterseed_habits_v1')!) as List).single);
    expect(stored().checklist!.archived, true);
    expect(find.text('0 active · 1 archived'), findsOneWidget);
    await apply('Restore habits');
    expect(stored().checklist!.archived, false);
    expect(stored().checklist!.today(now).durationSeconds, 600);
    expect(jsonDecode(prefs.getString('betterseed_water_progress_v3')!),
        water.toJson());
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Read'), 120,
        scrollable: find
            .descendant(
                of: find.byType(ChecklistPage),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Read'), 120,
        scrollable: find
            .descendant(
                of: find.byType(ChecklistPage),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);
    expect(stored().checklist!.today(now).done, true);
    expect(jsonDecode(prefs.getString('betterseed_water_progress_v3')!),
        water.toJson());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets(
      'habit focus shares Garden geometry, preserves audio and restores system UI',
      (tester) async {
    final now = DateTime.now(), day = checklistDay(DateTime.now());
    final data = ChecklistData(
            start: day, plan: const HabitPlan(type: 'duration', target: 2))
        .advance(now);
    SharedPreferences.setMockInitialValues({
      'betterseed_motion_v2': false,
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_day_v1': day,
      'betterseed_habits_v1':
          jsonEncode([Habit(id: 'h', title: 'Read', checklist: data).toJson()])
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.tap(find.byKey(const ValueKey('enter-focus-mode')));
    await pumpGardenTransition(tester);
    final geometry =
        tester.getRect(find.byKey(const ValueKey('editor-draggable-tree')));
    await tester.tap(find.byKey(const ValueKey('exit-focus-mode')));
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpGardenTransition(tester);
    final players = audioPlayers;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('focus-h')), 120,
        scrollable: find
            .descendant(
                of: find.byType(ChecklistPage),
                matching: find.byType(Scrollable))
            .first);
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('focus-h')));
    await pumpGardenTransition(tester);
    expect(find.byType(FocusHud), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-1')), findsNothing);
    expect(tester.getRect(find.byKey(const ValueKey('editor-draggable-tree'))),
        geometry);
    expect(find.byKey(const ValueKey('garden-live-ambient')), findsNothing);
    expect(audioPlayers, players);
    await tester.tap(find.byKey(const ValueKey('focus-toggle')));
    await tester.pump();
    final session = tester.widget<FocusHud>(find.byType(FocusHud)).session;
    expect(session.running, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(session.running, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(session.running, false);
    await tester.tap(find.byKey(const ValueKey('exit-habit-focus')));
    await pumpGardenTransition(tester);
    expect(find.byKey(const ValueKey('tab-1')), findsOneWidget);
    expect(systemModes.toString(), contains('SystemUiMode.edgeToEdge'));
    expect(tester.takeException(), isNull);
  });

  for (final settings in [
    (true, false, false),
    (true, true, true),
    (true, false, true),
    (false, true, false)
  ]) {
    testWidgets(
        'focus follows Garden motion/override/reduced settings $settings',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: settings.$3);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final now = DateTime.now(), day = checklistDay(DateTime.now());
      final data = ChecklistData(
              start: day, plan: const HabitPlan(type: 'duration', target: 2))
          .advance(now);
      SharedPreferences.setMockInitialValues({
        'betterseed_motion_v2': settings.$1,
        'betterseed_game_motion_override_v1': settings.$2,
        'betterseed_music_v2': false,
        'betterseed_sfx_v2': false,
        'betterseed_day_v1': day,
        'betterseed_habits_v1': jsonEncode(
            [Habit(id: 'h', title: 'Read', checklist: data).toJson()])
      });
      await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
      await waitForGardenReady(tester);
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await pumpGardenTransition(tester);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('focus-h')), 120,
          scrollable: find
              .descendant(
                  of: find.byType(ChecklistPage),
                  matching: find.byType(Scrollable))
              .first);
      await pumpGardenTransition(tester);
      await tester.tap(find.byKey(const ValueKey('focus-h')));
      await pumpGardenTransition(tester);
      final animated = settings.$1 && (!settings.$3 || settings.$2);
      final ambient = find.byKey(const ValueKey('garden-live-ambient'));
      if (animated) {
        expect(ambient, findsOneWidget);
        expect(
            find.byKey(const ValueKey('garden-butterfly-0')), findsOneWidget);
        final before =
            (tester.widget<CustomPaint>(ambient).painter as GardenLifePainter)
                .progress;
        await tester.pump(const Duration(seconds: 1));
        final after =
            (tester.widget<CustomPaint>(ambient).painter as GardenLifePainter)
                .progress;
        expect(after, isNot(before));
      } else {
        expect(ambient, findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets(
      'real edit clears obsolete timer, saves new goal and survives app restart',
      (tester) async {
    final now = DateTime.now(), day = checklistDay(DateTime.now());
    final data = ChecklistData(
            start: day, plan: const HabitPlan(type: 'duration', target: 2))
        .advance(now);
    SharedPreferences.setMockInitialValues({
      'betterseed_motion_v2': false,
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_day_v1': day,
      'betterseed_habits_v1':
          jsonEncode([Habit(id: 'h', title: 'Read', checklist: data).toJson()])
    });
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FocusSessionStore('guest');
    final oldSession = FocusSession(
        habitId: 'h',
        day: day,
        targetMinutes: 2,
        baseSeconds: 0,
        elapsedMilliseconds: 30000);
    await store.save(oldSession);
    oldSession.dispose();
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpGardenTransition(tester);
    await tester.scrollUntilVisible(find.text('Read'), 120,
        scrollable: find
            .descendant(
                of: find.byType(ChecklistPage),
                matching: find.byType(Scrollable))
            .first);
    await pumpGardenTransition(tester);
    await tester.tap(find.text('Read'));
    await pumpGardenTransition(tester);
    await tester.tap(find.byTooltip('Edit habit'));
    await pumpGardenTransition(tester);
    expect(find.byType(HabitEditor), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('goal-type-count')));
    await pumpGardenTransition(tester);
    await tester.tap(find.text('Save habit'));
    await pumpGardenTransition(tester);
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 80; i++) {
      final raw = jsonDecode(prefs.getString('betterseed_habits_v1')!) as List;
      if (Habit.fromJson(raw.single).checklist!.today(now).plan.type == 'count')
        break;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(await store.read('h'), isNull);
    final saved = Habit.fromJson(
        (jsonDecode(prefs.getString('betterseed_habits_v1')!) as List).single);
    expect(saved.checklist!.today(now).plan.type, 'count');
    expect(saved.checklist!.today(now).value, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpGardenTransition(tester);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('increment-h')), 120,
        scrollable: find
            .descendant(
                of: find.byType(ChecklistPage),
                matching: find.byType(Scrollable))
            .first);
    expect(find.byKey(const ValueKey('increment-h')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-h')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('partial focus saves real seconds and retry cannot double water',
      (tester) async {
    final now = DateTime.now(), day = checklistDay(DateTime.now());
    final data = ChecklistData(
            start: day, plan: const HabitPlan(type: 'duration', target: 2))
        .advance(now);
    SharedPreferences.setMockInitialValues({
      'betterseed_motion_v2': false,
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_day_v1': day,
      'betterseed_habits_v1':
          jsonEncode([Habit(id: 'h', title: 'Read', checklist: data).toJson()])
    });
    final store = FocusSessionStore('guest');
    Future<void> checkpoint(int seconds) async {
      final s = FocusSession(
          habitId: 'h',
          day: day,
          targetMinutes: 2,
          baseSeconds: 0,
          elapsedMilliseconds: seconds * 1000);
      await store.save(s);
      s.dispose();
    }

    await checkpoint(90);
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await pumpGardenTransition(tester);
    for (final seconds in [90, 120, 120]) {
      if (seconds != 90) await checkpoint(seconds);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('focus-h')), 120,
          scrollable: find
              .descendant(
                  of: find.byType(ChecklistPage),
                  matching: find.byType(Scrollable))
              .first);
      await pumpGardenTransition(tester);
      await tester.tap(find.byKey(const ValueKey('focus-h')));
      await pumpGardenTransition(tester);
      expect(tester.widget<FocusHud>(find.byType(FocusHud)).session.running,
          false);
      expect(
          tester.widget<FocusHud>(find.byType(FocusHud)).session.elapsedSeconds,
          seconds);
      await tester.tap(find.byKey(const ValueKey('focus-finish')));
      for (var i = 0;
          i < 60 && find.byType(FocusHud).evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (i % 8 == 0)
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(find.byType(FocusHud), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      final saved = Habit.fromJson(
          (jsonDecode(prefs.getString('betterseed_habits_v1')!) as List)
              .single);
      expect(saved.checklist!.today(now).durationSeconds, seconds);
      expect(saved.completed, seconds >= 120);
      final progress = WaterProgress.fromJson(
          jsonDecode(prefs.getString('betterseed_water_progress_v3')!));
      expect(progress.totalEarned, seconds >= 120 ? 1 : 0);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('one video controller survives HUD ticks and respects Motion OFF',
      (tester) async {
    final previous = VideoPlayerPlatform.instance;
    final video = CountingVideo();
    VideoPlayerPlatform.instance = video;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    var ms = 0;
    final session = FocusSession(
        habitId: 'h',
        day: checklistDay(DateTime.now()),
        targetMinutes: 15,
        baseSeconds: 0,
        monotonicMilliseconds: () => ms);
    Future<void> mount(bool motion) => tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Stack(children: [
          LocalPackVideoBackground(
              video: 'assets/videos/test.mp4',
              poster: 'assets/images/backgrounds/enchanted_valley.webp',
              animate: motion),
          FocusHud(
              session: session,
              title: 'Read',
              motion: motion,
              onCheckpoint: () async {},
              onFinish: () async {},
              onExit: () async {},
              onTarget: () {}),
        ]))));
    await mount(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(video.created, 1);
    session.start();
    for (var i = 0; i < 10; i++) {
      ms += 1000;
      await tester.pump(const Duration(seconds: 1));
    }
    expect(video.created, 1);
    expect(session.elapsedSeconds, 10);
    await mount(false);
    await tester.pump();
    expect(video.created, 1);
    expect(video.paused, greaterThan(0));
    expect(
        find.byKey(const ValueKey('local-pack-video-poster')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    session.dispose();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(video.disposed, 1);
    expect(tester.takeException(), isNull);
  });

  test('every registered Garden Pack uses its own existing scene assets', () {
    for (final pack in GardenPackRegistry.packs) {
      final look = GardenAppearance(pack.loadout);
      expect(look.treeImages, pack.trees);
      expect(look.background, isNotEmpty);
      expect(look.treeImages.length, 6);
    }
  });

  testWidgets('focus minimal HUD and confirmed reset fit 320 dp at 200%',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = FocusSession(
        habitId: 'h',
        day: checklistDay(DateTime.now()),
        targetMinutes: 15,
        baseSeconds: 60,
        elapsedMilliseconds: 90000);
    var checkpoints = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: FocusHud(
                session: session,
                title: 'A peaceful moment in my own garden',
                motion: false,
                onCheckpoint: () async {
                  checkpoints++;
                },
                onFinish: () async {},
                onExit: () async {},
                onTarget: () {}))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('toggle-focus-hud')));
    await tester.pump();
    expect(find.byKey(const ValueKey('focus-toggle')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-focus-hud')));
    await tester.pump();
    await tester.ensureVisible(find.byTooltip('Reset'));
    await tester.tap(find.byTooltip('Reset'));
    await tester.pumpAndSettle();
    expect(session.elapsedSeconds, 90);
    await tester.ensureVisible(find.text('Reset').last);
    await tester.tap(find.text('Reset').last);
    await tester.pumpAndSettle();
    expect(session.elapsedSeconds, 0);
    expect(session.totalSeconds, 60);
    expect(checkpoints, greaterThanOrEqualTo(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('statistics sections fit 320 dp and 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    var d = ChecklistData(start: checklistDay(now));
    d = d.record(now, d.today(now).change(value: 1));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: StatisticsPage(habits: [
          Habit(id: 'h', title: 'A long habit for accessibility', checklist: d)
        ], progress: WaterProgress(), tree: const Icon(Icons.park)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final section in [1, 2]) {
      await tester
          .ensureVisible(find.byKey(ValueKey('stats-section-$section')));
      await tester.tap(find.byKey(ValueKey('stats-section-$section')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}

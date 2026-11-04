import 'dart:async';
import 'dart:ui' as ui;
import 'package:betterseed/l10n/app_localizations.dart';
import 'package:betterseed/platform/garden_wallpaper.dart';
import 'package:betterseed/widgets/garden_wallpaper_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = GardenWallpaper.channel;
  setUp(() => rootBundle.clear());
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> launch(WidgetTester tester,
      {Locale locale = const Locale('en', 'US'), double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.locales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!),
      home: const GardenWallpaperPage(
        viewport: Size(180, 320),
        mediaQuery: MediaQueryData(size: Size(180, 320), devicePixelRatio: 2),
        assets: [],
        garden: ColoredBox(color: Colors.blue),
        liveGarden: ColoredBox(color: Colors.green),
        liveButterfly: 'assets/images/effects/butterfly_realistic.png',
      ),
    ));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
      final button = find.byKey(const ValueKey('wallpaper-apply'));
      if (button.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(button).onPressed != null) return;
    }
    fail('Wallpaper did not finish loading');
  }

  test('Live capability is opt-in and cancellation is not reported as applied',
      () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'capabilities')
        return {'supported': true, 'allowed': true};
      expect(call.method, 'previewLiveWallpaper');
      expect((call.arguments as Map).keys.toSet(),
          {'png', 'butterfly', 'glow', 'spark', 'core'});
      return false;
    });
    expect((await GardenWallpaper.capabilities()).live, isFalse);
    expect(
        await GardenWallpaper.previewLive(
            Uint8List.fromList([1]), Uint8List.fromList([2]),
            glow: 0xFFFFE39A, spark: 0xFFF8EDAC, core: 0xFFFFFFFF),
        isFalse);
    await expectLater(
        GardenWallpaper.previewLive(Uint8List(0), Uint8List(0),
            glow: 0, spark: 0, core: 0),
        throwsA(isA<PlatformException>()));
  });

  for (final applied in [false, true]) {
    testWidgets(
        'Live snapshot excludes animated overlays and awaits Android: $applied',
        (tester) async {
      final received = Completer<Map<dynamic, dynamic>>();
      final finish = Completer<bool>();
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'capabilities')
          return {
            'supported': true,
            'allowed': true,
            'lockScreen': true,
            'live': true
          };
        expect(call.method, 'previewLiveWallpaper');
        calls++;
        received.complete(call.arguments as Map);
        return finish.future;
      });
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('wallpaper-mode-live')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('wallpaper-target-home')), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('wallpaper-apply')));
        await tester.pump();
      });
      for (var i = 0; i < 100 && !received.isCompleted; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      expect(received.isCompleted, isTrue);
      final args = await received.future;
      final png = args['png'] as Uint8List;
      expect(ByteData.sublistView(png).getUint32(16), 360);
      expect(ByteData.sublistView(png).getUint32(20), 640);
      // Every pixel of the saved base is green: no static butterflies,
      // preview animation, app chrome or buttons were baked into the wallpaper.
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        final rgba =
            (await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        for (var i = 0; i < rgba.lengthInBytes; i += 4) {
          expect(rgba.getUint32(i), 0x4CAF50FF);
        }
        frame.image.dispose();
        codec.dispose();
      });
      expect((args['butterfly'] as Uint8List).length, greaterThan(100));
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('wallpaper-apply')))
              .onPressed,
          isNull);
      expect(find.text('Live garden wallpaper applied.'), findsNothing);
      expect(calls, 1);
      finish.complete(applied);
      await tester.pump();
      expect(
          find.text(applied
              ? 'Live garden wallpaper applied.'
              : 'Live wallpaper was not changed.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'Picker errors are shown and can be retried; still wallpaper remains available',
      (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'capabilities')
        return {
          'supported': true,
          'allowed': true,
          'lockScreen': true,
          'live': true
        };
      throw PlatformException(code: 'WALLPAPER_UNSUPPORTED');
    });
    await launch(tester);
    await tester.tap(find.byKey(const ValueKey('wallpaper-mode-live')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('wallpaper-apply')));
      await tester.pump();
    });
    for (var i = 0;
        i < 100 &&
            find.byKey(const ValueKey('wallpaper-error')).evaluate().isEmpty;
        i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(find.text('This wallpaper option is not supported on your device.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('wallpaper-apply')))
            .onPressed,
        isNotNull);
    await tester.tap(find.byKey(const ValueKey('wallpaper-mode-still')));
    await tester.pump();
    expect(find.byKey(const ValueKey('wallpaper-target-both')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallpaper-error')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final locale in AppLocalizations.locales) {
    testWidgets(
        '${locale.toLanguageTag()} live wallpaper fits a small screen with large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      messenger.setMockMethodCallHandler(
          channel,
          (_) async => {
                'supported': true,
                'allowed': true,
                'lockScreen': true,
                'live': true,
              });
      await launch(tester, locale: locale, scale: 1.6);
      await tester.tap(find.byKey(const ValueKey('wallpaper-mode-live')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.ensureVisible(find.byKey(const ValueKey('wallpaper-apply')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final strings = Localizations.of<AppLocalizations>(
          tester.element(find.byType(GardenWallpaperPage)), AppLocalizations)!;
      expect(find.text(strings.text('Preview live wallpaper')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

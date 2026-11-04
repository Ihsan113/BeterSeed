import 'dart:convert';
import 'dart:io';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/account/account_page.dart';
import 'package:betterseed/account/cloud_account.dart';
import 'package:betterseed/account/play_billing.dart';
import 'package:betterseed/l10n/app_localizations.dart';
import 'package:betterseed/main.dart';
import 'package:betterseed/widgets/coin_store_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'asset_editor_test.dart' show openEditor;
import 'garden_test_helpers.dart';
import 'play_billing_server_test.dart' show BillingAccount, FakePlay;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
      'betterseed_account_choice_v1': true,
      'betterseed_habits_v1': jsonEncode([
        {'id': 'custom', 'title': 'Settings', 'iconKey': 'leaf'}
      ]),
    });
  });
  test(
      'English is the default; selection persists; invalid saved language falls back',
      () async {
    final controller = AppLocale();
    await controller.load();
    expect(controller.locale, const Locale('en', 'US'));
    await controller.select(const Locale('pt', 'BR'));
    final restored = AppLocale();
    await restored.load();
    expect(restored.locale, const Locale('pt', 'BR'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppLocale.preference, 'unsupported');
    await restored.load();
    expect(restored.locale, const Locale('en', 'US'));
    controller.dispose();
    restored.dispose();
  });
  test(
      'placeholders preserve user text without translating or reinterpreting it',
      () {
    const strings = AppLocalizations(Locale('id'),
        {'Remove “{p0}” from your checklist?': 'Hapus “{p0}” dari daftar?'});
    expect(
        strings.text(
            'Remove “{p0}” from your checklist?', {'p0': 'Settings {p1}'}),
        'Hapus “Settings {p1}” dari daftar?');
    expect(strings.text('Custom title'), 'Custom title');
    expect(strings.text('Leaf Coins'), 'Leaf Coins');
  });
  testWidgets(
      'language changes in the open settings sheet and survives app recreation',
      (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('ja');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    expect(find.text('Garden'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('settings-menu-language')));
    await pumpGardenTransition(tester);
    await tester.tap(find.byKey(const ValueKey('language-id')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Bahasa aplikasi'), findsOneWidget);
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await waitForGardenReady(tester);
    await pumpGardenTransition(tester);
    expect(find.text('Taman'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppLocale.preference), 'id');
    expect(jsonDecode(prefs.getString('betterseed_habits_v1')!).first['title'],
        'Settings');
    await tester.pumpWidget(const SizedBox());
  });
  for (final locale in AppLocalizations.locales) {
    testWidgets(
        '${locale.toLanguageTag()} garden, settings, shop, editor and stats fit small screens',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await (await SharedPreferences.getInstance())
          .setString(AppLocale.preference, locale.toLanguageTag());
      await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
      await waitForGardenReady(tester);
      await pumpGardenTransition(tester);
      final ctx = tester.element(find.byType(GrowthHome));
      expect(find.text(ctx.tr('Garden')), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final tab in [1, 2, 3]) {
        await tester.tap(find.byKey(ValueKey('tab-$tab')));
        await pumpGardenTransition(tester);
        expect(tester.takeException(), isNull);
      }
      await openEditor(tester);
      expect(find.text(ctx.tr('Edit garden')), findsOneWidget);
      for (final tool in ['position', 'assets']) {
        await tester.tap(find.byKey(ValueKey('editor-tool-$tool')));
        await pumpGardenTransition(tester);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const ValueKey('asset-editor-cancel')));
      await pumpGardenTransition(tester);
      await tester.tap(find.byTooltip(ctx.tr('Settings')));
      await pumpGardenTransition(tester);
      final language = find.byKey(const ValueKey('settings-menu-language'));
      await tester.ensureVisible(language);
      await pumpGardenTransition(tester);
      expect(find.text(ctx.tr('App language')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets(
        '${locale.toLanguageTag()} sign in and coin store use localized labels at large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = AppLocalizations(
          locale,
          (jsonDecode(File('assets/l10n/${locale.languageCode}.json')
                  .readAsStringSync()) as Map)
              .cast<String, String>());
      Widget app(Widget child) => MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.locales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 640), textScaler: TextScaler.linear(1.6)),
              child: child!),
          home: child);
      final account = CloudAccount(api: AccountApi(baseUrl: ''));
      await tester.pumpWidget(app(AccountPage(account: account)));
      for (var attempt = 0;
          attempt < 100 && find.byType(AccountPage).evaluate().isEmpty;
          attempt++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(strings.text('Sign in to BetterSeed')), findsOneWidget);
      await tester
          .ensureVisible(find.text(strings.text('Create an email account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.text('Create an email account')));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('Create your account')), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      account.dispose();
      final billingAccount = BillingAccount(), play = FakePlay();
      final billing = PlayBilling(billingAccount, purchase: play);
      await tester.pumpWidget(app(
          BetterSeedCoinStorePage(account: billingAccount, billing: billing)));
      await tester.pumpAndSettle();
      expect(find.text(strings.text('Your balance')), findsOneWidget);
      for (final amount in [120, 300, 650, 1400]) {
        await tester.ensureVisible(find.byKey(ValueKey('coin-bundle-$amount')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Leaf Coins'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      billing.dispose();
      billingAccount.dispose();
      await play.events.close();
    });
  }
}

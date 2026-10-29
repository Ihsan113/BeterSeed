import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/account/account_page.dart';
import 'package:betterseed/account/cloud_account.dart';
import 'package:betterseed/account/legal_page.dart';
import 'cloud_account_test.dart' show MemorySession, garden, session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CloudAccount account;
  final requests = <http.Request>[];
  Future<http.Response> handler(http.Request r) async {
    requests.add(r);
    // Request/response bodies are deliberately not logged.
    final data = switch (r.url.path) {
      '/v1/legal' => {
          'version': '2026-10-27',
          'documents': {
            'privacy': {
              'title': 'Privacy policy',
              'body': 'Test policy from the server'
            },
            'terms': {'title': 'Terms of use', 'body': 'Terms from the server'}
          }
        },
      '/v1/garden' =>
        r.method == 'GET' ? {'revision': 0, 'snapshot': null} : {'revision': 1},
      '/v1/account' => {'user': account.user},
      '/v1/wallet' => {'balance': 0, 'packs': [], 'billingAvailable': true},
      '/v1/auth/register' => {'challengeId': 'challenge-id'},
      '/v1/auth/verify-email' => session('a'),
      _ => {'ok': true},
    };
    return http.Response(jsonEncode(data), 200,
        headers: {'content-type': 'application/json'});
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    account = CloudAccount(
        api: AccountApi(
            baseUrl: 'https://api.example.com', client: MockClient(handler)),
        sessions: MemorySession());
    await account.initialize(garden(0), garden(0));
  });
  tearDown(() => account.dispose());
  Future<void> show(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(scale)),
            child: child!),
        home: AccountPage(account: account)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'registration requires policies; verification precedes account creation in the app',
      (tester) async {
    await show(tester);
    await tester.ensureVisible(find.text('Create an email account'));
    await tester.tap(find.text('Create an email account'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Create account'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'long-password-test');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your email'), findsOneWidget);
    expect(account.signedIn, false);
    final request =
        requests.singleWhere((r) => r.url.path == '/v1/auth/register');
    expect(jsonDecode(request.body)['acceptTerms'], true);
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Verify email'));
    await tester.tap(find.widgetWithText(FilledButton, 'Verify email'));
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 10));
      if (account.signedIn && !account.busy) break;
    }
    expect(account.busy, false);
    await tester.pumpAndSettle();
    expect(account.signedIn, true);
    expect(find.text('Verified email account'), findsOneWidget);
    account.pause();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'Google accounts show authenticator and deletion but hide password controls',
      (tester) async {
    final google = session('g');
    google['user']['provider'] = 'google';
    await tester.runAsync(() => account.acceptSession(google));
    account.pause();
    await show(tester, scale: 1.8);
    expect(find.text('Google account'), findsOneWidget);
    expect(find.text('Change password'), findsNothing);
    expect(find.text('Authenticator'), findsOneWidget);
    await tester.ensureVisible(find.text('Delete account permanently'));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('email accounts expose password controls', (tester) async {
    await tester.runAsync(() => account.acceptSession(session('a')));
    account.pause();
    await show(tester);
    expect(find.text('Change password'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'guest page fits compact large-text screen with legal links and guest choice',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, scale: 1.8);
    await tester.ensureVisible(find.text('Continue as guest'));
    expect(tester.takeException(), isNull);
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Terms of use'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('legal screen loads published policies without authentication',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LegalPage(api: account.api, document: 'privacy')));
    await tester.pumpAndSettle();
    expect(find.text('Test policy from the server'), findsOneWidget);
    expect(requests.single.headers.containsKey('authorization'), false);
  });
}

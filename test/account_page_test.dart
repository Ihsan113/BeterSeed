import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:betterseed/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betterseed/account/account_api.dart';
import 'package:betterseed/ui/app_feedback.dart';
import 'package:betterseed/account/account_page.dart';
import 'package:betterseed/account/cloud_account.dart';
import 'package:betterseed/account/legal_page.dart';
import 'cloud_account_test.dart' show MemorySession, garden, session;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CloudAccount account;
  final requests = <http.Request>[];
  bool resetWithTwoFactor = false;
  bool emailAlreadyVerified = false;
  bool rejectCode = false;
  Future<http.Response> handler(http.Request r) async {
    requests.add(r);
    if (rejectCode && r.url.path == '/v1/auth/verify-email') {
      return http.Response(
          jsonEncode({'error': 'invalid_or_expired_code'}), 400);
    }
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
      '/v1/auth/forgot-password' => {'challengeId': 'email-challenge'},
      '/v1/auth/password-reset/verify-email' => {
          'challengeId': 'verified-email',
          'resetToken': 'email-proof',
          'twoFactorRequired': resetWithTwoFactor
        },
      '/v1/auth/password-reset/verify-factor' => {
          'challengeId': 'verified-factor',
          'resetToken': 'factor-proof'
        },
      '/v1/auth/verification/start' => emailAlreadyVerified
          ? {'status': 'already_verified'}
          : {'status': 'verification_sent', 'challengeId': 'requested-code'},
      '/v1/auth/resend-verification' => {'challengeId': 'resent-code'},
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
    rootBundle.clear();
    resetWithTwoFactor = false;
    emailAlreadyVerified = false;
    rejectCode = false;
    account = CloudAccount(
        api: AccountApi(
            baseUrl: 'https://api.example.com', client: MockClient(handler)),
        sessions: MemorySession());
    await account.initialize(garden(0), garden(0));
  });
  tearDown(() => account.dispose());
  Future<void> show(WidgetTester tester,
      {double scale = 1, Locale locale = const Locale('en', 'US')}) async {
    await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.locales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        theme: betterSeedTheme(),
        builder: (_, child) => MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(scale)),
            child: child!),
        home: AccountPage(account: account)));
    await tester.pumpAndSettle();
  }

  Future<void> verificationRequest(WidgetTester tester) async {
    await show(tester);
    await tester.ensureVisible(find.text('Need help signing in?'));
    await tester.tap(find.text('Need help signing in?'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.text('Verify an existing email registration'));
    await tester.tap(find.text('Verify an existing email registration'));
    await tester.pumpAndSettle();
  }

  Future<void> requestCode(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'a@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'long-password-test');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('account-submit')));
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'verification requests a code before showing input and throttles resend',
      (tester) async {
    await verificationRequest(tester);
    expect(find.text('6-digit email code'), findsNothing);
    expect(find.byKey(const ValueKey('verification-resend')), findsNothing);
    expect(requests.where((r) => r.url.path.contains('verification')), isEmpty);
    await requestCode(tester);
    expect(find.text('Enter your email code'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final resend = find.byKey(const ValueKey('verification-resend'));
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    await tester.pump(const Duration(seconds: 60));
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    await tester.ensureVisible(resend);
    await tester.tap(resend);
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.url.path == '/v1/auth/resend-verification'),
        hasLength(1));
    expect(tester.widget<TextButton>(resend).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'verified email returns to sign-in with a clear status and no OTP',
      (tester) async {
    emailAlreadyVerified = true;
    await verificationRequest(tester);
    await requestCode(tester);
    expect(find.text('Sign in to BetterSeed'), findsOneWidget);
    expect(
        find.text(
            'This email is already registered and verified. Sign in to continue.'),
        findsOneWidget);
    expect(find.text('6-digit email code'), findsNothing);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        isEmpty);
    expect(account.signedIn, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'invalid OTP keeps the verification step and explains how to retry',
      (tester) async {
    await verificationRequest(tester);
    await requestCode(tester);
    rejectCode = true;
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This code is incorrect, expired, or already used. Check the latest code or start again.'),
        findsOneWidget);
    expect(find.text('Enter your email code'), findsOneWidget);
    expect(account.signedIn, false);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'invalid sign-in fields are explained without sending credentials',
      (tester) async {
    await show(tester);
    await tester.tap(find.byKey(const ValueKey('account-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(requests.where((r) => r.url.path == '/v1/auth/login'), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

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
    expect(find.text('Enter your email code'), findsOneWidget);
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
  testWidgets(
      'permanent deletion keeps the confirmation open for missing proof',
      (tester) async {
    await tester.runAsync(() => account.acceptSession(session('a')));
    account.pause();
    await show(tester, scale: 1.6);
    await tester.ensureVisible(find.text('Delete account permanently'));
    await tester.tap(find.text('Delete account permanently'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete permanently'));
    await tester.pump();
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(account.signedIn, true);
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
  Future<void> submitRecovery(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('account-submit'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 10));
      if (tester.widget<FilledButton>(button).onPressed != null) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> startReset(WidgetTester tester) async {
    final context = tester.element(find.byType(AccountPage));
    await tester.ensureVisible(find.text(context.tr('Forgot password?')));
    await tester.tap(find.text(context.tr('Forgot password?')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'a@example.com');
    await submitRecovery(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(
        find.byKey(const ValueKey('reset-method-authenticator')), findsNothing);
    expect(find.text(context.tr('Continue as guest')), findsNothing);
    expect(find.text(context.tr('Help & information')), findsNothing);
    await tester.enterText(find.byType(TextField).first, '123456');
    await submitRecovery(tester);
  }

  for (final method in ['email', 'authenticator', 'recovery']) {
    testWidgets('Recovery uses separate verified steps: $method',
        (tester) async {
      resetWithTwoFactor = method != 'email';
      await show(tester, scale: 1.6);
      await startReset(tester);
      if (resetWithTwoFactor) {
        expect(find.text('Verify your identity'), findsOneWidget);
        expect(find.text('Choose a new password'), findsNothing);
        if (method == 'recovery') {
          await tester.tap(find.byKey(const ValueKey('reset-method-recovery')));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField).first,
            method == 'recovery' ? 'recovery-123' : '654321');
        await submitRecovery(tester);
      }
      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('reset-method-authenticator')),
          findsNothing);
      await tester.enterText(
          find.byType(TextField).first, 'a-new-long-password');
      await submitRecovery(tester);
      expect(find.text('Password reset. Sign in with your new password.'),
          findsOneWidget);
      expect(account.signedIn, isFalse);
      final completed = jsonDecode(requests
          .singleWhere((r) => r.url.path.endsWith('/complete'))
          .body) as Map;
      expect(completed.keys.toSet(), {'challengeId', 'resetToken', 'password'});
      expect(completed['resetToken'],
          resetWithTwoFactor ? 'factor-proof' : 'email-proof');
      expect(requests.any((r) => r.url.path.endsWith('/verify-factor')),
          resetWithTwoFactor);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final locale in AppLocalizations.locales) {
    testWidgets(
        '${locale.toLanguageTag()} recovery method selection fits large text',
        (tester) async {
      resetWithTwoFactor = true;
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester, scale: 1.6, locale: locale);
      await startReset(tester);
      expect(find.byKey(const ValueKey('reset-method-authenticator')),
          findsOneWidget);
      await tester
          .ensureVisible(find.byKey(const ValueKey('reset-method-recovery')));
      await tester.tap(find.byKey(const ValueKey('reset-method-recovery')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

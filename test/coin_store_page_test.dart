import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betterseed/account/play_billing.dart';
import 'package:betterseed/widgets/coin_store_page.dart';
import 'play_billing_server_test.dart' show BillingAccount, FakePlay;

void main() {
  for (final size in [const Size(320, 640), const Size(800, 1000)]) {
    testWidgets('coin store prices and help fit $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = BillingAccount(), play = FakePlay();
      final storeBilling = PlayBilling(account, purchase: play);
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                  size: size, textScaler: TextScaler.linear(1.8)),
              child: child!),
          home: BetterSeedCoinStorePage(
              account: account, billing: storeBilling)));
      await tester.pumpAndSettle();
      for (final amount in [120, 300, 650, 1400]) {
        await tester.ensureVisible(find.byKey(ValueKey('coin-bundle-$amount')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Rp10.000'), findsNWidgets(4));
      await tester.ensureVisible(find.text('Already paid but missing coins?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Already paid but missing coins?'));
      await tester.pumpAndSettle();
      expect(find.text('Check purchase delivery'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      storeBilling.dispose();
      account.dispose();
      await play.events.close();
    });
  }
}

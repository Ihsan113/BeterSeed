import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// BetterSeed loads preferences before mounting the IndexedStack; optional
/// CDN pack discovery deliberately runs separately. A fixed 300-500ms pump
/// alone is not a reliable readiness check.
/// Do not use pumpAndSettle here: the real Garden animates indefinitely.
Future<void> waitForGardenReady(WidgetTester tester) async {
  final ready = find.byKey(const ValueKey('shop-scroll'), skipOffstage: false);
  for (var frame = 0; frame < 80; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready.evaluate().isNotEmpty) return;
    // Some platform adapters use genuine asynchronous file I/O even under
    // flutter_test. Let it finish without pumping an infinite animation.
    if (frame % 8 == 7) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
    }
  }
  expect(ready, findsOneWidget,
      reason: 'Garden did not finish loading; check asynchronous initialization');
}

/// Advance route/sheet transitions by a bounded amount. The garden's ambient
/// animation is infinite, so pumpAndSettle cannot converge reliably.
Future<void> pumpGardenTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

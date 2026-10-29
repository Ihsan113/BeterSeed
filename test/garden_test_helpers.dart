import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// BetterSeed loads the local CDN manifest, prefs and platform services before
/// mounting the IndexedStack. A fixed 300-500ms pump is not a readiness check.
/// Do not use pumpAndSettle here: the real Garden animates indefinitely.
Future<void> waitForGardenReady(WidgetTester tester) async {
  final ready = find.byKey(const ValueKey('shop-scroll'), skipOffstage: false);
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready.evaluate().isNotEmpty) return;
  }
  expect(ready, findsOneWidget,
      reason: 'Garden must finish loading preferences and the CDN manifest');
}

/// Advance route/sheet transitions by a bounded amount. The garden's ambient
/// animation is infinite, so pumpAndSettle cannot converge reliably.
Future<void> pumpGardenTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

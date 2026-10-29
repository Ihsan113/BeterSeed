import 'package:betterseed/logic/growth.dart';
import 'package:betterseed/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('BetterSeed ships six growth stages', () {
    expect(treeStageThresholds.length, 6);
  });

  testWidgets('BetterSeedApp launches the real garden screen', (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_motion_v2': false,
    });

    // Do not use the default Flutter template's MyApp / counter test: this
    // project exposes BetterSeedApp as its root widget.
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(GrowthHome), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betterseed/checklist/checklist_page.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/habit_icons.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/water_progress.dart';

void main() {
  test('60 stable icons and every new icon label translated in seven locales',
      () {
    expect(habitIcons.length, 60);
    expect(habitIcons.map((i) => i.key).toSet().length, 60);
    expect(habitIcon('water'), Icons.local_drink_outlined);
    for (final locale in ['en', 'id', 'de', 'es', 'fr', 'ja', 'pt']) {
      final strings =
          jsonDecode(File('assets/l10n/$locale.json').readAsStringSync())
              as Map;
      for (final icon in habitIcons)
        expect(strings[icon.label], isA<String>(),
            reason: '$locale ${icon.label}');
    }
  });
  for (final width in [320.0, 360.0, 393.0, 600.0]) {
    testWidgets('Checklist and editor at $width dp, font 200%, keyboard',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      final d = ChecklistData(
          start: checklistDay(now),
          plan: const HabitPlan(type: 'count', target: 8, unit: 'glasses'));
      await tester.pumpWidget(MaterialApp(
          builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: Scaffold(
              body: ChecklistPage(
                  habits: [
                Habit(
                    id: 'one',
                    title: 'A long habit title for accessible small screens',
                    checklist: d)
              ],
                  progress: WaterProgress(),
                  onChanged: (_) {},
                  masterEnabled: false,
                  onEnableMaster: () async => true))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('Add a daily habit'), 250,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add a daily habit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a daily habit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField).first, 'Read');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Save habit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:convert';

import 'package:betterseed/main.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/growth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Bottom-sheet category cards may be outside the visible viewport.
// Scroll them into view before a real tap so navigation is actually tested.
Future<void> _openSettingsCategory(WidgetTester tester, String key) async {
  final category = find.byKey(ValueKey(key));
  expect(category, findsOneWidget);
  await tester.ensureVisible(category);
  await tester.pump();
  await tester.tap(category);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 220));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Checklist explains paused reminders when the master is off', (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false,
      'betterseed_sfx_v2': false,
      'betterseed_day_v1': todayLocalKey(),
      'betterseed_habits_v1': jsonEncode([
        (const Habit(id: 'read', title: 'Read', reminderEnabled: true)).toJson(),
      ]),
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pump();
    expect(find.byKey(const ValueKey('reminder-master-warning')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings offers Android and manual file backup controls', (tester) async {
    SharedPreferences.setMockInitialValues({
      'betterseed_music_v2': false, 'betterseed_sfx_v2': false,
    });
    await tester.pumpWidget(const BetterSeedApp(showLaunchFlow: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byKey(const ValueKey('settings-menu-routine')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-menu-backup')), findsOneWidget);

    await _openSettingsCategory(tester, 'settings-menu-routine');
    expect(find.byKey(const ValueKey('reminder-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    await _openSettingsCategory(tester, 'settings-menu-backup');
    expect(find.byKey(const ValueKey('backup-auto-info')), findsOneWidget);
    expect(find.byKey(const ValueKey('saf-backup-now')), findsOneWidget);
    expect(find.byKey(const ValueKey('saf-restore')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betterseed/checklist/checklist_page.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/checklist_detail.dart';
import 'package:betterseed/checklist/habit_icons.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/logic/water_progress.dart';

void main() {
  testWidgets('date selection does not imply completion; checkbox toggles once',
      (tester) async {
    final now = DateTime.now();
    final day = checklistDay(now);
    var habits = [
      Habit(
          id: 'toggle', title: 'Stretch', checklist: ChecklistData(start: day))
    ];
    var changes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => ChecklistPage(
                      habits: habits,
                      progress: WaterProgress(),
                      masterEnabled: false,
                      onEnableMaster: () async => true,
                      onChanged: (value) {
                        changes++;
                        update(() => habits = value);
                      },
                    )))));
    await tester.pumpAndSettle();
    final date = find.byKey(ValueKey('checklist-date-$day'));
    expect(
        find.descendant(of: date, matching: find.byIcon(Icons.check_rounded)),
        findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    final checkbox = find.byKey(const ValueKey('habit-toggle'));
    await tester.scrollUntilVisible(checkbox, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(changes, 1);
    expect(habits.single.completed, isTrue);
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
    expect(
        find.descendant(of: date, matching: find.byIcon(Icons.check_rounded)),
        findsOneWidget);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(changes, 2);
    expect(habits.single.completed, isFalse);
    expect(
        find.descendant(of: date, matching: find.byIcon(Icons.check_rounded)),
        findsNothing);
  });

  testWidgets(
      'historical detail shows the selected record and cannot mutate it',
      (tester) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    var data = ChecklistData(
        start: checklistDay(yesterday),
        plan: const HabitPlan(type: 'count', target: 8, unit: 'glasses'));
    data = data.record(yesterday, data.today(yesterday).change(value: 3));
    data = data.record(now, data.today(now).change(value: 8));
    await tester.pumpWidget(MaterialApp(
        home: ChecklistDetail(
      habit: Habit(id: 'water', title: 'Drink water', checklist: data),
      date: yesterday,
      onChanged: (_) => fail('History must not change'),
      onEdit: () => fail('History must not be editable'),
    )));
    await tester.pumpAndSettle();
    expect(find.text('3 / 8'), findsOneWidget);
    expect(find.text('8 / 8'), findsNothing);
    expect(find.text('+1'), findsNothing);
    expect(find.byTooltip('Edit habit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar and detail fit a small screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final data = ChecklistData(
        start: checklistDay(now),
        plan: const HabitPlan(type: 'duration', target: 20));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: ChecklistPage(
                habits: [
              Habit(id: 'read', title: 'Read a book', checklist: data)
            ],
                progress: WaterProgress(),
                onChanged: (_) {},
                masterEnabled: false,
                onEnableMaster: () async => true))));
    await tester.tap(find.byTooltip('Calendar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Read a book'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Read a book'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Read a book'));
    await tester.pumpAndSettle();
    expect(find.byType(ChecklistDetail), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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

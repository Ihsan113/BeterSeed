import 'dart:convert';
import 'package:betterseed/backup/backup_snapshot.dart';
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/logic/water_progress.dart';
import 'package:betterseed/data/habit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'habit_library_test.dart' show fixture, mount, tap, key;

Future<void> review(WidgetTester tester, String id) async {
  await tap(tester, key('library-actions-$id'));
  await tap(tester, find.text('Delete permanently'));
}

void main() {
  testWidgets(
      'permanent delete reviews the name and impact; cancel keeps habit',
      (tester) async {
    final source = ValueNotifier([fixture('Read')]);
    var saves = 0;
    await mount(tester, source, save: (_) async {
      saves++;
    });
    await review(tester, 'Read');
    expect(find.text('Selected habits: 1'), findsOneWidget);
    expect(
        find.text(
            'This cannot be undone here. Older backups may still contain these habits.'),
        findsOneWidget);
    await tap(tester, find.text('Cancel'));
    expect(source.value.single.title, 'Read');
    expect(saves, 0);
  });

  testWidgets(
      'filtered bulk delete removes active and archived selections only',
      (tester) async {
    final source = ValueNotifier([
      fixture('Read'),
      fixture('Reading', archived: true),
      fixture('Water')
    ]);
    final remaining = jsonEncode(source.value.last.toJson());
    await mount(tester, source);
    await tester.enterText(key('library-search'), 'Read');
    await tester.pumpAndSettle();
    await tap(tester, key('library-selection-mode'));
    await tap(tester, key('library-select-visible'));
    await tap(tester, key('library-bulk-actions'));
    await tap(tester, find.text('Delete permanently'));
    expect(find.text('Selected habits: 2'), findsOneWidget);
    await tap(tester, key('confirm-delete-habits'));
    expect(jsonEncode(source.value.single.toJson()), remaining);
    expect(find.text('Habits deleted'), findsOneWidget);
  });

  for (final changed in [true, false]) {
    testWidgets(
        'delete confirmation handles concurrent ${changed ? 'selected edit' : 'unselected addition'}',
        (tester) async {
      final source = ValueNotifier([fixture('Read')]);
      await mount(tester, source);
      await review(tester, 'Read');
      source.value = changed
          ? [source.value.single.copyWith(title: 'Updated remotely')]
          : [...source.value, fixture('New')];
      await tester.pumpAndSettle();
      await tap(tester, key('confirm-delete-habits'));
      expect(source.value.single.title, changed ? 'Updated remotely' : 'New');
      if (changed)
        expect(
            find.text('Habits changed. Review your selection and try again.'),
            findsOneWidget);
    });
  }

  testWidgets(
      'account change during confirmation cannot delete another account data',
      (tester) async {
    final source = ValueNotifier([fixture('Read')]);
    var owner = 'a', saves = 0;
    await mount(tester, source,
        scope: () => owner,
        save: (_) async {
          saves++;
        });
    await review(tester, 'Read');
    owner = 'b'; // no notification/frame yet: handler must check live scope
    await tap(tester, key('confirm-delete-habits'));
    expect(saves, 0);
    expect(source.value.single.id, 'Read');
  });

  testWidgets('delete reports failed persistence without reporting success',
      (tester) async {
    final source = ValueNotifier([fixture('Read')]);
    await mount(tester, source,
        save: (_) async => throw StateError('disk full'));
    await review(tester, 'Read');
    await tap(tester, key('confirm-delete-habits'));
    expect(find.text('Habits deleted'), findsNothing);
    expect(find.text('Changes could not be saved. Please try again.'),
        findsOneWidget);
    expect(source.value.length, 1);
  });

  testWidgets(
      'delete last habit at 320 dp and 200% text reaches a clean empty state',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = ValueNotifier([fixture('A habit with a long name')]);
    await mount(tester, source, scale: 2);
    await tester.scrollUntilVisible(
        key('library-actions-A habit with a long name'), 120,
        scrollable: find.byType(Scrollable).first);
    await review(tester, 'A habit with a long name');
    expect(tester.takeException(), isNull);
    await tap(tester, key('confirm-delete-habits'));
    expect(source.value, isEmpty);
    await tester.scrollUntilVisible(
        find.text('Plant your first daily habit 🌱'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Plant your first daily habit 🌱'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'empty and legacy habit lists retain the cloud version floor after deletion',
      () {
    expect(habitSnapshotVersion([]), 1);
    expect(habitSnapshotVersion([], previous: 2), 2);
    expect(habitSnapshotVersion([], previous: 3), 3);
    expect(
        habitSnapshotVersion([const Habit(id: 'legacy', title: 'Legacy')],
            previous: 3),
        3);
    expect(habitSnapshotVersion([fixture('Checkbox')]), 2);
    expect(
        habitSnapshotVersion(
            [fixture('Timed', plan: const HabitPlan(activityMinute: 420))]),
        3);
  });

  test(
      'backup of an empty habit list preserves existing water credit and tree XP',
      () {
    final water = WaterProgress()
      ..earnForHabit('2026-11-07', 'deleted')
      ..waterTree();
    final backup = BackupSnapshot(
        habits: const <Habit>[],
        progress: water,
        day: '2026-11-07',
        packId: 'default',
        ownedMoonlight: false,
        savedAtUtc: DateTime.utc(2026, 11, 7));
    final restored = BackupSnapshot.decode(backup.encode());
    expect(restored.habits, isEmpty);
    expect(restored.progress.toJson(), water.toJson());
    expect(restored.progress.earnForHabit('2026-11-07', 'deleted'), false);
    expect(restored.progress.xp, 10);
  });
}

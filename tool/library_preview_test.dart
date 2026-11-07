import 'dart:io';
import 'dart:ui' as ui;
import 'package:betterseed/checklist/checklist_data.dart';
import 'package:betterseed/checklist/habit_manager_page.dart';
import 'package:betterseed/data/habit.dart';
import 'package:betterseed/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('real Flutter renders of global management in Indonesian',
      (tester) async {
    const sdk = String.fromEnvironment('FLUTTER_SDK');
    const output = String.fromEnvironment('PREVIEW_OUTPUT',
        defaultValue: 'build/library_preview');
    await tester.runAsync(() async {
      await Directory(output).create(recursive: true);
      for (final e in {
        'Ahem': 'Roboto-Regular.ttf',
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf'
      }.entries) {
        final loader = FontLoader(e.key)
          ..addFont(Future.value(ByteData.sublistView(
              File('$sdk/bin/cache/artifacts/material_fonts/${e.value}')
                  .readAsBytesSync())));
        await loader.load();
      }
    });
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = checklistDay(DateTime.now());
    final source = ValueNotifier([
      Habit(
          id: 'water',
          title: 'Minum air putih',
          iconKey: 'water',
          checklist: ChecklistData(
              start: day,
              plan: const HabitPlan(
                  type: 'count',
                  target: 8,
                  unit: 'count',
                  activityMinute: 420))),
      Habit(
          id: 'read',
          title: 'Membaca buku',
          iconKey: 'book',
          reminderEnabled: true,
          reminderLeadMinutes: 15,
          checklist: ChecklistData(
              start: day,
              category: 'Evening',
              order: 1,
              plan: const HabitPlan(
                  type: 'duration', target: 20, activityMinute: 1140))),
      Habit(
          id: 'walk',
          title: 'Jalan pagi di taman',
          iconKey: 'walk',
          checklist: ChecklistData(
              start: day, order: 2, plan: const HabitPlan(weekdays: [6, 7]))),
      Habit(
          id: 'journal',
          title: 'Menulis jurnal',
          iconKey: 'book',
          checklist: ChecklistData(
              start: day, archived: true, category: 'Evening', order: 3)),
    ]);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('id'),
            supportedLocales: AppLocalizations.locales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate
            ],
            home: Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: TextButton(
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => HabitManagerPage(
                                        habits: source,
                                        onChanged: (next) async =>
                                            source.value = next,
                                        masterEnabled: () => true,
                                        onEnableMaster: () async => true,
                                        scope: () => 'guest'))),
                            child: const Text('Open'))))))));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary = boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await boundary.toImage(pixelRatio: 2);
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        picture.dispose();
      });
    }

    for (var frame = 0;
        frame < 80 && find.text('Open').evaluate().isEmpty;
        frame++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(HabitManagerPage), findsOneWidget);
    await capture('Semua_Kebiasaan');
    await tester.tap(find.byKey(const ValueKey('library-filters')));
    await capture('Filter_Kebiasaan');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-selection-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-select-water')));
    await tester.pumpAndSettle();
    await capture('Pilihan_Massal');
    await tester.tap(find.byKey(const ValueKey('library-bulk-actions')));
    await capture('Aksi_Massal');
    await tester.tap(find.text('Arsipkan kebiasaan'));
    await capture('Konfirmasi_Arsip');
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-status-archived')));
    await capture('Arsip_Kebiasaan');
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:betterseed/ui/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom confirmation scrolls above the keyboard with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? result;
    await tester.pumpWidget(MaterialApp(
      theme: betterSeedTheme(),
      builder: (_, child) => MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
            viewInsets: EdgeInsets.only(bottom: 240)),
        child: child!,
      ),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (dialog) => AppDialog(
                                tone: NoticeTone.error,
                                icon: Icons.delete_outline,
                                title:
                                    const Text('Delete account permanently?'),
                                content: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                          'Your cloud garden and account will be removed. Review the data and confirm your identity before continuing.'),
                                      TextField(
                                          decoration: InputDecoration(
                                              labelText: 'Current password')),
                                    ]),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, false),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(dialog, true),
                                      child: const Text('Delete permanently')),
                                ],
                              ));
                    },
                    child: const Text('Open'),
                  ))),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, false);
  });

  testWidgets(
      'global toast remains readable and dismissible on a compact screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: betterSeedTheme(),
      builder: (_, child) => MediaQuery(
          data: const MediaQueryData(
              size: Size(320, 640), textScaler: TextScaler.linear(1.6)),
          child: child!),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () =>
                        ScaffoldMessenger.of(context).showSnackBar(AppToast(
                      tone: NoticeTone.warning,
                      content: const Text(
                          'Unable to save your garden. Your changes are still on this phone. Check your connection and try again.'),
                    )),
                    child: const Text('Show message'),
                  ))),
    ));
    await tester.tap(find.text('Show message'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}

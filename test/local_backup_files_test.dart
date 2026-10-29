import 'package:betterseed/backup/local_backup_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('betterseed/backup_documents');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('manual backup asks Android to create a JSON document', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'createBackup');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      expect(args['name'], 'BetterSeed-backup-2026-10-25.json');
      expect(args['json'], '{"format":"betterseed.backup"}');
      return true;
    });
    expect(await LocalBackupFiles.saveJson(
      suggestedName: 'BetterSeed-backup-2026-10-25.json',
      contents: '{"format":"betterseed.backup"}',
    ), true);
  });

  test('manual restore reads JSON from the Android document picker', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'openBackup');
      return '{"format":"betterseed.backup"}';
    });
    expect(await LocalBackupFiles.openJson(), contains('betterseed.backup'));
  });

  test('picker cancellation does not fabricate a backup or restore', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    expect(await LocalBackupFiles.saveJson(suggestedName: 'x.json', contents: '{}'), isFalse);
    expect(await LocalBackupFiles.openJson(), isNull);
  });

  test('very large backup is rejected before launching Android picker', () async {
    await expectLater(LocalBackupFiles.saveJson(
      suggestedName: 'x.json',
      contents: List<String>.filled(4200000, 'x').join(),
    ), throwsFormatException);
  });
}

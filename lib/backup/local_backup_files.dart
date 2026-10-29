import 'dart:convert';

import 'package:flutter/services.dart';

/// Android Storage Access Framework bridge. The Android document picker can
/// display local storage or a cloud provider (e.g. Google Drive), if installed.
/// No Google OAuth, background upload, storage permissions, or server involved.
class LocalBackupFiles {
  static const MethodChannel _channel = MethodChannel('betterseed/backup_documents');

  /// Returns false if the user cancels. Other failures are reported explicitly.
  static Future<bool> saveJson({
    required String suggestedName,
    required String contents,
  }) async {
    if (utf8.encode(contents).length > 4 * 1024 * 1024) {
      throw const FormatException('BetterSeed backup is too large');
    }
    return await _channel.invokeMethod<bool>('createBackup', {
          'name': suggestedName,
          'json': contents,
        }) ?? false;
  }

  /// Returns null when the user dismisses the picker.
  static Future<String?> openJson() => _channel.invokeMethod<String>('openBackup');
}

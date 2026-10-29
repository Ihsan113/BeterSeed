import 'package:flutter/services.dart';

/// Android SAF picker. An imported MP3 is copied to private app storage so
/// playback remains available offline even after the provider goes away.
/// Never records the original URI or asks for broad storage permissions.
class ImportedMusic {
  const ImportedMusic({required this.path, required this.name});
  final String path;
  final String name;

  static ImportedMusic? fromPlatform(dynamic value) {
    if (value is! Map) return null;
    final path = value['path'];
    final name = value['name'];
    if (path is! String || path.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    return ImportedMusic(path: path, name: name);
  }
}

class LocalMusicFiles {
  static const MethodChannel _channel = MethodChannel('betterseed/music_files');

  /// Null means the user canceled the picker.
  static Future<ImportedMusic?> importMp3() async =>
      ImportedMusic.fromPlatform(await _channel.invokeMethod<dynamic>('pickMp3'));

  static Future<ImportedMusic?> installedMp3() async =>
      ImportedMusic.fromPlatform(await _channel.invokeMethod<dynamic>('getImportedMp3'));
}

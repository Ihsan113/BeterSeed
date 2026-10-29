import 'package:flutter/services.dart';

enum WallpaperTarget { home, lock, both }

class WallpaperCapabilities {
  const WallpaperCapabilities(
      {this.supported = false, this.allowed = false, this.lockScreen = false});
  final bool supported;
  final bool allowed;
  final bool lockScreen;
}

class GardenWallpaper {
  static const channel = MethodChannel('betterseed/wallpaper');

  static Future<WallpaperCapabilities> capabilities() async {
    try {
      final reply =
          await channel.invokeMapMethod<String, dynamic>('capabilities');
      return WallpaperCapabilities(
        supported: reply?['supported'] == true,
        allowed: reply?['allowed'] == true,
        lockScreen: reply?['lockScreen'] == true,
      );
    } on MissingPluginException {
      return const WallpaperCapabilities();
    }
  }

  /// Completes only after Android confirms the image was applied.
  static Future<void> setImage(Uint8List png, WallpaperTarget target) async {
    if (png.isEmpty || png.length > 20 * 1024 * 1024) {
      throw PlatformException(code: 'WALLPAPER_INVALID_IMAGE');
    }
    final applied = await channel.invokeMethod<bool>('setWallpaper', {
      'png': png,
      'target': target.name,
    });
    if (applied != true) throw PlatformException(code: 'WALLPAPER_FAILED');
  }
}

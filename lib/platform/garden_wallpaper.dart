import 'package:flutter/services.dart';

enum WallpaperTarget { home, lock, both }

class WallpaperCapabilities {
  const WallpaperCapabilities(
      {this.supported = false,
      this.allowed = false,
      this.lockScreen = false,
      this.live = false});
  final bool supported;
  final bool allowed;
  final bool lockScreen;
  final bool live;
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
        live: reply?['live'] == true,
      );
    } on MissingPluginException {
      return const WallpaperCapabilities();
    }
  }

  /// Opens Android's preview; true only when this wallpaper is actually selected.
  /// Canceling keeps the previously applied scene, including when it is ours.
  static Future<bool> previewLive(Uint8List png, Uint8List butterfly,
      {required int glow, required int spark, required int core}) async {
    if (png.isEmpty ||
        png.length > 20 * 1024 * 1024 ||
        butterfly.isEmpty ||
        butterfly.length > 4 * 1024 * 1024) {
      throw PlatformException(code: 'WALLPAPER_INVALID_IMAGE');
    }
    return await channel.invokeMethod<bool>('previewLiveWallpaper', {
          'png': png,
          'butterfly': butterfly,
          'glow': glow,
          'spark': spark,
          'core': core,
        }) ==
        true;
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

import 'package:flutter/services.dart';

/// Native Android-only features. Widget tests and other platforms degrade safely.
class DeviceFeatures {
  static const MethodChannel _channel =
      MethodChannel('betterseed/device_features');

  static Future<Map<String, dynamic>> getReminder() async {
    try {
      return await _channel.invokeMapMethod<String, dynamic>('getReminder') ??
          {'enabled': false, 'permissionGranted': false};
    } on MissingPluginException {
      return {'enabled': false, 'permissionGranted': false};
    } on PlatformException {
      return {'enabled': false, 'permissionGranted': false};
    }
  }

  /// Master switch only. Time belongs to each individual habit.
  static Future<bool> setReminder({required bool enabled}) async {
    try {
      final reply = await _channel.invokeMapMethod<String, dynamic>(
          'setReminder', {'enabled': enabled});
      return reply?['enabled'] == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Serialize the whole current list, so removed/edited habits cancel old alarms.
  /// The local day and completion state are used to suppress reminders for
  /// habits already checked off that day.
  static Future<void> syncHabitReminders(
      {required List<Map<String, dynamic>> habits, required String day}) async {
    try {
      await _channel.invokeMethod<void>(
          'syncHabitReminders', {'habits': habits, 'day': day});
    } on MissingPluginException {
      // Non-Android / Flutter unit test.
    } on PlatformException {
      // Local data still saves even if Android scheduling is unavailable.
    }
  }

  static Future<void> updateWidget(
      {required int water,
      required int stage,
      required int done,
      required int total,
      required String day,
      String theme = 'default',
      String? treeAsset,
      String? treeFile}) async {
    try {
      await _channel.invokeMethod<void>('updateWidget', {
        'water': water,
        'stage': stage,
        'done': done,
        'total': total,
        'day': day,
        'theme': theme,
        if (treeAsset != null) 'treeAsset': treeAsset,
        if (treeFile != null) 'treeFile': treeFile
      });
    } on MissingPluginException {
      // Flutter widget tests and non-Android targets have no native host.
    } on PlatformException {
      // Widget sync should never block saving habits.
    }
  }

  static Future<bool> requestPinWidget() async {
    try {
      return await _channel.invokeMethod<bool>('pinWidget') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> widgetInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('widgetInstalled') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

import 'package:betterseed/platform/device_features.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('betterseed/device_features');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('master notification setting does not require a global reminder time', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getReminder') {
        return {'enabled': true, 'permissionGranted': true};
      }
      if (call.method == 'setReminder') {
        expect(call.arguments, {'enabled': true});
        return {'enabled': true, 'permissionGranted': true};
      }
      return null;
    });
    final reminder = await DeviceFeatures.getReminder();
    expect(reminder['enabled'], isTrue);
    expect(await DeviceFeatures.setReminder(enabled: true), isTrue);
  });

  test('per-habit reminders, completion and local day are sent to Android', () async {
    Map<dynamic, dynamic>? snapshot;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'syncHabitReminders') {
        snapshot = Map<dynamic, dynamic>.from(call.arguments as Map);
      }
      return null;
    });
    final habits = <Map<String, dynamic>>[
      {'id': 'read', 'title': 'Read', 'completed': false,
       'reminderEnabled': true, 'reminderHour': 7, 'reminderMinute': 45},
    ];
    await DeviceFeatures.syncHabitReminders(habits: habits, day: '2026-10-24');
    expect(snapshot?['habits'], habits);
    expect(snapshot?['day'], '2026-10-24');
  });

  test('widget sync sends garden progress to native bridge', () async {
    Map<dynamic, dynamic>? snapshot;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'updateWidget') {
        snapshot = Map<dynamic, dynamic>.from(call.arguments as Map);
      }
      if (call.method == 'widgetInstalled') return false;
      if (call.method == 'pinWidget') return true;
      return null;
    });
    await DeviceFeatures.updateWidget(water: 3, stage: 2, done: 1,
        total: 4, day: '2026-10-24');
    expect(snapshot, {'water': 3, 'stage': 2, 'done': 1,
        'total': 4, 'day': '2026-10-24', 'theme': 'default'});
    // A claimed Moonlight pack must update the native widget too.
    await DeviceFeatures.updateWidget(water: 3, stage: 2, done: 1,
        total: 4, day: '2026-10-24', theme: 'moonlight');
    expect(snapshot, {'water': 3, 'stage': 2, 'done': 1,
        'total': 4, 'day': '2026-10-24', 'theme': 'moonlight'});
    await DeviceFeatures.updateWidget(water:3,stage:2,done:1,total:4,day:'2026-10-24',theme:'crystal_forest',treeAsset:'assets/images/trees/crystal/stage_1_sprout.webp');
    expect(snapshot?['treeAsset'],'assets/images/trees/crystal/stage_1_sprout.webp');
    expect(await DeviceFeatures.widgetInstalled(), isFalse);
    expect(await DeviceFeatures.requestPinWidget(), isTrue);
  });

  test('missing native host degrades safely during widget tests', () async {
    final reminder = await DeviceFeatures.getReminder();
    expect(reminder['enabled'], false);
    expect(await DeviceFeatures.setReminder(enabled: true), false);
    await DeviceFeatures.syncHabitReminders(habits: [], day: '2026-10-24');
    await DeviceFeatures.updateWidget(water: 0, stage: 1, done: 0,
        total: 0, day: '2026-10-24');
    expect(await DeviceFeatures.requestPinWidget(), false);
  });
}

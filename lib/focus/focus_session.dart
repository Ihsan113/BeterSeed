import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Foreground-only clock. Wall time is never used to calculate earned duration.
/// Checkpoints always recover paused, including after process death/reboot.
class FocusSession extends ChangeNotifier {
  FocusSession(
      {required this.habitId,
      required this.day,
      required this.targetMinutes,
      required this.baseSeconds,
      int elapsedMilliseconds = 0,
      int Function()? monotonicMilliseconds})
      : _elapsed = elapsedMilliseconds.clamp(0, 6000000000) {
    final watch = Stopwatch()..start();
    _clock = monotonicMilliseconds ?? () => watch.elapsedMilliseconds;
  }
  final String habitId, day;
  final int targetMinutes, baseSeconds;
  late final int Function() _clock;
  int _elapsed;
  int? _started;
  bool get running => _started != null;
  int get remainingBudgetMs =>
      ((targetMinutes * 60 - baseSeconds).clamp(0, 6000000)) * 1000;
  int get elapsedMilliseconds => (_elapsed +
          (_started == null ? 0 : (_clock() - _started!).clamp(0, 6000000000)))
      .clamp(0, remainingBudgetMs);
  int get elapsedSeconds => elapsedMilliseconds ~/ 1000;
  int get totalSeconds => (baseSeconds + elapsedSeconds).clamp(0, 6000000);
  bool get reachedTarget => totalSeconds >= targetMinutes * 60;
  void start() {
    if (running || reachedTarget) return;
    _started = _clock();
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _elapsed = elapsedMilliseconds;
    _started = null;
    notifyListeners();
  }

  void reset() {
    if (reachedTarget) {
      pause();
      return;
    }
    _started = null;
    _elapsed = 0;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'habitId': habitId,
        'day': day,
        'targetMinutes': targetMinutes,
        'baseSeconds': baseSeconds,
        'elapsedMilliseconds': elapsedMilliseconds
      };
  factory FocusSession.fromJson(Map<String, dynamic> json,
      {int Function()? monotonicMilliseconds}) {
    if (json['habitId'] is! String ||
        json['day'] is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(json['day']) ||
        json['targetMinutes'] is! int ||
        json['targetMinutes'] < 1 ||
        json['targetMinutes'] > 100000 ||
        json['baseSeconds'] is! int ||
        json['baseSeconds'] < 0 ||
        json['baseSeconds'] > 6000000 ||
        json['elapsedMilliseconds'] is! int ||
        json['elapsedMilliseconds'] < 0 ||
        json['elapsedMilliseconds'] > 6000000000) {
      throw const FormatException('Invalid focus checkpoint');
    }
    return FocusSession(
        habitId: json['habitId'],
        day: json['day'],
        targetMinutes: json['targetMinutes'],
        baseSeconds: json['baseSeconds'],
        elapsedMilliseconds: json['elapsedMilliseconds'],
        monotonicMilliseconds: monotonicMilliseconds);
  }
}

class FocusSessionStore {
  FocusSessionStore(this.account);
  final String account;
  Future<void> _queue = Future.value();
  String _key(String habitId) =>
      'betterseed_focus_v1_${base64Url.encode(utf8.encode(account))}_${base64Url.encode(utf8.encode(habitId))}';
  Future<FocusSession?> read(String id) async {
    await _queue.catchError((Object _) {});
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(id));
    if (raw == null) return null;
    try {
      return FocusSession.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(FocusSession session) {
    final json = jsonEncode(session.toJson());
    return _queue = _queue.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key(session.habitId), json))
        throw StateError('Focus checkpoint failed');
    });
  }

  Future<void> clear(String id) =>
      _queue = _queue.catchError((Object _) {}).then((_) async {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.remove(_key(id)))
          throw StateError('Focus checkpoint clear failed');
      });
}

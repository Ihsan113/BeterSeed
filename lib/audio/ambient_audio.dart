import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// One persistent music player for the entire app, and an independent SFX
/// player that does NOT request Android audio focus. Changing screens never
/// creates/destroys a player. All audio failures are non-fatal.
class AmbientAudio {
  final AudioPlayer _music = AudioPlayer();
  final AudioPlayer _effects = AudioPlayer();

  bool _foreground = true;
  bool _musicEnabled = true;
  bool _effectsEnabled = true;
  bool _disposed = false;
  bool _initialized = false;
  String? _customMusicPath;
  String? _playingSourceKey;
  Future<void> _musicQueue = Future<void>.value();
  Future<void> _effectQueue = Future<void>.value();

  Future<void> initialize({required bool music, required bool effects,
      String? customMusicPath}) async {
    _customMusicPath = customMusicPath;
    _musicEnabled = music;
    _effectsEnabled = effects;
    if (_initialized || _disposed) return;
    _initialized = true;
    try {
      // Keep focus with the long-running music. The short effects must not
      // steal it and cause the ambient track to pause/duck on Android.
      await _effects.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      await _effects.setReleaseMode(ReleaseMode.stop);
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(0.22);
    } catch (_) {
      // On unsupported platforms the app remains usable without audio.
    }
    await _syncMusic();
  }

  Future<void> _syncMusic() {
    // Serialize rapid foreground/toggle events; don't let an old pause run
    // after a newer resume. Each queued step checks current desired state.
    _musicQueue = _musicQueue.catchError((Object _) {}).then((_) async {
      if (_disposed || !_initialized) return;
      try {
        if (_foreground && _musicEnabled) {
          final desiredKey = _customMusicPath ?? 'default';
          if (_playingSourceKey != desiredKey) {
            // Switch tracks atomically in this serialized queue: never resume
            // the previous file after selecting the new one.
            await _music.stop();
            _playingSourceKey = null;
            final source = _customMusicPath == null
                ? AssetSource('audio/forest_piano.ogg')
                : DeviceFileSource(_customMusicPath!);
            await _music.play(source, volume: 0.22);
            _playingSourceKey = desiredKey;
          } else if (_music.state == PlayerState.paused) {
            await _music.resume();
          } else if (_music.state != PlayerState.playing) {
            final source = _customMusicPath == null
                ? AssetSource('audio/forest_piano.ogg')
                : DeviceFileSource(_customMusicPath!);
            await _music.play(source, volume: 0.22);
          }
        } else if (_music.state == PlayerState.playing) {
          await _music.pause();
        }
      } catch (_) {
        // The player can fail on a particular device; never crash the UI.
      }
    });
    return _musicQueue;
  }

  Future<void> setMusic(bool enabled) async {
    _musicEnabled = enabled;
    if (!_initialized && !_disposed) {
      await initialize(music: enabled, effects: _effectsEnabled);
    } else {
      await _syncMusic();
    }
  }

  Future<void> setCustomMusicPath(String? path, {bool forceRestart = false}) async {
    if (forceRestart) _playingSourceKey = null;
    _customMusicPath = path;
    await _syncMusic();
  }

  void setEffects(bool enabled) => _effectsEnabled = enabled;

  Future<void> setForeground(bool active) async {
    _foreground = active;
    if (!_disposed) await _syncMusic();
  }

  Future<void> effect(String name) {
    const allowed = {'tap', 'complete', 'plant', 'growth', 'water'};
    if (!allowed.contains(name) || _disposed || !_foreground || !_effectsEnabled) {
      return Future<void>.value();
    }
    _effectQueue = _effectQueue.catchError((Object _) {}).then((_) async {
      if (_disposed || !_foreground || !_effectsEnabled) return;
      try {
        await _effects.stop();
        await _effects.play(
          AssetSource('audio/$name.ogg'),
          volume: name == 'growth' ? 0.50 : (name == 'water' ? 0.40 : 0.32),
        );
      } catch (_) {}
    });
    return _effectQueue;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _musicQueue;
      await _effectQueue;
      await _music.dispose();
      await _effects.dispose();
    } catch (_) {}
  }
}

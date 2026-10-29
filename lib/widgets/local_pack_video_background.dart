import '../data/pack_downloads.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Bundled, muted pack video with an immediate still-frame fallback.
/// The controller exists only while its pack is equipped; it is paused on other
/// tabs, when animations are disabled, and when the app enters the background.
class LocalPackVideoBackground extends StatefulWidget {
  const LocalPackVideoBackground(
      {super.key,
      required this.animate,
      required this.video,
      required this.poster});
  final String video, poster;

  final bool animate;

  @override
  State<LocalPackVideoBackground> createState() =>
      _LocalPackVideoBackgroundState();
}

class _LocalPackVideoBackgroundState extends State<LocalPackVideoBackground>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.animate) _initialize();
  }

  Future<void> _initialize() async {
    if (_controller != null || _failed) return;
    final file = GardenPackFiles.fileFor(widget.video);
    final controller = file != null
        ? VideoPlayerController.file(file, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
        : VideoPlayerController.asset(widget.video,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) return;
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      if (!mounted || !identical(_controller, controller)) return;
      setState(() => _initialized = true);
      _syncPlayback();
    } catch (_) {
      // Decoding may be unavailable on emulators/older devices. The garden
      // stays functional with its baked first-frame poster.
      if (mounted && identical(_controller, controller)) {
        setState(() => _failed = true);
      }
    }
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !_initialized) return;
    if (widget.animate && _foreground) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  @override
  void didUpdateWidget(covariant LocalPackVideoBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video != oldWidget.video) {
      final previous = _controller;
      _controller = null;
      _initialized = false;
      _failed = false;
      previous?.dispose();
      if (widget.animate) _initialize();
    } else if (widget.animate && !oldWidget.animate && _controller == null) {
      _initialize();
    } else if (widget.animate != oldWidget.animate) {
      _syncPlayback();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    _controller = null;
    if (controller != null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image(
          key: const ValueKey('local-pack-video-poster'),
          image: GardenPackFiles.provider(widget.poster),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
        if (_initialized && !_failed && widget.animate && controller != null)
          Positioned.fill(
            child: ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.center,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

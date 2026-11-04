import '../ui/app_feedback.dart';
import '../l10n/app_localizations.dart';
import '../data/pack_downloads.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../platform/garden_wallpaper.dart';
import 'garden_life_painter.dart';
import 'live_wallpaper_effects.dart';

class GardenWallpaperPage extends StatefulWidget {
  const GardenWallpaperPage({
    super.key,
    required this.viewport,
    required this.mediaQuery,
    required this.garden,
    required this.assets,
    this.liveGarden,
    this.liveButterfly,
    this.livePalette = FireflyPalette.warm,
  });

  final Size viewport;
  final MediaQueryData mediaQuery;
  final Widget garden;
  final List<String> assets;
  final Widget? liveGarden;
  final String? liveButterfly;
  final FireflyPalette livePalette;

  @override
  State<GardenWallpaperPage> createState() => _GardenWallpaperPageState();
}

class _GardenWallpaperPageState extends State<GardenWallpaperPage>
    with SingleTickerProviderStateMixin {
  final _captureKey = GlobalKey();
  late final _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 120));
  Uint8List? _butterflyBytes;
  ui.Image? _butterflyImage;
  bool _live = false;
  bool _liveError = false;
  WallpaperCapabilities? _capabilities;
  WallpaperTarget _target = WallpaperTarget.home;
  bool _started = false;
  bool _ready = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _clock.dispose();
    _butterflyImage?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    try {
      final capabilities = await GardenWallpaper.capabilities();
      if (!mounted) return;
      setState(() => _capabilities = capabilities);
      Object? imageError;
      await Future.wait(widget.assets.map((asset) => precacheImage(
            GardenPackFiles.provider(asset),
            context,
            onError: (error, stack) => imageError = error,
          )));
      if (imageError != null) throw StateError('Garden image unavailable');
      if (capabilities.live && widget.liveButterfly != null) {
        try {
          final path = widget.liveButterfly!;
          final file = GardenPackFiles.fileFor(path);
          final data = file == null ? await rootBundle.load(path) : null;
          final bytes = file != null
              ? await file.readAsBytes()
              : data!.buffer
                  .asUint8List(data.offsetInBytes, data.lengthInBytes);
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 256);
          try {
            final frame = await codec.getNextFrame();
            if (!mounted) {
              frame.image.dispose();
              return;
            }
            _butterflyBytes = bytes;
            _butterflyImage = frame.image;
          } finally {
            codec.dispose();
          }
        } catch (_) {
          _liveError = true;
          if (_live)
            _error = 'Could not prepare wallpaper. Go back and try again.';
        }
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Could not prepare wallpaper. Go back and try again.');
    }
  }

  Future<Uint8List> _capture() async {
    await WidgetsBinding.instance.endOfFrame;
    final boundary = _captureKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint)
      throw StateError('Preview is not ready');
    // Bound native bitmap memory while retaining phone-resolution detail.
    final ratio = math.min(
        widget.mediaQuery.devicePixelRatio, 2560 / widget.viewport.longestSide);
    final image = await boundary.toImage(pixelRatio: ratio);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Unable to encode garden');
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Future<void> _apply() async {
    if (_busy ||
        !_ready ||
        _capabilities?.allowed != true ||
        _capabilities?.supported != true) return;
    final target = _target;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final png = await _capture();
      if (!mounted) return;
      if (_live) {
        final applied = await GardenWallpaper.previewLive(png, _butterflyBytes!,
            glow: widget.livePalette.glow.toARGB32(),
            spark: widget.livePalette.spark.toARGB32(),
            core: widget.livePalette.core.toARGB32());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(AppToast(
            content: Text(context.tr(applied
                ? 'Live garden wallpaper applied.'
                : 'Live wallpaper was not changed.'))));
        return;
      }
      await GardenWallpaper.setImage(png, target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(AppToast(
        content: Text(switch (target) {
          WallpaperTarget.home =>
            context.tr("Garden set as your home screen wallpaper."),
          WallpaperTarget.lock =>
            context.tr("Garden set as your lock screen wallpaper."),
          WallpaperTarget.both =>
            context.tr("Garden set on your home and lock screens."),
        }),
      ));
    } on PlatformException catch (error) {
      if (mounted)
        setState(() => _error = switch (error.code) {
              'WALLPAPER_NOT_ALLOWED' =>
                'This device does not allow wallpaper changes.',
              'WALLPAPER_UNSUPPORTED' =>
                'This wallpaper option is not supported on your device.',
              'WALLPAPER_BUSY' =>
                'A wallpaper change is already in progress. Try again shortly.',
              _ => 'Could not set wallpaper. Please try again.',
            });
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Could not set wallpaper. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = _capabilities;
    final unavailable = capabilities == null
        ? null
        : !capabilities.supported
            ? 'Wallpaper is available on supported Android phones.'
            : !capabilities.allowed
                ? 'Wallpaper changes are disabled by your device settings.'
                : null;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr("Garden wallpaper")),
          leading: IconButton(
            key: const ValueKey('wallpaper-close'),
            tooltip: context.tr("Back"),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: widget.viewport.width,
                        height: widget.viewport.height,
                        child: IgnorePointer(
                          child: ExcludeSemantics(
                            child: Stack(fit: StackFit.expand, children: [
                              RepaintBoundary(
                                key: _captureKey,
                                child: MediaQuery(
                                  data: widget.mediaQuery,
                                  child: SizedBox.expand(
                                    key: const ValueKey(
                                        'wallpaper-garden-viewport'),
                                    child: _live
                                        ? widget.liveGarden!
                                        : widget.garden,
                                  ),
                                ),
                              ),
                              if (_live && _butterflyImage != null)
                                CustomPaint(
                                    painter: LiveWallpaperEffects(_clock,
                                        _butterflyImage!, widget.livePalette)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .42,
                    maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (capabilities?.live == true &&
                          widget.liveGarden != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final live in [false, true])
                              ChoiceChip(
                                key: ValueKey(live
                                    ? 'wallpaper-mode-live'
                                    : 'wallpaper-mode-still'),
                                label: Text(context.tr(
                                    live ? 'Live wallpaper' : 'Still image')),
                                selected: _live == live,
                                onSelected: _busy
                                    ? null
                                    : (_) {
                                        setState(() {
                                          _live = live;
                                          _error = live && _liveError
                                              ? 'Could not prepare wallpaper. Go back and try again.'
                                              : null;
                                        });
                                        if (live &&
                                            !MediaQuery.disableAnimationsOf(
                                                context)) {
                                          _clock.repeat();
                                        } else {
                                          _clock.stop();
                                        }
                                      },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                          context.tr(_live
                              ? 'Butterflies and fireflies bring this garden snapshot to life. Apply again after your garden changes.'
                              : "A still image of your current garden. Set it again whenever your tree grows."),
                          textAlign: TextAlign.center),
                      if (_live) ...[
                        const SizedBox(height: 8),
                        Text(
                            context.tr(
                                'Android opens a preview and lets you choose the available screens. Animation pauses when hidden or in Battery Saver.'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: 12),
                      if (unavailable != null)
                        Text(context.tr(unavailable),
                            textAlign: TextAlign.center),
                      if (!_live &&
                          capabilities?.supported == true &&
                          capabilities?.allowed == true)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final target in WallpaperTarget.values)
                              if (target == WallpaperTarget.home ||
                                  capabilities!.lockScreen)
                                ChoiceChip(
                                  key: ValueKey(
                                      'wallpaper-target-${target.name}'),
                                  label: Text(switch (target) {
                                    WallpaperTarget.home =>
                                      context.tr("Home screen"),
                                    WallpaperTarget.lock =>
                                      context.tr("Lock screen"),
                                    WallpaperTarget.both => context.tr("Both"),
                                  }),
                                  selected: _target == target,
                                  onSelected: _busy
                                      ? null
                                      : (_) => setState(() => _target = target),
                                ),
                          ],
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(context.tr(_error!),
                            key: const ValueKey('wallpaper-error'),
                            textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const ValueKey('wallpaper-apply'),
                        onPressed: _ready &&
                                !_busy &&
                                (!_live || _butterflyBytes != null) &&
                                capabilities?.supported == true &&
                                capabilities?.allowed == true
                            ? _apply
                            : null,
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(_live
                                ? Icons.play_circle_outline
                                : Icons.wallpaper_outlined),
                        label: Text(_busy
                            ? context.tr("Setting wallpaper…")
                            : context.tr(_live
                                ? 'Preview live wallpaper'
                                : "Set wallpaper")),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'local_pack_video_background.dart';
import '../data/pack_downloads.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/garden_appearance.dart';
import '../data/shop_loadout.dart';
import '../logic/garden_scene_geometry.dart';
import 'garden_life_painter.dart';

/// A read-only preview: no ownership, progress or persistence callbacks.
class GardenPackPreview extends StatefulWidget {
  const GardenPackPreview({
    super.key,
    required this.title,
    required this.loadout,
    this.initialStage = 0,
    this.animate = true,
  });

  final String title;
  final ShopLoadout loadout;
  final int initialStage;
  final bool animate;

  @override
  State<GardenPackPreview> createState() => _GardenPackPreviewState();
}

class _GardenPackPreviewState extends State<GardenPackPreview>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late int _stage;
  late final AnimationController _motion;
  bool _foreground = true;
  bool get _animate =>
      widget.animate &&
      _foreground &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage.clamp(0, 5);
    _motion =
        AnimationController(vsync: this, duration: const Duration(seconds: 14));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    if (_animate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _foreground = state == AppLifecycleState.resumed);
    _syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = GardenAppearance(widget.loadout);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          key: const ValueKey('pack-preview-close'),
          tooltip: 'Close preview',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 650;
          final preview = Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedBuilder(
                    animation: _motion,
                    builder: (_, __) => _scene(appearance),
                  ),
                ),
              ),
            ),
          );
          final controls = SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                Text('Preview only · your garden stays unchanged',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('pack-preview-previous'),
                      tooltip: 'Previous growth stage',
                      onPressed:
                          _stage == 0 ? null : () => setState(() => _stage--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text('Growth stage ${_stage + 1} of 6',
                          key: const ValueKey('pack-preview-stage'),
                          textAlign: TextAlign.center),
                    ),
                    IconButton(
                      key: const ValueKey('pack-preview-next'),
                      tooltip: 'Next growth stage',
                      onPressed:
                          _stage == 5 ? null : () => setState(() => _stage++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _includedAsset('Butterfly', appearance.butterfly),
                    _includedAsset('Watering can', appearance.wateringCan),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 48,
                          child: CustomPaint(
                              painter: GardenLifePainter(.3,
                                  palette: appearance.fireflies)),
                        ),
                        const Text('Fireflies', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
          if (wide) {
            return Row(children: [
              Expanded(child: preview),
              Expanded(child: controls)
            ]);
          }
          return Column(children: [
            Expanded(child: preview),
            SizedBox(
                height: (constraints.maxHeight * .35).clamp(160.0, 240.0),
                child: controls),
          ]);
        }),
      ),
    );
  }

  Widget _includedAsset(String label, String asset) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GardenImage.asset(asset, width: 52, height: 48, fit: BoxFit.contain),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _scene(GardenAppearance appearance) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final area = Size(size.width, size.height * .66);
          final tree =
              GardenSceneGeometry.treeRect(area, ground: appearance.ground)
                  .shift(Offset(0, size.height * .16));
          return Stack(
            key: const ValueKey('pack-preview-scene'),
            fit: StackFit.expand,
            children: [
              if (appearance.video != null)
                LocalPackVideoBackground(
                  key: ValueKey(appearance.video), animate: _animate,
                  video: appearance.video!, poster: appearance.background)
              else
                GardenImage.asset(appearance.background, fit: BoxFit.cover),
              Positioned.fromRect(
                rect: tree,
                child: Transform.rotate(
                  angle: _animate
                      ? math.sin(_motion.value * math.pi * 2) * .005
                      : 0,
                  alignment: Alignment.bottomCenter,
                  child: GardenImage.asset(
                    appearance.treeAsset(_stage),
                    key: ValueKey('pack-preview-tree-$_stage'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              IgnorePointer(
                  child: CustomPaint(
                painter: GardenLifePainter(_animate ? _motion.value : .3,
                    palette: appearance.fireflies),
              )),
              Positioned(
                left: size.width * .20 +
                    (_animate ? math.sin(_motion.value * math.pi * 2) * 8 : 0),
                top: size.height * .5,
                child:
                    GardenImage.asset(appearance.butterfly, width: size.width * .14),
              ),
            ],
          );
        },
      );
}

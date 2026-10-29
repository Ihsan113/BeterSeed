import '../data/pack_downloads.dart';
import 'package:flutter/material.dart';

/// Full-screen scenic background that fills the viewport without blur.
/// The artwork is allowed to crop naturally so the garden stays immersive.
class AdaptiveGardenBackground extends StatelessWidget {
  const AdaptiveGardenBackground({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GardenImage.asset(
        asset,
        key: const ValueKey('full-background'),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

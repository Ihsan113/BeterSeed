# BetterSeed Batch 5 / v0.5.0

## Scope
1. Replace background `BoxFit.cover` with `BoxFit.contain`, with color-matched gradient letterboxing for unmatched aspect ratios. This shows the complete artwork without distortion/cropping.
2. Replace faint ambient painter with larger, high-contrast procedural butterflies and glowing fireflies on the Garden scene. The animations are mathematically periodic (no visible position jumps at the loop boundary), use the original 14s ticker and only render when Garden motion is enabled.
3. Replace top-right audio icon with Settings gear. Settings includes functioning music/SFX/motion switches and clear disabled future rows for Daily reminders and Home screen widget. Neither reminder scheduling nor widgets are implemented yet.
4. Keep garden tree positioned at fixed ground contact point; nothing in the animation moves the tree anchor.
5. Add widget tests for background fit, ambient painter presence, settings UI, and painter repaint conditions.

## Manual QA on phone
- Launch Garden, verify visible drifting fireflies and three butterflies. Watch for >14 s to ensure seamless path without teleports.
- Toggle Settings > Living garden off/on and confirm changes. Android reduced motion should be respected.
- Confirm whole forest background remains visible on short/wide and tall/narrow screens (matching gradient bands are expected as necessary).
- Observe root contact while watering, on tree-stage changes, and when navigating among all three tabs.
- Check audio survives opening/closing Settings and tab navigation.
- Ensure no newly requested permissions or services.

## Limits
- Build, analyzer and runtime QA require GitHub Actions / actual Android device (Flutter SDK not present in this container).

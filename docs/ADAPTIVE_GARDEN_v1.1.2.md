# BetterSeed v1.1.2 — Adaptive Garden & planting media

- Both Default Garden and Moonlight keep the sharp artwork complete with `BoxFit.contain`. Uncovered edge areas are covered by a blurred `BoxFit.cover` extension of the same image.
- The Moonlight background art now has an explicit central planting clearing, composited into the field for consistent visual planting.
- `PlantingGround` uses pre-calibrated anchors per theme. This is deterministic template-based placement, NOT machine vision or ML image detection.
- The root of each 512x512 sprite, soil contact plane, and watering target share `GardenSceneGeometry`, preventing mismatched offsets through app animations.
- The Android home-screen widget keeps its original emerald gradient shape with a stage-specific tree illustration. Theme-specific tree art still changes, but no full photo backgrounds are used.
- Widget background photo resources are removed from the source and the Android integration scripts to keep CI consistent.

## Device validation notes

Check on at least 320x640, 360x800, 393x873, and 600x960 devices and with larger Android text. In Garden, switch between Original and Moonlight, water a tree, change stage, and return to the app from the launcher widget. Visually inspect soil contact and any color seam on different screens.

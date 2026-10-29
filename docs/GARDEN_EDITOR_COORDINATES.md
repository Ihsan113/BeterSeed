# Garden editor: accurate preview and simpler controls

The editor previously sized the tree scene to the whole safe area. The saved
Garden instead places the scene between its header, progress, water and
navigation panels. A stored fractional offset therefore referred to different
scene dimensions, moving and resizing the tree after Save.

The preview now renders the same Garden layout at the live viewport size and
scales that entire viewport uniformly. It retains the original safe-area insets,
background crop, text scaling and 600-pixel content limit. Garden chrome is hidden
without removing its layout space; hidden controls cannot receive touch, keyboard
focus or accessibility actions. Drag deltas are measured in the scene's local
coordinates. The sprite and selection outline share `GardenSceneGeometry.treeRect`.
Existing per-background placement preferences require no migration.

The editor keeps Save and Cancel at the top, with controls outside the preview:

- **Preview:** enlarged, read-only view.
- **Position:** drag the tree, or adjust one of Size, Horizontal and Vertical.
  Reset applies only to the current background's position and size.
- **Assets:** one category at a time, with named thumbnails and a selection mark.

Controls scroll on small screens and with enlarged system text; wide layouts
place controls beside the preview. Cancel discards the entire draft.

Regression tests in `test/asset_editor_test.dart` compare actual rendered tree
bounds before editing, during a scaled drag, after Save and after app restart.
They cover Default, Moonlight and Sakura at 320×640, 393×852 and 800×1000, safe-area
insets, 1.8× text, asset mixing, per-background placement, Reset, Cancel and
read-only preview. Run `flutter analyze` and `flutter test --reporter expanded`.

# BetterSeed Golden Autumn Integration — v1.4.9+46

Integrasi ini memasang **Golden Autumn Garden Pack** ke base source `BeterSeed-main.zip`.

## Yang dipasang

- `assets/videos/autumn_garden_loopy_8s.mp4` — background loop lokal 8 detik.
- `assets/images/backgrounds/golden_autumn_garden.webp` — fallback statis/poster frame.
- `assets/images/shop/golden_autumn_pack_thumb.webp` — thumbnail shop.
- `assets/images/trees/skins/golden_autumn/` — 6 stage sprite pohon.
- `assets/images/effects/amber_butterfly.png`
- `assets/images/effects/maple_watering_can.png`
- `native/android/res/drawable-nodpi/widget_autumn_tree_0.webp` s.d. `widget_autumn_tree_5.webp`

## Wiring kode

- `lib/widgets/autumn_video_background.dart`
  - Player lokal dengan fallback gambar statis.
  - Pause otomatis saat app background atau motion animasi dimatikan.
- `lib/widgets/shop_page.dart`
  - Menambah `ShopLoadout.autumnPack`.
  - Menambah klaim/equip untuk **Golden Autumn Garden**.
- `lib/main.dart`
  - Menambah state kepemilikan Autumn.
  - Menambah integrasi animated background, asset editor, dan backup/save.
- `lib/backup/backup_snapshot.dart`
  - Menambah `ownedAutumn`.
- `lib/logic/garden_scene_geometry.dart`
  - Menambah `PlantingGround.autumnGarden` supaya sprite pohon lebih pas ke area tanah di background.
- `native/android/kotlin/BetterSeedWidget.kt`
  - Widget kini mendukung theme `golden_autumn`.

## Validasi statis yang dijalankan di container

- `python3 -m unittest discover -s scripts -p 'test_*.py'`

Semua tes Python lulus di container.

# BetterSeed v1.4.2+39 — Sakura Garden Set Integration / Handoff

## Tentang rilis

Basis: **BetterSeed v1.4.0+38**. Paket gambar Sakura lama v1.4.1 yang ditolak
**TIDAK digunakan**. Seluruh gambar tanaman dan efek yang dipakai berasal dari
file asli hasil generasi baru; sumber foto di Shop berasal dari video milik pengguna.
Tidak ada potongan dari poster concept-art atau file temporer yang dipaketkan.

## Aset final dan lokasi

| Tipe | Path | Keterangan |
|---|---|---|
| Garden video | `assets/videos/sakura_loop_5s.mp4` | Upload pengguna, H.264, 1080x1920, 30fps, 5s; mute loop |
| Garden static poster | `assets/images/backgrounds/sakura_garden.webp` | Frame pertama dari video, fallback |
| Tree sprites | `assets/images/trees/skins/sakura/stage_{0..5}_*.png` | 6 file RGBA 512², masing-masing satu generasi, akar dinormalisasi |
| Sakura butterfly | `assets/images/effects/butterfly_sakura.png` | Gambar generasi asli, RGBA 512² |
| Sakura watering can | `assets/images/effects/watering_can_sakura.png` | Gambar generasi asli, RGBA 512² |
| Android widget sprites | `native/android/res/drawable-nodpi/widget_sakura_tree_{0..5}.webp` | 6 RGBA WebP 340x320 dari sprite Sakura yang sama |
| Shop thumbnail | `assets/images/shop/sakura_pack_thumbnail.webp` | Thumbnail dari frame pertama video |
| Metrics | `docs/SAKURA_ASSET_METRICS.json` | Posisi visual alpha>=64 berdasarkan normalisasi |

Tidak ada gambar petals terpisah di runtime. Kupu-kupu dan fireflies Flutter sudah
menghasilkan efek sederhana dan ini sengaja untuk menjaga hemat memori.

## Tata cara pemakaian

1. `Shop > Sakura Blossom Garden > Claim Free`, lalu masuk ke `My Collection > Use`.
2. Semua kosmetik Garden dan widget berubah bersama saat Sakura dipakai.
3. Default dan Moonlight tetap independen dan dapat dipilih kapan pun.
4. Kepemilikan gratis Sakura dan pilihan pack tetap tersimpan di SharedPreferences,
   termasuk snapshot cadangan SAF. Tidak butuh login atau backend.

## Video / sumber daya

- Video diputar lewat `video_player` dan dikemas secara lokal (bukan streaming).
- Video tidak mengeluarkan suara, sehingga tidak bersaing dengan musik ambient.
- Video dijeda saat berada di tab selain Garden, aplikasi di-background, atau animasi
  Garden dimatikan/reduced motion. Dalam kondisi itu poster tetap terlihat.
- Jika inisialisasi video gagal, aplikasi menampilkan frame statis dan fungsi
  kebiasaan, tema dan backup tetap dapat dipakai.
- Render memakai `BoxFit.cover`, sama seperti Default/Moonlight; cropping normal
  pada perangkat dengan rasio lebih lebar/tinggi.
- Loop seamless perlu dicek secara visual pada perangkat fisik; frame video yang
  diunggah tetap tidak diubah waktunya oleh proyek ini.

## Kalibrasi sesuai THEME_PACK_ASSET_STANDARD.md

Sprite keenam tahap masing-masing dipusatkan sekitar `x=256` dan batas bawah
siluet alpha64 disamakan dengan referensi Default. Lebar sprite pada tahap awal
memang lebih sempit (bibit dan tunas Sakura) karena desain spesiesnya, dan
stage 4 memiliki kanopi lebih rendah dari Default; bukan efek ukuran file.

`GardenSceneGeometry.groundBottom` menambah `PlantingGround.sakuraGarden`
dengan fraksi scene **0.055**. `rootTarget`, bayangan, aliran air memakai geometri
scene yang sama. Koordinat pada berbagai jenis HP tetap perlu uji visual setelah
APK dibangun (tidak ada pengukuran otomatis dari video saat runtime).

## Uji rilis sebelum distribusi

- `python3 -m unittest discover -s scripts -p 'test_*.py' -v`
- `python3 scripts/verify_visual_assets.py`
- `python3 scripts/verify_android_integration.py --sources`
- `flutter pub get`
- `flutter analyze`
- `flutter test --reporter expanded`
- `flutter build apk --release` via GitHub Actions dengan sertifikat lama.
- APK terpasang: klaim free, equip, restart, periksa loop dan sinkronisasi widget;
  juga normal vs focus mode pada layar 320x640 dan 412x915.

Catatan: **sumber ini belum dibuild langsung** di lingkungan tanpa Flutter SDK;
perlu konfirmasi GitHub Actions dan perangkat Android untuk validasi final.

## Hotfix v1.4.3+40

- Sprite pohon Sakura dikalibrasi ulang pada scene Garden: sedikit diperkecil dan dinaikkan supaya base mound duduk pas di area tanam bundar.
- Tidak ada perubahan aset; hotfix ini murni penyesuaian layout/render.

## v1.4.4 — Live Garden Asset Editor / Position Fix

The editor opens from **Shop → My Collection → Edit Garden Assets** and uses
exactly the same live Garden scene as Focus mode. Only the tree can be moved and
resized (drag, horizontal/vertical sliders, scale slider, reset). Background,
tree skin, butterfly, watering can, and firefly variants can be switched from
already-claimed sets. No external image picker or arbitrary file injection.

Sakura's original bottom-position mistake was fixed: larger `bottom` values
raise a Flutter `Positioned` widget. The new planting ground fraction is `.14`
with a smaller `.02 * size` lift subtraction. Coordinates are normalized
fractions of the scene size, saved independently per background in
`betterseed_tree_placements_v1`. Draft changes are not saved until **Save**;
**Cancel** discards them. Manual JSON backups include optional cosmetics and
placement fields without changing the older backup format's version or
invalidating older files.

Expected QA: stage 1 and 6, tall/short devices, both garden and Focus Mode,
Drag & Save, Cancel, Reset, and background mix; verify watering effects and
native widget still follow the chosen tree stage/skin.


## UI refresh v1.4.7+44

- Halaman Garden Asset Editor dirancang ulang mengikuti referensi UI yang lebih modern.
- Picker aset sekarang berbasis thumbnail visual per kategori.

# Perbaikan tes wallpaper CI — 29 Oktober 2026

Basis source: GitHub main `ffc8d5a0b6c806a05f4e2b66b9f0bc6a81baf6d3`, BetterSeed 1.7.0+58.
Run yang diperiksa: https://github.com/Ihsan113/BeterSeed/actions/runs/40855554922/job/123385492053

## Penyebab

Run berhenti di langkah Unit tests: `Settings opens a still, clean wallpaper of the saved garden` melempar `Bad state: Too many elements` pada `tester.renderObject` di baris 178. Kegagalan yang sama berhasil direproduksi secara lokal sebelum perubahan.

Pencarian global dengan key `editor-draggable-tree` dapat menemukan pohon taman utama sekaligus pohon preview selama transisi halaman. RenderBox yang dibutuhkan tes adalah pohon di dalam viewport capture wallpaper. Key lokal yang sama pada dua subtree sah; tes harus memilih subtree yang dimaksud.

## Perubahan

- Pilih halaman wallpaper, viewport capture, lalu pohon dengan `find.descendant`. Pastikan setiap target tunggal sebelum membaca RenderBox. Pemeriksaan tidak mengambil hasil pertama secara sembarang.
- Pertahankan perbandingan posisi, ukuran, serta pemeriksaan tidak adanya video pada gambar wallpaper.
- Gunakan Original Garden yang dibundel bersama APK, dengan posisi dan skala tersimpan non-default. Source 1.7 mengunduh aset premium sesuai kebutuhan; fixture Sakura tanpa instalasi pack sebelumnya hanya menguji tampilan fallback, bukan koordinat Sakura tersimpan.
- Sinkronkan `pubspec.lock` dengan dependensi yang sudah dideklarasikan source terbaru: archive 3.6.1, crypto dan path_provider sebagai dependensi langsung. Tidak ada perubahan batas versi dalam pubspec.yaml.

## Validasi lokal

Flutter 3.47.8 / Dart 3.13.7:

- Sebelum perbaikan, tes wallpaper tersebut gagal dengan stack trace yang sama dengan GitHub Actions.
- Setelah perbaikan, seluruh **132 tes Flutter lulus**.
- `flutter analyze --no-pub`: tidak ada masalah.
- Seluruh **60 tes Python lulus**.
- Verifikasi aset, source native, serta integrasi Android lengkap lulus.
- `flutter build apk --debug --no-pub`: berhasil.
- `git diff --check`: bersih.

Validasi ini dilakukan di workspace. Run GitHub yang ditautkan tetap merupakan run gagal sebelumnya; workflow perlu berjalan lagi setelah perubahan dipush. Build AAB/APK release dengan sertifikat produksi belum dijalankan untuk perubahan ini. Tidak ada perubahan pada kode runtime aplikasi, backend/VPS, aset CDN, workflow atau konfigurasi signing.

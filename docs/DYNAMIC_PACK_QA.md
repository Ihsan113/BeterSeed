# Dynamic Garden Packs — hasil QA 28 Oktober 2026

Source dasar GitHub `bc16a2d` (main diperiksa ulang dengan fetch), ditandingkan dengan ZIP `AdminVPS-Safe-20261028-083945.zip`. Implementasi app **1.6.0+57**, backend **1.2.0**. Pemeriksaan dilakukan pada workspace lokal terisolasi; tidak ada deploy produksi. Commit dan publikasi source/ZIP dilakukan setelah persetujuan pengguna.

## Pemeriksaan yang benar-benar dijalankan

| Pemeriksaan | Hasil |
|---|---|
| `npm run check` dan `npm run build` di server | Lulus |
| `TEST_MYSQL_PORT=33068 npm test`, MySQL **8.0.46** nyata | **25 tes lulus**, tidak ada yang dilewati |
| `flutter analyze --no-pub` | Tidak ada masalah |
| `flutter test --no-pub` | **140 tes lulus** |
| `python -m unittest discover -s scripts -p 'test_*.py'` | **58 tes lulus** |
| Chromium / Playwright, backend nyata dan database UI uji terpisah | Lulus login/TOTP, sesi reload/logout, pengguna, paginasi/pencarian, koreksi koin, audit, Garden Pack Manager, tampilan mobile dan CSP |
| `flutter build apk --debug --no-pub` | Berhasil; APK `com.betterseed.app`, versionCode 57, versionName 1.6.0 |
| Pemeriksaan arsip APK | AssetManifest serta seluruh 18 tahap pohon premium tersedia; tes Flutter juga memeriksa seluruh aset pada registry |
| Docker build backend dan smoke HTTP container | Berhasil; `/health`, `/ready`, `/admin`, script/CSS admin dan `/v1/shop/catalog` merespons 200 |
| ZIP source + pemeriksaan checksum/isi | Dibuat dengan `scripts/package_server.py`; diperiksa ulang menggunakan `--check` |

Build Docker di workspace memakai CA proxy hanya sebagai BuildKit secret pada Dockerfile sementara untuk akses npm. Dockerfile repository tetap memakai trust store normal; CA workspace tidak dimasukkan ke source/image runtime. APK yang dibangun adalah debug untuk pemeriksaan kompilasi, bukan AAB release bertanda tangan produksi.

## Cakupan regresi dan keamanan

- Migrasi diulang, harga admin dan entitlement lama tetap utuh. ID baru `crystal_forest` dibuat melalui API admin tanpa whitelist backend.
- Delapan permintaan pembelian bersamaan memotong saldo sekali; acquisition menyimpan harga aktual. Revoke dukungan lalu pembelian ulang tidak berbenturan dengan ledger lama.
- Premium→Free, klaim gratis dengan saldo negatif setelah refund, Free→Premium, hidden dan retired mempertahankan hak pemilik. Pembeli baru ditolak pada status tidak tersedia.
- Quote basi/revisi berubah, perubahan harga bersamaan dengan pembelian, APK lama tanpa quote, dan minimum build ditolak tanpa debit yang tidak disetujui.
- Auth admin terpisah, cookie Secure/HttpOnly, origin/CSRF, input invalid, invariants Original Garden dan audit diuji. Browser memastikan markup berbahaya tampil sebagai teks; checkbox konfirmasi wajib dan pack ID tidak bisa diubah.
- Shop mencocokkan aset lengkap/minimum build/status, menyimpan cache per API origin dan menolak transaksi offline. Cache/response duplikat rusak tidak mengganti metadata yang valid. Koleksi hidden/retired tetap dapat dipakai offline.
- Restore backup lama tidak memberikan kepemilikan dari flag file; mapping valid memakai entitlement yang diberikan. ID pack baru tetap lolos decode. Sync menerima ID kosmetik/placement baru tanpa memberikan kepemilikan; pergantian akun tidak membawa wallet akun sebelumnya.
- Tes existing editor koordinat, preview locked, mixed cosmetics, enam tahap pohon, wallpaper, sesi persisten, konflik sync, Google Play idempotency/refund dan jembatan widget tetap lulus. Registry diperiksa terhadap AssetManifest dan versionCode; setiap field kosmetik mempunyai ID kepemilikan unik.

## Pemeriksaan yang masih harus dilakukan operator pada kanal internal

- Login Google, Gmail Relay, billing/refund Google Play dan RTDN dengan konfigurasi nyata. Provider eksternal ditiru dalam tes backend; tidak ada email atau pembayaran nyata yang dikirim.
- Instalasi APK/AAB bertanda tangan dengan keystore proyek yang sudah dipakai; gunakan API URL dan Google Web Client ID yang sama dengan konfigurasi server. AAB release produksi belum dibuat di workspace ini.
- Uji widget pada launcher HP, lifecycle video, offline/online dan perpindahan akun di perangkat nyata. Kompilasi Kotlin, asset packaging dan tes bridge sudah dilakukan; tidak ada pengujian launcher perangkat fisik.
- Backup dan uji migrasi pada salinan database produksi, lalu deploy backend dahulu sesuai UPGRADE.md. Jangan mengganti kunci, SKU, image database atau volume yang sudah digunakan. Harga/status pada database produksi belum diubah.

`crystal_forest` hanya contoh kontrak dan fixture pengujian, bukan pack baru yang telah dilengkapi artwork atau diaktifkan untuk pengguna.

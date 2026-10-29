# BetterSeed — Garden Pack On-demand (App build 58, v1.7.0)

## Apa yang masuk ke APK/AAB

- **Bundled ke Flutter install:** seluruh gambar runtime **Original Garden (Default)**, seluruh thumbnail 10 tema, aset UI/audio/kebijakan aplikasi, dan `assets/pack_downloads.json`.
- **Tidak masuk ke APK/AAB:** background, keenam sprite tahapan, watering can, butterfly, dan video sembilan pack pilihan lain. Semua file ini diunduh satu pack per permintaan pengguna.
- Pengguna tidak dipaksa unduh semuanya; tombol **Download · x.x MB**, progress, status Installed, dan Remove tersedia di Shop/Koleksi. Download **tidak memberi entitlement**: ownership/koin tetap diverifikasi oleh API lama.
- Saat gambar pack pernah dipilih tapi file belum diunduh atau sudah dihapus, taman tampil menggunakan Default secara aman; profil dan status kepemilikan tidak dihapus.
- Widget Android dapat membaca file tahap tanaman yang terpasang dari penyimpanan internal, dengan fallback ke Default. Video tetap diam/mute dan menggunakan poster jika motion dimatikan atau decoder gagal.
- Rancangan memakai **ZIP statis via HTTPS CDN**, **bukan Google Play Asset Delivery**. Format **AAB** dari Google Play hanya memecah APK menurut perangkat; **tidak otomatis menyediakan download per pack**. Pilihan CDN sengaja dibuat agar endpoint/DB backend VPS yang sudah berjalan tidak perlu diubah.

## Checklist pemasangan hosting (tidak perlu modifikasi VPS/API BetterSeed)

1. Siapkan **static object storage/CDN HTTPS** (mis. R2, S3, hosting file statis) pada domain yang dapat diakses publik. Jangan tempatkan konten ini di endpoint API yang memakai cookie/token autentikasi.
2. Ekstrak arsip deliverable `BetterSeed_Garden_Packs_CDN_v1.zip`. Upload **kesembilan file `*-r1.zip`** ke satu direktori publik CDN, tanpa mengubah nama/isi ZIP. Contoh alamat final: `https://cdn.contoh.com/betterseed/packs/ocean_coral-r1.zip`.
3. Pastikan URL tersebut mengembalikan **HTTP 200**, byte ZIP yang sama, dan header `Content-Type: application/zip` (atau `application/octet-stream`), tidak dialihkan login, tidak mengubah konten. Aplikasi **memverifikasi ukuran dan SHA-256** menurut manifest yang dibundel.
4. Di repository GitHub buka **Settings → Secrets and variables → Actions → Variables**, tambah `BETTERSEED_PACK_CDN_BASE_URL` dengan nilai `https://cdn.contoh.com/betterseed/packs` **tanpa slash di akhir**. Keep existing `BETTERSEED_API_URL`, keystore, SHA-1, dan secrets lama tetap sama.
5. Push source ZIP app dan jalankan workflow **BetterSeed Android APK + Google Play AAB**. Workflow mengirim parameter ini ke **dua build** APK dan AAB. Jika build lokal gunakan:

   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter build appbundle --release \
     --dart-define=BETTERSEED_API_URL=https://api.betterseed.my.id \
     --dart-define=BETTERSEED_PACK_CDN_BASE_URL=https://cdn.contoh.com/betterseed/packs
   ```

   Perhatikan: URL hanya **contoh**. Gunakan URL CDN milik Anda sendiri; Jangan membuat rilis publik dengan URL kosong jika mengharapkan tombol download bekerja.
6. Unggah AAB yang telah ditandatangani oleh **upload key permanen lama** ke Google Play. Paket download tidak mengubah package ID, keystore, atau SHA-1; penandatanganan tetap melalui workflow.
7. Setelah file CDN **live** dan app build **58+** tersedia, aktifkan katalog pack lewat **panel admin yang sudah ada**. Jangan aktifkan di katalog sebelum CDN siap.

## Daftar ZIP untuk upload CDN (ukuran ditampilkan di UI)

| Pack ID | Arsip | Ukuran perkiraan | Video |
|---|---|---:|---|
| `moonlight` | `moonlight-r1.zip` | 5.3 MiB | Tidak (pakai background statis) |
| `sakura` | `sakura-r1.zip` | 5.3 MiB | Ya |
| `golden_autumn` | `golden_autumn-r1.zip` | 21.7 MiB | Ya |
| `celestial_cloud` | `celestial_cloud-r1.zip` | 8.1 MiB | Ya |
| `ocean_coral` | `ocean_coral-r1.zip` | 8.4 MiB | Ya |
| `desert_oasis` | `desert_oasis-r1.zip` | 8.1 MiB | Ya |
| `fairy_lantern` | `fairy_lantern-r1.zip` | 8.7 MiB | Ya |
| `aurora_crystal` | `aurora_crystal-r1.zip` | 8.7 MiB | Ya |
| `enchanted_mushroom` | `enchanted_mushroom-r1.zip` | 11.6 MiB | Ya |

Ukuran adalah **MiB (1024×1024 byte)**. Ini angka ZIP unduhan, bukan total ruang setelah ekstraksi. Saat pemasangan dibutuhkan ruang sementara untuk file ZIP sekaligus ekstraksi. Moonlight memang tidak memiliki video dalam source; ia tetap mendukung gambar background statis.

## Panel admin backend yang sudah tersedia (tanpa deployment backend baru)

Server yang ada menyediakan **Admin → Garden Packs** dan `GET /v1/shop/catalog`, serta API admin `POST /admin/api/packs` dan `PATCH /admin/api/packs/:packId`. Di panel admin, buat entri yang `packId`-nya **persis** sama dengan ID tabel, isi `name`, `description`, `accessType` (`free` atau `premium`), `priceCoins` (0 untuk gratis; positif untuk premium), `status` (`draft` saat disiapkan lalu `active` setelah siap), `minimumAppBuild: 58`, `displayOrder`, dan alasan perubahan (`reason`). Panel menangani autentikasi/CSRF, jadi **lebih aman input manual melalui panel** daripada menyalin request langsung.

- **Template data** enam tema baru di `docs/admin_pack_templates.json` (hanya untuk input manual — **bukan** unggahan otomatis; sesuaikan harga koin sesuai strategi Anda).
- Pack lama `moonlight`, `sakura`, `golden_autumn` **jangan dibuat ulang** jika sudah ada dalam database; cukup pakai status/metadata yang saat ini tersimpan.
- Harga & entitlement **tetap dikelola backend**. Aplikasi hanya mengunduh bytes dari storage publik **setelah user memiliki pack**, sehingga video dapat didistribusikan bebas namun membuka pack premium tidak bisa dilakukan hanya dari ZIP.
- Untuk **mengubah file pack** di masa depan: upload ZIP revision baru, perbarui `assets/pack_downloads.json` (`file`, `sizeBytes`, `sha256`, `revision`), bangun ulang APK/AAB, lalu jalankan upgrade aplikasi. Jangan mengganti isi ZIP pada URL lama dengan checksum baru tanpa app update.

## Pemeriksaan kualitas / batasan

- Script: `python3 scripts/verify_delivery_archives.py --directory /path/to/nine/zips` mengecek nama, SHA-256, ukuran, path whitelist, jumlah enam tahap, dan format file.
- `python3 -m unittest discover -s scripts -p 'test_*.py'` memeriksa kontrak Python sumber; `python3 scripts/verify_android_integration.py --sources` memeriksa Kotlin/resource.
- **Tidak ada Flutter SDK di lingkungan pengeditan:** source sudah dipersiapkan, tetapi `flutter analyze`, `flutter test`, AAB release, dan pengujian di ponsel **harus dijalankan lewat GitHub Actions** sebelum dirilis.
- Pengecekan posisi tanah dan corong mengacu pratinjau komposit PNG. Efek animasi/screen ratio pada ponsel harus dicek lagi di 360×640, 393×851, dan mode landscape/fokus. Untuk posisi kustom yang pernah disimpan user di editor, preferensi lama bisa mengubah posisi visual, sehingga kalibrasi ideal sebaiknya dicek dengan posisi reset.
- Paket yang belum ada di katalog admin tetap memperlihatkan **thumbnail SOON** di Shop; file CDN dan pemasangan app tidak otomatis membuat produk baru di backend.

## Penanganan server

**Tidak ada file di `server/` yang diedit oleh perubahan ini.** Rencana upload CDN hanyalah hosting statis terpisah. Backend billing, entitlements, MySQL, dan alur login tidak disentuh.

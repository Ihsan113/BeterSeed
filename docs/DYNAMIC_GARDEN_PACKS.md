# Dynamic Garden Packs — app 1.6.0+57 / server 1.2.0

Katalog komersial berada di MySQL. Aset dan preset kosmetik berada di APK. Tidak ada URL aset dari API dan tidak ada download gambar/video baru. ID lama `default`, `moonlight`, `sakura`, `golden_autumn` tetap sama.

## Menambahkan `crystal_forest`

1. Siapkan aset lokal: background/poster, enam pohon transparan, butterfly dan watering can; opsional video loop dan thumbnail. Optimalkan ukuran/alpha supaya frame editor dan penggunaan memori tetap stabil. Simpan di `assets/`; daftarkan **setiap direktori** baru dalam `pubspec.yaml` (direktori Flutter tidak rekursif).
2. Tambahkan satu `LocalGardenPack` pada `GardenPackRegistry.packs` di `lib/data/garden_pack_registry.dart`. Contoh (path hanya ilustrasi; aset Crystal Forest belum dibuat dalam rilis ini):

```dart
LocalGardenPack(
  id: 'crystal_forest', name: 'Crystal Forest',
  loadout: ShopLoadout(
    treeSkinId: 'crystal_tree', backgroundId: 'crystal_garden',
    butterflyId: 'crystal_butterfly', wateringCanId: 'crystal_can',
    fireflyId: 'crystal_fireflies',
  ),
  background: 'assets/images/backgrounds/crystal_garden.webp',
  treeFolder: 'assets/images/trees/skins/crystal_forest',
  treeExtension: 'webp',
  butterfly: 'assets/images/effects/crystal_butterfly.png',
  wateringCan: 'assets/images/effects/crystal_can.png',
  // Optional video/thumbnail; ground and fireflies have defaults.
),
```

Nama file pohon: `stage_0_seed` sampai `stage_5_legendary`, dengan tahap `sprout`, `sapling`, `young`, `mature` di antaranya. Gunakan ID kosmetik unik per field; jangan memakai ID/asset pack lain sebagai pemilik aset baru. ID kosmetik lowercase/underscore maksimal 80 karakter, pack ID maksimal 40. `default` khusus pack Original.

3. Pilih `ground` yang sesuai titik tanah poster dan `fireflies` sesuai warna; tambahkan konfigurasi geometri bila artwork memerlukannya. Preview, editor, render taman dan wallpaper memakai mapping yang sama. Widget menerima path pohon lokal via MethodChannel, membaca hanya `flutter_assets/assets/images/…` dengan validasi path dan decoding maksimum 256px; tidak perlu edit whitelist Kotlin atau menambah resource native untuk pack baru. Resource widget lama tetap sebagai fallback.
4. Naikkan versionCode di `pubspec.yaml` **dan** `GardenPackRegistry.appBuild` bersama-sama. Jalankan pengujian mapping/AssetManifest, editor, enam tahap preview, lifecycle video dan widget launcher. Shop memeriksa semua aset mapping melalui AssetManifest sebelum menawarkan pembelian.
5. Admin → Garden Pack Manager → Tambah pack. Gunakan ID yang sama, status Draft, minimum build sesuai APK pertama, nama/deskripsi, harga dan urutan. Free wajib harga 0; Premium minimal 1. ID permanen/read-only setelah dibuat. Tidak tersedia delete; gunakan Retired agar histori dan entitlement tetap utuh.
6. Setelah APK siap pada kanal rilis, ubah menjadi Active. APK yang tidak mengenali ID, terlalu tua, atau kehilangan aset tidak menawarkan pembelian. Penambahan ID tidak membutuhkan perubahan kode backend atau dashboard.

## Harga dan kepemilikan

- GET `/v1/shop/catalog` publik mengembalikan `{version:1,packs:[...]}`. Field setiap pack: `packId,name,description,accessType,priceCoins,status,minimumAppBuild,displayOrder,revision`. Draft hanya ada pada API admin. Hidden/Retired tersedia sebagai metadata bagi koleksi, tidak untuk pembeli baru.
- POST `/v1/shop/unlock` membutuhkan bearer session dan body `{packId,expectedPrice,catalogRevision,appBuild}`. Harga/revisi harus tepat cocok. `409 catalog_changed` mengembalikan metadata baru di `details.pack`; app menyegarkan katalog dan pengguna harus mengonfirmasi lagi, tidak melakukan retry debit otomatis.
- Transaksi mengunci user lalu baris katalog; memeriksa entitlement yang sudah ada, mengurangi saldo sekali, menambah entitlement, acquisition dengan harga/revisi aktual, serta ledger. Retry pengguna yang sudah memiliki pack mengembalikan wallet tanpa debit. Klaim Free juga tercatat permanen; `default` dimiliki secara implisit.
- Premium→Free tidak mengembalikan koin transaksi lama. Free→Premium tidak mencabut klaim lama. Harga/status/build baru tidak mencabut entitlement. Admin tetap bisa melakukan revoke individual melalui fitur dukungan lama (terpisah dari mengubah status katalog).
- Aturan Play verification, SKU, token binding, consume-after-commit, rekonsiliasi dan refund tetap digunakan. Ledger acquisition memakai ID per transaksi agar revoke lalu beli ulang tidak bertabrakan dengan key pembelian terdahulu.
- Cache katalog terpisah per URL API, berisi metadata tanpa token. Cache rusak/duplikat diabaikan; kegagalan API menampilkan status offline dan menonaktifkan transaksi. Harga cache tetap harus divalidasi server. Koleksi mengikuti wallet akun yang tersimpan lokal; backup tidak memberikan hak premium.
- Backup v1 lama tetap terbaca. Flag `owned*` di file tidak menjadi bukti entitlement; pemulihan tampilan membutuhkan pack yang sudah terverifikasi untuk akun tersebut. Data guest lama pada perangkat yang sama tetap dipertahankan sebagai kompatibilitas lokal, bukan bukti pembelian akun online. Kosmetik valid dari APK lebih baru dirender dengan fallback aman dan dipertahankan selama sync progres; memilih tampilan baru secara eksplisit menggantinya.

## API admin

`GET /admin/api/packs` menambahkan owners/timestamps. `POST /admin/api/packs` menerima metadata, packId dan reason; `PATCH /admin/api/packs/:packId` menerima metadata lengkap, expectedRevision dan reason. Semua memakai sesi admin terpisah; mutasi membutuhkan origin yang benar dan CSRF token. Tidak ada endpoint admin publik atau pengubahan pack ID. Konflik edit menghasilkan 409; refresh dan periksa lagi. Audit memuat metadata sebelum/sesudah. Nama/deskripsi ditampilkan sebagai teks, bukan HTML. Jumlah pemilik dihitung dari entitlement; Original dimiliki semua pengguna secara implisit.

## Build dan validasi

Backend harus dipasang **sebelum** aplikasi (lihat UPGRADE.md). Jangan mengganti signing key/Play package atau konfigurasi OAuth.

```sh
flutter pub get
python3 scripts/generate_android.py
python3 scripts/configure_play_sdk.py
python3 scripts/prepare_android.py
flutter analyze
flutter test
# Setelah konfigurasi signing lama tersedia seperti workflow repo:
flutter build appbundle --release \
  --dart-define=BETTERSEED_API_URL=https://api.domain-anda \
  --dart-define=BETTERSEED_GOOGLE_WEB_CLIENT_ID=web-client-id-anda
```

Gunakan workflow `.github/workflows/android-apk.yml` untuk signing/verifikasi AAB dengan secret yang sudah ada. Jangan menaruh service-account, API key relay, database dump atau keystore dalam commit/ZIP. Endpoint API dan Web OAuth Client ID adalah konfigurasi build; token/kunci server tetap di environment privat.

Backend lokal: `npm ci && npm run check && npm run build`, migrasikan database tes terisolasi, lalu `TEST_MYSQL_PORT=33068 npm test` dari `server/` (fixture memakai betterseed_test dan password tes). `python3 scripts/package_server.py` menghasilkan ZIP source tanpa kredensial; `--check` memeriksa isinya. Hasil QA aktual dicatat pada `docs/DYNAMIC_PACK_QA.md` (atau `DYNAMIC_PACK_QA.md` di root ZIP server).

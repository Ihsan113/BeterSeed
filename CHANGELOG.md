## v1.7.0+58 — Individually downloadable Garden Packs

- Only Original Garden artwork and small thumbnails are bundled; nine other packs have independently installable ZIPs.
- Adds Aurora Crystal, Enchanted Mushroom, Celestial Cloud, Ocean Coral, Desert Oasis, Fairy Lantern; preserves the original Moonlight, Sakura and Golden Autumn pack IDs.
- Uses immutable app-side SHA-256/size metadata, HTTPS CDN opt-in downloads, atomic installation, local previews, video and sprite playback, and storage management.
- Per-pack spout calibration and planting placement; native widget can read validated installed sprites.
- Server API, MySQL schema, commercial ownership and permanent signing keys remain unchanged. Hosting/download URLs are build-time configuration.

## v1.6.0+57 — Dynamic Garden Packs

- Adds a database Garden Pack catalog and authenticated, CSRF-protected Garden Pack Manager with immutable IDs, revision checks and audit history.
- Uses atomic, quoted-price purchases and permanent free claims; preserves existing entitlements through pricing/status changes and protects old APKs from silent repricing.
- Matches server offers to complete APK asset mappings; supports cached offline collections, generic editor/preview/rendering and bundled widget artwork.
- Stops backup ownership hints from granting premium access; preserves future cosmetic IDs during progress sync.
- Server 1.2.0 adds migration 003 compatible with MySQL 8.0.46. See server/UPGRADE.md and docs/DYNAMIC_GARDEN_PACKS.md.

## v1.5.1+56 — Persistent sessions, calmer screens & administration

- Restore an encrypted account session before opening account settings; recover missing local profiles without adopting another account’s garden.
- Persist refresh request IDs and replay the same encrypted response after interrupted delivery, while retaining refresh replay detection and revocation.
- Simplify sign-in/registration, group secondary help, redesign Leaf Coin bundles and replace implementation notes in user-facing settings/help.
- Preview locked editor assets with visible lock badges; explain missing ownership on Save while keeping the draft open.
- Rotate a short garden message each visit without repeating the previous one or affecting tree coordinates.
- Add a responsive, self-hosted admin dashboard with independent password + TOTP login, Secure/HttpOnly sessions, CSRF/origin checks, account CRUD, suspension, session revocation, idempotent wallet corrections, pack controls and audit history.
- Add additive migrations and an interactive admin provisioning/recovery CLI. Native VPS binds loopback by default; Compose remains accessible inside its private container network.
- Include clean packaging and a VPS upgrade guide. No production secrets are bundled.

## v1.5.0+55 — Accounts, cloud sync and server-verified purchases (unreleased)

- Adds optional Google/email login and guest continuation, email signup OTP, email-only forgot/change/reset password, TOTP authenticator with recovery codes, and reauthenticated permanent account deletion.
- Adds a Node.js/TypeScript/MySQL backend and Docker deployment package. Secrets are configured on the server; encrypted session credentials stay in Android secure storage.
- Adds durable revision-based garden sync, idempotent retries, account-separated local copies, explicit conflict resolution and recovery copies. Coordinates, cosmetics, habits, progress and sound/motion preferences are included.
- Replaces locally granted Leaf Coins with server verification, account-bound Play tokens, transactional ledger and unlocks, post-commit consumption, reconciliation and refund debits. Existing local balances remain separate guest data and are not treated as payment proof.
- Adds public backend and app privacy/terms/licenses/FAQ/about pages, signup policy consent and a public account-deletion information URL.
- Retains pack previews, static wallpaper, current branding, Play package identity, stable signing and all existing garden features from main 2f6eebd.
- See docs/ACCOUNTS_SYNC_AND_BILLING.md for configuration, validation and release requirements.

## v1.4.17+54 — 2026-10-26

**GitHub Actions signed Google Play AAB release delivery**

- Extended the existing Android GitHub Actions workflow to produce `app-release.aab` in addition to the existing signed APK artifact.
- Uses the same persistent signing secrets and pinned release/upload SHA-1; no keystore rotation, embedded credentials, or unsafe debug-signing fallback.
- Added cryptographic AAB verification with `jarsigner` and `keytool`, archive integrity checks, expected certificate fingerprint comparison, and a safe checksum/report.
- Added an independent `BetterSeed-GooglePlay-release-aab` downloadable Actions artifact and upload checklist for Google Play Internal Testing.
- Pinned generated Android app to SDK API 36 for 2026 Google Play target requirements, without changing Android `com.betterseed.app` identity or minimum SDK.
- Preserved the existing APK artifact, Emerald adaptive icon, premium coin products, wallpaper fix, and all Garden Pack assets/videos.
- New release version **1.4.17+54**, Android versionCode **54**.

## v1.4.16+53 — 2026-10-26

**GitHub Actions run 40341873568: compact Shop layout + Garden Asset Editor UI regression**

- Fixed the Leaf Coin Shop balance card RenderFlex overflow at 320dp and large Android text scales. Its purchase CTA uses a full-width second row on compact layouts without clipping the balance.
- Corrected Garden Asset Editor widget-test navigation to scroll the Shop's Collection tab into view before tapping. The new coin balance card increased the scroll distance; off-screen tapping had prevented the editor from opening.
- Preserved the actual editor drag/save/reload regression assertions (not skipped or removed).
- Rechecked the Android `com.betterseed.app` package and rounded Emerald adaptive icon resources without changing them.
- Kept Garden Pack assets, compressed videos, wallpaper butterfly spacing, existing user preferences, signing configuration, and Billing product IDs unchanged.
- Increased version to **1.4.16+53**. GitHub Actions Flutter tests and APK build must still confirm this revision.

## v1.4.15+52 — 2026-10-26

**CI regression hotfix + consolidated Play branding + wallpaper butterfly spacing**

- Fixed the stale editor unit-test contract that caused GitHub Actions run **40337553281**, job **121623093034**, to stop on `chosen.wateringCanId ==` after Premium Garden Pack ownership gating was introduced.
- Updated tests to verify the actual safe editor save behavior: applying `ShopLoadout.fromMap` using the user's existing pack ownership flags; selecting a premium component can no longer silently grant a paid pack.
- Restored the previously implemented static-wallpaper butterfly spacing and regression test from v1.4.12, which had been omitted when the v1.4.13 coin branch was created.
- Preserved the permanent Android application ID **`com.betterseed.app`**, complete native Kotlin package mapping, Emerald adaptive/round launcher resources, two alternative icons, and 512×512 Play Store icon from v1.4.14.
- Preserved the Leaf Coin Store and Google Play Billing scaffold, existing artwork/videos (including compressed Golden Autumn), habit data and existing release-signing settings.
- Updated app version to **1.4.15+52**. This source still requires Flutter analyze/test/build in GitHub Actions; payment verification remains a separate production-hardening task.

## v1.4.14+51 — 2026-10-26

**Play Store identity + professional adaptive rounded app icon**

- Android Application ID / namespace switched from the Flutter placeholder to **`com.betterseed.app`** in the isolated Android generator; new ID must be checked for availability before Google Play publication.
- Updated native Kotlin package declarations, reminder action ID, generator destination and integration checks consistently.
- Introduced three alternative BetterSeed icons (Emerald, Sunrise, Minimal Ivory) as standalone PNG assets, with Emerald chosen as the launcher default.
- Added Android adaptive icon background/foreground/monochrome artwork, rounded legacy icons and a round icon resource for varied Android launchers.
- Added correctly unrounded **512×512** Play Store artwork in `assets/play_store_icon_512.png` (Google Play applies its own masking).
- Updated brand image in the in-app header, regenerated launcher mipmap sizes, version number and checks.
- Signing secrets, keystore, habit data, Garden Packs, video loops and Play Billing product IDs remain unchanged.
- Fixed an old Python contract test that expected the pre-premium Asset Editor behavior.

## v1.4.13+50 — 2026-10-26

**Premium Garden Pack flow + Leaf Coin Store + Google Play Billing scaffold**

- Header kanan atas sekarang menampilkan **Leaf Coin** (ikon daun) sebagai mata uang premium, menggantikan badge water di bagian atas. Info water tetap ada di kartu bawah Garden.
- Menambahkan **Leaf Coin Store** sebagai halaman penuh baru (bukan bottom sheet) dengan tampilan lebih clean dan profesional.
- Coin Store sudah menyiapkan flow **Google Play Billing** menggunakan `in_app_purchase` untuk pembelian bundle coin.
- Menambahkan bundle produk contoh: `betterseed_coin_120`, `betterseed_coin_300`, `betterseed_coin_650`, dan `betterseed_coin_1400`.
- Shop Garden Pack sekarang mendukung model **premium unlock** dengan leaf coin untuk Moonlight, Sakura, dan Golden Autumn.
- Menambahkan indikator balance leaf coin di halaman Shop dan tombol cepat menuju Coin Store.
- Menutup celah Asset Editor agar pack premium tidak otomatis terbuka hanya karena memilih aset campuran yang belum dimiliki.
- Progres coin dan riwayat delivery purchase lokal kini disimpan di SharedPreferences.
- Versi aplikasi dinaikkan ke **1.4.13+50**.

## v1.4.11+48 — 2026-10-26

**GitHub Actions CI hotfix — stale release-version contract checks**

- Fixed the two Python CI tests that still required `1.4.9+46` after `pubspec.yaml` was updated.
- CI now reads the app version from `pubspec.yaml` dynamically and checks that the newest CHANGELOG entry matches it.
- Removed unrelated, hardcoded release-version logic from the Sakura geometry regression test.
- Kept all Golden Autumn sprites, Android widget assets, and the already-compressed background video unchanged.
- Updated the application version to **1.4.11+48**.

## v1.4.10+47 — 2026-10-26

**Golden Autumn asset correction (base terbaru + video kompres tetap dipakai)**

- Menjadikan `BeterSeed-main (1).zip` sebagai base terbaru.
- Mempertahankan video background Golden Autumn yang sudah dikompres pada base terbaru.
- Mengganti aset Golden Autumn yang sebelumnya salah/kurang cocok dengan set aset baru dari `Download.zip`.
- Mengganti background statis, thumbnail pack shop, 6 stage pohon, amber butterfly, maple watering can, ember fireflies, dan widget Autumn Android.
- Tidak mengubah mekanik integrasi pack; fokus update ini hanya pembetulan aset visual Golden Autumn.
- Versi dinaikkan ke **1.4.10+47**.

## v1.4.9+46 — 2026-10-26

**Golden Autumn animated pack integrated into base source**

- Base source `BeterSeed-main.zip` sekarang sudah dipasangi **Golden Autumn Garden Pack** penuh.
- Menambahkan 6 sprite pohon `golden_autumn`, background statis fallback, thumbnail shop, amber butterfly, maple watering can, ember fireflies, dan 6 resource widget Android.
- Menambahkan background loop lokal `assets/videos/autumn_garden_loopy_8s.mp4` dengan fallback gambar statis saat animasi dimatikan, app di background, atau decoder video tidak tersedia.
- Shop, My Collection, dan Asset Editor sekarang mendukung claim/equip/mix untuk pack Golden Autumn.
- Backup/restore dan SharedPreferences kini menyimpan status kepemilikan Autumn, kosmetik aktif, dan penempatan pohon untuk background `golden_autumn_garden`.
- Android home widget kini mengenali tema `golden_autumn` dan menampilkan sprite pohon Autumn sesuai stage.
- Kalibrasi planting ground ditambah untuk Autumn agar batang pohon lebih pas ke area tanah cincin pada background baru.
- Versi aplikasi dinaikkan ke **1.4.9+46**.

# BetterSeed — Version History

Dokumen utama perubahan rilis. Catatan teknis lama di `docs/` tetap tersedia
untuk referensi tanpa perlu menambah banyak file Markdown baru setiap batch.

## v1.4.7+44 — 2026-10-25

**Garden Asset Editor UX refinement**

- Editor taman dirancang ulang mengikuti flow referensi yang lebih clean dan profesional.
- Preview taman sekarang jauh lebih besar sehingga area drag pohon terasa lebih lega.
- Kontrol editor dipisah menjadi mode **Preview**, **Position**, dan **Assets** agar tidak makan tempat.
- Tombol Save dipindah ke bottom action bar, sementara Cancel tetap tersedia di header.
- Drag pohon dipulihkan agar kembali langsung nyaman dipakai saat mode Position aktif.
- Asset picker dibuat lebih ringkas dengan thumbnail horizontal per kategori.
- Versi aplikasi dinaikkan ke **1.4.7+44**.

## v1.4.6+43 — 2026-10-25

**Garden Asset Editor UI refresh**

- Menerapkan tampilan editor aset baru yang lebih modern, proporsional, dan fleksibel.
- Preview taman kini lebih visual dengan highlight area pohon yang sedang digeser.
- Kontrol posisi/ukuran dipisah dalam kartu khusus agar lebih rapi dan mudah dipakai.
- Pemilihan background, tree, butterflies, watering can, dan fireflies sekarang memakai thumbnail visual, bukan dropdown teks biasa.
- Tombol Save / Cancel / Reset tetap dipertahankan dan seluruh fungsi editor v1.4.5 tetap berjalan.
- Versi aplikasi dinaikkan ke **1.4.6+43**.

## v1.4.5+42 — 2026-10-25

**Garden Asset Mixer, imported MP3 background music, and plant-only reset**

- My Collection → Edit Garden Assets now allows any combination of built-in backgrounds,
  tree sprites, butterflies, watering cans and fireflies. No external assets are imported.
  The matching free theme is unlocked when its component is saved. Save/Cancel remain
  transactional and per-background tree coordinates are preserved.
- The Shop distinguishes complete Garden Pack presets from a Custom Mix.
- Settings → Sound & Garden supports the default soundtrack or a locally imported MP3.
  Android's system document picker copies a validated MP3 (maximum 25 MB) to private app
  storage. Playback loops offline, stops in background, and source selection persists.
  The previous selection stays unchanged if import fails or the user cancels.
- Settings → Garden Progress → Reset plant growth resets only growth XP/stage after
  confirmation. Habits, completed checklists, water earned/spent, water balance,
  credit ledger and streaks are preserved; spent water is not refunded.
- Imported audio is device-local, not included in JSON or Android Auto Backup; when
  the file is missing after reinstall, the soundtrack falls back to built-in audio.
- Application version increased to **1.4.5+42**. Native signing config unchanged.

### Verify release

Run `python3 -m unittest discover -s scripts -p 'test_*.py'`,
`flutter analyze`, `flutter test --reporter expanded`, and GitHub Actions APK build.
Test MP3 import / cancel / default playback, mixing across three packs,
resetting a tree without resetting a checked checklist, and backup round-trips.

## v1.4.4+41 — 2026-10-25

**Sakura planting fix & My Collection Asset Editor**

- Perbaikan arah offset Sakura: pangkal pohon sekarang naik ke media tanam tengah
  (sebelumnya nilai bottom terbalik sehingga pohon semakin turun).
- My Collection kini memiliki **Edit Garden Assets** dengan preview taman langsung.
  Seret pohon untuk memindah posisi X/Y, atur skala pohon, dan Reset bila perlu.
- Edit latar, skin pohon, kupu-kupu, penyiram dan kunang-kunang secara independen,
  hanya dari Garden Pack yang sudah di-claim. Pilihan dicoba secara live.
- Setiap latar menyimpan konfigurasi posisi/ukuran pohon tersendiri. Save menyimpan,
  Cancel membatalkan tanpa merusak pengaturan aktif.
- Posisi air disesuaikan dengan pangkal sprite setelah diubah oleh editor.
- Cadangan JSON versi 1 tetap kompatibel; detail kosmetik dan koordinat opsional
  ikut terbawa backup baru tanpa mengubah format backup lama.
- Data habis/XP, onboarding, audio, video Sakura, tema lama dan sertifikat Android
  tidak direset. **Version 1.4.4+41**.

Cek manual setelah build: Stage 1 dan 6 di normal/Focus, Edit→Save→restart,
Edit→Cancel, ganti background/tree, restore, widget, perangkat kecil.

## v1.4.3+40 — 2026-10-25

**Hotfix: Sakura tree position calibration**

- Posisi pohon Sakura di scene Garden dikalibrasi ulang agar duduk lebih pas
  di lingkaran tanah tengah, tidak terlihat terlalu turun ke batu depan.
- Sprite Sakura diberi skala visual khusus dan lift vertikal khusus, tanpa
  mengubah posisi tema Default maupun Moonlight.
- Penyesuaian ini ikut berlaku di tampilan Garden normal dan Focus Mode karena
  keduanya memakai builder scene yang sama.
- Versi aplikasi dinaikkan ke **1.4.3+40** sebagai penanda hotfix visual.

### Uji rilis

Periksa kembali stage Sakura awal, tengah, dan penuh di Garden normal maupun
Focus Mode, lalu jalankan `flutter analyze`, `flutter test`, dan build APK.

## v1.4.2+39 — 2026-10-25

**New: Sakura Garden Pack (animated)**

- Garden Set ketiga `Sakura Blossom Garden` ditambahkan ke Shop dan My Collection.
- Memakai 6 sprite Sakura hasil generate baru (bukan pack Sakura v1.4.1 yang ditolak),
  serta butterfly, watering can, firefly pink, 6 widget Android dan thumbnail baru.
- Background memakai video unggahan pengguna `sakura_loop_5s.mp4` (5 detik,
  H.264, 1080x1920), loop tanpa audio saat Sakura aktif.
- Ketika efek gerak dimatikan, di tab lain, aplikasi di background, atau decoder
  tidak tersedia, gunakan poster statis dari video yang sama.
- Claim Free tidak langsung meng-equip; status Sakura dimasukkan ke preferensi,
  Snapshot backup/restore versi 1 yang tetap kompatibel, serta native widget.
- Kalibrasi posisi akar `PlantingGround.sakuraGarden`, tanpa mengubah tema lama.
- Versi aplikasi dinaikkan ke **1.4.2+39**. Versi paket yang ditolak adalah
  aset eksperimental v1.4.1, bukan kode aplikasi.

### Uji rilis

Jalankan `flutter pub get`, `flutter analyze`, `flutter test --reporter expanded`
dan build GitHub Actions. Tes secara nyata claim Sakura, pergantian ketiga tema,
animasi 5 detik, efek reduce-motion, Focus Mode, lalu sinkronisasi widget.

## v1.4.0+38 — 2026-10-25

**New: Welcome / Onboarding / Animated Splash**

- Splash screen animasi lembut menggunakan aset yang sudah ada, dengan teks
  "Preparing your calm garden..." dan pesan singkat tentang headphone.
- Minimum splash 1,5 detik; inisialisasi preferensi berlangsung bersamaan
  dan tidak ada loading palsu yang ditambahkan setelah data selesai dibaca.
- Panduan 4 halaman (Welcome, Habits, Growth, Focus & Headphones) dapat di-Skip,
  swipe dan tap Next; tombol Enter Garden menyelesaikan tutorial.
- Status penyelesaian (`betterseed_onboarding_completed_v1`) tersimpan lokal.
  Panduan tampil sekali dan tidak muncul setiap aplikasi dibuka.
- Menu **Settings > Widget & Display > Welcome guide** untuk membuka ulang.
- Semua gambar onboarding memakai aset lokal aplikasi; tidak memerlukan
  API, login, koneksi internet, atau permission baru.
- Semua fitur v1.3.0 (Auto Backup Android + SAF lokal, widget, reminders,
  garden skins, full screen, release signing) tetap digunakan tanpa migrasi
  atau reset data.
- Penomoran sumber APK di `pubspec.yaml`: **1.4.0+38**.
- Tes alur first launch, repeat launch, skip, headphone tip, replay, serta
  regresi fitur lama ditambahkan/dipertahankan.

### Verifikasi & penerbitan

1. Upload isi ZIP ke root repo, termasuk `.github/` dan file `CHANGELOG.md`.
2. Jalankan workflow Android APK, periksa tahap `flutter analyze`, `flutter test`
   dan `flutter build apk --release`.
3. Uji install **update tanpa uninstall** untuk menjaga data lokal.
4. Validasi onboarding pada fresh install atau dengan flag preferensi dihapus,
   dan verify warm start tanpa mengulang tutorial.
5. Pastikan tetap memakai release signing yang sama dengan build sebelumnya.

### Batasan

Build Flutter/Android dan tes Flutter sesungguhnya harus diverifikasi di CI
apabila Flutter SDK tidak tersedia di mesin penyusun arsip.

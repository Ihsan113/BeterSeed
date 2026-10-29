# BetterSeed — 1.7.0+58 · Optional Garden Pack Downloads

See `docs/ON_DEMAND_PACK_DELIVERY.md` for hosting and administrator setup. The install bundles only Original Garden and all Shop thumbnails. All other garden videos/sprites are downloaded individually, with checksum validation.

# BetterSeed 1.6.0+57 — Dynamic Garden Packs

Garden Pack sekarang dikelola melalui katalog backend dan **Garden Pack Manager** di `/admin`. Aset tetap dibundel di APK; harga, akses Free/Premium, status, dan urutan dapat diubah tanpa mengedit backend. Lihat [panduan pack baru](docs/DYNAMIC_GARDEN_PACKS.md) dan [upgrade server 1.2.0](server/UPGRADE.md). Backend harus diperbarui terlebih dahulu.

Pembaruan ini menggunakan GitHub `main` **27f97e4** dan ZIP server VPS yang diberikan pengguna sebagai base. Konfigurasi rahasia dan database VPS tidak disertakan atau diubah.

- **Akun**: pemulihan sesi setelah aplikasi dibuka kembali, retry refresh token saat koneksi terputus, login/daftar lebih ringkas.
- **Editor**: aset yang belum dimiliki bertanda kunci, dapat dicoba, dan memunculkan penjelasan saat mencoba menyimpan. Rancangan tetap tersedia untuk dilanjutkan.
- **Garden & Shop**: pesan taman acak per kunjungan, toko Leaf Coins baru, serta bahasa pengaturan/bantuan yang lebih mudah dipahami.
- **Admin**: dashboard web `/admin`, akses terpisah dengan sandi + authenticator, CRUD pengguna, penangguhan, pencabutan sesi, koreksi koin/pack, riwayat pembelian dan audit.
- **Update VPS**: [server/UPGRADE.md](server/UPGRADE.md). Perbarui backend sebelum APK; pertahankan `.env`, kunci enkripsi, kredensial dan volume MySQL lama.
- **Unduh backend**: [BetterSeed-server.zip](distribution/BetterSeed-server.zip) — paket sementara untuk diunduh dari GitHub, lengkap dengan panduan upgrade dan checksum.
- **Buat ulang paket backend bersih**: `python3 scripts/package_server.py` → `build/server/BetterSeed-server.zip` (tidak masuk Git secara otomatis).
- **Akun, sinkronisasi, billing**: [docs/ACCOUNTS_SYNC_AND_BILLING.md](docs/ACCOUNTS_SYNC_AND_BILLING.md); [dokumentasi server](server/README.md).

Pembaruan ini belum dipasang ke VPS. Gunakan domain API/OAuth/Play yang sudah Anda konfigurasi. Build tanpa `BETTERSEED_API_URL` tetap berfungsi sebagai tamu; rahasia Gmail Relay hanya berada di server.

---

Bagian berikut adalah riwayat rilis; catatan lama bahwa aplikasi tidak memiliki login/server merujuk pada versi sebelum 1.5.0.

> **Rilis source v1.4.17+54:** Flow premium BetterSeed kini memakai **Leaf Coin Store** full page dan scaffold **Google Play Billing** untuk top up coin. Premium Garden Pack bisa di-unlock pakai coin, sementara info water tetap ada di kartu bawah Garden.
> Sekarang GitHub Actions juga menyiapkan signed Google Play release AAB. Lihat `docs/GOOGLE_PLAY_AAB_GITHUB_ACTIONS_v1.4.17.md` dan `CHANGELOG.md` untuk instruksi lengkap.



# BetterSeed v1.4.0 — Welcome & Animated Launch

**Current release:** `1.4.17+54` — lihat [CHANGELOG.md](CHANGELOG.md) untuk perubahan, cara validasi, dan riwayat rilis.

**Play Store identity:** `com.betterseed.app` (replaces placeholder `com.example.betterseed`). Launcher icon: Emerald rounded/adaptive; two alternate designs and listing icon are in `assets/branding/` and `assets/play_store_icon_512.png`. Before switching from an older installed APK, export a manual SAF backup: the new Android ID is a different app and cannot directly access old local data. See [Play Store Branding Guide](docs/PLAY_STORE_BRANDING_v1.4.14.md).

- First launch: animated splash → optional 4-page introduction (Welcome, Habits, Growth, Focus & Headphones) → garden.
- Subsequent launches: short splash → garden, without repeating the tutorial.
- To replay: **Settings → Widget & Display → Welcome guide**.
- Everything remains offline-first and uses bundled visual assets.
- Legacy Android Auto Backup and manual SAF backup remain available.

---

## GitHub Actions widget-test hotfix — 2026-10-25

In [failed run #40182352371](https://github.com/Ihsan113/BeterSeed/actions/runs/40182352371/job/121135862684), `flutter analyze` passed but `flutter test` failed when entering Settings submenus. The Settings category test tapped an off-screen tile and Flutter rejected colored `DecoratedBox` layers above a `ListTile`'s Material ink.

This archive fixes the two causes: Settings section cards now use `Material` with the same theme and border; the test suite scrolls menu items into view before tapping, and the sheet resets its scroll position on category changes. The fixes preserve backup, assets, widget and signing code. See `docs/CI_SETTINGS_WIDGET_TEST_HOTFIX_2026-10-25.md` for the log diagnosis.

After pushing **the archive contents to the repository root** (including `.github/`), rerun GitHub Actions. Locally execute `flutter analyze` and `flutter test --reporter expanded` if Flutter is installed. This container has no Flutter SDK, so the Android APK build is not yet verified for this revision.

---

## CI hotfix — `MyApp` error in `flutter analyze` (October 2026)

The real entry widget is **`BetterSeedApp`** in `lib/main.dart`, not the
Flutter template's `MyApp`.  A source-only checkout must **never** run
`flutter create ... .` in the repository root: the template can generate
`test/widget_test.dart` with `const MyApp()`, breaking analysis.

- GitHub Actions now runs `python3 scripts/generate_android.py`, which builds
  the Android scaffold in a temporary project and copies **only** `android/`.
- `test/widget_test.dart` is a BetterSeed-specific smoke test, not the stock
  counter example. Python CI tests guard against regressions.
- The CI workflow checks `git diff --exit-code -- lib/ test/ pubspec.yaml`
  to ensure the scaffold has not changed tracked application sources.
- To fix an existing GitHub checkout: extract this ZIP over the repo root,
  ensure `test/widget_test.dart` is replaced, then commit all changed files:

  ```bash
  git add -A
  git commit -m "Fix Flutter MyApp CI test regression"
  git push
  ```

On your own computer, run `python3 scripts/generate_android.py` **only if**
`android/` does not already exist, followed by `python3 scripts/prepare_android.py`,
`flutter pub get`, `flutter analyze`, and `flutter test`.
This hotfix does not alter the offline habit data model, Auto Backup/SAF,
Android package name, app version, or release signing configuration.

---

# BetterSeed v1.3.0 — Android Auto Backup + Manual Document Backup

- Google OAuth dan Drive API **dihapus**; tidak ada Web Client ID, server, atau perizinan Drive khusus aplikasi.
- Android Auto Backup untuk SharedPreferences progres (Android mengatur jadwal dan pemulihannya).
- Tombol **Backup to file** / **Restore from file** memakai Android Storage Access Framework; file picker dapat menawarkan Google Drive.
- Restore memvalidasi JSON, mengonfirmasi sebelum menimpa, dan menyimpan checkpoint untuk Undo.
- SHA-1 signing release & GitHub Actions **tetap dikunci** dengan keystore lama untuk mengamankan upgrade.
- Baca [panduan v1.3.0](docs/ANDROID_AUTO_BACKUP_AND_SAF_v1.3.0.md) sebelum build dan tes perangkat.

> Bagian riwayat v1.2.x di bawah hanya catatan versi lama; OAuth v1.2.x **tidak lagi digunakan**.

---

## Update v1.2.5 — Safe provider diagnostics

- Map Google Sign-In unknown errors to safe provider status codes (28444 / 10 / 16). No login flow changes.
- Unit tests for OAuth, account reauth and report redaction.
- (Deprecated in v1.3.0).

## v1.2.4 — Google Drive safe connection diagnostics

- Connection attempts now display a **stage**, a stable **code**, and a suggested next action instead of the same generic OAuth/SHA message for every failure.
- The report can be copied from the error dialog without tokens, credentials, or email.
- Drive is only shown as connected after scope authorization, access headers, **and** the Google Drive API check succeed.
- Background sign-in is not started alongside the manual account picker.
- No changes to SHA-1 signing, Google OAuth client configuration, Garden, Shop or assets.

> **v1.2.3 signing clarity:** The MT Manager *file checksum SHA-1* is not the Google OAuth *signing certificate SHA-1*. GitHub Actions verifies signing before publishing and now bundles `CERTIFICATE_SHA1_README.txt` next to the release APK. See `docs/CERTIFICATE_VS_APK_FILE_SHA1_v1.2.3.md`.

## BetterSeed v1.2.2 — Signing verification fix

This update fixes false failures in the post-build APK certificate fingerprint check while preserving strict pinned SHA-1 enforcement. See `docs/APK_SIGNATURE_VERIFIER_HOTFIX_v1.2.2.md`. Reuse your existing release keystore.

## v1.2.1 — Stable APK signing / SHA-1

- GitHub Actions now produces a **release APK signed by a persistent keystore** from repository secrets.
- On every build, the signing certificate SHA-1 is checked against the resulting APK. Missing signing secrets **fail** rather than produce a new debug SHA-1.
- **One-time setup required:** [docs/STABLE_ANDROID_SIGNING_v1.2.1.md](docs/STABLE_ANDROID_SIGNING_v1.2.1.md).
- No keystore or password is included with this project.

## v1.2.0 — Reminder guard + Google Drive (manual) backup

- Checklist and Habit Composer now explain when reminder master is OFF and provide an **Enable** action (which may request Android notification permission).
- Google Drive private `appDataFolder` backup/restore, user-approved replacement and one-level local Undo.
- Google Sign-In requires external OAuth project, Android package certificate SHA, Drive API, and optional CI Web client ID secret before usable. (Deprecated in v1.3.0).
- Cloud backup is manual, not automatic/bidirectional; offline tracking never depends on a Google account.

## Latest update

- v1.1.7: Moonlight tree sprites normalized to the actual visible dimensions of the Default stages; focus mode with immersive fullscreen controls added.
- v1.1.6: increased the Moonlight tree presentation so it matches the default tree scale better in the garden and widget.
- v1.1.5: enlarged the Moonlight tree stages to match the visual scale of the default tree in both the garden and Android widget.
- v1.1.4: restored full-screen garden backgrounds with no blur, using direct cover rendering for a cleaner immersive look.
- v1.1.3: replaced Moonlight dark theme background with the selected premium moonlit landscape and kept the repository clean with only active visual assets.

## Update v1.1.2 — Adaptive Garden & aligned planting spot

See `docs/ADAPTIVE_GARDEN_v1.1.2.md`. Moonlight soil clearing is enhanced; both themes show uncropped sharp backdrops with soft edge extension. Android widget keeps the simple gradient background and themed trees.

# BetterSeed v1.1.1 — Garden Pack CI hotfix

A focused patch built on **v1.1.0**. Retains the Shop / My Collection
bundle system, Free Moonlight Pack, dynamic garden, stage celebrations,
and Android widget theme integration.

## Corrections

1. `BetterSeedShopPage` now renders its two pack cards eagerly inside a
   `SingleChildScrollView + Column`, rather than letting `ListView` lazily
   omit cards that are below the fold. The Shop remains scrollable on compact
   phones and at 1.6x–2.0x text sizes.
2. The Android widget channel regression test now checks the newly added
   `theme` field for both `default` and `moonlight` values. The native app
   code already transmitted this correctly.
3. Version advanced to **1.1.1+24** so that it can update v1.1.0+23.

## Important

The failures in run 40146999007 were **four test failures**, not analyzer
errors. `flutter analyze` passed there. This patch retains all runtime
features; no feature tests were disabled or deleted.

Run the GitHub workflow to validate Flutter tests and build an installable
APK. Flutter is not available in this export environment, so local Flutter
analyze and tests are not claimed as passing. `android/` is normally generated
by Flutter and is excluded from this source ZIP; `native/android/` is included.

For updating GitHub, extract into the repository root, run `git add -A`,
commit and push. Do not uninstall the existing app if you want to keep habits
and progress.


### v1.4.5 — Personalize your garden and sound

- **Shop → My Collection → Edit Garden Assets:** customize the background,
  growing plant, butterflies, watering can, and firefly style independently.
  The editor uses existing included art only; all three built-in sets are free.
  Position and scale the tree, preview the combination, then Save or Cancel.
- **Settings → Sound & Garden:** switch between the original ambient music and
  a local MP3 from the Android document picker (up to 25 MB). The selected MP3
  is copied to device-private app storage and plays offline in a loop. It is
  not uploaded or included in progress backups. Restoring the default track
  does not delete the imported MP3.
- **Settings → Garden Progress:** reset *only tree growth XP/stage* with a
  confirmation; completed habits, water balances, streaks, and habit history
  remain unchanged. Previously spent water is not refunded.

No new storage permissions, logins, or server-side services are required.
See `CHANGELOG.md` for technical release notes and verification steps.
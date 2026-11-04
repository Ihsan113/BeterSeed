# Checklist 2.0 review candidate — snapshot v2

Local source now supports checklist snapshot v2. Read `CHECKLIST_2.md` in the
backend ZIP (or `../docs/CHECKLIST_2.md` in the repository). No SQL migration is
added. The backend advertises v2 support and prevents v1 overwrites after an
account upgrades. Deploy the reviewed compatible backend before enabling v2 cloud
sync. Never roll back to a backend without the downgrade guard after v2 data is
stored. Production authorization and all existing VPS guards still apply.

This candidate retains previous release version numbers until release approval.
The historical upgrade notes below are not proof of deployment.

# Account experience — server 1.3.1 / app 1.8.1+60

> **PRODUCTION WARNING — native systemd VPS, NOT Compose.**
> Read [`../AGENTS.md`](../AGENTS.md),
> [`../ops/vps/KNOWN_STATE.md`](../ops/vps/KNOWN_STATE.md) and
> [`../ops/vps/DEPLOY_GUARDS.md`](../ops/vps/DEPLOY_GUARDS.md) first.
> On 2026-11-04 two attempted 1.2.0 → 1.3.0 deployments failed. The second
> attempt applied **migration 004 successfully** using privileged MySQL access,
> then failed systemd startup with **`MODULE_NOT_FOUND`** for both
> `/opt/betterseed-api/dist/index.js` and `dist/worker.js`. A subsequent VPS
> check confirmed backend **1.2.0**, API/worker active, `/ready=200`.
> Restrictive root-owned directories are a plausible but unverified on-VPS
> explanation for the startup failure. Verify entrypoint placement and
> readability **as the service's configured User** before any code swap.
> The runtime MySQL user `betterseed_api` does **not** have `CREATE`; never run
> the generic `dist/migrate.js` as that account on production, because it
> replays ALL migrations. Do not grant the app user permanent DDL privileges.
> Check if 004 is present before planning any further migration.
> **Do not deploy from these docs alone; obtain explicit user authorization.**

## Pembaruan 1.3.1: verifikasi email dan tampilan akun

Basis runtime: GitHub `a1aa3bd` dan ZIP `BetterSeed_Full_Source_Latest_Codex_VPS_Guards_20261104.zip`. Panduan VPS dari ZIP dipertahankan. Pasang dan verifikasi backend **1.3.1 sebelum app 1.8.1+60**, melalui proses staging dan persetujuan produksi di atas.

Endpoint baru `POST /v1/auth/verification/start` menerima email dan sandi. Hanya sandi yang benar dapat menampilkan status `already_verified` atau membuat challenge `verification_sent`. Login dengan sandi benar untuk email yang belum terverifikasi memberi `email_not_verified`; sandi salah tetap memberi respons umum. Endpoint daftar menerima status tambahan hanya dengan bukti sandi yang benar, dan tetap menyediakan `challengeId` untuk kompatibilitas APK lama. OTP, batas percobaan, pembatasan permintaan dan aturan 2FA tetap berlaku.

Tidak ada migrasi baru, kredensial atau variabel environment tambahan **dari 1.3.0 ke 1.3.1**. VPS yang masih 1.2.0 harus diperiksa berdasarkan panduan di atas; jangan menjalankan migrator sebagai akun runtime. Catatan ini bukan bukti deployment. Panduan `AGENTS.md` dan `ops/vps/` disertakan di akar ZIP, sejajar dengan folder `BetterSeed-server`, agar tautan relatif tetap berfungsi. Lihat juga `ACCOUNT_EXPERIENCE.md` dalam folder backend ZIP.

## Riwayat pembaruan 1.3.0

Base source: GitHub main `413d605`. This release adds bulk Garden Pack JSON editing, encrypted database backup/restore and a responsive admin interface. See `ADMIN_TRANSFER_AND_LOCALIZATION.md` in the ZIP (or `../docs/ADMIN_TRANSFER_AND_LOCALIZATION.md` in the repository) for browser steps, backup limits and migration requirements.

## Pembaruan alur pemulihan sandi

Pasang source backend terbaru ini **sebelum** APK dengan alur lupa sandi bertahap. Tambahan endpoint `/v1/auth/password-reset/verify-email`, `/verify-factor`, dan `/complete` memakai tabel challenge yang sudah ada; tidak ada migrasi atau variabel environment tambahan. Jangan hanya mengganti APK jika server masih memakai source sebelum endpoint ini ditambahkan. Endpoint reset lama tetap berfungsi untuk APK lama.

Respons awal lupa sandi tidak membocorkan keberadaan akun atau status 2FA. Setelah OTP email benar, server meminta autentikator/kode pemulihan hanya jika sudah diaktifkan. Grant acak lima menit hanya berlaku untuk satu tahap dan satu akun, dibatasi lima percobaan, dan hanya bisa dipakai sekali. Reset tetap mencabut sesi aktif dan mempertahankan 2FA saat login.

## Upgrade from server 1.2.0

1. Keep a private database backup, `.env`, provider credentials and the existing MySQL volume/version. Preserve `TOKEN_PEPPER` and `DATA_ENCRYPTION_KEY`. Source ZIPs contain neither these secrets nor live data.
2. Build the new backend with Node.js 24 (`npm ci` then `npm run build`) **in staging**. Confirm `dist/index.js` and `dist/worker.js` exist, their directory layout is correct, and both are readable/traversable by the actual systemd user after installation. Copy `public/` with the runtime source. Docker Compose build applies to separate installs only; this VPS uses systemd.
3. On the existing native VPS, **verify migration 004 state** using the read-only collector: the 2026-11-04 v2 attempt already successfully applied it. If an incremental migration is ever needed, use separately authorized administrative MySQL access after backup; **do not** run `dist/migrate.js` using the restricted runtime account. On *independent Compose installs only*, follow the appropriate container migrator workflow. Migration 004 adds a gate table and singleton row without replacing user, catalog or finance data. MySQL DDL is not transactionally reversible.
4. Start API and worker from the same 1.3.0 build. On Compose, use `docker compose stop api worker` before migration and `docker compose up -d api worker` afterward. Never use `down -v`. No old API/worker may remain connected during a dashboard restore because older versions do not acquire the coordination lock.
5. Check `/ready`, `/admin`, the catalog, sync and worker logs. Existing admin credentials remain valid. Test an export and isolated restore before using backups operationally. Each API/worker process now allows up to 16 additional gate connections; account for replica counts in the MySQL connection limit.
6. Release app 1.8.0+59 after backend verification. There are no new provider credentials, billing product IDs or environment variables for these features.

Routine catalog import and database export/restore now use the dashboard. Initial installation, migrations, external secrets and CDN assets still need server setup. Database import is a complete logical replacement of supported BetterSeed tables, not an arbitrary SQL uploader or a merge. Use a restricted destination, the same backend/schema and original encryption keys for migration; reconcile purchases/refunds and reapply deletions before reopening traffic. Backup import also replaces admin accounts and revokes all sessions.

The previous upgrade guide below remains useful for older installations; its version-specific release checks describe server 1.2.0.

---

# Upgrade Dynamic Garden Packs — server 1.2.0

Dasar pembaruan: GitHub main `bc16a2d` dan ZIP `AdminVPS-Safe-20261028-083945.zip`. Source runtime ZIP cocok dengan basis GitHub; perbaikan Docker yang menyertakan `public/` dan bind address container dari GitHub dipertahankan. Tidak ada konfigurasi rahasia produksi yang disalin ke source.

Migrasi baru `003_garden_catalog.sql` menambahkan `garden_packs` dan `pack_acquisitions`, lalu menambahkan empat ID awal dengan `INSERT IGNORE`. Migrasi berulang tidak mengubah harga/status yang sudah diedit admin dan tidak memodifikasi entitlement/pembelian lama. Tabel lama tetap digunakan. DDL MySQL melakukan implicit commit: jalankan migrasi sebelum mengganti proses API, dan ulangi jika terputus; jangan mengandalkan rollback transaksi DDL.

**MySQL 8.0.46 tetap didukung dan telah diuji. Tidak perlu upgrade atau downgrade database.** Untuk Docker, pertahankan image/tag serta volume database yang sudah digunakan; jangan mengganti MySQL 8.4 yang sudah ada menjadi 8.0.46. Instalasi native dapat tetap menggunakan MySQL 8.0.46.

## Sebelum memperbarui

- Cadangkan database dan simpan `.env`, folder `secrets/`, konfigurasi reverse proxy, serta unit systemd/PM2 yang sudah digunakan. Cadangan mengandung data pengguna: simpan privat, maksimal 30 hari.
- ZIP baru hanya berisi source/config contoh. Jangan menimpa `.env` atau `secrets/`; jangan mengganti `TOKEN_PEPPER` maupun `DATA_ENCRYPTION_KEY` pada pembaruan ini. Mengganti kunci akan memutus sesi/membuat data terenkripsi tidak dapat dibaca.
- Gunakan **Node.js 24** dan MySQL **8.0.46 atau 8.4** sesuai instalasi saat ini. Jalankan perintah dari direktori backend.
- Pasang **backend terlebih dahulu**, lalu rilis aplikasi 1.6.0+57. App baru mengirim harga yang disetujui, revisi katalog, dan build APK; backend lama tidak mendukung kontrak ini.
- Set `PUBLIC_BASE_URL=https://domain-api-anda` tanpa path. Dashboard memakai origin yang sama; tidak perlu domain/CORS tambahan. Pertahankan konfigurasi OAuth, Google Play dan Gmail Relay yang sudah berfungsi.
- Terbitkan pembaruan kebijakan dengan `LEGAL_VERSION=2026-10-28` setelah meninjaunya. Perubahan menjelaskan akses pengelola dan retensi audit.

## VPS native / systemd / PM2

Salin `src/`, `public/`, `migrations/`, `package.json`, `package-lock.json`, `tsconfig.json` dan dokumentasi dari ZIP baru ke direktori instalasi. Tidak perlu mengganti `.env` lama. Tambahkan `HOST=127.0.0.1` jika belum ada.

```sh
npm ci
npm run build
# Migrasi menambahkan tabel; tidak mengosongkan atau membuat ulang data lama.
# STOP: do not run the generic migration runner with the runtime DB user on this VPS.
# Migration 004 was already applied on 2026-11-04; verify live DB state first.
# Follow ../ops/vps/DEPLOY_GUARDS.md for an explicitly approved migration.
```

Restart layanan API dan worker dengan service manager yang sudah dipakai. Entry point tetap `dist/index.js` dan `dist/worker.js`. Jangan menjalankan dua proses API pada port yang sama.

## Docker Compose

Salin source baru beserta Dockerfile/compose.yaml; pertahankan `.env`, `secrets/`, nama project Compose dan volume MySQL yang lama. Sebelum menjalankan Compose, tetapkan `MYSQL_IMAGE` pada `.env` sesuai image database yang **sedang digunakan**: `mysql:8.0.46` untuk instalasi 8.0.46, atau tag 8.4 yang sama untuk instalasi 8.4. Default kompatibilitas Compose tetap `mysql:8.4`; jangan membiarkannya mengganti database 8.0.46 secara tidak sengaja. Ini tidak berlaku untuk MySQL native.

```sh
docker compose build api worker migrate
docker compose run --rm migrate
docker compose up -d api worker
```

Jangan gunakan `docker compose down -v`: volume berisi database. Migrasi juga aman dijalankan ulang. Pastikan image api/worker berasal dari source yang sama.

## Buat akun admin

Akun admin **terpisah** dari akun BetterSeed. Tidak ada sandi bawaan dan tidak ada endpoint pendaftaran admin publik. Jalankan lewat terminal SSH interaktif; sandi diminta tanpa echo dan tidak dimasukkan ke argumen shell.

Native:

```sh
node --env-file=.env dist/admin-cli.js admin@domain-anda.com
```

Docker:

```sh
docker compose exec -it api node dist/admin-cli.js admin@domain-anda.com
```

CLI menampilkan secret/URI authenticator baru di terminal pribadi. Tambahkan ke authenticator, lalu masukkan kode untuk mengonfirmasi. CLI tidak menyimpan admin jika konfirmasi gagal. Simpan secret pemulihan dengan aman; jangan masukkan ke GitHub, tiket dukungan, atau screenshot publik. Tunggu kode berikutnya sebelum login.

Buka **`https://domain-api-anda/admin`**. Login membutuhkan email admin, sandi dan kode authenticator. Session cookie HttpOnly + Secure + SameSite Strict berakhir setelah 8 jam. Reverse proxy harus meneruskan `/admin`, `/admin/*` serta API/halaman legal ke proses yang sama. Jangan menambahkan cache/CDN cache untuk `/admin*` atau `/v1/*`. `TRUST_PROXY` tetap hanya IP/CIDR proxy yang dipercaya.

Jika authenticator/sandi admin hilang, operator VPS dapat menjalankan perintah CLI yang sama ditambah `--reset`. Ini mengganti sandi/secret dan mencabut semua sesi admin tersebut. Administrator baru harus dibuat satu per orang; jangan berbagi kredensial.

## Fitur dan batasan dashboard

- Ringkasan jumlah pengguna, email terverifikasi, sesi aktif, penangguhan, pembelian yang menunggu penyelesaian, dan antrean email.
- Cari email, paginasi, detail status/progres **total** (tanpa menampilkan isi kebiasaan), pembelian, perubahan saldo, dan riwayat tindakan.
- Buat akun email: belum terverifikasi, belum menyetujui syarat. Berikan sandi awal melalui saluran aman. Pemilik membuka aplikasi → Need help signing in? → Verify an existing email registration → masukkan email → kirim kode baru → setujui kebijakan → verifikasi. Minta pemilik mengganti sandi setelah masuk. Tidak ada login otomatis atau bypass OTP.
- Ubah email akun email: mencabut semua sesi dan memerlukan verifikasi alamat baru. Authenticator tetap diperlukan. Akun yang sudah pernah terverifikasi tidak dihapus oleh pembersihan pendaftaran kedaluwarsa saat menunggu verifikasi email baru. Email Google dikelola Google.
- Tangguhkan/aktifkan dan cabut sesi. Data tetap disimpan saat ditangguhkan. Perangkat yang sedang offline dapat menampilkan salinan lokal, tetapi tidak mendapat akses server.
- Penyesuaian koin dengan alasan wajib dan ID tindakan untuk mencegah kredit ganda saat retry; terpisah dari bukti pembayaran Play. Saldo negatif diizinkan untuk koreksi/refund. Pemberian/pencabutan pack tidak menagih, tidak mengembalikan pembayaran, dan tidak mengubah riwayat pembelian.
- Hapus permanen memerlukan pengetikan email. Data pribadi dan catatan admin yang terkait akun dihapus/dianonimkan; fingerprint pembelian anonim tetap mencegah pemberian ulang. Ini tidak memproses refund Play. Pengguna perlu menghapus data aplikasi pada perangkat offline lain untuk menghapus salinan lokal.
- Semua admin memiliki akses pengelola penuh; belum ada role granular. Tidak ada editor purchase token, status verifikasi paksa, penonaktifan MFA pengguna, atau pembacaan password/secret.
- Audit dicatat maksimal 180 hari oleh worker. Jangan menaruh sandi, token, atau informasi sensitif di alasan tindakan.

## Sesi aplikasi

Vault terenkripsi tetap menyimpan kredensial di perangkat. Inisialisasi akun menunggu pembacaan vault sebelum membuka halaman akun. Profil lokal yang hilang tidak lagi membuang sesi valid; data akun dipulihkan dari cloud tanpa mengambil taman akun lain. Koneksi offline tidak menghapus sesi.

Refresh token tetap berotasi. App menyimpan UUID permintaan di vault **sebelum** meminta refresh; retry setelah koneksi/proses terputus memakai UUID yang sama. Backend menyimpan hasil terenkripsi yang hanya valid selama sesi penggantinya masih hidup (maksimal 30 hari). Token lama dengan UUID berbeda tetap dianggap replay dan mencabut sesi. Logout, penghapusan, reset sandi dan pencabutan sesi juga menghapus receipt melalui FK.

Pengguna tetap perlu login setelah logout eksplisit, reinstall/clear data, pemindahan ke perangkat baru, kredensial dicabut atau refresh token kedaluwarsa karena lebih dari 30 hari tidak digunakan. Kredensial tidak dimasukkan dalam backup Android.

## Pemeriksaan setelah deploy

1. `/health` dan `/ready` berhasil; halaman `/privacy`, `/admin` serta script/CSS dashboard dapat dimuat melalui HTTPS.
2. Admin berhasil login dengan kode baru, dan akun aplikasi biasa tidak dapat membuka API admin.
3. Coba pencarian/read-only terhadap akun uji. Untuk pengujian mutasi, gunakan akun khusus uji dan alasan yang jelas.
4. Pada APK baru: login → tutup paksa aplikasi → buka kembali offline → kembali online; akun dan taman tetap benar. Ulangi setelah access token berumur lebih dari 15 menit.
5. Uji pembelian di Google Play internal testing; perbaikan ini tidak mengganti SKU atau cara verifikasi Play yang sudah terpasang.

## Transisi katalog dan pemeriksaan tambahan

1. Sebelum migrasi, hentikan sementara perubahan admin, ambil dump konsisten seluruh schema/data (misalnya `mysqldump --single-transaction --routines --triggers` dengan kredensial dari option file privat), dan uji restore di database terisolasi. Catat jumlah users, entitlements, purchases, coin_ledger serta saldo/revisi akun uji. Jangan menaruh dump atau `.env` di GitHub.
2. Jalankan migrasi pada salinan staging MySQL 8.0.46 terlebih dahulu. Jalankan dua kali dan bandingkan jumlah/isi transaksi lama serta empat ID katalog. Jangan memakai database pengujian otomatis pada produksi; suite tes menghapus fixture di database tes.
3. Deploy backend 1.2.0 dan worker dari source yang sama. `GET /v1/shop/catalog` harus berisi `version:1`, empat ID awal, harga 0/180/280/420, dan status active. Akun admin lama tetap bisa login.
4. APK lama tanpa quote masih bisa membeli tiga pack lama **hanya** bila harga sama dengan harga awal, premium/active, dan minimum build <=56. Perubahan harga/akses/build menyebabkan `409 app_update_required`; status hidden/retired menyebabkan `409 pack_unavailable`. APK lama mungkin menampilkan pesan umum—tidak ada debit dalam kedua kasus. Pemilik lama tetap dilayani. Jangan mengubah penawaran lama sebelum siap mengarahkan pengguna ke update.
5. Uji app 1.6.0+57 dari kanal internal: harga dinamis, perubahan harga saat dialog terbuka (`catalog_changed`, minta pengguna memeriksa ulang), klaim gratis, koneksi terputus, editor, koleksi offline, perpindahan akun, preview, wallpaper, dan widget launcher.
6. Uji billing nyata memakai akun license tester Google Play, SKU yang sudah ada, token terikat akun, retry delivery dan refund. Tes lokal menggunakan provider tiruan dan tidak membuktikan koneksi Play/Gmail/OAuth produksi.
7. Pack baru didaftarkan sebagai draft lebih dahulu. Rilis APK yang memiliki seluruh asetnya, lalu aktifkan dengan `minimum_app_build` sesuai build pertama tersebut. Free harus diklaim online agar haknya tetap tersimpan ketika berubah menjadi Premium. `default` otomatis selalu dimiliki dan tidak butuh klaim.

## Rollback

- Pilihan aman: rollback APK sambil mempertahankan backend 1.2.0. Entitlement dan transaksi tidak berubah. APK lama tidak dapat memakai aset yang belum ada di APK tersebut.
- Jika backend bermasalah, hentikan sementara endpoint mutasi katalog/pembelian pack di reverse proxy dan perbaiki/roll forward. **Jangan menjalankan endpoint unlock backend lama setelah katalog berubah**: versi lama memakai harga/status hardcode dan tidak memahami klaim gratis, ID baru, atau quote. Rollback backend hanya setelah transaksi pack diblokir dan kontrak app/sync yang dilayani telah diperiksa di staging.
- Pertahankan tabel tambahan, volume dan semua kunci. Jangan drop tabel atau restore dump lama secara langsung: ini dapat kehilangan pembelian setelah dump, menghidupkan kembali akun terhapus, atau menyebabkan pengulangan transaksi. Pemulihan database perlu rekonsiliasi transaksi dan dilakukan operator secara terpisah.

Panduan registrasi aset, kontrak API, dan build AAB ada di `../docs/DYNAMIC_GARDEN_PACKS.md` pada repository. ZIP server menyertakan dokumen yang sama sebagai `DYNAMIC_GARDEN_PACKS.md`.

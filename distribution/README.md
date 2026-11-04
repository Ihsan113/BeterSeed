# Backend BetterSeed 1.3.0

Paket sementara untuk diunduh dari GitHub: [BetterSeed-server.zip](BetterSeed-server.zip), dengan [checksum SHA-256](BetterSeed-server.zip.sha256).

Paket berisi source backend, migrasi database, dashboard admin, tes dan panduan upgrade; tidak berisi `.env` produksi, database, secret atau `node_modules`.

Panduan fitur baru ada di `ADMIN_TRANSFER_AND_LOCALIZATION.md`: impor/ekspor JSON pack, backup database terenkripsi, dan migrasi.

Baca `UPGRADE.md` di dalam ZIP sebelum memperbarui VPS. Backend harus diperbarui sebelum aplikasi 1.8.0+59. Pertahankan konfigurasi dan versi database yang sudah digunakan. Tidak ada deploy otomatis ke VPS.

Setelah diunduh, folder `distribution/` boleh dihapus. Source backend tetap di `server/`, dan ZIP dapat dibuat kembali dengan `python3 scripts/package_server.py`.

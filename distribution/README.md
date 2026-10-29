# Backend BetterSeed 1.2.0

Paket sementara untuk diunduh dari GitHub: [BetterSeed-server.zip](BetterSeed-server.zip), dengan [checksum SHA-256](BetterSeed-server.zip.sha256).

Paket berisi source backend, migrasi database, dashboard admin, tes dan panduan upgrade; tidak berisi `.env` produksi, database, secret atau `node_modules`.

Baca `UPGRADE.md` di dalam ZIP sebelum memperbarui VPS. Backend harus diperbarui sebelum aplikasi 1.6.0+57. Pertahankan konfigurasi dan versi database yang sudah digunakan. Tidak ada deploy otomatis ke VPS.

Setelah diunduh, folder `distribution/` boleh dihapus. Source backend tetap di `server/`, dan ZIP dapat dibuat kembali dengan `python3 scripts/package_server.py`.

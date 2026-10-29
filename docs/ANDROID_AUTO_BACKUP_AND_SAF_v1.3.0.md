# BetterSeed v1.3.0 — Android Auto Backup + SAF document backup

## Cara kerja

- **Android Auto Backup** (`allowBackup=true`) mencadangkan hanya preferences Flutter dalam `FlutterSharedPreferences.xml`: progres, daftar habit, air, XP, pilihan Garden, suara, dan kebiasaan pengingat. Pada Android 12+ file ditentukan di `data-extraction-rules`; pada Android 11- ditentukan di `full-backup-content`. Pemicu, akun tujuan, ketersediaan, kuota 25 MB, dan restore semuanya dikendalikan Android. Jangan menganggap tombol Backup to file menjalankan Auto Backup.
- **Manual Backup to file** membuka Android **ACTION_CREATE_DOCUMENT**, menghasilkan file JSON versi 1 melalui penyedia file pilihan pengguna (lokal/Drive jika tersedia). Tidak perlu login Google di BetterSeed.
- **Manual Restore from file** membuka **ACTION_OPEN_DOCUMENT**; JSON dibatasi 4 MB, dicek format dan versi, dilihat ringkasannya, lalu **memerlukan persetujuan pengguna**. Salinan progres lama disimpan dulu untuk Undo.
- **Notification master permission** dan native widget runtime preferences tidak ikut Auto Backup/JSON; Android baru perlu izin notifikasi ulang dan widget rumah mungkin perlu dipasang ulang. Jadwal tiap habit tersimpan di JSON dan diterapkan bila master diaktifkan kembali.
- Tidak ada backend, Vercel, OAuth Android/Web Client, atau `google_sign_in` di aplikasi.

## Pengujian manual wajib sebelum rilis

1. Dari APK release lama dengan **sertifikat yang sama**, update ke APK versi ini **tanpa uninstall** dan pastikan progres awal tetap utuh.
2. Settings → **Backup to file** → pilih Drive jika ditampilkan oleh pemilih dokumen Android, atau folder lokal. Periksa file `.json` memang tersedia dan isinya data BetterSeed.
3. Tambah habit dan air, kemudian **Restore from file** → pilih file JSON → **Cancel**: data tetap baru.
4. Ulangi Restore dan **konfirmasi**; pastikan checklist, air, XP, riwayat, skin/pack serta jadwal habit kembali.
5. Tekan **Undo last manual restore**, pastikan data sebelum restore dipulihkan.
6. Pilih JSON rusak / format salah / file sangat besar; tidak boleh menimpa progres.
7. Uji dengan penyedia Drive dimatikan/tidak ada; pemilih file tetap bisa memakai penyimpanan lokal.
8. Uji Auto Backup terpisah lewat alat resmi Android, karena waktunya tidak bisa dipaksa lewat UI BetterSeed.

## Penting

Jangan mencabut/recreate keystore. Secrets keystore & `BETTERSEED_PINNED_SHA1` tetap wajib untuk rilis GitHub Actions. Secret `BETTERSEED_GOOGLE_WEB_CLIENT_ID` kini tidak digunakan dan aman untuk dihapus dari GitHub jika tidak dipakai proses lain.

### Menghapus file legacy dari checkout lama

Jika timpa ZIP di atas checkout GitHub yang sudah ada, hapus file source yang tidak dipakai:

```bash
git rm -f lib/backup/drive_backup_service.dart lib/backup/drive_connection_diagnostic.dart test/drive_connection_diagnostic_test.dart 2>/dev/null || true
git rm -f docs/GOOGLE_DRIVE_BACKUP_v1.2.0.md docs/GOOGLE_DRIVE_DIAGNOSTICS_v1.2.4.md docs/GOOGLE_SIGNIN_PROVIDER_CODES_v1.2.5.md 2>/dev/null || true
```

Pastikan `git add -A` agar penghapusan file lama dan source baru ter-commit. `android/` tetap dibuat oleh GitHub Actions dari `native/android`.

# Live wallpaper — BetterSeed 1.8.0+59

## Cara memakai

1. Atur taman dan simpan posisi pohon di aplikasi. Unduh pack yang ingin digunakan terlebih dahulu.
2. Buka **Settings → Widget & Display → Garden wallpaper**.
3. Pilih **Live wallpaper**, lalu **Preview live wallpaper**.
4. Android membuka preview wallpaper. Gunakan tombol terapkan milik Android dan pilih layar yang tersedia pada perangkat Anda. Dukungan layar kunci bergantung pada versi Android dan launcher; aplikasi tidak menjanjikan pilihan yang tidak disediakan sistem.

Pilihan **Still image** tetap tersedia untuk wallpaper gambar biasa. Jika perangkat tidak mendukung live wallpaper, halaman tetap menyediakan fitur gambar yang didukungnya.

Live wallpaper adalah **snapshot taman dengan animasi kupu-kupu dan kunang-kunang**, menggunakan aset dan warna pack yang sedang dipakai. Pohon, tahap pertumbuhan, latar, ukuran dan posisi pohon berasal dari tampilan taman yang disimpan saat membuka halaman wallpaper. UI, tombol, saldo dan informasi akun tidak ikut masuk ke gambar. Animasi preview tidak dibakar menjadi kupu-kupu statis tambahan di snapshot.

Setelah pohon tumbuh atau tampilan taman berubah, buka halaman ini dan terapkan ulang untuk memperbarui wallpaper. Versi ini tidak melakukan sinkronisasi pertumbuhan otomatis ke wallpaper, tidak menjalankan video latar pack, dan tidak memutar musik. Android dapat melakukan crop tengah untuk menyesuaikan ukuran layar/launcher; rasio gambar dipertahankan agar pohon tidak diregangkan.

## Perilaku Android

- Layanan native `WallpaperService` berjalan tanpa halaman Flutter terbuka. Menutup aplikasi dari recent apps tidak sama dengan mengganti wallpaper. Android mengelola pengaktifan kembali layanan setelah proses dihentikan atau perangkat direstart. Force stop/uninstall tetap mengikuti perilaku sistem.
- Snapshot dan sprite disalin ke penyimpanan privat `noBackupFilesDir`; tidak memerlukan izin galeri/penyimpanan atau akses jaringan saat diputar. Menghapus unduhan pack tidak menghilangkan wallpaper yang telah diterapkan. Salinan wallpaper bertahan sampai diganti, data aplikasi dihapus, atau aplikasi dihapus.
- Animasi dibatasi maksimal sekitar 24 fps, memakai Canvas hardware jika tersedia, dan berhenti saat wallpaper tidak terlihat, layar mati, atau Battery Saver aktif. Pengaturan animasi sistem yang dinonaktifkan juga dihormati. Tidak ada wake lock, alarm, foreground notification, video decoder atau audio.
- Preview menggunakan snapshot sementara. Membatalkan preview mempertahankan snapshot aktif sebelumnya. Penggantian hanya disimpan setelah wallpaper BetterSeed terverifikasi sebagai pilihan Android; tidak menampilkan sukses hanya karena picker berhasil dibuka. Android 14+ juga diperiksa untuk wallpaper layar kunci terpisah.
- Gambar diperiksa tipe, dimensi, ukuran dan keberhasilan decode sebelum dipublikasikan. Snapshot aktif dan preview terpisah, pemuatan gambar dilakukan di worker, dan salinan lama dibersihkan setelah penggantian/batal.
- Nama layanan dan halaman wallpaper mengikuti tujuh bahasa aplikasi. Panel pemilihan bawaan Android menggunakan bahasa sistem.

Fitur ini sepenuhnya di perangkat; tidak memerlukan endpoint, migrasi MySQL atau kredensial backend baru.

## Verifikasi

```sh
flutter analyze
flutter test test/live_wallpaper_test.dart test/garden_wallpaper_test.dart test/wallpaper_butterfly_layout_test.dart
python3 scripts/prepare_android.py
python3 scripts/verify_android_integration.py
python3 scripts/test_native_wallpaper.py
flutter build apk --debug
```

Tes Flutter memeriksa hasil picker, pembatalan, error/retry, pemisahan gambar dan efek, koordinat pohon, serta tujuh bahasa di layar kecil dengan teks besar. Tes Android Robolectric memakai decode gambar nyata untuk memeriksa preview terpisah, commit/cancel, file rusak, persistensi, dan pembersihan snapshot. Tes native juga dijalankan di GitHub Actions; dependensi tes hanya dipasang sementara pada scaffold Android yang dihasilkan, lalu konfigurasi build dipulihkan.

Hasil lokal: `flutter analyze` tanpa masalah, 168 tes Flutter, 4 tes native Android, 64 pemeriksaan repository, serta build APK debug berhasil.

Pemeriksaan perangkat nyata tetap diperlukan sebelum rilis publik: coba launcher bawaan dan layar kunci yang tersedia, batalkan preview saat wallpaper BetterSeed sudah aktif, tutup aplikasi, matikan/hidupkan layar, aktifkan Battery Saver, restart perangkat, dan hapus unduhan pack setelah menerapkan wallpaper. Pengujian lokal tidak menggantikan variasi perilaku picker/launcher dari produsen HP.

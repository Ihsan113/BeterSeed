# Widget dan pengelolaan unduhan pack

Basis: GitHub main `8922951`, aplikasi 1.7.0+58 dengan aset premium di CDN.

## Perubahan

- Widget memakai pohon dari tampilan tersimpan dan tahap XP saat ini. Path logis serta path file instalasi dikirim melalui MethodChannel. Android memeriksa path kanonis terhadap direktori pack privat dan marker instalasi sebelum membaca gambar, lalu melakukan downsampling maksimal 256px.
- Selesainya pemindaian awal, instalasi atau penghapusan pack memicu pembaruan widget; notifikasi progres download tidak menulis snapshot berulang kali. Snapshot juga diperbarui sebelum memasang widget. Draft editor tidak diterapkan ke widget.
- Selama aset belum tersedia, widget mengikuti tampilan Original Garden yang terlihat dalam aplikasi, dengan tahap pertumbuhan tetap sesuai XP. Setelah aset tersedia, tampilannya diperbarui tanpa menunggu pengguna mengubah progres.
- Tombol Remove downloaded files membuka konfirmasi yang menjelaskan bahwa hanya unduhan perangkat yang dihapus. Batal tidak menghapus file. Hasil penghapusan ditampilkan dan klik berulang dibatasi; kepemilikan akun dan progres tidak diubah. Cache gambar dievikt setelah penghapusan agar pengunduhan ulang tidak memakai gambar lama.
- Editor menggunakan ikon kategori, indikator download dan label Not downloaded untuk aset yang belum terpasang. Thumbnail Shop tidak lagi dipakai sebagai pengganti pohon/background/butterfly/watering can/firefly. Penanda lock dan validasi sebelum Save tetap berlaku.

## Validasi

- 140 tes Flutter lulus dan flutter analyze tidak menemukan masalah.
- 60 tes skrip Python lulus; integrasi native Android terverifikasi.
- Build APK debug berhasil.
- Tes baru memakai file instalasi sementara: pemindaian terlambat, enam tahap pohon, kombinasi background Sakura/pohon Moonlight, penghapusan yang membersihkan path widget, pembatalan penghapusan, serta kepemilikan yang tetap tersimpan.
- Dialog konfirmasi diuji pada viewport 320×640 dengan skala teks 1.6. Tes editor memeriksa kelima kategori memakai placeholder tanpa widget Image untuk pack belum terpasang.

Validasi widget dilakukan melalui snapshot MethodChannel, pemeriksaan source native, dan kompilasi Android. Tampilan launcher pada HP fisik belum diuji. Tidak ada perubahan konfigurasi backend atau isi arsip CDN.

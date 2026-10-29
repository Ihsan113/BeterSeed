> Pembaruan app 1.5.1+56 / server 1.1.0 menambahkan pemulihan sesi, dashboard admin dan migrasi tambahan. Untuk VPS yang sudah dikonfigurasi, ikuti [panduan pembaruan](../server/UPGRADE.md); pertahankan `.env`/kunci/database lama dan pasang backend sebelum app.

# Akun, sinkronisasi, dan billing — 1.5.0+55

Base: `origin/main` **2f6eebd**, versi 1.4.17+54. Implementasi ini tidak memerlukan Google Drive untuk cloud sync. Preview pack, wallpaper, branding, package `com.betterseed.app`, serta konfigurasi signing terbaru tetap dipertahankan.

## Yang ditambahkan

- Google sign-in, email/sandi, dan tamu. Daftar email harus memasukkan OTP; akun Google memakai email terverifikasi dari Google.
- Lupa/reset/ganti sandi khusus akun email. Akun Google tidak menampilkan kontrol sandi aplikasi.
- Autentikator TOTP dan sepuluh recovery code sekali pakai, tersedia bagi kedua provider. Perubahan keamanan dan penghapusan akun meminta verifikasi identitas ulang. Reset sandi tidak melewati 2FA.
- Penghapusan permanen akun/cloud progress. Tamu dan akun lain tidak ikut terhapus. Data lokal di perangkat lain yang sedang offline harus dihapus dari perangkat tersebut.
- Sinkronisasi otomatis ketika aplikasi aktif: habit, riwayat completion, air, XP, koordinat/ukuran pohon per background, kosmetik, preferensi suara/gerakan. File MP3 dan izin Android tetap lokal.
- Konflik dua perangkat tidak langsung menimpa data. Pengguna memilih versi cloud atau perangkat; keduanya tersimpan dalam salinan pemulihan lokal. Ekspor konflik berisi catatan kedua versi, bukan format backup SAF lama.
- Saldo Leaf Coin dan pack berasal dari backend. Token Play diperiksa server, dikaitkan ke akun, dicatat sekali lewat transaksi SQL, lalu dikonsumsi. Pengiriman ulang, refund, dan keterlambatan respons wallet ditangani.
- Kebijakan privasi, syarat penggunaan, lisensi/credit Pixabay, FAQ, dan tentang aplikasi tersedia di aplikasi dan URL publik backend. Ada URL publik petunjuk permintaan hapus akun.

## Pemasangan

1. Gunakan ZIP backend yang sudah diunduh atau folder `server/` dalam source. ZIP sementara di GitHub sudah dihapus setelah diunduh. Untuk membuat ulang, jalankan `python3 scripts/package_server.py`; hasilnya ada di `build/server/BetterSeed-server.zip` dan tidak masuk Git.
2. Pasang dengan Docker di VPS sesuai [server/README.md](../server/README.md). Isi `.env` dari contoh: database, dua kunci enkripsi/hash acak, domain HTTPS, operator, email dukungan, dan key Gmail Relay. **Key asli tidak disertakan dalam ZIP.**
3. Konfigurasi Web OAuth Client ID dan Android OAuth client memakai package serta certificate SHA-1 yang benar. Untuk APK dari Play gunakan sertifikat Play App Signing.
4. Pasang service account Google Play di file rahasia VPS; aktifkan empat produk coin yang sudah ada di aplikasi. Atur RTDN Pub/Sub untuk pemberitahuan refund dan worker untuk rekonsiliasi.
5. Isi GitHub Variables `BETTERSEED_API_URL` dan `BETTERSEED_GOOGLE_WEB_CLIENT_ID`. Workflow Android meneruskannya ke APK/AAB. Jangan masukkan Gmail key atau service-account JSON ke Flutter.
6. Isi Play Console dengan URL `/privacy` dan `/delete-account`; periksa teks legal dan identitas operator, sertifikat lisensi unduhan musik, backup/retensi, dan email dukungan sebelum publikasi.

Jika konfigurasi API belum diisi, aplikasi tetap bisa digunakan sebagai tamu. Pembelian baru memerlukan akun dan backend yang siap.

## Migrasi progres lama

Taman tamu dapat diadopsi saat masuk akun baru. Jika akun sudah memiliki taman cloud yang berbeda, aplikasi meminta pilihan. Taman akun A tidak digunakan sebagai upload awal akun B. Sign out mengembalikan taman tamu, sedangkan perubahan offline akun disimpan untuk login berikutnya.

Versi sebelumnya menyimpan coin dan kepemilikan pack secara lokal tanpa verifikasi backend. Data lama tetap ada di profil tamu perangkat, tetapi server tidak menganggap nilai JSON lokal sebagai bukti pembayaran. Jangan menghapus data lama sebelum menyelesaikan pemeriksaan pesanan Play melalui dukungan. Tidak ada konversi otomatis yang dapat digunakan untuk membuat coin palsu.

## Validasi

- Analisis Flutter: bersih.
- 126 tes Flutter lulus, termasuk pemulihan upload terputus, edit saat upload, konflik, isolasi akun, rotasi token, urutan verifikasi/penyelesaian pembayaran, dan UI akun pada teks besar.
- 58 tes Python lulus untuk integrasi Android, signing, workflow, dan fitur sebelumnya.
- 12 tes backend lulus terhadap MySQL 8.4 sungguhan; provider Google/Play/email dimock agar tidak membuat pembayaran atau mengirim email nyata.
- Image Docker berhasil dibangun dan dijalankan; migrasi, koneksi MySQL, halaman legal, serta signup dengan Argon2 native diperiksa.
- APK debug berhasil dibangun. Google sign-in, OTP via relay nyata, pembelian/refund dari internal testing Play, serta kebijakan perangkat masih perlu diuji setelah konfigurasi provider tersedia.

Source menyertakan CI backend dan pembuat ZIP deterministik. CI membuat dan memeriksa paket sementara di `build/server/`, tanpa membutuhkan ZIP yang disimpan di Git. Jalankan `python3 scripts/package_server.py` jika membutuhkan paket baru; `--check` memastikan ZIP cocok dengan source, checksum benar, dan tidak membawa kredensial.

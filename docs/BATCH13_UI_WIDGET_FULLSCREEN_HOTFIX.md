# BetterSeed v1.3.0 — UI / Widget / Fullscreen Hotfix

Perubahan utama:

1. **Artefak blur / glow di bawah pohon dikurangi**
   - Menyetel ulang `_GroundContactPainter` agar area dasar pohon lebih halus dan tidak terasa seperti noda blur.

2. **Fullscreen / Focus Mode lebih imersif**
   - Saat masuk Focus Mode, aplikasi sekarang menyembunyikan system bars dengan mode manual overlays kosong.
   - Style system bar dibuat transparan agar area atas tidak terasa seperti bar hitam.
   - Saat keluar dari Focus Mode, mode kembali ke edge-to-edge.

3. **Asset widget stage 2 dibersihkan**
   - `native/android/res/drawable-nodpi/widget_tree_2.webp` dibersihkan dari elemen kecil aneh di bawah tanaman.

4. **Settings dirapikan menjadi menu bertingkat**
   - Halaman Settings utama kini berisi kategori:
     - Sound & Garden
     - Daily Routine
     - Widget & Display
     - Backup & Restore
   - Setiap kategori membuka halaman pengaturan sendiri agar tata letak lebih bersih dan proporsional.

5. **Widget test / settings test diperbarui**
   - Test Flutter yang memeriksa Settings disesuaikan dengan struktur submenu baru.

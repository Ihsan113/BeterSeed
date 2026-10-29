# Batch 11 — Free Cosmetic Shop Implementation

## Ringkasan
Implementasi batch ini menambahkan kosmetik uji coba yang bisa langsung dipakai dari halaman **Shop** tanpa billing nyata terlebih dahulu.

## Yang Diimplementasikan
1. **Tree Skins**
   - 1 item kosmetik: `Moonlight Tree Skin`
   - Memakai **6 sprite** pertumbuhan yang konsisten dari stage 1–6.

2. **Background**
   - 1 item kosmetik: `Twilight Overlook`
   - Mengganti background Garden dengan framing yang lebih aman supaya tanaman lebih terasa napak di area tanah.

3. **Butterfly Skins**
   - 1 item kosmetik: `Cosmic Butterfly`
   - Dipakai pada animasi kupu-kupu di Garden.

4. **Watering Can**
   - 1 item kosmetik: `Celestial Watering Can`
   - Dipakai saat animasi menyiram.

5. **Firefly Colors**
   - 1 item kosmetik: `Prism Fireflies`
   - Mengubah palette painter firefly menjadi warna-warni.

## Perilaku Shop
- Semua item bertanda **FREE** untuk uji coba.
- Setiap item bisa langsung **Apply**.
- Status item aktif berubah menjadi **In Use**.
- Ada blok **How to use** di halaman Shop.
- State kosmetik disimpan ke `SharedPreferences`.

## Catatan Teknis
- Default loadout tetap aman saat pertama install.
- Asset baru dibuat dengan ukuran yang lebih kompatibel untuk layar portrait mobile.
- Garden layout disetel ulang agar tree lebih proporsional dan lebih “napak”.
- Struktur shop sudah siap untuk dihubungkan ke billing di batch berikutnya.

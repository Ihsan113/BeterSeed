# BetterSeed v1.4.13 — Leaf Coin Store + Google Play Billing

Rilis ini menambahkan flow premium baru:

- Mata uang premium memakai **Leaf Coin** (ikon daun) di header kanan atas.
- Halaman **Leaf Coin Store** adalah full page, bukan modal bawah.
- Premium Garden Pack dibuka dengan Leaf Coin.
- Pembelian coin memakai scaffold **Google Play Billing** via package `in_app_purchase`.

## Product ID yang perlu dibuat di Google Play Console

Buat **In-app products** dengan ID berikut:

- `betterseed_coin_120`
- `betterseed_coin_300`
- `betterseed_coin_650`
- `betterseed_coin_1400`

## Mapping bundle di aplikasi

- `betterseed_coin_120` → 120 leaf coins
- `betterseed_coin_300` → 300 leaf coins
- `betterseed_coin_650` → 650 leaf coins
- `betterseed_coin_1400` → 1400 leaf coins

## Harga premium pack di aplikasi

- Moonlight Night Pack → 180 leaf coins
- Sakura Blossom Garden → 280 leaf coins
- Golden Autumn Garden → 420 leaf coins

## Catatan integrasi

- Kredit coin diberikan setelah Google Play mengembalikan status purchase sukses.
- Riwayat delivery lokal disimpan untuk mencegah grant ganda pada event purchase yang sama.
- Asset Editor tidak lagi meng-unlock pack premium secara otomatis.
- Untuk produksi yang lebih aman, tahap berikutnya disarankan menambah verifikasi server-side / Play Developer API.

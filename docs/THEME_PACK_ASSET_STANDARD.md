# BetterSeed — Standar Resmi Asset Theme Pack

**Acuan kode:** BetterSeed **v1.1.7+30**. **Jenis dokumen:** standar art/UX untuk penambahan paket tema; **bukan pengubah kode**.  
**Tujuan:** setiap paket baru tampil seukuran, setinggi, dan setepat pijakannya dengan **Original Garden**, dari Stage 1 sampai Stage 6, pada Garden normal, Focus Mode, dan widget Android.

> **Aturan utama:** JANGAN menyamakan ukuran file saja. Yang harus disamakan ialah **luas siluet tanaman terlihat di atas kanvas transparan**, pusat horizontal, dan titik dasar akar/soil. Perbedaan estetika sah, tetapi tanaman tidak boleh terlihat mini atau melayang.

## 1. Isi minimal satu paket lengkap

| Bagian | Jumlah | Dimensi/format ekspor | Catatan |
|---|---:|---|---|
| Tanaman Stage 1–6 | **6** | **512×512 px** RGBA PNG/WebP transparan | Setiap stage satu berkas dengan pusat/pijakan konsisten |
| Background Garden | **1** | Master **1080×1920** px, rasio **9:16**; ekspor WebP kualitas ±85–92 | Jangan baked-in tanaman utama; sisakan media tanam jelas |
| Kupu-kupu | 1 | RGBA square **512×512** (art bisa lebih kecil) | Tanpa kotak hitam/putih, jangan terlalu ramai |
| Alat penyiram | 1 | RGBA square **512×512** | Corong harus mudah dikalibrasi dengan air |
| Fireflies | 1 konfigurasi | Palet warna efek Flutter, bukan wajib gambar | Pertahankan kepadatan moderat agar Garden tidak berisik |
| Pohon widget Stage 1–6 | **6** | **340×320 px** RGBA WebP | Buat dari sprite yang sama, pusat dan dasar konsisten; widget tetap tanpa foto background |
| Thumbnail pack | 1 | Rasio 9:16 atau 3:4 | Boleh berasal dari background untuk Shop, optimalkan ukuran |

Ukuran gambar dan format di atas adalah **standar ekspor ke depan**. Saat ini dua background proyek masing-masing berukuran **768×1365** dan **941×1672**; keduanya bekerja karena rasionya mendekati 9:16. Tidak wajib membesarkan aset lama tanpa alasan.

## 2. Ukuran visual enam tahap — acuan nyata dari Original Garden

Semua sprite default dan Moonlight memiliki kanvas 512×512. Ukuran berikut **BUKAN ukuran file**, melainkan *bounding box* piksel nyata dengan alpha minimal **64/255** (mengabaikan hampir seluruh pinggir cahaya transparan).

| Stage | Nama file (tanpa ekstensi) | Default: siluet W×H | X terlihat | Y terlihat | Batas bawah Y | Moonlight v1.1.7: W×H |
|---|---|---:|---:|---:|---:|---:|
| 1 (seed) | `stage_0_seed` | 330 × 202 | 103–432 | 257–458 | 459 | 329 × 187 |
| 2 (sprout) | `stage_1_sprout` | 332 × 308 | 95–426 | 150–457 | 458 | 315 × 301 |
| 3 (sapling) | `stage_2_sapling` | 338 × 373 | 89–426 | 85–457 | 458 | 300 × 377 |
| 4 (young) | `stage_3_young` | 380 × 457 | 62–441 | 25–481 | 482 | 364 × 458 |
| 5 (mature) | `stage_4_mature` | 454 × 479 | 11–464 | 5–483 | 484 | 400 × 480 |
| 6 (legendary) | `stage_5_legendary` | 496 × 478 | 2–497 | 0–477 | 478 | 405 × 477 |

**Standar penerimaan tema baru:**

- **Tinggi siluet:** usahakan **90–110%** tinggi siluet Default pada tahap sama. Tujuannya visual sama besar; jangan membesarkan `Image.asset` lewat kode hanya karena PNG banyak ruang transparan.
- **Lebar siluet:** target **85–115%** lebar Default. Jika bentuk desain memang ramping (misalnya pinus/bambu), lebar boleh berbeda dengan alasan visual yang jelas, **tetapi tinggi harus tetap dominan dan nyaman dilihat**.
- **Akar/bagian dasar:** batas bawah siluet disamakan dalam kisaran **±6 px** terhadap Default untuk masing-masing stage. Tanaman dan gundukan tanah tidak boleh terlihat terpisah dari pijakan.
- **Tengah visual X:** pusat silhouette sekitar **x=256**, toleransi ±16 px. Jangan membuat pohon cenderung ke samping.
- **Kanvas transparan wajib:** pinggir alpha=0, tidak ada latar tertanam di sprite; PNG RGBA, WebP harus betul-betul menyimpan alpha.
- **Tidak ada potongan nyasar:** hapus daun, partikel, bayangan, dan gundukan tanah yang terpisah jauh di bawah tanaman (masalah pernah terjadi pada `stage_2_sapling.webp`).
- Pertahankan bentuk akar/gundukan **wajar** di setiap stage. Jangan menaruh tanaman di tanah yang berbeda-beda dari gambar background.

**Penting:** bounding box alpha tidak selalu sama dengan bentuk visual utama jika ada percikan cahaya jauh dari objek. Lakukan pemeriksaan komposit secara visual setelah pengukuran otomatis; idealnya kilau latar dianimasikan terpisah.

### Contoh kesalahan yang harus dihindari

- Sprite 512×512 tetapi tanaman terlihat hanya ~150 px di tengah dan dikelilingi transparansi → tanaman tampak sangat kecil meski ukuran file benar.
- Memperbesar ukuran widget Moonlight saja sampai 1,14× → hanya menutupi gejala; bisa membuat pangkal tanah bergeser.
- Memotong gundukan tanah secara tidak sengaja saat crop sprite → akar terlihat menggantung.
- Menempelkan bayangan besar dan kilau acak pada sprite → sulit dicocokkan dengan `rootTarget` dan animasi.

## 3. Background & posisi media tanam

**Saat ini Garden memakai `BoxFit.cover` tanpa blur.** Background **mengisi seluruh layar**, sehingga wajar bila sedikit terpotong pada layar 19.5:9/20:9. Jangan menjanjikan gambar 9:16 selalu terlihat 100% di semua jenis layar sekaligus penuh tanpa crop.

Standar desain background:

1. **Rasio sumber 9:16**, disarankan master minimal 1080×1920. Area penting (terutama tempat menanam, cahaya utama, dan tepi tanah) diletakkan di *safe zone* tengah agar tidak hilang saat crop.
2. **Media tanam**: permukaan tanah/hamparan datar harus tersedia di **tengah horizontal** bagian bawah komposisi. Jangan taruh air/sungai sebagai titik pijak; tanaman tidak boleh tampak mengambang.
3. **Titik pijak harus dikalibrasi pada aplikasi, bukan ditebak dari file PNG**. Tiap background mungkin butuh `PlantingGround` atau parameter titik dasar sendiri.
4. **Jangan memasukkan pohon utama ke dalam background**: pohon harus tetap asset terpisah agar enam stage, Focus Mode, dan penyiraman tidak menumpuk objek ganda.
5. Komposisi visual: header/status bar tidak menutupi subjek penting, tanaman berada di tengah dan terlihat utuh, panel air serta tab bawah tidak menabrak akarnya.
6. Untuk gambar malam, desain media tanam dengan nilai terang/kontras yang cukup supaya pangkal akar jelas, bukan gelap pekat.

**Rumus geometri saat ini** (`lib/logic/garden_scene_geometry.dart`):

```dart
// scene = daerah gambar tanaman, bukan keseluruhan layar
size = min(scene.width * 0.74, scene.height * 0.72).clamp(88.0, 430.0);
groundBottom = max(10.0, scene.height * (moonlight ? 0.082 : 0.035));
rootY = scene.height - groundBottom - size * 0.03;
```

Ini **koordinat scene Flutter**, bukan titik otomatis yang dibaca dari JPEG. Jika menambah tema ketiga, jangan menggunakan fraksi Moonlight tanpa memeriksa media tanam pada gambar baru. **Gunakan satu titik pijak** bagi bayangan/akar, titik jatuh air, dan animasi stage. Kalibrasikan di layar normal **dan** Focus Mode.

## 4. Standar animasi & Focus Mode

- Animasi tumbuh memusat ke **alignment `bottomCenter`**, bukan pusat gambar, sehingga posisi akar tetap.
- Sway rotasi berpangkal di bawah (`Alignment.bottomCenter`), tanpa gerakan naik-turun yang mengangkat tanah.
- Alat penyiram masuk proporsional; corong dan aliran air harus mengenai area akar (`GardenSceneGeometry.wateringSpout()` dan `rootTarget()`).
- Kupu-kupu/kunang-kunang berputar ringan dan loop halus tanpa jeda mencolok; tidak menutupi label, tombol, atau area penting pohon.
- Mode Focus memperluas area pandang. **Periksa ulang tanaman dan akar** pada mode ini, karena tinggi scene yang dipakai bukan sama dengan mode Garden biasa.
- Ikuti pengaturan Living Garden / sistem animasi pengguna dan kurangi animasi bila diminta.

## 5. Widget Android (tetap sederhana)

- Latar widget tetap memakai **gradien/warna bawaan**, **tidak** memakai gambar panorama Garden.
- Pohon widget mengikuti **tema aktif dan stage yang sama** dengan aplikasi.
- Tiap tema baru membutuhkan **6 file `widget_<theme>_tree_0.webp` sampai `_5.webp`** ukuran **340×320 px** dengan transparansi yang valid. Nama spesifik disesuaikan dengan Kotlin yang mengacu pada resource tersebut.
- Sumber art berasal dari sprite 512×512 yang sudah dinormalisasi. Crop ke objek lalu sisipkan ke canvas 340×320 **dengan proporsi yang tetap nyaman**; jangan menyimpan gambar yang hanya terlihat beberapa piksel.
- Widget menggunakan `RemoteViews` Android dan hanya memperbarui gambar saat data berubah; **bukan** animasi live 60 FPS.

## 6. Struktur direktori untuk paket baru

Contoh tema bernama **Sakura** (contoh rancangan, **belum otomatis dikenali oleh kode v1.1.7**):

```text
assets/images/trees/skins/sakura/
  stage_0_seed.png
  stage_1_sprout.png
  stage_2_sapling.png
  stage_3_young.png
  stage_4_mature.png
  stage_5_legendary.png
assets/images/backgrounds/sakura_garden.webp
assets/images/effects/butterfly_sakura.png
assets/images/effects/watering_can_sakura.png
native/android/res/drawable-nodpi/
  widget_sakura_tree_0.webp ... widget_sakura_tree_5.webp
```

Untuk tema ketiga, developer **wajib menghubungkan** registrasi paket dan ownership di `lib/widgets/shop_page.dart`, mapping sprite/background/efek serta penyimpanan pilihan di `lib/main.dart`, kalibrasi pijakan di `lib/logic/garden_scene_geometry.dart`, resource dan mapping widget Kotlin, `pubspec.yaml`, serta tes Flutter/Android terkait. **Menyalin file saja belum membuat tema muncul di Shop.**

## 7. Checklist wajib sebelum rilis paket baru

- [ ] Punya semua **6 stage**, nama dan urutan benar (Stage 1 = `stage_0_seed`, Stage 6 = `stage_5_legendary`).
- [ ] Setiap sprite **512×512, RGBA**, transparansi benar, tanpa kotak warna latar.
- [ ] Ukuran siluet **setara Default per tahap**; posisi x tengah dan akar sesuai toleransi.
- [ ] Tidak ada daun/sparkle liar terlepas di bawah dan tidak ada daun/cabang terpotong.
- [ ] Background **9:16**, visual unik, ada media tanam di tengah, tidak memasukkan pohon tetap.
- [ ] Preview Garden di **320×640**, **360×800**, dan **412×915**; cek posisi pohon, safe crop, dan panel.
- [ ] Preview **Focus Mode** pada ukuran yang sama; pangkal tanaman tidak melayang.
- [ ] Penyiraman mengarah ke akar dengan benar; efek air tidak terpisah dari media tanam.
- [ ] Enam gambar widget **340×320** sesuai stage dan tema; latar widget tetap sederhana.
- [ ] Shop menampilkan satu **Garden Pack** lengkap; My Collection dapat memakai/kembali ke Default.
- [ ] Hanya asset aktif disimpan di source. Tidak ada duplikat preview besar atau PNG sumber proyek yang tidak dipakai.
- [ ] Lisensi semua art/audio tercatat untuk penggunaan komersial.
- [ ] Jalankan `flutter analyze`, `flutter test --reporter expanded`, skrip verifikasi Android/asset, dan **build APK di GitHub Actions**; jangan menyebut build lolos sebelum hasilnya benar-benar hijau.

## 8. Cara audit cepat jika pohon tema baru terlihat kecil

1. Buka asset Stage 2 Default dan Stage 2 tema baru **berdampingan dengan kanvas 512×512 yang sama**.
2. Abaikan lebar file. Ukur batas piksel yang **alpha ≥ 64/255**; periksa apakah lebar/tinggi objek tema baru terlalu kecil.
3. Jika objek terlalu kecil, rapikan batas objek (*trim alpha transparan*), kemudian **skala isi objek** dan letakkan kembali pada 512×512 dengan pusat serta **batas bawah** menyamai referensi Default.
4. Periksa keenam stage, bukan satu saja. Jangan ubah ukuran `Image.asset` secara berbeda untuk tiap tema kecuali benar-benar diperlukan.
5. Lakukan screenshot komposit Garden (default vs tema baru) di ukuran HP yang sama, lalu verifikasi akar, tanah, air, dan layout UI.

**File data acuan:** `docs/THEME_PACK_REFERENCE_METRICS.csv` — angka baseline diambil langsung dari source v1.1.7 dengan ambang alpha 64/255.

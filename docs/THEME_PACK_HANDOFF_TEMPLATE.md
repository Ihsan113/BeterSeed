# Template Serah Terima Garden Theme Pack Baru

> Salin ini untuk **setiap** tema. Lengkapi sebelum implementasi dan commit ke repo.

## Identitas paket
- ID unik paket (`snake_case`): `____________`
- Nama tampilan: `____________`
- Tema dan palet warna: `____________`
- Sumber asset / pembuat / lisensi: `____________`
- Status Shop: `FREE test / planned premium`

## Asset checklist
- [ ] 6 sprite tanaman 512×512 RGBA — ukur siluet vs Original per stage
- [ ] Background 9:16, disarankan 1080×1920 master WebP
- [ ] Kupu-kupu 512×512 RGBA
- [ ] Alat penyiram 512×512 RGBA
- [ ] Palet firefly
- [ ] Widget 6 sprite 340×320 RGBA WebP (tanpa foto panorama sebagai latar)
- [ ] Thumbnail katalog Shop

## Kalibrasi media tanam
- Background memiliki area pijakan jelas pada: X ___% dari lebar, Y ___% dari tinggi gambar
- `groundBottom` fraksi scene terkalibrasi: `____`
- Kedua mode yang sudah dicek: [ ] Normal [ ] Focus
- Alat siram mengenai akar: [ ] Ya
- Tinggi & akar semua stage setara Default: [ ] Ya

## Perbandingan tahap
| Stage | File | Alpha≥64 width × height | Bottom Y | Lolos vs Default? |
|---|---|---|---|---|
| 1 | `stage_0_seed` | | | [ ] |
| 2 | `stage_1_sprout` | | | [ ] |
| 3 | `stage_2_sapling` | | | [ ] |
| 4 | `stage_3_young` | | | [ ] |
| 5 | `stage_4_mature` | | | [ ] |
| 6 | `stage_5_legendary` | | | [ ] |

## Uji layar / kualitas
- [ ] Garden 320×640
- [ ] Garden 360×800
- [ ] Garden 412×915
- [ ] Focus Mode dan Back Android
- [ ] Shop → Claim/Owned → My Collection → Use → Default
- [ ] Widget tema dan stage berganti benar
- [ ] `flutter analyze` lolos
- [ ] `flutter test --reporter expanded` lolos
- [ ] `python3 scripts/verify_visual_assets.py` lolos
- [ ] `python3 scripts/verify_android_integration.py --sources` lolos
- [ ] GitHub Actions APK build hijau
- [ ] ZIP bersih, tanpa asset tidak terpakai

## Catatan visual / screenshot komparasi
- Tautan / path screenshot: `____________`
- Revisi terakhir: `____________`

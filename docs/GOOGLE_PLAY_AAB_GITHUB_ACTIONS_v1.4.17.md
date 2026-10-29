# BetterSeed v1.4.17+54 — AAB signed release dari GitHub Actions

## Apa yang berubah?

Workflow `.github/workflows/android-apk.yml` sekarang tetap menghasilkan APK seperti
sebelumnya **dan juga menghasilkan Android App Bundle (.aab) bertanda tangan untuk
Google Play Console**. Tidak perlu membuat AAB secara manual di Termux.

**AAB berbeda dari APK**: file `.aab` harus diunggah ke Play Console, tidak dipasang
langsung seperti APK. Download ZIP artefak dari GitHub Actions, ekstrak, lalu
pilih file `app-release.aab` pada Internal testing > Create new release.

| Properti | Nilai |
| --- | --- |
| Package name / application ID | `com.betterseed.app` |
| Versi | `1.4.17+54` (versionCode 54) |
| Android target API | 36 (Android 16) |
| AAB (setelah GitHub Actions sukses) | `build/app/outputs/bundle/release/app-release.aab` |
| Nama artefak AAB | `BetterSeed-GooglePlay-release-aab` |
| Nama artefak APK lama | `BetterSeed-stable-release-apk` |
| Pemeriksa tanda tangan AAB | `scripts/verify_signed_aab.py` |

## 1. Siapkan signing di GitHub Actions (sekali saja)

Masuk ke repo GitHub > Settings > Secrets and variables > Actions.

Pada bagian **Repository secrets**, siapkan keempat nama yang sudah digunakan
oleh workflow APK sebelumnya:

- `BETTERSEED_KEYSTORE_BASE64`: keystore JKS/PKCS12 release yang sama, dalam Base64
- `BETTERSEED_KEYSTORE_PASSWORD`: kata sandi keystore
- `BETTERSEED_KEY_ALIAS`: alias dari key yang sama
- `BETTERSEED_KEY_PASSWORD`: kata sandi key alias

Pada bagian **Repository variables**, siapkan:

- `BETTERSEED_PINNED_SHA1`: SHA-1 **sertifikat upload dari keystore tersebut**

**Jangan** mengunggah `.jks`, `key.properties`, Base64 keystore, password, atau
screenshot password ke repo atau chat. Gunakan keystore lama yang sudah
mendukung APK; jangan membentuk key baru untuk setiap build. Jika Play Console
sudah memiliki *upload key* terdaftar, sertifikat keystore GitHub harus cocok.
Jika berbeda, AAB dapat ditolak dan harus mengikuti prosedur reset upload key.

Setelah mengaktifkan Play App Signing, Google dapat memegang **app signing key**
yang berbeda dari **upload key**. Itu normal. SHA-1 yang diperiksa dalam GitHub
Actions di sini adalah sertifikat keystore upload, bukan SHA-1 tanda tangan APK
yang didistribusikan oleh Play Store.

## 2. Generate AAB tanpa mengganggu APK

1. Push source ZIP ini ke akar repo (`pubspec.yaml`, `.github/`, `scripts/`, dst.).
2. Buka GitHub > Actions > `BetterSeed Android APK + Google Play AAB`.
3. Klik `Run workflow`, pilih branch `main`, kemudian jalankan.
4. Pastikan semua langkah test dan build selesai hijau, terutama:
   - Configure persistent release signing
   - Build signed Google Play release AAB
   - Verify AAB JAR signature and pinned upload certificate
   - Upload Google Play release AAB artifact
5. Buka halaman run > **Artifacts** > `BetterSeed-GooglePlay-release-aab`.
6. Download ZIP artefak, ekstrak `app-release.aab` dan file laporan
   `AAB_PLAY_UPLOAD_VERIFICATION.txt`.

Workflow **fail-closed**: jika rahasia keystore tidak lengkap, fingerprint
berbeda, tanda tangan AAB invalid, atau pengujian gagal, AAB tidak diunggah.
Pada Pull Request dari fork/PR umum, tidak ada upload signed AAB untuk
melindungi secrets. Source ZIP ini **bukan** AAB hasil build.

## 3. Upload ke Google Play Console — Internal Testing

1. Pastikan BetterSeed dibuat di Play Console dengan package `com.betterseed.app`.
   Jika sudah membuat dengan ID lain, tidak bisa mengubah ID aplikasi Google Play.
2. Buka `Test and release` > `Testing` > `Internal testing`.
3. Buat rilis, pilih `app-release.aab` dari artefak langkah 2.
4. Ikuti setup **Play App Signing**, identitas aplikasi, App content, Data Safety,
   formulir kebijakan privasi, dan fitur in-app products jika ditampilkan.
5. Masukkan tester, review lalu rollout untuk internal testing.
6. Aktifkan `License testing` untuk akun penguji Billing.

**Penting**: meskipun AAB valid dan dapat diterima, Play Console bisa meminta
pengisian persyaratan lain sebelum rilis. Simpan fingerprint SHA-256 AAB untuk
membandingkan file unduhan dengan laporan yang dibuat workflow.

## 4. Status Google Play Billing

App ini masih menggunakan tahap awal `in_app_purchase` dengan coin yang disimpan
secara lokal. **Jangan lakukan penjualan produksi sebelum ada verifikasi token
pembelian server-side, idempotensi delivery/consume, penanganan refund, dan
pemulihan hak pembelian**. AAB ini ditujukan terlebih dahulu untuk **Internal
Testing dan uji Google Play Billing**.

## 5. Troubleshooting

- **No AAB artifact**: periksa apakah semua tes hijau, secrets tersedia, dan run
  bukan Pull Request. AAB hanya diunggah setelah verifikasi berhasil.
- **Keystore mismatch**: `BETTERSEED_PINNED_SHA1` perlu sama dengan sertifikat
  keystore lama, bukan checksum file APK/AAB.
- **Wrong package**: `com.betterseed.app` harus sama dengan identitas aplikasi
  di Google Play Console.
- **Version already used**: setiap upload ke Google Play harus menaikkan
  `versionCode`; versi ini menggunakan **54**.
- **AAB rejects API target**: cek generated Android SDK API 36 serta pesan
  terbaru Play Console; target policy bisa berubah pada masa mendatang.
- **APK install upgrades**: package lama `com.example.betterseed` berbeda;
  gunakan backup SAF sebelum pindah dari aplikasi lama.

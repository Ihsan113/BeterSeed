# Tindak lanjut laporan audit — 7 November 2026

## Cakupan dan bukti

Laporan pengguna ditulis untuk `67d156a`; pemeriksaan ini menggunakan source
lebih baru, `e6ac61c51e4cc20c85ece9e22cc7570eb2aa97ab`, sebelum perubahan lokal.
Laporan asli mencatat **0 confirmed, 5 needs_validation, 3 rejected**.
Prioritas P0/P1 di laporan bukan bukti kerentanan terkonfirmasi.
Ini verifikasi temuan yang dilaporkan, bukan pentest lengkap atau sertifikasi.
Review dilakukan satu pemeriksa; verifikasi independen tidak dilakukan.

| Temuan | Hasil pemeriksaan dan tindakan |
|---|---|
| BS-NV-001 | Source memang mengambil gate MySQL sebelum parsing dan limiter. Tambahkan admission di memori sebelum akses DB, dan pindahkan gate ke `preHandler` setelah parsing. Limiter DB tetap di dalam gate agar tidak menulis saat restore. Eksploit DoS di produksi belum dibuktikan. |
| BS-NV-002 | RTDN memang dikecualikan dari limiter umum. Tambahkan anggaran khusus dan batas concurrency, dengan 429/503 dan `Retry-After`. Verifikasi Google serta pemrosesan transaksi tetap berlaku. Respons sibuk tidak mengakui pesan sebagai sukses. Kapasitas delivery nyata masih perlu staging. |
| BS-NV-003 | Backup Android memang memasukkan Flutter preferences termasuk habit dan cache profil. Kebijakan privacy sudah menyebut backup, tetapi terms ambigu. Perjelas kedua dokumen, pertahankan backup yang sudah ada. Vault token tetap di luar allowlist backup. Ini klarifikasi privasi, bukan bukti kebocoran. |
| BS-NV-004 | Action menggunakan tag bergerak dan Flutter stable tanpa versi. Pin semua action eksternal ke SHA yang diverifikasi dari repository resminya; pin Flutter 3.47.8 dan Node 24.22.1. Ini hardening reproducibility, bukan bukti supply-chain compromise. |
| BS-NV-005 | Versi backend yang sedang berjalan belum terbukti. Tidak ada perubahan source yang bisa membuktikan deployment. Perlu snapshot read-only terbaru oleh pemilik; tidak mengakses VPS selama pekerjaan ini. |

Tiga temuan yang ditolak laporan tidak dihidupkan kembali sebagai kerentanan:
snapshot tidak dapat mengubah wallet/entitlement, purchase token memiliki
perlindungan replay, dan nama aset CDN dibatasi allowlist. Tes integrasi mencakup
otorisasi wallet, pembayaran bersamaan, refund dan snapshot; tidak ada pengujian
ulang CDN di perangkat pada pekerjaan ini.

## Batas admission backend 1.4.1

- `onRequest`: tanpa DB; maksimal 4.096 bucket IP/grup per proses, jendela 60 detik
  memakai waktu monotonik. Bucket aktif tidak dibuang untuk menerima IP baru.
  IP baru saat penuh mendapat 503 + `Retry-After: 1`.
- Login/auth: 40 request/menit/IP; API lain: 180; RTDN: 600. Query string tidak
  mengubah klasifikasi. IP berasal dari Fastify dengan konfigurasi `TRUST_PROXY`
  yang sudah ada; header forwarding tidak dipercaya secara otomatis.
- Setelah parsing: maksimal 12 request API/admin dan 4 RTDN aktif per proses.
  Permintaan berlebih mendapat 503 + `Retry-After: 1`; rate limit mendapat 429.
  Jangan ubah respons ini menjadi 200 di proxy karena Pub/Sub perlu retry.
- Limiter persisten lintas replica dan gate reader/writer tetap dipertahankan.
  Restore tetap memperoleh exclusive lock dalam handler setelah autentikasi.
- Parser tetap memiliki batas 4 MiB. Body invalid/terlalu besar ditolak sebelum
  memegang gate. Permintaan yang terputus tidak melepaskan slot saat handlernya
  masih bekerja. Pekerjaan yang selesai/error melepaskan slot secara idempotent.
- Batas proses bukan perlindungan DDoS menyeluruh. Validasi staging masih perlu
  memeriksa proxy timeout/body limits, shared-IP/NAT, burst notifikasi sah,
  retry Pub/Sub, jumlah replica, dan kapasitas MySQL. Tidak ada load test live.

## Kontrak dan rilis

- Backend **1.4.1**, app metadata **1.11.2+66**, `appBuild=66`.
- Snapshot tetap v3 dengan kompatibilitas v1/v2 yang sudah ada; tidak ada field,
  migrasi SQL, perubahan akun, token, saldo, hadiah, reminder, atau UI baru.
- Default/contoh `LEGAL_VERSION` menjadi `2026-11-07`. Operator perlu meninjau
  wording dan memperbarui versi kebijakan saat deployment disetujui; environment
  produksi tidak diubah dan tidak boleh diganti dengan file contoh.
- Perbaikan runtime backend baru berlaku setelah deployment terpisah. APK/push
  GitHub tidak menerapkannya ke VPS. **Production current state unverified.**
- SHA CI diperoleh dari `git ls-remote` repository resmi untuk tag major yang
  sudah dipakai, tanpa mengganti major action. Tag Flutter 3.47.8 juga diverifikasi.
  Saat memperbarui pins, review perubahan upstream dan jalankan CI; image runner,
  JDK patch, Android package repository dan transitive downloads belum sepenuhnya
  dibuat hermetic. Tidak ada klaim supply chain seluruhnya terkunci.

## Validasi lokal

Pengujian memakai image/tool/dependency yang sudah tersedia, tanpa instalasi.
Container read-only, source/toolchain read-only, network eksternal dimatikan,
environment di-allowlist, non-root, capability dibuang, `no-new-privileges`,
batas CPU/memory/PID/file/time, dan semua write target ke tmpfs terbatas.
MySQL disposable 8.0.46 hanya tersedia lewat loopback namespace terisolasi;
tidak ada port host, data akun nyata atau konfigurasi produksi.

| Pemeriksaan yang dijalankan | Hasil |
|---|---|
| TypeScript `tsc --noEmit` | Lulus |
| Build `tsc --outDir /tmp/dist` dan cek `index.js` / `worker.js` | Lulus |
| Integrasi API dengan MySQL 8.0.46, `test/api.test.ts` | 41 lulus |
| Admission/body/RTDN/concurrency/disconnect, `test/ingress.test.ts` | 9 lulus |
| Python `unittest discover -s scripts -p 'test_*.py'` | 67 lulus |
| `git diff --check` | Lulus |

Total 50 kasus backend unik: suite awal lulus 49/49, kemudian suite admission
final lulus 9/9 setelah menambah satu kasus socket disconnect. Tes membuktikan
slot tetap ditahan selama pekerjaan berlangsung dan tersedia lagi sesudahnya.
Setup DB terisolasi pertama gagal karena akun MySQL hanya tersedia untuk socket
localhost; fixture diperbaiki dengan akun khusus loopback sebelum hasil lulus.
Tidak ada perubahan akun database di luar container pengujian.

Tes tidak menggantikan pengujian kapasitas staging atau verifikasi deployment.
Android/Flutter runtime tidak berubah; tidak ada APK, emulator atau Google Play
live test untuk patch ini. Peringatan deprecation `disableRequestLogging` dari
Fastify tetap ada; bukan kegagalan tes atau perubahan pada redaksi log rahasia.

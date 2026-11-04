# BetterSeed 1.8.0+59 / backend 1.3.0

Source base: GitHub `main` at `413d605`. This release adds bulk catalog editing, encrypted database transfer, a responsive admin dashboard, and seven app interface languages. It does not deploy to a VPS. Android live wallpaper was subsequently authorized and added; see `LIVE_WALLPAPER.md` for its snapshot behavior and device setup.

## Garden Pack Manager: JSON export and import

Open `/admin`, sign in, and select **Garden Packs**. Search and status filters help find packs; each card shows price, revision and minimum app build. Export JSON, edit it locally, then import the file to review the differences. Enter a reason before applying. The preview expires after ten minutes; export and review again if another administrator changes a pack meanwhile.

The document format is:

```json
{
  "format": "betterseed-garden-packs",
  "version": 1,
  "packs": [
    {
      "packId": "example_garden",
      "name": "Example Garden",
      "description": "A short description for the shop.",
      "accessType": "premium",
      "priceCoins": 180,
      "status": "draft",
      "minimumAppBuild": 59,
      "displayOrder": 10,
      "revision": null
    }
  ]
}
```

- Keep the exported `revision` for existing packs; use `null` only for a new ID. IDs cannot be renamed. Duplicate IDs and unknown fields are rejected. Up to 500 packs per import.
- `accessType`: `free` (price zero) or `premium` (positive integer price). `status`: `draft`, `active`, `hidden`, or `retired`.
- Original Garden stays free, active and compatible with existing apps. Packs absent from a file are kept. Use status changes to withdraw a pack.
- All catalog edits commit together or none do. Price/revision changes remain subject to the existing purchase quote check. Existing ownership, purchases and Leaf Coins are unaffected by a **catalog** import.
- This edits catalog metadata only. A new visual pack still needs app-side asset mappings, a compatible app build, and its validated CDN asset package. JSON cannot upload art or grant ownership. Never activate an unsupported pack just because its metadata can be imported.

## Database: encrypted backup, restore, and migration

Open **Database** in the dashboard. Export requires your admin password, a fresh authenticator code, a reason, and a separate backup passphrase of at least 16 characters. A code already used for login/export cannot be reused; wait for the next code. The browser downloads `BetterSeed-database.encrypted.json` directly. Keep the file and passphrase separately and privately; a lost passphrase cannot be recovered.

The backup includes application accounts (including password hashes and encrypted authenticator secrets), admin accounts, gardens, sync history, wallets, purchases, ledgers, entitlements, catalog and audit records. It is encrypted with AES-256-GCM and a random salt/nonce; the passphrase derives a key with scrypt. There is no plaintext database download from this UI.

It excludes active sessions, OTP/challenge records, outgoing email, rate-limit counters, maintenance locks, environment files, provider credentials and CDN assets. **This is a versioned logical BetterSeed backup, not an arbitrary MySQL `.sql` importer or a copy of every database on the VPS.** Routine export/restore uses the browser; initial server installation and schema upgrades still use the existing deployment process.

To restore:

1. Download a fresh safety backup of the destination database first. Keep the destination restricted from public use during recovery/migration.
2. Select the encrypted backup and enter its passphrase. Review its creation date and table counts. Invalid encryption, schema, key identity or document structure is rejected before confirmation.
3. Confirm the safety backup was saved, type `RESTORE`, and enter a reason, admin password and a fresh authenticator code.
4. Restore **replaces** the supported application tables; it does not merge users or add balances. A database transaction keeps foreign keys enabled and rolls everything back if an insert fails. All current API requests and worker operations must finish before the restore can take its exclusive database gate. Busy requests return a retryable error rather than racing the replacement.
5. After success all app/admin sessions are revoked. Sign in with an **admin account present in the backup** and the next authenticator code. Users must sign in again; normal sync conflict handling still applies to offline device edits.

A restore returns purchases, wallets, users and audit history to the snapshot time. Before opening a recovered server, reconcile later Google Play purchases/refunds and reapply completed account deletions. Follow the existing maximum 30-day backup retention policy; keep a restricted deletion record outside database backups. Do not repeatedly restore old financial snapshots into a publicly writable server.

For migration to another VPS, install the **same backend release and migrations** first, preserve the original `TOKEN_PEPPER` and `DATA_ENCRYPTION_KEY`, and configure the same provider credentials separately. Create a temporary destination admin to access the dashboard, import the backup, then sign in as an admin restored from it. The temporary admin is replaced too. Check schema/charset/collation compatibility in the preview; schema differences are rejected instead of guessed. Transfer `.env`, provider secrets and CDN files through a separate private channel. These files and the backup must never be committed to GitHub. Test on an isolated destination before moving traffic.

The browser workflow is bounded to a 32 MiB decrypted snapshot and 100,000 rows per table (encrypted upload limit 46 MB in the UI, 48 MiB API request limit). Large installations need a managed MySQL backup/migration process instead. Set reverse-proxy request limits/timeouts high enough for permitted uploads; do not disable authentication or CSRF checks. No DDL, external SQL tool, older API instance or older worker may write concurrently with restore: all API/worker replicas must use backend 1.3.0 or newer with migration `004_database_gate.sql` installed. Each process uses an additional bounded gate pool of up to 16 connections; size MySQL connection limits for your replica count.

## App languages

First launch defaults to **English (United States)**, independently of the phone language. Choose a language from the welcome/sign-in language button or **Settings → App language**:

| Locale | Language |
|---|---|
| `en-US` | English (United States) |
| `id` | Bahasa Indonesia |
| `ja` | 日本語 |
| `de` | Deutsch |
| `fr` | Français |
| `es-419` | Español (Latinoamérica) |
| `pt-BR` | Português (Brasil) |

The preference is saved on the device and updates the interface without resetting the garden. Home, habits, statistics, shop, coin store, editor, static wallpaper, account flows, settings, introductory screens and Android widget/reminder labels follow the choice. Dates use the selected locale. **Leaf Coins** and product bundle names remain unchanged. User habit names and server-authored pack names/descriptions stay as entered; existing habit titles are never rewritten. New starter habit names use the selected language.

Policy navigation is translated; official legal document bodies remain in the backend's published language, with a notice. Google Play/Google sign-in system screens use their provider/device language. The admin dashboard remains Indonesian. Live wallpaper is now available alongside static wallpaper. Both interfaces follow the app language; see `LIVE_WALLPAPER.md`.

## Verification

Automated coverage includes revision conflicts and atomic catalog imports; authenticated, CSRF-protected backup operations; wrong passphrases/keys and tampering; foreign-key rollback; cross-process maintenance locks; exact JSON, Unicode, timestamp and BIGINT restoration; and preservation of financial state. Flutter tests cover saved language choice, default English, user text preservation and compact screens with large text across all seven languages. A browser smoke test exercises JSON download/import, encrypted backup/restore, logout and responsive admin layouts against a disposable MySQL database.

Real Google Play purchases, production restore, physical-device widgets and live notifications still require internal-release/device validation with the operator's existing configuration. No production database or credentials are bundled in the source ZIP.

Local verification on 2026-11-02:

- `flutter analyze`: no issues. The complete Flutter suite passed 178 tests after the recovery/navigation update, including editor geometry, direct customization access, staged password recovery and seven-language layouts.
- Python repository contracts: 64 passed. Backend MySQL 8.0.46 integration suite: 35 passed; TypeScript check/build passed.
- Admin browser flow passed at 320, 768 and 1440 px, including real file downloads, bulk import, encrypted restore, session revocation and literal rendering of uploaded HTML-like text.
- Native integration verification and Android debug APK build passed. Four native Android snapshot tests also passed. Backend Docker image built successfully; the test environment's proxy CA was supplied as an ephemeral build secret without changing the production Dockerfile or disabling TLS validation.
- Backend ZIP content, reproducibility and SHA-256 checked; runtime secrets and dependencies excluded.

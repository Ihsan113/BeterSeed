# BetterSeed backend

**Server 1.2.0 / app 1.6.0+57:** dashboard admin ada di `/admin`. Untuk instalasi VPS yang sudah berjalan, ikuti [UPGRADE.md](UPGRADE.md) terlebih dahulu. Akun admin dibuat dengan CLI interaktif dan wajib memakai authenticator; tidak ada password bawaan. Folder `public/admin/` harus disertakan saat deploy.

# BetterSeed account server

Node.js 24 + TypeScript + MySQL 8.0.46/8.4 (retain your installed database version). Optional accounts, automatic garden sync, and a server-authoritative Leaf Coin wallet for Android package **com.betterseed.app**. This ZIP is source code, not an already hosted service. No production secrets, database, Flutter assets, or `node_modules` are included.

## Install on a VPS

1. Install Docker Engine + Compose v2 and a host reverse proxy such as Caddy. Point an API domain at the VPS. Allow public HTTPS; do not expose MySQL or port 8080 publicly.
2. Extract this archive and enter `BetterSeed-server/`. Copy `.env.example` to `.env`. Set `MYSQL_PASSWORD` and a **different** `MYSQL_ROOT_PASSWORD`; generate independent `TOKEN_PEPPER` and `DATA_ENCRYPTION_KEY` with `openssl rand -hex 32` twice. Keep the keys stable and back them up securely; changing them invalidates token fingerprints or makes encrypted data unreadable. Set `PUBLIC_BASE_URL`, `LEGAL_OPERATOR_NAME`, `SUPPORT_EMAIL`, and the policy version.
3. Put the Gmail relay key in `GMAIL_RELAY_API_KEY`, with `GMAIL_RELAY_BASE_URL=https://gmailrelay.vercel.app`. Never put this key in Flutter, GitHub variables, the image, logs, or the ZIP. Messages use `POST /api/send` with `X-API-Key`, JSON `to`, `subject`, `html`, and `reply_to`. Email codes are valid for 10 minutes and five guesses. An encrypted SQL outbox retries relay failures until expiry. The worker must be running for emails to arrive.
4. Set `GOOGLE_WEB_CLIENT_ID` to your **Web application** OAuth client ID. Create an Android OAuth client for `com.betterseed.app` with the actual installed app certificate SHA-1. For Play builds use the **Play App Signing** certificate, not merely the upload certificate. Add debug signing only in a test OAuth configuration. No Drive API or Drive permission is needed.
5. Initially leave `GOOGLE_APPLICATION_CREDENTIALS` empty to disable purchasing. When configuring billing, create `secrets/`, place the Google Play service account JSON there as `google-play.json`, readable by container user UID 1000, and set the variable to `/run/secrets/google-play.json`. Enable Android Publisher API and grant the service account the necessary app-specific Play Console purchase/order permissions. Do not commit that JSON.
6. Run `docker compose up -d --build`. The `migrate` service initializes the schema, then `api` and `worker` start. This initial migration is idempotent; preserve the database volume on upgrades. Do not run `docker compose down -v` on production data.
7. Configure the host reverse proxy using `Caddyfile.example` and your real domain. Set `TRUST_PROXY` to the **exact IP/CIDR of the reverse proxy as seen by the API container**, not all addresses. Inspect the Docker network gateway for a host-based proxy. Without this, client IPs share a rate bucket; trusting arbitrary forwarded headers allows rate-limit bypass. Only the host reverse proxy should reach the published loopback port. Restart the API after changing environment variables.
8. Check `https://YOUR_DOMAIN/ready`, `/privacy`, `/terms`, `/licenses`, `/faq`, `/about`, and `/delete-account`. Set the Play Console privacy URL and account-deletion URL to those public pages. Keep support email monitored; deletion requests made outside the app must be verified and handled.
9. In the Flutter repository set GitHub **variables** `BETTERSEED_API_URL=https://YOUR_DOMAIN` and `BETTERSEED_GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID`. These are public configuration, not secrets. CI passes them to both APK and AAB builds. Empty API configuration keeps the app in guest mode. Locally use:

   ```sh
   flutter build appbundle --release \
     --dart-define=BETTERSEED_API_URL=https://YOUR_DOMAIN \
     --dart-define=BETTERSEED_GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
   ```

The server refuses production startup without HTTPS URLs, strong independent encryption keys, an operator name, a valid support email, and an email relay key. It does not silently invent these values. Verify external provider credentials before allowing public purchases.

## Google Play Billing setup

Create single-quantity consumable one-time products (do **not** enable multi-quantity):

| Product ID | Coins |
|---|---:|
| betterseed_coin_120 | 120 |
| betterseed_coin_300 | 300 |
| betterseed_coin_650 | 650 |
| betterseed_coin_1400 | 1400 |

Garden Pack metadata and prices are managed in `/admin` → Garden Pack Manager. The initial prices are Moonlight 180, Sakura 280 and Golden Autumn 420; they are seeded once, never reset by repeated migrations. App 1.6.0+57 reads this catalog and submits the reviewed price and revision. A changed quote is rejected without spending coins. Free claims persist as entitlements even if the pack later becomes premium. A Google login is not required for billing: verified email accounts can buy too. Guest purchases are disabled.

The Android client sends the account's opaque `billingAccountId` as Play's obfuscated external account ID and uses `autoConsume: false`. The server checks the token with Android Publisher for the fixed package and allowlisted product, purchased state, quantity 1, account binding, and consumption status. It commits a unique token fingerprint, ledger entry and wallet credit in one SQL transaction, then consumes the product with Google. Duplicate deliveries return the same account balance. A worker repairs a crash/timeout between grant and consumption; the app never grants coins locally or acknowledges a pending/unverified transaction.

Test with a Play **internal-testing** installation and license tester, not a sideloaded debug APK. Verify real successful, pending, canceled, declined, retried, refunded, and account-switch purchases. Test loss of network after charge and after server grant. Previously consumed coins return through the same BetterSeed account, not Play restore. The UI's retry action queries unconsumed purchases and refreshes the account wallet.

For prompt refunds, configure Google Pub/Sub real-time developer notifications with an authenticated push subscription to `https://YOUR_DOMAIN/v1/billing/notifications`. Set `GOOGLE_RTDN_AUDIENCE` to that exact audience and `GOOGLE_RTDN_SERVICE_ACCOUNT_EMAIL` to the **push-authentication** service account email. The server verifies Google's JWT signature, audience, issuer and verified service-account email, and rejects the wrong package. Give Pub/Sub permission to mint the push OIDC token as prescribed by Google. Unknown purchase notifications never create credits by themselves.

The worker also polls the Voided Purchases API over a 30-day window with pagination. Refunds debit once; if coins were spent the balance can go negative and further pack spending is blocked. This release does not enable multi-quantity purchases, subscriptions, iOS payments, or automated refund requests. Existing pack unlocks remain after a refunded coin purchase; the coin debt remains. The client ignores late wallet responses with older wallet revisions.

Older app versions delivered coins locally and consumed them without server verification. Those local balances and unlocks remain in the device's separate guest profile, but **are not accepted as proof of payment** for a cloud wallet. For migration, retain the old data/export and investigate real Play order references through support. Do not import arbitrary coin/ownership flags from a JSON backup. This release does not invent paid entitlements without evidence.

## Authentication and security

- Email registration requires accepting the current legal version and proving email ownership before any session is issued. Forgot/reset password apply only to email accounts. Responses do not disclose whether an email is registered. Registration does not overwrite an existing password.
- Google ID tokens are validated on the backend using Google's signing keys, exact Web audience, verified email, expiry, issuer and a 10-minute freshness limit. Users are keyed by Google's `sub`, not user-provided email. An existing email account is never automatically linked to a Google identity. Google accounts cannot call password-change/reset routes.
- Passwords use Argon2id (64 MiB, three passes). Access tokens expire after 15 minutes. Refresh tokens expire after 30 days, rotate once per refresh and are stored only as keyed hashes on the server. Reusing a rotated refresh token revokes that account's sessions. The app serializes refresh calls. If a refresh response is lost, signing in again is the safe recovery path.
- Two-factor authentication uses RFC 6238 TOTP, a ±1 step clock window, encrypted secrets, replay protection, and ten one-use hashed recovery codes. Setup expires in ten minutes and only activates after a valid code. Enabling/disabling invalidates other sessions and outstanding challenges. Password resets still require a valid second factor when enabled. Keep the VPS clock synchronized.
- Sensitive actions (password change, 2FA setup/disable, permanent deletion) require a fresh password/Google identity plus the current second factor if enabled. Password changes/resets invalidate sessions. No support bypass for 2FA is implemented.
- Rate limits use atomic MySQL counters shared by API instances, keyed IP/email/account identifiers. Request bodies, bearer headers, provider request configs, OTPs and Google tokens are not logged. HTTPS, a private DB, prepared SQL, strict request validation, request size limits and bearer authorization are required.
- Mobile sessions use Android encrypted secure storage excluded from the app's allowlisted Auto Backup files. Garden progress is a local preference cache and can be included in Android backup. Rooted/compromised devices are outside these controls.

## Sync protocol and data ownership

`GET /v1/garden` returns `{revision, snapshot, updatedAt}`. `PUT /v1/garden` accepts `{baseRevision, mutationId, snapshot}`. `mutationId` is a random UUID for **one immutable payload**. A per-account transaction checks the expected revision and retains the operation result. Retrying the same operation after a lost response cannot apply it twice. Reusing a mutation ID for different data is rejected. Stale revisions return HTTP 409 with the current remote version.

The app durably saves the pending mutation before networking. New edits made during an upload are kept separately and sent against the returned revision. Sync runs after local changes (debounced), periodically while active, and on resume, with bounded retry backoff. It is not an Android background service; fully closing the app pauses sync. Offline edits remain available. Conflicts pause uploading; users choose cloud/device and a local recovery file preserves both versions. Resolution is also protected by revision comparison. No naive addition of XP, water, or completion counters is used.

Synced: habit definitions and per-habit reminder settings, completion/day history, water/XP/tree stage data, mixed cosmetics, exact per-background tree coordinates/scale, sound/motion preferences. Notification permission/master permission, imported MP3 bytes, wallpaper images and credential material remain local. Financial state is excluded from the garden schema and loaded only from the wallet/entitlement APIs. The app gates equipped cosmetics against server entitlements for signed-in users.

Guest and each signed-in account have separate local copies. Signing out restores the guest garden. A new account can adopt guest progress; an existing cloud garden that differs requires an explicit conflict choice. Account A is never automatically uploaded as account B. Manual restore checkpoints are namespaced by account. Losing a secure session restores the guest view instead of treating the last account's mirror as guest content.

## API reference

All request/response bodies are JSON, except public policy pages. Authenticated endpoints require `Authorization: Bearer ACCESS_TOKEN`. Do not put tokens in URLs. Error shape: `{ "error": "stable_code", "details": { ... } }`; `details` is supplied for sync conflicts. Use the Flutter client and test fixtures for full request examples.

| Method and route | Purpose / required fields |
|---|---|
| GET /v1/config, /v1/legal | Public capabilities and published policies |
| POST /v1/auth/register | email, password (12–128 chars), acceptTerms=true, legalVersion |
| POST /v1/auth/resend-verification | email; always returns a challenge ID |
| POST /v1/auth/verify-email | challengeId, 6-digit code |
| POST /v1/auth/login | email, password; session or 2FA challenge |
| POST /v1/auth/google | idToken, acceptTerms=true, legalVersion |
| POST /v1/auth/two-factor | challengeId, challengeToken, factor (TOTP/recovery) |
| POST /v1/auth/forgot-password | email; returns a reset challenge ID |
| POST /v1/auth/reset-password | challengeId, code, password, factor if enabled |
| POST /v1/auth/refresh | refreshToken; replaces token pair |
| POST /v1/auth/logout | Authenticated; revokes current session |
| GET /v1/account | Account profile and provider capabilities |
| POST /v1/account/password | password, newPassword, factor if enabled; email only |
| POST /v1/account/two-factor/setup | password or idToken; returns secret and otpauth URI |
| POST /v1/account/two-factor/confirm | factor; returns recovery codes exactly once |
| POST /v1/account/two-factor/disable | password or idToken, factor |
| DELETE /v1/account | password or idToken, factor if enabled, confirmation="DELETE" |
| GET, PUT /v1/garden | Revisioned sync described above |
| GET /v1/wallet | Authoritative balance, wallet revision, packs and billing availability |
| POST /v1/billing/verify | productId, purchaseToken |
| POST /v1/shop/unlock | packId; server charges once, even on retry |
| POST /v1/billing/notifications | Authenticated Pub/Sub envelope; separate Google OIDC auth |

## Operations, retention and deletion

Keep API and worker running. Monitor `/ready`, container restarts, unsent `email_outbox` age and credited-but-not-consumed purchases. Worker errors deliberately omit provider payloads; diagnose credential/configuration status without logging secrets. An alert should fire well before Google's three-day acknowledgement deadline. Google's consume endpoint acknowledges consumables; never consume before the SQL grant commits.

Make encrypted daily MySQL backups, restrict access and keep a maximum **30-day** retention so the published privacy policy is truthful. Keep a restricted record of deletion requests outside backups and reapply completed deletions before opening a restored database to users. Do not restore an old database into a live service without reconciling purchase grants, refunds, deleted users and sessions. Test restore procedures on an isolated instance. Database migrations should be reviewed before production upgrades.

The worker removes expired challenges, hashed rate limits, used refresh markers and email outbox messages; expired sessions; expired pending TOTP setups; and unverified accounts older than seven days. Successful emails are immediately removed from the outbox. Active account/progress data remain until account deletion. Permanent deletion cascades through account identity, sessions, challenges, recovery codes, garden, sync operations, wallet and entitlements. Encrypted purchase tokens are erased; anonymous keyed token fingerprints and financial deltas remain to block replay. Other disconnected devices may retain local copies; clearing app data/uninstalling there erases those copies. User-created exported files and Google Play records are not under server control.

The included legal text describes this implementation, including Google, Gmail Relay and hosting data processing. Set the actual operator/contact and review your deployment practices before publishing it. The operator must keep the Pixabay download/license certificate for the supplied music track and any required creator details; royalty-free is not public domain. The app's license screen links to track #308945 and the Pixabay terms. No copyright transfer is asserted.

## Validate locally

Node 24 and a disposable MySQL instance are required. These tests intentionally use only `betterseed_test`, localhost port 33067 and the documented test-only root password; they mock Google/Play/email and never send live emails or make payments.

```sh
docker run -d --name betterseed-account-tests \
  -e MYSQL_ROOT_PASSWORD=betterseed_local_test_only -e MYSQL_DATABASE=betterseed_test \
  -p 127.0.0.1:33067:3306 mysql:8.0.46
# Wait until mysqladmin ping succeeds inside the container.
npm ci
npm run check
npm test
npm run build
npm audit --omit=dev
# After testing, remove only this disposable test container:
docker rm -f betterseed-account-tests
```

Optional `TEST_MYSQL_HOST`/`TEST_MYSQL_PORT` select a test service. Tests delete test data and must never point at production. Test coverage includes OTP single use/guess limits, refresh replay, password reset session revocation, 2FA/recovery/replay, account isolation, revision conflicts/idempotent sync, payload tampering, simultaneous purchase delivery, account-bound tokens, failed consumption repair, duplicate unlock/refund, and permanent deletion. Live Google sign-in, actual Gmail relay delivery and Play test purchases require your provider configuration and device testing; mocked integration tests are not a substitute for those release checks.

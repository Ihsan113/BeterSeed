# BetterSeed — mandatory instructions for Codex and coding agents

These instructions apply to the **entire repository**. Before backend changes,
read `ops/vps/KNOWN_STATE.md`, `ops/vps/README.md`,
`ops/vps/DEPLOY_GUARDS.md`, and `server/UPGRADE.md`.

## Production is NOT the GitHub branch

GitHub HEAD is **not a deployment receipt**.

**CRITICAL — DO NOT assume `server/package.json` equals the live VPS version.**
The repository contains backend **1.3.0** at GitHub main commit
`a1aa3bd0b97f2b9366db8d087f2d034e7399a7fe`; the **last verified live
VPS was still 1.2.0**, with API and worker active and local `/ready` HTTP 200
AFTER the failed 1.3.0 upgrade (2026-11-04). The live status may change after
this observation. Inspect a fresh read-only snapshot before claiming anything
is deployed. Never infer successful deployment from GitHub Actions.

### Existing topology (do not replace with Docker)

- Ubuntu VPS; **native MySQL**, **systemd**, external Caddy reverse proxy.
- Deployed app path: `/opt/betterseed-api`.
- Systemd units: `betterseed-api.service`, `betterseed-worker.service`.
- Live configuration: `/etc/betterseed/` (outside the repository).
- Production database and credentials are **not part of the GitHub project**.
- `server/compose.yaml` is a separate installation example. Production is NOT
  using that Compose stack. Do not run Compose or initialize a new database.
- Optional Garden Pack sprites are on a separate CDN; VPS updates must not
  modify CDN/R2, Android assets, or Play signing.

## Read these lessons from two failed production upgrades

1. **First failure:** migration runner `server/src/migrate.ts` replayed 001–004
   using restricted runtime MySQL user `betterseed_api`. MySQL denied `CREATE`
   on `users`. Do not grant permanent DDL/ALL PRIVILEGES to this account.
   Use separately authorized admin migration access for reviewed DDL.
2. **Second attempt:** administrative migration **004_database_gate.sql
   succeeded**, and runtime DB gate access was verified. Staging TypeScript
   build and native `argon2` smoke check passed. But new services failed
   readiness, logging `MODULE_NOT_FOUND` for
   `/opt/betterseed-api/dist/index.js` and `dist/worker.js`.
   Root-owned staging directories with restrictive permissions are a plausible
   cause (locally reproduced), but the exact on-VPS cause is **not yet proven**.
   Verify file presence, ownership, directory execute/traverse permissions,
   and readability **as the actual systemd User**, *before* stopping services.
3. The deployment script attempted rollback after each failure. The user
   subsequently confirmed **1.2.0**, both systemd services `active`, and
   local `/ready=200` after the second failure. Schema 004 remains applied;
   the code rollback does not roll database DDL back. No newer on-VPS deploy
   has been verified in this conversation.

## Safe change / deployment contract

- Prefer code changes, documentation, and offline tests. **Do not independently
  deploy** or migrate production; obtain the user's explicit approval.
- Preflight current read-only state, including `database_gate` existence and
  service-specific runtime file access. `ops/vps/state/current.json` exists
  only after collecting live evidence; check its timestamp and review contents.
- For upgrades: review migrations, use a privileged migration-only connection,
  create independent SOURCE and FULL DATABASE backups, preserve `.env`,
  `TOKEN_PEPPER`, `DATA_ENCRYPTION_KEY`, signing and provider credentials.
- Build to staging; assert `dist/index.js` **and** `dist/worker.js` exist and
  are accessible to each service account; inspect file and parent directory
  ownership/permissions. The prior deployments passed `npm run build` but
  failed runtime startup.
- Stop/restart API and worker together only when the planned rollout is ready;
  test local `/ready`, public HTTPS `/ready`, logs, admin endpoints and the
  worker. Verify exact backend version after startup. Keep rollback available.
- NEVER run project integration tests against the production database: tests
  modify fixture tables. Never automatically restore a production DB backup.
- Never commit or print real server address, SSH key, env file, API tokens,
  database dump, Google Play JSON, secrets, account data, or unredacted logs.

## Fresh, safe VPS inspection

`ops/vps/snapshot_from_termux.sh` gathers an allowlisted read-only JSON report
from the user's configured SSH connection. It does **not** deploy. Review
`ops/vps/state/current.json` locally before committing to a public repo.
If there is no recent report, say **"production current state unverified"**.
Read `ops/vps/DEPLOY_GUARDS.md` for detailed checks and failure recovery.

## Application versioning

User instruction (2026-11-05): increase the application version for every app
update. Update `pubspec.yaml` version/build and `GardenPackRegistry.appBuild`
together; never reuse an Android versionCode for a new release. Current UI
planner candidate: 1.10.1+63.

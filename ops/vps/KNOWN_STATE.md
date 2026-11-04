# BetterSeed VPS — dated operational evidence (NOT live configuration)

This document records evidence from the user-operated VPS, not deployment
instructions or current authentication details. **Do not claim these facts are
current after another deployment until a new read-only snapshot verifies them.**

## 2026-11-04 08:14:10 UTC — first preflight (verified)

| Detail | Observed value |
|---|---|
| Topology | Ubuntu VPS, systemd, native MySQL, Caddy |
| Application path | `/opt/betterseed-api` |
| Services | `betterseed-api.service` and `betterseed-worker.service`: active |
| Backend package | **1.2.0** |
| Node / npm | v24.22.1 / 11.19.1 |
| MySQL client | 8.0.46 |
| Migration files on disk | 001, 002, 003 |
| Local and public `/ready` | HTTP 200 |
| Configuration (contents NOT captured) | `/etc/betterseed/api.env`, `db.env` and `google-play.json` present |

The GitHub repo's `server/compose.yaml` is not the VPS's running layout.

## 2026-11-04 08:15 UTC — failed upgrade attempt #1

- The initial deployment package built backend **1.3.0** in staging and backed
  up source and database.
- It stopped API/worker and ran `dist/migrate.js` as runtime DB account
  `betterseed_api`. `001_initial.sql` issued `CREATE TABLE IF NOT EXISTS users`;
  MySQL returned `ER_TABLEACCESS_DENIED_ERROR` / `CREATE command denied`.
- Source rollback was attempted. At that time the script did not prove
  service recovery. A subsequent preflight (next section) later showed the
  old services were healthy.
- Backup directory logged: `/var/backups/betterseed/upgrade-20261104T081525Z`.
  Backups contain private user data; do **not** commit or copy them publicly.

## 2026-11-04 08:27 UTC — failed upgrade attempt #2

- The v2 deploy preflight showed the **1.2.0** services and local/public
  `/ready` healthy, with admin MySQL socket accessible.
- Staging `npm ci`, TypeScript checks/build, and `argon2` native smoke check
  passed. Privileged migration permissions and the existing schema checked OK.
- A private full database backup was written under
  `/var/backups/betterseed/upgrade-20261104T082745Z`.
- The privileged migrator successfully applied **ONLY migration 004**
  (`database_gate` table + singleton row) before stopping old services.
  The script reported `Runtime DB gate access: OK`.
- The subsequent v1.3.0 service startup **failed readiness**. The systemd
  journal showed:

  ```text
  Error: Cannot find module '/opt/betterseed-api/dist/index.js'
  Error: Cannot find module '/opt/betterseed-api/dist/worker.js'
  code: 'MODULE_NOT_FOUND'
  ```
- The exact cause of these errors **on the VPS** was not directly verified.
  Restrictive root-owned parent directories in the v2 script produced this
  error in a local reproduction. Check directory execute/traverse permissions
  *as the service's configured User* and check actual compiled file paths.
- v2 attempted to restore source 1.2.0; it did NOT roll back SQL migration 004
  (expected: MySQL DDL is not transactionally reversible).

## After attempt #2 — rollback health VERIFIED by the user

The user executed a read-only SSH check and provided these exact outputs:

```text
active
active
1.2.0
API HTTP 200
```

The checks covered both systemd units, `/opt/betterseed-api/package.json`, and
local `http://127.0.0.1:8080/ready`. The second attempt's journal confirms
missing module entrypoints during the failed startup; the above results verify
that **source 1.2.0 was restored and both services were healthy at inspection**.
No subsequent successful 1.3.0 deployment has been shown in this conversation.

**Last observed code status: backend v1.2.0 running.**
**Last observed schema change: migration 004 applied successfully.**
**CURRENT LIVE STATUS: UNKNOWN UNTIL REFRESHED** after any new deploy.

## Source-repo state and what NOT to assume

- GitHub `main` at `a1aa3bd0b97f2b9366db8d087f2d034e7399a7fe`
  contains **backend v1.3.0** and migration files 001–004.
- GitHub Actions backend tests passed. They do not deploy to this VPS.
- A v3 deployment kit was prepared with improved runtime permissions and
  diagnostics but was **not shown successfully deployed** in the logs.
- Do not repeat migration 004 unnecessarily or revert/drop `database_gate`.
  A new deployment must first check current table and singleton-row state.

## Before next production operation

1. Obtain a fresh read-only snapshot: `ops/vps/snapshot_from_termux.sh`.
2. Confirm service health, runtime version, compiled file paths and table 004.
3. Inspect `systemctl show` for User/Group and compare to actual path ownership
   and access using read-only checks. Never print unit Environment contents.
4. Review and back up first, build staging, validate runtime readability,
   then perform an explicitly authorized coordinated restart.
5. Use `ops/vps/DEPLOY_GUARDS.md` and `server/UPGRADE.md`.

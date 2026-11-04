# Production deployment guards — BetterSeed native systemd

This is a **checklist for a human-approved production change**, not a deploy
script. The existing VPS is native Ubuntu + systemd + MySQL + Caddy.

## 0. Read, confirm, and get authorization

- Consult `AGENTS.md`, `KNOWN_STATE.md`, and a *fresh* `state/current.json`.
- Explicitly confirm the user's approval before touching the production VPS.
- A GitHub build passing does not prove that a production rollout is safe.
- Never display raw passwords, environment variables or production logs
  containing tokens. Do not send host IP/key or backups to a public repo.

## 1. Preflight (read-only, BEFORE downtime)

- Confirm exact live code version, `/ready`, both systemd states and
  `WorkingDirectory`, active Node/npm, and existing DB migration state.
- Check systemd **effective User and Group** via `systemctl show -p User
  -p Group`; verify service `ExecStart`, not merely `package.json` scripts.
  Do not dump full unit files, which could contain secrets.
- Inspect `namei -l /opt/betterseed-api/dist/index.js` and the analogous
  `worker.js` on staging once built. Each parent directory requires `x`
  (traverse); each entrypoint requires `r` for the actual service account.
- Check the compiled output is in **`dist/index.js` and `dist/worker.js`**,
  not `dist/src/` or another path, before stopping existing services or swapping production.
- A TypeScript build success alone is not a runtime test: the v2 deployment
  built successfully but systemd logged `MODULE_NOT_FOUND` for both files.
- Verify `argon2` native dependencies under the same Node runtime and
  deployment architecture. Do not assume npm warnings are harmless.
- Verify database 004 table/row status before touching migration state.

## 2. Safe migration and backup

- Back up both the **complete** existing source and **full** MySQL database,
  confirm backup success, and keep files private with appropriate retention.
- Preserve existing `/etc/betterseed/` and keys, database volume and version.
- Avoid running the generic `dist/migrate.js` as `betterseed_api`: it executes
  all 001–004 SQL files and lacks CREATE privileges. Use only a separately
  approved privileged migration method and reviewed incremental SQL.
- In the last observed v2 attempt, `004_database_gate.sql` was applied and
  the app user's access to it passed; do not recreate or drop it blindly.
- Do not run integration tests (which can delete fixture data) on production.

## 3. Atomic deployment preparation

- Build in a staging directory using the same runtime architecture.
- Assert both entrypoints exist *after packaging and after installation*.
- Check source copy preserves the intended directory layout and is owned
  or traversable/readable by each systemd user. Prefer owner/group-preserving
  file installation with permissions reviewed for non-secret build outputs.
- Do not copy `umask 077` root-owned `700` source directories unchanged into
  a service owned by a separate non-root user.
- **Do not relax permissions on production `.env` or provider JSON** to fix
  runtime issues; config remains private and available only to authorized
  service accounts.
- Test access using the exact unit user (read-only) before starting services.
- Prepare a tested rollback strategy before stopping the old API/worker.

## 4. Rollout and health

- Coordinate stopping and starting API/worker; avoid mixed 1.2/1.3 processes.
- Verify both `systemctl is-active` outputs, exact runtime package version,
  actual compiled paths, local `/ready=200` and public HTTPS `/ready=200`.
- Inspect bounded, redacted `journalctl` if either service fails.
- Validate expected admin/UI and sync functionality with safe test accounts.
- If rollback is needed, restore source and service permissions, then verify
  both services and readiness. **MySQL DDL remains after code rollback**.
- Record outcome in `KNOWN_STATE.md` only after direct observation. Never
  claim success based solely on an upload/build/deploy script exit code.

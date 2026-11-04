# Existing BetterSeed VPS — production reference for Codex

**Do not assume GitHub HEAD is deployed.** The last verified VPS backend was
**1.2.0**, whereas the GitHub snapshot at that time carried **1.3.0**. After the 2026-11-04
failed deployment, the real VPS had both services active and local `/ready=200`;
MySQL migration 004 had been successfully applied. This is dated evidence,
not a live status report.

## Existing deployment topology

| Purpose | Actual deployment |
|---|---|
| Application root | `/opt/betterseed-api` |
| Runtime | Node.js 24 on Ubuntu |
| Process supervisor | systemd: `betterseed-api.service`, `betterseed-worker.service` |
| Database | Native MySQL; NOT a Docker Compose database |
| Reverse proxy | Caddy |
| Configuration | `/etc/betterseed/` — sensitive, never copy to GitHub |
| Backups | Private `/var/backups/betterseed/` |
| Optional Garden Pack assets | Separate CDN/R2, unaffected by backend rollout |

Read `KNOWN_STATE.md` for both failed upgrade attempts and the verified
rollback, `DEPLOY_GUARDS.md` for prevention, and `server/UPGRADE.md` for
software requirements. Docker instructions in `server/README.md` are optional
for separate/new installs, **not** the correct production deployment path.

## Obtain a fresh read-only report via Termux

From a Termux checkout of the repository, with existing working SSH auth:

```bash
export BETTERSEED_SSH_TARGET='YOUR_SSH_USER@YOUR_VPS_HOST'
export BETTERSEED_SSH_KEY="$HOME/.ssh/betterseed_api_ed25519"
bash ops/vps/snapshot_from_termux.sh
python3 -m json.tool ops/vps/state/current.json
```

This script sends a read-only collector over SSH, asks for sudo on the VPS,
queries allowlisted systemd/Node/MySQL metadata, and retrieves JSON. It does
not deploy, restart services, perform SQL changes, display credential values,
or push GitHub commits. It creates/removes temporary files on the VPS only.
Review report timestamps and content **before** adding it to public GitHub.

A successful snapshot includes runtime `backend_package_version`, service
states, local `/ready`, migration filenames and read-only `database_gate`
table presence. It does NOT verify all features or prove future health.
A snapshot captured before the most recent deployment is stale.

## Sharing reviewed VPS facts with Codex

1. Keep the permanent instructions in `AGENTS.md` and the dated notes in
   `KNOWN_STATE.md` (both safe for a public repository).
2. Optionally commit **only a manually reviewed, sanitized**
   `ops/vps/state/current.json` after running the collector. No host IP,
   credentials, personal records, raw `systemctl cat` output or DB dumps.
3. Update the dated observations after any new attempted upgrade, including
   failed/rolled-back deployments and validated recovery. Mark uncertainty.
4. The snapshot is a report, **not** a task to upgrade production.

## Important MySQL restriction

The production runtime account `betterseed_api` cannot `CREATE TABLE`.
`server/src/migrate.ts` replays **all** migration files on every run; this
fails even for existing `CREATE TABLE IF NOT EXISTS` statements when executed
as the runtime user. Use a separate approved administrative migration account
for reviewed DDL. The **004 database_gate migration has already been applied**
on the VPS in the 08:27 UTC attempt; verify before planning any changes.
Do not grant permanent DDL rights to the app user or run integration tests
against production: those tests mutate data.

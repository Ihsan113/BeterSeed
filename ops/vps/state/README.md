# Reviewable, read-only VPS snapshots

`current.json` is generated only by `ops/vps/snapshot_from_termux.sh` from
live, authorized VPS inspection. It is **not included** in this source archive
because we have no fresh machine-readable snapshot after the latest rollback.

The last user-provided check verified both services active, backend 1.2.0,
local HTTP 200, after the v2 failure; see `../KNOWN_STATE.md`. A successful
SQL 004 migration preceded that rollback. A future snapshot may differ.

Before committing a snapshot to this public repository, inspect the content
for server addresses, credentials, private environment variables, account
records, DB names, or other sensitive data. Do not commit raw dumps, systemd
unit listings or private logs. A snapshot becomes stale after any deploy.

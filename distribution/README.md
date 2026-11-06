# BetterSeed backend — Checklist & Statistics 2.1 candidate

Backend source **1.4.0**. ZIP: [BetterSeed-server.zip](BetterSeed-server.zip),
with its [SHA-256 checksum](BetterSeed-server.zip.sha256).

Includes v1/v2/v3 snapshot compatibility, strict planner validation, downgrade
protection, source tests and production guards. Read `CHECKLIST_2_1_CONTRACT.md`,
`CHECKLIST_2_1_VALIDATION.md` and `UPGRADE.md` inside the archive. Snapshot v3 and
local backend tests were approved; production deployment was not. Production
current state unverified. A repository ZIP is not deployment evidence.

No new SQL migration. No production configuration, secrets, database or
node_modules is included. Production changes require separate authorization
and the VPS guards. Rebuild using `python3 scripts/package_server.py`.

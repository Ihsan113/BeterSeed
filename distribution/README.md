# BetterSeed backend — Checklist 2.0 review candidate

Source ZIP: [BetterSeed-server.zip](BetterSeed-server.zip), with its
[SHA-256 checksum](BetterSeed-server.zip.sha256).

Includes v1/v2 snapshot compatibility, validation, the legacy overwrite guard,
source tests and upgrade instructions. Read `CHECKLIST_2.md` and `UPGRADE.md`
inside the archive. This candidate retains the previous package version until
release approval. A repository ZIP is not evidence of production deployment.

No new SQL migration. No production configuration, secrets, database or
node_modules is included. Production changes require separate authorization
and the VPS guards. Rebuild using `python3 scripts/package_server.py`.

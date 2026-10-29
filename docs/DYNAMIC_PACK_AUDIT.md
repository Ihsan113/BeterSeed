# Dynamic garden catalog audit and migration plan

Base: GitHub main `bc16a2d`; production source archive `AdminVPS-Safe-20261028-083945.zip`.

The uploaded runtime sources match the previous account/admin release. Its Dockerfile omits public admin assets, Compose omits HOST, and its tests/docs predate the last GitHub release. Preserve the working native VPS loopback bind and deployed secrets; retain GitHub's Docker fixes, migrations and regression tests. The archive does not contain migrations or runtime secrets.

Current coupling: static billing costs and pack enums, three ownership booleans in Home, static Shop cards and renderer switches, static background-key validation, backup ownership hints, and native widget theme switches. These require coordinated changes. Existing Play SKU verification/refund/consumption is independent and must remain unchanged.

Plan: additive MySQL 8.0-compatible catalog with immutable IDs and per-row revision; price/revision confirmation inside the same transaction as wallet debit and entitlement insertion. Keep legacy price only as a migration-time safety ceiling/identity for old clients: accept old requests only while catalog still exactly matches its original offer. Active-only new acquisitions; existing entitlement wins regardless of visibility/retirement. Free packs require an explicit online claim so later premium conversion preserves rights. Default remains always free.

Admin uses existing cookie/TOTP/CSRF/origin checks and audit. Local APK registry owns assets; catalog never supplies file paths. Unknown/unsupported packs cannot be bought from this APK. Account-scoped wallet cache remains authoritative for offline collection; catalog cache never grants ownership. Restore ignores financial ownership hints and preserves known cosmetic IDs subject to the current account's entitlements.

Deployment: migrate and restart backend first, verify compatibility, then release APK. No production deployment or credential changes are part of this work.

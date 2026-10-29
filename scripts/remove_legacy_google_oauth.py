"""Optional one-time repo checkout cleanup after extracting v1.3.0 ZIP."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
old = (
    'lib/backup/drive_backup_service.dart',
    'lib/backup/drive_connection_diagnostic.dart',
    'test/drive_connection_diagnostic_test.dart',
    'test/drive_backup_snapshot_test.dart',
    'docs/GOOGLE_DRIVE_BACKUP_v1.2.0.md',
    'docs/GOOGLE_DRIVE_DIAGNOSTICS_v1.2.4.md',
    'docs/GOOGLE_SIGNIN_PROVIDER_CODES_v1.2.5.md',
)
for relative in old:
    p = root / relative
    if p.is_file():
        p.unlink()
        print('Removed legacy file:', relative)
print('Legacy Google OAuth cleanup complete; review git status before committing.')

#!/usr/bin/env python3
"""Read-only, allowlisted runtime summary for an existing BetterSeed VPS.

Run under sudo on the VPS. No source/DB mutations, no config values printed.
Output ONE JSON object only (safe to review before committing). Never trace
shell env, dump databases, or output full systemd service definitions.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess

PROD = Path('/opt/betterseed-api')
MIGRATIONS = PROD / 'migrations'
EXPECTED = ('betterseed-api.service', 'betterseed-worker.service')
DB_OBJECTS = ('users', 'admin_users', 'garden_packs', 'database_gate')


def call(argv: list[str], timeout: int = 8) -> tuple[bool, str]:
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=timeout,
                           check=False, encoding='utf-8', errors='replace')
        return p.returncode == 0, p.stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return False, ''


def version(command: list[str]) -> str | None:
    ok, result = call(command)
    return result[:100] if ok and result else None


def deployed_version() -> str | None:
    try:
        v = json.loads((PROD / 'package.json').read_text('utf-8')).get('version')
        return v if isinstance(v, str) and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:[-+][a-zA-Z0-9.-]+)?', v) else None
    except (OSError, ValueError, TypeError):
        return None


def deployed_git_commit() -> str | None:
    try:
        sha = (PROD / '.betterseed-git-commit').read_text('utf-8').strip()
        return sha if re.fullmatch(r'[a-f0-9]{40}', sha) else None
    except OSError:
        return None


def compiled_hash() -> str | None:
    try:
        h = hashlib.sha256()
        with (PROD / 'dist/index.js').open('rb') as source:
            for block in iter(lambda: source.read(1024 * 1024), b''):
                h.update(block)
        return h.hexdigest()
    except OSError:
        return None


def service(name: str) -> dict:
    active_ok, state = call(['systemctl', 'is-active', name])
    wd_ok, directory = call(['systemctl', 'show', '-p', 'WorkingDirectory',
                             '--value', name])
    return {'active': active_ok and state == 'active',
            'working_directory_matches_expected': wd_ok and directory == str(PROD)}


def database_metadata() -> dict:
    # Never output DB env values. Node's --env-file parses existing private
    # files as the application does; only the database identifier is used
    # internally to choose a read-only SHOW TABLES query.
    args = ['node']
    for path in ('/etc/betterseed/api.env', '/etc/betterseed/db.env'):
        if Path(path).is_file():
            args.append(f'--env-file={path}')
    args.extend(['-p', 'process.env.MYSQL_DATABASE || "betterseed"'])
    ok, db_name = call(args)
    if not ok or not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', db_name):
        return {'privileged_read_only_query_available': False,
                'tables_present': {name: None for name in DB_OBJECTS},
                'mysql_server_version': None}
    ok, server_version = call(['mysql', '--protocol=socket', '--batch',
                               '--skip-column-names', '--execute', 'SELECT VERSION()'])
    if not ok:
        return {'privileged_read_only_query_available': False,
                'tables_present': {name: None for name in DB_OBJECTS},
                'mysql_server_version': None}
    status = {}
    for name in DB_OBJECTS:
        ok, result = call([
            'mysql', '--protocol=socket', '--batch', '--skip-column-names',
            '--database', db_name,
            '--execute', ("SELECT COUNT(*) FROM information_schema.tables "
                          "WHERE table_schema=DATABASE() AND table_name='" + name + "'")])
        status[name] = result == '1' if ok else None
    return {'privileged_read_only_query_available': True,
            'tables_present': status,
            'mysql_server_version': server_version[:100]}


def main() -> None:
    ready_ok, code = call(['curl', '-sS', '-o', '/dev/null', '--max-time', '5',
                           '-w', '%{http_code}', 'http://127.0.0.1:8080/ready'])
    migrations = sorted(p.name for p in MIGRATIONS.glob('*.sql') if p.is_file())
    report = {
        'schema_version': 1,
        'origin': 'read_only_vps_snapshot',
        'collected_at_utc': datetime.now(timezone.utc).isoformat(timespec='seconds'),
        'deployment': {
            'type': 'native_ubuntu_systemd_mysql',
            'directory': str(PROD),
            'backend_package_version': deployed_version(),
            'deployed_git_commit_marker': deployed_git_commit(),
            'compiled_api_sha256': compiled_hash(),
            'node_version': version(['node', '--version']),
            'npm_version': version(['npm', '--version']),
            'mysql_client_version': version(['mysql', '--version']),
            'migration_sql_files_on_disk': migrations,
        },
        'services': {name: service(name) for name in EXPECTED},
        'local_ready_http_status': int(code) if ready_ok and code.isdecimal() else None,
        'database': database_metadata(),
        'caution': 'Read-only observations only; review timestamp after every deployment.',
    }
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()

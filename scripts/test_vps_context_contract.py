"""Safety and accuracy contract for repository-level VPS context given to Codex."""
from pathlib import Path
import importlib.util
import ipaddress
import re
import io
import json
import unittest
from unittest import mock
from contextlib import redirect_stdout

ROOT = Path(__file__).resolve().parents[1]
COLLECTOR = ROOT / 'ops/vps/collect_state.py'


class VpsContextContractTest(unittest.TestCase):
    def test_agent_knows_this_is_native_systemd_not_production_compose(self):
        guide = (ROOT / 'AGENTS.md').read_text('utf-8')
        for key in ('/opt/betterseed-api', 'betterseed-api.service',
                    'betterseed-worker.service', 'native MySQL',
                    'not a deployment receipt', 'restricted',
                    'snapshot_from_termux.sh'):
            self.assertIn(key, guide)
        history = (ROOT / 'ops/vps/KNOWN_STATE.md').read_text('utf-8')
        for phrase in ('UNKNOWN UNTIL REFRESHED', 'migration 004',
                       'MODULE_NOT_FOUND', '1.2.0', 'API HTTP 200'):
            self.assertIn(phrase, history)
        guards = (ROOT / 'ops/vps/DEPLOY_GUARDS.md').read_text('utf-8')
        for phrase in ('dist/index.js', 'dist/worker.js', 'systemd',
                       'umask 077', 'before stopping'):
            self.assertIn(phrase, guards)
        latest = ROOT / 'ops/vps/state/current.json'
        if latest.exists():
            data = json.loads(latest.read_text('utf-8'))
            self.assertEqual(data['origin'], 'read_only_vps_snapshot')
            self.assertIn('collected_at_utc', data)
            self.assertNotIn('private_key', latest.read_text('utf-8').lower())

    def test_no_host_or_secrets_embedded_in_vps_docs(self):
        paths = [ROOT / 'AGENTS.md', ROOT / 'ops/vps/KNOWN_STATE.md',
                 ROOT / 'ops/vps/README.md',
                 ROOT / 'ops/vps/snapshot_from_termux.sh',
                 ROOT / 'ops/vps/collect_state.py',
                 ROOT / 'ops/vps/DEPLOY_GUARDS.md']
        contents = '\n'.join(p.read_text('utf-8') for p in paths)
        for literal_ip in re.findall(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', contents):
            self.assertFalse(ipaddress.ip_address(literal_ip).is_global,
                             'Do not commit public VPS addresses')
        self.assertNotIn('BEGIN OPENSSH PRIVATE KEY', contents)
        self.assertNotIn('gsk_', contents)
        self.assertNotIn('api_key=', contents.lower())
        self.assertIn('review', contents.lower())

    def test_collector_emits_allowlisted_readonly_snapshot(self):
        spec = importlib.util.spec_from_file_location('vps_collect', COLLECTOR)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        def fake_call(argv, timeout=8):
            if argv[:2] == ['systemctl', 'is-active']:
                return True, 'active'
            if argv[:2] == ['systemctl', 'show']:
                return True, '/opt/betterseed-api'
            if 'curl' in argv[0]:
                return True, '200'
            if argv[:2] == ['node', '--version']:
                return True, 'v24.22.1'
            if argv[:2] == ['npm', '--version']:
                return True, '11.19.1'
            return False, ''
        with mock.patch.object(module, 'call', side_effect=fake_call), \
             mock.patch.object(module, 'deployed_version', return_value='1.2.0'), \
             mock.patch.object(module, 'deployed_git_commit', return_value=None), \
             mock.patch.object(module, 'compiled_hash', return_value=None), \
             mock.patch.object(module, 'database_metadata', return_value={
                 'privileged_read_only_query_available': False,
                 'tables_present': {name: None for name in module.DB_OBJECTS},
                 'mysql_server_version': None,
             }), \
             redirect_stdout(io.StringIO()) as captured:
            module.main()
        report = json.loads(captured.getvalue())
        self.assertEqual(report['schema_version'], 1)
        self.assertEqual(report['origin'], 'read_only_vps_snapshot')
        self.assertEqual(report['deployment']['backend_package_version'], '1.2.0')
        self.assertEqual(report['local_ready_http_status'], 200)
        self.assertTrue(report['services']['betterseed-api.service']['active'])
        self.assertNotIn('password', captured.getvalue().lower())
        self.assertNotIn('host_ip', captured.getvalue().lower())


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env bash
# Run from Termux with your existing SSH key. No production changes.
set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd -- "$HERE/../.." && pwd)"
TARGET="${BETTERSEED_SSH_TARGET:?Set BETTERSEED_SSH_TARGET=user@host locally; do not commit it}"
KEY="${BETTERSEED_SSH_KEY:-$HOME/.ssh/betterseed_api_ed25519}"
DEST="$REPO/ops/vps/state/current.json"
[[ -f "$KEY" ]] || { echo 'ERROR: SSH key not found.' >&2; exit 1; }
for c in ssh scp; do command -v "$c" >/dev/null || { echo "Missing $c" >&2; exit 1; }; done

SSHOPTS=(-i "$KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes)
REMOTE=$(ssh "${SSHOPTS[@]}" "$TARGET" 'mktemp -d "$HOME/.betterseed-state.XXXXXXXX"')
[[ "$REMOTE" =~ ^/home/[A-Za-z0-9._-]+/\.betterseed-state\.[A-Za-z0-9]+$ ]] || {
  echo 'ERROR: unexpected remote temp path. Nothing was executed.' >&2
  exit 1
}
cleanup() { ssh "${SSHOPTS[@]}" "$TARGET" "rm -rf -- '$REMOTE'" >/dev/null 2>&1 || true; }
trap cleanup EXIT
scp -q "${SSHOPTS[@]}" "$HERE/collect_state.py" "$TARGET:$REMOTE/collector.py"
echo 'Collecting read-only VPS state. Sudo may ask for your VPS password.'
# Redirect stdout on the VPS itself so SSH/sudo prompts cannot corrupt JSON.
ssh -tt "${SSHOPTS[@]}" "$TARGET" \
  "sudo python3 '$REMOTE/collector.py' > '$REMOTE/report.json'"
mkdir -p "$(dirname -- "$DEST")"
TEMP="$(mktemp "${DEST}.XXXXXXXX.tmp")"
trap 'rm -f "$TEMP"; cleanup' EXIT
scp -q "${SSHOPTS[@]}" "$TARGET:$REMOTE/report.json" "$TEMP"
# Check basic structure before moving to the tracked candidate path.
python3 - "$TEMP" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]); d = json.loads(p.read_text('utf-8'))
assert d['schema_version'] == 1
assert d['origin'] == 'read_only_vps_snapshot'
assert 'services' in d and 'deployment' in d and 'database' in d
for prohibited in ('password', 'token', 'private_key', 'secret', 'host_address', 'client_email'):
    assert prohibited not in p.read_text('utf-8').lower(), 'Unexpected sensitive field'
PY
mv "$TEMP" "$DEST"
echo "Collected: $DEST"
echo 'Review this allowlisted snapshot carefully BEFORE adding it to GitHub.'
echo 'No production changes were made; this command does not commit or push.'

#!/usr/bin/env bash
set -euo pipefail

REPO=""
PASSPHRASE_FILE="${HOME}/.openclaw/backup-sensitive-passphrase.txt"
SRC_OPENCLAW="${HOME}/.openclaw"
SRC_WORKSPACE="/Users/dong/clawd"
ARCHIVE_REL="openclaw-sensitive/latest.tar.gz.enc"
MANIFEST_REL="openclaw-sensitive/MANIFEST.json"

usage() {
  cat <<'EOF'
Usage:
  backup-openclaw-sensitive.sh --repo /path/to/repo [--passphrase-file /path/to/file]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --passphrase-file) PASSPHRASE_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$REPO" ]] || { echo "--repo is required" >&2; exit 1; }
[[ -d "$REPO" ]] || { echo "Repo path not found: $REPO" >&2; exit 1; }
mkdir -p "$(dirname "$PASSPHRASE_FILE")"
if [[ ! -f "$PASSPHRASE_FILE" ]]; then
  openssl rand -hex 32 > "$PASSPHRASE_FILE"
  chmod 600 "$PASSPHRASE_FILE"
fi
chmod 600 "$PASSPHRASE_FILE" || true

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
STAGE="$WORKDIR/payload"
mkdir -p "$STAGE/home-openclaw" "$STAGE/workspace-clawd"

copy_path() {
  local src="$1"
  local dest="$2"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    rsync -a --delete --exclude '.git/' --exclude '.gitmodules' --exclude '.DS_Store' "$src" "$dest"
  fi
}
copy_file() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

# Sensitive roots
copy_path "$SRC_OPENCLAW/credentials/" "$STAGE/home-openclaw/credentials/"
copy_path "$SRC_OPENCLAW/devices/" "$STAGE/home-openclaw/devices/"
copy_path "$SRC_OPENCLAW/identity/" "$STAGE/home-openclaw/identity/"
copy_path "$SRC_OPENCLAW/telegram/" "$STAGE/home-openclaw/telegram/"
copy_file "$SRC_OPENCLAW/openclaw.json" "$STAGE/home-openclaw/openclaw.json"

# Agent-local auth/cookies/config bits
python3 - <<'PY' "$SRC_OPENCLAW" "$STAGE/home-openclaw"
import os, shutil, sys
src_root, dest_root = sys.argv[1], sys.argv[2]
include_names = {
    'auth.json', 'identity.json', 'cookies.json', 'cookies_backup.json'
}
prefix_names = ('auth-profiles.json', 'cookies_backup_')
for dirpath, dirnames, filenames in os.walk(src_root):
    dirnames[:] = [d for d in dirnames if d not in {'.git', 'sessions', 'logs', 'browser', 'canvas', 'media', 'delivery-queue'}]
    for name in filenames:
        if name in include_names or name.startswith(prefix_names):
            src = os.path.join(dirpath, name)
            rel = os.path.relpath(src, src_root)
            dest = os.path.join(dest_root, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy2(src, dest)
PY

# Workspace-sensitive docs/files
copy_file "$SRC_WORKSPACE/TOOLS.md" "$STAGE/workspace-clawd/TOOLS.md"
copy_file "$SRC_WORKSPACE/MEMORY.md" "$STAGE/workspace-clawd/MEMORY.md"

python3 - <<'PY' "$SRC_WORKSPACE" "$STAGE/workspace-clawd"
import os, shutil, sys
src_root, dest_root = sys.argv[1], sys.argv[2]
for dirpath, dirnames, filenames in os.walk(src_root):
    dirnames[:] = [d for d in dirnames if d not in {'.git', 'node_modules', 'dist', 'build'}]
    for name in filenames:
        if name == 'cookies.json' or name.startswith('cookies_backup'):
            src = os.path.join(dirpath, name)
            rel = os.path.relpath(src, src_root)
            dest = os.path.join(dest_root, rel)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            shutil.copy2(src, dest)
PY

STAMP="$(date '+%Y-%m-%dT%H-%M-%S%z')"
mkdir -p "$REPO/$(dirname "$ARCHIVE_REL")"

tar -C "$WORKDIR" -czf - payload | \
  openssl enc -aes-256-cbc -pbkdf2 -salt -pass file:"$PASSPHRASE_FILE" -out "$REPO/$ARCHIVE_REL"

cat > "$REPO/$MANIFEST_REL" <<EOF
{
  "createdAt": "$STAMP",
  "archive": "$ARCHIVE_REL",
  "passphraseFile": "$PASSPHRASE_FILE",
  "format": "openssl-aes-256-cbc-pbkdf2"
}
EOF

echo "Encrypted sensitive backup written to: $REPO/$ARCHIVE_REL"

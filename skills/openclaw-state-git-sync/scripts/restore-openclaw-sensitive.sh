#!/usr/bin/env bash
set -euo pipefail

FROM=""
PASSPHRASE_FILE="${HOME}/.openclaw/backup-sensitive-passphrase.txt"
ARCHIVE_REL="openclaw-sensitive/latest.tar.gz.enc"
DEST_OPENCLAW="${HOME}/.openclaw"
DEST_WORKSPACE="/Users/dong/clawd"

usage() {
  cat <<'EOF'
Usage:
  restore-openclaw-sensitive.sh --from /path/to/repo [--passphrase-file /path/to/file]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --passphrase-file) PASSPHRASE_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$FROM" ]] || { echo "--from is required" >&2; exit 1; }
[[ -f "$FROM/$ARCHIVE_REL" ]] || { echo "Encrypted archive not found: $FROM/$ARCHIVE_REL" >&2; exit 1; }
[[ -f "$PASSPHRASE_FILE" ]] || { echo "Passphrase file not found: $PASSPHRASE_FILE" >&2; exit 1; }

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
STAMP="$(date '+%Y-%m-%dT%H-%M-%S%z')"

openssl enc -d -aes-256-cbc -pbkdf2 -pass file:"$PASSPHRASE_FILE" -in "$FROM/$ARCHIVE_REL" | tar -C "$WORKDIR" -xzf -
SRC="$WORKDIR/payload"

backup_existing() { [[ -e "$1" ]] && mv "$1" "$1.pre-restore-$STAMP"; }
restore_path() {
  local src="$1"
  local dest="$2"
  if [[ -e "$src" ]]; then
    backup_existing "$dest"
    mkdir -p "$(dirname "$dest")"
    rsync -a --exclude '.git/' --exclude '.gitmodules' "$src" "$dest"
  fi
}
restore_file() {
  local src="$1"
  local dest="$2"
  if [[ -f "$src" ]]; then
    backup_existing "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

restore_path "$SRC/home-openclaw/credentials/" "$DEST_OPENCLAW/credentials/"
restore_path "$SRC/home-openclaw/devices/" "$DEST_OPENCLAW/devices/"
restore_path "$SRC/home-openclaw/identity/" "$DEST_OPENCLAW/identity/"
restore_path "$SRC/home-openclaw/telegram/" "$DEST_OPENCLAW/telegram/"
restore_file "$SRC/home-openclaw/openclaw.json" "$DEST_OPENCLAW/openclaw.json"

# Restore any captured nested sensitive files
if [[ -d "$SRC/home-openclaw" ]]; then
  rsync -a "$SRC/home-openclaw/" "$DEST_OPENCLAW/"
fi
if [[ -d "$SRC/workspace-clawd" ]]; then
  rsync -a "$SRC/workspace-clawd/" "$DEST_WORKSPACE/"
fi

echo "Sensitive restore complete. Previous files were renamed with .pre-restore-$STAMP"

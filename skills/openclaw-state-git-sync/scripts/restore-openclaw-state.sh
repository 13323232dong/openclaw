#!/usr/bin/env bash
set -euo pipefail

PROFILE="core"
FROM=""
DEST_OPENCLAW="${HOME}/.openclaw"
DEST_WORKSPACE="/Users/dong/clawd"

usage() {
  cat <<'EOF'
Usage:
  restore-openclaw-state.sh --from /path/to/repo [--profile core|full]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --from) FROM="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$FROM" ]] || { echo "--from is required" >&2; exit 1; }
SRC="$FROM/openclaw-state"
[[ -d "$SRC" ]] || { echo "Snapshot dir not found: $SRC" >&2; exit 1; }
STAMP="$(date '+%Y-%m-%dT%H-%M-%S%z')"
mkdir -p "$DEST_OPENCLAW" "$DEST_WORKSPACE"

backup_existing() { [[ -e "$1" ]] && mv "$1" "$1.pre-restore-$STAMP"; }
restore_path() {
  local src="$1" dest="$2"
  if [[ -e "$src" ]]; then
    backup_existing "$dest"
    mkdir -p "$(dirname "$dest")"
    rsync -a --exclude '.git/' --exclude '.gitmodules' --exclude '.github/' "$src" "$dest"
  fi
}
restore_file() {
  local src="$1" dest="$2"
  if [[ -f "$src" ]]; then
    backup_existing "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

restore_file "$SRC/home-openclaw/openclaw.json" "$DEST_OPENCLAW/openclaw.json"
restore_file "$SRC/home-openclaw/mcp.json" "$DEST_OPENCLAW/mcp.json"
restore_file "$SRC/home-openclaw/mcp-config.json" "$DEST_OPENCLAW/mcp-config.json"
restore_file "$SRC/home-openclaw/cron/jobs.json" "$DEST_OPENCLAW/cron/jobs.json"
restore_path "$SRC/home-openclaw/agents/" "$DEST_OPENCLAW/agents/"
restore_path "$SRC/home-openclaw/skills/" "$DEST_OPENCLAW/skills/"
restore_path "$SRC/home-openclaw/scripts/" "$DEST_OPENCLAW/scripts/"
restore_path "$SRC/home-openclaw/workspace/" "$DEST_OPENCLAW/workspace/"

if [[ "$PROFILE" == "full" ]]; then
  restore_path "$SRC/home-openclaw/credentials/" "$DEST_OPENCLAW/credentials/"
  restore_path "$SRC/home-openclaw/devices/" "$DEST_OPENCLAW/devices/"
  restore_path "$SRC/home-openclaw/identity/" "$DEST_OPENCLAW/identity/"
  restore_path "$SRC/home-openclaw/telegram/" "$DEST_OPENCLAW/telegram/"
fi

for f in AGENTS.md SOUL.md USER.md TOOLS.md IDENTITY.md HEARTBEAT.md MEMORY.md; do
  restore_file "$SRC/workspace-clawd/$f" "$DEST_WORKSPACE/$f"
done
restore_path "$SRC/workspace-clawd/memory/" "$DEST_WORKSPACE/memory/"
restore_path "$SRC/workspace-clawd/skills/" "$DEST_WORKSPACE/skills/"

echo "Restore complete. Previous files were renamed with .pre-restore-$STAMP"

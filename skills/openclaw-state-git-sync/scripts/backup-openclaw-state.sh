#!/usr/bin/env bash
set -euo pipefail

PROFILE="core"
REPO=""
SRC_OPENCLAW="${HOME}/.openclaw"
SRC_WORKSPACE="/Users/dong/clawd"

usage() {
  cat <<'EOF'
Usage:
  backup-openclaw-state.sh --repo /path/to/repo [--profile core|full]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$REPO" ]] || { echo "--repo is required" >&2; exit 1; }
[[ -d "$REPO" ]] || { echo "Repo path not found: $REPO" >&2; exit 1; }
[[ -d "$SRC_OPENCLAW" ]] || { echo "OpenClaw state dir not found: $SRC_OPENCLAW" >&2; exit 1; }

DEST="$REPO/openclaw-state"
STAMP="$(date '+%Y-%m-%dT%H-%M-%S%z')"
rm -rf "$DEST"
mkdir -p "$DEST/home-openclaw" "$DEST/workspace-clawd"

copy_path() {
  local src="$1" rel="$2" dest="$DEST/$rel"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    rsync -a --delete \
      --exclude '.git/' --exclude '.gitmodules' --exclude '.github/' \
      --exclude 'sessions/' --exclude '*.jsonl' --exclude '*.sqlite' \
      --exclude 'auth.json' --exclude 'auth-profiles.json' \
      --exclude 'cookies.json' --exclude 'cookies_backup*.json' \
      --exclude '*.tmp' --exclude '*.bak' --exclude '.DS_Store' \
      "$src" "$dest"
  fi
}

copy_file() {
  local src="$1" rel="$2" dest="$DEST/$rel"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    cp -f "$src" "$dest"
  fi
}

copy_file "$SRC_OPENCLAW/openclaw.json" "home-openclaw/openclaw.json"
copy_file "$SRC_OPENCLAW/mcp.json" "home-openclaw/mcp.json"
copy_file "$SRC_OPENCLAW/mcp-config.json" "home-openclaw/mcp-config.json"
copy_file "$SRC_OPENCLAW/cron/jobs.json" "home-openclaw/cron/jobs.json"
copy_path "$SRC_OPENCLAW/agents/" "home-openclaw/agents/"
copy_path "$SRC_OPENCLAW/skills/" "home-openclaw/skills/"
copy_path "$SRC_OPENCLAW/scripts/" "home-openclaw/scripts/"
copy_path "$SRC_OPENCLAW/workspace/" "home-openclaw/workspace/"

if [[ "$PROFILE" == "full" ]]; then
  copy_path "$SRC_OPENCLAW/credentials/" "home-openclaw/credentials/"
  copy_path "$SRC_OPENCLAW/devices/" "home-openclaw/devices/"
  copy_path "$SRC_OPENCLAW/identity/" "home-openclaw/identity/"
  copy_path "$SRC_OPENCLAW/telegram/" "home-openclaw/telegram/"
fi

for f in AGENTS.md SOUL.md USER.md TOOLS.md IDENTITY.md HEARTBEAT.md MEMORY.md; do
  copy_file "$SRC_WORKSPACE/$f" "workspace-clawd/$f"
done
copy_path "$SRC_WORKSPACE/memory/" "workspace-clawd/memory/"
copy_path "$SRC_WORKSPACE/skills/" "workspace-clawd/skills/"

find "$DEST" -type d \( -name logs -o -name browser -o -name canvas -o -name media -o -name delivery-queue \) -prune -exec rm -rf {} + || true
cat > "$DEST/SNAPSHOT.json" <<EOF
{"createdAt":"$STAMP","profile":"$PROFILE"}
EOF

echo "Snapshot written to: $DEST"

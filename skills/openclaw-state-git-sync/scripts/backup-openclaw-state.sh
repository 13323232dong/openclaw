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
  local src="$1"
  local rel="$2"
  local dest="$DEST/$rel"
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
  local src="$1"
  local rel="$2"
  local dest="$DEST/$rel"
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

python3 - <<'PY' "$DEST"
import os, re, sys
root = sys.argv[1]
text_exts = {'.md','.txt','.json','.jsonl','.yaml','.yml','.env','.cfg','.conf','.ini','.sh','.py','.ts','.js'}
patterns = [
    (re.compile(r'(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]+)'), '[REDACTED_GITHUB_TOKEN]'),
    (re.compile(r'(sk-[A-Za-z0-9\-_]{20,})'), '[REDACTED_OPENAI_KEY]'),
    (re.compile(r'(xai-[A-Za-z0-9\-_]{10,}|xai[A-Za-z0-9\-_]{10,})'), '[REDACTED_XAI_KEY]'),
    (re.compile(r'(tvly-[A-Za-z0-9\-_]{10,})'), '[REDACTED_TAVILY_KEY]'),
    (re.compile(r'(moltbook_sk_[A-Za-z0-9\-_]+)'), '[REDACTED_MOLTBOOK_KEY]'),
    (re.compile(r'(GOCSPX-[A-Za-z0-9\-_]+)'), '[REDACTED_GOOGLE_CLIENT_SECRET]'),
]
line_keywords = re.compile(r'(password|passwd|api\s*key|client\s*secret|token|refresh\s*token|access\s*token|密码|密钥|令牌)', re.I)
for dirpath, _, filenames in os.walk(root):
    for name in filenames:
        path = os.path.join(dirpath, name)
        _, ext = os.path.splitext(name.lower())
        if ext not in text_exts:
            continue
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                s = f.read()
            orig = s
            for pat, repl in patterns:
                s = pat.sub(repl, s)
            lines = []
            changed = False
            for line in s.splitlines(True):
                if line_keywords.search(line) and ':' in line:
                    prefix, _ = line.split(':', 1)
                    line = prefix + ': [REDACTED]\n'
                    changed = True
                lines.append(line)
            s2 = ''.join(lines)
            if s2 != orig or changed:
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(s2)
        except Exception:
            pass
PY

cat > "$DEST/SNAPSHOT.json" <<EOF
{"createdAt":"$STAMP","profile":"$PROFILE"}
EOF

echo "Snapshot written to: $DEST"

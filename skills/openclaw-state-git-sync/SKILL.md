---
name: openclaw-state-git-sync
description: Back up and restore an OpenClaw installation's brain/toolbox via Git. Use when the user wants disaster recovery, cross-machine sync, backup/restore of ~/.openclaw state, agents, skills, workspace memory files, or model/config continuity across computers.
---

# OpenClaw State Git Sync

Use this skill to manage OpenClaw state outside the code repo, mainly under `~/.openclaw`, plus selected workspace memory/prompt files.

## Purpose

This skill provides a Git-based disaster recovery workflow for:
- config and model settings
- agents and local skills
- workspace prompt files
- long-term memory and daily memory docs
- scripts and selected automation state

## Profiles

### core
Recommended default.

Includes:
- `~/.openclaw/openclaw.json`
- `~/.openclaw/agents/` definitions
- `~/.openclaw/skills/`
- `~/.openclaw/scripts/`
- `~/.openclaw/workspace/`
- `~/.openclaw/cron/jobs.json`
- `~/.openclaw/mcp.json`
- `~/.openclaw/mcp-config.json`
- `/Users/dong/clawd/AGENTS.md`
- `/Users/dong/clawd/SOUL.md`
- `/Users/dong/clawd/USER.md`
- `/Users/dong/clawd/TOOLS.md`
- `/Users/dong/clawd/IDENTITY.md`
- `/Users/dong/clawd/HEARTBEAT.md`
- `/Users/dong/clawd/MEMORY.md`
- `/Users/dong/clawd/memory/`
- `/Users/dong/clawd/skills/`

Excludes by default:
- credentials
- device pairing
- browser state
- logs/cache/temp
- session transcripts
- auth files, cookies, tokens, sqlite files

### full
Only when the user explicitly wants sensitive disaster recovery state too.
May include credentials, devices, identity, telegram state. Prefer a private repo and optional encryption.

### encrypted-sensitive
Recommended for secret material.

Uses OpenSSL AES-256-CBC with PBKDF2 and stores an encrypted archive in the backup repo.
Typical contents:
- `~/.openclaw/credentials/`
- `~/.openclaw/devices/`
- `~/.openclaw/identity/`
- `~/.openclaw/telegram/`
- selected `auth.json`, `auth-profiles.json*`, and `cookies*.json`
- `TOOLS.md` and selected secret-bearing workspace files

## Backup

```bash
bash scripts/backup-openclaw-state.sh --profile core --repo /path/to/repo
```

## Restore

```bash
bash scripts/restore-openclaw-state.sh --from /path/to/repo --profile core
```

## Safety rules

- Default to `core`
- Ask before `full`
- Ask before restoring over an existing `~/.openclaw`
- Prefer a private repo for actual snapshots
- Before restore, stop OpenClaw when possible
- Validate absolute paths in `openclaw.json` after restore

## Notes

This skill should usually be committed to a normal code repo, but actual snapshots should go to a private backup repo unless the user explicitly accepts the exposure risk.

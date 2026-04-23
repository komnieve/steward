# focus-dash

Always-on personal focus dashboard served at `http://localhost:8888/`. Not a productivity tool — a support structure for wholesome work.

Single-page UI. Pin it in a browser tab. Glance. Execute.

## What's in the bundle

| file | what it does |
|------|-------------|
| `index.html` | single-page UI — today tab + watcher tab. Self-hosted fonts, SSE live push, paper + ink aesthetic |
| `priorities.json` | state of the world — northstar, today's 2–4 priorities (each with `action`, `paste`, `block`, `note` sections), `done` history, `if_theres_room` backlog |
| `priorities.skeleton.json` | empty starter copied to `priorities.json` on first install |
| `server.py` | Python stdlib-only HTTP server. Static files + `GET /events` (SSE), `GET /api/focus`, `GET /api/now`, `POST /api/mark-done`, `POST /api/mark-undone`, `POST /api/refresh` |
| `refresh.sh` | invokes the configured runtime (Claude Code or Codex) with a durable prompt + fresh context. Writes a new priorities.json. Preserves `done` and `northstar`. |
| `prompt.md` | durable prompt the refresh uses. Schema + prioritization heuristics + anti-patterns. Edit this to change how the dashboard thinks. |
| `fonts/` | self-hosted Fraunces + Spectral (variable + static WOFF2). ~500 KB total |
| `launchd/` | macOS LaunchAgent plist templates (rendered at install time) |

## How it's wired

- `~/.steward/focus-dash/priorities.json` is the single source of truth
- `server.py` watches the file's mtime and pushes SSE events to connected browsers — the UI reloads live on any edit
- `refresh.sh` regenerates priorities.json from your status file + activity.db + git log + (optional) focus watcher data
- The `desk` CLI (`$STEWARD_HOME/bin/desk`) mutates priorities.json atomically under `flock` — safe against concurrent edits from server, refresh, and CLI

## Configuration (env vars)

All optional — the setup script wires sensible defaults into the launchd plists.

| var | default | purpose |
|-----|---------|---------|
| `STEWARD_HOME` | (set by setup) | base dir |
| `STEWARD_PRIORITIES` | `$STEWARD_HOME/focus-dash/priorities.json` | priorities path |
| `STEWARD_ACTIVITY_DB` | `$STEWARD_HOME/activity.db` | activity log |
| `STEWARD_FOCUS_DB` | `$STEWARD_HOME/personas/focus/focus.db` | focus watcher db (optional) |
| `STEWARD_STATUS_MD` | (unset) | optional project status file for refresh |
| `STEWARD_STUCK_JSON` | `$STEWARD_HOME/stuck.json` | stuck-item tracker (optional; legacy `steward-stuck.json` auto-detected if present) |
| `STEWARD_PROJECT_ROOT` | set at install | git dir for recent commits |
| `STEWARD_RUNTIME` | set at install | `claude-code` or `codex` |
| `STEWARD_LLM_MODEL` | `claude-opus-4-7` | model for refresh (claude-code only) |
| `FOCUS_DASH_PORT` | `8888` | server port |

## Scheduled refresh

Three launchd fires on weekdays: **9:15am, 1:30pm, 6:15pm** (edit the plist to change times).
Logs at `$STEWARD_HOME/log/focus-dash-refresh.log`.
Each run takes ~60–90s on Claude Opus.

## Install (after `./scripts/setup` installs the bundle)

The setup script renders the launchd plist templates and prints the `launchctl load` commands. If you skipped the auto-load, run:

```bash
launchctl load ~/Library/LaunchAgents/com.steward.focus-dash.plist
launchctl load ~/Library/LaunchAgents/com.steward.focus-dash-refresh.plist

launchctl list | grep focus-dash
curl -sS http://127.0.0.1:8888/api/now
```

Keep the tab pinned: `http://localhost:8888/`.

## Manual operations

```bash
# Trigger an ad-hoc refresh (also wired to the refresh ↻ button in the UI)
curl -X POST http://127.0.0.1:8888/api/refresh

# Restart the server (after editing server.py)
launchctl unload ~/Library/LaunchAgents/com.steward.focus-dash.plist
launchctl load   ~/Library/LaunchAgents/com.steward.focus-dash.plist

# Tail the refresh log
tail -f $STEWARD_HOME/log/focus-dash-refresh.log

# Previous priorities (kept as backup on every refresh)
cat $STEWARD_HOME/focus-dash/priorities.prev.json
```

## Keyboard

| key | action |
|-----|--------|
| `j` / `k` | navigate priorities |
| `o` / `Enter` | expand focused priority |
| `c` | copy first paste block of focused priority |
| `d` | mark focused priority done |
| `t` / `w` | switch to today / watcher tab |

## Linux / non-macOS

The server + refresh work fine on Linux. The launchd plists don't. Use systemd, cron, or a tmux-attached loop — PRs welcome for a systemd unit template.

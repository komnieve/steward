# Focus persona — the mindfulness bell

**macOS only.** The watcher uses `screencapture` + AppleScript (`osascript`) to see what's on screen. Linux users: this bundle is skipped at setup time. PR welcome for a Wayland/X11 equivalent.

## What it is

Every 2–5 minutes (configurable), a launchd agent:

1. Captures a screenshot of each monitor
2. Reads the frontmost app + visible windows via AppleScript
3. Pulls your focus-dash priorities and active agent sessions
4. Asks a fast vision model (Haiku) what's on screen
5. Asks a judgment model (Opus) whether this is work or drift — with the user's priorities as context
6. If drift: sends one gentle message via macOS notification. If work or ambiguous: silent.

It is **not** a productivity monitor. It is a bell. The persona (`CLAUDE.md`) sets the tone: short, quote-led, warm, never shaming.

## Files

| file | purpose |
|------|---------|
| `CLAUDE.md` | the persona — how the judgment model should speak |
| `focus-check.sh` | one tick — screenshots, prompts, produces an assessment |
| `focus-loop.sh` | orchestration loop (escalation levels, delivery) |
| `quotes.md` | starter library of ~400 quotes from meditation/contemplative traditions |
| `quote-finder.sh` | weekly cron that grows `quotes.md` via LLM + web search |
| `launchd/` | macOS LaunchAgent plist templates |
| `focus.db` | local SQLite — focus log, created on first run (gitignored) |
| `screenshots/` | transient screen captures (gitignored, deleted after each tick) |

## Configuration (env vars)

All optional — setup wires them into the launchd plist.

| var | default | purpose |
|-----|---------|---------|
| `STEWARD_HOME` | set by setup | base dir |
| `STEWARD_PRIORITIES` | `$STEWARD_HOME/focus-dash/priorities.json` | the user's priorities (drives what counts as work) |
| `STEWARD_STATUS_MD` | unset | optional fallback: scrapes `## P0` section if no priorities.json |
| `STEWARD_PROJECT_ROOT` | set by setup | used to locate Claude Code transcripts for session context |
| `STEWARD_RUNTIME` | `claude-code` | the LLM runtime |
| `STEWARD_LLM_MODEL` | `claude-opus-4-6` | model for the judgment pass |

## Permissions (macOS)

The watcher needs two TCC grants:

1. **Screen Recording** — for `screencapture` to capture all displays. Grant in System Settings → Privacy & Security → Screen Recording for your terminal (or for `/usr/sbin/screencapture` if triggering from launchd).
2. **Accessibility / Automation** — for AppleScript to read frontmost app + window titles. Grant to whichever process runs `osascript`.

Both prompts fire automatically the first time the script runs. If you skip the prompts, the watcher will silently fail — rerun manually once to re-trigger.

## Install

The setup script (`./scripts/setup`) offers this bundle as Phase 5b, macOS only. If you accept, it:

1. Copies `personas/focus/` into `$STEWARD_HOME/personas/focus/`
2. Initializes an empty `focus.db`
3. Renders `launchd/com.steward.focus-*.plist.template` into `~/Library/LaunchAgents/`
4. Prints the `launchctl load` commands (you run them after granting permissions)

## Manual tick

```bash
STEWARD_HOME=~/.steward ./focus-check.sh 1
# → prints the assessment to stdout, or "--" if no drift
```

## Turning it off

```bash
launchctl unload ~/Library/LaunchAgents/com.steward.focus-loop.plist
launchctl unload ~/Library/LaunchAgents/com.steward.quote-finder.plist
```

## A note on the bar

The persona is deliberately conservative. It prefers to miss a 5-minute scroll than interrupt genuine research. If you find it nagging you on things that are clearly work, edit `CLAUDE.md` — the persona is yours.

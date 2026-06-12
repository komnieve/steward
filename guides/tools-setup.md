# Tools & Integrations Setup Guide

## Signal delivery (signal-cli)

Signal delivery is wired into `daily-check.sh`. It is **send-only** today: steward
sends your reflection as a Signal message (to yourself by default, or any recipient
you set). Replying back to steward over Signal is not yet supported. To enable it,
set `delivery: "signal"` in `~/.steward/config.json` and configure `~/.steward/.env`
(see *Configure steward* below).

### Install

**macOS (Homebrew)** — recommended:

```bash
brew install signal-cli
# Pulls openjdk (Java 21+) as a dependency. Also handy for linking:
brew install qrencode
```

This puts `signal-cli` (and `qrencode`) on PATH under `/opt/homebrew/bin/`.

**Linux** — some distros package it (`apt install signal-cli`, `pacman -S signal-cli`,
or the Nix/Flatpak builds). If yours doesn't, grab a release tarball:

```bash
# Check https://github.com/AsamK/signal-cli/releases for the current version
VERSION=0.13.24
wget "https://github.com/AsamK/signal-cli/releases/download/v${VERSION}/signal-cli-${VERSION}-Linux.tar.gz"
tar xf "signal-cli-${VERSION}-Linux.tar.gz" -C /opt
ln -sf "/opt/signal-cli-${VERSION}/bin/signal-cli" /usr/local/bin/signal-cli
# qrencode is in every major distro's repos: apt/dnf/pacman install qrencode
```

**Windows** — run steward (and signal-cli) under WSL2 and follow the Linux steps
above inside your WSL distro. There's also a native Windows tarball on the releases
page if you'd rather not use WSL.

signal-cli requires Java 21+ — Homebrew pulls it in for you; on Linux/WSL install a
JRE 21+ (e.g. `apt install openjdk-21-jre-headless`).

### Register or link

You can register a fresh number, or link signal-cli as a secondary device to a phone
that already has Signal. Linking is usually easiest.

**Register a number** (you'll get an SMS code):

```bash
signal-cli -a +1YOURPHONE register
signal-cli -a +1YOURPHONE verify CODE
```

**Link as a secondary device** — the link process must **stay alive** while you scan
the QR code with your phone (Signal → Settings → Linked Devices → Link New Device).
Don't pipe it through `head` or anything that closes the pipe early — that sends
SIGPIPE and kills the link before the scan completes. Instead, background it, render
the URI as a QR code, scan, then wait:

```bash
signal-cli link -n "steward" > /tmp/steward-link.txt 2>&1 &
LINK_PID=$!
sleep 2
# Print the QR right in the terminal — works the same on macOS, Linux, and WSL:
qrencode -t ANSIUTF8 "$(grep -m1 '^sgnl://' /tmp/steward-link.txt)"
# Scan it with your phone, then let the link finish:
wait "$LINK_PID"
```

Prefer a PNG you can open in an image viewer? Swap the qrencode line for
`qrencode -o /tmp/steward-link.png "$(grep -m1 '^sgnl://' /tmp/steward-link.txt)"`
and open it with `open` (macOS), `xdg-open` (Linux), or `wslview` (WSL).

### Configure steward

steward reads the Signal number and recipient from `~/.steward/.env`:

```bash
SIGNAL_NUMBER=+1YOURPHONE       # the registered/linked number steward sends *from*
SIGNAL_RECIPIENT=+1YOURPHONE    # who receives the message; defaults to SIGNAL_NUMBER if unset
```

Keep `.env` out of version control — it contains your phone number.

### Test

```bash
# Send a test message to yourself
echo "Steward test" | signal-cli -a +1YOURPHONE send --message-from-stdin --notify-self +1YOURPHONE
```

A clean run of steward logs `delivered to signal (<recipient>)` to
`~/.steward/logs/{morning,evening}.log`.

### Troubleshooting
- **"User is not registered"**: the number must be registered/linked with Signal first.
- **"Device not found"**: re-register or re-link the device.
- **Link dies before you can scan**: don't pipe `signal-cli link` through `head` (SIGPIPE) — use the background + QR approach above.
- **Messages not arriving when sending to yourself**: make sure `--notify-self` is included.

---

## Runtime: Claude Code

The steward runs Claude Code in headless mode (`claude -p`). Make sure it's installed and authenticated.

```bash
# Install (if not already)
npm install -g @anthropic-ai/claude-code

# Verify it works
claude --version

# Make sure you're authenticated
claude
# (follow auth prompts if needed)
```

### Claude Code Settings

The steward system benefits from these settings in `~/.claude/settings.json`:

```json
{
  "model": "opus",
  "alwaysThinkingEnabled": true
}
```

- `model: "opus"` — Uses Claude Opus for deeper reasoning (the steward benefits from this). You can use "sonnet" for lower cost.
- `alwaysThinkingEnabled` — Extended thinking helps the steward form better assessments.

---

## Optional: Google Workspace CLI (gws)

If you want Claude to read your email, check your calendar, search Drive, or update spreadsheets during sessions.

### Installation

```bash
pip install gws-cli
# or
pipx install gws-cli
```

### Authentication

```bash
# Set up Google Cloud project and OAuth credentials
# See: https://pypi.org/project/gws-cli/ for details

gws auth login
```

### Usage Examples

```bash
# Check calendar
gws calendar events list --params '{"calendarId": "primary", "maxResults": 5, "timeMin": "2026-03-06T00:00:00Z"}'

# Search Drive
gws drive files list --params '{"q": "name contains \"invoice\"", "pageSize": 10}'

# Read email
gws gmail messages list --params '{"maxResults": 5}'

# Read spreadsheet
gws sheets spreadsheets.values get --spreadsheetId SHEET_ID --range 'Sheet1!A1:D10'
```

Tell Claude about gws in your CLAUDE.md or auto-memory so it knows to use it.

---

## Optional: MCP Servers

Claude Code supports MCP (Model Context Protocol) servers that extend its capabilities. Configure in `.mcp.json` at your project root or `~/.claude/projects/<project-id>/.mcp.json`.

### Webflow MCP (edit websites from Claude Code)

```json
{
  "mcpServers": {
    "webflow": {
      "type": "http",
      "url": "https://mcp.webflow.com/mcp"
    }
  }
}
```

Enable in `.claude/settings.local.json`:
```json
{
  "enabledMcpjsonServers": ["webflow"]
}
```

Other MCP servers to consider:
- **GitHub MCP** — deeper GitHub integration
- **Slack MCP** — read/send Slack messages
- **Notion MCP** — read/write Notion pages
- **Database MCPs** — direct database access

---

## Optional: Claude Code Skills

Skills are custom slash commands. They live in `.claude/skills/<skill-name>/SKILL.md`.

### Built-in skills (installed via Anthropic)
- **orient** — Read project state and summarize what's pending
- **frontend-design** — Create production-grade UI components
- **skill-creator** — Create and test custom skills

### Creating a custom skill

```bash
mkdir -p .claude/skills/my-skill
cat > .claude/skills/my-skill/SKILL.md << 'EOF'
# My Skill

[Instructions for what this skill does when invoked with /my-skill]
EOF
```

Example orient skill:
```markdown
# Orient Skill

Read these files to understand current project state:
1. Check docs/session-notes/ for recent session summaries
2. Read any TODO.md or STATUS.md files
3. Summarize what was last worked on and what's pending
```

---

## Optional: Claude Code Hooks

Hooks run shell commands in response to Claude Code events. Configure in `.claude/settings.json` at the project level.

### Example: Auto-stage session notes

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "if [ -f docs/session-notes/current.md ]; then git add docs/session-notes/; fi"
          }
        ]
      }
    ]
  }
}
```

This runs after every tool use and stages any session notes that exist. Useful for ensuring session notes don't get lost.

### Hook events
- `PreToolUse` — Before a tool runs (can block it)
- `PostToolUse` — After a tool completes
- `Notification` — When Claude wants to notify you

---

## Optional: Auto-Memory

Claude Code has a persistent memory system at `~/.claude/projects/<project-id>/memory/`. The main file `MEMORY.md` is loaded into every conversation.

This is where Claude stores:
- Your preferences and patterns learned across sessions
- Key project structure and conventions
- People, terminology, and context that persists
- Solutions to recurring problems

You don't need to set this up — Claude Code manages it automatically. But you can:
- Read it: `cat ~/.claude/projects/<project-id>/memory/MEMORY.md`
- Edit it: Directly modify the file, or tell Claude "remember that I prefer X"
- Clear it: Delete entries that are wrong or outdated

The steward system benefits from auto-memory because Claude remembers things like:
- Your preferred communication style
- How you like to structure sessions
- Tools and workflows you've set up
- People and their roles

---

## Permissions

Configure tool permissions in `.claude/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(npm:*)",
      "Bash(ls:*)",
      "Bash",
      "Read",
      "Edit",
      "Write",
      "Glob",
      "Grep",
      "WebFetch",
      "WebSearch"
    ],
    "deny": [
      "Bash(rm -rf:*)",
      "Bash(sudo:*)"
    ]
  }
}
```

This controls which tools Claude can use without asking for permission. The daily check explicitly sets `--allowedTools "Read,Glob,Grep,Bash(sqlite3:*)"` for the autonomous runs, so the steward can read its files and query activity.db without broader shell access.

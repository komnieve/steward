# Tools & Integrations Setup Guide

## Optional / future: signal-cli

Signal delivery is not wired into the v0.2 setup flow. These notes are kept for a
future delivery path and for people experimenting manually. The default supported
delivery channels today are terminal and Slack webhook.

### Installation

```bash
# Download latest release
# Check https://github.com/AsamK/signal-cli/releases for current version
VERSION=0.13.24
wget "https://github.com/AsamK/signal-cli/releases/download/v${VERSION}/signal-cli-${VERSION}-Linux.tar.gz"
tar xf "signal-cli-${VERSION}-Linux.tar.gz" -C /opt
ln -sf "/opt/signal-cli-${VERSION}/bin/signal-cli" /usr/local/bin/signal-cli

# Or install to ~/.local/bin
mkdir -p ~/.local/bin
tar xf "signal-cli-${VERSION}-Linux.tar.gz"
ln -sf "$(pwd)/signal-cli-${VERSION}/bin/signal-cli" ~/.local/bin/signal-cli
```

signal-cli requires Java 21+.

### Registration

```bash
# Register your phone number (you'll receive an SMS verification code)
signal-cli -a +1YOURPHONE register

# Verify with the code you received
signal-cli -a +1YOURPHONE verify CODE

# Link as a secondary device (alternative — if Signal is already on your phone)
signal-cli link -n "steward" | head -1
# This prints a URI — convert it to a QR code and scan with your Signal app
```

### Testing

```bash
# Send a test message to yourself
echo "Steward test" | signal-cli -a +1YOURPHONE send --message-from-stdin --notify-self +1YOURPHONE
```

### Troubleshooting
- **"User is not registered"**: Your phone number needs to be registered with Signal first (have the Signal app installed)
- **"Device not found"**: Re-register or re-link the device
- **Messages not arriving**: Check that `--notify-self` is included (sending to yourself requires this flag)

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
# See: https://github.com/nicholasgasior/gws-cli for details

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

This controls which tools Claude can use without asking for permission. The steward scripts explicitly set `--allowedTools "Read,Glob,Grep,Bash"` for the autonomous runs.

# Getting Started with Steward

This guide walks you from clone to your first autonomous steward check-in.

## Prerequisites

- **Claude Code** installed and working ([docs](https://docs.anthropic.com/en/docs/claude-code))
- **signal-cli** installed for Signal messaging ([GitHub](https://github.com/AsamK/signal-cli))
- A Signal account registered with signal-cli
- **SQLite3** installed (usually pre-installed on Linux/macOS)
- A project directory where you do your work

## Step 1: Set Up Your Project Directory

Your project directory is where you'll keep status files, project docs, and work logs. This is also where you'll run Claude Code from.

```bash
mkdir -p ~/projects/mywork/work
cd ~/projects/mywork
git init
```

## Step 2: Copy Template Files

```bash
# Copy CLAUDE.md to your project root
cp steward/templates/CLAUDE.md ~/projects/mywork/CLAUDE.md

# Copy status.md template
cp steward/templates/status.md ~/projects/mywork/work/status.md

# Copy steward persona to ~/.claude/
mkdir -p ~/.claude
cp steward/templates/steward-persona.md ~/.claude/steward-persona.md
cp steward/templates/steward-stuck.json ~/.claude/steward-stuck.json

# Copy settings (includes time awareness hook)
cp steward/templates/settings.json ~/.claude/settings.json

# Copy the time awareness hook
mkdir -p ~/.claude/hooks
cp steward/hooks/inject-time.sh ~/.claude/hooks/inject-time.sh
chmod +x ~/.claude/hooks/inject-time.sh

# Copy steward scripts
cp steward/scripts/daily-check.sh ~/.claude/daily-check.sh
cp steward/scripts/evening-check.sh ~/.claude/evening-check.sh
cp steward/scripts/steward-gather.sh ~/.claude/steward-gather.sh
cp steward/scripts/steward-update-stuck.sh ~/.claude/steward-update-stuck.sh
cp steward/scripts/steward-summarize-sessions.sh ~/.claude/steward-summarize-sessions.sh
chmod +x ~/.claude/*.sh
```

## Step 3: Create the Activity Database

```bash
bash steward/setup/create-activity-db.sh
```

This creates `~/.claude/activity.db` with the activity_log and research_queries tables.

## Step 4: Customize Your Files

These files need your personal information to work:

### CLAUDE.md (in your project root)

Edit the "Who You Are — Working Context" section. Be honest about:
- What you're building and why
- Your working patterns and tendencies
- What kind of accountability works for you
- Family/life context that affects work capacity

The more honest you are, the better the system works. See `guides/personality-assessment.md` for a structured way to develop this.

### steward-persona.md (in ~/.claude/)

This is the persona the autonomous steward uses when it runs on cron. Customize:
- Your name and context
- What projects you're working on
- The tone you want (direct? gentle? both?)
- The escalation protocol (how persistent should it be about stuck items?)

### Scripts (in ~/.claude/)

Each script has `[PLACEHOLDER]` values that need replacing:

```bash
# In daily-check.sh, evening-check.sh, and steward-gather.sh, replace:
[YOUR_HOME_DIR]     → your actual home directory (e.g., /home/youruser)
[YOUR_PHONE_NUMBER] → your Signal phone number (e.g., +14155551234)
[YOUR_PROJECT_DIR]  → your project directory (e.g., /home/youruser/projects/mywork)
```

### steward-gather.sh

The "PROJECT FILES" section is where you add your own project-specific files. The steward reads these to understand what's going on. Add paths to your trackers, status docs, and operational files.

## Step 5: Set Up Cron

```bash
crontab -e
```

Add these lines:

```
# Morning steward check-in at 9am
0 9 * * * /bin/bash ~/.claude/daily-check.sh >> ~/.claude/cron.log 2>&1

# Evening steward check-in at 6pm
0 18 * * * /bin/bash ~/.claude/evening-check.sh >> ~/.claude/cron.log 2>&1
```

On macOS, use `launchd` instead of cron for more reliable scheduling. On WSL2, cron only fires while WSL is running.

## Step 6: Test It

### Test the time awareness hook

Start a Claude Code session in your project directory. Type anything. You should see a `<user-prompt-submit-hook>` block injected with the current time, timezone, and elapsed time since last prompt.

### Test the steward manually

```bash
# Run the morning check manually
bash ~/.claude/daily-check.sh
```

Check `~/.claude/cron.log` for output. If everything is configured correctly, you should receive a Signal message with the steward's assessment.

### Log your first activity

```bash
sqlite3 ~/.claude/activity.db "INSERT INTO activity_log (timestamp, project, category, activity, duration_min, notes) VALUES (datetime('now', 'localtime'), 'setup', 'admin', 'Initial steward setup', 30, 'Got steward running');"
```

## Step 7: Start Working

Open Claude Code in your project directory. The system is now active:

- **Every prompt** gets time context injected automatically
- **Every session** Claude reads your CLAUDE.md and understands your context
- **Twice daily** the steward reads everything, assesses where things stand, and sends you a Signal message
- **status.md** is your primary state tracker — update it every session
- **activity.db** captures what you did and for how long — log at natural transition points

## What to Do Next

1. **Run the personality assessment** — see `guides/personality-assessment.md`. This deepens the system's understanding of who you are and how to work with you.
2. **Customize your steward-gather.sh** — add your actual project files so the steward sees the full picture.
3. **Use it for a week** before making structural changes. Let the system reveal what's working and what isn't.
4. **Read the other guides** — `guides/steward.md` explains the steward architecture in depth. `guides/activity-tracking.md` covers the activity database. `guides/practice-integration.md` is optional but powerful.

## Troubleshooting

**Steward not sending messages**: Check `~/.claude/cron.log`. Common issues: wrong paths in scripts, signal-cli not configured, cron not running.

**Time hook not firing**: Make sure `~/.claude/hooks/inject-time.sh` is executable (`chmod +x`) and `~/.claude/settings.json` has the UserPromptSubmit hook configured.

**Activity database errors**: Run `sqlite3 ~/.claude/activity.db ".tables"` to verify the tables exist. If not, rerun the setup script.

**"SKIPPED — weekend"**: The steward skips weekends by default. Edit the DOW check in daily-check.sh if you want weekend check-ins.

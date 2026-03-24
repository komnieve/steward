# Steward

An autonomous AI chief-of-staff system built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). It combines structured project management, scheduled autonomous check-ins via Signal, activity tracking, personality-informed coaching, and contemplative practice integration into a coherent operating system for solo founders and independent workers.

This isn't a chatbot wrapper. It's a working system that:

- **Sends you morning and evening check-ins via Signal** — an autonomous Claude instance reads your project files, git log, and activity database, then sends you a honest assessment of where things stand
- **Tracks your work across three layers** — status files (state), SQLite activity log (events), and git log (code changes)
- **Knows who you are** — through a guided personality assessment, the system understands your strengths, blind spots, and patterns so it can give you advice that actually lands
- **Holds work as practice** — optionally integrates contemplative/mindfulness framing so that how you work matters as much as what you produce
- **Maintains persistent memory** — Claude Code's auto-memory feature lets the system learn your preferences and patterns across sessions

## What Problem This Solves

If you work alone — founder, freelancer, indie hacker — you lack the thing that offices provide automatically: someone who sees the whole picture, notices when you're drifting, and asks uncomfortable questions. Not a task manager. A thinking partner who shows up reliably.

The Steward is that. It reads everything, remembers nothing between runs (by design — it re-reads from source every time), and tells you what it sees. When it's working well, it feels like having a chief of staff who knows your projects, your patterns, and your tendencies.

## System Architecture

```
+---------------------------+
|      Claude Code CLI      |
|  (interactive sessions)   |
+---------------------------+
        |           |
        v           v
+-------------+  +------------------+
| CLAUDE.md   |  | Auto-Memory      |
| (project    |  | (persistent      |
|  instructions|  |  cross-session)  |
+-------------+  +------------------+
        |
        v
+---------------------------+
|    Three-Layer Tracking   |
|                           |
| 1. status.md    (STATE)   |
| 2. activity.db  (EVENTS)  |
| 3. git log      (CODE)    |
+---------------------------+
        |
        v
+---------------------------+
|    Steward (Autonomous)   |
|                           |
| - Cron: 9am + 6pm        |
| - Reads all project files |
| - Queries activity DB     |
| - Checks git log          |
| - Sends Signal message    |
+---------------------------+
        |
        v
+---------------------------+
|   Signal Notification     |
|   (to your phone)         |
+---------------------------+
```

## Getting Started

New to Steward? See the **[Getting Started Guide](guides/getting-started.md)** for a step-by-step walkthrough from clone to your first autonomous check-in.

## Components

### 1. CLAUDE.md — Project Instructions
The brain of the system. Claude Code reads this file at the start of every session. It defines:
- Session start ritual (what files to read, what to show)
- Your role description and communication style
- Information architecture (how the three tracking layers work)
- Working practices and guardrails
- Optionally: who you are and how to work with you

See: [CLAUDE.md Setup Guide](guides/claude-md.md) | [Template](templates/CLAUDE.md)

### 2. The Steward — Autonomous Check-ins
A persona file + shell scripts + cron jobs that run Claude Code in headless mode (`claude -p`), read your project state, and send you a Signal message with an honest assessment.

- **Morning (9am)**: What deserves energy today? What's slipping? Any deadlines?
- **Evening (6pm)**: What moved? What didn't? Patterns? Tomorrow's priority?
- Skips weekends and holidays automatically
- Includes activity log data so it doesn't miss non-code work

See: [Steward Setup Guide](guides/steward.md) | [Persona Template](templates/steward-persona.md) | [Scripts](scripts/)

### 3. Activity Tracking — SQLite Database
Git commits only capture code. The activity database captures everything else: meetings, calls, deployments, research, planning. The steward reads both.

```bash
sqlite3 ~/.claude/activity.db "INSERT INTO activity_log
  (timestamp, project, category, activity, duration_min, notes)
  VALUES (datetime('now', 'localtime'), 'myproject', 'meeting', 'Client sync call', 30, 'Discussed roadmap');"
```

See: [Activity Tracking Guide](guides/activity-tracking.md) | [Schema Setup](setup/create-activity-db.sh)

### 4. Status Dashboard — status.md
The primary source of truth the steward reads. Three sections:
- **Deadlines**: hard dates that expire
- **Active Projects**: living status of every thread
- **Work Log**: permanent record of accomplishments by week

See: [Status Guide](guides/status-dashboard.md) | [Template](templates/status.md)

### 5. Personality Assessment
A guided conversation framework that helps Claude understand your working patterns, strengths, blind spots, and psychological tendencies. This isn't therapy — it's operational self-knowledge that makes the steward's advice more useful.

See: [Personality Assessment Guide](guides/personality-assessment.md)

### 6. Practice Integration (Optional)
A philosophical framework for holding work as practice — contemplative awareness applied to professional execution. Useful if you have a meditation/mindfulness practice and want to integrate it with how you work.

See: [Practice Guide](guides/practice-integration.md) | [Template](templates/UPEKHA.md)

### 7. Learning Edge Detection
When you work with AI every day, it's easy to route around things you don't understand instead of learning them. The model handles it, the work ships, and your understanding stays flat.

Learning Edge Detection is a CLAUDE.md instruction that watches for moments where you defer something out of avoidance (not efficiency) and flags it as a learning opportunity. It pairs with a `learning-edges.md` file that tracks your active growth areas, and supports spaced retrieval practice — the model generates questions that test your understanding over time instead of just re-explaining things.

The principle: **using models should accelerate learning, not bypass it.**

See: [Learning as Practice Guide](guides/learning-as-practice.md) | [Learning Edges Template](templates/learning-edges-template.md)

### 8. Time Awareness Hook
A `UserPromptSubmit` hook that injects temporal metadata into every Claude Code message: current time, timezone, elapsed time since last prompt, date changes, and last logged activity. The model never has to guess what time it is or how long you've been away.

This enables context-aware behavior: surfacing time-sensitive items after long gaps, noting day transitions, and resolving relative dates accurately.

See: [Hook Script](hooks/inject-time.sh) | [Settings Template](templates/settings.json)

### 9. Research Query Tracking
When you need analysis beyond what Claude Code can do in a session (e.g., deep research with a frontier model like GPT 5.4 Pro), the system tracks research queries in the activity database. Each query gets a folder with a `prompt.md` and `response.md`, and metadata is stored in SQLite for easy querying.

See: [Activity Tracking Guide](guides/activity-tracking.md) | [Schema Setup](setup/create-activity-db.sh)

### 10. Transcription Corrections
If you use voice input (dictation), Claude Code can auto-correct known speech-to-text errors. Maintain a correction table and reference it in CLAUDE.md.

See: [Template](templates/transcription-corrections.md)

### 9. Tools & Integrations
The system works with several external tools:

| Tool | Purpose | Required? |
|------|---------|-----------|
| **signal-cli** | Send/receive Signal messages | Yes (for steward notifications) |
| **gws** | Google Workspace CLI (Gmail, Calendar, Drive, Sheets) | Optional |
| **Webflow MCP** | Edit websites directly from Claude Code | Optional |
| **Claude Code Skills** | Custom slash commands (orient, etc.) | Optional |
| **Claude Code Hooks** | Auto-run shell commands on tool events | Optional |

See: [Tools Setup Guide](guides/tools-setup.md)

## Quick Start

### Prerequisites
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- A Unix-like environment (Linux, macOS, WSL2)
- signal-cli installed and registered (see [Signal setup](guides/tools-setup.md#signal-cli))
- Basic familiarity with cron, SQLite, and shell scripting

### 1. Clone and copy templates
```bash
git clone <this-repo> steward
cd steward

# Copy CLAUDE.md to your project
cp templates/CLAUDE.md /path/to/your/project/CLAUDE.md

# Copy steward persona
cp templates/steward-persona.md ~/.claude/steward-persona.md

# Copy steward scripts
cp scripts/daily-check.sh ~/.claude/daily-check.sh
cp scripts/evening-check.sh ~/.claude/evening-check.sh
chmod +x ~/.claude/daily-check.sh ~/.claude/evening-check.sh
```

### 2. Create the activity database
```bash
bash setup/create-activity-db.sh
```

### 3. Create your status file
```bash
cp templates/status.md /path/to/your/project/work/status.md
```

### 4. Edit the templates
Every template has `[PLACEHOLDER]` markers. Go through each one and customize:
- Your name and projects
- Your phone number in the steward scripts
- Your project directory paths
- Your communication preferences

### 5. Set up cron
```bash
crontab -e
# Add:
0 9 * * * /home/YOU/.claude/daily-check.sh >> /home/YOU/.claude/cron.log 2>&1
0 18 * * * /home/YOU/.claude/evening-check.sh >> /home/YOU/.claude/cron.log 2>&1
```

### 6. (Optional) Run the personality assessment
Start a Claude Code session and follow the guide in [guides/personality-assessment.md](guides/personality-assessment.md).

### 7. (Optional) Set up practice integration
If you have a contemplative practice, customize `templates/UPEKHA.md` and add it to your project.

### 8. (Optional) Enable Learning Edge Detection
Add the Learning Edge Detection instruction to your CLAUDE.md (see [the guide](guides/learning-as-practice.md)) and copy `templates/learning-edges-template.md` to `work/learning-edges.md` in your project.

## File Structure
```
steward/
  README.md                          # This file
  guides/
    getting-started.md               # Step-by-step setup walkthrough
    claude-md.md                     # How to write effective CLAUDE.md files
    steward.md                       # How the autonomous steward works
    activity-tracking.md             # Setting up and using the activity database
    status-dashboard.md              # How to maintain status.md
    personality-assessment.md        # Guided self-assessment framework
    practice-integration.md          # Work-as-practice philosophy (optional)
    learning-as-practice.md          # Learning Edge Detection and spaced retrieval
    tools-setup.md                   # Signal, gws, MCP servers, hooks, skills, memory
  hooks/
    inject-time.sh                   # Time awareness hook (UserPromptSubmit)
  templates/
    CLAUDE.md                        # Project instructions template
    steward-persona.md               # Steward persona template
    status.md                        # Status dashboard template
    UPEKHA.md                        # Practice integration template
    transcription-corrections.md     # Speech-to-text corrections template
    learning-edges-template.md       # Learning edges tracking template
    holidays.txt                     # Holiday skip list
    settings.json                    # Claude Code settings (includes time hook)
    mcp.json                         # MCP server config example
  scripts/
    daily-check.sh                   # Morning steward cron script
    evening-check.sh                 # Evening steward cron script
    steward-gather.sh                # Context gathering (Phase 1)
    steward-update-stuck.sh          # Stuck item tracker updater
    steward-summarize-sessions.sh    # Session summary generator
  setup/
    create-activity-db.sh            # Initialize SQLite database (activity + research queries)
```

## Design Principles

1. **Source of truth is files, not memory.** The steward has no memory across runs. It re-reads everything every time. This means your files must be current — but it also means there's no hidden state, no drift, no stale cache.

2. **Three layers, three purposes.** Status.md = where things stand (state). Activity.db = what happened (events). Git log = what code changed. Each serves a different question. All three together give the full picture.

3. **Compassion AND follow-through.** The steward is direct but not harsh. It names what's true — stalled work, missed commitments, patterns of avoidance — without shaming. This is not about being nice. It's about being effective with a human nervous system.

4. **Practice is infrastructure, not decoration.** If you integrate the contemplative dimension, it's not a bolt-on. It's the foundation that makes sustained execution possible. Protect it accordingly.

5. **The system is the scaffold, you are the builder.** None of this replaces your judgment. It provides structure, accountability, and a second perspective. Customize aggressively — strip what doesn't serve you, add what does.

## Limitations

- **WSL2 caveat**: Cron jobs won't fire if WSL2 isn't running at the scheduled time. Consider a Windows Task Scheduler trigger to wake WSL.
- **Signal registration**: signal-cli requires a phone number and device registration. This is the most friction-heavy part of setup.
- **Claude Code costs**: The steward runs two Claude sessions per day (morning + evening, ~25 turns each). Budget accordingly.
- **No real-time**: The steward is batch-oriented (2x/day). It doesn't monitor in real-time. For that, you'd need a different architecture.

## Credits

Built by Komnieve Singh / Upekha Ventures. Powered by [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic.

---

*This system evolved organically over months of daily use. It wasn't designed top-down — it grew from real needs, real patterns, and real sessions. Your version will evolve too. Start simple, add what helps, remove what doesn't.*

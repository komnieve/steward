# Getting started with Steward

From clone to first run in about 20 minutes.

---

## Prerequisites

- An agent runtime on PATH — either [Claude Code](https://claude.com/product/claude-code)
  or [Codex](https://github.com/openai/codex). You need one; either works.
- API key for that runtime (`ANTHROPIC_API_KEY` or `OPENAI_API_KEY` — whichever the
  runtime uses).
- `sqlite3` (usually pre-installed on macOS/Linux; `sudo apt install sqlite3` on
  Debian/Ubuntu/WSL).
- Unix-ish shell — macOS, Linux, or WSL.

## Install

```bash
git clone https://github.com/komnieve/steward ~/repos/steward
cd ~/repos/steward
./scripts/setup
```

That's it. The setup script walks you through eight phases.

> **A note on `project_root`:** if you enable `focus-dash` or the focus watcher,
> setup asks for a **project_root** — the path to the work repo you want the
> steward to read commits from. Running setup from the steward clone is fine, but
> `project_root` should point at **your work repo**, not the steward clone itself.
> Leave it blank to skip git-aware features.

---

## What the setup script does

**Phase 0 — Prerequisite check.** Verifies your OS, detects your agent runtime, checks
sqlite3, confirms an API key is available, creates `~/.steward/`.

**Phase 1 — Intention.** Six free-text questions about what you want from this
system. Your answers are written to `~/.steward/intention.md`, which you can edit any
time.

**Phase 2 — Practice Layer.** Picks which practice components you want installed
(True North, wholesomeness lens, work-as-practice, etc.). Each is a template you'll
edit to fit you. See [`practice-layer.md`](practice-layer.md).

**Phase 3 — User lens.** A short guided capture of who you are when working well, what
trips you up, how you communicate. Writes `~/.steward/user-lens.md`.

**Phase 4 — Technical.** Picks delivery channel (terminal, Slack webhook, email,
Signal) and schedule (morning, evening, both, or manual-only).

**Phase 5 — Optional features.** Stuck-item tracker, time-awareness hook, research
query tracking, people table — all opt-in.

**Phase 6 — Scaffolding.** Renders templates, initializes the activity database,
writes the runtime adapter (`CLAUDE.md` for Claude Code, `AGENTS.md` for Codex).

**Phase 7 — First run.** Optional smoke test.

**Phase 8 — Handoff.** Summary of what's installed and how to use it day-to-day.

---

## What gets created

```
~/.steward/
  config.json             ← runtime/delivery/feature config
  intention.md            ← your Phase 1 answers
  user-lens.md            ← your Phase 3 answers
  persona.md              ← how the steward speaks to you
  status.md               ← your active threads (you maintain this)
  activity.db             ← SQLite event log
  stuck.json              ← stuck-item tracker state
  practice/               ← your chosen Practice Layer components
    *.md
  CLAUDE.md  or  AGENTS.md   ← runtime adapter (generated)
```

---

## Day-to-day use

**Manual run:**

```bash
bash ~/repos/steward/scripts/daily-check.sh
```

**Scheduled runs** (if you picked a schedule during setup): cron or launchd fires
`daily-check.sh` at your chosen times, and delivery goes to your chosen channel.

**Logging activity:**

```bash
sqlite3 ~/.steward/activity.db \
  "INSERT INTO activity_log (project, category, activity, duration_min, notes)
   VALUES ('myproject', 'meeting', 'Client sync', 45, 'Discussed Q3 roadmap');"
```

See [`activity-tracking.md`](activity-tracking.md).

**Editing your practice:**

Open any file in `~/.steward/practice/`, any file in `~/.steward/*.md`, or your status
file. Everything is plain markdown. Changes take effect on the next run.

**Re-running setup:**

```bash
./scripts/setup --force     # re-run from scratch, overwriting
./scripts/setup --help
```

---

## Troubleshooting

**"no agent runtime detected"** — install Claude Code or Codex and put it on PATH.

**"sqlite3 not found"** — install it (`brew install sqlite` / `sudo apt install sqlite3`).

**"~/.steward/ already exists"** — you've run setup before. Re-run with `--force` to
overwrite, or back up the existing directory and remove it first.

---

## What to do next

1. Read [`practice-layer.md`](practice-layer.md) and edit the components you installed
   to fit you. The templates are just starting points.
2. Populate `~/.steward/status.md` with a few active threads so the first run has
   something to work with.
3. Log a couple of recent activities to `activity.db` for the same reason.
4. Run `daily-check.sh` once to see what it produces. Adjust.

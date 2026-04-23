# Activity Tracking Guide

## The Problem

Git commits only capture code changes. Most of your actual work — meetings, calls, deployments, research, planning, writing — produces no commits. Without tracking these, the steward (and you) will systematically undercount your productivity and give wrong assessments.

## The Solution: SQLite Activity Log

A simple SQLite database at `~/.steward/activity.db` that captures work events with timestamps, duration, and context.

## Setup

The main `./scripts/setup` creates `~/.steward/activity.db` automatically. If you want to create it manually or understand the schema:

```bash
sqlite3 ~/.steward/activity.db << 'EOF'
CREATE TABLE activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now', 'localtime')),
    project TEXT,
    category TEXT,
    activity TEXT,
    duration_min INTEGER,
    notes TEXT,
    source TEXT DEFAULT 'manual',
    outcome TEXT
);
CREATE INDEX idx_activity_ts ON activity_log(timestamp);
CREATE INDEX idx_activity_project ON activity_log(project);
CREATE INDEX idx_activity_category ON activity_log(category);

-- The scaffolded db also creates a research_queries table (used by the
-- research-query workflow if that feature is enabled). If you're creating
-- the db manually and you don't need research queries, skip this:
CREATE TABLE research_queries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    project TEXT,
    status TEXT DEFAULT 'draft',  -- draft, sent, received, reviewed
    model TEXT,
    tags TEXT,                    -- comma-separated
    summary TEXT,
    prompt_path TEXT,
    response_path TEXT,
    created_at TEXT DEFAULT (datetime('now', 'localtime')),
    updated_at TEXT DEFAULT (datetime('now', 'localtime'))
);
CREATE INDEX idx_rq_project ON research_queries(project);
CREATE INDEX idx_rq_status ON research_queries(status);
EOF
```

## Schema

| Column | Type | Purpose |
|--------|------|---------|
| `id` | INTEGER | Auto-incrementing primary key |
| `timestamp` | TEXT | When the activity happened (defaults to now) |
| `project` | TEXT | Which project (e.g., "myapp", "client-x", "personal") |
| `category` | TEXT | Type of work (see categories below) |
| `activity` | TEXT | Short description of what you did |
| `duration_min` | INTEGER | Approximate minutes spent |
| `notes` | TEXT | Context, outcomes, decisions made |
| `source` | TEXT | How it was logged (default: "manual") |
| `outcome` | TEXT | Optional: what resulted from the activity |

## Categories

Use consistent categories so you can analyze how your time is distributed:

| Category | Examples |
|----------|----------|
| `coding` | Writing code, debugging, code review |
| `deployment` | Deploying to production, server configuration |
| `research` | Market research, technical investigation |
| `meeting` | Calls, syncs, 1:1s |
| `writing` | Documentation, articles, proposals |
| `planning` | Sprint planning, roadmap work, strategy |
| `admin` | Invoicing, legal, tax, bookkeeping |
| `communication` | Emails, Slack, customer support |
| `review` | PR reviews, document reviews, audits |
| `practice` | Meditation, reflection, journaling |
| `break` | Lunch, walks, rest |

## Logging Activities

### During interactive sessions
Tell the runtime (Claude Code, Codex, etc.) to log activities at natural transition points:

> "Log that meeting — 30 minutes, discussed roadmap with the client"

It will run:
```bash
sqlite3 ~/.steward/activity.db "INSERT INTO activity_log
  (timestamp, project, category, activity, duration_min, notes)
  VALUES (datetime('now', 'localtime'), 'client-x', 'meeting', 'Roadmap discussion', 30, 'Agreed on Q2 priorities');"
```

### From the command line
```bash
sqlite3 ~/.steward/activity.db "INSERT INTO activity_log
  (timestamp, project, category, activity, duration_min, notes)
  VALUES (datetime('now', 'localtime'), 'myapp', 'coding', 'Built auth module', 90, 'JWT + refresh tokens');"
```

### Retroactive logging
If you forgot to log something earlier:
```bash
sqlite3 ~/.steward/activity.db "INSERT INTO activity_log
  (timestamp, project, category, activity, duration_min, notes)
  VALUES ('2026-03-06 14:00:00', 'myapp', 'deployment', 'Production deploy v2.1', 45, 'Zero downtime');"
```

## Querying

```bash
# Recent activity (last 7 days)
sqlite3 -header -column ~/.steward/activity.db \
  "SELECT * FROM activity_log WHERE timestamp >= datetime('now', '-7 days', 'localtime') ORDER BY timestamp;"

# Hours by project this week
sqlite3 -header -column ~/.steward/activity.db \
  "SELECT project, printf('%.1f hrs', SUM(duration_min)/60.0) as hours
   FROM activity_log
   WHERE timestamp >= datetime('now', '-7 days', 'localtime')
   GROUP BY project ORDER BY hours DESC;"

# Hours by category today
sqlite3 -header -column ~/.steward/activity.db \
  "SELECT category, printf('%.1f hrs', SUM(duration_min)/60.0) as hours
   FROM activity_log
   WHERE date(timestamp) = date('now', 'localtime')
   GROUP BY category ORDER BY hours DESC;"

# Total hours this month
sqlite3 ~/.steward/activity.db \
  "SELECT printf('%.1f hours', SUM(duration_min)/60.0)
   FROM activity_log
   WHERE timestamp >= date('now', 'start of month', 'localtime');"
```

## How the Steward Uses This

The morning and evening scripts query the activity database and include the results in the prompt sent to the configured runtime. This means the steward sees:
- What you actually did (not just what code you committed)
- How long things took
- Which projects are getting attention
- Whether meetings and calls are being logged

If the activity log is empty but you were working all day, the steward will think you did nothing. Log at natural transition points — after each meeting, after each work block, at end of day at latest.

## Activity Log vs. Status.md

These serve different purposes:

| | Activity Log | Status.md |
|---|---|---|
| **Answers** | "What happened?" | "Where do things stand?" |
| **Granularity** | Individual events | Thread-level state |
| **Time** | Timestamped events | Current snapshot |
| **Example** | "Deployed v2.1, 45 min" | "Production: v2.1 live, next: monitoring" |

Both are needed. "Deployed for 45 minutes" tells the steward what you did. "Production is now on v2.1" tells the steward the state changed.

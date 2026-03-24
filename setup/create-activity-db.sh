#!/bin/bash
# Create the SQLite activity database for work tracking
# Run once during initial setup

DB_PATH="${1:-$HOME/.claude/activity.db}"

if [ -f "$DB_PATH" ]; then
  echo "Database already exists at $DB_PATH"
  echo "To recreate, delete it first: rm $DB_PATH"
  exit 1
fi

# Ensure directory exists
mkdir -p "$(dirname "$DB_PATH")"

sqlite3 "$DB_PATH" << 'EOF'
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

-- Research query tracking
-- Use this to track prompts you send to external models (e.g., GPT 5.4 Pro)
-- and their responses. Helps you maintain a library of deep research queries.
CREATE TABLE research_queries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    project TEXT,
    status TEXT DEFAULT 'draft',  -- draft, sent, received, reviewed
    model TEXT,                    -- e.g., gpt-5.4-pro, claude-opus
    tags TEXT,                     -- comma-separated
    summary TEXT,
    prompt_path TEXT,              -- relative path to prompt.md
    response_path TEXT,            -- relative path to response.md
    created_at TEXT DEFAULT (datetime('now', 'localtime')),
    updated_at TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX idx_rq_project ON research_queries(project);
CREATE INDEX idx_rq_status ON research_queries(status);
EOF

echo "Activity database created at $DB_PATH"
echo ""
echo "Usage examples:"
echo ""
echo "  # Log an activity"
echo "  sqlite3 $DB_PATH \"INSERT INTO activity_log (timestamp, project, category, activity, duration_min, notes) VALUES (datetime('now', 'localtime'), 'myproject', 'meeting', 'Weekly sync', 30, 'Discussed roadmap');\""
echo ""
echo "  # View recent activity"
echo "  sqlite3 -header -column $DB_PATH \"SELECT * FROM activity_log WHERE timestamp >= datetime('now', '-7 days', 'localtime') ORDER BY timestamp;\""
echo ""
echo "  # Hours by project this week"
echo "  sqlite3 -header -column $DB_PATH \"SELECT project, printf('%.1f hrs', SUM(duration_min)/60.0) FROM activity_log WHERE timestamp >= datetime('now', '-7 days', 'localtime') GROUP BY project;\""
echo ""
echo "Categories: coding, deployment, research, meeting, writing, planning, admin, communication, review, practice, break"
echo ""
echo "  # Track a research query"
echo "  sqlite3 $DB_PATH \"INSERT INTO research_queries (slug, title, project, status, model, summary, prompt_path) VALUES ('my-query', 'Research Title', 'myproject', 'draft', 'gpt-5.4-pro', 'Brief description', 'work/research/queries/my-query/prompt.md');\""
echo ""
echo "  # List research queries"
echo "  sqlite3 -header -column $DB_PATH \"SELECT slug, project, status, model FROM research_queries ORDER BY created_at DESC;\""

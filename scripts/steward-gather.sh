#!/bin/bash
# Phase 1: Context gathering for steward review
# Runs fast — collects all project state into a single briefing file
# This is called by daily-check.sh and evening-check.sh before the deep-think pass
#
# Usage: steward-gather.sh <morning|evening> <output-file>
#
# CUSTOMIZE: Update PROJECT_DIR and any project-specific file paths below.

set -euo pipefail

MODE="${1:-morning}"
OUTPUT="${2:-/tmp/steward-briefing.md}"

PROJECT_DIR="[YOUR_PROJECT_DIR]"          # e.g., /home/you/projects/mywork
ACTIVITY_DB="$HOME/.claude/activity.db"
STUCK_FILE="$HOME/.claude/steward-stuck.json"

# --- Helper ---
section() {
  echo "" >> "$OUTPUT"
  echo "=== $1 ===" >> "$OUTPUT"
  echo "" >> "$OUTPUT"
}

file_if_exists() {
  if [ -f "$1" ]; then
    cat "$1" >> "$OUTPUT"
    echo "" >> "$OUTPUT"
  fi
}

# --- Start fresh ---
echo "# Steward Briefing — $(date '+%A, %B %d, %Y') ($MODE)" > "$OUTPUT"

# --- 1. Status dashboard (most important) ---
section "STATUS DASHBOARD"
file_if_exists "$PROJECT_DIR/work/status.md"

# --- 2. Activity log ---
section "ACTIVITY LOG"
if [ -f "$ACTIVITY_DB" ]; then
  if [ "$MODE" = "morning" ]; then
    echo "Last 3 days:" >> "$OUTPUT"
    sqlite3 -header "$ACTIVITY_DB" "
      SELECT timestamp,
        CASE CAST(strftime('%w', timestamp) AS INTEGER)
          WHEN 0 THEN 'Sun' WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue'
          WHEN 3 THEN 'Wed' WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat'
        END as day,
        project, category, activity, duration_min, notes
      FROM activity_log
      WHERE timestamp >= datetime('now', '-3 days', 'localtime')
      ORDER BY timestamp;
    " 2>/dev/null >> "$OUTPUT" || echo "(query failed)" >> "$OUTPUT"
    TOTAL=$(sqlite3 "$ACTIVITY_DB" "
      SELECT printf('%.1f', COALESCE(SUM(duration_min), 0)/60.0)
      FROM activity_log
      WHERE timestamp >= datetime('now', '-3 days', 'localtime');
    " 2>/dev/null || echo "0")
    echo "" >> "$OUTPUT"
    echo "Total hours (3 days): $TOTAL" >> "$OUTPUT"
  else
    echo "Today:" >> "$OUTPUT"
    sqlite3 -header "$ACTIVITY_DB" "
      SELECT timestamp,
        CASE CAST(strftime('%w', timestamp) AS INTEGER)
          WHEN 0 THEN 'Sun' WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue'
          WHEN 3 THEN 'Wed' WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' WHEN 6 THEN 'Sat'
        END as day,
        project, category, activity, duration_min, notes
      FROM activity_log
      WHERE date(timestamp) = date('now', 'localtime')
      ORDER BY timestamp;
    " 2>/dev/null >> "$OUTPUT" || echo "(query failed)" >> "$OUTPUT"
    TODAY_HRS=$(sqlite3 "$ACTIVITY_DB" "
      SELECT printf('%.1f', COALESCE(SUM(duration_min), 0)/60.0)
      FROM activity_log
      WHERE date(timestamp) = date('now', 'localtime');
    " 2>/dev/null || echo "0")
    WEEK_HRS=$(sqlite3 "$ACTIVITY_DB" "
      SELECT printf('%.1f', COALESCE(SUM(duration_min), 0)/60.0)
      FROM activity_log
      WHERE timestamp >= datetime('now', '-7 days', 'localtime');
    " 2>/dev/null || echo "0")
    WEEK_BREAKDOWN=$(sqlite3 "$ACTIVITY_DB" "
      SELECT project, printf('%.1f hrs', SUM(duration_min)/60.0) as hours
      FROM activity_log
      WHERE timestamp >= datetime('now', '-7 days', 'localtime')
      GROUP BY project ORDER BY SUM(duration_min) DESC;
    " 2>/dev/null || echo "(no data)")
    echo "" >> "$OUTPUT"
    echo "Hours today: $TODAY_HRS | Hours this week: $WEEK_HRS" >> "$OUTPUT"
    echo "Weekly breakdown:" >> "$OUTPUT"
    echo "$WEEK_BREAKDOWN" >> "$OUTPUT"
  fi
else
  echo "(no activity database found)" >> "$OUTPUT"
fi

# --- 3. Git log ---
section "GIT LOG (last 3 days)"
cd "$PROJECT_DIR"
git log --since="3 days ago" --format="%ad %s" --date=format:"%a %b %d" --no-decorate 2>/dev/null >> "$OUTPUT" || echo "(no commits)" >> "$OUTPUT"

# --- 4. Key project files ---
# CUSTOMIZE: Add your own project files here.
# Example:
#   section "MY PROJECT"
#   file_if_exists "$PROJECT_DIR/work/my-project/tracker.md"
#
# Include operational files (trackers, status docs), not reference material.
# Keep the briefing focused — the steward doesn't need every file, just the
# ones that tell it where things stand.

section "PROJECT FILES"
echo "(Add your project-specific files here. See comments in script.)" >> "$OUTPUT"

# --- 5. Stuck item tracker ---
section "STUCK ITEM TRACKER"
if [ -f "$STUCK_FILE" ]; then
  cat "$STUCK_FILE" >> "$OUTPUT"
else
  echo "(no stuck items tracked yet — this is the first run with tracking)" >> "$OUTPUT"
fi

# --- 6. Today's conversation transcript summary ---
section "TODAY'S CONVERSATION SUMMARY"
SESSION_SUMMARY="/tmp/steward-session-summary-$(date +%Y%m%d).md"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
if CLAUDE_BIN="$CLAUDE_BIN" "$HOME/.claude/steward-summarize-sessions.sh" "$SESSION_SUMMARY" 2>/dev/null; then
  if [ -f "$SESSION_SUMMARY" ] && [ -s "$SESSION_SUMMARY" ]; then
    cat "$SESSION_SUMMARY" >> "$OUTPUT"
  else
    echo "(session summary generation produced empty output)" >> "$OUTPUT"
  fi
else
  echo "(session summary generation failed — check steward-summarize-sessions.sh)" >> "$OUTPUT"
fi

echo "" >> "$OUTPUT"
echo "=== END BRIEFING ===" >> "$OUTPUT"

# Report size
LINES=$(wc -l < "$OUTPUT")
SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "Briefing generated: $LINES lines, $SIZE"

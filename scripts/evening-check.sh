#!/bin/bash
# Evening steward review — runs via cron at 6pm
# Accountability check: what moved, what didn't, pattern recognition
#
# CUSTOMIZE: Update paths, phone number, and project directory below.

export PATH="$HOME/.local/bin:$PATH"
export HOME="[YOUR_HOME_DIR]"       # e.g., /home/youruser
unset CLAUDECODE                     # Prevents nesting if called from within Claude Code

# Skip weekends and holidays
DOW=$(date +%u)  # 1=Mon, 7=Sun
TODAY=$(date +%Y-%m-%d)
HOLIDAYS_FILE="$HOME/.claude/holidays.txt"
if [ "$DOW" -ge 6 ]; then
  echo "$(date): SKIPPED — weekend (day $DOW)" >> "$HOME/.claude/cron.log"
  exit 0
fi
if [ -f "$HOLIDAYS_FILE" ] && grep -q "^$TODAY" "$HOLIDAYS_FILE"; then
  echo "$(date): SKIPPED — holiday ($TODAY)" >> "$HOME/.claude/cron.log"
  exit 0
fi

# CUSTOMIZE these paths
CLAUDE="$(which claude)"
SIGNAL_CLI="$(which signal-cli)"
PHONE="[YOUR_PHONE_NUMBER]"
PROJECT_DIR="[YOUR_PROJECT_DIR]"
PERSONA="$HOME/.claude/steward-persona.md"
LOG="$HOME/.claude/cron.log"
COMBINED_OUTPUT="/tmp/steward-evening-combined.txt"

echo "$(date): evening-check.sh starting" >> "$LOG"

# Read the persona file
PERSONA_TEXT=$(cat "$PERSONA" 2>/dev/null)
if [ -z "$PERSONA_TEXT" ]; then
  echo "$(date): ERROR — persona file missing or empty" >> "$LOG"
  exit 1
fi

# Pull today's activity from SQLite
ACTIVITY_DB="$HOME/.claude/activity.db"
TODAY_ACTIVITY=""
if [ -f "$ACTIVITY_DB" ]; then
  TODAY_ACTIVITY=$(sqlite3 -header "$ACTIVITY_DB" "
    SELECT timestamp, project, category, activity, duration_min, notes
    FROM activity_log
    WHERE date(timestamp) = date('now', 'localtime')
    ORDER BY timestamp;
  " 2>/dev/null)
  TODAY_HOURS=$(sqlite3 "$ACTIVITY_DB" "
    SELECT printf('%.1f', COALESCE(SUM(duration_min), 0)/60.0)
    FROM activity_log
    WHERE date(timestamp) = date('now', 'localtime');
  " 2>/dev/null)
  WEEK_HOURS=$(sqlite3 "$ACTIVITY_DB" "
    SELECT printf('%.1f', COALESCE(SUM(duration_min), 0)/60.0)
    FROM activity_log
    WHERE timestamp >= datetime('now', '-7 days', 'localtime');
  " 2>/dev/null)
  WEEK_BREAKDOWN=$(sqlite3 "$ACTIVITY_DB" "
    SELECT project, printf('%.1f hrs', SUM(duration_min)/60.0) as hours
    FROM activity_log
    WHERE timestamp >= datetime('now', '-7 days', 'localtime')
    GROUP BY project ORDER BY SUM(duration_min) DESC;
  " 2>/dev/null)
fi

# Build prompt
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << ENDOFPROMPT
$PERSONA_TEXT

---

EVENING REVIEW — $(date '+%A, %B %d, %Y')

## TODAY'S ACTIVITY LOG
This captures ALL work — meetings, deployments, calls, admin — not just git commits. Read this FIRST before assessing the day.

Hours logged today: ${TODAY_HOURS:-0}
Hours logged this week: ${WEEK_HOURS:-0}

${TODAY_ACTIVITY:-No activity logged today.}

Weekly breakdown by project:
${WEEK_BREAKDOWN:-No data.}

---

This is the evening accountability review. Read everything listed in your instructions above. Read the activity log above FIRST — it captures work that git misses. Then check git log for today.

Then write your evening message. Focus on:
1. What actually moved today — check BOTH the activity log AND git commits. Meetings, deployments, and calls count as real work.
2. What was supposed to happen but didn't — check the morning's priorities against reality
3. Pattern recognition: is this part of a streak (good or bad)? Has this week been productive or spinning?
4. The single most important thing for tomorrow
5. If rest is warranted, say so — sustainable pace matters

CRITICAL OUTPUT INSTRUCTIONS:
- Your FINAL response must be ONLY the plain text message to send. No preamble like "Here's the message" or "I'll send this." Just the message itself.
- Do NOT try to send the message yourself. Do NOT use any tools in your final response. Just output the text.
- If nothing useful to say, output exactly: SKIP
- Plain text only. No markdown. No asterisks. No headers.
ENDOFPROMPT

# Run Claude in headless mode
$CLAUDE -p "$(cat "$PROMPT_FILE")" \
  --allowedTools "Read,Glob,Grep,Bash" \
  --max-turns 25 \
  -d "$PROJECT_DIR" > "$COMBINED_OUTPUT" 2>&1

EXIT_CODE=$?
DIGEST=$(cat "$COMBINED_OUTPUT" 2>/dev/null)
echo "$(date): claude exit code: $EXIT_CODE, combined output length: ${#DIGEST}" >> "$LOG"

# Save full output to log for debugging
echo "$(date): === FULL OUTPUT ===" >> "$LOG"
echo "$DIGEST" >> "$LOG"
echo "$(date): === END OUTPUT ===" >> "$LOG"

# Filter: don't send on error exit
if [ $EXIT_CODE -ne 0 ]; then
  echo "$(date): SKIPPED — claude exited with error code $EXIT_CODE" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"
  exit 1
fi

if [ -z "$DIGEST" ]; then
  echo "$(date): SKIPPED — empty output" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"
  exit 0
fi

# Filter API errors
if echo "$DIGEST" | grep -qi "API Error\|Internal server error\|api_error\|rate_limit"; then
  echo "$(date): SKIPPED — output contains API error" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"
  exit 1
fi

# Extract the final message block (after last --- separator)
if echo "$DIGEST" | grep -q "^---$"; then
  MESSAGE=$(echo "$DIGEST" | awk '/^---$/{buf=""; next} {buf=buf"\n"$0} END{print buf}' | sed '/^$/d' | sed 's/^[[:space:]]*//')
else
  MESSAGE="$DIGEST"
fi

# Strip common preamble lines
MESSAGE=$(echo "$MESSAGE" | grep -v "^Here's the evening" | grep -v "^Want me to send" | grep -v "^I've now read" | grep -v "^Let me compose" | sed '/^$/{ N; /^\n$/d; }')

# Trim whitespace
MESSAGE=$(echo "$MESSAGE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$MESSAGE" ]; then
  echo "$(date): SKIPPED — message empty after parsing" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"
  exit 0
fi

if [ "$MESSAGE" = "SKIP" ]; then
  echo "$(date): SKIPPED — steward said SKIP (nothing to report)" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"
  exit 0
fi

# Send via Signal
echo "$MESSAGE" | $SIGNAL_CLI -a "$PHONE" send --message-from-stdin --notify-self "$PHONE" 2>>"$LOG"
echo "$(date): Signal sent OK" >> "$LOG"

# Cleanup
rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"

#!/bin/bash
# Morning steward review — runs via cron at 9am
# Deep review of all projects, trajectory check, recommendation
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
CLAUDE="$(which claude)"                        # Path to claude CLI
SIGNAL_CLI="$(which signal-cli)"                # Path to signal-cli
PHONE="[YOUR_PHONE_NUMBER]"                     # e.g., +14155551234
PROJECT_DIR="[YOUR_PROJECT_DIR]"                # e.g., /home/you/projects/mywork
PERSONA="$HOME/.claude/steward-persona.md"
LOG="$HOME/.claude/cron.log"
COMBINED_OUTPUT="/tmp/steward-morning-combined.txt"

echo "$(date): daily-check.sh starting" >> "$LOG"

# Read the persona file
PERSONA_TEXT=$(cat "$PERSONA" 2>/dev/null)
if [ -z "$PERSONA_TEXT" ]; then
  echo "$(date): ERROR — persona file missing or empty" >> "$LOG"
  exit 1
fi

# Pull recent activity from SQLite
ACTIVITY_DB="$HOME/.claude/activity.db"
RECENT_ACTIVITY=""
if [ -f "$ACTIVITY_DB" ]; then
  RECENT_ACTIVITY=$(sqlite3 -header "$ACTIVITY_DB" "
    SELECT timestamp, project, category, activity, duration_min, notes
    FROM activity_log
    WHERE timestamp >= datetime('now', '-3 days', 'localtime')
    ORDER BY timestamp;
  " 2>/dev/null)
  TOTAL_HOURS=$(sqlite3 "$ACTIVITY_DB" "
    SELECT printf('%.1f', COALESCE(SUM(duration_min), 0)/60.0)
    FROM activity_log
    WHERE timestamp >= datetime('now', '-3 days', 'localtime');
  " 2>/dev/null)
fi

# Build prompt
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << ENDOFPROMPT
$PERSONA_TEXT

---

MORNING REVIEW — $(date '+%A, %B %d, %Y')

## ACTIVITY LOG (last 3 days)
This is the actual work log — it captures meetings, deployments, calls, and other work that does NOT produce git commits. Read this BEFORE checking git log. Do not say "nothing happened" if activities are logged here.

Total hours logged (last 3 days): ${TOTAL_HOURS:-0}

${RECENT_ACTIVITY:-No activity logged in the database.}

---

This is the morning review. Read everything listed in your instructions above. Also read the activity log above — it captures work that git misses (meetings, deployments, calls, admin). Take your time — read each file, check the git log for the past 3 days, cross-reference open threads against actual progress.

Then write your morning message. Focus on:
1. What deserves energy TODAY specifically — not a recap of everything open, but the highest-leverage move
2. Anything that's slipping or has been sitting too long — be specific
3. Any deadlines in the next 7 days
4. If there's a pattern of drift or paralysis across recent days, name it
5. One clear recommendation

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

# Claude's output when using tools includes thinking/tool-use in the stream.
# Extract the final message block (after last --- separator).
if echo "$DIGEST" | grep -q "^---$"; then
  MESSAGE=$(echo "$DIGEST" | awk '/^---$/{buf=""; next} {buf=buf"\n"$0} END{print buf}' | sed '/^$/d' | sed 's/^[[:space:]]*//')
else
  MESSAGE="$DIGEST"
fi

# Strip common preamble lines Claude sometimes adds
MESSAGE=$(echo "$MESSAGE" | grep -v "^Here's the morning message" | grep -v "^Want me to send" | grep -v "^I've now read" | grep -v "^Let me compose" | sed '/^$/{ N; /^\n$/d; }')

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

# Send via Signal (sends to self — you receive it on your phone)
echo "$MESSAGE" | $SIGNAL_CLI -a "$PHONE" send --message-from-stdin --notify-self "$PHONE" 2>>"$LOG"
echo "$(date): Signal sent OK" >> "$LOG"

# Cleanup
rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT"

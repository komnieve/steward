#!/bin/bash
# Evening steward review — runs via cron at 6pm
# Two-phase architecture:
#   Phase 1: Gather all context into a briefing file (fast, no AI needed)
#   Phase 2: Deep-think pass with full briefing + persona (ultrathink)
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
GATHER="$HOME/.claude/steward-gather.sh"
UPDATE_STUCK="$HOME/.claude/steward-update-stuck.sh"
LOG="$HOME/.claude/cron.log"
BRIEFING="/tmp/steward-evening-briefing.md"
COMBINED_OUTPUT="/tmp/steward-evening-combined.txt"

echo "$(date): evening-check.sh starting" >> "$LOG"

# --- Phase 1: Gather context ---
echo "$(date): Phase 1 — gathering context" >> "$LOG"
bash "$GATHER" evening "$BRIEFING" >> "$LOG" 2>&1
if [ ! -f "$BRIEFING" ]; then
  echo "$(date): ERROR — briefing file not generated" >> "$LOG"
  exit 1
fi
BRIEFING_LINES=$(wc -l < "$BRIEFING")
echo "$(date): Briefing ready: $BRIEFING_LINES lines" >> "$LOG"

# --- Phase 2: Deep-think analysis ---
echo "$(date): Phase 2 — deep-think analysis" >> "$LOG"

# Read the persona file
PERSONA_TEXT=$(cat "$PERSONA" 2>/dev/null)
if [ -z "$PERSONA_TEXT" ]; then
  echo "$(date): ERROR — persona file missing or empty" >> "$LOG"
  exit 1
fi

# Read the briefing
BRIEFING_TEXT=$(cat "$BRIEFING" 2>/dev/null)

# Build the prompt
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" << ENDOFPROMPT
$PERSONA_TEXT

---

EVENING REVIEW — $(date '+%A, %B %d, %Y')

The following briefing contains ALL project state, activity logs, git history, stuck item tracking, and reference materials. Everything you need is here — you do not need to read any additional files.

$BRIEFING_TEXT

---

This is the evening accountability review. The briefing above contains everything. Think deeply about:

1. What actually moved today — check BOTH the activity log AND git commits. Meetings, deployments, and calls count as real work.
2. What was supposed to happen but didn't — check the morning's priorities against reality
3. Pattern recognition: is this part of a streak (good or bad)? Has this week been productive or spinning?
4. The single most important thing for tomorrow
5. If a sit day or rest is warranted, say so — sustainable pace matters

FOR STUCK ITEMS AT SCAFFOLD LEVEL: You MUST draft actual, ready-to-send actions. Make it so all he has to do is say "yes." If you scaffolded something this morning and it wasn't acted on, don't repeat the same scaffold — note it's waiting and ask what happened.

FOR STUCK ITEMS AT REFRAME LEVEL: Engage the deeper conversation. Don't repeat yourself. Try a new angle.

After your message, output the STUCK_UPDATE block to update the tracker.

CRITICAL OUTPUT INSTRUCTIONS:
- Your FINAL response must be ONLY the plain text message to send, followed by the STUCK_UPDATE block.
- Do NOT try to send the message yourself. Do NOT use any tools in your final response. Just output the text.
- If nothing useful to say, output exactly: SKIP
- Plain text only in the message portion. No markdown. No asterisks. No headers.
ENDOFPROMPT

# Run with high effort (ultrathink) for deep analysis
cat "$PROMPT_FILE" | $CLAUDE -p \
  --effort high \
  --allowedTools "Read,Glob,Grep,Bash,WebSearch" \
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
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT" "$BRIEFING"
  exit 1
fi

if [ -z "$DIGEST" ]; then
  echo "$(date): SKIPPED — empty output" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT" "$BRIEFING"
  exit 0
fi

# Filter API errors
if echo "$DIGEST" | grep -qi "API Error\|Internal server error\|api_error\|rate_limit"; then
  echo "$(date): SKIPPED — output contains API error" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT" "$BRIEFING"
  exit 1
fi

# --- Update stuck tracker ---
bash "$UPDATE_STUCK" "$COMBINED_OUTPUT" >> "$LOG" 2>&1

# --- Extract message (everything before <<<STUCK_UPDATE>>>) ---
MESSAGE=$(echo "$DIGEST" | sed '/<<<STUCK_UPDATE>>>/,/<<<END_STUCK_UPDATE>>>/d')

# Strip any remaining "---" separator lines (steward sometimes uses them)
MESSAGE=$(echo "$MESSAGE" | grep -v "^---$")

# Strip common preamble lines
MESSAGE=$(echo "$MESSAGE" | grep -v "^Here's the evening" | grep -v "^Want me to send" | grep -v "^I've now read" | grep -v "^Let me compose" | sed '/^$/{ N; /^\n$/d; }')

# Trim whitespace
MESSAGE=$(echo "$MESSAGE" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$MESSAGE" ]; then
  echo "$(date): SKIPPED — message empty after parsing" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT" "$BRIEFING"
  exit 0
fi

if [ "$MESSAGE" = "SKIP" ]; then
  echo "$(date): SKIPPED — steward said SKIP (nothing to report)" >> "$LOG"
  rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT" "$BRIEFING"
  exit 0
fi

# Send via Signal
echo "$MESSAGE" | $SIGNAL_CLI -a "$PHONE" send --message-from-stdin --notify-self "$PHONE" 2>>"$LOG"
echo "$(date): Signal sent OK" >> "$LOG"

# Cleanup
rm -f "$PROMPT_FILE" "$COMBINED_OUTPUT" "$BRIEFING"

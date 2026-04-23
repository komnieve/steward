#!/bin/bash
# Weekly quote-finder for the focus persona's library.
# Reads the current quotes.md, sweeps multiple thin/over-cycled themes, and appends
# as much material as lands — no cap on quantity. The selection-time model at
# each focus tick chooses what's skillful; deeper library = better selection pool.
# Models only get more powerful, so bet on model judgment at use-time, not on
# artificial throttling at ingestion-time.
#
# Cadence: weekly, Sunday 9am (see launchd/*.template).
# Runtime-aware: shells out to `claude` on claude-code, `codex` on codex.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEWARD_HOME="${STEWARD_HOME:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
RUNTIME="${STEWARD_RUNTIME:-claude-code}"

QUOTES_FILE="${STEWARD_QUOTES_FILE:-$SCRIPT_DIR/quotes.md}"
LOG="${STEWARD_LOG:-$STEWARD_HOME/log/quote-finder.log}"
ACTIVITY_DB="${STEWARD_ACTIVITY_DB:-$STEWARD_HOME/activity.db}"
TS=$(date '+%Y-%m-%d %H:%M:%S')

mkdir -p "$(dirname "$LOG")"

echo "[$TS] quote-finder starting" >> "$LOG"

if [ ! -f "$QUOTES_FILE" ]; then
    echo "[$TS] ERROR: quotes file not found at $QUOTES_FILE" >> "$LOG"
    exit 1
fi

# ---------- Prompt ----------
# Loaded from sibling file so the bash parser doesn't have to swallow a
# multi-hundred-line heredoc with embedded backticks and parens.
PROMPT_FILE="$SCRIPT_DIR/quote-finder.prompt.md"
if [ ! -f "$PROMPT_FILE" ]; then
    echo "[$TS] ERROR: prompt file not found at $PROMPT_FILE" >> "$LOG"
    exit 1
fi
PROMPT="$(cat "$PROMPT_FILE")"
PROMPT="${PROMPT//\{\{QUOTES_FILE\}\}/$QUOTES_FILE}"

# ---------- Invoke the configured runtime ----------
case "$RUNTIME" in
  claude-code)
    if ! command -v claude >/dev/null 2>&1; then
      echo "[$TS] ERROR: claude CLI not on PATH" >> "$LOG"
      exit 1
    fi
    RESULT=$(claude -p "$PROMPT" \
        --allowedTools "Read,WebSearch,WebFetch" \
        --model "${STEWARD_LLM_MODEL:-claude-opus-4-6}" \
        --max-turns 100 \
        --permission-mode dontAsk \
        2>>"$LOG")
    ;;
  codex)
    if ! command -v codex >/dev/null 2>&1; then
      echo "[$TS] ERROR: codex CLI not on PATH" >> "$LOG"
      exit 1
    fi
    RESULT=$(codex run "$PROMPT" 2>>"$LOG")
    ;;
  *)
    echo "[$TS] ERROR: unknown STEWARD_RUNTIME=$RUNTIME" >> "$LOG"
    exit 1
    ;;
esac

# ---------- Sanity checks ----------
if [ -z "$RESULT" ]; then
    echo "[$TS] empty response — skipping append" >> "$LOG"
    exit 0
fi

if echo "$RESULT" | grep -q '^SKIP$'; then
    echo "[$TS] model chose to SKIP this week" >> "$LOG"
    exit 0
fi

# Must look like markdown (HTML comment + bullet lines). If it doesn't, log and skip.
if ! echo "$RESULT" | grep -q '<!-- auto-added'; then
    echo "[$TS] response did not match expected format — skipping append:" >> "$LOG"
    echo "$RESULT" >> "$LOG"
    echo "---" >> "$LOG"
    exit 0
fi

# Dedupe guard — if any proposed quote already exists verbatim in quotes.md, skip the whole batch
while IFS= read -r line; do
    # Extract the quoted text (between *" and "*)
    quote=$(echo "$line" | grep -oE '\*"[^"]+"\*' | head -1)
    if [ -n "$quote" ]; then
        if grep -qF "$quote" "$QUOTES_FILE"; then
            echo "[$TS] dedupe hit on: $quote — skipping entire batch" >> "$LOG"
            exit 0
        fi
    fi
done < <(echo "$RESULT")

# ---------- Append ----------
{
    echo ""
    echo "$RESULT"
} >> "$QUOTES_FILE"

# Count new lines added
NEW_COUNT=$(echo "$RESULT" | grep -c '^- \*"' || true)

echo "[$TS] appended $NEW_COUNT quote(s)" >> "$LOG"
echo "---" >> "$LOG"

# ---------- Log to activity.db (if present) ----------
if [ -f "$ACTIVITY_DB" ]; then
    sqlite3 "$ACTIVITY_DB" "INSERT INTO activity_log (timestamp, project, category, activity, duration_min, notes) VALUES (datetime('now', 'localtime'), 'steward', 'writing', 'Quote finder added $NEW_COUNT quote(s)', 2, 'Weekly cron: appended to focus persona quote library.');" 2>/dev/null || true
fi

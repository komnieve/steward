#!/usr/bin/env bash
# Morning steward review. Runtime-aware, delivery-aware.
#
# Reads:  ~/.steward/config.json (runtime, delivery, features)
# Uses:   detected agent runtime (claude-code / codex / etc.)
# Writes: delivery per config (terminal / slack webhook / etc.)
#
# Usage:
#   ./scripts/daily-check.sh             — run with defaults
#   MODE=morning ./scripts/daily-check.sh
#   MODE=evening ./scripts/evening-check.sh

set -euo pipefail

MODE="${MODE:-morning}"
STEWARD_HOME="${STEWARD_HOME:-$HOME/.steward}"
STEWARD_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$STEWARD_HOME/logs/${MODE}.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "$(date '+%Y-%m-%dT%H:%M:%S%z') $*" >> "$LOG"; }

# --- sanity ---
if [[ ! -d "$STEWARD_HOME" ]]; then
  echo "error: $STEWARD_HOME does not exist. run ./scripts/setup first." >&2
  exit 1
fi
if [[ ! -f "$STEWARD_HOME/config.json" ]]; then
  echo "error: $STEWARD_HOME/config.json missing. re-run ./scripts/setup." >&2
  exit 1
fi

# --- skip weekends and holidays (unless forced) ---
if [[ "${FORCE:-}" != "1" ]]; then
  DOW=$(date +%u)  # 1=Mon … 7=Sun
  TODAY=$(date +%Y-%m-%d)
  HOLIDAYS="$STEWARD_REPO/templates/holidays.txt"
  if [[ "$DOW" -ge 6 ]]; then
    log "SKIPPED weekend"
    exit 0
  fi
  if [[ -f "$HOLIDAYS" ]] && grep -q "^$TODAY" "$HOLIDAYS"; then
    log "SKIPPED holiday $TODAY"
    exit 0
  fi
fi

log "starting $MODE check"

# --- load config ---
read -r RUNTIME DELIVERY USER_NAME < <(python3 - "$STEWARD_HOME/config.json" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
print(data.get("runtime", ""), data.get("delivery", "terminal"), data.get("user", "user"))
PY
)

log "runtime=$RUNTIME delivery=$DELIVERY user=$USER_NAME"

# --- gather activity (last 48h) ---
ACTIVITY=$(sqlite3 "$STEWARD_HOME/activity.db" "
  SELECT timestamp, project, category, activity, duration_min
  FROM activity_log
  WHERE timestamp >= datetime('now', '-48 hours', 'localtime')
  ORDER BY timestamp DESC
  LIMIT 40;" 2>/dev/null || echo "")

# --- build the briefing that goes to the agent ---
BRIEF=$(mktemp -t steward-brief.XXXXXX)
{
  echo "# Steward briefing — $MODE — $(date '+%Y-%m-%d %H:%M %Z')"
  echo
  echo "## Context you already have"
  echo "- user-lens: \`~/.steward/user-lens.md\`"
  echo "- persona:   \`~/.steward/persona.md\`"
  echo "- intention: \`~/.steward/intention.md\`"
  echo "- practice:  \`~/.steward/practice/*.md\`"
  echo "- status:    \`~/.steward/status.md\`"
  echo
  echo "## Recent activity (last 48h)"
  if [[ -n "$ACTIVITY" ]]; then
    echo "\`\`\`"
    echo "$ACTIVITY"
    echo "\`\`\`"
  else
    echo "(no logged activity in the window)"
  fi
  echo
  echo "## Ask"
  if [[ "$MODE" == "morning" ]]; then
    echo "Generate a morning check-in. Read the files above. Read activity.db for"
    echo "anything relevant not already shown. Write a short, honest reflection: what"
    echo "deserves energy today, what's slipping, any deadlines, one sentence on"
    echo "whether the substrate (practice, sleep, maintenance) is being tended."
  else
    echo "Generate an evening reflection. Read the files above. What moved today?"
    echo "What didn't? Any pattern worth naming? One sentence of energy or practice"
    echo "observation for tomorrow."
  fi
} > "$BRIEF"

log "briefing ready at $BRIEF ($(wc -l < "$BRIEF") lines)"

# --- invoke agent runtime to produce the message ---
MSG=$(mktemp -t steward-msg.XXXXXX)
case "$RUNTIME" in
  claude-code)
    if command -v claude >/dev/null 2>&1; then
      (cd "$STEWARD_HOME" && claude -p "$(cat "$BRIEF")" --output-format text) > "$MSG" 2>> "$LOG" || {
        log "claude invocation failed — see $LOG"
        echo "[steward] agent invocation failed; see $LOG" > "$MSG"
      }
    else
      log "claude CLI not found; writing placeholder"
      echo "[steward] claude CLI not found. install it, or re-run setup and pick a different runtime." > "$MSG"
    fi
    ;;
  codex)
    if command -v codex >/dev/null 2>&1; then
      (cd "$STEWARD_HOME" && codex run "$(cat "$BRIEF")") > "$MSG" 2>> "$LOG" || {
        log "codex invocation failed — see $LOG"
        echo "[steward] agent invocation failed; see $LOG" > "$MSG"
      }
    else
      log "codex CLI not found; writing placeholder"
      echo "[steward] codex CLI not found. install it, or re-run setup and pick a different runtime." > "$MSG"
    fi
    ;;
  *)
    log "unknown runtime: $RUNTIME"
    echo "[steward] unknown runtime '$RUNTIME' in config.json. re-run ./scripts/setup." > "$MSG"
    ;;
esac

# --- deliver ---
case "$DELIVERY" in
  slack)
    WEBHOOK=""
    [[ -f "$STEWARD_HOME/.env" ]] && WEBHOOK=$(grep '^SLACK_WEBHOOK_URL=' "$STEWARD_HOME/.env" | cut -d= -f2-)
    if [[ -z "$WEBHOOK" ]]; then
      log "no SLACK_WEBHOOK_URL — falling back to stdout"
      cat "$MSG"
    else
      # Escape for JSON: naive, works for most steward output.
      PAYLOAD=$(python3 -c "import json,sys; print(json.dumps({'text': sys.stdin.read()}))" < "$MSG")
      curl -s -X POST -H 'Content-Type: application/json' --data "$PAYLOAD" "$WEBHOOK" >> "$LOG" 2>&1 \
        && log "delivered to slack webhook" \
        || log "slack delivery failed"
    fi
    ;;
  signal)
    SIGNAL_NUMBER=""
    SIGNAL_RECIPIENT=""
    if [[ -f "$STEWARD_HOME/.env" ]]; then
      SIGNAL_NUMBER=$(grep '^SIGNAL_NUMBER=' "$STEWARD_HOME/.env" | cut -d= -f2-)
      SIGNAL_RECIPIENT=$(grep '^SIGNAL_RECIPIENT=' "$STEWARD_HOME/.env" | cut -d= -f2-)
    fi
    # Default recipient to the linked number (send-to-self) when unset.
    [[ -z "$SIGNAL_RECIPIENT" ]] && SIGNAL_RECIPIENT="$SIGNAL_NUMBER"
    if ! command -v signal-cli >/dev/null 2>&1; then
      log "signal-cli not found — falling back to stdout"
      cat "$MSG"
    elif [[ -z "$SIGNAL_NUMBER" ]]; then
      log "no SIGNAL_NUMBER in $STEWARD_HOME/.env — falling back to stdout"
      cat "$MSG"
    else
      if signal-cli -a "$SIGNAL_NUMBER" send --message-from-stdin --notify-self "$SIGNAL_RECIPIENT" < "$MSG" >> "$LOG" 2>&1; then
        log "delivered to signal ($SIGNAL_RECIPIENT)"
      else
        log "signal delivery failed — falling back to stdout"
        cat "$MSG"
      fi
    fi
    ;;
  email)
    log "$DELIVERY delivery not yet wired in v0.2; falling back to stdout"
    cat "$MSG"
    ;;
  terminal|*)
    cat "$MSG"
    ;;
esac

# --- cleanup ---
rm -f "$BRIEF" "$MSG"
log "done"

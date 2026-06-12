#!/bin/bash
# Regenerate priorities.json for the focus dashboard.
#
# Called by launchd on schedule, and by POST /api/refresh.
# Invokes the configured LLM runtime with a durable prompt + fresh context,
# writes output atomically (only if valid JSON).
#
# Env vars (all optional — sensible defaults):
#   STEWARD_HOME         base dir (default: parent of this script's dir)
#   STEWARD_PRIORITIES   priorities.json path
#   STEWARD_STATUS_MD    project status file (optional; skipped if missing)
#   STEWARD_ACTIVITY_DB  activity.db path
#   STEWARD_FOCUS_DB     focus.db path (optional; skipped if missing)
#   STEWARD_STUCK_JSON   stuck tracker path (optional)
#   STEWARD_PROJECT_ROOT git dir to source recent commits from (optional)
#   STEWARD_RUNTIME      "claude-code" | "codex"  (default: claude-code)
#   STEWARD_LLM_MODEL    model id (default: claude-opus-4-7 on claude-code)
#   TZ                   timezone for timestamps

set -u

# Respect an explicitly-set TZ; otherwise use system localtime.
[ -n "${TZ:-}" ] && export TZ
unset CLAUDECODE

DASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEWARD_HOME="${STEWARD_HOME:-$(cd "$DASH_DIR/.." && pwd)}"
CONFIG_JSON="$STEWARD_HOME/config.json"
PROMPT_FILE="$DASH_DIR/prompt.md"
PRIORITIES="${STEWARD_PRIORITIES:-$DASH_DIR/priorities.json}"
LOG="${STEWARD_LOG:-$STEWARD_HOME/log/focus-dash-refresh.log}"

# Read a top-level string field from config.json using stdlib python3.
# Returns empty string if config is missing, unparseable, or field absent.
_cfg_get() {
  local key="$1"
  [ -f "$CONFIG_JSON" ] || { echo ""; return; }
  python3 - "$CONFIG_JSON" "$key" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    v = d.get(sys.argv[2], "")
    if v is None:
        v = ""
    print(v)
except Exception:
    print("")
PY
}

# Resolution order: env > config.json > sensible default.
RUNTIME="${STEWARD_RUNTIME:-$(_cfg_get runtime)}"
RUNTIME="${RUNTIME:-claude-code}"

PROJECT_DIR="${STEWARD_PROJECT_ROOT:-$(_cfg_get project_root)}"
# No $PWD fallback: unset => git section will skip cleanly.

STATUS_MD="${STEWARD_STATUS_MD:-$STEWARD_HOME/status.md}"
STUCK_JSON="${STEWARD_STUCK_JSON:-$STEWARD_HOME/stuck.json}"
# Legacy fallback: older installs used steward-stuck.json
if [ ! -f "$STUCK_JSON" ] && [ -f "$STEWARD_HOME/steward-stuck.json" ]; then
  STUCK_JSON="$STEWARD_HOME/steward-stuck.json"
fi
ACTIVITY_DB="${STEWARD_ACTIVITY_DB:-$STEWARD_HOME/activity.db}"
FOCUS_DB="${STEWARD_FOCUS_DB:-$STEWARD_HOME/personas/focus/focus.db}"

TS=$(date '+%Y-%m-%d %H:%M:%S %Z')

mkdir -p "$(dirname "$LOG")"
echo "$TS: refresh starting (caller=${1:-unknown})" >> "$LOG"
echo "$TS:   resolved runtime=$RUNTIME project_root=${PROJECT_DIR:-<unset>} status_md=$STATUS_MD" >> "$LOG"

# Skip on weekends (match steward policy)
DOW=$(date +%u)
if [ "$DOW" -ge 6 ]; then
  echo "$TS: SKIPPED — weekend (day $DOW)" >> "$LOG"
  exit 0
fi

TMPDIR_REFRESH=$(mktemp -d "${TMPDIR:-/tmp}/focus-refresh.XXXXXX") || exit 1
CONTEXT="$TMPDIR_REFRESH/context.md"
OUT_RAW="$TMPDIR_REFRESH/raw.txt"
OUT_JSON="$TMPDIR_REFRESH/out.json"

# -----------------------------------------------------------
# Assemble context
# -----------------------------------------------------------
{
  echo "# CURRENT priorities.json (preserve done + northstar unless stale)"
  cat "$PRIORITIES"
  echo ""
  echo "---"
  echo ""
  if [ -n "$STATUS_MD" ] && [ -f "$STATUS_MD" ]; then
    echo "# status.md — top 240 lines (P0 + deadlines + active projects)"
    head -240 "$STATUS_MD"
    echo ""
    echo "---"
    echo ""
  fi
  echo "# Stuck tracker"
  cat "$STUCK_JSON" 2>/dev/null || echo "(no stuck tracker)"
  echo ""
  echo "---"
  echo ""
  if [ -f "$ACTIVITY_DB" ]; then
    echo "# Activity today"
    sqlite3 "$ACTIVITY_DB" "SELECT timestamp, project, category, activity, duration_min, substr(notes,1,120) FROM activity_log WHERE date(timestamp) = date('now','localtime') ORDER BY timestamp DESC" -separator ' | ' 2>/dev/null
    echo ""
    echo "---"
    echo ""
    echo "# Activity yesterday"
    sqlite3 "$ACTIVITY_DB" "SELECT timestamp, project, category, activity, duration_min FROM activity_log WHERE date(timestamp) = date('now','-1 day','localtime') ORDER BY timestamp DESC" -separator ' | ' 2>/dev/null
    echo ""
    echo "---"
    echo ""
  fi
  if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR/.git" ]; then
    echo "# Recent git commits (24h)"
    ( cd "$PROJECT_DIR" && git log --since='24 hours ago' --pretty=format:'- %h %s' 2>/dev/null | head -20 )
    echo ""
    echo ""
    echo "---"
    echo ""
  fi
  if [ -f "$FOCUS_DB" ]; then
    echo "# Focus watcher — last 30 entries"
    sqlite3 "$FOCUS_DB" "SELECT substr(timestamp,12,5) as t, active_app, is_drift, substr(assessment,1,120) FROM focus_log ORDER BY id DESC LIMIT 30" -separator ' | ' 2>/dev/null
    echo ""
    echo "---"
    echo ""
  fi
  echo "# Current wall clock: $(date '+%A %B %d %Y, %I:%M %p %Z')"
} > "$CONTEXT"

CTX_BYTES=$(wc -c < "$CONTEXT")
echo "$TS: context assembled — $CTX_BYTES bytes" >> "$LOG"

# -----------------------------------------------------------
# Build final prompt (persona + context)
# -----------------------------------------------------------
FULL="$TMPDIR_REFRESH/full.md"
{
  cat "$PROMPT_FILE"
  echo ""
  echo "---"
  echo ""
  echo "# CONTEXT BUNDLE"
  echo ""
  cat "$CONTEXT"
} > "$FULL"

# -----------------------------------------------------------
# Invoke the configured runtime (text in, text out)
# -----------------------------------------------------------
START=$(date +%s)
case "$RUNTIME" in
  claude-code)
    MODEL="${STEWARD_LLM_MODEL:-claude-opus-4-7}"
    if ! command -v claude >/dev/null 2>&1; then
      echo "$TS: FAILED — claude CLI not found on PATH" >> "$LOG"
      rm -rf "$TMPDIR_REFRESH"
      exit 1
    fi
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
      claude \
        -p \
        --model "$MODEL" \
        --permission-mode dontAsk \
        --max-turns 4 \
        --add-dir "$PROJECT_DIR" \
        < "$FULL" > "$OUT_RAW" 2>> "$LOG"
    else
      claude \
        -p \
        --model "$MODEL" \
        --permission-mode dontAsk \
        --max-turns 4 \
        < "$FULL" > "$OUT_RAW" 2>> "$LOG"
    fi
    EXIT=$?
    ;;
  codex)
    if ! command -v codex >/dev/null 2>&1; then
      echo "$TS: FAILED — codex CLI not found on PATH" >> "$LOG"
      rm -rf "$TMPDIR_REFRESH"
      exit 1
    fi
    if [ -n "$PROJECT_DIR" ] && [ -d "$PROJECT_DIR" ]; then
      ( cd "$PROJECT_DIR" && codex exec - < "$FULL" ) > "$OUT_RAW" 2>> "$LOG"
    else
      codex exec - < "$FULL" > "$OUT_RAW" 2>> "$LOG"
    fi
    EXIT=$?
    ;;
  *)
    echo "$TS: FAILED — unknown STEWARD_RUNTIME=$RUNTIME" >> "$LOG"
    rm -rf "$TMPDIR_REFRESH"
    exit 1
    ;;
esac
DUR=$(( $(date +%s) - START ))

OUT_BYTES=$(wc -c < "$OUT_RAW" 2>/dev/null || echo 0)
echo "$TS: runtime=$RUNTIME exit=$EXIT duration=${DUR}s output=$OUT_BYTES bytes" >> "$LOG"

if [ "$EXIT" -ne 0 ] || [ "$OUT_BYTES" -lt 50 ]; then
  echo "$TS: FAILED — runtime exit $EXIT, output too small" >> "$LOG"
  head -c 400 "$OUT_RAW" >> "$LOG"
  echo "" >> "$LOG"
  rm -rf "$TMPDIR_REFRESH"
  exit 1
fi

# -----------------------------------------------------------
# Extract + validate JSON
# -----------------------------------------------------------
python3 - "$OUT_RAW" "$OUT_JSON" <<'PY' >> "$LOG" 2>&1
import json, re, sys
raw = open(sys.argv[1], 'r', encoding='utf-8').read()
# find the first balanced {...} block
start = raw.find('{')
if start < 0:
    print("no opening brace found")
    sys.exit(2)
depth = 0
end = -1
in_str = False
esc = False
for i, c in enumerate(raw[start:], start=start):
    if in_str:
        if esc:
            esc = False
        elif c == '\\':
            esc = True
        elif c == '"':
            in_str = False
        continue
    if c == '"':
        in_str = True
    elif c == '{':
        depth += 1
    elif c == '}':
        depth -= 1
        if depth == 0:
            end = i + 1
            break
if end < 0:
    print("unbalanced braces")
    sys.exit(3)
blob = raw[start:end]
try:
    data = json.loads(blob)
except Exception as exc:
    print(f"json parse failed: {exc}")
    sys.exit(4)
# minimal schema check
for k in ("today", "done", "if_theres_room"):
    if k not in data:
        print(f"missing required key: {k}")
        sys.exit(5)
json.dump(data, open(sys.argv[2], 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
print("json valid")
PY

if [ ! -s "$OUT_JSON" ]; then
  echo "$TS: FAILED — json extraction did not produce output" >> "$LOG"
  rm -rf "$TMPDIR_REFRESH"
  exit 2
fi

# -----------------------------------------------------------
# Atomic replace — preserve backup
# -----------------------------------------------------------
cp "$PRIORITIES" "$DASH_DIR/priorities.prev.json"
mv "$OUT_JSON" "$PRIORITIES"

TODAY_COUNT=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))['today']))" "$PRIORITIES")
DONE_COUNT=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1])).get('done',[])))" "$PRIORITIES")
echo "$TS: refresh SUCCESS — today=$TODAY_COUNT done=$DONE_COUNT" >> "$LOG"

rm -rf "$TMPDIR_REFRESH"
exit 0

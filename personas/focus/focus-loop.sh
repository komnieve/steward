#!/bin/bash
# Focus loop — runs focus-check every N minutes during work hours, shows dialog only when drifting
# Usage: ./focus-loop.sh [interval_minutes]
# Defaults: every 5 minutes, runs 9am-6pm, kill with: focus-off

FOCUS_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_FILE="$FOCUS_DIR/focus.db"
SCREENSHOT_DIR="$FOCUS_DIR/screenshots"
INTERVAL_MIN=${1:-5}
INTERVAL_SEC=$((INTERVAL_MIN * 60))
DIALOG_PID=""
WORK_START=9   # 9am
WORK_END=18    # 6pm

mkdir -p "$SCREENSHOT_DIR"

# Initialize database
sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS focus_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    active_app TEXT,
    active_window TEXT,
    all_windows TEXT,
    assessment TEXT,
    is_drift INTEGER DEFAULT 0,
    screenshot_path TEXT,
    acknowledged_at TEXT
);"

DRIFT_WINDOW=3600  # 1 hour rolling window in seconds

# Count drifts in the last hour from the database
count_recent_drifts() {
    local cutoff=$(date -v-1H '+%Y-%m-%d %H:%M:%S')
    sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM focus_log WHERE is_drift = 1 AND timestamp > '$cutoff';"
}

echo "[focus] Starting. Every ${INTERVAL_MIN}m, ${WORK_START}:00-${WORK_END}:00. (PID $$)"
echo "[focus] Kill with: focus-off"

cleanup() {
    echo "[focus] $(date '+%H:%M') Stopped."
    [ -n "$DIALOG_PID" ] && kill "$DIALOG_PID" 2>/dev/null
    exit 0
}
trap cleanup SIGTERM SIGINT

while true; do
    # 0. Prune screenshots older than 3 days (privacy + disk hygiene)
    find "$SCREENSHOT_DIR" -name '*.png' -mtime +3 -delete 2>/dev/null

    # 0b. Check work hours
    HOUR=$(date '+%H' | sed 's/^0//')
    if [ "$HOUR" -lt "$WORK_START" ] || [ "$HOUR" -ge "$WORK_END" ]; then
        echo "[focus] $(date '+%H:%M') Outside work hours. Sleeping until ${WORK_START}:00..."
        # Sleep until next work start (rough — just check every 15 min)
        sleep 900
        continue
    fi

    # 1. Check if screen is locked or user is idle (>5 min)
    IDLE_SEC=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
    if [ "${IDLE_SEC:-0}" -gt 300 ]; then
        echo "[focus] $(date '+%H:%M') Skipped — idle ${IDLE_SEC}s"
        sleep "$INTERVAL_SEC"
        continue
    fi

    # 2. Check if previous dialog is still open (unacknowledged)
    if [ -n "$DIALOG_PID" ] && kill -0 "$DIALOG_PID" 2>/dev/null; then
        echo "[focus] $(date '+%H:%M') Skipped — previous dialog still open"
        sleep "$INTERVAL_SEC"
        continue
    fi
    DIALOG_PID=""

    # 3. Capture window context (for logging)
    ACTIVE_INFO=$(osascript -e '
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    set frontWindow to ""
    try
        set frontWindow to name of front window of (first application process whose frontmost is true)
    end try
    return frontApp & " | " & frontWindow
end tell' 2>/dev/null)
    ACTIVE_APP=$(echo "$ACTIVE_INFO" | cut -d'|' -f1 | xargs)
    ACTIVE_WINDOW=$(echo "$ACTIVE_INFO" | cut -d'|' -f2- | xargs)

    ALL_WINDOWS=$(osascript -e '
set output to ""
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    repeat with proc in (every application process whose visible is true)
        set appName to name of proc
        set isFront to ""
        if appName = frontApp then set isFront to " [ACTIVE]"
        try
            repeat with w in (every window of proc)
                set output to output & appName & isFront & " | " & name of w & linefeed
            end repeat
        end try
    end repeat
end tell
return output' 2>/dev/null)

    # 4. Save screenshots of all monitors with timestamp
    SHOT_TS=$(date '+%Y%m%d-%H%M%S')
    SHOT_PATH="$SCREENSHOT_DIR/focus-${SHOT_TS}"
    screencapture -x -D1 "${SHOT_PATH}-1.png" 2>/dev/null
    screencapture -x -D2 "${SHOT_PATH}-2.png" 2>/dev/null
    screencapture -x -D3 "${SHOT_PATH}-3.png" 2>/dev/null

    # 5. Count drifts in last hour (from database — survives restarts)
    RECENT_DRIFTS=$(count_recent_drifts)
    ESCALATION=$((RECENT_DRIFTS + 1))
    [ "$ESCALATION" -gt 5 ] && ESCALATION=5

    # 6. Run focus check with escalation level.
    #    Stderr goes to focus-loop.err; a non-zero exit (2 = runtime
    #    misconfigured, 1 = screenshot failure) is a failed check, NOT
    #    an "on track" tick — surface it, skip db logging, try again.
    RESULT=$("$FOCUS_DIR/focus-check.sh" "$ESCALATION" 2>"$FOCUS_DIR/focus-loop.err")
    CHECK_RC=$?
    if [ "$CHECK_RC" -ne 0 ]; then
        echo "[focus] $(date '+%H:%M') check failed (rc=$CHECK_RC) — see focus-loop.err"
        sleep "$INTERVAL_SEC"
        continue
    fi

    # 7. Determine if on-track (strip whitespace, backticks, dashes-only)
    CLEAN=$(echo "$RESULT" | tr -d '`' | xargs)
    IS_DRIFT=0
    if [ -z "$CLEAN" ] || echo "$CLEAN" | grep -qE '^-+$'; then
        echo "[focus] $(date '+%H:%M') On track."
        CLEAN="on track"
    elif echo "$CLEAN" | grep -qiE '^WALK$'; then
        IS_DRIFT=1
        echo "[focus] $(date '+%H:%M') Walk intervention ($((RECENT_DRIFTS + 1)) drifts in last hour)"
        osascript -e 'display dialog "Close the laptop. Take a walk. Come back when you'\''re ready." with title "🚶" buttons {"Going for a walk"} default button 1 with icon note' &>/dev/null &
        DIALOG_PID=$!
        CLEAN="walk"
    else
        IS_DRIFT=1
        HOURLY_COUNT=$((RECENT_DRIFTS + 1))
        echo "[focus] $(date '+%H:%M') Drift ($HOURLY_COUNT in last hour, level $ESCALATION): $CLEAN"

        # Button text shifts with escalation
        case $ESCALATION in
            1|2) BTN="Back to it" ;;
            3)   BTN="I see it" ;;
            4)   BTN="What do I need?" ;;
            *)   BTN="Going for a walk" ;;
        esac

        # Pass dynamic strings as argv — drift messages contain quoted text,
        # and interpolating them into AppleScript source breaks the dialog.
        osascript \
            -e 'on run argv' \
            -e 'display dialog (item 1 of argv) with title "🔔" buttons {item 2 of argv} default button 1 with icon note' \
            -e 'end run' \
            "$CLEAN" "$BTN" &>/dev/null &
        DIALOG_PID=$!
    fi

    # 7. Log to database
    NOW=$(date '+%Y-%m-%d %H:%M:%S')
    sqlite3 "$DB_FILE" "INSERT INTO focus_log (timestamp, active_app, active_window, all_windows, assessment, is_drift, screenshot_path)
        VALUES ('$NOW', '$(echo "$ACTIVE_APP" | sed "s/'/''/g")', '$(echo "$ACTIVE_WINDOW" | sed "s/'/''/g")', '$(echo "$ALL_WINDOWS" | sed "s/'/''/g")', '$(echo "$CLEAN" | sed "s/'/''/g")', $IS_DRIFT, '$SHOT_PATH');"

    sleep "$INTERVAL_SEC"
done

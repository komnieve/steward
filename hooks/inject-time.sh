#!/bin/bash
# Time context injection hook for Claude Code
# Fires on every UserPromptSubmit, injecting temporal metadata
# so the model never has to guess what time it is.
#
# Setup: Register this hook in ~/.claude/settings.json under hooks.UserPromptSubmit
# See templates/settings.json for the exact configuration.

# Consume stdin (hook input — not needed here but must be read)
cat > /dev/null

NOW_EPOCH=$(date +%s)
NOW_ISO=$(date '+%Y-%m-%dT%H:%M:%S%z')
NOW_LOCAL=$(date '+%Y-%m-%d %H:%M %Z')
WEEKDAY=$(date '+%A')
# Timezone: /etc/localtime symlink works on macOS and most Linux; timedatectl is
# Linux-only; $TZ is the last resort.
TZ_IANA=$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')
[ -n "$TZ_IANA" ] || TZ_IANA=$(timedatectl show -p Timezone --value 2>/dev/null || echo "${TZ:-unknown}")

# Interactive = a human is at the keyboard. Headless sessions (launchd/cron
# steward runs) have no terminal, so /dev/tty won't open — they may read the
# clock but must not reset it, or automated runs would fake human activity.
INTERACTIVE="false"
if ( : < /dev/tty ) 2>/dev/null; then
    INTERACTIVE="true"
elif [ -n "${TERM:-}" ] && [ "$TERM" != "dumb" ]; then
    # Some hook harnesses don't attach /dev/tty even in interactive sessions;
    # fall back to TERM: terminal-launched sessions inherit it, launchd/cron
    # environments don't set it.
    INTERACTIVE="true"
fi

# Calculate elapsed time since last prompt
TIMESTAMP_FILE="$HOME/.claude/.last-prompt-timestamp"
ELAPSED_DISPLAY=""
DATE_CHANGED=""

if [ -f "$TIMESTAMP_FILE" ]; then
    LAST_EPOCH=$(cat "$TIMESTAMP_FILE")
    ELAPSED=$((NOW_EPOCH - LAST_EPOCH))
    # BSD (macOS) date first, GNU fallback — `date -d @epoch` is GNU-only and
    # silently failing here made date_changed read "true" on every prompt.
    LAST_DATE=$(date -r "$LAST_EPOCH" '+%Y-%m-%d' 2>/dev/null || date -d "@$LAST_EPOCH" '+%Y-%m-%d' 2>/dev/null)
    NOW_DATE=$(date '+%Y-%m-%d')

    if [ "$ELAPSED" -lt 60 ]; then
        ELAPSED_DISPLAY="${ELAPSED}s"
    elif [ "$ELAPSED" -lt 3600 ]; then
        ELAPSED_DISPLAY="$((ELAPSED / 60))m"
    elif [ "$ELAPSED" -lt 86400 ]; then
        ELAPSED_DISPLAY="$((ELAPSED / 3600))h $((ELAPSED % 3600 / 60))m"
    else
        ELAPSED_DISPLAY="$((ELAPSED / 86400))d $((ELAPSED % 86400 / 3600))h"
    fi

    # Only meaningful when we could compute LAST_DATE on this platform.
    if [ -n "$LAST_DATE" ]; then
        if [ "$LAST_DATE" != "$NOW_DATE" ]; then
            DATE_CHANGED="true"
        else
            DATE_CHANGED="false"
        fi
    fi
fi

# Write current timestamp for next calculation — interactive sessions only, so
# the since-last-prompt clock always measures from the last *human* prompt.
if [ "$INTERACTIVE" = "true" ]; then
    echo "$NOW_EPOCH" > "$TIMESTAMP_FILE"
fi

# Get last activity from activity.db for gap awareness.
# Prefer $STEWARD_HOME/activity.db; fall back to legacy ~/.claude/activity.db for
# users still running the older layout.
LAST_ACTIVITY=""
ACTIVITY_DB="${STEWARD_HOME:-$HOME/.steward}/activity.db"
if [ ! -f "$ACTIVITY_DB" ] && [ -f "$HOME/.claude/activity.db" ]; then
    ACTIVITY_DB="$HOME/.claude/activity.db"
fi
if [ -f "$ACTIVITY_DB" ]; then
    LAST_ACTIVITY=$(sqlite3 "$ACTIVITY_DB" \
        "SELECT timestamp || ' | ' || activity FROM activity_log ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null)
fi

# Output — this gets injected into Claude's context
echo "<user-prompt-submit-hook>"
echo "now: $NOW_ISO"
echo "local: $NOW_LOCAL"
echo "weekday: $WEEKDAY"
echo "timezone: $TZ_IANA"
if [ -n "$ELAPSED_DISPLAY" ]; then
    echo "since_last_prompt: $ELAPSED_DISPLAY"
    [ -n "$DATE_CHANGED" ] && echo "date_changed: $DATE_CHANGED"
fi
if [ -n "$LAST_ACTIVITY" ]; then
    echo "last_activity: $LAST_ACTIVITY"
fi
echo "</user-prompt-submit-hook>"

exit 0

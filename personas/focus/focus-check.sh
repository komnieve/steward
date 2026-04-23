#!/bin/bash
# Focus check — two-tier assessment: Haiku describes screens, Opus judges intent
# Usage: ./focus-check.sh [escalation_level]
# Returns a short focus assessment to stdout

FOCUS_DIR="$(cd "$(dirname "$0")" && pwd)"
STEWARD_HOME="${STEWARD_HOME:-$(cd "$FOCUS_DIR/../.." && pwd)}"
STATUS_FILE="${STEWARD_STATUS_MD:-}"
PRIORITIES_FILE="${STEWARD_PRIORITIES:-$STEWARD_HOME/focus-dash/priorities.json}"
SHOT_TS=$(date +%s)
SCREENSHOT_1="/tmp/focus-check-${SHOT_TS}-1.png"
SCREENSHOT_2="/tmp/focus-check-${SHOT_TS}-2.png"
SCREENSHOT_3="/tmp/focus-check-${SHOT_TS}-3.png"

# 1. Capture all three monitors (silent)
screencapture -x -D1 "$SCREENSHOT_1" 2>/dev/null
screencapture -x -D2 "$SCREENSHOT_2" 2>/dev/null
screencapture -x -D3 "$SCREENSHOT_3" 2>/dev/null

# Build screenshot reference for prompt
SHOT_REFS=""
for f in "$SCREENSHOT_1" "$SCREENSHOT_2" "$SCREENSHOT_3"; do
    [ -f "$f" ] && SHOT_REFS="$SHOT_REFS $f"
done

if [ -z "$SHOT_REFS" ]; then
    echo "ERROR: Screenshot failed"
    exit 1
fi

# 2. Get active window context (authoritative, more reliable than image recognition)
ACTIVE_APP=$(osascript -e '
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    set frontWindow to ""
    try
        set frontWindow to name of front window of (first application process whose frontmost is true)
    end try
    return frontApp & " | " & frontWindow
end tell' 2>/dev/null)

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

# 3. Read today's priorities.
#    Prefer focus-dash priorities.json (structured + authoritative).
#    Fall back to STEWARD_STATUS_MD P0 section if set.
PRIORITIES=""
if [ -f "$PRIORITIES_FILE" ]; then
    PRIORITIES=$(python3 -c "
import json, sys
try:
    d = json.load(open('$PRIORITIES_FILE'))
    out = []
    ns = d.get('northstar', {})
    if ns.get('text'):
        out.append(f\"Northstar ({ns.get('horizon','')}):\\n  {ns['text']}\")
    today = d.get('today', [])
    if today:
        out.append('Today:')
        for it in today:
            out.append(f\"  - {it.get('title','')}: {it.get('context','')}\")
    room = d.get('if_theres_room', [])
    if room:
        out.append('If there is room:')
        for it in room[:5]:
            out.append(f\"  - {it.get('title','')}\")
    print('\\n'.join(out))
except Exception as e:
    print(f'(priorities unreadable: {e})', file=sys.stderr)
" 2>/dev/null)
fi
if [ -z "$PRIORITIES" ] && [ -n "$STATUS_FILE" ] && [ -f "$STATUS_FILE" ]; then
    PRIORITIES=$(awk '/^## P0/{flag=1; next} /^## |^---/{flag=0} flag' "$STATUS_FILE")
fi

CURRENT_TIME=$(date '+%I:%M%p %A')

# 4. Get escalation level (passed as first argument, default 1)
ESCALATION=${1:-1}

# 4b. Get active Claude Code sessions (what's being worked on right now).
#     Derives the transcript dir from STEWARD_PROJECT_ROOT — Claude Code's
#     transcript convention is to encode the cwd path as "-Users-foo-bar"
#     style. Skipped silently if the runtime isn't claude-code.
SESSIONS_DIR="$HOME/.claude/sessions"
ACTIVE_SESSIONS=""
PROJECT_ROOT_FOR_TRANSCRIPTS="${STEWARD_PROJECT_ROOT:-}"
if [ -d "$SESSIONS_DIR" ] && [ -n "$PROJECT_ROOT_FOR_TRANSCRIPTS" ]; then
    export PROJECT_ROOT_FOR_TRANSCRIPTS
    ACTIVE_SESSIONS=$(python3 << 'PYEOF'
import json, os, glob

sessions_dir = os.path.expanduser("~/.claude/sessions")
project_root = os.environ.get("PROJECT_ROOT_FOR_TRANSCRIPTS", "")
# Claude Code transcript-dir convention: "/Users/foo/bar" -> "-Users-foo-bar"
transcripts_dir = ""
if project_root:
    encoded = project_root.replace("/", "-")
    transcripts_dir = os.path.expanduser(f"~/.claude/projects/{encoded}")

def pid_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, PermissionError):
        return False

results = []
for sf in glob.glob(os.path.join(sessions_dir, "*.json")):
    try:
        with open(sf) as f:
            sess = json.load(f)
        pid = sess.get("pid", 0)
        if not pid_alive(pid):
            continue
        sid = sess.get("sessionId", "")
        cwd = sess.get("cwd", "")

        # Get last 3 user messages from transcript
        jsonl_path = os.path.join(transcripts_dir, f"{sid}.jsonl")
        recent_msgs = []
        if os.path.exists(jsonl_path):
            with open(jsonl_path, "rb") as f:
                f.seek(0, 2)
                size = f.tell()
                chunk = min(size, 200000)
                f.seek(size - chunk)
                lines = f.read().decode("utf-8", errors="replace").strip().split("\n")

            for line in reversed(lines):
                if len(recent_msgs) >= 3:
                    break
                try:
                    obj = json.loads(line)
                    if obj.get("type") != "user":
                        continue
                    msg = obj.get("message", {})
                    content = msg.get("content", "")
                    if isinstance(content, list):
                        content = " ".join(c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text")
                    if isinstance(content, str):
                        content = content.strip()
                        if content.startswith("<local-command") or content.startswith("<command-") or "<system-reminder>" in content[:200]:
                            continue
                        if len(content) < 10:
                            continue
                        if len(content) > 200:
                            content = content[:200] + "..."
                        recent_msgs.append(content)
                except (json.JSONDecodeError, KeyError):
                    pass

        recent_msgs.reverse()
        cwd_short = cwd.replace(os.path.expanduser("~/"), "~/")
        session_text = f"Session (PID {pid}, {cwd_short}):"
        if recent_msgs:
            for m in recent_msgs:
                session_text += f"\n  - {m}"
        else:
            session_text += "\n  (no recent messages)"
        results.append(session_text)

if results:
    print("\n".join(results))
else:
    print("(no active sessions)")
PYEOF
    )
fi

# ============================================================
# TIER 1: Haiku — fast vision pass, just describe what's on screen
# ============================================================
HAIKU_PROMPT="Describe what you see on each monitor screenshot. For each screen, note:
- What application/website is visible
- What specific content is shown (page titles, feed names, video titles, article headlines, code, email subjects, etc.)
- What the user appears to be doing (reading, writing, browsing a feed, watching video, coding, etc.)

Be factual and specific. Do not judge or assess — just describe. Keep it concise, 2-3 lines per monitor."

SCREEN_DESC=$(claude -p "$HAIKU_PROMPT" \
    $SHOT_REFS \
    --model claude-haiku-4-5-20251001 \
    --max-turns 1 \
    2>/dev/null)

# ============================================================
# TIER 2: Opus — deep judgment with full context + CLAUDE.md persona
# ============================================================

# Pick 8 random quotes from quotes.md so the model always has fresh material
# (with --max-turns 1 it can't read the file itself)
QUOTES_FILE="$FOCUS_DIR/quotes.md"
QUOTE_ROTATION=""
if [ -f "$QUOTES_FILE" ]; then
    QUOTE_ROTATION=$(grep '^\- \*"' "$QUOTES_FILE" | sort -R | head -8)
fi

OPUS_PROMPT="It is $CURRENT_TIME.

ESCALATION_LEVEL: $ESCALATION

ACTIVE WINDOW (frontmost app — this is authoritative):
$ACTIVE_APP

ALL VISIBLE WINDOWS:
$ALL_WINDOWS

SCREEN DESCRIPTIONS (from vision analysis of all monitors):
$SCREEN_DESC

ACTIVE AGENT SESSIONS (what the user is actively working on right now):
$ACTIVE_SESSIONS

TODAY'S PRIORITIES:
$PRIORITIES

QUOTES ROTATION (use one of these — they rotate each check):
$QUOTE_ROTATION

FIRST: Assess whether the user is on track or drifting. Use the priorities above to know what counts as work. Any screen activity plausibly related to a listed priority or to the northstar is work. The active agent sessions above show what's currently being worked on — use that to resolve ambiguity.

If the user is on track or it's ambiguous: output exactly -- (two dashes, nothing else). Do this REGARDLESS of the ESCALATION_LEVEL. When in doubt, assume work.

If and ONLY if the user is genuinely drifting (clearly non-work social-feed scrolling, entertainment, news rabbit holes with no work connection): respond following the tone guidance in your CLAUDE.md for the given ESCALATION_LEVEL. IMPORTANT: Every drift message at EVERY level must include a quote or practice-line from the QUOTES ROTATION above. Weave it naturally — a bell before the question."

RESULT=$(cd "$FOCUS_DIR" && echo "$OPUS_PROMPT" | claude -p \
    --allowedTools "Read" \
    --model claude-opus-4-6 \
    --max-turns 1 \
    2>/dev/null)

echo "$RESULT"

# Cleanup
rm -f "$SCREENSHOT_1" "$SCREENSHOT_2" "$SCREENSHOT_3"

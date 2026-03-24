#!/bin/bash
# Extracts and summarizes today's Claude conversation transcripts
# Uses Haiku for fast, cheap summarization
# Output: a comprehensive summary of what was discussed and accomplished
#
# Usage: steward-summarize-sessions.sh <output-file>
#
# CUSTOMIZE: Update the project_dir path in the Python script below to match
# your Claude Code projects directory.

set -euo pipefail

OUTPUT="${1:-/tmp/session-summary.md}"
CLAUDE="${CLAUDE_BIN:-claude}"
EXTRACT_FILE="/tmp/steward-transcript-extract.txt"
PROMPT_FILE="/tmp/steward-summary-prompt.txt"

# Extract user + assistant text from today's sessions into a file
# CUSTOMIZE: Update the project_dir path below
python3 << 'PYEOF' > "$EXTRACT_FILE"
import json, os, glob
from datetime import datetime

# CUSTOMIZE: This should point to your Claude Code project's session directory
# It's typically: ~/.claude/projects/-<path-with-dashes>/
project_dir = os.path.expanduser("~/.claude/projects/")

# Find all project subdirectories and look for JSONL files
today = datetime.now().strftime("%Y-%m-%d")
today_files = []

for root, dirs, files in os.walk(project_dir):
    for f in files:
        if f.endswith(".jsonl"):
            filepath = os.path.join(root, f)
            mtime = os.path.getmtime(filepath)
            mdate = datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")
            if mdate == today:
                today_files.append((mtime, filepath))

today_files.sort()  # chronological order

for mtime, filepath in today_files:
    size = os.path.getsize(filepath)
    if size < 5000:  # skip tiny sessions (steward runs, etc)
        continue

    sid = os.path.basename(filepath).replace(".jsonl", "")[:8]
    print(f"\n--- Session {sid} ({size // 1024}KB) ---\n")

    with open(filepath) as fh:
        for line in fh:
            try:
                obj = json.loads(line)
                msg_type = obj.get("type", "")

                if msg_type == "user":
                    msg = obj.get("message", {})
                    if isinstance(msg, dict):
                        content = msg.get("content", "")
                        if isinstance(content, str) and len(content.strip()) > 10:
                            if content.startswith("<local-command") or content.startswith("<command-"):
                                continue
                            if "<task-notification>" in content:
                                continue
                            if "<system-reminder>" in content and len(content.strip()) < 500:
                                continue
                            text = content.strip()
                            if len(text) > 2000:
                                text = text[:2000] + "\n[...truncated...]"
                            print(f"USER: {text}\n")
                        elif isinstance(content, list):
                            for c in content:
                                if isinstance(c, dict) and c.get("type") == "text":
                                    text = c.get("text", "").strip()
                                    if len(text) > 10 and not text.startswith("<local-command") and not text.startswith("<command-") and "<task-notification>" not in text:
                                        if "<system-reminder>" in text and len(text) < 500:
                                            continue
                                        if len(text) > 2000:
                                            text = text[:2000] + "\n[...truncated...]"
                                        print(f"USER: {text}\n")

                elif msg_type == "assistant":
                    msg = obj.get("message", {})
                    if isinstance(msg, dict):
                        content = msg.get("content", "")
                        if isinstance(content, str) and len(content.strip()) > 10:
                            text = content.strip()
                            if len(text) > 1500:
                                text = text[:1500] + "\n[...truncated...]"
                            print(f"CLAUDE: {text}\n")
                        elif isinstance(content, list):
                            for c in content:
                                if isinstance(c, dict) and c.get("type") == "text":
                                    text = c.get("text", "").strip()
                                    if len(text) > 10:
                                        if len(text) > 1500:
                                            text = text[:1500] + "\n[...truncated...]"
                                        print(f"CLAUDE: {text}\n")
            except (json.JSONDecodeError, KeyError):
                pass
PYEOF

# Check if we got anything
EXTRACT_SIZE=$(wc -c < "$EXTRACT_FILE")
if [ "$EXTRACT_SIZE" -lt 100 ]; then
    echo "No substantial conversation transcripts found for today." > "$OUTPUT"
    exit 0
fi

# Build prompt file (avoids ARG_MAX)
cat > "$PROMPT_FILE" << 'PROMPTEOF'
You are reviewing today's Claude Code conversation transcripts for a daily steward briefing. Summarize comprehensively:

1. WHAT WAS DISCUSSED — every topic, in order
2. WHAT WAS ACCOMPLISHED — concrete outputs (files created, emails sent, calls made, decisions reached)
3. WHAT WAS DECIDED — key decisions and their rationale
4. WHAT'S PENDING — things started but not finished, things promised for later
5. EMOTIONAL STATE — any signals about energy, mood, struggle, wins

Be thorough. Don't limit yourself to 10 lines — capture everything meaningful. This summary is the steward's primary window into what actually happened today.

Here are the transcripts:

PROMPTEOF

# Append transcript to prompt file
cat "$EXTRACT_FILE" >> "$PROMPT_FILE"

# Truncate if too large (Haiku context is ~200K tokens, ~150K chars is safe)
PROMPT_SIZE=$(wc -c < "$PROMPT_FILE")
if [ "$PROMPT_SIZE" -gt 150000 ]; then
    head -c 150000 "$PROMPT_FILE" > "${PROMPT_FILE}.tmp"
    echo -e "\n\n[...transcripts truncated for length...]" >> "${PROMPT_FILE}.tmp"
    mv "${PROMPT_FILE}.tmp" "$PROMPT_FILE"
fi

# Use Haiku for speed/cost, pipe via stdin to avoid ARG_MAX
# unset CLAUDECODE to allow nested invocation
unset CLAUDECODE
cat "$PROMPT_FILE" | $CLAUDE -p --model claude-haiku-4-5-20251001 --max-turns 1 > "$OUTPUT" 2>/dev/null

# Report
LINES=$(wc -l < "$OUTPUT")
echo "Session summary generated: $LINES lines"

# Cleanup
rm -f "$EXTRACT_FILE" "$PROMPT_FILE"

# The Steward — Autonomous Check-in System

> **⚠️ LEGACY DOC — pre-v0.2 architecture.** This guide describes the original `~/.claude/`-based Signal-delivery steward. The current runner lives at `scripts/daily-check.sh` and is runtime-pluggable (Claude Code / Codex) and delivery-pluggable (terminal / Slack webhook / …). Paths shown here as `~/.claude/*` now live under `~/.steward/`.
>
> **For current docs see:** [`guides/getting-started.md`](getting-started.md), [`guides/runtimes.md`](runtimes.md), [`guides/delivery-slack.md`](delivery-slack.md).
>
> Kept here as a snapshot of the original design intent. Will be folded into the current guides or removed in a future cleanup.

---

The steward is an autonomous agent run that runs on a schedule, reads all your project files, and sends you an honest assessment via your configured delivery channel. It has no memory between runs — it re-reads everything from scratch each time. This is a feature, not a limitation: there's no hidden state, no drift, no stale assumptions.

## How It Works

```
Cron triggers script (9am / 6pm)
    |
    v
Script reads steward-persona.md
Script queries activity.db for recent work
    |
    v
Script builds a prompt combining:
  - Persona (who you are, how to review)
  - Activity log (recent work events)
  - Time-specific instructions (morning vs evening)
    |
    v
claude -p runs headless with the prompt
  - Reads work/status.md
  - Reads project files in work/
  - Checks git log
  - Forms assessment
  - Outputs plain text message
    |
    v
Script extracts message from Claude's output
  - Filters errors, empty output
  - Strips tool-use artifacts
  - Handles "SKIP" (nothing to report)
    |
    v
signal-cli sends message to your phone
```

## The Two Reviews

### Morning (9am) — "What deserves energy today?"
- Reads last 3 days of activity + git
- Identifies the highest-leverage move for today
- Flags anything slipping or overdue
- Checks deadlines in the next 7 days
- Detects multi-day drift or paralysis patterns
- Ends with one clear recommendation

### Evening (6pm) — "What actually happened?"
- Reads today's activity + git
- Compares what was planned against what got done
- Shows weekly hours + breakdown by project
- Recognizes streaks (productive or stuck)
- Identifies tomorrow's priority
- Calls for rest if pace is unsustainable

## Key Design Decisions

### No memory between runs
The steward reads from files every time. This means:
- Your `work/status.md` MUST be current (most common failure mode)
- There's no "ghost state" — what the steward knows is exactly what's in the files
- If the steward gives a wrong assessment, the fix is always in the files

### The persona is the behavior
All steward behavior is controlled by `~/.claude/steward-persona.md`. Want it more direct? Edit the persona. Want it to check different files? Edit the persona. Want it to focus on different priorities? Edit the persona. The scripts don't contain review logic — they just orchestrate the Claude call and deliver the message.

### SKIP gate
If the steward has nothing useful to say, it outputs "SKIP" and no message is sent. This prevents noise — you only get messages when there's something worth saying.

### Error filtering
The scripts filter out API errors, empty output, and Claude's tool-use artifacts (which appear in stdout when using `claude -p`). The message extraction uses the last `---` separator as a boundary, then strips known preamble patterns.

### `unset CLAUDECODE`
This prevents the headless Claude instance from detecting it's inside another Claude Code session (which would cause it to refuse to run). Critical for cron execution.

## Customizing the Persona

The persona file has these sections — customize each:

1. **Who you are** — Context about your work, projects, people, patterns. The more honest and specific, the better the advice.

2. **Your Job (sections 1-5)** — What the steward should read, check, and recommend. Add or remove file paths, change the review focus, adjust what "trajectory" means for your work.

3. **Your Voice** — How the steward communicates. Some people want bullet points. Some want paragraphs. Some want gentle nudges. Some want blunt truth. Set the tone here.

4. **What NOT to Do** — Anti-patterns to prevent. If the steward keeps doing something unhelpful, add it here.

## Debugging

All output is logged to `~/.claude/cron.log`. When something isn't working:

```bash
# See recent log entries
tail -100 ~/.claude/cron.log

# Run the morning check manually
bash ~/.claude/daily-check.sh

# Test just the Claude call (without Signal)
claude -p "$(cat ~/.claude/steward-persona.md)" \
  --allowedTools "Read,Glob,Grep,Bash" \
  --max-turns 10 \
  -d /path/to/your/project
```

Common issues:
- **Empty messages**: Usually means `status.md` is missing or the persona file path is wrong
- **API errors**: Rate limits or authentication. Check that `claude` works interactively first.
- **Cron not firing**: On WSL2, cron only runs when WSL is active. Check `service cron status`.
- **Message garbled**: The output parsing assumes `---` separators. If Claude's output format changes, the extraction logic may need updating.

## Cost Considerations

Each steward run uses ~25 Claude turns (reading files, forming assessment). At current pricing, this is roughly:
- 2 runs/day x ~25 turns x ~$0.01-0.05/turn = ~$0.50-2.50/day
- Monthly: ~$10-50 depending on how many files the steward reads

You can reduce costs by:
- Lowering `--max-turns` (10 is usually enough if your files are well-organized)
- Reducing the number of files the persona tells it to read
- Running once/day instead of twice

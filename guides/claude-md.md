# CLAUDE.md — Project Instructions Guide

CLAUDE.md is the file Claude Code reads at the start of every session. It's the single most important file in the system — it defines how Claude behaves, what it knows about you, and how the whole operating system works.

## Where It Lives

Claude Code looks for instructions in this order (all are loaded, later ones can override):
1. `~/.claude/CLAUDE.md` — global (applies to all projects)
2. `<project-root>/CLAUDE.md` — project-specific (checked into git)
3. `<project-root>/.claude/settings.local.json` — local overrides (not checked in)

For the steward system, most configuration goes in the **project-level** CLAUDE.md.

## Key Sections

### Session Start Ritual
Tells Claude what to read and do at the beginning of every session. This is critical for continuity — Claude has no memory between sessions, so the ritual reconstructs context.

```markdown
## Session Start Ritual
Every session, do the following:
1. Read these files: [list of files]
2. Show status snapshot: for each active project show Now/Next/Blocked
3. Propose top 1-3 actions; ask for confirmation
```

### Who You Are
The most impactful section. Tell Claude:
- What you're working on and why
- How you work best (structured sessions? open exploration?)
- Known patterns (avoidance, overcommitting, perfectionism)
- What kind of accountability works for you
- Life context that affects capacity

This isn't a resume. It's operational self-knowledge. The more honest you are, the better Claude's advice.

### Information Architecture
Defines the three-layer tracking system (status.md, activity.db, git log) and how they relate. This section tells Claude how to update each layer during sessions.

### Execution Culture
Sets the tone for how Claude holds you accountable. The template includes language like "care IS follow-through" and specific behaviors (tracking commitments, naming stalled work, pulling back from brainstorming to shipping). Adjust to match what works for you.

### Transcription Corrections
If you use voice input, a quick-reference table of common errors lets Claude auto-correct without you having to spell things out every time.

### Terminology
Project-specific vocabulary, people's names, abbreviations. Claude reads this every session and uses it for context.

## Tips for Effective CLAUDE.md Files

1. **Be specific, not abstract.** "Name stalled work directly" is better than "hold me accountable."

2. **Update it.** CLAUDE.md should evolve as your projects and patterns change. It's not a one-time setup.

3. **Don't over-engineer.** Start with the template, use it for a week, then adjust based on what's actually helpful.

4. **Reference other files.** CLAUDE.md should point to detailed files rather than containing everything. "See work/status.md for project state" keeps it manageable.

5. **Include guardrails.** "Ask before destructive actions" and "never fabricate facts" prevent costly mistakes.

## Relationship to the Steward

The steward persona file (`~/.steward/persona.md`) is separate from CLAUDE.md. CLAUDE.md governs interactive sessions. The steward persona governs autonomous check-ins. They share the same project files (status.md, activity.db, git log) but serve different purposes:

- **CLAUDE.md**: "How should you behave when I'm working with you?"
- **Steward persona**: "How should you assess my work when I'm not here?"

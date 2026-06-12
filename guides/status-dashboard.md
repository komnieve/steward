# Status Dashboard Guide

## Why This Matters

`~/.steward/status.md` is the **single most important file** in the steward system. (If you keep a separate project repo, a `work/status.md` there is an optional convention some setups use — the scaffold created by setup lives at `~/.steward/status.md`.) The autonomous steward reads it cold every morning and evening with zero memory of prior runs. If this file is stale or inaccurate, the steward will:
- Nag you about things already done
- Miss things that changed
- Give recommendations based on outdated information
- Erode your trust in the system

Keeping status.md current is the one non-negotiable maintenance task.

## Structure

The file has three sections:

### 1. Deadlines
Hard dates that will expire or be missed. Only include real deadlines — not aspirational targets.

```markdown
## Deadlines

| Date | Item | Project |
|------|------|---------|
| **Mar 30** | China patent response due | Patent |
| **Apr 15** | Tax filing deadline | Admin |
```

- Remove or strikethrough when passed
- Update if dates change
- Include enough context for the steward to understand urgency

### 2. Active Projects
Living status of every open thread, organized by project. This is STATE, not history.

```markdown
### Project Name
| Thread | Status | Next Action |
|--------|--------|-------------|
| Feature X | In progress — auth module done, API pending | Build API endpoints |
| Client onboarding | Blocked — waiting on credentials | Follow up Friday |
| Marketing site | Shipped Feb 26 | Done |
```

For each thread:
- **Thread**: A named piece of work (specific enough to track)
- **Status**: Current state — be precise. Not "in progress" but "auth module done, API pending"
- **Next Action**: The specific next step. Not "continue work" but "Build API endpoints"

### 3. Work Log
Permanent record of accomplishments, organized by week/month. This section grows over time and is never trimmed.

```markdown
## Work Log

### March 2026

**Week of Mar 3-7**
- Shipped auth module to production
- Client sync call — agreed on Q2 roadmap
- Fixed deployment pipeline (was failing on ARM builds)
```

One line per accomplishment. Concrete. Answer "what did I get done this week?" and this section should answer it clearly.

## Update Discipline

### When to update
- **Every session** — update status.md during interactive sessions when threads change state
- When a thread starts, ships, gets blocked, or gets killed
- When a deadline passes or changes
- When a new thread opens
- When a significant decision is made

### Session instruction
Include this in your runtime's session-instructions file (`CLAUDE.md`, `AGENTS.md`, etc.):

> "Update ~/.steward/status.md every session — especially when threads change state (started, shipped, blocked, killed). The steward reads this file cold with no memory."

### Common failure modes

1. **"Finish loose ends"** stays on the list for a week after the work is done → steward nags about it
2. Thread says "in progress" but hasn't moved in two weeks → steward can't distinguish stalled from active
3. Deadline passes but isn't updated → steward treats it as still upcoming
4. New work starts but isn't added → steward doesn't know about it

## Tips

- **Be honest about status.** "Stalled — haven't touched this in a week" is better than "in progress" for something that isn't moving. The steward can help with stalled work; it can't help if it thinks things are moving.

- **Kill threads.** If something has been sitting for weeks and you're not going to do it, mark it as killed. Zombie threads clutter the dashboard and dilute the steward's focus.

- **Keep next actions specific.** "Email John about pricing by Friday" is actionable. "Follow up" is not.

- **Separate state from history.** Active Projects = current state (changes constantly). Work Log = permanent record (only grows). Don't put history in the Active section or current state in the Work Log.

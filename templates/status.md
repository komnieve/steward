# Status Dashboard

**Last updated**: [DATE]

---

## Deadlines

| Date | Item | Project |
|------|------|---------|
| **[DATE]** | [What's due] | [Project] |

---

## Active Projects

### [Project Name]
| Thread | Status | Next Action |
|--------|--------|-------------|
| [Thread name] | [Current state] | [What needs to happen next] |

<!--
Add more project sections as needed.
Each thread should have:
- A clear name
- Current status (In progress / Blocked / Shipped / Killed)
- The specific next action (not vague — "Email John re: pricing" not "Follow up")

Update this EVERY SESSION. The steward reads this file cold with no memory.
If this file is stale, the steward gives wrong advice.
-->

---

## Work Log

Permanent record. One line per accomplishment. Ask "what did I get done this week/month?" and this answers it.

### [Month Year]

**Week of [Date Range]**
- [What you accomplished]
- [What you shipped]
- [Key decisions made]

---

## How This File Works

**This file is the steward's primary source of truth.** The steward reads this file cold every morning and evening with zero memory of prior runs. If this file is stale, the steward gives wrong assessments.

- **Claude updates this every session** — especially when threads change state (started, shipped, blocked, killed)
- **Deadlines** section: hard dates only — things that will expire or be missed. Remove or update when they pass.
- **Active Projects**: living status of every open thread, organized by project. This is STATE, not history.
- **Work Log**: permanent, organized by week/month. Never trimmed. Answers "what did I get done?"

**Relationship to other data stores:**
- `~/.steward/activity.db` captures **events** (what happened, how long) — the steward reads this too, but it doesn't capture state changes
- Git log captures **code commits** — the steward reads this too
- Status.md is what the steward trusts for "where do things stand"

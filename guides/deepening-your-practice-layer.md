# Deepening your Practice Layer

*How the Practice Layer components actually show up through a working day, and how the agent you run becomes a partner in deepening practice rather than a productivity tool.*

---

## The core idea

Most agents are optimization machines. You ask for a thing, they produce a thing. The output gets better; you don't.

The Practice Layer points at a different possibility: **your agent as a partner in who you're becoming, not just what you're producing.** That's only possible if the agent holds context about your practice, your values, your patterns — and surfaces them at the moments when it matters.

This guide shows what that looks like concretely. It uses the [`contemplative-practitioner`](../practice-layer/examples/contemplative-practitioner/) example for illustration, but the shape generalizes. If you're writing your own Practice Layer (from templates or a different example), the same rhythms apply.

---

## A day with a deep Practice Layer loaded

### Morning — setting intention

You open an agent session. The agent has read your `practice/*.md` files and your `status.md`. You type something simple:

> *"What should I focus on today?"*

A generic agent returns a prioritized task list. An agent with your Practice Layer loaded does something different. It might ask back:

> *"Before I answer — what's the intention you want to bring to today? You've been in a week of Tier-2 work; one Tier-1 move could shift the week. But I notice you're light on sleep and today's calendar is heavy. What would be wholesome here?"*

That's not productivity advice. That's a partner who has read your `wholesome-intention.md`, noticed a drift pattern from your `work-as-practice.md`, and gently surfaced the practice-level question without reciting the files back at you.

### Mid-morning — hitting a block

You've been at the same task for 40 minutes and the screen is full of half-written drafts. You type:

> *"I'm stuck."*

A generic agent offers suggestions. An agent with your Practice Layer loaded names the pattern:

> *"This reads like bargaining — you keep rewriting in case 'the right phrasing' will make the ask land better. The `wholesomeness-lens.md` cue for this is: 'what trade are you trying to make?' The note doesn't need to be perfect. Send the honest version and see what comes back."*

It used the fetter vocabulary from your lens, the cue-question you authored, and the specificity of the moment. It didn't recite the lens as content — it *applied* it.

### Afternoon — a decision

Someone asks you to take on a new commitment. You're genuinely unsure. You bring it to the agent:

> *"Should I take this on? It's interesting. I'm worried it's too much."*

The agent pulls from your `true-north.md`:

> *"Your stated orientation is toward 'enough, not more' financially and 'present for my household first.' This adds ~4 hrs/week for 12 weeks. If you take it, what drops? If nothing drops, the family time is where it'll come from by default. Is this ambition wholesome, or is it the part of you that can't say no to being asked?"*

It's not making the decision for you. It's asking the question that the `ambition-as-question.md` component was designed to surface. You still decide.

### Evening — reflection

You ask the agent for a short evening reflection. Instead of summarizing your tasks, it notes a pattern:

> *"You shipped the outreach. That's a Tier-1 move after a Tier-2 week — worth naming. You also skipped your afternoon walk for the third day. Your `maintenance-as-practice.md` names body as a floor, not an extra. Walk tomorrow, not as a chore — as part of the substrate."*

Two observations. Grounded in specifics. Not a to-do list. Ends with energy.

---

## What makes this possible

Three things have to be true for this shape to work:

### 1. Your practice files are specific and alive

If your `wholesomeness-lens.md` is a list of generic virtues, the agent can only produce generic advice. If it names *your* operative fetters with *your* recognition cues, the agent can reflect precisely. **Specificity is what generates depth on the output side.**

This is why the example in [`practice-layer/examples/contemplative-practitioner/`](../practice-layer/examples/contemplative-practitioner/) is deliberately specific — it names four primary fetters with Pāli terms, cue questions, and the exact felt sense of each. Your fork should be equally specific, in your own vocabulary.

### 2. The Practice Layer is actually loaded in the session

This is a detail that's easy to miss. By default, `./scripts/setup` installs your practice files to `~/.steward/practice/`, and the scheduled steward check-ins (via `daily-check.sh`) see them. But your **interactive** agent sessions (when you open Claude Code or Codex in some other directory to do real work) may not — they load the config files local to that session.

Two fixes:

- **For Claude Code**: add a reference to `~/.steward/practice/` in your global `~/.claude/CLAUDE.md`, or symlink the practice dir into `~/.claude/practice/`. The `claude-code` runtime reads those automatically.
- **For Codex**: add the equivalent reference to `~/.codex/AGENTS.md`.

`./scripts/setup` offers to wire this up as Phase 6d (optional). If you skipped it, you can rerun setup or do it by hand.

### 3. The agent uses the files skillfully

A Practice Layer that just gets recited back at you is useless. The behavior we want is *application* — the lens gets used quietly, the cue-question shows up at the right moment, the drift pattern gets named without the list of patterns being listed.

The persona your runtime adapter loads (`~/.steward/CLAUDE.md` for Claude Code, `~/.steward/AGENTS.md` for Codex) instructs the agent to:

- Load the Practice Layer as a shaping prior, not content to recite
- Apply it before emitting a recommendation, not after
- Never taxonomy-dump the list of patterns

This is baked into the default adapter. If you customize it, preserve that principle.

---

## Starting points by depth

### Light

Fill in `templates/wholesome-intention.md` and `templates/wholesomeness-lens.md` with rough first-pass content. Even thin versions change the agent's register. Come back and deepen when you notice the quality of reflection feels shallow.

### Medium

Fork the [`contemplative-practitioner`](../practice-layer/examples/contemplative-practitioner/) example. Edit the specifics to your own voice. Cut the components that don't fit. Keep the structure.

### Deep

Write your Practice Layer from scratch over a few sitting/reflection sessions. Don't rush it. The file should feel true to read a month from now, not clever to write today. Open a PR to `practice-layer/examples/` when it's good enough to share.

---

## Pitfalls

**The files becoming performance.** If you find yourself editing the lens to make it sound wise rather than to make it more accurate, stop. The lens is for you to use, not for anyone to read.

**The check becoming the fetter.** "Did I run the wholesomeness check today?" is already the fetter running the check. Use the lens always; never *ritualize* it. Name the irony precisely when it happens.

**Treating the agent as the authority.** The agent holds the lens so you don't have to hold it constantly. It is not the source of the lens. If the agent says something that feels off, the agent is wrong. Your practice is yours.

---

## Closing

A model that reflects you back to yourself — in the voice of your own practice, at the moment when the fetter is running — is a rare thing. The Practice Layer is how that happens.

Make it yours. Make it specific. Use it lightly. Let it deepen over years.

*Mary Oliver: "Attention is the beginning of devotion."*

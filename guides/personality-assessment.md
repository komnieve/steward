# Personality Assessment Guide

## What This Is

A guided conversation framework for developing operational self-knowledge — understanding your strengths, blind spots, working patterns, and psychological tendencies. This isn't therapy. It's giving the steward system (and yourself) enough context to provide advice that actually lands.

When the steward knows that you avoid shipping because visibility triggers anxiety (not because you're lazy), it can frame its nudges differently. When it knows you work best in structured blocks with someone present, it can recommend that structure instead of generic "just do it" advice.

## Prerequisites

This process works best after **at least 5-10 real working sessions with the same runtime** (Claude Code, Codex, etc.). The runtime needs enough interaction history to observe real patterns — not just what you say about yourself, but how you actually work. If you're just starting out, use it on real work for a week or two first, then come back to this.

You'll also want a `work/` directory in your project for storing the observations and assessment files. If you're using the steward template, this already exists.

## The Process

### Phase 1: Observations (1-2 sessions)

Before the assessment conversation, the runtime needs data. Work together for a few sessions and let it observe patterns. Then ask it to write up what it sees.

Prompt:
> "Based on our sessions together, write up your observations about my working patterns, strengths, and blind spots. Be honest. Put it in `work/personality-observations.md`."

It will notice things like:
- When you're energized vs. drained
- What you avoid and what you lean into
- How you respond to pressure
- Your communication patterns
- Where you get stuck and what unsticks you

### Phase 2: The Guided Conversation (1 session, ~60-90 minutes)

This is a structured conversation where the runtime asks questions and you answer honestly. The goal is depth, not breadth. Some questions will be easy. Some will hit nerve.

Start with:
> "Let's do the personality assessment conversation. I want you to ask me questions to understand who I am — not my resume, but how I actually work, what drives me, what I avoid, what I'm afraid of. Be direct. I'll be honest."

### How to Facilitate

This is not a questionnaire. Don't just run down the list. The questions below are starting points — the real signal comes from follow-ups.

- **Go where the energy is.** If an answer has heat — emotion, hesitation, a long pause, a deflection — stay there. Ask "say more about that" or "what's underneath that?"
- **Follow up on half-answers.** If someone says "I guess I avoid conflict," don't move on. Ask: "What happens when you imagine the conflict? What are you afraid will happen?"
- **Don't rush.** Better to spend 20 minutes on one rich thread than to skim through all the questions. You can always do a second session.
- **Mirror back what you hear.** "It sounds like you're saying X — is that right?" This builds trust and lets them correct or deepen.
- **Name patterns you notice across answers.** "You've mentioned control three times now — in how you manage your team, how you prepare for meetings, how you parent. Is that a pattern you recognize?"
- **Hold space for silence.** Some of these questions require thinking. Don't fill the gap.
- **Be direct but not clinical.** You're having a real conversation, not administering a test. Match their energy. If they're being vulnerable, honor that.

### Question Areas

Work through these roughly in order. The earlier questions build trust and context; the later ones go deeper. You won't get to everything — that's fine. Prioritize depth over coverage.

**1. Energy and motivation:**
- What energizes you? What drains you?
- Describe your best workday in the last month. What made it good?
- Describe your worst. What made it bad?
- When do you feel most alive professionally?
- What kind of work makes time disappear?

**2. Patterns and tendencies:**
- What do you consistently avoid? What's underneath the avoidance?
- When you're stuck, what does "stuck" actually feel like? (In your body, in your thoughts, in your behavior.)
- What's your relationship with deadlines? Do they motivate or paralyze?
- How do you respond to criticism? To praise?
- What's the story you tell yourself when things go wrong? ("I'm not good enough," "nobody helps me," "I should have known better" — what's the tape?)

**3. Working style:**
- Do you work better alone or with someone present? Why?
- What does your best productive state feel like?
- How do you handle unstructured time? (Be honest — not how you think you should handle it.)
- What role do you naturally take in groups? Leader, advisor, executor, observer?
- When you're in a meeting, what are you paying attention to that others aren't?

**4. What you want:**
- What do you actually want? Not what you think you should want. Not what would be impressive. What do you want?
- If money were completely solved, what would you do on a Tuesday?
- What does "enough" look like for you? (Enough money, enough success, enough recognition.)
- What are you building toward? Is it clear or fuzzy?
- What would you regret not having tried?

**5. Relationships and identity:**
- What are you afraid of people finding out about you?
- What's the gap between how you present and how you feel inside?
- Where in your life are you performing vs. being authentic?
- When you imagine your kids (or people who matter to you) as adults talking about you, what do you want them to say?
- Who do you admire? What specifically about them?
- Who were you before you started optimizing?

**6. Strengths and shadows:**
- What strength of yours might also be holding you back?
- Where does perfectionism show up? Where is it actually serving you?
- Do you over-prepare as a way to avoid starting?
- What's the thing you're best at that nobody pays you for?
- What feedback have you received more than once that you haven't fully accepted?

### Estimating Psychological Frameworks

After the conversation, the runtime should estimate the person's profile across standard frameworks. These aren't tests — they're pattern-matching from real answers. Include evidence for each estimate.

- **Big Five (OCEAN)**: Rate each dimension (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism) as low/moderate/high with specific evidence from the conversation. Example: "High Openness — drawn to novel frameworks, builds cross-domain connections, bored by routine execution."
- **MBTI approximation**: Estimate the 4-letter type but hold it loosely. Note where the person falls clearly vs. where they're near the middle.
- **Enneagram**: Estimate core type, wing, and stress/growth directions. This one often resonates most — share it and ask if it lands.
- **Professional archetype**: What role fits them naturally? (Architect, operator, evangelist, advisor, builder, etc.) This is the most actionable — it tells you what work they should be doing more of.

### Phase 3: The Written Assessment

After the conversation, ask for a comprehensive write-up.

Prompt:
> "Write up the personality assessment based on our conversation and your observations. Include: core identity, what energizes/drains me, working patterns, psychological tendencies (Big Five, MBTI, Enneagram if relevant), strengths profile, and what this means for how I should work. Put it in `work/personality-assessment.md`."

The assessment should cover:

1. **Core identity** — Who you are at the operational level
2. **What energizes you** — Activities, contexts, and conditions that bring out your best
3. **What drains you** — The opposite
4. **Working patterns** — How you actually work (not how you think you should)
5. **Psychological frameworks** — Big Five, MBTI, Enneagram as applicable (these are approximations, not labels)
6. **Strengths profile** — Your top strengths and the shadow side of each
7. **Growth edges** — Where the biggest leverage is for improvement
8. **What the steward should know** — Operational summary for the steward persona

### Phase 4: Integration

Once the assessment exists, integrate it into two places so both your interactive sessions and autonomous check-ins are informed by it.

#### 1. Session-instructions file — "Who You Are" Working Context

Add a section to your runtime's session-instructions file (`CLAUDE.md`, `AGENTS.md`, etc.) that gives it the operational context it needs. This isn't the full assessment — it's the working summary. Structure it like this:

```markdown
## Who [Your Name] Is — Working Context

Read this every session. It shapes how you work together.

**Core pattern**: [1-2 sentences on the central dynamic that drives your work behavior.
Example: "Avoids visibility and external testing due to fear of being found lacking."]

**How this shows up in work**: [Specific behavioral patterns to watch for.
Example: "Specs get written but outreach doesn't start. Configs are ready but
don't get deployed. The work isn't hard — the exposure is."]

**What actually works**: [What helps you break through the pattern.
Example: "Structured sessions with someone present. External accountability.
Time-boxing. When stuck, asking: 'Is fear making this decision, or are you?'"]

**Strengths**: [Your top capabilities — what to leverage.]

**Growth edges**: [Where the biggest leverage is for improvement.]

**How to work with him/her**: [Specific instructions for tone and approach.
Example: "Compassion AND follow-through, always together. Don't coddle, don't shame.
Name what's true and ask what's next."]

**Full assessment**: `work/personality-assessment.md`
```

#### 2. Steward Persona

Add the operational insights to your steward persona file's context section. The steward needs less depth but more actionable framing:

```markdown
## Who You're Working With

- [Name] tends to [pattern]. When you see [specific sign], nudge toward [action].
- Best work happens when [conditions].
- Avoidance usually means [root cause], not laziness.
- Frame nudges as [approach that works] rather than [approach that doesn't].
```

The steward only needs the operational summary — it doesn't need the full inner landscape.

## What Makes a Good Assessment

- **Honest, not flattering.** The point is accuracy, not feeling good.
- **Specific, not generic.** "You avoid cold outreach because visibility triggers anxiety" is useful. "You sometimes procrastinate" is not.
- **Connected to behavior.** Every insight should connect to observable patterns and actionable implications.
- **Compassionate but direct.** Understanding why a pattern exists doesn't mean accepting it. Name it, understand it, work with it.
- **Living document.** Update it as you learn more. Challenge anything that doesn't land. The goal is accuracy in service of direction.

## Setup Note: Fork, Don't Clone

If you're using someone else's steward repo as a starting point, **fork it** on GitHub and make your fork **private**. This gives you your own copy you can customize without affecting the original, and keeps your personal assessment files out of a public repo. On GitHub: click "Fork" → check "Copy the main branch only" → under your fork's Settings → General → change visibility to Private.

## Privacy Note

The personality assessment can contain deeply personal material. Consider:
- Keeping it in a `.gitignore`d directory if your repo is shared
- Or keeping it in a private project file that isn't pushed
- The steward only needs the operational summary, not the full inner landscape

## Example Assessment Structure

```markdown
# Personality Assessment — [Your Name]

## Part 1: Who You Are
- Core identity
- What energizes you (numbered list)
- What drains you (numbered list)
- What you want

## Part 2: Psychological Frameworks
- Big Five (OCEAN) estimated profile with evidence
- MBTI approximation with nuance
- Enneagram type with integration/disintegration patterns
- Entrepreneurial/professional archetype

## Part 3: Synthesis
- Core alignment (what roles/contexts fit you)
- The growth edge that matters most
- What the steward should know (operational summary)

## Part 4: Flagged for Deeper Exploration
- Questions that weren't reached or need follow-up
```

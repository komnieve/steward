# Personality Assessment Guide

## What This Is

A guided conversation framework for developing operational self-knowledge — understanding your strengths, blind spots, working patterns, and psychological tendencies. This isn't therapy. It's giving the steward system (and yourself) enough context to provide advice that actually lands.

When the steward knows that you avoid shipping because visibility triggers anxiety (not because you're lazy), it can frame its nudges differently. When it knows you work best in structured blocks with someone present, it can recommend that structure instead of generic "just do it" advice.

## The Process

### Phase 1: Observations (1-2 sessions)

Before the assessment conversation, Claude needs data. Work together for a few sessions and let Claude observe patterns. Then ask it to write up what it sees.

Prompt:
> "Based on our sessions together, write up your observations about my working patterns, strengths, and blind spots. Be honest. Put it in `work/personality-observations.md`."

Claude will notice things like:
- When you're energized vs. drained
- What you avoid and what you lean into
- How you respond to pressure
- Your communication patterns
- Where you get stuck and what unsticks you

### Phase 2: The Guided Conversation (1 session, ~60-90 minutes)

This is a structured conversation where Claude asks questions and you answer honestly. The goal is depth, not breadth. Some questions will be easy. Some will hit nerve.

Start with:
> "Let's do the personality assessment conversation. I want you to ask me questions to understand who I am — not my resume, but how I actually work, what drives me, what I avoid, what I'm afraid of. Be direct. I'll be honest."

### Suggested Question Areas

**Energy and motivation:**
- What energizes you? What drains you?
- Describe your best workday in the last month. What made it good?
- Describe your worst. What made it bad?
- When do you feel most alive professionally?

**Patterns and tendencies:**
- What do you consistently avoid? What's underneath the avoidance?
- When you're stuck, what does "stuck" actually feel like in your body?
- What's your relationship with deadlines? Do they motivate or paralyze?
- How do you respond to criticism? To praise?

**Working style:**
- Do you work better alone or with someone present? Why?
- What does your best productive state feel like?
- How do you handle unstructured time?
- What role do you naturally take in groups?

**Deeper questions (if you're willing):**
- What are you afraid of people finding out about you?
- What's the gap between how you present and how you feel inside?
- Where in your life are you performing vs. being authentic?
- What would you do on a Tuesday if money were completely solved?
- When you imagine your kids as adults talking about you, what do you want them to say?

**Strengths that might be blind spots:**
- What strength of yours might also be holding you back?
- Where does perfectionism show up? Where is it actually serving you?
- Do you over-prepare as a way to avoid starting?

### Phase 3: The Written Assessment

After the conversation, ask Claude to write up a comprehensive assessment.

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

Once the assessment exists, reference it in two places:

1. **CLAUDE.md** — Add a summary in the "Who You Are" section + link to the full file
2. **Steward persona** — Add the operational insights to the persona's context section

This means both your interactive sessions and your autonomous check-ins are informed by the assessment.

## What Makes a Good Assessment

- **Honest, not flattering.** The point is accuracy, not feeling good.
- **Specific, not generic.** "You avoid cold outreach because visibility triggers anxiety" is useful. "You sometimes procrastinate" is not.
- **Connected to behavior.** Every insight should connect to observable patterns and actionable implications.
- **Compassionate but direct.** Understanding why a pattern exists doesn't mean accepting it. Name it, understand it, work with it.
- **Living document.** Update it as you learn more. Challenge anything that doesn't land. The goal is accuracy in service of direction.

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

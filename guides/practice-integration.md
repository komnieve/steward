# Practice Integration Guide

This is the optional contemplative dimension. If you have a meditation, mindfulness, or contemplative practice and want to integrate it with your work, this guide explains how.

If this doesn't resonate, skip it. The steward system works fine without it.

## Why Integrate Practice and Work

For people with an established practice, there's often a hard discontinuity: "practice time" feels clear and grounded, "work time" feels scattered and reactive. The gap between the two is where most of the struggle lives.

Integrating practice doesn't mean meditating at your desk. It means:
- Noticing when anxiety is driving decisions (vs. clarity)
- Using difficult moments (rejection, criticism, failure) as material rather than things to escape
- Maintaining awareness through transitions (between tasks, between meetings, between sessions)
- Recognizing avoidance patterns as they arise, not after they've run for three hours

## How It Works in the Steward System

### 1. UPEKHA.md (or whatever you name it)
A file in your project root that captures your practice philosophy. Your runtime reads it during session start and uses it as context. It doesn't force practice on you — it holds the frame.

### 2. Steward persona integration
If you want the steward to check on your practice, add a section to the persona:

```markdown
### Check the Practice Dimension
- Has [name] taken any sit days recently? If not, and it's been more than a week, mention it.
- Is the pace sustainable or is there grinding?
- If practice is being skipped, that's a bigger problem than any business thread —
  it's the infrastructure degrading.
```

### 3. Activity logging
Track practice sessions in the activity database:

```bash
sqlite3 ~/.steward/activity.db "INSERT INTO activity_log
  (timestamp, project, category, activity, duration_min, notes)
  VALUES (datetime('now', 'localtime'), 'personal', 'practice', 'Morning sit', 45, 'Vipassana, strong concentration');"
```

This lets you (and the steward) see whether practice is actually happening, not just intended.

### 4. The Tonglen strategy
The UPEKHA template includes a specific technique for when difficult feelings arise during work (rejection, failure, tension). The sequence:

1. Notice the pull toward distraction
2. Turn toward the sensation (body awareness)
3. Breathe in — feel it fully
4. Remember others experiencing the same thing
5. Breathe out — let awareness hold it

This is particularly useful for solo founders dealing with: cold outreach anxiety, deployment fear, customer-facing exposure, financial stress, imposter syndrome.

## What "Work as Practice" Looks Like in Practice

- **Session start**: Brief landing in the body before diving into tasks. 30 seconds. Not performance, just presence.
- **Transitions**: Between meetings or tasks, notice the state of the mind. Scattered? Anxious? Clear? Just notice.
- **Avoidance moments**: When you notice yourself reaching for distraction, that's the bell. What's underneath? Not to analyze forever — just to see.
- **Difficult conversations**: Before sending a hard email or making a hard call, pause. Is this coming from clarity or reactivity?
- **End of session**: What was the quality of attention today? Not judgment — just noticing.

## For the Steward

If you want the steward to hold this dimension, the key instruction is:

> "The practice isn't competing with professional execution — it's the infrastructure that makes sustained execution possible. When practice is strong, avoidance patterns loosen and shipping gets easier. When practice weakens, the space between trigger and response collapses. Protect the practice."

This reframes practice from "nice to have" to "load-bearing infrastructure." The steward should treat skipped practice like skipped sleep — not a moral failing, but a capacity issue that will show up downstream.

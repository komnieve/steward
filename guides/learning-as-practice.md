# Learning as Practice

## The Problem

AI models are incredible thinking partners. They're also the fastest way to stop learning.

When you can ask a model to explain any concept, write any code, solve any problem — the temptation is to let it. And it works. The code ships, the email gets sent, the architecture gets designed. But something quietly erodes: your own understanding deepens at the surface level and stalls at the edges.

This is the bargain nobody talks about. You get faster. You also get more dependent. The model handles the hard parts, and the hard parts are exactly where learning happens.

If you're using the steward system to build a company or run your work, you're in this every day. The question isn't whether to use models — obviously you should. The question is: **how do you use models in a way that accelerates learning instead of bypassing it?**

## What the Science Says

Three ideas from learning research matter here.

### Retrieval practice beats re-exposure

The most robust finding in learning science: testing yourself on material produces dramatically better retention than re-reading it. It's not even close. Re-reading feels productive (you recognize the material, it feels familiar) but produces weak memory traces. Actively pulling answers out of your head — even when it's effortful and you get things wrong — builds durable understanding.

This is the problem with how most people use AI. You ask, it explains, you read the explanation, you nod, you move on. That's re-exposure. The information passes through you without sticking.

### Bloom's two-sigma problem

In 1984, Benjamin Bloom showed that one-on-one tutoring produced learning gains of two standard deviations over conventional classroom instruction. That's enormous — the average tutored student performed better than 98% of classroom students.

The catch was cost. One tutor per student doesn't scale. But AI does. You now have access to a tutor that can meet you exactly where you are, at any time, on any topic. The question is whether you actually use it as a tutor (which means it asks you questions and makes you think) vs. as an oracle (which means you ask it questions and passively absorb).

### Vygotsky's Zone of Proximal Development

Lev Vygotsky identified the "zone of proximal development" — the space between what you can do alone and what you can do with help. Learning happens in this zone. Not in the comfortable territory of what you already know, and not in the overwhelming territory of what's completely over your head. In the stretch zone, where you need a nudge but can do most of the work yourself.

AI naturally operates outside this zone. It doesn't scaffold — it solves. Unless you explicitly instruct it not to.

## The IKFOO Inspiration

This idea crystallized from something specific: **IKFOO** (I Know Fuck-All Obviously), a spaced repetition system for book retention.

The original concept: after reading a book, generate retrieval practice questions from the highlights. Then review them on a spaced schedule — not re-reading highlights, but actively testing yourself on the ideas. The goal was simple: actually retain what you read instead of letting books dissolve into vague impressions.

That concept evolved. If spaced retrieval practice works for book knowledge, it works for anything. And if you're working with an AI system that sees what you're learning and where you're struggling, it can do something a generic flashcard app can't: **detect your actual learning edges in real time and generate practice questions that target them.**

## Learning Edge Detection

This is the core mechanism. Add this to your runtime's session-instructions file (`CLAUDE.md`, `AGENTS.md`, etc.):

```markdown
## Learning Edge Detection

When I defer something to you that I clearly don't understand — not delegating for efficiency,
but avoiding because I don't get it — flag it. Gently. Like this:

"I can handle this, but this seems like it might be a learning edge for you —
[concept]. Want me to explain it so you can do it next time, or just handle it?"

Maintain a file at `work/learning-edges.md` that tracks areas where I'm pushing my
understanding. When relevant, generate retrieval practice questions instead of
just giving me answers.

The principle: using models should accelerate learning, not bypass it.
```

The key distinction is between **delegation** and **avoidance**:

- "Generate the SQL migration for this schema change" — delegation. You know SQL, you're saving time. Fine.
- "Just handle the database stuff" — avoidance. You don't understand what's happening and you're routing around it. This is the learning edge.

The system watches for the second pattern and offers to turn it into learning.

## The Learning Edges File

The `learning-edges.md` file is a living document. It tracks:

- **The domain**: what area you're pushing into
- **Current level**: honest assessment of where you are
- **The boundary**: specifically what you don't understand yet
- **Retrieval questions**: questions generated to test your understanding over time

Example entry:

```markdown
### PostgreSQL query optimization
- **Current level**: Can write queries, understand basic JOINs and indexes.
  Don't understand query plans or when the optimizer makes bad decisions.
- **The boundary**: EXPLAIN ANALYZE output. When to use partial indexes vs.
  composite indexes. Why some queries ignore indexes.
- **Retrieval questions**:
  1. What does a Seq Scan in an EXPLAIN output tell you, and when is it actually fine?
  2. You have a table with 10M rows and a query filtering on status and created_at.
     What index would you create, and why that shape?
  3. What's the difference between a partial index and a filtered query?
```

See the [template](../templates/learning-edges-template.md) for a blank version you can start from.

## How This Works in Practice

**During sessions**: your runtime notices when you're deferring something you don't understand. It offers a choice — handle it for you (no judgment) or use it as a teaching moment. If you choose to learn, it scaffolds instead of solving. It asks you questions, gives hints, lets you struggle productively.

**Between sessions**: your runtime (or the steward, if you set it up) can deliver spaced retrieval questions. "Two weeks ago you were learning about Kubernetes networking. Quick check: what's the difference between a ClusterIP and a NodePort service?" This turns dead time into learning reinforcement.

**Over time**: The learning-edges file becomes a map of your growth. You can see what you've pushed through, what's still at the boundary, and where you've plateaued. It's also useful context for the steward — when it sees you avoiding something that's on your learning edges list, it can be more specific in its nudge.

## Future: Steward-Delivered Spaced Repetition

The full vision: the steward reads your learning-edges.md during its morning or evening check-in and includes 1-2 retrieval questions in the Signal message. Not every day — maybe twice a week, spaced out by topic.

```
Morning check-in:

[... normal steward assessment ...]

Quick retrieval (PostgreSQL, flagged 12 days ago):
You have a query that's doing an index scan but still slow.
What are three things you'd check in the EXPLAIN output?
```

This isn't built yet but the pieces are all there — the steward already reads project files and sends Signal messages on a schedule. Adding retrieval questions is a natural extension.

## The Principle

**Using models should accelerate learning, not bypass it.**

This isn't about making things harder for yourself. It's about being intentional. When you're delegating something you understand to save time — great. When you're routing around something you don't understand because the model makes it easy to — that's the moment to notice.

The model can be your oracle or your tutor. The oracle makes you faster today and more dependent tomorrow. The tutor makes you slower today and more capable tomorrow. The steward system lets you choose deliberately, and gently reminds you when you're choosing the oracle on autopilot.

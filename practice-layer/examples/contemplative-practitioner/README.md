# Contemplative practitioner — example Practice Layer

A fully-written Practice Layer for someone with an **established contemplative practice** — sitting most mornings, familiar with Buddhist/meditation-tradition vocabulary, comfortable with the idea that work and practice are not separate domains.

If that's you, fork this. Edit in your voice. Rewrite the specifics. Keep whatever lands.

If it's not — you're in the wrong example. Go look at `../` for the index.

## What this assumes

- You have, or want, a regular sitting practice.
- You're willing to name your own operative patterns — using Pāli vocabulary, Stoic vocabulary, IFS parts language, or whatever else fits your lineage.
- You want the agent that serves you to be a **partner in deepening practice**, not a productivity tool that happens to know some mindfulness quotes.
- You accept that the depth here comes from specificity. Generic spiritual wisdom is exactly what we're avoiding.

## What's in it

Eight files. Each one is meant to be edited — none of this is dogma:

| File | What it holds |
|------|---------------|
| `wholesomeness-lens.md` | **The deepest piece.** A fetter-based negative test for whether an action feeds my patterns or loosens them. Draws from the Pāli ten-fetter framework, with the operative subset named explicitly. |
| `true-north.md` | Long-horizon orientation. Values across dimensions. Drift signals that tell me I've lost the thread. |
| `work-as-practice.md` | Work itself as meditation material. Three tiers of work, how fetters show up on the desk. |
| `maintenance-as-practice.md` | Body, desk, sleep, files, relationships — tending the substrate. Stewart Brand as reference. |
| `people-matter.md` | Relationships as practice, not pipeline. The intention field per person. |
| `wholesome-intention.md` | The light pause before meaningful action. Positive and negative paths. |
| `ambition-as-question.md` | *Is this ambition wholesome, or craving in an ambition costume?* |

## Teachers drawn on

Voices that recur in these files, in case you want the lineage visible: Ajahn Chah, Ajahn Sumedho, Sayadaw U Tejaniya, Joseph Goldstein, Ramana Maharshi, Thich Nhat Hanh, Pema Chödrön, Mary Oliver, Stewart Brand, Robert Caro. Take what resonates. Replace with your own teachers if these aren't yours.

## How to use it

```bash
# After ./scripts/setup creates ~/.steward/practice/, either:

# (a) Replace the installed templates with this example:
cp -r ~/repos/steward/practice-layer/examples/contemplative-practitioner/* \
      ~/.steward/practice/

# (b) Or fork the example first, edit to fit you, then copy in:
cp -r ~/repos/steward/practice-layer/examples/contemplative-practitioner \
      ~/my-practice-layer
# ... edit files in ~/my-practice-layer/ ...
cp ~/my-practice-layer/*.md ~/.steward/practice/
```

See `../../SPEC.md` for the interface the practice files implement, and `../../../guides/deepening-your-practice-layer.md` for how these files surface through a working day.

## A note on depth

This example is deliberately specific. It names fetters by Pāli name. It has opinions about tiers of work. It cites particular teachers. **That specificity is the point.** The alternative — vague wellness prose — is the thing the Practice Layer exists to avoid.

Your fork should be just as specific, just as opinionated, just as grounded in *your* actual practice. If you don't have strong opinions about what wholesome work looks like for you, the honest move is to sit with that for a few weeks before filling these files in. The template is empty until you make it yours.

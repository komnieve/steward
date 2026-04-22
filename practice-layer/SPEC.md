# Practice Layer — specification

The Practice Layer is the spine that makes Steward different from a productivity tool.
It encodes *what matters to you* and *how you want to be guided* into files the agent reads
every run.

This doc defines the interface. Anyone can author a Practice Layer that conforms to it —
as a personal customization, a community-edition fork, or a third-party distribution.

---

## What a Practice Layer is

A Practice Layer is **a set of markdown files** in `$STEWARD_HOME/practice/` that the
steward loads on every run. Each file captures one dimension of the user's aspirational
operating frame.

A compliant Practice Layer provides at minimum:

1. **An intention file** — what the user wants the system to guide them toward.
2. **A lens file** — named patterns/tendencies to notice.
3. **A negative-test mechanism** — a question the steward asks itself before emitting a
   recommendation ("does this feed the pattern, or loosen it?").

Everything else is optional.

---

## File conventions

- Files live in `$STEWARD_HOME/practice/`.
- Each file is plain markdown, human-editable.
- A manifest at `$STEWARD_HOME/practice/.installed` lists the names of installed
  components, one per line.
- The persona loads every `.md` file in `practice/` as context at the start of each run.

---

## Components in the default set

The public repo ships templates for seven components. Users pick which to install at
setup; each is independently optional.

| Component | File | What it does |
|---|---|---|
| True North | `true-north.md` | Long-horizon orientation — where are you moving? |
| Ambition-as-question | `ambition-as-question.md` | Reflective prompt to consider bigger plays |
| Wholesomeness lens | `wholesomeness-lens.md` | Name operative patterns; use as negative test |
| Maintenance-as-practice | `maintenance-as-practice.md` | Caring for infrastructure IS practice |
| Wholesome intention | `wholesome-intention.md` | Light "is this wholesome?" reflection |
| People matter | `people-matter.md` | How you want to show up in each relationship |
| Work-as-practice | `work-as-practice.md` | How you do the work matters as much as what you ship |

Each file is a template with prompts, not a doctrine. Users make it theirs.

---

## Authoring your own

Fork `practice-layer/templates/`. Rewrite each file in your own voice, drawing from
whatever tradition or framework serves you (contemplative, Stoic, humanist, religious,
something entirely your own). Re-publish as a separate repo or as a PR.

Guidance for authors:

- **Voice is yours.** Don't mimic a generic "AI-assistant-friendly" register. Practice
  layers that feel alive do so because they carry a specific voice.
- **Make the negative test concrete.** "Avoid unwholesomeness" isn't testable.
  "Does this action feed bargaining with reality?" is.
- **Anti-ritualization caveat.** Say this plainly in your wholesomeness-lens: if running
  the check becomes the point, the lens has become the thing it warns against.
- **Calibrate per-user.** Don't prescribe a fixed list of patterns. The user names their
  own operative ones.

---

## How the steward uses the Practice Layer

1. **Load-at-start.** Every run, the persona reads every file in `practice/` into context.
2. **Inform recommendations.** When the steward proposes an action, it considers the
   practice files as shaping priors — not as rules to enforce.
3. **Pre-emit check.** Before emitting a recommendation, the persona runs a single-line
   negative-test: *"does this framing feed a pattern the user named?"* If yes, rewrite the
   framing while keeping the action.
4. **Never recite the lens as content.** The Practice Layer shapes how the steward
   speaks; the steward doesn't lecture it back.

---

## What a Practice Layer is NOT

- It is not therapy. It is operational self-knowledge.
- It is not an ethics engine. It is a reflective scaffold.
- It is not a rule system. It is a set of priors the agent holds.
- It is not a replacement for your actual practice. It's a companion to it.

---

## Fork catalog

Anyone running Steward with a rich Practice Layer is welcome to add theirs to
`FORKS.md` at the repo root. Gift economy — fork freely, share if it helps others.

# Practice Layer — user guide

The Practice Layer is the spine that makes Steward different from a productivity tool.
It encodes *what matters to you* and *how you want to be guided* into files the agent
reads every run.

This guide is for users installing or editing their Practice Layer. For the interface
definition and authoring spec, see
[`practice-layer/SPEC.md`](../practice-layer/SPEC.md).

---

## At install

`./scripts/setup` asks you which of seven components you want installed:

1. **True North compass** — long-horizon orientation
2. **Ambition-as-question** — a reflective prompt, not doctrine
3. **Wholesomeness lens** — name your operative patterns; test actions against them
4. **Maintenance-as-practice** — caring for the infrastructure of your life IS practice
5. **Wholesome intention** — light "is this wholesome?" reflection
6. **People matter** — how you want to show up in each relationship
7. **Work-as-practice** — how you do the work matters as much as what you ship

You can pick all, some, or none. If you pick none, your Practice Layer is empty and
the steward will behave more like a straightforward project manager. If that's what
you want, that's fine; consider whether Steward is the right tool.

Each component you install is rendered from a template in
`practice-layer/templates/` into your `~/.steward/practice/` directory as a
markdown file you then edit to fit you.

---

## Editing

Open any file in `~/.steward/practice/` in your editor. Every template has prompts or
placeholders for you to replace with your own content. Templates are written in a
generic register — your version should be in *your* voice, drawing from your actual
practice, framework, tradition, or intuition.

There is no "right way." These files are yours. The steward loads whatever is there.

---

## Calibrating the wholesomeness lens

The wholesomeness lens is the most actionable component. It names the patterns you
most want to notice when they show up in your work.

Best practice for calibration:

1. **Notice three to five patterns that reliably show up for you.** Not "what I
   aspire to avoid" — what actually runs. Honest inventory.
2. **Name each pattern with a specific word.** Generic words ("procrastination",
   "avoidance") don't land when the pattern shows up — precise names do.
   Contemplative traditions offer ready vocabulary (bargaining, conceit, restlessness,
   identity view, ill-will, sensual grasping, doubt); use them if they resonate, or
   coin your own.
3. **Write a cue-question for each.** One line. Something you can ask yourself when
   you suspect the pattern is running.
4. **Don't over-specify.** More patterns is not better. Three live, accurate patterns
   beat ten that you rarely remember.

---

## Adding components later

Copy the template in and register it in the manifest:

```bash
cp practice-layer/templates/<name>.md ~/.steward/practice/
echo "<name>" >> ~/.steward/practice/.installed
```

The manifest (`~/.steward/practice/.installed`) is one component name per line, no
`.md` extension — e.g. `true-north`. The steward loads whatever markdown is in the
directory; the manifest records what setup installed.

---

## Removing components

Delete the file from `~/.steward/practice/`. The steward stops loading it. Done.

---

## Swapping Practice Layers

If you want to try a different authored Practice Layer (e.g., a community edition in
`practice-layer/examples/`), back up your current `~/.steward/practice/` and copy the
alternative in. The interface is the same; only the content changes.

---

## Authoring your own

If you want to write a full Practice Layer from scratch — grounded in a specific
tradition, for a specific community, in a specific voice — see the authoring guide in
[`practice-layer/SPEC.md`](../practice-layer/SPEC.md). Contributions welcome.

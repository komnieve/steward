# Steward

**A chief of staff for people who hold work as practice.**

Steward is an AI companion that reads your active threads, notices what's drifting,
and reflects what's true — across mornings, evenings, and the thousand small decisions
in between. It is not a productivity app. It is infrastructure for holding work, life,
and practice as one thing.

If you want pure productivity — deadlines, tasks, output optimization — there are
better tools. If you want a system that assumes your work is also where your practice
happens, keep reading.

---

## What it does

- **Daily reviews.** Morning: what deserves energy today? Evening: what moved, what
  didn't, what's next? The steward reads your status file, your activity log, and your
  code changes — then sends you a short, honest reflection.
- **Holds the thread.** When you commit to something and drift, the steward notices.
  When you ship after weeks of avoidance, it names the shift.
- **Runs on your Practice Layer.** Whatever frame you hold — contemplative, Stoic,
  humanist, religious, something entirely your own — the steward reads it alongside
  your work and speaks in that register.
- **Works with your agent of choice.** Claude Code, Codex, or anything that can read
  files and shell out. Bring your own.

Not a chatbot. Not a to-do app. A system that sees you clearly and shows up reliably.

---

## Who it's for

**People who hold work as practice.** Founders, operators, writers, teachers,
practitioners, volunteers, coordinators — anyone for whom *how* they work is as
important as *what* they ship.

If you're skeptical of "AI as productivity hack" but open to AI as a reflective
companion that takes your inner life seriously — this is for you.

---

## How it works

Two concepts in the spine:

**Steward Core** — the persistent state every run reads: who you are (`user-lens.md`),
what's live (`status.md`), what happened (`activity.db`), what's stuck (`stuck.json`).

**Practice Layer** — a set of markdown files that encode *what matters to you* and
*how you want to be guided*. You pick which components to install at setup. See
[`practice-layer/SPEC.md`](practice-layer/SPEC.md).

Your agent runtime (Claude Code, Codex, or any file-reading agent) loads both at the
start of every run. Daily review generates a short reflection. Delivery is terminal,
Slack webhook, or email — your pick.

---

## Getting started

**Prerequisites:**

- An agent runtime on PATH: [Claude Code](https://claude.com/product/claude-code) or
  [Codex](https://github.com/openai/codex) (either works — use what you have)
- API key for the runtime (Anthropic or OpenAI)
- `sqlite3`
- A Unix-ish shell (macOS, Linux, WSL)

**Install (~20 min):**

```bash
git clone https://github.com/komnieve/steward ~/repos/steward
cd ~/repos/steward
./scripts/setup
```

`setup` walks you through eight phases: prerequisite check, intention capture,
Practice Layer components, user lens, technical choices (runtime, delivery, schedule),
optional features, scaffolding, first run, and handoff. At the end, your
`~/.steward/` is configured to you.

See [`guides/getting-started.md`](guides/getting-started.md) for the walkthrough.

---

## Directory overview

```
steward/
  README.md                         ← this file
  scripts/
    setup                           ← guided installer (start here)
    setup-phases/                   ← 8 per-phase sub-scripts
    daily-check.sh                  ← morning steward run
    evening-check.sh                ← evening steward run
  practice-layer/
    SPEC.md                         ← what a Practice Layer is
    templates/                      ← 7 component templates
    examples/                       ← community forks go here
  runtimes/
    claude-code/                    ← adapter for Claude Code
    codex/                          ← adapter for Codex
  guides/
    getting-started.md
    practice-layer.md
    runtimes.md
    delivery-slack.md
    status-dashboard.md
    activity-tracking.md
    personality-assessment.md
    ...
  templates/
    steward-persona.md              ← the persona every run loads
    status.md
    transcription-corrections.md
    learning-edges-template.md
    holidays.txt
    settings.json
  hooks/
    inject-time.sh                  ← optional time-awareness hook
```

---

## Delivery

- **Terminal** (default) — `daily-check.sh` prints to stdout. Zero setup.
- **Slack webhook** — one-curl POST to an incoming webhook URL. Works inside your
  existing Slack perimeter; no new vendor review. See
  [`guides/delivery-slack.md`](guides/delivery-slack.md).
- **Slack MCP plugin** (Claude Code only) — `claude plugin install slack`. Richer
  capabilities if you're on CC.
- **Email / Signal** — documented paths, not wired in v0.2. Coming.

---

## Contributing

Fork freely, adapt for your context, contribute back when it serves. This is practice
made public. Gift economy — no paid features, no gate.

If you author a Practice Layer others might use, add it to
[`practice-layer/examples/`](practice-layer/examples/). If you extend a runtime
adapter for an agent we don't ship, PR it into [`runtimes/`](runtimes/).

---

## Acknowledgments

Built by Komnieve Singh / Upekha Ventures. Shaped by conversations with fellow
practitioners — you know who you are. The Practice Layer interface draws on decades of
contemplative traditions without claiming to represent any of them.

---

## License

MIT. Use it. Fork it. Make it yours.

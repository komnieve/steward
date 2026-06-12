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
- **Optional local memory.** Steward Memory (Recall) builds a local hybrid search
  index over your Steward files and any folders you add — local model, no embedding
  API. Heavier install; off by default. See
  [`guides/local-memory.md`](guides/local-memory.md).

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
Slack webhook, or Signal in v0.2.

---

## Getting started

**Prerequisites:**

- An agent runtime on PATH: [Claude Code](https://claude.com/product/claude-code) or
  [Codex](https://github.com/openai/codex) (either works — use what you have)
- API key for the runtime (Anthropic or OpenAI)
- `sqlite3`
- `python3` (3.x — setup and the daily check use it for config handling)
- A Unix-ish shell (macOS, Linux, WSL)

**Install (~20 min):**

```bash
git clone https://github.com/komnieve/steward ~/repos/steward
cd ~/repos/steward
./scripts/setup
```

`setup` walks you through prerequisite check, intention capture, Practice Layer
components, user lens, technical choices, optional local tools, advanced integrations,
scaffolding, your steward's first check-in, and handoff. The default path only writes inside
`~/.steward/`; anything that edits runtime/global config or starts background services
asks again and shows the target files first.

Manual runs work immediately after setup. Automatic scheduling is not wired into the
main installer yet; use launchd, cron, or systemd manually if you want scheduled runs.
If you enable focus-dash or the focus watcher, setup will ask for a `project_root` —
point it at your actual work repo, not the steward clone (or leave blank to skip
git-aware features).

See [`guides/getting-started.md`](guides/getting-started.md) for the walkthrough.

---

## Directory overview

```
steward/
  README.md                         ← this file
  scripts/
    setup                           ← guided installer (start here)
    setup-phases/                   ← guided setup phases
    daily-check.sh                  ← morning steward run
    evening-check.sh                ← evening steward run
  practice-layer/
    SPEC.md                         ← what a Practice Layer is
    templates/                      ← 7 component templates
    examples/                       ← community forks go here
  runtimes/
    claude-code/                    ← adapter for Claude Code
    codex/                          ← adapter for Codex
  packages/
    recall/                         ← Steward Memory engine (optional, local search)
  tools/
    desk, tokens                    ← small optional CLIs (priorities, token counts)
  focus-dash/
    refresh.sh ...                  ← browser dashboard at localhost:8888 (optional)
  personas/
    focus/                          ← focus watcher (macOS-only, optional, opt-in)
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
    steward-persona.md              ← copied to ~/.steward/persona.md; the runtime adapter loads it every run
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
- **Signal** — send-only delivery via `signal-cli`. Reflections arrive as a Signal
  message to your own number (or any recipient you set). See
  [`guides/tools-setup.md`](guides/tools-setup.md).
- **Email** — not wired in v0.2. Coming.

---

## Contributing

Fork freely, adapt for your context, contribute back when it serves. This is practice
made public. Gift economy — no paid features, no gate.

If you author a Practice Layer others might use, add it to
[`practice-layer/examples/`](practice-layer/examples/). If you extend a runtime
adapter for an agent we don't ship, PR it into [`runtimes/`](runtimes/).

---

## Acknowledgments

Built as a service of Upekha Ventures and shaped by conversations with
practitioners. The Practice Layer interface draws on contemplative traditions
without claiming to represent any of them.

---

## License

MIT. Use it. Fork it. Make it yours.

# Runtimes

Steward works with any agent that can read files and call shell commands. We ship
adapter configs for two common choices:

- **Claude Code** — Anthropic's CLI. Auto-loads `CLAUDE.md` at the start of every
  session; native MCP, skills, hooks, and auto-memory support.
- **Codex** — OpenAI's CLI. Similar file-reading + tool-use agent pattern.

You can also use any other agent that can read files and run shell (Aider, Cline,
continue.dev, a custom setup). The minimum contract is: the agent reads
`$STEWARD_HOME/persona.md`, `user-lens.md`, `status.md`, the `practice/` directory, and
can query `activity.db` via `sqlite3`.

---

## Claude Code

**Installation:**
```bash
# see https://claude.com/product/claude-code for the current install instructions
```

**How Steward integrates:**
- `setup` writes `$STEWARD_HOME/CLAUDE.md` from
  [`runtimes/claude-code/CLAUDE.md.template`](../runtimes/claude-code/CLAUDE.md.template)
- When you run `claude` from `~/.steward/`, `CLAUDE.md` is auto-loaded as the session's
  system context. It references every other file the persona needs.
- Optional: install the time-injection hook for temporal awareness (`hooks/inject-time.sh`).
- Optional: install the Slack MCP plugin for richer Slack integration (`claude plugin install slack`).

**API key:** `ANTHROPIC_API_KEY` env var, or whatever `claude` CLI's standard config is.

---

## Codex

**Installation:**
```bash
# see https://github.com/openai/codex for current install instructions
```

**How Steward integrates:**
- `setup` writes `$STEWARD_HOME/AGENTS.md` from
  [`runtimes/codex/AGENTS.md.template`](../runtimes/codex/AGENTS.md.template)
- When you run `codex` from `~/.steward/`, `AGENTS.md` is auto-loaded as the session's
  system context. It references every other file the persona needs.

**API key:** `OPENAI_API_KEY` env var, or whatever `codex` CLI's standard config is.

---

## Other agents

Any agent that can:
- Read markdown files
- Execute shell (for `sqlite3` queries on `activity.db`)
- Be given a system prompt / context document

…will work. Copy one of the existing adapter files in
[`runtimes/`](../runtimes/) and rename it to whatever convention your agent expects.
The file references the core Steward files; that's the only real contract.

If you write an adapter for a new runtime, contribute it back — PR a new directory
under [`runtimes/`](../runtimes/).

---

## Switching runtimes

If you installed with one runtime and want to switch, re-run `./scripts/setup
--runtime claude-code` (or `--runtime codex`). Your Practice Layer, status file,
activity log, and user lens stay intact; only the adapter file changes.

# Runtime adapters

Steward works with any agent runtime that can read files and call shell commands.
Each directory here contains a small adapter file that tells a specific agent how to
load the Steward context.

- [`claude-code/`](claude-code/) — adapter for [Claude Code](https://claude.com/product/claude-code)
- [`codex/`](codex/) — adapter for [Codex](https://github.com/openai/codex)

The adapter files are templates. `./scripts/setup` copies the appropriate one into
`$STEWARD_HOME/` with the filename that agent expects (`CLAUDE.md`, `AGENTS.md`, etc.).

---

## Adding a new runtime

Copy either existing directory, rename it, and adjust the template's header to match
your agent's expected config filename + any agent-specific conventions. The body
should still reference the same `$STEWARD_HOME/` files; that's the Steward contract.

Open a PR to share your adapter with other users of the same agent.

---

## Minimum contract

A runtime is compatible with Steward if it can:

1. Read markdown files from `$STEWARD_HOME/`
2. Execute shell commands (for `sqlite3` queries against `activity.db`)
3. Accept a system-level context document (a CLAUDE.md-equivalent)

Most agents that can read files and run tools meet this bar.

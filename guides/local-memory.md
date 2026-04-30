# Steward Memory (Recall)

A local hybrid search index over your Steward files and any other folders you
add. Opt-in. Lives at `~/.steward/recall/`.

Recall is the engine. The full Recall README is at
[`packages/recall/README.md`](../packages/recall/README.md). This guide covers
the Steward-specific install, configuration, and use.

---

## What it is

- **Hybrid search**: vector similarity + keyword FTS, fused via Reciprocal Rank
  Fusion. Catches both semantic matches and exact-string matches.
- **Local model**: embeddings run on your machine. No note contents are sent
  to an embedding API.
- **MCP-aware**: exposes `search`, `fetch`, and `query_db` tools to Claude
  Code (or any MCP host), so the agent can call recall before answering
  questions about your prior work.
- **Generic SQLite adapter**: declare tables in TOML, get one synthetic
  document per row.

## Privacy model

- All indexing and search happens on your machine.
- Embedding model weights download once from Hugging Face (~600MB) and are
  cached locally; subsequent runs are offline.
- The `query_db` tool runs read-only SQL against databases you opt in to. The
  SQLite authorizer denies writes, ATTACH, and extension loads.
- The `fetch` tool refuses URIs that aren't in the index — no arbitrary file
  reads.

## Hardware expectations

- **Disk**: ~2GB total (torch + sentence-transformers + model weights +
  search.db). Index size grows with corpus.
- **RAM**: 1–2GB for first model load.
- **CPU/GPU**:
  - On Apple Silicon, the default `device = "auto"` uses the MPS backend; first
    query takes a few seconds.
  - On x86 Linux/Windows with no GPU, embedding falls back to CPU. First index
    of a large corpus can take many minutes.
  - On CUDA machines, set `device = "cuda"` (or leave on `auto`).

If your machine is lighter than this, skip Steward Memory. Steward works
without it — every other feature is independent.

## Install

Two paths:

**Via Steward setup** (recommended):

```bash
./scripts/setup
# Phase 5 → answer "y" to "Steward Memory"
# Phase 6e → walks you through venv, install, optional first-index, and MCP stanza
```

**Manual** (after Steward setup completes without Memory):

```bash
mkdir -p ~/.steward/recall
cp ~/repos/steward/packages/recall/templates/recall.config.toml ~/.steward/recall/config.toml
python3 -m venv ~/.steward/recall/.venv
~/.steward/recall/.venv/bin/pip install -e "$HOME/repos/steward/packages/recall[embeddings]"
```

The `[embeddings]` extra is what pulls `torch` + `sentence-transformers`. If
you forget it, `recall index` will fail at first use with an import error.

> **Windows users**: native Windows is not exercised by Steward setup. Use WSL
> for the bash-based install, or install Recall manually under PowerShell using
> the venv's `Scripts\` layout (`%USERPROFILE%\.steward\recall\.venv\Scripts\`).
> The Recall package itself is cross-platform; only the setup shell script is
> Unix-only.

Either way you end up with:

```
~/.steward/recall/
  config.toml          ← what to index, what to expose to query_db
  search.db            ← the index (gitignored)
  .venv/               ← isolated Python env
```

## First index

```bash
RECALL_CONFIG=~/.steward/recall/config.toml \
  ~/.steward/recall/.venv/bin/recall index --full
```

The first run downloads model weights and embeds every chunk. Subsequent runs
are incremental — only files whose content hash changed get re-embedded.

## Configuration

Edit `~/.steward/recall/config.toml`. The file is annotated.

### Adding folders

```toml
[[markdown_sources]]
name       = "notes"
path       = "~/notes"
extensions = [".md", ".txt"]
```

`name` becomes the document's `source_type`; you can filter by it:

```bash
recall search "decision log" -s notes
```

### Adding SQLite sources

Each table you declare produces one synthetic document per row. Set
`queryable = true` to also expose the database to the `query_db` tool.

```toml
[[sqlite_sources]]
name      = "journal"
path      = "~/.steward/journal.db"
queryable = true

  [[sqlite_sources.tables]]
  table           = "entries"
  id_column       = "id"
  modified_column = "updated_at"
  title_columns   = ["topic"]
  text_columns    = ["created_at", "topic", "body"]
  where           = "body IS NOT NULL AND trim(body) != ''"
```

`where` clauses are trusted config — never user/MCP input.

## Day-to-day use

```bash
# Sugar form (routes to search)
recall "what did we decide about X"

# Canonical
recall search "project alpha" -s notes -k 5

# SQL against a queryable DB
recall query-db journal "SELECT topic, created_at FROM entries ORDER BY created_at DESC LIMIT 10"

# Index health (no model load)
recall doctor

# Index health + model load + sample query
recall doctor --model

# Diagnose retrieval (per-signal breakdown)
recall debug-search "tricky query" -e expected_substring
```

The `recall` shim assumes `RECALL_CONFIG` is set. Either export it in your
shell, or invoke as `RECALL_CONFIG=~/.steward/recall/config.toml recall ...`.

## MCP integration with Claude Code

Add this to `~/.claude.json` under `mcpServers`:

```json
"recall": {
  "type": "stdio",
  "command": "/Users/YOU/.steward/recall/.venv/bin/python",
  "args": ["-m", "recall.mcp_server"],
  "env": {
    "RECALL_CONFIG": "/Users/YOU/.steward/recall/config.toml"
  }
}
```

Setup will print this stanza for you with your real paths during phase 6e.
You edit `~/.claude.json` yourself; setup never modifies it automatically.

The MCP server exposes:

- `search` — call this before answering questions about prior decisions or
  written notes. Returns ranked chunks with source URIs.
- `fetch` — full content for a URI returned by `search`. Refuses URIs not
  present in the index.
- `query_db` — read-only SQL against `queryable = true` databases. Hardened
  with a SQLite authorizer.

**Tip**: in your Claude Code project's `CLAUDE.md`, add a recall-first hint:

> When asked about prior decisions, ongoing projects, or anything written
> down before, call `search` before answering from training-data recall.

## Background indexing

Setup does not install schedulers. To run `recall index` on a timer, pick the
mechanism that matches your OS.

**macOS (launchd):**

```xml
<!-- ~/Library/LaunchAgents/com.steward.recall-index.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>            <string>com.steward.recall-index</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/YOU/.steward/recall/.venv/bin/recall</string>
    <string>index</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>RECALL_CONFIG</key>  <string>/Users/YOU/.steward/recall/config.toml</string>
  </dict>
  <key>StartInterval</key>    <integer>900</integer>
  <key>StandardOutPath</key>  <string>/Users/YOU/.steward/recall/index.log</string>
  <key>StandardErrorPath</key><string>/Users/YOU/.steward/recall/index.log</string>
  <key>RunAtLoad</key>        <true/>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.steward.recall-index.plist
```

**Linux (systemd user timer):** create `~/.config/systemd/user/recall-index.{service,timer}` and `systemctl --user enable --now recall-index.timer`.

**Windows:** Task Scheduler → "Create Basic Task" pointing at the venv's
`recall.exe` with `index` argument and `RECALL_CONFIG` set.

A single index pass is incremental and idempotent — running it on a 15-minute
timer is a reasonable default.

## Troubleshooting

**`recall doctor` says "search.db missing"** — run `recall index --full` once.

**First MCP call is slow** — the embedding model loads lazily on the first
vector query. Typical first-load is a few seconds on Apple Silicon, longer on
CPU. Subsequent queries are fast.

**`pip install` fails on torch** — try a Python 3.12 venv (`python3.12 -m
venv`). torch wheels lag the latest Python release by a few weeks.

**`recall index` hangs at first run** — first run downloads ~600MB of model
weights from Hugging Face. Watch network. If you don't want HF downloads,
pre-cache the model with `huggingface-cli download
Snowflake/snowflake-arctic-embed-l-v2.0`.

**Stale results after editing files** — the indexer hashes content; an edit
should trigger a re-embed on the next index. If `recall status` shows the file
in your corpus and a fresh search still returns the old chunk, force-rebuild:
`recall index --reset-embeddings`.

## Disabling / removing

```bash
# Stop indexing (if scheduled)
launchctl unload ~/Library/LaunchAgents/com.steward.recall-index.plist 2>/dev/null
rm -f  ~/Library/LaunchAgents/com.steward.recall-index.plist

# Remove the index and venv (keeps your config.toml so you can re-enable later)
rm -rf ~/.steward/recall/.venv ~/.steward/recall/search.db*

# Or remove everything
rm -rf ~/.steward/recall

# Remove the MCP registration: edit ~/.claude.json and delete the "recall" entry
```

Recall does not write outside `~/.steward/recall/` (and the Hugging Face model
cache, by default at `~/.cache/huggingface/`).

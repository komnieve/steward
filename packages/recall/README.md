# recall

Local hybrid search over markdown corpora and SQLite databases. Designed to be
called by a coding agent (via MCP) and by a human (via CLI).

Recall is the engine behind Steward's optional local memory layer. It can also
be used standalone outside Steward.

## What you get

- Hybrid retrieval: vector similarity + chunk FTS + document-title FTS, fused
  via Reciprocal Rank Fusion.
- Local embedding model — no note contents are sent to an embedding API.
- Markdown-aware chunking that preserves heading context.
- Generic SQLite source adapter: declare tables in TOML, get one synthetic
  document per row.
- `query_db` tool: read-only SQL against configured databases, hardened with a
  SQLite authorizer and a wall-clock progress handler.
- MCP server: `search`, `fetch`, `query_db` exposed for use by Claude Code or
  any MCP-compatible host.

## Hardware and first-run notes

- The default embedding model (`Snowflake/snowflake-arctic-embed-l-v2.0`) is
  ~600MB on disk and downloads from Hugging Face on first use.
- First model load can be slow (multi-second on Apple Silicon, longer on
  CPU-only machines).
- On CPU-only laptops with limited RAM, indexing a large corpus can be slow.
- `device = "auto"` picks `mps` on Apple Silicon, `cuda` if available, else
  `cpu`. Override in `[embedding]` if needed.
- Recall is optional. Steward works without it; only enable if your machine
  has the headroom.

## Install

```bash
cd packages/recall
python3.12 -m venv .venv
.venv/bin/pip install -e ".[embeddings,dev]"
```

The `[embeddings]` extra pulls `sentence-transformers` and `torch` (~2GB on
disk). Skip it (`pip install -e ".[dev]"`) if you're plugging in a custom
embedder or only exercising chunking + FTS. The default `recall index` and
`recall search` paths require `[embeddings]`.

## Configure

Recall reads `~/.steward/recall/config.toml` by default. A starter template
lives at `templates/recall.config.toml`. Override with `RECALL_CONFIG=/path`
or `RECALL_HOME=/dir`.

If no config file is present, the in-process default indexes `~/.steward/`
and configures no SQLite sources.

## First index

```bash
.venv/bin/recall doctor             # DB / config / index integrity (no model load)
.venv/bin/recall index --full       # walks the corpus, downloads model on first run
.venv/bin/recall doctor --model     # also load the embedding model + sample query
.venv/bin/recall status             # see what got indexed
```

## CLI

```bash
recall "what did we decide about X"            # sugar for `recall search ...`
recall search "project alpha" -s project       # filter by configured source name
recall query-db journal "SELECT * FROM entries LIMIT 5"
recall status
recall doctor          # fast checks, no HF model load
recall doctor --model  # adds embedding load + sample query
```

The bare-query form (`recall "..."`) is sugar that routes to `recall search`.
The canonical/scriptable form is `recall search "..."` — prefer that in
scripts, slash-commands, and shared docs.

## MCP integration

Register the server in your MCP host's config. For Claude Code
(`~/.claude.json` under `mcpServers`):

```json
"recall": {
  "type": "stdio",
  "command": "/path/to/.venv/bin/python",
  "args": ["-m", "recall.mcp_server"],
  "env": {
    "RECALL_CONFIG": "/path/to/your/config.toml"
  }
}
```

The MCP server exposes three tools:

- `search` — hybrid search; returns ranked chunks with source URIs.
- `fetch` — full content for a URI returned by `search`. Refuses URIs not
  present in the index (no arbitrary file reads).
- `query_db` — read-only SQL against configured queryable databases. Caps row
  counts and refuses ATTACH / writes / extension loads at the SQLite
  authorizer.

## Architecture

Three layers:

- **Indexer** (`src/recall/indexer/`) — walks markdown files and configured DB
  tables, hashes content, embeds dirty chunks, upserts into `search.db`.
- **Search** (`src/recall/search/`) — hybrid vector + keyword via `sqlite-vec`
  + FTS5 (chunk-level + document-title), fused with RRF.
- **MCP server** (`src/recall/mcp_server.py`) — exposes `search`, `fetch`,
  `query_db` to MCP hosts.

`search.db` lives at `[index].db_path` (default `~/.steward/recall/search.db`)
and is gitignored.

## Background indexing

A `recall index` invocation is incremental and idempotent. Schedule it however
you like — launchd on macOS, systemd timer / cron on Linux, Task Scheduler on
Windows. The package does not install schedulers automatically.

## Eval

```bash
recall eval         # runs tests/eval_queries.yaml if present
```

Eval suites are user-specific and gitignored. The command no-ops cleanly if
no eval file exists.

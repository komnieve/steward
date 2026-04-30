"""MCP server exposing search, fetch, query_db.

All handlers return controlled TextContent error payloads instead of letting
exceptions bubble to the MCP client. Inputs are validated and clamped.
"""

import asyncio
import json
import sqlite3
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import TextContent, Tool

from recall.config import CONFIG
from recall.db.connection import open_external_db, open_search_db
from recall.indexer.sqlite_adapter import allowed_tables
from recall.search.hybrid import hybrid_search

server = Server("recall")

K_MIN = 1
K_MAX = 50
K_DEFAULT = 10


@server.list_tools()
async def list_tools() -> list[Tool]:
    db_names = sorted(CONFIG.queryable_dbs)
    db_clause = (
        f"Available databases: {', '.join(db_names)}. "
        if db_names else
        "No databases are configured for query_db; this tool will refuse all calls. "
    )
    return [
        Tool(
            name="search",
            description=(
                "Hybrid keyword + vector search over the user's local memory index "
                "(configured markdown sources and selected SQLite database rows). "
                "Use this BEFORE answering questions about prior decisions, ongoing "
                "projects, meeting outcomes, or anything that may have been written down "
                "before. Returns ranked chunks with source URIs that can be passed to "
                "fetch for the full content."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {"type": "string", "description": "Free-text search query"},
                    "k": {"type": "integer", "default": K_DEFAULT, "minimum": K_MIN, "maximum": K_MAX},
                    "source_type": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Optional filter: list of source names from config plus 'db_row'",
                    },
                },
                "required": ["query"],
            },
        ),
        Tool(
            name="fetch",
            description=(
                "Fetch the full content of a source identified by URI. "
                "Use after search to read more context around a hit. "
                "Refuses URIs not present in the index (no arbitrary file reads). "
                "Supported schemes: file:///path  (returns file contents), "
                "db://<db>/<table>/<rowid>  (returns the formatted row)."
            ),
            inputSchema={
                "type": "object",
                "properties": {"source_uri": {"type": "string"}},
                "required": ["source_uri"],
            },
        ),
        Tool(
            name="query_db",
            description=(
                "Run read-only SQL against a configured local SQLite database. "
                + db_clause +
                "Only SELECT/WITH allowed; ATTACH/PRAGMA-write/extension-load denied at "
                "the SQLite authorizer. Results are capped (default "
                f"{CONFIG.query_db_default_limit_mcp} rows, max {CONFIG.query_db_max_limit}). "
                "Use this for exact rows, counts, time-bucketed aggregations, joins."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "database": {"type": "string", "enum": db_names} if db_names else {"type": "string"},
                    "sql": {"type": "string"},
                    "limit": {"type": "integer", "minimum": 1,
                              "maximum": CONFIG.query_db_max_limit,
                              "default": CONFIG.query_db_default_limit_mcp},
                },
                "required": ["database", "sql"],
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    try:
        if name == "search":
            return _search(arguments)
        if name == "fetch":
            return _fetch(arguments)
        if name == "query_db":
            return _query_db(arguments)
        return [TextContent(type="text", text=f"Unknown tool: {name}")]
    except Exception as e:
        return [TextContent(type="text", text=f"Tool '{name}' error: {type(e).__name__}: {e}")]


def _search(args: dict[str, Any]) -> list[TextContent]:
    try:
        query_raw = args.get("query")
        if not isinstance(query_raw, str):
            return [TextContent(type="text", text="Refused: 'query' must be a non-empty string.")]
        query = query_raw.strip()
        if not query:
            return [TextContent(type="text", text="Refused: 'query' is empty.")]
        k = _coerce_int(args.get("k"), K_DEFAULT, K_MIN, K_MAX)

        source_type = args.get("source_type")
        if source_type is not None:
            if not isinstance(source_type, list) or not all(isinstance(s, str) for s in source_type):
                return [TextContent(type="text", text="Refused: 'source_type' must be a list of strings.")]

        if not CONFIG.db_path.exists():
            return [TextContent(type="text",
                text="search.db missing. Run `recall index --full` first.")]

        try:
            results = hybrid_search(query, k=k, source_type=source_type)
        except Exception as e:
            return [TextContent(type="text",
                text=f"Search failed: {type(e).__name__}: {e}")]

        if not results:
            return [TextContent(type="text", text=f"No results for: {query}")]

        payload = [
            {
                "rank": i + 1,
                "source_uri": r.source_uri,
                "title": r.title,
                "source_type": r.source_type,
                "section_heading": r.section_heading,
                "score": round(r.score, 5),
                "vec_rank": r.vec_rank,
                "fts_rank": r.fts_rank,
                "text": r.text,
            }
            for i, r in enumerate(results)
        ]
        return [TextContent(type="text", text=json.dumps(payload, indent=2))]
    except Exception as e:
        return [TextContent(type="text", text=f"search error: {type(e).__name__}: {e}")]


def _fetch(args: dict[str, Any]) -> list[TextContent]:
    try:
        uri_raw = args.get("source_uri")
        if not isinstance(uri_raw, str) or not uri_raw.strip():
            return [TextContent(type="text", text="Refused: 'source_uri' must be a non-empty string.")]
        uri = uri_raw.strip()
        parsed = urlparse(uri)

        if parsed.scheme == "file":
            return _fetch_file(uri, parsed)
        if parsed.scheme == "db":
            return _fetch_db(uri, parsed)
        return [TextContent(type="text", text=f"Unsupported URI scheme: {parsed.scheme}")]
    except Exception as e:
        return [TextContent(type="text", text=f"fetch error: {type(e).__name__}: {e}")]


def _fetch_file(uri: str, parsed) -> list[TextContent]:
    raw_path = parsed.path
    if not raw_path:
        return [TextContent(type="text", text="Refused: file URI missing path.")]

    try:
        canonical = Path(raw_path).resolve(strict=False)
    except Exception as e:
        return [TextContent(type="text", text=f"Refused: cannot resolve path: {e}")]
    canonical_uri = f"file://{canonical}"

    if not CONFIG.db_path.exists():
        return [TextContent(type="text",
            text="search.db missing. Run `recall index --full` first.")]

    conn = open_search_db(read_only=True)
    try:
        row = conn.execute(
            "SELECT 1 FROM documents WHERE source_uri = ? LIMIT 1",
            (canonical_uri,),
        ).fetchone()
    finally:
        conn.close()

    if not row:
        return [TextContent(type="text",
            text="Refused: source_uri (after canonicalization) is not in the index. "
                 "Use search first to discover valid URIs.")]

    if not canonical.exists():
        return [TextContent(type="text", text=f"File not found on disk: {canonical}")]
    if not canonical.is_file():
        return [TextContent(type="text", text=f"Refused: not a regular file: {canonical}")]
    try:
        return [TextContent(type="text",
            text=canonical.read_text(encoding="utf-8", errors="replace"))]
    except Exception as e:
        return [TextContent(type="text", text=f"Error reading {canonical}: {type(e).__name__}: {e}")]


def _fetch_db(uri: str, parsed) -> list[TextContent]:
    db_name = parsed.netloc
    parts = parsed.path.lstrip("/").split("/")
    if len(parts) != 2:
        return [TextContent(type="text", text=f"Bad db URI: {uri}")]
    table, row_id = parts

    if db_name not in CONFIG.queryable_dbs:
        return [TextContent(type="text", text=f"Unknown database: {db_name}")]
    if table not in allowed_tables(db_name):
        return [TextContent(type="text",
            text=f"Refused: table '{table}' is not in the indexed table whitelist for {db_name}.")]

    if CONFIG.db_path.exists():
        conn = open_search_db(read_only=True)
        try:
            row = conn.execute(
                "SELECT 1 FROM documents WHERE source_uri = ? LIMIT 1", (uri,),
            ).fetchone()
        finally:
            conn.close()
        if not row:
            return [TextContent(type="text",
                text="Refused: db URI is not in the index. "
                     "Use search first to discover valid URIs.")]

    src = CONFIG.sqlite_sources_by_name.get(db_name)
    id_column = "id"
    if src:
        for tbl in src.tables:
            if tbl.table == table:
                id_column = tbl.id_column
                break

    conn = open_external_db(db_name, hardened=True)
    try:
        result = conn.execute(
            f"SELECT * FROM {table} WHERE {id_column} = ? LIMIT 1", (row_id,),
        ).fetchone()
    except sqlite3.Error as e:
        conn.close()
        return [TextContent(type="text", text=f"DB error: {e}")]
    finally:
        conn.close()
    if not result:
        return [TextContent(type="text", text=f"Row not found: {uri}")]
    body = "\n".join(f"{k}: {result[k]}" for k in result.keys())
    return [TextContent(type="text", text=body)]


def _query_db(args: dict[str, Any]) -> list[TextContent]:
    try:
        db_name = args.get("database")
        sql_raw = args.get("sql")
        limit_raw = args.get("limit")

        if not isinstance(db_name, str) or db_name not in CONFIG.queryable_dbs:
            return [TextContent(type="text",
                text=f"Refused: unknown database. Allowed: {', '.join(CONFIG.queryable_dbs) or '(none configured)'}")]
        if not isinstance(sql_raw, str) or not sql_raw.strip():
            return [TextContent(type="text", text="Refused: 'sql' must be a non-empty string.")]

        sql = sql_raw.strip()
        if not _is_read_only(sql):
            return [TextContent(type="text",
                text="Refused: only SELECT/WITH allowed at the lexical gate. "
                     "Use a single read-only statement.")]

        limit = _coerce_int(limit_raw, CONFIG.query_db_default_limit_mcp,
                            1, CONFIG.query_db_max_limit)
        wrapped = _wrap_with_limit(sql, limit)

        conn = open_external_db(db_name, hardened=True)
        try:
            cur = conn.execute(wrapped)
            rows = []
            while len(rows) < limit:
                batch = cur.fetchmany(min(200, limit - len(rows)))
                if not batch:
                    break
                rows.extend(batch)
            cur.close()
        except sqlite3.DatabaseError as e:
            # DatabaseError is the parent of OperationalError; on Python 3.12
            # the SQLite authorizer raises DatabaseError directly, so catching
            # the broader class is necessary to map authorizer denials to the
            # "Refused: SQL not authorized" branch.
            conn.close()
            msg = str(e)
            if "not authorized" in msg.lower():
                return [TextContent(type="text",
                    text=f"Refused: SQL not authorized (writes/ATTACH/extensions are blocked): {msg}")]
            return [TextContent(type="text",
                text=f"SQL error: {msg}\n\nTip: rewrite as a single explicit SELECT.")]
        except sqlite3.Error as e:
            conn.close()
            return [TextContent(type="text", text=f"DB error: {type(e).__name__}: {e}")]
        finally:
            try:
                conn.close()
            except Exception:
                pass

        payload = [dict(r) for r in rows]
        suffix = f"\n(capped at {limit} rows)" if len(rows) >= limit else ""
        return [TextContent(type="text",
            text=json.dumps(payload, indent=2, default=str) + suffix)]
    except Exception as e:
        return [TextContent(type="text", text=f"query_db error: {type(e).__name__}: {e}")]


def _is_read_only(sql: str) -> bool:
    s = sql.strip().lower()
    if not s:
        return False
    first = s.split(None, 1)[0]
    if first not in ("select", "with"):
        return False
    forbidden = (" insert ", " update ", " delete ", " drop ", " alter ", " create ",
                 " replace ", " attach ", " detach ", " pragma ")
    padded = f" {s} "
    return not any(f in padded for f in forbidden)


def _wrap_with_limit(sql: str, limit: int) -> str:
    body = sql.strip().rstrip(";").strip()
    return f"SELECT * FROM ({body}) LIMIT {int(limit)}"


def _coerce_int(raw, default: int, lo: int, hi: int) -> int:
    if raw is None:
        return default
    try:
        v = int(raw)
    except (TypeError, ValueError):
        return default
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v


def main() -> None:
    """MCP server entry point.

    Configuration is read from `recall.config` at module-import time, which
    resolves the config path from the `RECALL_CONFIG` env var (or
    `RECALL_HOME`, or the default `~/.steward/recall/config.toml`). Pass
    config via env var when launching:

        RECALL_CONFIG=/path/to/config.toml python -m recall.mcp_server
    """
    asyncio.run(_run())


async def _run() -> None:
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())


if __name__ == "__main__":
    main()

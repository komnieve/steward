"""SQLite connection management. Handles sqlite-vec extension load and schema init."""

import sqlite3
from importlib import resources
from pathlib import Path

import sqlite_vec

from recall.config import CONFIG


def open_search_db(path: Path | None = None, read_only: bool = False) -> sqlite3.Connection:
    """Open the search.db with sqlite-vec loaded and FK enforcement on."""
    path = path or CONFIG.db_path
    path.parent.mkdir(parents=True, exist_ok=True)

    if read_only and path.exists():
        uri = f"file:{path}?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
    else:
        conn = sqlite3.connect(path)

    conn.row_factory = sqlite3.Row
    conn.enable_load_extension(True)
    sqlite_vec.load(conn)
    conn.enable_load_extension(False)
    conn.execute("PRAGMA foreign_keys = ON")
    if not read_only:
        # WAL is a write op; running it on a mode=ro connection raises
        # `unable to open database file`. Only configure on writable conns.
        conn.execute("PRAGMA journal_mode = WAL")
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    """Apply schema.sql idempotently and backfill new FTS tables when needed."""
    schema_sql = resources.files("recall.db").joinpath("schema.sql").read_text()
    conn.executescript(schema_sql)
    # External-content FTS5 tables (fts_documents has content=documents) need
    # their index built explicitly when added to an existing DB. Triggers cover
    # future writes, but existing rows have to be backfilled via the FTS5
    # 'rebuild' control command. fts_documents_idx is empty (only ~2 schema
    # rows) until rebuild populates it.
    docs_n = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    idx_n = conn.execute("SELECT COUNT(*) FROM fts_documents_idx").fetchone()[0]
    if docs_n > 0 and idx_n <= 2:
        conn.execute("INSERT INTO fts_documents(fts_documents) VALUES('rebuild')")
    conn.commit()


def open_external_db(name: str, *, hardened: bool = False,
                     timeout_seconds: float | None = None) -> sqlite3.Connection:
    """Open a queryable external SQLite DB read-only.

    When hardened=True, installs a read-only SQLite authorizer (denies
    ATTACH/DETACH/extension load/writes) and a progress handler that aborts
    the query if it exceeds timeout_seconds. Use hardened=True for any path
    where SQL comes from a tool surface (CLI query-db, MCP query_db).
    """
    if name not in CONFIG.queryable_dbs:
        raise ValueError(f"Unknown database: {name}. Known: {list(CONFIG.queryable_dbs)}")
    path = CONFIG.queryable_dbs[name]
    if not path.exists():
        raise FileNotFoundError(f"Database file does not exist: {path}")
    uri = f"file:{path}?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    if hardened:
        from recall.db.authorizer import (
            make_progress_handler,
            make_read_only_authorizer,
        )
        conn.set_authorizer(make_read_only_authorizer())
        if timeout_seconds is None:
            timeout_seconds = CONFIG.query_db_timeout_seconds
        handler, n = make_progress_handler(timeout_seconds)
        conn.set_progress_handler(handler, n)
    return conn


def get_meta(conn: sqlite3.Connection, key: str) -> str:
    row = conn.execute("SELECT value FROM meta WHERE key = ?", (key,)).fetchone()
    return row["value"] if row else ""


def set_meta(conn: sqlite3.Connection, key: str, value: str) -> None:
    conn.execute(
        "INSERT INTO meta(key, value) VALUES(?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        (key, value),
    )

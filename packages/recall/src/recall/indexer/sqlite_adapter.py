"""Generic SQLite source adapter.

Walks each table declared in CONFIG.sqlite_sources and yields one synthetic
document per row. Title and body are built from the configured column lists;
no per-table format functions are hardcoded. The optional WHERE clause comes
from trusted config only — never from user/MCP input.
"""

import hashlib
import sqlite3
from typing import Iterator

from recall.config import CONFIG, SqliteSource, SqliteTable
from recall.indexer.chunker import Chunk
from recall.indexer.markdown_adapter import SourceDoc


def _hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def _row_value(row: sqlite3.Row, column: str) -> str:
    if column not in row.keys():
        return ""
    val = row[column]
    return "" if val is None else str(val)


def _build_title(row: sqlite3.Row, columns: tuple[str, ...], fallback: str) -> str:
    if not columns:
        return fallback
    parts = [v for v in (_row_value(row, c) for c in columns) if v]
    return " — ".join(parts) if parts else fallback


def _build_text(row: sqlite3.Row, columns: tuple[str, ...]) -> str:
    if not columns:
        keys = row.keys()
    else:
        keys = [c for c in columns if c in row.keys()]
    lines = []
    for c in keys:
        v = _row_value(row, c)
        if v:
            lines.append(f"{c}: {v}")
    return "\n".join(lines)


def _has_text(text: str) -> bool:
    return bool(text and text.strip())


def _iter_table_rows(conn: sqlite3.Connection, tbl: SqliteTable) -> Iterator[sqlite3.Row]:
    sql = f"SELECT * FROM {tbl.table}"
    if tbl.where:
        sql += f" WHERE {tbl.where}"
    yield from conn.execute(sql)


def _iter_source_docs(source: SqliteSource) -> Iterator[SourceDoc]:
    if not source.path.exists():
        return
    try:
        conn = sqlite3.connect(f"file:{source.path}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
    except Exception:
        return
    try:
        for tbl in source.tables:
            for row in _iter_table_rows(conn, tbl):
                row_id = _row_value(row, tbl.id_column)
                if not row_id:
                    continue
                text = _build_text(row, tbl.text_columns)
                if not _has_text(text):
                    continue
                title = _build_title(row, tbl.title_columns, fallback=f"{source.name}/{tbl.table}/{row_id}")
                modified = ""
                if tbl.modified_column:
                    modified = _row_value(row, tbl.modified_column)
                source_uri = f"db://{source.name}/{tbl.table}/{row_id}"
                yield SourceDoc(
                    source_uri=source_uri,
                    source_type="db_row",
                    source_adapter="sqlite_table",
                    title=title,
                    modified_at=modified,
                    content_hash=_hash(text),
                    metadata={"db": source.name, "table": tbl.table, "row_id": row_id},
                    chunks=[Chunk(
                        text=text,
                        section_heading=f"{source.name}/{tbl.table}",
                        start_line=1,
                        end_line=text.count("\n") + 1,
                    )],
                )
    finally:
        conn.close()


def iter_sqlite_docs() -> Iterator[SourceDoc]:
    for source in CONFIG.sqlite_sources:
        yield from _iter_source_docs(source)


def allowed_tables(db_name: str) -> set[str]:
    """Tables the indexer walks for a given DB name. Used by the fetch URI
    whitelist in the MCP server."""
    src = CONFIG.sqlite_sources_by_name.get(db_name)
    if not src:
        return set()
    return {t.table for t in src.tables}

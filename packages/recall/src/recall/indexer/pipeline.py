"""Indexing orchestrator. Walks all sources, hashes, embeds dirty, upserts, prunes deletes."""

import json
import sqlite3
import struct
import time
from dataclasses import dataclass
from typing import Iterator

import sqlite_vec

from recall.config import CONFIG
from recall.db.connection import init_schema, open_search_db, set_meta
from recall.indexer.embed import embed, embedding_dim, model_id
from recall.indexer.lock import IndexLockHeld, index_lock
from recall.indexer.markdown_adapter import SourceDoc, iter_markdown_docs
from recall.indexer.sqlite_adapter import iter_sqlite_docs


@dataclass
class IndexStats:
    scanned: int = 0
    new: int = 0
    updated: int = 0
    unchanged: int = 0
    deleted: int = 0
    chunks_embedded: int = 0
    duration_sec: float = 0.0


def _vec_to_bytes(vec) -> bytes:
    return sqlite_vec.serialize_float32(vec.tolist())


def _all_sources() -> Iterator[SourceDoc]:
    yield from iter_markdown_docs()
    yield from iter_sqlite_docs()


def _existing_hashes(conn: sqlite3.Connection) -> dict[str, tuple[int, str]]:
    rows = conn.execute("SELECT id, source_uri, content_hash FROM documents").fetchall()
    return {r["source_uri"]: (r["id"], r["content_hash"]) for r in rows}


def _replace_doc(conn: sqlite3.Connection, doc: SourceDoc, doc_id: int | None) -> int:
    """Insert or replace a document and its chunks. Returns document id."""
    now = str(int(time.time()))
    metadata_json = json.dumps(doc.metadata) if doc.metadata else None

    if doc_id is None:
        cur = conn.execute(
            "INSERT INTO documents(source_uri, source_type, source_adapter, title, "
            "modified_at, indexed_at, content_hash, metadata) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (doc.source_uri, doc.source_type, doc.source_adapter, doc.title,
             doc.modified_at, now, doc.content_hash, metadata_json),
        )
        doc_id = cur.lastrowid
    else:
        # Delete existing chunks (cascade clears vec_chunks via app logic below)
        chunk_ids = [r["id"] for r in conn.execute(
            "SELECT id FROM chunks WHERE document_id = ?", (doc_id,)
        )]
        for cid in chunk_ids:
            conn.execute("DELETE FROM vec_chunks WHERE chunk_id = ?", (cid,))
        conn.execute("DELETE FROM chunks WHERE document_id = ?", (doc_id,))
        conn.execute(
            "UPDATE documents SET source_type = ?, source_adapter = ?, title = ?, "
            "modified_at = ?, indexed_at = ?, content_hash = ?, metadata = ? "
            "WHERE id = ?",
            (doc.source_type, doc.source_adapter, doc.title,
             doc.modified_at, now, doc.content_hash, metadata_json, doc_id),
        )

    return doc_id


def _insert_chunks(conn: sqlite3.Connection, doc_id: int, doc: SourceDoc) -> list[int]:
    """Insert chunks for a doc, return list of new chunk ids in order."""
    chunk_ids: list[int] = []
    for idx, chunk in enumerate(doc.chunks):
        cur = conn.execute(
            "INSERT INTO chunks(document_id, chunk_index, text, start_line, end_line, "
            "section_heading, token_count) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (doc_id, idx, chunk.text, chunk.start_line, chunk.end_line,
             chunk.section_heading, chunk.token_count),
        )
        chunk_ids.append(cur.lastrowid)
    return chunk_ids


def _prune_deleted(conn: sqlite3.Connection, present_uris: set[str]) -> int:
    rows = conn.execute("SELECT id, source_uri FROM documents").fetchall()
    deleted = 0
    for r in rows:
        if r["source_uri"] not in present_uris:
            chunk_ids = [c["id"] for c in conn.execute(
                "SELECT id FROM chunks WHERE document_id = ?", (r["id"],)
            )]
            for cid in chunk_ids:
                conn.execute("DELETE FROM vec_chunks WHERE chunk_id = ?", (cid,))
            conn.execute("DELETE FROM documents WHERE id = ?", (r["id"],))
            deleted += 1
    return deleted


def run_index(full: bool = False, on_progress=None) -> IndexStats:
    """Walk all sources, embed dirty docs, prune deletes.

    Atomicity contract: each document is committed only after all its chunks
    have been embedded AND their vectors stored. If embedding or DB writes for
    a doc fail, the transaction rolls back so we never persist a doc whose
    `content_hash` matches the source while its `vec_chunks` are missing.

    Concurrency: holds an exclusive flock on CONFIG.lock_path for the whole
    run. If another process is already indexing, raises IndexLockHeld so the
    caller can exit cleanly instead of interleaving with the other run.
    """
    with index_lock(CONFIG.lock_path):
        return _run_index_locked(full=full, on_progress=on_progress)


def _run_index_locked(full: bool = False, on_progress=None) -> IndexStats:
    start = time.time()
    stats = IndexStats()

    conn = open_search_db()
    init_schema(conn)
    set_meta(conn, "embedding_model", model_id())
    set_meta(conn, "embedding_dim", str(embedding_dim()))
    conn.commit()

    # Always look up prior doc IDs so re-runs UPDATE rather than INSERT
    # (source_uri is UNIQUE — full=True without this would crash on conflict).
    # `full` only controls whether to skip on hash match.
    existing = _existing_hashes(conn)
    present_uris: set[str] = set()

    for doc in _all_sources():
        stats.scanned += 1
        present_uris.add(doc.source_uri)
        prior = existing.get(doc.source_uri)

        if prior and prior[1] == doc.content_hash and not full:
            stats.unchanged += 1
            continue

        # Embed BEFORE writing anything to the DB. If embedding fails we leave
        # the prior state untouched.
        try:
            vecs = embed([c.text for c in doc.chunks])
        except Exception:
            # Skip this doc; the existing index entry (if any) stays valid.
            continue

        try:
            conn.execute("BEGIN")
            doc_id = _replace_doc(conn, doc, prior[0] if prior else None)
            chunk_ids = _insert_chunks(conn, doc_id, doc)
            for cid, vec in zip(chunk_ids, vecs):
                conn.execute(
                    "INSERT INTO vec_chunks(chunk_id, embedding) VALUES (?, ?)",
                    (cid, _vec_to_bytes(vec)),
                )
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            continue

        stats.chunks_embedded += len(chunk_ids)
        if prior:
            stats.updated += 1
        else:
            stats.new += 1

        if on_progress and stats.scanned % 25 == 0:
            on_progress(stats)

    # Prune docs whose source_uri vanished from disk / the DB row source.
    stats.deleted = _prune_deleted(conn, present_uris)

    set_meta(conn, "last_full_index_at" if full else "last_incremental_index_at",
             str(int(time.time())))
    conn.commit()
    conn.close()

    stats.duration_sec = time.time() - start
    return stats

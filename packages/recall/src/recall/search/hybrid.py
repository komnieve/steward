"""Hybrid search: vector + chunk-keyword + document-metadata, fused via RRF.

Three signal streams contribute to the fused ranking:

1. Vector similarity over chunk embeddings (semantic content).
2. FTS over chunk text + section_heading (keyword content).
3. FTS over document title + source_uri (slug-style queries: file slugs find
   the right doc even when body text never repeats the slug).

Document-level FTS hits are converted to chunk-level by attributing the
doc-rank to the document's first chunk only (one representative per doc),
which keeps RRF math clean without flooding scores with N chunks per match.
"""

import sqlite3
from collections import defaultdict
from dataclasses import dataclass

import sqlite_vec

from recall.config import CONFIG
from recall.db.connection import open_search_db
from recall.indexer.embed import embed_query


@dataclass
class SearchResult:
    chunk_id: int
    document_id: int
    source_uri: str
    source_type: str
    title: str
    section_heading: str | None
    text: str
    score: float
    vec_rank: int | None
    fts_rank: int | None
    fts_doc_rank: int | None


def _vec_search(conn: sqlite3.Connection, query: str, k: int) -> list[tuple[int, float]]:
    vec = embed_query(query)
    blob = sqlite_vec.serialize_float32(vec.tolist())
    rows = conn.execute(
        """
        SELECT chunk_id, distance
        FROM vec_chunks
        WHERE embedding MATCH ? AND k = ?
        ORDER BY distance
        """,
        (blob, k),
    ).fetchall()
    return [(r["chunk_id"], r["distance"]) for r in rows]


def _fts_search(conn: sqlite3.Connection, query: str, k: int) -> list[tuple[int, float]]:
    fts_query = _build_fts_query(query)
    rows = conn.execute(
        """
        SELECT rowid, rank
        FROM fts_chunks
        WHERE fts_chunks MATCH ?
        ORDER BY rank
        LIMIT ?
        """,
        (fts_query, k),
    ).fetchall()
    return [(r["rowid"], r["rank"]) for r in rows]


def _fts_documents_search(conn: sqlite3.Connection, query: str, k: int) -> list[tuple[int, float]]:
    """FTS over document title + source_uri. Returns (document_id, rank)."""
    fts_query = _build_fts_query(query)
    rows = conn.execute(
        """
        SELECT rowid AS doc_id, rank
        FROM fts_documents
        WHERE fts_documents MATCH ?
        ORDER BY rank
        LIMIT ?
        """,
        (fts_query, k),
    ).fetchall()
    return [(r["doc_id"], r["rank"]) for r in rows]


def _representative_chunks(conn: sqlite3.Connection, doc_ids: list[int]) -> dict[int, int]:
    """For each doc_id, return the first chunk's id. Used to map doc-level
    FTS hits onto a single representative chunk for RRF fusion."""
    if not doc_ids:
        return {}
    placeholders = ",".join("?" * len(doc_ids))
    rows = conn.execute(
        f"""
        SELECT document_id, MIN(id) AS chunk_id
        FROM chunks
        WHERE document_id IN ({placeholders})
        GROUP BY document_id
        """,
        doc_ids,
    ).fetchall()
    return {r["document_id"]: r["chunk_id"] for r in rows}


def _build_fts_query(query: str) -> str:
    """Build an FTS5 query that's permissive (OR across terms) and quote-safe."""
    cleaned = []
    for tok in query.split():
        tok = tok.strip().strip("\"'.,;:!?()[]{}")
        if not tok:
            continue
        if any(c in tok for c in "*\""):
            continue
        cleaned.append(f'"{tok}"')
    if not cleaned:
        return f'"{query.replace(chr(34), "")}"'
    return " OR ".join(cleaned)


def _hydrate(conn: sqlite3.Connection, chunk_ids: list[int]) -> dict[int, sqlite3.Row]:
    if not chunk_ids:
        return {}
    placeholders = ",".join("?" * len(chunk_ids))
    rows = conn.execute(
        f"""
        SELECT c.id AS chunk_id, c.text, c.section_heading,
               c.document_id, d.source_uri, d.source_type, d.title
        FROM chunks c
        JOIN documents d ON d.id = c.document_id
        WHERE c.id IN ({placeholders})
        """,
        chunk_ids,
    ).fetchall()
    return {r["chunk_id"]: r for r in rows}


def _run_three_searches(conn: sqlite3.Connection, query: str):
    """Returns (vec_hits, fts_chunk_hits, fts_doc_hits). Tolerates FTS parse
    errors (rare with our cleaning pass) by returning empty lists for failures."""
    try:
        vec_hits = _vec_search(conn, query, CONFIG.vec_top_k)
    except sqlite3.OperationalError:
        vec_hits = []
    try:
        fts_chunk_hits = _fts_search(conn, query, CONFIG.fts_top_k)
    except sqlite3.OperationalError:
        fts_chunk_hits = []
    try:
        fts_doc_hits = _fts_documents_search(conn, query, CONFIG.fts_top_k)
    except sqlite3.OperationalError:
        fts_doc_hits = []
    return vec_hits, fts_chunk_hits, fts_doc_hits


def _fuse(vec_hits, fts_chunk_hits, fts_doc_hits, doc_to_chunk):
    """RRF-fuse three signal streams. Returns (scores, vec_rank, fts_rank,
    fts_doc_rank) all keyed by chunk_id."""
    rrf = CONFIG.rrf_k
    scores: dict[int, float] = defaultdict(float)
    vec_rank: dict[int, int] = {}
    fts_rank: dict[int, int] = {}
    fts_doc_rank: dict[int, int] = {}

    for rank, (cid, _) in enumerate(vec_hits):
        scores[cid] += 1.0 / (rrf + rank)
        vec_rank[cid] = rank

    for rank, (cid, _) in enumerate(fts_chunk_hits):
        scores[cid] += 1.0 / (rrf + rank)
        fts_rank[cid] = rank

    for rank, (doc_id, _) in enumerate(fts_doc_hits):
        cid = doc_to_chunk.get(doc_id)
        if cid is None:
            continue
        scores[cid] += 1.0 / (rrf + rank)
        fts_doc_rank[cid] = rank

    return scores, vec_rank, fts_rank, fts_doc_rank


def hybrid_search(
    query: str,
    k: int = 10,
    source_type: list[str] | None = None,
) -> list[SearchResult]:
    conn = open_search_db(read_only=True)
    try:
        vec_hits, fts_chunk_hits, fts_doc_hits = _run_three_searches(conn, query)
        doc_ids = [d for d, _ in fts_doc_hits]
        doc_to_chunk = _representative_chunks(conn, doc_ids)
        scores, vec_rank, fts_rank, fts_doc_rank = _fuse(
            vec_hits, fts_chunk_hits, fts_doc_hits, doc_to_chunk
        )

        if not scores:
            return []

        sorted_ids = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        all_ids = [cid for cid, _ in sorted_ids]
        rows = _hydrate(conn, all_ids)

        results: list[SearchResult] = []
        doc_chunk_count: dict[int, int] = defaultdict(int)
        for cid, score in sorted_ids:
            row = rows.get(cid)
            if not row:
                continue
            if source_type and row["source_type"] not in source_type:
                continue
            if doc_chunk_count[row["document_id"]] >= 2:
                continue
            doc_chunk_count[row["document_id"]] += 1
            results.append(SearchResult(
                chunk_id=cid,
                document_id=row["document_id"],
                source_uri=row["source_uri"],
                source_type=row["source_type"],
                title=row["title"] or "",
                section_heading=row["section_heading"],
                text=row["text"],
                score=score,
                vec_rank=vec_rank.get(cid),
                fts_rank=fts_rank.get(cid),
                fts_doc_rank=fts_doc_rank.get(cid),
            ))
            if len(results) >= k:
                break
        return results
    finally:
        conn.close()


def debug_search(query: str, expected_substring: str | None = None) -> dict:
    """Per-signal diagnostic. Returns the raw vector / FTS-chunk / FTS-doc
    hit lists with source URIs, plus the fused top-50 and (optionally) where
    the expected substring shows up in each.
    """
    conn = open_search_db(read_only=True)
    try:
        vec_hits, fts_chunk_hits, fts_doc_hits = _run_three_searches(conn, query)
        doc_ids = [d for d, _ in fts_doc_hits]
        doc_to_chunk = _representative_chunks(conn, doc_ids)
        scores, vec_rank, fts_rank, fts_doc_rank = _fuse(
            vec_hits, fts_chunk_hits, fts_doc_hits, doc_to_chunk
        )

        # Hydrate everything we touched
        all_chunk_ids = set()
        all_chunk_ids.update(c for c, _ in vec_hits)
        all_chunk_ids.update(c for c, _ in fts_chunk_hits)
        all_chunk_ids.update(doc_to_chunk.values())
        rows_by_cid = _hydrate(conn, list(all_chunk_ids))

        # Doc rows for fts_doc_hits (some may not have chunks → no rep chunk)
        doc_rows = {}
        if doc_ids:
            ph = ",".join("?" * len(doc_ids))
            for r in conn.execute(
                f"SELECT id, title, source_uri, source_type FROM documents WHERE id IN ({ph})",
                doc_ids,
            ):
                doc_rows[r["id"]] = r

        def _row_label(cid):
            r = rows_by_cid.get(cid)
            if not r:
                return f"<chunk {cid}>"
            return f"{r['source_type']} | {r['title'][:60]} | {r['source_uri']}"

        def _doc_label(did):
            r = doc_rows.get(did)
            if not r:
                return f"<doc {did}>"
            return f"{r['source_type']} | {r['title'][:60]} | {r['source_uri']}"

        sorted_fused = sorted(scores.items(), key=lambda x: x[1], reverse=True)

        out = {
            "query": query,
            "vec_top": [
                {"rank": i, "chunk_id": cid, "distance": d, "label": _row_label(cid)}
                for i, (cid, d) in enumerate(vec_hits)
            ],
            "fts_chunks_top": [
                {"rank": i, "chunk_id": cid, "fts_rank_score": s, "label": _row_label(cid)}
                for i, (cid, s) in enumerate(fts_chunk_hits)
            ],
            "fts_documents_top": [
                {"rank": i, "doc_id": did, "fts_rank_score": s, "label": _doc_label(did)}
                for i, (did, s) in enumerate(fts_doc_hits)
            ],
            "fused_top": [
                {
                    "rank": i,
                    "chunk_id": cid,
                    "score": round(score, 5),
                    "vec_rank": vec_rank.get(cid),
                    "fts_rank": fts_rank.get(cid),
                    "fts_doc_rank": fts_doc_rank.get(cid),
                    "label": _row_label(cid),
                }
                for i, (cid, score) in enumerate(sorted_fused)
            ],
        }

        if expected_substring:
            needle = expected_substring.lower()
            def _hit(label): return needle in label.lower()
            out["expected"] = {
                "substring": expected_substring,
                "vec_first_match_rank": next((h["rank"] for h in out["vec_top"] if _hit(h["label"])), None),
                "fts_chunks_first_match_rank": next((h["rank"] for h in out["fts_chunks_top"] if _hit(h["label"])), None),
                "fts_documents_first_match_rank": next((h["rank"] for h in out["fts_documents_top"] if _hit(h["label"])), None),
                "fused_first_match_rank": next((h["rank"] for h in out["fused_top"] if _hit(h["label"])), None),
            }
        return out
    finally:
        conn.close()

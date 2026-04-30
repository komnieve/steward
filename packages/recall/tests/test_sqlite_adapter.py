"""Tests for the generic config-driven SQLite source adapter."""

from __future__ import annotations

from pathlib import Path

from recall.config import CONFIG, SqliteSource, SqliteTable
from recall.indexer.sqlite_adapter import allowed_tables, iter_sqlite_docs


def test_allowed_tables_for_unknown_db():
    assert allowed_tables("does-not-exist") == set()


def test_iter_sqlite_docs_with_journal(monkeypatch, journal_db: Path):
    sources = [
        SqliteSource(
            name="journal",
            path=journal_db,
            queryable=True,
            tables=(
                SqliteTable(
                    table="entries",
                    id_column="id",
                    modified_column="updated_at",
                    title_columns=("topic",),
                    text_columns=("created_at", "topic", "body"),
                    where="body IS NOT NULL AND trim(body) != ''",
                ),
            ),
        )
    ]
    monkeypatch.setattr(CONFIG, "sqlite_sources", sources)

    docs = list(iter_sqlite_docs())

    # Two real entries plus one with empty body that the WHERE clause filters.
    assert len(docs) == 2
    uris = {d.source_uri for d in docs}
    assert "db://journal/entries/1" in uris
    assert "db://journal/entries/2" in uris

    titles = {d.title for d in docs}
    assert "first entry" in titles
    assert "second entry" in titles

    first = next(d for d in docs if d.source_uri == "db://journal/entries/1")
    assert "kicked off project alpha" in first.chunks[0].text
    assert first.modified_at == "2024-01-02"
    assert first.metadata == {"db": "journal", "table": "entries", "row_id": "1"}


def test_allowed_tables_returns_configured_set(monkeypatch, journal_db: Path):
    sources = [
        SqliteSource(
            name="journal",
            path=journal_db,
            tables=(SqliteTable(table="entries"), SqliteTable(table="other")),
        )
    ]
    monkeypatch.setattr(CONFIG, "sqlite_sources", sources)
    assert allowed_tables("journal") == {"entries", "other"}


def test_iter_sqlite_docs_skips_missing_db(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(CONFIG, "sqlite_sources", [
        SqliteSource(
            name="ghost",
            path=tmp_path / "does-not-exist.db",
            tables=(SqliteTable(table="entries"),),
        )
    ])
    assert list(iter_sqlite_docs()) == []

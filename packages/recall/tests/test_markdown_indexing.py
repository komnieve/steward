"""Tests for the markdown adapter walking and chunking files."""

from __future__ import annotations

from pathlib import Path

from recall.config import CONFIG, MarkdownSource
from recall.indexer.markdown_adapter import iter_markdown_docs


def test_iter_markdown_docs_indexes_fixtures(monkeypatch, notes_dir: Path):
    monkeypatch.setattr(CONFIG, "markdown_sources", [
        MarkdownSource(name="test", path=notes_dir, extensions=(".md", ".txt")),
    ])
    docs = list(iter_markdown_docs())

    titles = {d.title for d in docs}
    assert "decision-log" in titles
    assert "project-alpha" in titles
    assert "meeting-notes" in titles


def test_iter_markdown_docs_skips_excluded_dirs(monkeypatch, tmp_path: Path):
    """Files inside an excluded dir name (e.g. `.venv`) must never be indexed.

    Built at runtime: a committed `.venv/` fixture would be silently dropped
    by .gitignore, so the test would pass for the wrong reason in a clean
    clone."""
    real = tmp_path / "real-note.md"
    real.write_text("# real note\n\nbody")
    excluded = tmp_path / ".venv"
    excluded.mkdir()
    (excluded / "should-be-skipped.md").write_text("# skipped\n\nbody")

    monkeypatch.setattr(CONFIG, "markdown_sources", [
        MarkdownSource(name="test", path=tmp_path, extensions=(".md", ".txt")),
    ])
    docs = list(iter_markdown_docs())
    uris = [d.source_uri for d in docs]

    assert any("real-note.md" in u for u in uris), "real note should be indexed"
    for u in uris:
        assert "/.venv/" not in u, f"walker indexed an excluded-dir file: {u}"


def test_iter_markdown_docs_respects_extensions(monkeypatch, tmp_path: Path):
    md = tmp_path / "a.md"
    md.write_text("# md file\n\nbody")
    txt = tmp_path / "b.txt"
    txt.write_text("plain text body")
    skip = tmp_path / "c.log"
    skip.write_text("not indexed")

    monkeypatch.setattr(CONFIG, "markdown_sources", [
        MarkdownSource(name="test", path=tmp_path, extensions=(".md",)),
    ])
    docs = list(iter_markdown_docs())
    titles = {d.title for d in docs}
    assert "a" in titles
    assert "b" not in titles  # .txt not in extensions
    assert "c" not in titles  # .log not in extensions

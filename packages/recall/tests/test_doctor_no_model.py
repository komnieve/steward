"""Verify `recall doctor` (no --model flag) does NOT load the embedding model.

If we accidentally call `recall.indexer.embed._model()` during plain doctor,
the test patches it to raise — so any invocation explodes loudly.
"""

from __future__ import annotations

from pathlib import Path

import pytest
from typer.testing import CliRunner

from recall.cli import app
from recall.config import CONFIG


@pytest.fixture
def runner():
    return CliRunner()


def _isolate_db(monkeypatch, tmp_path: Path):
    """Point the global CONFIG at a tmp DB path that does not exist yet —
    doctor will report it missing rather than trying to open."""
    monkeypatch.setattr(CONFIG, "db_path", tmp_path / "search.db")
    monkeypatch.setattr(CONFIG, "lock_path", tmp_path / "index.lock")
    monkeypatch.setattr(CONFIG, "sqlite_sources", [])


def test_doctor_without_model_does_not_load_embedder(monkeypatch, tmp_path: Path, runner):
    _isolate_db(monkeypatch, tmp_path)

    calls = {"count": 0}

    def boom():
        calls["count"] += 1
        raise AssertionError("doctor (no --model) must not load the embedding model")

    # Patch the lazy loader. doctor without --model should never call this.
    import recall.indexer.embed as embed_mod
    monkeypatch.setattr(embed_mod, "_model", boom)

    result = runner.invoke(app, ["doctor"])
    # Doctor will exit non-zero because search.db is missing — that's fine.
    # We only care that _model() was not invoked.
    assert calls["count"] == 0, "doctor (no --model) called the embedding loader"
    # And it should mention the missing DB so we know we actually ran doctor.
    assert "search.db missing" in result.stdout or "search.db missing" in result.output


def test_doctor_with_model_attempts_load(monkeypatch, tmp_path: Path, runner):
    _isolate_db(monkeypatch, tmp_path)

    calls = {"count": 0}

    def stub_model():
        calls["count"] += 1
        return object()

    import recall.indexer.embed as embed_mod
    monkeypatch.setattr(embed_mod, "_model", stub_model)

    result = runner.invoke(app, ["doctor", "--model"])
    assert calls["count"] >= 1, "doctor --model must attempt the embedding load"
    # Output should announce the --model checks block
    assert "--model checks" in result.output or "embedding model" in result.output

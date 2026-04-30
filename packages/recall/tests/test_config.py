"""Tests for config loading and defaults."""

from __future__ import annotations

import os
from pathlib import Path

from recall.config import (
    DEFAULT_EMBEDDING_DEVICE,
    DEFAULT_EMBEDDING_MODEL,
    Config,
    SqliteSource,
    _load_config_from_toml,
    _public_default_config,
)


def test_public_defaults_steward_only():
    cfg = _public_default_config()
    assert len(cfg.markdown_sources) == 1
    only = cfg.markdown_sources[0]
    assert only.name == "steward"
    assert ".steward" in str(only.path)
    assert cfg.sqlite_sources == []
    assert cfg.embedding_device == DEFAULT_EMBEDDING_DEVICE
    assert cfg.embedding_model == DEFAULT_EMBEDDING_MODEL


def test_toml_load_basic(tmp_path: Path):
    toml = tmp_path / "config.toml"
    toml.write_text(
        f"""
[index]
db_path   = "{tmp_path}/search.db"
lock_path = "{tmp_path}/index.lock"

[embedding]
device = "cpu"

[[markdown_sources]]
name = "notes"
path = "{tmp_path}/notes"
extensions = [".md"]

[[sqlite_sources]]
name = "journal"
path = "{tmp_path}/journal.db"
queryable = true

  [[sqlite_sources.tables]]
  table         = "entries"
  id_column     = "id"
  title_columns = ["topic"]
  text_columns  = ["topic", "body"]
"""
    )
    cfg = _load_config_from_toml(toml)
    assert cfg.db_path == tmp_path / "search.db"
    assert cfg.lock_path == tmp_path / "index.lock"
    assert cfg.embedding_device == "cpu"

    assert len(cfg.markdown_sources) == 1
    src = cfg.markdown_sources[0]
    assert src.name == "notes"
    assert src.extensions == (".md",)

    assert len(cfg.sqlite_sources) == 1
    sql = cfg.sqlite_sources[0]
    assert sql.name == "journal"
    assert sql.queryable is True
    assert sql.tables[0].table == "entries"
    assert sql.tables[0].title_columns == ("topic",)


def test_queryable_dbs_property(tmp_path: Path):
    cfg = Config(
        db_path=tmp_path / "search.db",
        lock_path=tmp_path / "lock",
        sqlite_sources=[
            SqliteSource(name="public", path=tmp_path / "p.db", queryable=True),
            SqliteSource(name="hidden", path=tmp_path / "h.db", queryable=False),
        ],
    )
    assert "public" in cfg.queryable_dbs
    assert "hidden" not in cfg.queryable_dbs
    assert cfg.queryable_dbs["public"] == tmp_path / "p.db"


def test_path_expansion(tmp_path: Path):
    """~ and $VAR should expand in TOML paths."""
    os.environ["RECALL_TEST_DIR"] = str(tmp_path)
    try:
        toml = tmp_path / "config.toml"
        toml.write_text(
            """
[index]
db_path = "$RECALL_TEST_DIR/search.db"
lock_path = "~/should-have-tilde-expanded.lock"

[[markdown_sources]]
name = "notes"
path = "$RECALL_TEST_DIR/notes"
"""
        )
        cfg = _load_config_from_toml(toml)
        assert cfg.db_path == tmp_path / "search.db"
        # Tilde expansion: starts with the user's home, not literally "~"
        assert "~" not in str(cfg.lock_path)
        assert cfg.markdown_sources[0].path == tmp_path / "notes"
    finally:
        os.environ.pop("RECALL_TEST_DIR", None)

"""Shared pytest fixtures.

Each test gets a fresh `RECALL_HOME` so the global `CONFIG` (which is built at
package import time from environment / TOML) is isolated per session. Tests
that need to override individual fields on the already-loaded CONFIG do so
via `monkeypatch.setattr(CONFIG, "field", ...)`.
"""

from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest

PACKAGE_SRC = Path(__file__).resolve().parents[1] / "src"
if str(PACKAGE_SRC) not in sys.path:
    sys.path.insert(0, str(PACKAGE_SRC))


@pytest.fixture
def fixtures_dir() -> Path:
    return Path(__file__).resolve().parent / "fixtures"


@pytest.fixture
def notes_dir(fixtures_dir: Path) -> Path:
    return fixtures_dir / "notes"


@pytest.fixture
def journal_db(tmp_path: Path) -> Path:
    """A tiny SQLite db with a `journal/entries` table for adapter tests."""
    db_path = tmp_path / "journal.db"
    conn = sqlite3.connect(db_path)
    conn.executescript(
        """
        CREATE TABLE entries (
            id INTEGER PRIMARY KEY,
            created_at TEXT,
            updated_at TEXT,
            topic TEXT,
            body TEXT
        );
        INSERT INTO entries (id, created_at, updated_at, topic, body) VALUES
            (1, '2024-01-01', '2024-01-02', 'first entry', 'kicked off project alpha'),
            (2, '2024-01-05', '2024-01-05', 'second entry', 'wrote the architecture doc'),
            (3, '2024-01-10', '2024-01-10', 'empty body skipped', '');
        """
    )
    conn.commit()
    conn.close()
    return db_path

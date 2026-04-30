"""Tests for the read-only SQLite authorizer."""

from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from recall.db.authorizer import make_progress_handler, make_read_only_authorizer


@pytest.fixture
def hardened_db(tmp_path: Path) -> sqlite3.Connection:
    """A SQLite connection with a tiny schema and the read-only authorizer
    installed. We open in read-write mode so any DENY actually surfaces as
    sqlite3.OperationalError (`mode=ro` would short-circuit some of them at
    the open layer)."""
    db = tmp_path / "x.db"
    conn = sqlite3.connect(db)
    conn.executescript(
        """
        CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT);
        INSERT INTO t (name) VALUES ('a'), ('b'), ('c');
        """
    )
    conn.commit()
    conn.set_authorizer(make_read_only_authorizer())
    return conn


# Python's sqlite3 module historically raised OperationalError for authorizer
# denials, but Python 3.12 raises DatabaseError directly. Catch the broader
# DatabaseError (parent class) for portability across versions.
DENIED = sqlite3.DatabaseError


def test_select_allowed(hardened_db):
    rows = hardened_db.execute("SELECT name FROM t ORDER BY id").fetchall()
    assert [r[0] for r in rows] == ["a", "b", "c"]


def test_with_cte_allowed(hardened_db):
    rows = hardened_db.execute(
        "WITH x AS (SELECT name FROM t) SELECT * FROM x"
    ).fetchall()
    assert len(rows) == 3


def test_insert_denied(hardened_db):
    with pytest.raises(DENIED):
        hardened_db.execute("INSERT INTO t (name) VALUES ('z')")


def test_update_denied(hardened_db):
    with pytest.raises(DENIED):
        hardened_db.execute("UPDATE t SET name = 'z'")


def test_delete_denied(hardened_db):
    with pytest.raises(DENIED):
        hardened_db.execute("DELETE FROM t")


def test_drop_denied(hardened_db):
    with pytest.raises(DENIED):
        hardened_db.execute("DROP TABLE t")


def test_create_denied(hardened_db):
    with pytest.raises(DENIED):
        hardened_db.execute("CREATE TABLE u (id INTEGER PRIMARY KEY)")


def test_attach_denied(hardened_db, tmp_path: Path):
    other = tmp_path / "other.db"
    sqlite3.connect(other).close()
    with pytest.raises(DENIED):
        hardened_db.execute(f"ATTACH DATABASE '{other}' AS other_db")


def test_pragma_writable_denied(hardened_db):
    with pytest.raises(DENIED):
        hardened_db.execute("PRAGMA journal_mode = WAL")


def test_pragma_introspection_allowed(hardened_db):
    rows = hardened_db.execute("PRAGMA table_info(t)").fetchall()
    assert any(r[1] == "name" for r in rows)


def test_progress_handler_returns_callable():
    handler, n = make_progress_handler(60.0)
    assert callable(handler)
    assert isinstance(n, int) and n > 0
    # Within budget → returns 0 (don't abort)
    assert handler() == 0

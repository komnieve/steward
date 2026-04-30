"""Tests for the pure helpers in mcp_server (lexical SQL gate, limit clamp,
int coercion). Avoids spinning up the actual MCP server runtime."""

from __future__ import annotations

from recall.mcp_server import _coerce_int, _is_read_only, _wrap_with_limit


def test_is_read_only_accepts_select():
    assert _is_read_only("SELECT 1") is True
    assert _is_read_only("  select * from t") is True


def test_is_read_only_accepts_with_cte():
    assert _is_read_only("WITH x AS (SELECT 1) SELECT * FROM x") is True


def test_is_read_only_rejects_writes():
    for sql in (
        "INSERT INTO t VALUES (1)",
        "UPDATE t SET a=1",
        "DELETE FROM t",
        "DROP TABLE t",
        "ALTER TABLE t ADD COLUMN x INT",
        "CREATE TABLE u (id INT)",
        "REPLACE INTO t VALUES (1)",
    ):
        assert _is_read_only(sql) is False, f"should reject: {sql!r}"


def test_is_read_only_rejects_attach_and_pragma():
    assert _is_read_only("ATTACH DATABASE 'x.db' AS x") is False
    assert _is_read_only("DETACH DATABASE x") is False
    assert _is_read_only("PRAGMA journal_mode = WAL") is False


def test_is_read_only_rejects_mixed_statements():
    """Defense-in-depth: a write keyword anywhere in the query trips the gate."""
    assert _is_read_only("SELECT 1; INSERT INTO t VALUES (1)") is False


def test_is_read_only_rejects_empty():
    assert _is_read_only("") is False
    assert _is_read_only("   ") is False


def test_wrap_with_limit_strips_trailing_semicolon():
    out = _wrap_with_limit("SELECT * FROM t ;", 10)
    assert "LIMIT 10" in out
    assert ";" not in out.rstrip()


def test_wrap_with_limit_handles_with():
    out = _wrap_with_limit("WITH x AS (SELECT 1) SELECT * FROM x", 25)
    assert "LIMIT 25" in out


def test_coerce_int_clamps_low():
    assert _coerce_int(0, 10, 1, 100) == 1
    assert _coerce_int(-5, 10, 1, 100) == 1


def test_coerce_int_clamps_high():
    assert _coerce_int(9999, 10, 1, 100) == 100


def test_coerce_int_accepts_in_range():
    assert _coerce_int(42, 10, 1, 100) == 42


def test_coerce_int_uses_default_for_none_or_garbage():
    assert _coerce_int(None, 10, 1, 100) == 10
    assert _coerce_int("not a number", 10, 1, 100) == 10

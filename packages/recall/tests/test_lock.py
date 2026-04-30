"""Tests for the index lock — cross-platform via filelock."""

from __future__ import annotations

from pathlib import Path

import pytest

from recall.indexer.lock import IndexLockHeld, index_lock


def test_lock_acquire_and_release(tmp_path: Path):
    lock_path = tmp_path / "index.lock"
    with index_lock(lock_path):
        assert lock_path.exists()
    # After release the lock file may or may not be present (filelock leaves
    # it on disk by default), but it must be re-acquirable.
    with index_lock(lock_path):
        pass


def test_lock_double_acquire_raises(tmp_path: Path):
    lock_path = tmp_path / "index.lock"
    with index_lock(lock_path):
        with pytest.raises(IndexLockHeld):
            with index_lock(lock_path):
                pass

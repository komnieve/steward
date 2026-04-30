"""Process-level lock for `recall index` to prevent overlapping runs.

Uses the `filelock` library so the lock works on macOS, Linux, and Windows.
The lock is non-blocking: if another process holds it, IndexLockHeld is
raised rather than queueing.
"""

import os
from contextlib import contextmanager
from pathlib import Path

from filelock import FileLock, Timeout


class IndexLockHeld(Exception):
    """Raised when another `recall index` process holds the lock."""


@contextmanager
def index_lock(lock_path: Path):
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock = FileLock(str(lock_path))
    try:
        lock.acquire(timeout=0)
    except Timeout:
        raise IndexLockHeld(
            f"Another recall index run is in progress (lock: {lock_path})."
        )
    pid_marker = lock_path.with_suffix(lock_path.suffix + ".pid")
    try:
        try:
            pid_marker.write_text(str(os.getpid()))
        except OSError:
            pass
        yield
    finally:
        try:
            if pid_marker.exists():
                pid_marker.unlink()
        except OSError:
            pass
        lock.release()

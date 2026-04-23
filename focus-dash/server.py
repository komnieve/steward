#!/usr/bin/env python3
"""Focus dashboard HTTP server.

Serves static files + SSE push when priorities.json changes + a small
JSON API backing the dashboard:

  GET  /events            server-sent events, pushes on priorities.json mtime change
  GET  /api/focus         recent focus_log entries + today's counters
  POST /api/mark-done     move a priority from today[] into done[], append to activity.db
  POST /api/mark-undone   reverse (move back from done to top of today)
  GET  /api/now           server-side 'monday afternoon' etc.
"""
import contextlib
import fcntl
import io
import json
import os
import queue
import sqlite3
import subprocess
import threading
import time
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.abspath(__file__))
STEWARD_HOME = os.environ.get("STEWARD_HOME") or os.path.dirname(ROOT)
PRIORITIES = os.environ.get("STEWARD_PRIORITIES") or os.path.join(ROOT, "priorities.json")
FOCUS_DB = os.environ.get("STEWARD_FOCUS_DB") or os.path.join(STEWARD_HOME, "personas", "focus", "focus.db")
ACTIVITY_DB = os.environ.get("STEWARD_ACTIVITY_DB") or os.path.join(STEWARD_HOME, "activity.db")
PORT = int(os.environ.get("FOCUS_DASH_PORT", "8888"))

_subs: list[queue.Queue] = []
_subs_lock = threading.Lock()
_priorities_write_lock = threading.Lock()


def _subscribe() -> queue.Queue:
    q: queue.Queue = queue.Queue(maxsize=16)
    with _subs_lock:
        _subs.append(q)
    return q


def _unsubscribe(q: queue.Queue) -> None:
    with _subs_lock:
        if q in _subs:
            _subs.remove(q)


def _broadcast(event: str) -> None:
    with _subs_lock:
        dead = []
        for q in _subs:
            try:
                q.put_nowait(event)
            except queue.Full:
                dead.append(q)
        for q in dead:
            _subs.remove(q)


def _watcher() -> None:
    last = 0.0
    while True:
        try:
            mtime = os.path.getmtime(PRIORITIES)
            if mtime != last:
                if last != 0.0:
                    _broadcast(f"update:{int(mtime)}")
                last = mtime
        except FileNotFoundError:
            pass
        time.sleep(0.4)


@contextlib.contextmanager
def _locked_priorities():
    """Read-modify-write priorities.json under a flock."""
    with _priorities_write_lock:
        fd = os.open(PRIORITIES, os.O_RDWR | os.O_CREAT)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            raw = os.read(fd, 10 * 1024 * 1024).decode("utf-8") or "{}"
            data = json.loads(raw)
            yield data
            os.lseek(fd, 0, 0)
            os.ftruncate(fd, 0)
            os.write(fd, json.dumps(data, indent=2, ensure_ascii=False).encode("utf-8"))
            os.write(fd, b"\n")
        finally:
            fcntl.flock(fd, fcntl.LOCK_UN)
            os.close(fd)


def _read_focus(limit: int = 60, today_only: bool = False) -> dict:
    if not os.path.exists(FOCUS_DB):
        return {"entries": [], "stats": {}, "error": "focus.db not found"}
    try:
        con = sqlite3.connect(f"file:{FOCUS_DB}?mode=ro", uri=True, timeout=2.0)
        con.row_factory = sqlite3.Row
        today = time.strftime("%Y-%m-%d")
        if today_only:
            cur = con.execute(
                """
                SELECT id, timestamp, active_app, active_window,
                       assessment, is_drift, screenshot_path
                FROM focus_log
                WHERE date(timestamp) = ?
                ORDER BY id DESC
                LIMIT ?
                """,
                (today, limit),
            )
        else:
            cur = con.execute(
                """
                SELECT id, timestamp, active_app, active_window,
                       assessment, is_drift, screenshot_path
                FROM focus_log
                ORDER BY id DESC
                LIMIT ?
                """,
                (limit,),
            )
        entries = [dict(r) for r in cur.fetchall()]

        stats_cur = con.execute(
            """
            SELECT
              SUM(CASE WHEN date(timestamp)=? THEN 1 ELSE 0 END) AS checks_today,
              SUM(CASE WHEN date(timestamp)=? AND is_drift=1 THEN 1 ELSE 0 END) AS drifts_today,
              (SELECT MAX(timestamp) FROM focus_log) AS last_check_at,
              (SELECT active_app FROM focus_log ORDER BY id DESC LIMIT 1) AS current_app,
              (SELECT active_window FROM focus_log ORDER BY id DESC LIMIT 1) AS current_window,
              (SELECT assessment FROM focus_log ORDER BY id DESC LIMIT 1) AS current_assessment
            FROM focus_log
            """,
            (today, today),
        )
        stats = dict(stats_cur.fetchone())
        con.close()
        return {"entries": entries, "stats": stats}
    except Exception as exc:  # noqa: BLE001
        return {"entries": [], "stats": {}, "error": str(exc)}


def _log_activity(entry: dict) -> None:
    """Append a row to ~/.claude/activity.db."""
    if not entry:
        return
    try:
        con = sqlite3.connect(ACTIVITY_DB, timeout=2.0)
        con.execute(
            """
            INSERT INTO activity_log
              (timestamp, project, category, activity, duration_min, notes)
            VALUES (datetime('now', 'localtime'), ?, ?, ?, ?, ?)
            """,
            (
                entry.get("project", "general"),
                entry.get("category", "admin"),
                entry.get("activity", ""),
                int(entry.get("duration_min") or 0) or None,
                entry.get("notes", ""),
            ),
        )
        con.commit()
        con.close()
    except Exception as exc:  # noqa: BLE001
        print(f"[activity] write failed: {exc}", flush=True)


def _mark_done(pid: str) -> dict:
    with _locked_priorities() as data:
        today_list = data.setdefault("today", [])
        done_list = data.setdefault("done", [])
        for i, item in enumerate(today_list):
            if item.get("id") == pid:
                removed = today_list.pop(i)
                removed["done_at"] = datetime.now().astimezone().isoformat(timespec="seconds")
                done_list.insert(0, removed)
                _log_activity(removed.get("log") or {})
                return {"ok": True, "id": pid}
        return {"ok": False, "error": f"not found: {pid}"}


def _mark_undone(pid: str) -> dict:
    with _locked_priorities() as data:
        today_list = data.setdefault("today", [])
        done_list = data.setdefault("done", [])
        for i, item in enumerate(done_list):
            if item.get("id") == pid:
                removed = done_list.pop(i)
                removed.pop("done_at", None)
                today_list.insert(0, removed)
                return {"ok": True, "id": pid}
        return {"ok": False, "error": f"not found: {pid}"}


_OPEN_ROOT = os.environ.get("STEWARD_OPEN_ROOT") or os.path.expanduser("~")
_OPEN_PROJECT_ROOT = os.environ.get("STEWARD_PROJECT_ROOT") or os.getcwd()


def _open_path(raw: str) -> dict:
    if not raw:
        return {"ok": False, "error": "missing path"}
    path = raw
    if path.startswith("~/"):
        path = os.path.expanduser(path)
    elif not path.startswith("/"):
        path = os.path.join(_OPEN_PROJECT_ROOT, path)
    try:
        real = os.path.realpath(path)
    except OSError as exc:
        return {"ok": False, "error": f"realpath failed: {exc}"}
    if not real.startswith(_OPEN_ROOT + os.sep) and real != _OPEN_ROOT:
        return {"ok": False, "error": f"outside allowed root: {real}"}
    if not os.path.exists(real):
        return {"ok": False, "error": f"not found: {real}"}
    try:
        subprocess.Popen(
            ["/usr/bin/open", real],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
        )
        return {"ok": True, "path": real}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc)}


def _trigger_refresh() -> dict:
    """Spawn refresh.sh detached — returns immediately.
    The dashboard will see the update via SSE when refresh.sh writes priorities.json.
    """
    script = os.path.join(ROOT, "refresh.sh")
    if not os.path.exists(script):
        return {"ok": False, "error": "refresh.sh not found"}
    try:
        subprocess.Popen(
            ["/bin/bash", script, "api"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
        return {"ok": True, "status": "triggered"}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc)}


def _time_of_day() -> dict:
    now = datetime.now()
    hour = now.hour
    if hour < 5:
        tod = "late night"
    elif hour < 12:
        tod = "morning"
    elif hour < 17:
        tod = "afternoon"
    elif hour < 21:
        tod = "evening"
    else:
        tod = "night"
    weekday = now.strftime("%A").lower()
    day = now.day
    month = now.strftime("%B").lower()
    return {
        "label": f"{weekday} {tod}",
        "date_phrase": f"{weekday} · {month} {_ordinal_word(day)}",
        "iso": now.isoformat(timespec="minutes"),
    }


def _ordinal_word(n: int) -> str:
    words = {
        1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth",
        6: "sixth", 7: "seventh", 8: "eighth", 9: "ninth", 10: "tenth",
        11: "eleventh", 12: "twelfth", 13: "thirteenth", 14: "fourteenth",
        15: "fifteenth", 16: "sixteenth", 17: "seventeenth", 18: "eighteenth",
        19: "nineteenth", 20: "twentieth", 21: "twenty-first",
        22: "twenty-second", 23: "twenty-third", 24: "twenty-fourth",
        25: "twenty-fifth", 26: "twenty-sixth", 27: "twenty-seventh",
        28: "twenty-eighth", 29: "twenty-ninth", 30: "thirtieth",
        31: "thirty-first",
    }
    return words.get(n, str(n))


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def log_message(self, fmt, *args):
        pass

    def do_GET(self):
        if self.path.startswith("/events"):
            return self._sse_stream()
        if self.path.startswith("/api/focus"):
            today_only = "today=1" in self.path
            limit_str = self._qs_get("limit", "60")
            try:
                limit = max(1, min(int(limit_str), 500))
            except ValueError:
                limit = 60
            return self._send_json(_read_focus(limit=limit, today_only=today_only))
        if self.path.startswith("/api/now"):
            return self._send_json(_time_of_day())
        super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/mark-done"):
            payload = self._read_body_json()
            return self._send_json(_mark_done(payload.get("id", "")))
        if self.path.startswith("/api/mark-undone"):
            payload = self._read_body_json()
            return self._send_json(_mark_undone(payload.get("id", "")))
        if self.path.startswith("/api/refresh"):
            return self._send_json(_trigger_refresh())
        if self.path.startswith("/api/open"):
            payload = self._read_body_json()
            return self._send_json(_open_path(payload.get("path", "")))
        self.send_error(404)

    def _qs_get(self, key: str, default: str) -> str:
        if "?" not in self.path:
            return default
        query = self.path.split("?", 1)[1]
        for part in query.split("&"):
            if part.startswith(key + "="):
                return part.split("=", 1)[1]
        return default

    def _read_body_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    def _send_json(self, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _sse_stream(self) -> None:
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()
        q = _subscribe()
        try:
            self.wfile.write(b": connected\n\n")
            self.wfile.flush()
            while True:
                try:
                    event = q.get(timeout=15)
                    self.wfile.write(f"data: {event}\n\n".encode("utf-8"))
                    self.wfile.flush()
                except queue.Empty:
                    self.wfile.write(b": heartbeat\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass
        finally:
            _unsubscribe(q)


def main() -> None:
    threading.Thread(target=_watcher, daemon=True).start()
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"focus-dash serving on http://127.0.0.1:{PORT}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()


if __name__ == "__main__":
    main()

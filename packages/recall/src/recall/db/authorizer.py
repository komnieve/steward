"""Read-only SQLite authorizer for the query_db surface.

The authorizer is the real wall (alongside `mode=ro`). It denies anything
beyond SELECT/READ/recursive CTE/function calls and a small whitelist of
read-only introspection PRAGMAs. ATTACH, DETACH, transaction control,
extension loading, and any DDL/DML are blocked.

Threat model: SQL is authored by the local user or by an AI assistant
acting on the user's behalf, not by external clients. The goal is accident
prevention and prompt-injection hardening, not enterprise sandboxing.
"""

import sqlite3
import time

# SQLite action constants. Hardcoded ints because Python 3.11+ exposes them
# under sqlite3.SQLITE_* but we want resilience across versions.
SQLITE_OK = 0
SQLITE_DENY = 1
SQLITE_IGNORE = 2

SQLITE_CREATE_INDEX = 1
SQLITE_CREATE_TABLE = 2
SQLITE_CREATE_TEMP_INDEX = 3
SQLITE_CREATE_TEMP_TABLE = 4
SQLITE_CREATE_TEMP_TRIGGER = 5
SQLITE_CREATE_TEMP_VIEW = 6
SQLITE_CREATE_TRIGGER = 7
SQLITE_CREATE_VIEW = 8
SQLITE_DELETE = 9
SQLITE_DROP_INDEX = 10
SQLITE_DROP_TABLE = 11
SQLITE_DROP_TEMP_INDEX = 12
SQLITE_DROP_TEMP_TABLE = 13
SQLITE_DROP_TEMP_TRIGGER = 14
SQLITE_DROP_TEMP_VIEW = 15
SQLITE_DROP_TRIGGER = 16
SQLITE_DROP_VIEW = 17
SQLITE_INSERT = 18
SQLITE_PRAGMA = 19
SQLITE_READ = 20
SQLITE_SELECT = 21
SQLITE_TRANSACTION = 22
SQLITE_UPDATE = 23
SQLITE_ATTACH = 24
SQLITE_DETACH = 25
SQLITE_ALTER_TABLE = 26
SQLITE_REINDEX = 27
SQLITE_ANALYZE = 28
SQLITE_CREATE_VTABLE = 29
SQLITE_DROP_VTABLE = 30
SQLITE_FUNCTION = 31
SQLITE_SAVEPOINT = 32
SQLITE_RECURSIVE = 33

ALLOWED_ACTIONS = {
    SQLITE_SELECT,
    SQLITE_READ,
    SQLITE_FUNCTION,
    SQLITE_RECURSIVE,
    # SQLITE_ANALYZE is intentionally NOT allowed: it writes to sqlite_stat*
    # tables. mode=ro would catch it, but a read-only authorizer should not
    # whitelist write actions. No introspection use case needs it.
}

# PRAGMAs that are useful for schema introspection and definitionally side-effect-free
ALLOWED_PRAGMAS = {
    "table_info",
    "table_xinfo",
    "table_list",
    "foreign_key_list",
    "index_list",
    "index_info",
    "index_xinfo",
    "database_list",
    "function_list",
    "module_list",
    "compile_options",
    "schema_version",
    "user_version",
    "data_version",
    "page_size",
    "page_count",
}


def make_read_only_authorizer():
    def authorizer(action, arg1, arg2, db_name, trigger):
        if action in ALLOWED_ACTIONS:
            return SQLITE_OK
        if action == SQLITE_PRAGMA:
            # arg1 is the pragma name. arg2 may carry an argument
            # (e.g. `table_info(people)` → arg2='people') OR a setting value
            # (e.g. `journal_mode=WAL` → arg2='WAL'). The authorizer can't
            # distinguish read-arg from write-value, so we whitelist purely by
            # pragma name. ALLOWED_PRAGMAS is curated to introspection-only
            # pragmas where the arg is always a schema object name.
            if arg1 and arg1.lower() in ALLOWED_PRAGMAS:
                return SQLITE_OK
            return SQLITE_DENY
        return SQLITE_DENY

    return authorizer


def make_progress_handler(timeout_seconds: float):
    """Opcode-triggered progress handler with a wall-clock deadline.

    SQLite invokes the callback every `n` VM opcodes (not on a timer). The
    callback then checks wall-clock and returns 1 to abort if the deadline
    has passed. So the deadline only fires while SQLite is actively making
    VM progress — a perfectly idle wait inside the engine wouldn't trigger
    it. For SELECT-only workloads this is the right shape: cancels runaway
    compute (giant joins, recursive CTEs, full scans) without overhead.

    Returns (handler, n_opcodes) suitable for `Connection.set_progress_handler`.
    """
    start = time.time()
    deadline = start + timeout_seconds

    def handler():
        if time.time() > deadline:
            return 1
        return 0

    return handler, 1000

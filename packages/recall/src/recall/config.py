"""Configuration: TOML-driven paths, model choice, and indexing scope.

Resolution order:
  1. RECALL_CONFIG env var → explicit path to a config TOML
  2. RECALL_HOME env var  → use $RECALL_HOME/config.toml
  3. Default              → ~/.steward/recall/config.toml

If no config file exists, in-process defaults are used: the index lives at
~/.steward/recall/search.db and the only markdown source is ~/.steward/.
No SQLite sources are configured by default.

A starter TOML lives at packages/recall/templates/recall.config.toml.
"""

import os
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

HOME = Path.home()


def _expand(path_str: str) -> Path:
    """Expand ~ and $VAR in a path string and return a Path."""
    return Path(os.path.expandvars(os.path.expanduser(path_str)))


def recall_home() -> Path:
    return _expand(os.environ.get("RECALL_HOME", "~/.steward/recall"))


def config_path() -> Path:
    cfg = os.environ.get("RECALL_CONFIG")
    if cfg:
        return _expand(cfg)
    return recall_home() / "config.toml"


DEFAULT_EMBEDDING_MODEL = "Snowflake/snowflake-arctic-embed-l-v2.0"
DEFAULT_EMBEDDING_DIM = 1024
DEFAULT_EMBEDDING_DEVICE = "auto"  # "auto" → mps if Apple Silicon, cuda if available, else cpu


@dataclass
class MarkdownSource:
    name: str
    path: Path
    extensions: tuple[str, ...] = (".md", ".txt")


@dataclass
class SqliteTable:
    """One indexable table in a SQLite source.

    text_columns: columns concatenated to form the document body.
    title_columns: columns concatenated to form the title.
    where: optional SQL fragment appended after WHERE. Trusted config only —
    never user/MCP input.
    """
    table: str
    id_column: str = "id"
    modified_column: str | None = None
    title_columns: tuple[str, ...] = ()
    text_columns: tuple[str, ...] = ()
    where: str = ""


@dataclass
class SqliteSource:
    name: str
    path: Path
    queryable: bool = False  # True → exposed to query_db
    tables: tuple[SqliteTable, ...] = ()


@dataclass
class Config:
    db_path: Path
    lock_path: Path

    embedding_model: str = DEFAULT_EMBEDDING_MODEL
    embedding_dim: int = DEFAULT_EMBEDDING_DIM
    embedding_device: str = DEFAULT_EMBEDDING_DEVICE
    embedding_batch_size: int = 8
    embedding_max_seq_length: int = 512
    query_prefix: str = "query: "
    document_prefix: str = ""

    query_db_default_limit_cli: int = 1000
    query_db_default_limit_mcp: int = 500
    query_db_max_limit: int = 2000
    query_db_timeout_seconds: float = 10.0

    chunk_target_tokens: int = 300
    chunk_max_tokens: int = 800
    chunk_overlap_tokens: int = 50

    rrf_k: int = 60
    vec_top_k: int = 50
    fts_top_k: int = 50

    markdown_sources: list[MarkdownSource] = field(default_factory=list)

    excluded_dir_names: set[str] = field(default_factory=lambda: {
        "node_modules", "vendor", ".venv", "venv", ".git",
        "dist", "build", "__pycache__", ".pytest_cache",
        ".next", ".cache", "embeddings_cache",
    })
    excluded_file_extensions: set[str] = field(default_factory=lambda: {
        ".pdf", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg",
        ".mp3", ".mp4", ".mov", ".wav", ".m4a",
        ".zip", ".tar", ".gz", ".tgz", ".bz2",
        ".db", ".sqlite", ".sqlite3",
        ".pyc", ".so", ".dylib",
    })
    indexed_extensions: set[str] = field(default_factory=lambda: {".md", ".txt"})

    sqlite_sources: list[SqliteSource] = field(default_factory=list)

    @property
    def queryable_dbs(self) -> dict[str, Path]:
        return {s.name: s.path for s in self.sqlite_sources if s.queryable}

    @property
    def sqlite_sources_by_name(self) -> dict[str, SqliteSource]:
        return {s.name: s for s in self.sqlite_sources}


def _public_default_config() -> Config:
    home = recall_home()
    return Config(
        db_path=home / "search.db",
        lock_path=home / "index.lock",
        markdown_sources=[
            MarkdownSource(name="steward", path=_expand("~/.steward"), extensions=(".md", ".txt")),
        ],
        sqlite_sources=[],
    )


def _load_config_from_toml(path: Path) -> Config:
    raw = tomllib.loads(path.read_text())

    home = recall_home()
    idx = raw.get("index", {})
    db_path = _expand(idx.get("db_path", str(home / "search.db")))
    lock_path = _expand(idx.get("lock_path", str(home / "index.lock")))

    emb = raw.get("embedding", {})
    qd = raw.get("query_db", {})
    ch = raw.get("chunking", {})
    sr = raw.get("search", {})
    excl = raw.get("exclusions", {})

    md_sources = [
        MarkdownSource(
            name=entry["name"],
            path=_expand(entry["path"]),
            extensions=tuple(entry.get("extensions", [".md", ".txt"])),
        )
        for entry in raw.get("markdown_sources", [])
    ]

    sql_sources = []
    for entry in raw.get("sqlite_sources", []):
        tables = tuple(
            SqliteTable(
                table=t["table"],
                id_column=t.get("id_column", "id"),
                modified_column=t.get("modified_column"),
                title_columns=tuple(t.get("title_columns", [])),
                text_columns=tuple(t.get("text_columns", [])),
                where=t.get("where", ""),
            )
            for t in entry.get("tables", [])
        )
        sql_sources.append(SqliteSource(
            name=entry["name"],
            path=_expand(entry["path"]),
            queryable=entry.get("queryable", False),
            tables=tables,
        ))

    cfg = Config(
        db_path=db_path,
        lock_path=lock_path,
        embedding_model=emb.get("model", DEFAULT_EMBEDDING_MODEL),
        embedding_dim=int(emb.get("dim", DEFAULT_EMBEDDING_DIM)),
        embedding_device=emb.get("device", DEFAULT_EMBEDDING_DEVICE),
        embedding_batch_size=int(emb.get("batch_size", 8)),
        embedding_max_seq_length=int(emb.get("max_seq_length", 512)),
        query_prefix=emb.get("query_prefix", "query: "),
        document_prefix=emb.get("document_prefix", ""),
        query_db_default_limit_cli=int(qd.get("default_limit_cli", 1000)),
        query_db_default_limit_mcp=int(qd.get("default_limit_mcp", 500)),
        query_db_max_limit=int(qd.get("max_limit", 2000)),
        query_db_timeout_seconds=float(qd.get("timeout_seconds", 10.0)),
        chunk_target_tokens=int(ch.get("target_tokens", 300)),
        chunk_max_tokens=int(ch.get("max_tokens", 800)),
        chunk_overlap_tokens=int(ch.get("overlap_tokens", 50)),
        rrf_k=int(sr.get("rrf_k", 60)),
        vec_top_k=int(sr.get("vec_top_k", 50)),
        fts_top_k=int(sr.get("fts_top_k", 50)),
        markdown_sources=md_sources,
        sqlite_sources=sql_sources,
    )
    if "dir_names" in excl:
        cfg.excluded_dir_names = set(excl["dir_names"])
    if "file_extensions" in excl:
        cfg.excluded_file_extensions = set(excl["file_extensions"])
    return cfg


def load_config() -> Config:
    cfg_path = config_path()
    if cfg_path.exists():
        return _load_config_from_toml(cfg_path)
    return _public_default_config()


CONFIG = load_config()

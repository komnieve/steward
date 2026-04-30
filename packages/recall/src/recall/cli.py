"""recall CLI: index, search, query-db, status, doctor, eval, debug-search."""

import sqlite3
import sys
from pathlib import Path

import typer
import yaml
from rich.console import Console
from rich.table import Table

from recall.config import CONFIG
from recall.db.connection import (
    get_meta,
    init_schema,
    open_external_db,
    open_search_db,
)
from recall.indexer.lock import IndexLockHeld
from recall.indexer.pipeline import run_index
from recall.search.format import render_results
from recall.search.hybrid import debug_search, hybrid_search

# `no_args_is_help=False` because we add a top-level callback that turns
# `recall "some query"` into sugar for `recall search "some query"`.
# When called with no args at all, we still print help (via the callback).
app = typer.Typer(
    no_args_is_help=False,
    add_completion=False,
    pretty_exceptions_enable=False,
    invoke_without_command=True,
)
console = Console()


# --- Top-level shorthand -----------------------------------------------------
# Lets you type `recall "free text"` and have it route to the search subcommand.
# Canonical/documented form remains `recall search "..."`. We detect the sugar
# case before Typer parses subcommands, then rewrite argv.

_KNOWN_COMMANDS = {
    "index", "search", "query-db", "status", "doctor", "debug-search", "eval",
    "--help", "-h",
}


def _maybe_apply_search_sugar() -> None:
    if len(sys.argv) < 2:
        return
    first = sys.argv[1]
    if first in _KNOWN_COMMANDS:
        return
    if first.startswith("-"):
        return
    sys.argv.insert(1, "search")


@app.callback()
def _root(ctx: typer.Context):
    if ctx.invoked_subcommand is None:
        console.print(ctx.get_help())
        raise typer.Exit(0)


@app.command()
def index(
    full: bool = typer.Option(False, "--full", help="Force re-walk (still hash-skip)."),
    reset_embeddings: bool = typer.Option(False, "--reset-embeddings",
        help="Drop the index and re-embed everything from scratch."),
):
    """Run the indexer (incremental by default)."""
    if reset_embeddings:
        if CONFIG.db_path.exists():
            console.print(f"[yellow]Removing existing search.db at {CONFIG.db_path}[/]")
            CONFIG.db_path.unlink()
            for suffix in ("-shm", "-wal"):
                aux = CONFIG.db_path.with_name(CONFIG.db_path.name + suffix)
                if aux.exists():
                    aux.unlink()
        full = True
    console.print(f"[bold]Indexing[/] (full={full})…")
    try:
        stats = run_index(full=full)
    except IndexLockHeld as e:
        console.print(f"[yellow]Skipped:[/] {e}")
        raise typer.Exit(0)
    console.print(
        f"[green]done[/] in {stats.duration_sec:.1f}s — "
        f"scanned={stats.scanned} new={stats.new} updated={stats.updated} "
        f"unchanged={stats.unchanged} deleted={stats.deleted} chunks_embedded={stats.chunks_embedded}"
    )


@app.command()
def search(
    query: str = typer.Argument(..., help="Free-text query"),
    k: int = typer.Option(10, "-k", help="Top-k results"),
    source: list[str] = typer.Option(None, "-s", "--source",
        help="Filter by source name (any markdown_source.name from config, or 'db_row')"),
):
    """Hybrid search over the indexed corpus."""
    results = hybrid_search(query, k=k, source_type=source or None)
    render_results(results, query)


@app.command(name="query-db")
def query_db(
    database: str = typer.Argument(..., help="Database name from config (queryable=true)"),
    sql: str = typer.Argument(..., help="Read-only SQL"),
    limit: int = typer.Option(None, "-l", "--limit",
        help=f"Hard row cap (default {CONFIG.query_db_default_limit_cli}, max {CONFIG.query_db_max_limit})"),
):
    """Run read-only SQL against a configured queryable SQLite database."""
    if not _is_read_only(sql):
        typer.echo("Refused: only SELECT/WITH allowed.", err=True)
        raise typer.Exit(2)
    effective_limit = _clamp_limit(limit, CONFIG.query_db_default_limit_cli)
    wrapped = _wrap_with_limit(sql, effective_limit)
    try:
        conn = open_external_db(database, hardened=True)
    except (ValueError, FileNotFoundError) as e:
        typer.echo(f"Refused: {e}", err=True)
        raise typer.Exit(2)
    try:
        rows = _stream_rows(conn, wrapped, effective_limit)
    except sqlite3.DatabaseError as e:
        # Authorizer denials raise DatabaseError on Python 3.12; the broader
        # parent class catches that plus the more specific OperationalError.
        typer.echo(f"SQL error: {e}", err=True)
        raise typer.Exit(2)
    finally:
        conn.close()
    if not rows:
        console.print("[dim]no rows[/]")
        return
    table = Table(show_lines=False)
    cols = rows[0].keys()
    for c in cols:
        table.add_column(c)
    for r in rows:
        table.add_row(*[str(r[c]) if r[c] is not None else "" for c in cols])
    console.print(table)
    if len(rows) >= effective_limit:
        console.print(f"[dim](capped at {effective_limit} rows; use -l to raise up to {CONFIG.query_db_max_limit})[/]")


@app.command()
def status():
    """Show index health."""
    if not CONFIG.db_path.exists():
        console.print(f"[red]search.db not found at {CONFIG.db_path}[/]")
        console.print("Run [bold]recall index --full[/] to create it.")
        raise typer.Exit(1)
    conn = open_search_db(read_only=True)
    docs = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    chunks = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    by_type = conn.execute(
        "SELECT source_type, COUNT(*) AS n FROM documents GROUP BY source_type ORDER BY n DESC"
    ).fetchall()
    last_full = get_meta(conn, "last_full_index_at")
    last_incr = get_meta(conn, "last_incremental_index_at")
    model = get_meta(conn, "embedding_model")
    dim = get_meta(conn, "embedding_dim")
    conn.close()

    console.print(f"[bold]search.db[/] at {CONFIG.db_path}")
    console.print(f"  documents: {docs}")
    console.print(f"  chunks:    {chunks}")
    console.print(f"  model:     {model} (dim={dim})")
    console.print(f"  last full: {_fmt_ts(last_full)}")
    console.print(f"  last incr: {_fmt_ts(last_incr)}")
    table = Table(title="By source_type")
    table.add_column("type")
    table.add_column("docs", justify="right")
    for r in by_type:
        table.add_row(r["source_type"], str(r["n"]))
    console.print(table)


@app.command()
def doctor(
    model: bool = typer.Option(False, "--model",
        help="Also load the embedding model and run a sample hybrid query (slow first time, may download weights)."),
):
    """Check that everything is wired up + index integrity.

    By default does NOT load the embedding model — fast and offline-safe.
    Pass --model to additionally validate embedding model load and a sample query.
    """
    ok = True
    console.print("[bold]recall doctor[/]")

    # search.db
    if not CONFIG.db_path.exists():
        console.print(f"  [yellow]⚠[/] search.db missing at {CONFIG.db_path}")
        console.print(f"     remediation: [bold]recall index --full[/]")
        ok = False
    else:
        try:
            conn = open_search_db()
            init_schema(conn)
            conn.execute("SELECT vec_version()").fetchone()
            console.print(f"  [green]✓[/] search.db opens, sqlite-vec loaded")

            integ = conn.execute("PRAGMA integrity_check").fetchone()[0]
            if integ == "ok":
                console.print(f"  [green]✓[/] integrity_check: ok")
            else:
                console.print(f"  [red]✗[/] integrity_check: {integ}")
                console.print(f"     remediation: [bold]recall index --reset-embeddings[/]")
                ok = False

            docs_n = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
            chunks_n = conn.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
            vec_n = conn.execute("SELECT COUNT(*) FROM vec_chunks").fetchone()[0]
            fts_n = conn.execute("SELECT COUNT(*) FROM fts_chunks").fetchone()[0]
            console.print(f"  [green]✓[/] counts — docs={docs_n} chunks={chunks_n} vec={vec_n} fts={fts_n}")

            missing_vec = conn.execute(
                "SELECT COUNT(*) FROM chunks WHERE id NOT IN (SELECT chunk_id FROM vec_chunks)"
            ).fetchone()[0]
            if missing_vec == 0:
                console.print(f"  [green]✓[/] no chunks missing vectors")
            else:
                console.print(f"  [red]✗[/] {missing_vec} chunks missing vectors")
                console.print(f"     remediation: [bold]recall index --reset-embeddings[/]")
                ok = False

            orphan_vec = conn.execute(
                "SELECT COUNT(*) FROM vec_chunks WHERE chunk_id NOT IN (SELECT id FROM chunks)"
            ).fetchone()[0]
            if orphan_vec == 0:
                console.print(f"  [green]✓[/] no orphan vec rows")
            else:
                console.print(f"  [red]✗[/] {orphan_vec} orphan vec rows")
                console.print(f"     remediation: [bold]recall index --reset-embeddings[/]")
                ok = False

            if fts_n != chunks_n:
                console.print(f"  [yellow]⚠[/] FTS row count {fts_n} != chunks {chunks_n}")
                ok = False
            else:
                console.print(f"  [green]✓[/] FTS rows match chunks")

            try:
                fts_docs_n = conn.execute("SELECT COUNT(*) FROM fts_documents").fetchone()[0]
                if fts_docs_n != docs_n:
                    console.print(f"  [yellow]⚠[/] fts_documents row count {fts_docs_n} != documents {docs_n}")
                    console.print(f"     remediation: open the DB once via `recall status` to trigger backfill")
                    ok = False
                else:
                    console.print(f"  [green]✓[/] fts_documents rows match documents ({fts_docs_n})")
                conn.execute(
                    "SELECT 1 FROM fts_documents WHERE fts_documents MATCH ? LIMIT 1",
                    ("the",),
                ).fetchone()
                console.print(f"  [green]✓[/] fts_documents sample query OK")
            except sqlite3.OperationalError as e:
                console.print(f"  [red]✗[/] fts_documents check failed: {e}")
                ok = False

            stored_model = get_meta(conn, "embedding_model")
            stored_dim = get_meta(conn, "embedding_dim")
            if stored_model and stored_model != CONFIG.embedding_model:
                console.print(f"  [yellow]⚠[/] model drift: meta={stored_model} config={CONFIG.embedding_model}")
                console.print(f"     remediation: [bold]recall index --reset-embeddings[/]")
                ok = False
            else:
                console.print(f"  [green]✓[/] model meta matches config: {stored_model or '(unset)'}")
            if stored_dim and stored_dim != str(CONFIG.embedding_dim):
                console.print(f"  [yellow]⚠[/] dim drift: meta={stored_dim} config={CONFIG.embedding_dim}")
                console.print(f"     remediation: [bold]recall index --reset-embeddings[/]")
                ok = False

            try:
                conn.execute(
                    "SELECT 1 FROM fts_chunks WHERE fts_chunks MATCH ? LIMIT 1",
                    ("the",),
                ).fetchone()
                console.print(f"  [green]✓[/] FTS sample query OK")
            except Exception as e:
                console.print(f"  [red]✗[/] FTS sample failed: {e}")
                ok = False

            conn.close()

        except Exception as e:
            console.print(f"  [red]✗[/] search.db check failed: {e}")
            ok = False

    # External DBs
    for name, path in CONFIG.queryable_dbs.items():
        if path.exists():
            console.print(f"  [green]✓[/] external db [bold]{name}[/]: {path}")
        else:
            console.print(f"  [yellow]⚠[/] external db [bold]{name}[/] not found: {path}")

    # Lock file presence (informational only)
    if CONFIG.lock_path.exists():
        console.print(f"  [dim]ℹ index lock file present (this is normal): {CONFIG.lock_path}[/]")

    # Optional model load + sample query — only when --model is passed.
    if model:
        console.print("[bold]--model checks[/] (loading embedding model)")
        try:
            from recall.indexer.embed import _model
            _model()
            console.print(f"  [green]✓[/] embedding model loads: {CONFIG.embedding_model}")
        except Exception as e:
            console.print(f"  [red]✗[/] embedding model failed: {e}")
            ok = False

        if CONFIG.db_path.exists():
            try:
                conn = open_search_db(read_only=True)
                docs_n = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
                conn.close()
            except Exception:
                docs_n = 0
            if docs_n > 0:
                try:
                    res = hybrid_search("test", k=1)
                    console.print(f"  [green]✓[/] hybrid search sample returned {len(res)} result(s)")
                except Exception as e:
                    console.print(f"  [red]✗[/] hybrid search sample failed: {e}")
                    ok = False

    if ok:
        console.print("[green]all good.[/]")
    else:
        console.print("[red]doctor found issues — see above[/]")
        raise typer.Exit(1)


@app.command(name="debug-search")
def debug_search_cmd(
    query: str = typer.Argument(..., help="Free-text query to diagnose"),
    expect: str = typer.Option(None, "-e", "--expect",
        help="Substring to look for in source_uri/title — reports its rank in each signal stream"),
    top: int = typer.Option(15, "-n", "--top",
        help="How many top entries to print per signal stream"),
):
    """Per-signal retrieval diagnostic: vector / chunk-FTS / doc-FTS / fused."""
    out = debug_search(query, expected_substring=expect)
    console.print(f"[bold]query:[/] {out['query']}")
    if expect:
        e = out["expected"]
        console.print(f"\n[bold]expected substring:[/] [cyan]{e['substring']}[/]")
        console.print(f"  vec rank:       {e['vec_first_match_rank']}")
        console.print(f"  fts_chunks:     {e['fts_chunks_first_match_rank']}")
        console.print(f"  fts_documents:  {e['fts_documents_first_match_rank']}")
        console.print(f"  fused:          {e['fused_first_match_rank']}")

    def _print_section(name, entries, score_key):
        console.print(f"\n[bold]{name}[/] (top {min(top, len(entries))} of {len(entries)})")
        for h in entries[:top]:
            mark = "[cyan]✱[/] " if expect and expect.lower() in h["label"].lower() else "  "
            console.print(f"  {mark}{h['rank']:>3}. {h['label']}")

    _print_section("vector top", out["vec_top"], "distance")
    _print_section("fts_chunks top", out["fts_chunks_top"], "fts_rank_score")
    _print_section("fts_documents top", out["fts_documents_top"], "fts_rank_score")
    _print_section("fused top", out["fused_top"], "score")


@app.command(name="eval")
def eval_cmd(
    file: Path = typer.Option(None, "-f", "--file", help="Eval YAML file"),
    k: int = typer.Option(10, "-k", help="Top-k retrieved per query"),
):
    """Run golden-set queries from eval YAML; pass if expected substrings appear in top-k.

    No-ops gracefully when the eval file is missing — eval suites are private to
    each user's index and not shipped with the package.
    """
    if file is None:
        # Default to <package_root>/tests/eval_queries.yaml.
        # __file__ = src/recall/cli.py → parents[2] = the recall/ project root.
        file = Path(__file__).resolve().parents[2] / "tests" / "eval_queries.yaml"
    if not file.exists():
        console.print(f"[dim]no eval file at {file} — skipping[/]")
        raise typer.Exit(0)

    try:
        data = yaml.safe_load(file.read_text())
    except yaml.YAMLError as e:
        console.print(f"[red]bad YAML: {e}[/]")
        raise typer.Exit(2)

    queries = data.get("queries", []) if isinstance(data, dict) else []
    if not queries:
        console.print("[yellow]no queries in eval file[/]")
        raise typer.Exit(0)

    if not CONFIG.db_path.exists():
        console.print("[red]search.db not found — run `recall index --full` first[/]")
        raise typer.Exit(2)

    passed = 0
    failed = 0
    for q in queries:
        query_text = (q.get("q") or "").strip()
        must = [s.lower() for s in (q.get("must_include_substrings") or [])]
        if not query_text or not must:
            continue
        try:
            results = hybrid_search(query_text, k=k)
        except Exception as e:
            console.print(f"  [red]✗[/] {query_text[:80]} — search error: {type(e).__name__}: {e}")
            failed += 1
            continue
        haystack = "\n".join(
            f"{r.source_uri}\n{r.title}\n{r.text}" for r in results
        ).lower()
        misses = [s for s in must if s not in haystack]
        if not misses:
            console.print(f"  [green]✓[/] {query_text[:80]}")
            passed += 1
        else:
            console.print(f"  [red]✗[/] {query_text[:80]}")
            console.print(f"     missing substrings: {misses}")
            failed += 1

    total = passed + failed
    console.print(f"\n[bold]{passed}/{total}[/] queries passed")
    if failed:
        raise typer.Exit(1)


def _is_read_only(sql: str) -> bool:
    """Lexical defense-in-depth on top of mode=ro + authorizer."""
    s = sql.strip().lower()
    if not s:
        return False
    first = s.split(None, 1)[0]
    if first not in ("select", "with"):
        return False
    forbidden = (" insert ", " update ", " delete ", " drop ", " alter ", " create ",
                 " replace ", " attach ", " detach ", " pragma ")
    padded = f" {s} "
    return not any(f in padded for f in forbidden)


def _wrap_with_limit(sql: str, limit: int) -> str:
    body = sql.strip().rstrip(";").strip()
    return f"SELECT * FROM ({body}) LIMIT {int(limit)}"


def _clamp_limit(requested: int | None, default: int) -> int:
    if requested is None:
        return min(default, CONFIG.query_db_max_limit)
    try:
        n = int(requested)
    except (TypeError, ValueError):
        return min(default, CONFIG.query_db_max_limit)
    if n < 1:
        return 1
    return min(n, CONFIG.query_db_max_limit)


def _stream_rows(conn: sqlite3.Connection, sql: str, cap: int) -> list:
    cur = conn.execute(sql)
    rows = []
    while len(rows) < cap:
        batch = cur.fetchmany(min(200, cap - len(rows)))
        if not batch:
            break
        rows.extend(batch)
    cur.close()
    return rows


def _fmt_ts(ts: str) -> str:
    if not ts:
        return "[dim]never[/]"
    try:
        from datetime import datetime
        return datetime.fromtimestamp(int(ts)).strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return ts


def main() -> None:
    """Entry point with sugar: `recall "..."` becomes `recall search "..."`."""
    _maybe_apply_search_sugar()
    app()


if __name__ == "__main__":
    main()

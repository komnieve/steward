"""Pretty-print search results for CLI."""

from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.rule import Rule

from recall.search.hybrid import SearchResult

_console = Console()


def render_results(results: list[SearchResult], query: str) -> None:
    _console.print(Rule(f"[bold]{query}[/bold]"))
    if not results:
        _console.print("[dim]no results[/dim]")
        return
    for i, r in enumerate(results, start=1):
        ranks = []
        if r.vec_rank is not None:
            ranks.append(f"vec#{r.vec_rank + 1}")
        if r.fts_rank is not None:
            ranks.append(f"fts#{r.fts_rank + 1}")
        rank_str = " ".join(ranks) or "—"
        header = (
            f"[bold cyan]{i}.[/] [bold]{r.title or r.source_uri}[/]\n"
            f"[dim]{r.source_uri}[/]\n"
            f"[dim]{r.source_type} · {rank_str} · score={r.score:.4f}"
        )
        if r.section_heading:
            header += f" · {r.section_heading}"
        header += "[/dim]"
        body = r.text.strip()
        if len(body) > 1200:
            body = body[:1200] + "\n…"
        _console.print(Panel(body, title=header, title_align="left", border_style="dim"))

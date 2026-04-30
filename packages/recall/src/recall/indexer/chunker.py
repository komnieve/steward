"""Markdown-aware semantic chunker.

Splits hierarchically: section -> subsection -> paragraph -> sentence.
Always prefixes chunks with their heading chain so context survives retrieval.
"""

import re
from dataclasses import dataclass
from typing import Iterable

from recall.config import CONFIG


@dataclass
class Chunk:
    text: str
    section_heading: str | None
    start_line: int
    end_line: int

    @property
    def token_count(self) -> int:
        return rough_token_count(self.text)


HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$")


def rough_token_count(text: str) -> int:
    """Cheap token estimate: words + punctuation. Good enough for chunk sizing."""
    return max(1, len(text) // 4)


def _parse_blocks(text: str) -> list[tuple[int, str, str]]:
    """Parse markdown into (line_no, kind, content) blocks.
    kind ∈ {'h1','h2','h3','h4','h5','h6','para'}.
    Paragraphs are separated by blank lines. Headings are single-line.
    """
    lines = text.splitlines()
    blocks: list[tuple[int, str, str]] = []
    para_buf: list[str] = []
    para_start = 1

    def flush_para(end_line: int):
        nonlocal para_buf, para_start
        if para_buf:
            blocks.append((para_start, "para", "\n".join(para_buf).strip()))
            para_buf = []

    in_fence = False
    fence_marker: str | None = None

    for i, line in enumerate(lines, start=1):
        stripped = line.strip()
        # Track fenced code blocks — don't parse headings inside
        if stripped.startswith("```") or stripped.startswith("~~~"):
            if not in_fence:
                in_fence = True
                fence_marker = stripped[:3]
                if not para_buf:
                    para_start = i
                para_buf.append(line)
            elif stripped.startswith(fence_marker or "```"):
                para_buf.append(line)
                in_fence = False
                fence_marker = None
            else:
                para_buf.append(line)
            continue

        if in_fence:
            para_buf.append(line)
            continue

        m = HEADING_RE.match(line)
        if m:
            flush_para(i - 1)
            level = len(m.group(1))
            blocks.append((i, f"h{level}", m.group(2).strip()))
            continue

        if not stripped:
            flush_para(i - 1)
        else:
            if not para_buf:
                para_start = i
            para_buf.append(line)

    flush_para(len(lines))
    return blocks


def _heading_chain_at(blocks: list[tuple[int, str, str]], idx: int) -> list[str]:
    """Return the heading hierarchy in effect at block `idx`."""
    chain: list[str | None] = [None] * 6
    for j in range(idx):
        line_no, kind, content = blocks[j]
        if kind.startswith("h"):
            level = int(kind[1])
            chain[level - 1] = content
            for k in range(level, 6):
                chain[k] = None
    return [c for c in chain if c is not None]


def _heading_prefix(chain: list[str]) -> str:
    if not chain:
        return ""
    return " > ".join(chain)


def _split_long_paragraph(text: str, max_tokens: int) -> list[str]:
    """Sentence-split a paragraph that's too big. Greedy-pack sentences up to target."""
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    target = max_tokens
    chunks: list[str] = []
    current: list[str] = []
    current_tokens = 0
    for s in sentences:
        s_tokens = rough_token_count(s)
        if current_tokens + s_tokens > target and current:
            chunks.append(" ".join(current))
            current = [s]
            current_tokens = s_tokens
        else:
            current.append(s)
            current_tokens += s_tokens
    if current:
        chunks.append(" ".join(current))
    return chunks


def chunk_markdown(text: str) -> list[Chunk]:
    """Chunk markdown into coherent passages.

    Strategy:
      1. Pack paragraphs greedily up to target_tokens, breaking only at paragraph
         boundaries within the same heading section.
      2. If a single paragraph exceeds max_tokens, sentence-split it.
      3. Always prefix the chunk with its heading chain.
    """
    target = CONFIG.chunk_target_tokens
    max_tokens = CONFIG.chunk_max_tokens

    blocks = _parse_blocks(text)
    if not blocks:
        return []

    chunks: list[Chunk] = []
    current_paras: list[tuple[int, int, str]] = []  # (start_line, end_line, text)
    current_tokens = 0
    current_chain: list[str] = []

    def emit():
        nonlocal current_paras, current_tokens
        if not current_paras:
            return
        body = "\n\n".join(p[2] for p in current_paras)
        prefix = _heading_prefix(current_chain)
        full_text = f"# {prefix}\n\n{body}" if prefix else body
        chunks.append(Chunk(
            text=full_text,
            section_heading=prefix or None,
            start_line=current_paras[0][0],
            end_line=current_paras[-1][1],
        ))
        current_paras = []
        current_tokens = 0

    for i, (line_no, kind, content) in enumerate(blocks):
        if kind.startswith("h"):
            emit()
            current_chain = _heading_chain_at(blocks, i + 1)
            continue
        # paragraph
        para_lines = content.count("\n") + 1
        para_end = line_no + para_lines - 1
        para_tokens = rough_token_count(content)

        if para_tokens > max_tokens:
            emit()
            for sub in _split_long_paragraph(content, target):
                prefix = _heading_prefix(current_chain)
                full_text = f"# {prefix}\n\n{sub}" if prefix else sub
                chunks.append(Chunk(
                    text=full_text,
                    section_heading=prefix or None,
                    start_line=line_no,
                    end_line=para_end,
                ))
            continue

        if current_tokens + para_tokens > target and current_paras:
            emit()
        current_paras.append((line_no, para_end, content))
        current_tokens += para_tokens

    emit()
    return chunks


def chunk_text(text: str, source_label: str = "") -> list[Chunk]:
    """Chunk plain text (transcripts, etc.) by paragraph packing only."""
    paras = [p.strip() for p in re.split(r"\n\n+", text) if p.strip()]
    target = CONFIG.chunk_target_tokens
    max_tokens = CONFIG.chunk_max_tokens
    chunks: list[Chunk] = []
    current: list[str] = []
    current_tokens = 0
    line_cursor = 1
    line_starts: list[int] = []

    def emit():
        nonlocal current, current_tokens, line_starts
        if not current:
            return
        body = "\n\n".join(current)
        chunks.append(Chunk(
            text=body,
            section_heading=source_label or None,
            start_line=line_starts[0] if line_starts else 1,
            end_line=line_cursor,
        ))
        current = []
        current_tokens = 0
        line_starts = []

    for p in paras:
        p_tokens = rough_token_count(p)
        if p_tokens > max_tokens:
            emit()
            for sub in _split_long_paragraph(p, target):
                chunks.append(Chunk(
                    text=sub,
                    section_heading=source_label or None,
                    start_line=line_cursor,
                    end_line=line_cursor + sub.count("\n"),
                ))
            line_cursor += p.count("\n") + 2
            continue
        if current_tokens + p_tokens > target and current:
            emit()
        if not current:
            line_starts.append(line_cursor)
        current.append(p)
        current_tokens += p_tokens
        line_cursor += p.count("\n") + 2

    emit()
    return chunks

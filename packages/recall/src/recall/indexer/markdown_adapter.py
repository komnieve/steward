"""Markdown / text file source adapter. Walks configured paths, yields documents."""

import hashlib
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

import frontmatter

from recall.config import CONFIG
from recall.indexer.chunker import Chunk, chunk_markdown, chunk_text


@dataclass
class SourceDoc:
    source_uri: str
    source_type: str
    source_adapter: str
    title: str
    modified_at: str
    content_hash: str
    metadata: dict
    chunks: list[Chunk]


def _file_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8", errors="replace")).hexdigest()


def _is_excluded_path(p: Path) -> bool:
    return any(part in CONFIG.excluded_dir_names for part in p.parts)


def _is_excluded_file(p: Path, allowed_extensions: set[str]) -> bool:
    suffix = p.suffix.lower()
    if suffix in CONFIG.excluded_file_extensions:
        return True
    if suffix not in allowed_extensions:
        return True
    return False


def _walk_dir(root: Path, allowed_extensions: set[str]) -> Iterator[Path]:
    if not root.exists():
        return
    if root.is_file():
        if not _is_excluded_file(root, allowed_extensions):
            yield root
        return
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        if _is_excluded_path(p):
            continue
        if _is_excluded_file(p, allowed_extensions):
            continue
        yield p


def _build_doc(p: Path, source_type: str) -> SourceDoc | None:
    try:
        raw = p.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return None

    if not raw.strip():
        return None

    metadata: dict = {}
    body = raw
    title = p.stem

    if p.suffix.lower() == ".md":
        try:
            post = frontmatter.loads(raw)
            metadata = dict(post.metadata) if post.metadata else {}
            body = post.content
            if "title" in metadata:
                title = str(metadata["title"])
            elif "name" in metadata:
                title = str(metadata["name"])
        except Exception:
            pass
        chunks = chunk_markdown(body)
    else:
        chunks = chunk_text(body, source_label=title)

    if not chunks:
        return None

    stat = p.stat()
    return SourceDoc(
        source_uri=f"file://{p.resolve()}",
        source_type=source_type,
        source_adapter="markdown",
        title=title,
        modified_at=str(int(stat.st_mtime)),
        content_hash=_file_hash(raw),
        metadata=metadata,
        chunks=chunks,
    )


def iter_markdown_docs() -> Iterator[SourceDoc]:
    seen_uris: set[str] = set()
    for source in CONFIG.markdown_sources:
        allowed = set(source.extensions)
        for p in _walk_dir(source.path, allowed):
            doc = _build_doc(p, source.name)
            if doc and doc.source_uri not in seen_uris:
                seen_uris.add(doc.source_uri)
                yield doc

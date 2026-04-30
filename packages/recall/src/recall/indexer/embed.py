"""SentenceTransformer wrapper for the configured embedding model.

The heavy import (`sentence_transformers`, which transitively pulls torch) is
deferred until `_model()` is actually called. Importing this module is cheap
and torch-free, so doctor-without-model and the MCP server's startup path
don't pay the load cost up front.
"""

from functools import lru_cache

import numpy as np

from recall.config import CONFIG


def _resolve_device(name: str) -> str:
    """Translate `device = "auto"` to a concrete backend.

    Order: cuda > mps > cpu. We import torch lazily — falling through to "cpu"
    if torch isn't available means callers don't blow up just from device
    resolution, only when the actual model load is attempted.
    """
    if name != "auto":
        return name
    try:
        import torch  # noqa: WPS433 — intentional lazy import
    except ImportError:
        return "cpu"
    try:
        if torch.cuda.is_available():
            return "cuda"
    except Exception:
        pass
    try:
        if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
            return "mps"
    except Exception:
        pass
    return "cpu"


@lru_cache(maxsize=1)
def _model():
    # Deferred import: keeps `import recall.indexer.embed` cheap and
    # torch-free. The model only loads on first call.
    from sentence_transformers import SentenceTransformer

    device = _resolve_device(CONFIG.embedding_device)
    m = SentenceTransformer(CONFIG.embedding_model, device=device)
    m.max_seq_length = CONFIG.embedding_max_seq_length
    return m


def _encode(texts: list[str], prefix: str) -> np.ndarray:
    if not texts:
        return np.zeros((0, CONFIG.embedding_dim), dtype=np.float32)
    model = _model()
    prefixed = [prefix + t for t in texts] if prefix else texts
    vecs = model.encode(
        prefixed,
        batch_size=CONFIG.embedding_batch_size,
        normalize_embeddings=True,
        convert_to_numpy=True,
        show_progress_bar=False,
    )
    return vecs.astype(np.float32)


def embed(texts: list[str]) -> np.ndarray:
    """Embed documents. Snowflake Arctic Embed v2.0 has no doc-side prefix."""
    return _encode(texts, CONFIG.document_prefix)


def embed_query(text: str) -> np.ndarray:
    return _encode([text], CONFIG.query_prefix)[0]


def model_id() -> str:
    return CONFIG.embedding_model


def embedding_dim() -> int:
    return CONFIG.embedding_dim

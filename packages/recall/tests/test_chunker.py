"""Tests for the markdown chunker — pure logic, no model load."""

from __future__ import annotations

from recall.indexer.chunker import chunk_markdown, chunk_text, rough_token_count


def test_chunk_markdown_empty():
    assert chunk_markdown("") == []
    assert chunk_markdown("   \n  \n") == []


def test_chunk_markdown_single_section():
    text = "# Heading\n\nA paragraph.\n\nAnother paragraph."
    chunks = chunk_markdown(text)
    assert len(chunks) >= 1
    # Heading chain shows up at the top of the chunk
    assert "Heading" in chunks[0].text
    assert chunks[0].section_heading == "Heading"


def test_chunk_markdown_heading_chain():
    text = (
        "# Top\n\nintro paragraph\n\n"
        "## Sub A\n\npara A1\n\n"
        "## Sub B\n\npara B1"
    )
    chunks = chunk_markdown(text)
    headings = [c.section_heading for c in chunks]
    assert "Top" in headings or "Top > Sub A" in headings
    assert any(h and "Sub A" in h for h in headings)
    assert any(h and "Sub B" in h for h in headings)


def test_chunk_text_handles_paragraphs():
    text = "First paragraph.\n\nSecond paragraph here."
    chunks = chunk_text(text)
    assert len(chunks) >= 1
    assert "First paragraph" in chunks[0].text


def test_rough_token_count_monotone():
    short = "hello"
    long = "hello " * 200
    assert rough_token_count(short) < rough_token_count(long)
    assert rough_token_count("") >= 1  # min floor

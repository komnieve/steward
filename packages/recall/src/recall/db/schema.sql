-- search.db schema
-- Versioned: meta.schema_version. Bump on any change.

CREATE TABLE IF NOT EXISTS documents (
  id            INTEGER PRIMARY KEY,
  source_uri    TEXT UNIQUE NOT NULL,
  source_type   TEXT NOT NULL,
  source_adapter TEXT NOT NULL,
  title         TEXT,
  modified_at   TEXT NOT NULL,
  indexed_at    TEXT NOT NULL,
  content_hash  TEXT NOT NULL,
  metadata      TEXT
);

CREATE INDEX IF NOT EXISTS idx_documents_source_type ON documents(source_type);
CREATE INDEX IF NOT EXISTS idx_documents_modified_at ON documents(modified_at);

CREATE TABLE IF NOT EXISTS chunks (
  id              INTEGER PRIMARY KEY,
  document_id     INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
  chunk_index     INTEGER NOT NULL,
  text            TEXT NOT NULL,
  start_line      INTEGER,
  end_line        INTEGER,
  section_heading TEXT,
  token_count     INTEGER NOT NULL,
  UNIQUE(document_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_chunks_document ON chunks(document_id);

CREATE VIRTUAL TABLE IF NOT EXISTS vec_chunks USING vec0(
  chunk_id INTEGER PRIMARY KEY,
  embedding FLOAT[1024]
);

CREATE VIRTUAL TABLE IF NOT EXISTS fts_chunks USING fts5(
  text,
  section_heading,
  content=chunks,
  content_rowid=id,
  tokenize='porter unicode61'
);

-- Document-level FTS over title + source_uri/path. Lets slug-style queries
-- find the right document even when the body text never repeats the slug
-- (e.g. searching for a filename that doesn't appear in the body). Fused
-- with chunk-level FTS and vector search via RRF.
CREATE VIRTUAL TABLE IF NOT EXISTS fts_documents USING fts5(
  title,
  source_uri,
  content=documents,
  content_rowid=id,
  tokenize='porter unicode61'
);

CREATE TRIGGER IF NOT EXISTS documents_ai AFTER INSERT ON documents BEGIN
  INSERT INTO fts_documents(rowid, title, source_uri)
    VALUES (new.id, new.title, new.source_uri);
END;

CREATE TRIGGER IF NOT EXISTS documents_ad AFTER DELETE ON documents BEGIN
  INSERT INTO fts_documents(fts_documents, rowid, title, source_uri)
    VALUES ('delete', old.id, old.title, old.source_uri);
END;

CREATE TRIGGER IF NOT EXISTS documents_au AFTER UPDATE ON documents BEGIN
  INSERT INTO fts_documents(fts_documents, rowid, title, source_uri)
    VALUES ('delete', old.id, old.title, old.source_uri);
  INSERT INTO fts_documents(rowid, title, source_uri)
    VALUES (new.id, new.title, new.source_uri);
END;

CREATE TRIGGER IF NOT EXISTS chunks_ai AFTER INSERT ON chunks BEGIN
  INSERT INTO fts_chunks(rowid, text, section_heading)
    VALUES (new.id, new.text, new.section_heading);
END;

CREATE TRIGGER IF NOT EXISTS chunks_ad AFTER DELETE ON chunks BEGIN
  INSERT INTO fts_chunks(fts_chunks, rowid, text, section_heading)
    VALUES ('delete', old.id, old.text, old.section_heading);
END;

CREATE TRIGGER IF NOT EXISTS chunks_au AFTER UPDATE ON chunks BEGIN
  INSERT INTO fts_chunks(fts_chunks, rowid, text, section_heading)
    VALUES ('delete', old.id, old.text, old.section_heading);
  INSERT INTO fts_chunks(rowid, text, section_heading)
    VALUES (new.id, new.text, new.section_heading);
END;

CREATE TABLE IF NOT EXISTS meta (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

INSERT OR IGNORE INTO meta(key, value) VALUES
  ('schema_version', '1'),
  ('embedding_model', ''),
  ('embedding_dim', ''),
  ('last_full_index_at', ''),
  ('last_incremental_index_at', '');

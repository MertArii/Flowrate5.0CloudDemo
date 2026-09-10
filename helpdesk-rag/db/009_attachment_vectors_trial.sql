-- demo@sirket.com customer_email'iyle acilmis, gercekte trial olan ama
-- /ask'in is_trial ayrimindan once tickets tablosuna karismis ticket'lari
-- tickets_trial'a tasirken, onlara bagli attachment_vectors (RAG Katman 2
-- embedding'leri) kaybolmasin diye trial karsiligi.

CREATE TABLE IF NOT EXISTS attachment_vectors_trial (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attachment_id UUID REFERENCES message_attachments_trial(id) ON DELETE CASCADE,
    ticket_id UUID REFERENCES tickets_trial(id) ON DELETE CASCADE,
    source VARCHAR(255),
    chunk_index INT NOT NULL,
    page_number INT,
    chunk_content TEXT NOT NULL,
    embedding vector(1024) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_attachment_vectors_trial_embedding
    ON attachment_vectors_trial USING hnsw (embedding vector_cosine_ops);

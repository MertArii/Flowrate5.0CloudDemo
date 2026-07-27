-- AI Helpdesk & RAG - tam veritabanı şeması (10 tablo).
-- NOT: Embedding boyutu bge-m3'e göre 1024'tür (doküman 768 diyordu; bge-m3
-- 1024 ürettiği için 1024'e çekildi). Embedding modeli değişirse burayı ve
-- app/config.py:embed_dim'i birlikte güncelleyin.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- SUPPORT GROUPS
CREATE TABLE IF NOT EXISTS support_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    email_alias VARCHAR(150),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- USERS
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(150) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    title VARCHAR(100),
    department VARCHAR(100),
    region VARCHAR(100),
    phone VARCHAR(50),
    role VARCHAR(20) DEFAULT 'customer' CHECK (role IN ('customer', 'agent', 'admin')),
    support_group_id UUID REFERENCES support_groups(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- TICKETS
CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_number SERIAL UNIQUE,
    customer_email VARCHAR(150) NOT NULL,
    customer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    recipient_email VARCHAR(150) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    raw_issue_description TEXT NOT NULL,
    extracted_category VARCHAR(100),
    region VARCHAR(100),
    status VARCHAR(30) DEFAULT 'new' CHECK (status IN ('new','l1_routing','assigned','in_progress','resolved','closed')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
    assigned_group_id UUID REFERENCES support_groups(id) ON DELETE SET NULL,
    assigned_agent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ
);

-- MESSAGES
CREATE TABLE IF NOT EXISTS ticket_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    sender_email VARCHAR(150) NOT NULL,
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('customer','agent','ai_bot','system')),
    message_body TEXT NOT NULL,
    ai_generated_draft TEXT,
    rag_sources_used JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ATTACHMENTS
CREATE TABLE IF NOT EXISTS message_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES ticket_messages(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_type VARCHAR(50),
    ocr_extracted_text TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ROUTING RULES
CREATE TABLE IF NOT EXISTS routing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_name VARCHAR(100) NOT NULL,
    recipient_email_pattern VARCHAR(150),
    keyword_triggers TEXT[],
    sender_domain VARCHAR(100),
    target_group_id UUID NOT NULL REFERENCES support_groups(id) ON DELETE CASCADE,
    default_assigned_agent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    priority_score INT DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ROUTING LOGS
CREATE TABLE IF NOT EXISTS routing_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    decision_factors JSONB NOT NULL,
    assigned_group_id UUID REFERENCES support_groups(id),
    assigned_agent_id UUID REFERENCES users(id),
    confidence_score FLOAT,
    is_overridden_by_human BOOLEAN DEFAULT FALSE,
    correct_group_id UUID REFERENCES support_groups(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- TICKET SOLUTIONS (RAG KATMANI 1 - net sorun/çözüm çiftleri)
CREATE TABLE IF NOT EXISTS ticket_solutions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE SET NULL,
    category VARCHAR(100),
    problem_text TEXT NOT NULL,
    solution_text TEXT NOT NULL,
    embedding vector(1024),
    metadata JSONB,
    is_verified BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ticket_solutions_embedding
    ON ticket_solutions USING hnsw (embedding vector_cosine_ops);

-- ATTACHMENT VECTORS (RAG KATMANI 2 - doküman parçaları)
-- attachment_id ve ticket_id NULLABLE: bir e-postaya bağlı olmayan bağımsız
-- bilgi bankası dokümanları da (SAP kılavuzu vb.) buraya /ingest ile eklenebilsin.
CREATE TABLE IF NOT EXISTS attachment_vectors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attachment_id UUID REFERENCES message_attachments(id) ON DELETE CASCADE,
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    source VARCHAR(255),          -- bağımsız doküman kaynağı (dosya adı)
    chunk_index INT NOT NULL,
    page_number INT,
    chunk_content TEXT NOT NULL,
    embedding vector(1024) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_attachment_vectors_embedding
    ON attachment_vectors USING hnsw (embedding vector_cosine_ops);

-- AI FEEDBACKS
CREATE TABLE IF NOT EXISTS ai_feedbacks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID REFERENCES ticket_messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    feedback_text TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- /ask endpoint'i (Postman'dan manuel test amacli sorulan sorular) artik
-- gercek tickets tablosunu kirletmesin diye ayni yapida bir "trial" (deneme)
-- tablo seti. Gercek is akisi (/triage) hala tickets/routing_logs/
-- ticket_messages/message_attachments'a yaziyor; sadece /ask trial
-- tablolarina yazar. users/support_groups/sla_policies/alt_kategoriler/
-- sap_modules gibi ortak referans veriler paylasilir (kirletilmiyor zaten).

CREATE TABLE IF NOT EXISTS tickets_trial (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_number SERIAL UNIQUE,
    customer_email VARCHAR(150) NOT NULL,
    customer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    recipient_email VARCHAR(150) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    raw_issue_description TEXT NOT NULL,
    extracted_category VARCHAR(100),
    region VARCHAR(100),
    status VARCHAR(30) DEFAULT 'new' CHECK (status IN ('new','l1_routing','assigned','in_progress','waiting','resolved','closed')),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent','planned')),
    assigned_group_id UUID REFERENCES support_groups(id) ON DELETE SET NULL,
    assigned_agent_id UUID REFERENCES users(id) ON DELETE SET NULL,
    sla_policy_id UUID REFERENCES sla_policies(id),
    response_deadline TIMESTAMPTZ,
    workaround_deadline TIMESTAMPTZ,
    resolution_deadline TIMESTAMPTZ,
    first_response_at TIMESTAMPTZ,
    sla_status VARCHAR(20) DEFAULT 'within_sla',
    last_paused_at TIMESTAMPTZ,
    total_paused_duration INTERVAL DEFAULT '00:00:00',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    sub_category_id UUID REFERENCES alt_kategoriler(id) ON DELETE SET NULL,
    sap_module_id UUID REFERENCES sap_modules(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS routing_logs_trial (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID REFERENCES tickets_trial(id) ON DELETE CASCADE,
    decision_factors JSONB NOT NULL,
    assigned_group_id UUID REFERENCES support_groups(id),
    assigned_agent_id UUID REFERENCES users(id),
    confidence_score FLOAT,
    is_overridden_by_human BOOLEAN DEFAULT FALSE,
    correct_group_id UUID REFERENCES support_groups(id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ticket_messages_trial (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES tickets_trial(id) ON DELETE CASCADE,
    sender_email VARCHAR(150) NOT NULL,
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('customer','agent','ai_bot','system')),
    message_body TEXT NOT NULL,
    ai_generated_draft TEXT,
    rag_sources_used JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS message_attachments_trial (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID NOT NULL REFERENCES ticket_messages_trial(id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_path TEXT NOT NULL,
    file_type VARCHAR(50),
    ocr_extracted_text TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- /messages/{id}/feedback endpoint'i ai_bot mesajina puan verirken
-- message_id'nin gercek mi trial mi oldugunu ayirt edip dogru tabloya
-- yazabilsin diye (bkz. app/rag/store.py:get_ai_message/create_ai_feedback).
CREATE TABLE IF NOT EXISTS ai_feedbacks_trial (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_id UUID REFERENCES ticket_messages_trial(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    feedback_text TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

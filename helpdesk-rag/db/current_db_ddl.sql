--
-- PostgreSQL database dump
--

\restrict L8FpcQfAVCpF0GWJ0Zsrr4DyroeAYirgErQfuC9ANjFGL1NXQs0LyXgrRrxlNEW

-- Dumped from database version 16.14 (Debian 16.14-1.pgdg12+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg12+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ai_feedbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_feedbacks (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    message_id uuid,
    user_id uuid,
    rating integer,
    feedback_text text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ai_feedbacks_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: alt_kategoriler; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alt_kategoriler (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    grup_id uuid NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: attachment_vectors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachment_vectors (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    attachment_id uuid,
    ticket_id uuid,
    source character varying(255),
    chunk_index integer NOT NULL,
    page_number integer,
    chunk_content text NOT NULL,
    embedding public.vector(1024) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: classification_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.classification_categories (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    category_key text NOT NULL,
    aciklama text NOT NULL,
    ekip_group_id uuid,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    ekip_gorunum_adi text
);


--
-- Name: kategori_gruplari; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kategori_gruplari (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ust_kategori_id uuid NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: message_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_attachments (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    message_id uuid NOT NULL,
    file_name character varying(255) NOT NULL,
    file_path text NOT NULL,
    file_type character varying(50),
    ocr_extracted_text text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: routing_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing_logs (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ticket_id uuid,
    decision_factors jsonb NOT NULL,
    assigned_group_id uuid,
    assigned_agent_id uuid,
    confidence_score double precision,
    is_overridden_by_human boolean DEFAULT false,
    correct_group_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: routing_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing_rules (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    rule_name character varying(100) NOT NULL,
    recipient_email_pattern character varying(150),
    keyword_triggers text[],
    sender_domain character varying(100),
    target_group_id uuid NOT NULL,
    default_assigned_agent_id uuid,
    priority_score integer DEFAULT 10,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: sap_modules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sap_modules (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    code text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: sla_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sla_policies (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    level_int integer NOT NULL,
    level_name character varying(100) NOT NULL,
    priority_key character varying(20) NOT NULL,
    response_target interval,
    workaround_target interval,
    resolution_target interval NOT NULL,
    is_business_days boolean DEFAULT false,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: support_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.support_groups (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    email_alias character varying(150),
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: ticket_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_messages (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ticket_id uuid NOT NULL,
    sender_email character varying(150) NOT NULL,
    sender_type character varying(20) NOT NULL,
    message_body text NOT NULL,
    ai_generated_draft text,
    rag_sources_used jsonb,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ticket_messages_sender_type_check CHECK (((sender_type)::text = ANY ((ARRAY['customer'::character varying, 'agent'::character varying, 'ai_bot'::character varying, 'system'::character varying])::text[])))
);


--
-- Name: ticket_solutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_solutions (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ticket_id uuid,
    category character varying(100),
    problem_text text NOT NULL,
    solution_text text NOT NULL,
    embedding public.vector(1024),
    metadata jsonb,
    is_verified boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    ticket_number integer NOT NULL,
    customer_email character varying(150) NOT NULL,
    customer_id uuid,
    recipient_email character varying(150) NOT NULL,
    subject character varying(255) NOT NULL,
    raw_issue_description text NOT NULL,
    extracted_category character varying(100),
    region character varying(100),
    status character varying(30) DEFAULT 'new'::character varying,
    priority character varying(20) DEFAULT 'medium'::character varying,
    assigned_group_id uuid,
    assigned_agent_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    resolved_at timestamp with time zone,
    sla_policy_id uuid,
    response_deadline timestamp with time zone,
    workaround_deadline timestamp with time zone,
    resolution_deadline timestamp with time zone,
    first_response_at timestamp with time zone,
    sla_status character varying(20) DEFAULT 'within_sla'::character varying,
    last_paused_at timestamp with time zone,
    total_paused_duration interval DEFAULT '00:00:00'::interval,
    sub_category_id uuid,
    sap_module_id uuid,
    CONSTRAINT tickets_priority_check CHECK (((priority)::text = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'urgent'::text, 'planned'::text]))),
    CONSTRAINT tickets_status_check CHECK (((status)::text = ANY (ARRAY['new'::text, 'l1_routing'::text, 'assigned'::text, 'in_progress'::text, 'waiting'::text, 'resolved'::text, 'closed'::text])))
);


--
-- Name: COLUMN tickets.sub_category_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tickets.sub_category_id IS 'alt_kategoriler tablosuna işaret eder. Üst kategori/grup, alt_kategoriler -> kategori_gruplari -> ust_kategoriler JOIN''iyle elde edilir.';


--
-- Name: COLUMN tickets.sap_module_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tickets.sap_module_id IS 'Opsiyonel — sadece SAP ile ilgili ticket''larda dolu. sub_category_id''den BAĞIMSIZ çapraz bir alandır (ör. Yetki Hatası + FI, Bug fix + MM gibi).';


--
-- Name: tickets_ticket_number_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tickets_ticket_number_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tickets_ticket_number_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tickets_ticket_number_seq OWNED BY public.tickets.ticket_number;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    email character varying(150) NOT NULL,
    full_name character varying(150) NOT NULL,
    title character varying(100),
    department character varying(100),
    region character varying(100),
    phone character varying(50),
    role character varying(20) DEFAULT 'customer'::character varying,
    support_group_id uuid,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    uzman_kategorileri text[],
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['customer'::character varying, 'agent'::character varying, 'admin'::character varying])::text[])))
);


--
-- Name: ust_kategoriler; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ust_kategoriler (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: tickets ticket_number; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets ALTER COLUMN ticket_number SET DEFAULT nextval('public.tickets_ticket_number_seq'::regclass);


--
-- Name: ai_feedbacks ai_feedbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_feedbacks
    ADD CONSTRAINT ai_feedbacks_pkey PRIMARY KEY (id);


--
-- Name: alt_kategoriler alt_kategoriler_grup_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alt_kategoriler
    ADD CONSTRAINT alt_kategoriler_grup_id_name_key UNIQUE (grup_id, name);


--
-- Name: alt_kategoriler alt_kategoriler_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alt_kategoriler
    ADD CONSTRAINT alt_kategoriler_pkey PRIMARY KEY (id);


--
-- Name: attachment_vectors attachment_vectors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_vectors
    ADD CONSTRAINT attachment_vectors_pkey PRIMARY KEY (id);


--
-- Name: classification_categories classification_categories_category_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_categories
    ADD CONSTRAINT classification_categories_category_key_key UNIQUE (category_key);


--
-- Name: classification_categories classification_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.classification_categories
    ADD CONSTRAINT classification_categories_pkey PRIMARY KEY (id);


--
-- Name: kategori_gruplari kategori_gruplari_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kategori_gruplari
    ADD CONSTRAINT kategori_gruplari_pkey PRIMARY KEY (id);


--
-- Name: kategori_gruplari kategori_gruplari_ust_kategori_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kategori_gruplari
    ADD CONSTRAINT kategori_gruplari_ust_kategori_id_name_key UNIQUE (ust_kategori_id, name);


--
-- Name: message_attachments message_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_attachments
    ADD CONSTRAINT message_attachments_pkey PRIMARY KEY (id);


--
-- Name: routing_logs routing_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_logs
    ADD CONSTRAINT routing_logs_pkey PRIMARY KEY (id);


--
-- Name: routing_rules routing_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_rules
    ADD CONSTRAINT routing_rules_pkey PRIMARY KEY (id);


--
-- Name: sap_modules sap_modules_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sap_modules
    ADD CONSTRAINT sap_modules_code_key UNIQUE (code);


--
-- Name: sap_modules sap_modules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sap_modules
    ADD CONSTRAINT sap_modules_pkey PRIMARY KEY (id);


--
-- Name: sla_policies sla_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_policies
    ADD CONSTRAINT sla_policies_pkey PRIMARY KEY (id);


--
-- Name: support_groups support_groups_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_groups
    ADD CONSTRAINT support_groups_name_key UNIQUE (name);


--
-- Name: support_groups support_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.support_groups
    ADD CONSTRAINT support_groups_pkey PRIMARY KEY (id);


--
-- Name: ticket_messages ticket_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_messages
    ADD CONSTRAINT ticket_messages_pkey PRIMARY KEY (id);


--
-- Name: ticket_solutions ticket_solutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_solutions
    ADD CONSTRAINT ticket_solutions_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_ticket_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_ticket_number_key UNIQUE (ticket_number);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ust_kategoriler ust_kategoriler_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ust_kategoriler
    ADD CONSTRAINT ust_kategoriler_name_key UNIQUE (name);


--
-- Name: ust_kategoriler ust_kategoriler_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ust_kategoriler
    ADD CONSTRAINT ust_kategoriler_pkey PRIMARY KEY (id);


--
-- Name: idx_alt_kategoriler_grup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_alt_kategoriler_grup ON public.alt_kategoriler USING btree (grup_id);


--
-- Name: idx_attachment_vectors_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attachment_vectors_embedding ON public.attachment_vectors USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_kategori_gruplari_ust; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_kategori_gruplari_ust ON public.kategori_gruplari USING btree (ust_kategori_id);


--
-- Name: idx_ticket_solutions_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ticket_solutions_embedding ON public.ticket_solutions USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_tickets_sap_module; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_sap_module ON public.tickets USING btree (sap_module_id);


--
-- Name: idx_tickets_sub_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_sub_category ON public.tickets USING btree (sub_category_id);


--
-- Name: ai_feedbacks ai_feedbacks_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_feedbacks
    ADD CONSTRAINT ai_feedbacks_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.ticket_messages(id) ON DELETE CASCADE;


--
-- Name: ai_feedbacks ai_feedbacks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_feedbacks
    ADD CONSTRAINT ai_feedbacks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: alt_kategoriler alt_kategoriler_grup_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alt_kategoriler
    ADD CONSTRAINT alt_kategoriler_grup_id_fkey FOREIGN KEY (grup_id) REFERENCES public.kategori_gruplari(id) ON DELETE CASCADE;


--
-- Name: attachment_vectors attachment_vectors_attachment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_vectors
    ADD CONSTRAINT attachment_vectors_attachment_id_fkey FOREIGN KEY (attachment_id) REFERENCES public.message_attachments(id) ON DELETE CASCADE;


--
-- Name: attachment_vectors attachment_vectors_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachment_vectors
    ADD CONSTRAINT attachment_vectors_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: kategori_gruplari kategori_gruplari_ust_kategori_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kategori_gruplari
    ADD CONSTRAINT kategori_gruplari_ust_kategori_id_fkey FOREIGN KEY (ust_kategori_id) REFERENCES public.ust_kategoriler(id) ON DELETE CASCADE;


--
-- Name: message_attachments message_attachments_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_attachments
    ADD CONSTRAINT message_attachments_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.ticket_messages(id) ON DELETE CASCADE;


--
-- Name: routing_logs routing_logs_assigned_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_logs
    ADD CONSTRAINT routing_logs_assigned_agent_id_fkey FOREIGN KEY (assigned_agent_id) REFERENCES public.users(id);


--
-- Name: routing_logs routing_logs_assigned_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_logs
    ADD CONSTRAINT routing_logs_assigned_group_id_fkey FOREIGN KEY (assigned_group_id) REFERENCES public.support_groups(id);


--
-- Name: routing_logs routing_logs_correct_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_logs
    ADD CONSTRAINT routing_logs_correct_group_id_fkey FOREIGN KEY (correct_group_id) REFERENCES public.support_groups(id);


--
-- Name: routing_logs routing_logs_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_logs
    ADD CONSTRAINT routing_logs_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: routing_rules routing_rules_default_assigned_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_rules
    ADD CONSTRAINT routing_rules_default_assigned_agent_id_fkey FOREIGN KEY (default_assigned_agent_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: routing_rules routing_rules_target_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.routing_rules
    ADD CONSTRAINT routing_rules_target_group_id_fkey FOREIGN KEY (target_group_id) REFERENCES public.support_groups(id) ON DELETE CASCADE;


--
-- Name: ticket_messages ticket_messages_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_messages
    ADD CONSTRAINT ticket_messages_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: ticket_solutions ticket_solutions_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_solutions
    ADD CONSTRAINT ticket_solutions_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE SET NULL;


--
-- Name: tickets tickets_assigned_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_assigned_agent_id_fkey FOREIGN KEY (assigned_agent_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: tickets tickets_assigned_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_assigned_group_id_fkey FOREIGN KEY (assigned_group_id) REFERENCES public.support_groups(id) ON DELETE SET NULL;


--
-- Name: tickets tickets_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: tickets tickets_sap_module_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_sap_module_id_fkey FOREIGN KEY (sap_module_id) REFERENCES public.sap_modules(id) ON DELETE SET NULL;


--
-- Name: tickets tickets_sla_policy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_sla_policy_id_fkey FOREIGN KEY (sla_policy_id) REFERENCES public.sla_policies(id);


--
-- Name: tickets tickets_sub_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_sub_category_id_fkey FOREIGN KEY (sub_category_id) REFERENCES public.alt_kategoriler(id) ON DELETE SET NULL;


--
-- Name: users users_support_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_support_group_id_fkey FOREIGN KEY (support_group_id) REFERENCES public.support_groups(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict L8FpcQfAVCpF0GWJ0Zsrr4DyroeAYirgErQfuC9ANjFGL1NXQs0LyXgrRrxlNEW


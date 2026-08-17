-- DROP SCHEMA public;

CREATE SCHEMA public AUTHORIZATION pg_database_owner;

COMMENT ON SCHEMA public IS 'standard public schema';

-- DROP TYPE public.gtrgm;

CREATE TYPE public.gtrgm (
	INPUT = gtrgm_in,
	OUTPUT = gtrgm_out,
	ALIGNMENT = 4,
	STORAGE = plain,
	CATEGORY = U,
	DELIMITER = ',');

-- DROP TYPE public.halfvec;

CREATE TYPE public.halfvec (
	INPUT = halfvec_in,
	OUTPUT = halfvec_out,
	RECEIVE = halfvec_recv,
	SEND = halfvec_send,
	TYPMOD_IN = halfvec_typmod_in,
	ALIGNMENT = 4,
	STORAGE = secondary,
	CATEGORY = U,
	DELIMITER = ',');

-- DROP TYPE public.sparsevec;

CREATE TYPE public.sparsevec (
	INPUT = sparsevec_in,
	OUTPUT = sparsevec_out,
	RECEIVE = sparsevec_recv,
	SEND = sparsevec_send,
	TYPMOD_IN = sparsevec_typmod_in,
	ALIGNMENT = 4,
	STORAGE = secondary,
	CATEGORY = U,
	DELIMITER = ',');

-- DROP TYPE public.vector;

CREATE TYPE public.vector (
	INPUT = vector_in,
	OUTPUT = vector_out,
	RECEIVE = vector_recv,
	SEND = vector_send,
	TYPMOD_IN = vector_typmod_in,
	ALIGNMENT = 4,
	STORAGE = secondary,
	CATEGORY = U,
	DELIMITER = ',');

-- DROP SEQUENCE public.tickets_ticket_number_seq;

CREATE SEQUENCE public.tickets_ticket_number_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 2147483647
	START 1
	CACHE 1
	NO CYCLE;

-- Permissions

ALTER SEQUENCE public.tickets_ticket_number_seq OWNER TO helpdesk;
GRANT ALL ON SEQUENCE public.tickets_ticket_number_seq TO helpdesk;
-- public.classification_categories definition

-- Drop table

-- DROP TABLE public.classification_categories;

CREATE TABLE public.classification_categories ( id uuid DEFAULT uuid_generate_v4() NOT NULL, category_key text NOT NULL, aciklama text NOT NULL, ekip_group_id uuid NULL, is_active bool DEFAULT true NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, ekip_gorunum_adi text NULL, CONSTRAINT classification_categories_category_key_key UNIQUE (category_key), CONSTRAINT classification_categories_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.classification_categories OWNER TO helpdesk;
GRANT ALL ON TABLE public.classification_categories TO helpdesk;


-- public.sla_policies definition

-- Drop table

-- DROP TABLE public.sla_policies;

CREATE TABLE public.sla_policies ( id uuid DEFAULT uuid_generate_v4() NOT NULL, level_int int4 NOT NULL, level_name varchar(100) NOT NULL, priority_key varchar(20) NOT NULL, response_target interval NULL, workaround_target interval NULL, resolution_target interval NOT NULL, is_business_days bool DEFAULT false NULL, description text NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT sla_policies_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.sla_policies OWNER TO helpdesk;
GRANT ALL ON TABLE public.sla_policies TO helpdesk;


-- public.support_groups definition

-- Drop table

-- DROP TABLE public.support_groups;

CREATE TABLE public.support_groups ( id uuid DEFAULT uuid_generate_v4() NOT NULL, "name" varchar(100) NOT NULL, email_alias varchar(150) NULL, description text NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT support_groups_name_key UNIQUE (name), CONSTRAINT support_groups_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.support_groups OWNER TO helpdesk;
GRANT ALL ON TABLE public.support_groups TO helpdesk;


-- public.users definition

-- Drop table

-- DROP TABLE public.users;

CREATE TABLE public.users ( id uuid DEFAULT uuid_generate_v4() NOT NULL, email varchar(150) NOT NULL, full_name varchar(150) NOT NULL, title varchar(100) NULL, department varchar(100) NULL, region varchar(100) NULL, phone varchar(50) NULL, "role" varchar(20) DEFAULT 'customer'::character varying NULL, support_group_id uuid NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, uzman_kategorileri _text NULL, CONSTRAINT users_email_key UNIQUE (email), CONSTRAINT users_pkey PRIMARY KEY (id), CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['customer'::character varying, 'agent'::character varying, 'admin'::character varying])::text[]))), CONSTRAINT users_support_group_id_fkey FOREIGN KEY (support_group_id) REFERENCES public.support_groups(id) ON DELETE SET NULL);

-- Permissions

ALTER TABLE public.users OWNER TO helpdesk;
GRANT ALL ON TABLE public.users TO helpdesk;


-- public.routing_rules definition

-- Drop table

-- DROP TABLE public.routing_rules;

CREATE TABLE public.routing_rules ( id uuid DEFAULT uuid_generate_v4() NOT NULL, rule_name varchar(100) NOT NULL, recipient_email_pattern varchar(150) NULL, keyword_triggers _text NULL, sender_domain varchar(100) NULL, target_group_id uuid NOT NULL, default_assigned_agent_id uuid NULL, priority_score int4 DEFAULT 10 NULL, is_active bool DEFAULT true NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT routing_rules_pkey PRIMARY KEY (id), CONSTRAINT routing_rules_default_assigned_agent_id_fkey FOREIGN KEY (default_assigned_agent_id) REFERENCES public.users(id) ON DELETE SET NULL, CONSTRAINT routing_rules_target_group_id_fkey FOREIGN KEY (target_group_id) REFERENCES public.support_groups(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.routing_rules OWNER TO helpdesk;
GRANT ALL ON TABLE public.routing_rules TO helpdesk;


-- public.tickets definition

-- Drop table

-- DROP TABLE public.tickets;

CREATE TABLE public.tickets ( id uuid DEFAULT uuid_generate_v4() NOT NULL, ticket_number serial4 NOT NULL, customer_email varchar(150) NOT NULL, customer_id uuid NULL, recipient_email varchar(150) NOT NULL, subject varchar(255) NOT NULL, raw_issue_description text NOT NULL, extracted_category varchar(100) NULL, region varchar(100) NULL, status varchar(30) DEFAULT 'new'::character varying NULL, priority varchar(20) DEFAULT 'medium'::character varying NULL, assigned_group_id uuid NULL, assigned_agent_id uuid NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, resolved_at timestamptz NULL, sla_policy_id uuid NULL, response_deadline timestamptz NULL, workaround_deadline timestamptz NULL, resolution_deadline timestamptz NULL, first_response_at timestamptz NULL, sla_status varchar(20) DEFAULT 'within_sla'::character varying NULL, last_paused_at timestamptz NULL, total_paused_duration interval DEFAULT '00:00:00'::interval NULL, CONSTRAINT tickets_pkey PRIMARY KEY (id), CONSTRAINT tickets_priority_check CHECK (((priority)::text = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'urgent'::text, 'planned'::text]))), CONSTRAINT tickets_status_check CHECK (((status)::text = ANY (ARRAY['new'::text, 'l1_routing'::text, 'assigned'::text, 'in_progress'::text, 'waiting'::text, 'resolved'::text, 'closed'::text]))), CONSTRAINT tickets_ticket_number_key UNIQUE (ticket_number), CONSTRAINT tickets_assigned_agent_id_fkey FOREIGN KEY (assigned_agent_id) REFERENCES public.users(id) ON DELETE SET NULL, CONSTRAINT tickets_assigned_group_id_fkey FOREIGN KEY (assigned_group_id) REFERENCES public.support_groups(id) ON DELETE SET NULL, CONSTRAINT tickets_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(id) ON DELETE SET NULL, CONSTRAINT tickets_sla_policy_id_fkey FOREIGN KEY (sla_policy_id) REFERENCES public.sla_policies(id));

-- Permissions

ALTER TABLE public.tickets OWNER TO helpdesk;
GRANT ALL ON TABLE public.tickets TO helpdesk;


-- public.routing_logs definition

-- Drop table

-- DROP TABLE public.routing_logs;

CREATE TABLE public.routing_logs ( id uuid DEFAULT uuid_generate_v4() NOT NULL, ticket_id uuid NULL, decision_factors jsonb NOT NULL, assigned_group_id uuid NULL, assigned_agent_id uuid NULL, confidence_score float8 NULL, is_overridden_by_human bool DEFAULT false NULL, correct_group_id uuid NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT routing_logs_pkey PRIMARY KEY (id), CONSTRAINT routing_logs_assigned_agent_id_fkey FOREIGN KEY (assigned_agent_id) REFERENCES public.users(id), CONSTRAINT routing_logs_assigned_group_id_fkey FOREIGN KEY (assigned_group_id) REFERENCES public.support_groups(id), CONSTRAINT routing_logs_correct_group_id_fkey FOREIGN KEY (correct_group_id) REFERENCES public.support_groups(id), CONSTRAINT routing_logs_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.routing_logs OWNER TO helpdesk;
GRANT ALL ON TABLE public.routing_logs TO helpdesk;


-- public.ticket_messages definition

-- Drop table

-- DROP TABLE public.ticket_messages;

CREATE TABLE public.ticket_messages ( id uuid DEFAULT uuid_generate_v4() NOT NULL, ticket_id uuid NOT NULL, sender_email varchar(150) NOT NULL, sender_type varchar(20) NOT NULL, message_body text NOT NULL, ai_generated_draft text NULL, rag_sources_used jsonb NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT ticket_messages_pkey PRIMARY KEY (id), CONSTRAINT ticket_messages_sender_type_check CHECK (((sender_type)::text = ANY ((ARRAY['customer'::character varying, 'agent'::character varying, 'ai_bot'::character varying, 'system'::character varying])::text[]))), CONSTRAINT ticket_messages_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.ticket_messages OWNER TO helpdesk;
GRANT ALL ON TABLE public.ticket_messages TO helpdesk;


-- public.ticket_solutions definition

-- Drop table

-- DROP TABLE public.ticket_solutions;

CREATE TABLE public.ticket_solutions ( id uuid DEFAULT uuid_generate_v4() NOT NULL, ticket_id uuid NULL, category varchar(100) NULL, problem_text text NOT NULL, solution_text text NOT NULL, embedding public.vector NULL, metadata jsonb NULL, is_verified bool DEFAULT true NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, updated_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT ticket_solutions_pkey PRIMARY KEY (id), CONSTRAINT ticket_solutions_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE SET NULL);
CREATE INDEX idx_ticket_solutions_embedding ON public.ticket_solutions USING hnsw (embedding vector_cosine_ops);

-- Permissions

ALTER TABLE public.ticket_solutions OWNER TO helpdesk;
GRANT ALL ON TABLE public.ticket_solutions TO helpdesk;


-- public.ai_feedbacks definition

-- Drop table

-- DROP TABLE public.ai_feedbacks;

CREATE TABLE public.ai_feedbacks ( id uuid DEFAULT uuid_generate_v4() NOT NULL, message_id uuid NULL, user_id uuid NULL, rating int4 NULL, feedback_text text NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT ai_feedbacks_pkey PRIMARY KEY (id), CONSTRAINT ai_feedbacks_rating_check CHECK (((rating >= 1) AND (rating <= 5))), CONSTRAINT ai_feedbacks_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.ticket_messages(id) ON DELETE CASCADE, CONSTRAINT ai_feedbacks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.ai_feedbacks OWNER TO helpdesk;
GRANT ALL ON TABLE public.ai_feedbacks TO helpdesk;


-- public.message_attachments definition

-- Drop table

-- DROP TABLE public.message_attachments;

CREATE TABLE public.message_attachments ( id uuid DEFAULT uuid_generate_v4() NOT NULL, message_id uuid NOT NULL, file_name varchar(255) NOT NULL, file_path text NOT NULL, file_type varchar(50) NULL, ocr_extracted_text text NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT message_attachments_pkey PRIMARY KEY (id), CONSTRAINT message_attachments_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.ticket_messages(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.message_attachments OWNER TO helpdesk;
GRANT ALL ON TABLE public.message_attachments TO helpdesk;


-- public.attachment_vectors definition

-- Drop table

-- DROP TABLE public.attachment_vectors;

CREATE TABLE public.attachment_vectors ( id uuid DEFAULT uuid_generate_v4() NOT NULL, attachment_id uuid NULL, ticket_id uuid NULL, "source" varchar(255) NULL, chunk_index int4 NOT NULL, page_number int4 NULL, chunk_content text NOT NULL, embedding public.vector NOT NULL, created_at timestamptz DEFAULT CURRENT_TIMESTAMP NULL, CONSTRAINT attachment_vectors_pkey PRIMARY KEY (id), CONSTRAINT attachment_vectors_attachment_id_fkey FOREIGN KEY (attachment_id) REFERENCES public.message_attachments(id) ON DELETE CASCADE, CONSTRAINT attachment_vectors_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE);
CREATE INDEX idx_attachment_vectors_embedding ON public.attachment_vectors USING hnsw (embedding vector_cosine_ops);

-- Permissions

ALTER TABLE public.attachment_vectors OWNER TO helpdesk;
GRANT ALL ON TABLE public.attachment_vectors TO helpdesk;



-- DROP FUNCTION public.array_to_halfvec(_numeric, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_halfvec(numeric[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_halfvec(_numeric, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_halfvec(_numeric, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_halfvec(_int4, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_halfvec(integer[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_halfvec(_int4, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_halfvec(_int4, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_halfvec(_float4, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_halfvec(real[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_halfvec(_float4, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_halfvec(_float4, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_halfvec(_float8, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_halfvec(double precision[], integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_halfvec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_halfvec(_float8, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_halfvec(_float8, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_sparsevec(_float8, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(double precision[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_sparsevec(_float8, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_sparsevec(_float8, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_sparsevec(_int4, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(integer[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_sparsevec(_int4, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_sparsevec(_int4, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_sparsevec(_float4, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(real[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_sparsevec(_float4, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_sparsevec(_float4, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_sparsevec(_numeric, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_sparsevec(numeric[], integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.array_to_sparsevec(_numeric, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_sparsevec(_numeric, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_vector(_int4, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_vector(integer[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$
;

-- Permissions

ALTER FUNCTION public.array_to_vector(_int4, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_vector(_int4, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_vector(_numeric, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_vector(numeric[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$
;

-- Permissions

ALTER FUNCTION public.array_to_vector(_numeric, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_vector(_numeric, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_vector(_float8, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_vector(double precision[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$
;

-- Permissions

ALTER FUNCTION public.array_to_vector(_float8, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_vector(_float8, int4, bool) TO helpdesk;

-- DROP FUNCTION public.array_to_vector(_float4, int4, bool);

CREATE OR REPLACE FUNCTION public.array_to_vector(real[], integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$array_to_vector$function$
;

-- Permissions

ALTER FUNCTION public.array_to_vector(_float4, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.array_to_vector(_float4, int4, bool) TO helpdesk;

-- DROP AGGREGATE public.avg(halfvec);

-- Aggregate function public.avg(halfvec)
-- ERROR: more than one function named "public.avg";

-- Permissions

ALTER AGGREGATE public.avg(halfvec) OWNER TO helpdesk;
GRANT ALL ON AGGREGATE public.avg(halfvec) TO helpdesk;

-- DROP AGGREGATE public.avg(vector);

-- Aggregate function public.avg(vector)
-- ERROR: more than one function named "public.avg";

-- Permissions

ALTER AGGREGATE public.avg(vector) OWNER TO helpdesk;
GRANT ALL ON AGGREGATE public.avg(vector) TO helpdesk;

-- DROP FUNCTION public.binary_quantize(halfvec);

CREATE OR REPLACE FUNCTION public.binary_quantize(halfvec)
 RETURNS bit
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_binary_quantize$function$
;

-- Permissions

ALTER FUNCTION public.binary_quantize(halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.binary_quantize(halfvec) TO helpdesk;

-- DROP FUNCTION public.binary_quantize(vector);

CREATE OR REPLACE FUNCTION public.binary_quantize(vector)
 RETURNS bit
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$binary_quantize$function$
;

-- Permissions

ALTER FUNCTION public.binary_quantize(vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.binary_quantize(vector) TO helpdesk;

-- DROP FUNCTION public.cosine_distance(vector, vector);

CREATE OR REPLACE FUNCTION public.cosine_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$cosine_distance$function$
;

-- Permissions

ALTER FUNCTION public.cosine_distance(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.cosine_distance(vector, vector) TO helpdesk;

-- DROP FUNCTION public.cosine_distance(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.cosine_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_cosine_distance$function$
;

-- Permissions

ALTER FUNCTION public.cosine_distance(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.cosine_distance(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.cosine_distance(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.cosine_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_cosine_distance$function$
;

-- Permissions

ALTER FUNCTION public.cosine_distance(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.cosine_distance(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.gin_extract_query_trgm(text, internal, int2, internal, internal, internal, internal);

CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$
;

-- Permissions

ALTER FUNCTION public.gin_extract_query_trgm(text, internal, int2, internal, internal, internal, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gin_extract_query_trgm(text, internal, int2, internal, internal, internal, internal) TO helpdesk;

-- DROP FUNCTION public.gin_extract_value_trgm(text, internal);

CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$
;

-- Permissions

ALTER FUNCTION public.gin_extract_value_trgm(text, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gin_extract_value_trgm(text, internal) TO helpdesk;

-- DROP FUNCTION public.gin_trgm_consistent(internal, int2, text, int4, internal, internal, internal, internal);

CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$
;

-- Permissions

ALTER FUNCTION public.gin_trgm_consistent(internal, int2, text, int4, internal, internal, internal, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gin_trgm_consistent(internal, int2, text, int4, internal, internal, internal, internal) TO helpdesk;

-- DROP FUNCTION public.gin_trgm_triconsistent(internal, int2, text, int4, internal, internal, internal);

CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$
;

-- Permissions

ALTER FUNCTION public.gin_trgm_triconsistent(internal, int2, text, int4, internal, internal, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gin_trgm_triconsistent(internal, int2, text, int4, internal, internal, internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_compress(internal);

CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_compress(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_compress(internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_consistent(internal, text, int2, oid, internal);

CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_consistent(internal, text, int2, oid, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_consistent(internal, text, int2, oid, internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_decompress(internal);

CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_decompress(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_decompress(internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_distance(internal, text, int2, oid, internal);

CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_distance(internal, text, int2, oid, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_distance(internal, text, int2, oid, internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_in(cstring);

CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_in(cstring) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_in(cstring) TO helpdesk;

-- DROP FUNCTION public.gtrgm_options(internal);

CREATE OR REPLACE FUNCTION public.gtrgm_options(internal)
 RETURNS void
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE
AS '$libdir/pg_trgm', $function$gtrgm_options$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_options(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_options(internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_out(gtrgm);

CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_out(gtrgm) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_out(gtrgm) TO helpdesk;

-- DROP FUNCTION public.gtrgm_penalty(internal, internal, internal);

CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_penalty(internal, internal, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_penalty(internal, internal, internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_picksplit(internal, internal);

CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_picksplit(internal, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_picksplit(internal, internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal);

CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal) TO helpdesk;

-- DROP FUNCTION public.gtrgm_union(internal, internal);

CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$
;

-- Permissions

ALTER FUNCTION public.gtrgm_union(internal, internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.gtrgm_union(internal, internal) TO helpdesk;

-- DROP FUNCTION public.halfvec(halfvec, int4, bool);

CREATE OR REPLACE FUNCTION public.halfvec(halfvec, integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec$function$
;

-- Permissions

ALTER FUNCTION public.halfvec(halfvec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec(halfvec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.halfvec_accum(_float8, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_accum(double precision[], halfvec)
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_accum$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_accum(_float8, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_accum(_float8, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_add(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_add(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_add$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_add(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_add(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_avg(_float8);

CREATE OR REPLACE FUNCTION public.halfvec_avg(double precision[])
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_avg$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_avg(_float8) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_avg(_float8) TO helpdesk;

-- DROP FUNCTION public.halfvec_cmp(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_cmp(halfvec, halfvec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_cmp$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_cmp(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_cmp(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_combine(_float8, _float8);

CREATE OR REPLACE FUNCTION public.halfvec_combine(double precision[], double precision[])
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_combine$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_combine(_float8, _float8) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_combine(_float8, _float8) TO helpdesk;

-- DROP FUNCTION public.halfvec_concat(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_concat(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_concat$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_concat(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_concat(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_eq(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_eq(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_eq$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_eq(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_eq(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_ge(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_ge(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_ge$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_ge(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_ge(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_gt(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_gt(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_gt$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_gt(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_gt(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_in(cstring, oid, int4);

CREATE OR REPLACE FUNCTION public.halfvec_in(cstring, oid, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_in$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_in(cstring, oid, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_in(cstring, oid, int4) TO helpdesk;

-- DROP FUNCTION public.halfvec_l2_squared_distance(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_l2_squared_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_squared_distance$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_l2_squared_distance(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_l2_squared_distance(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_le(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_le(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_le$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_le(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_le(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_lt(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_lt(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_lt$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_lt(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_lt(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_mul(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_mul(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_mul$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_mul(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_mul(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_ne(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_ne(halfvec, halfvec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_ne$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_ne(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_ne(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_negative_inner_product(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_negative_inner_product(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_negative_inner_product$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_negative_inner_product(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_negative_inner_product(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_out(halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_out(halfvec)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_out$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_out(halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_out(halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_recv(internal, oid, int4);

CREATE OR REPLACE FUNCTION public.halfvec_recv(internal, oid, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_recv$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_recv(internal, oid, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_recv(internal, oid, int4) TO helpdesk;

-- DROP FUNCTION public.halfvec_send(halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_send(halfvec)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_send$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_send(halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_send(halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_spherical_distance(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_spherical_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_spherical_distance$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_spherical_distance(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_spherical_distance(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_sub(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.halfvec_sub(halfvec, halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_sub$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_sub(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_sub(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.halfvec_to_float4(halfvec, int4, bool);

CREATE OR REPLACE FUNCTION public.halfvec_to_float4(halfvec, integer, boolean)
 RETURNS real[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_to_float4$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_to_float4(halfvec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_to_float4(halfvec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.halfvec_to_sparsevec(halfvec, int4, bool);

CREATE OR REPLACE FUNCTION public.halfvec_to_sparsevec(halfvec, integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_to_sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_to_sparsevec(halfvec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_to_sparsevec(halfvec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.halfvec_to_vector(halfvec, int4, bool);

CREATE OR REPLACE FUNCTION public.halfvec_to_vector(halfvec, integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_to_vector$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_to_vector(halfvec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_to_vector(halfvec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.halfvec_typmod_in(_cstring);

CREATE OR REPLACE FUNCTION public.halfvec_typmod_in(cstring[])
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_typmod_in$function$
;

-- Permissions

ALTER FUNCTION public.halfvec_typmod_in(_cstring) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.halfvec_typmod_in(_cstring) TO helpdesk;

-- DROP FUNCTION public.hamming_distance(bit, bit);

CREATE OR REPLACE FUNCTION public.hamming_distance(bit, bit)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$hamming_distance$function$
;

-- Permissions

ALTER FUNCTION public.hamming_distance(bit, bit) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.hamming_distance(bit, bit) TO helpdesk;

-- DROP FUNCTION public.hnsw_bit_support(internal);

CREATE OR REPLACE FUNCTION public.hnsw_bit_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$hnsw_bit_support$function$
;

-- Permissions

ALTER FUNCTION public.hnsw_bit_support(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.hnsw_bit_support(internal) TO helpdesk;

-- DROP FUNCTION public.hnsw_halfvec_support(internal);

CREATE OR REPLACE FUNCTION public.hnsw_halfvec_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$hnsw_halfvec_support$function$
;

-- Permissions

ALTER FUNCTION public.hnsw_halfvec_support(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.hnsw_halfvec_support(internal) TO helpdesk;

-- DROP FUNCTION public.hnsw_sparsevec_support(internal);

CREATE OR REPLACE FUNCTION public.hnsw_sparsevec_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$hnsw_sparsevec_support$function$
;

-- Permissions

ALTER FUNCTION public.hnsw_sparsevec_support(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.hnsw_sparsevec_support(internal) TO helpdesk;

-- DROP FUNCTION public.hnswhandler(internal);

CREATE OR REPLACE FUNCTION public.hnswhandler(internal)
 RETURNS index_am_handler
 LANGUAGE c
AS '$libdir/vector', $function$hnswhandler$function$
;

-- Permissions

ALTER FUNCTION public.hnswhandler(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.hnswhandler(internal) TO helpdesk;

-- DROP FUNCTION public.inner_product(vector, vector);

CREATE OR REPLACE FUNCTION public.inner_product(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$inner_product$function$
;

-- Permissions

ALTER FUNCTION public.inner_product(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.inner_product(vector, vector) TO helpdesk;

-- DROP FUNCTION public.inner_product(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.inner_product(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_inner_product$function$
;

-- Permissions

ALTER FUNCTION public.inner_product(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.inner_product(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.inner_product(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.inner_product(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_inner_product$function$
;

-- Permissions

ALTER FUNCTION public.inner_product(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.inner_product(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.ivfflat_bit_support(internal);

CREATE OR REPLACE FUNCTION public.ivfflat_bit_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$ivfflat_bit_support$function$
;

-- Permissions

ALTER FUNCTION public.ivfflat_bit_support(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.ivfflat_bit_support(internal) TO helpdesk;

-- DROP FUNCTION public.ivfflat_halfvec_support(internal);

CREATE OR REPLACE FUNCTION public.ivfflat_halfvec_support(internal)
 RETURNS internal
 LANGUAGE c
AS '$libdir/vector', $function$ivfflat_halfvec_support$function$
;

-- Permissions

ALTER FUNCTION public.ivfflat_halfvec_support(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.ivfflat_halfvec_support(internal) TO helpdesk;

-- DROP FUNCTION public.ivfflathandler(internal);

CREATE OR REPLACE FUNCTION public.ivfflathandler(internal)
 RETURNS index_am_handler
 LANGUAGE c
AS '$libdir/vector', $function$ivfflathandler$function$
;

-- Permissions

ALTER FUNCTION public.ivfflathandler(internal) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.ivfflathandler(internal) TO helpdesk;

-- DROP FUNCTION public.jaccard_distance(bit, bit);

CREATE OR REPLACE FUNCTION public.jaccard_distance(bit, bit)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$jaccard_distance$function$
;

-- Permissions

ALTER FUNCTION public.jaccard_distance(bit, bit) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.jaccard_distance(bit, bit) TO helpdesk;

-- DROP FUNCTION public.l1_distance(vector, vector);

CREATE OR REPLACE FUNCTION public.l1_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$l1_distance$function$
;

-- Permissions

ALTER FUNCTION public.l1_distance(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l1_distance(vector, vector) TO helpdesk;

-- DROP FUNCTION public.l1_distance(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.l1_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l1_distance$function$
;

-- Permissions

ALTER FUNCTION public.l1_distance(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l1_distance(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.l1_distance(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.l1_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l1_distance$function$
;

-- Permissions

ALTER FUNCTION public.l1_distance(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l1_distance(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.l2_distance(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.l2_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_distance$function$
;

-- Permissions

ALTER FUNCTION public.l2_distance(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_distance(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.l2_distance(vector, vector);

CREATE OR REPLACE FUNCTION public.l2_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$l2_distance$function$
;

-- Permissions

ALTER FUNCTION public.l2_distance(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_distance(vector, vector) TO helpdesk;

-- DROP FUNCTION public.l2_distance(halfvec, halfvec);

CREATE OR REPLACE FUNCTION public.l2_distance(halfvec, halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_distance$function$
;

-- Permissions

ALTER FUNCTION public.l2_distance(halfvec, halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_distance(halfvec, halfvec) TO helpdesk;

-- DROP FUNCTION public.l2_norm(sparsevec);

CREATE OR REPLACE FUNCTION public.l2_norm(sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_norm$function$
;

-- Permissions

ALTER FUNCTION public.l2_norm(sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_norm(sparsevec) TO helpdesk;

-- DROP FUNCTION public.l2_norm(halfvec);

CREATE OR REPLACE FUNCTION public.l2_norm(halfvec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_norm$function$
;

-- Permissions

ALTER FUNCTION public.l2_norm(halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_norm(halfvec) TO helpdesk;

-- DROP FUNCTION public.l2_normalize(sparsevec);

CREATE OR REPLACE FUNCTION public.l2_normalize(sparsevec)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_normalize$function$
;

-- Permissions

ALTER FUNCTION public.l2_normalize(sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_normalize(sparsevec) TO helpdesk;

-- DROP FUNCTION public.l2_normalize(halfvec);

CREATE OR REPLACE FUNCTION public.l2_normalize(halfvec)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_l2_normalize$function$
;

-- Permissions

ALTER FUNCTION public.l2_normalize(halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_normalize(halfvec) TO helpdesk;

-- DROP FUNCTION public.l2_normalize(vector);

CREATE OR REPLACE FUNCTION public.l2_normalize(vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$l2_normalize$function$
;

-- Permissions

ALTER FUNCTION public.l2_normalize(vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.l2_normalize(vector) TO helpdesk;

-- DROP FUNCTION public.set_limit(float4);

CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$
;

-- Permissions

ALTER FUNCTION public.set_limit(float4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.set_limit(float4) TO helpdesk;

-- DROP FUNCTION public.show_limit();

CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$
;

-- Permissions

ALTER FUNCTION public.show_limit() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.show_limit() TO helpdesk;

-- DROP FUNCTION public.show_trgm(text);

CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$
;

-- Permissions

ALTER FUNCTION public.show_trgm(text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.show_trgm(text) TO helpdesk;

-- DROP FUNCTION public.similarity(text, text);

CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$
;

-- Permissions

ALTER FUNCTION public.similarity(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.similarity(text, text) TO helpdesk;

-- DROP FUNCTION public.similarity_dist(text, text);

CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$
;

-- Permissions

ALTER FUNCTION public.similarity_dist(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.similarity_dist(text, text) TO helpdesk;

-- DROP FUNCTION public.similarity_op(text, text);

CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$
;

-- Permissions

ALTER FUNCTION public.similarity_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.similarity_op(text, text) TO helpdesk;

-- DROP FUNCTION public.sparsevec(sparsevec, int4, bool);

CREATE OR REPLACE FUNCTION public.sparsevec(sparsevec, integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec(sparsevec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec(sparsevec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.sparsevec_cmp(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_cmp(sparsevec, sparsevec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_cmp$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_cmp(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_cmp(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_eq(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_eq(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_eq$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_eq(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_eq(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_ge(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_ge(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_ge$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_ge(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_ge(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_gt(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_gt(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_gt$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_gt(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_gt(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_in(cstring, oid, int4);

CREATE OR REPLACE FUNCTION public.sparsevec_in(cstring, oid, integer)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_in$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_in(cstring, oid, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_in(cstring, oid, int4) TO helpdesk;

-- DROP FUNCTION public.sparsevec_l2_squared_distance(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_l2_squared_distance(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_l2_squared_distance$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_l2_squared_distance(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_l2_squared_distance(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_le(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_le(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_le$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_le(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_le(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_lt(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_lt(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_lt$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_lt(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_lt(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_ne(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_ne(sparsevec, sparsevec)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_ne$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_ne(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_ne(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_negative_inner_product(sparsevec, sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_negative_inner_product(sparsevec, sparsevec)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_negative_inner_product$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_negative_inner_product(sparsevec, sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_negative_inner_product(sparsevec, sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_out(sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_out(sparsevec)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_out$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_out(sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_out(sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_recv(internal, oid, int4);

CREATE OR REPLACE FUNCTION public.sparsevec_recv(internal, oid, integer)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_recv$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_recv(internal, oid, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_recv(internal, oid, int4) TO helpdesk;

-- DROP FUNCTION public.sparsevec_send(sparsevec);

CREATE OR REPLACE FUNCTION public.sparsevec_send(sparsevec)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_send$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_send(sparsevec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_send(sparsevec) TO helpdesk;

-- DROP FUNCTION public.sparsevec_to_halfvec(sparsevec, int4, bool);

CREATE OR REPLACE FUNCTION public.sparsevec_to_halfvec(sparsevec, integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_to_halfvec$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_to_halfvec(sparsevec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_to_halfvec(sparsevec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.sparsevec_to_vector(sparsevec, int4, bool);

CREATE OR REPLACE FUNCTION public.sparsevec_to_vector(sparsevec, integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_to_vector$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_to_vector(sparsevec, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_to_vector(sparsevec, int4, bool) TO helpdesk;

-- DROP FUNCTION public.sparsevec_typmod_in(_cstring);

CREATE OR REPLACE FUNCTION public.sparsevec_typmod_in(cstring[])
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$sparsevec_typmod_in$function$
;

-- Permissions

ALTER FUNCTION public.sparsevec_typmod_in(_cstring) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.sparsevec_typmod_in(_cstring) TO helpdesk;

-- DROP FUNCTION public.strict_word_similarity(text, text);

CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$
;

-- Permissions

ALTER FUNCTION public.strict_word_similarity(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.strict_word_similarity(text, text) TO helpdesk;

-- DROP FUNCTION public.strict_word_similarity_commutator_op(text, text);

CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$
;

-- Permissions

ALTER FUNCTION public.strict_word_similarity_commutator_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.strict_word_similarity_commutator_op(text, text) TO helpdesk;

-- DROP FUNCTION public.strict_word_similarity_dist_commutator_op(text, text);

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$
;

-- Permissions

ALTER FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.strict_word_similarity_dist_commutator_op(text, text) TO helpdesk;

-- DROP FUNCTION public.strict_word_similarity_dist_op(text, text);

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$
;

-- Permissions

ALTER FUNCTION public.strict_word_similarity_dist_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.strict_word_similarity_dist_op(text, text) TO helpdesk;

-- DROP FUNCTION public.strict_word_similarity_op(text, text);

CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$
;

-- Permissions

ALTER FUNCTION public.strict_word_similarity_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.strict_word_similarity_op(text, text) TO helpdesk;

-- DROP FUNCTION public.subvector(halfvec, int4, int4);

CREATE OR REPLACE FUNCTION public.subvector(halfvec, integer, integer)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_subvector$function$
;

-- Permissions

ALTER FUNCTION public.subvector(halfvec, int4, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.subvector(halfvec, int4, int4) TO helpdesk;

-- DROP FUNCTION public.subvector(vector, int4, int4);

CREATE OR REPLACE FUNCTION public.subvector(vector, integer, integer)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$subvector$function$
;

-- Permissions

ALTER FUNCTION public.subvector(vector, int4, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.subvector(vector, int4, int4) TO helpdesk;

-- DROP AGGREGATE public.sum(vector);

-- Aggregate function public.sum(vector)
-- ERROR: more than one function named "public.sum";

-- Permissions

ALTER AGGREGATE public.sum(vector) OWNER TO helpdesk;
GRANT ALL ON AGGREGATE public.sum(vector) TO helpdesk;

-- DROP AGGREGATE public.sum(halfvec);

-- Aggregate function public.sum(halfvec)
-- ERROR: more than one function named "public.sum";

-- Permissions

ALTER AGGREGATE public.sum(halfvec) OWNER TO helpdesk;
GRANT ALL ON AGGREGATE public.sum(halfvec) TO helpdesk;

-- DROP FUNCTION public.uuid_generate_v1();

CREATE OR REPLACE FUNCTION public.uuid_generate_v1()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v1$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v1() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_generate_v1() TO helpdesk;

-- DROP FUNCTION public.uuid_generate_v1mc();

CREATE OR REPLACE FUNCTION public.uuid_generate_v1mc()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v1mc$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v1mc() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_generate_v1mc() TO helpdesk;

-- DROP FUNCTION public.uuid_generate_v3(uuid, text);

CREATE OR REPLACE FUNCTION public.uuid_generate_v3(namespace uuid, name text)
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v3$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v3(uuid, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_generate_v3(uuid, text) TO helpdesk;

-- DROP FUNCTION public.uuid_generate_v4();

CREATE OR REPLACE FUNCTION public.uuid_generate_v4()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v4() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_generate_v4() TO helpdesk;

-- DROP FUNCTION public.uuid_generate_v5(uuid, text);

CREATE OR REPLACE FUNCTION public.uuid_generate_v5(namespace uuid, name text)
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v5$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v5(uuid, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_generate_v5(uuid, text) TO helpdesk;

-- DROP FUNCTION public.uuid_nil();

CREATE OR REPLACE FUNCTION public.uuid_nil()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_nil$function$
;

-- Permissions

ALTER FUNCTION public.uuid_nil() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_nil() TO helpdesk;

-- DROP FUNCTION public.uuid_ns_dns();

CREATE OR REPLACE FUNCTION public.uuid_ns_dns()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_dns$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_dns() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_ns_dns() TO helpdesk;

-- DROP FUNCTION public.uuid_ns_oid();

CREATE OR REPLACE FUNCTION public.uuid_ns_oid()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_oid$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_oid() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_ns_oid() TO helpdesk;

-- DROP FUNCTION public.uuid_ns_url();

CREATE OR REPLACE FUNCTION public.uuid_ns_url()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_url$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_url() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_ns_url() TO helpdesk;

-- DROP FUNCTION public.uuid_ns_x500();

CREATE OR REPLACE FUNCTION public.uuid_ns_x500()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_x500$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_x500() OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.uuid_ns_x500() TO helpdesk;

-- DROP FUNCTION public.vector(vector, int4, bool);

CREATE OR REPLACE FUNCTION public.vector(vector, integer, boolean)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector$function$
;

-- Permissions

ALTER FUNCTION public.vector(vector, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector(vector, int4, bool) TO helpdesk;

-- DROP FUNCTION public.vector_accum(_float8, vector);

CREATE OR REPLACE FUNCTION public.vector_accum(double precision[], vector)
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_accum$function$
;

-- Permissions

ALTER FUNCTION public.vector_accum(_float8, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_accum(_float8, vector) TO helpdesk;

-- DROP FUNCTION public.vector_add(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_add(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_add$function$
;

-- Permissions

ALTER FUNCTION public.vector_add(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_add(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_avg(_float8);

CREATE OR REPLACE FUNCTION public.vector_avg(double precision[])
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_avg$function$
;

-- Permissions

ALTER FUNCTION public.vector_avg(_float8) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_avg(_float8) TO helpdesk;

-- DROP FUNCTION public.vector_cmp(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_cmp(vector, vector)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_cmp$function$
;

-- Permissions

ALTER FUNCTION public.vector_cmp(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_cmp(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_combine(_float8, _float8);

CREATE OR REPLACE FUNCTION public.vector_combine(double precision[], double precision[])
 RETURNS double precision[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_combine$function$
;

-- Permissions

ALTER FUNCTION public.vector_combine(_float8, _float8) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_combine(_float8, _float8) TO helpdesk;

-- DROP FUNCTION public.vector_concat(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_concat(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_concat$function$
;

-- Permissions

ALTER FUNCTION public.vector_concat(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_concat(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_dims(halfvec);

CREATE OR REPLACE FUNCTION public.vector_dims(halfvec)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$halfvec_vector_dims$function$
;

-- Permissions

ALTER FUNCTION public.vector_dims(halfvec) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_dims(halfvec) TO helpdesk;

-- DROP FUNCTION public.vector_dims(vector);

CREATE OR REPLACE FUNCTION public.vector_dims(vector)
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_dims$function$
;

-- Permissions

ALTER FUNCTION public.vector_dims(vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_dims(vector) TO helpdesk;

-- DROP FUNCTION public.vector_eq(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_eq(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_eq$function$
;

-- Permissions

ALTER FUNCTION public.vector_eq(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_eq(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_ge(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_ge(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_ge$function$
;

-- Permissions

ALTER FUNCTION public.vector_ge(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_ge(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_gt(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_gt(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_gt$function$
;

-- Permissions

ALTER FUNCTION public.vector_gt(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_gt(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_in(cstring, oid, int4);

CREATE OR REPLACE FUNCTION public.vector_in(cstring, oid, integer)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_in$function$
;

-- Permissions

ALTER FUNCTION public.vector_in(cstring, oid, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_in(cstring, oid, int4) TO helpdesk;

-- DROP FUNCTION public.vector_l2_squared_distance(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_l2_squared_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_l2_squared_distance$function$
;

-- Permissions

ALTER FUNCTION public.vector_l2_squared_distance(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_l2_squared_distance(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_le(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_le(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_le$function$
;

-- Permissions

ALTER FUNCTION public.vector_le(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_le(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_lt(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_lt(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_lt$function$
;

-- Permissions

ALTER FUNCTION public.vector_lt(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_lt(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_mul(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_mul(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_mul$function$
;

-- Permissions

ALTER FUNCTION public.vector_mul(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_mul(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_ne(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_ne(vector, vector)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_ne$function$
;

-- Permissions

ALTER FUNCTION public.vector_ne(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_ne(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_negative_inner_product(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_negative_inner_product(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_negative_inner_product$function$
;

-- Permissions

ALTER FUNCTION public.vector_negative_inner_product(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_negative_inner_product(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_norm(vector);

CREATE OR REPLACE FUNCTION public.vector_norm(vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_norm$function$
;

-- Permissions

ALTER FUNCTION public.vector_norm(vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_norm(vector) TO helpdesk;

-- DROP FUNCTION public.vector_out(vector);

CREATE OR REPLACE FUNCTION public.vector_out(vector)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_out$function$
;

-- Permissions

ALTER FUNCTION public.vector_out(vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_out(vector) TO helpdesk;

-- DROP FUNCTION public.vector_recv(internal, oid, int4);

CREATE OR REPLACE FUNCTION public.vector_recv(internal, oid, integer)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_recv$function$
;

-- Permissions

ALTER FUNCTION public.vector_recv(internal, oid, int4) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_recv(internal, oid, int4) TO helpdesk;

-- DROP FUNCTION public.vector_send(vector);

CREATE OR REPLACE FUNCTION public.vector_send(vector)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_send$function$
;

-- Permissions

ALTER FUNCTION public.vector_send(vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_send(vector) TO helpdesk;

-- DROP FUNCTION public.vector_spherical_distance(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_spherical_distance(vector, vector)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_spherical_distance$function$
;

-- Permissions

ALTER FUNCTION public.vector_spherical_distance(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_spherical_distance(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_sub(vector, vector);

CREATE OR REPLACE FUNCTION public.vector_sub(vector, vector)
 RETURNS vector
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_sub$function$
;

-- Permissions

ALTER FUNCTION public.vector_sub(vector, vector) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_sub(vector, vector) TO helpdesk;

-- DROP FUNCTION public.vector_to_float4(vector, int4, bool);

CREATE OR REPLACE FUNCTION public.vector_to_float4(vector, integer, boolean)
 RETURNS real[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_to_float4$function$
;

-- Permissions

ALTER FUNCTION public.vector_to_float4(vector, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_to_float4(vector, int4, bool) TO helpdesk;

-- DROP FUNCTION public.vector_to_halfvec(vector, int4, bool);

CREATE OR REPLACE FUNCTION public.vector_to_halfvec(vector, integer, boolean)
 RETURNS halfvec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_to_halfvec$function$
;

-- Permissions

ALTER FUNCTION public.vector_to_halfvec(vector, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_to_halfvec(vector, int4, bool) TO helpdesk;

-- DROP FUNCTION public.vector_to_sparsevec(vector, int4, bool);

CREATE OR REPLACE FUNCTION public.vector_to_sparsevec(vector, integer, boolean)
 RETURNS sparsevec
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_to_sparsevec$function$
;

-- Permissions

ALTER FUNCTION public.vector_to_sparsevec(vector, int4, bool) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_to_sparsevec(vector, int4, bool) TO helpdesk;

-- DROP FUNCTION public.vector_typmod_in(_cstring);

CREATE OR REPLACE FUNCTION public.vector_typmod_in(cstring[])
 RETURNS integer
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/vector', $function$vector_typmod_in$function$
;

-- Permissions

ALTER FUNCTION public.vector_typmod_in(_cstring) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.vector_typmod_in(_cstring) TO helpdesk;

-- DROP FUNCTION public.word_similarity(text, text);

CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$
;

-- Permissions

ALTER FUNCTION public.word_similarity(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.word_similarity(text, text) TO helpdesk;

-- DROP FUNCTION public.word_similarity_commutator_op(text, text);

CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$
;

-- Permissions

ALTER FUNCTION public.word_similarity_commutator_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.word_similarity_commutator_op(text, text) TO helpdesk;

-- DROP FUNCTION public.word_similarity_dist_commutator_op(text, text);

CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$
;

-- Permissions

ALTER FUNCTION public.word_similarity_dist_commutator_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.word_similarity_dist_commutator_op(text, text) TO helpdesk;

-- DROP FUNCTION public.word_similarity_dist_op(text, text);

CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$
;

-- Permissions

ALTER FUNCTION public.word_similarity_dist_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.word_similarity_dist_op(text, text) TO helpdesk;

-- DROP FUNCTION public.word_similarity_op(text, text);

CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$
;

-- Permissions

ALTER FUNCTION public.word_similarity_op(text, text) OWNER TO helpdesk;
GRANT ALL ON FUNCTION public.word_similarity_op(text, text) TO helpdesk;


-- Permissions

GRANT ALL ON SCHEMA public TO pg_database_owner;
GRANT USAGE ON SCHEMA public TO public;
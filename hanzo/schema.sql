-- Hanzo Unified Analytics Schema
-- Combines web analytics, AI observability, and business metrics
-- Based on ClickHouse with optimizations for Hanzo platform

-- =============================================================================
-- DATABASE SETUP
-- =============================================================================
CREATE DATABASE IF NOT EXISTS hanzo;

-- =============================================================================
-- ORGANIZATIONS & PROJECTS (Core Identity)
-- =============================================================================
CREATE TABLE IF NOT EXISTS hanzo.organizations (
    id UUID,
    name String,
    slug String,
    created_at DateTime64(3) DEFAULT now(),
    updated_at DateTime64(3) DEFAULT now(),
    settings Map(String, String),
    INDEX idx_slug slug TYPE bloom_filter() GRANULARITY 1
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (id);

CREATE TABLE IF NOT EXISTS hanzo.projects (
    id UUID,
    organization_id UUID,
    name String,
    slug String,
    type LowCardinality(String), -- 'website', 'api', 'app', 'base'
    created_at DateTime64(3) DEFAULT now(),
    updated_at DateTime64(3) DEFAULT now(),
    settings Map(String, String),
    INDEX idx_org organization_id TYPE bloom_filter() GRANULARITY 1,
    INDEX idx_slug slug TYPE bloom_filter() GRANULARITY 1
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (organization_id, id);

-- =============================================================================
-- WEB ANALYTICS (from Umami/hanzo-analytics)
-- =============================================================================

-- Website Events (page views, custom events, interactions)
CREATE TABLE IF NOT EXISTS hanzo.website_events (
    project_id UUID,
    session_id UUID,
    visit_id UUID,
    event_id UUID,
    -- Session context
    hostname LowCardinality(String),
    browser LowCardinality(String),
    os LowCardinality(String),
    device LowCardinality(String),
    screen LowCardinality(String),
    language LowCardinality(String),
    country LowCardinality(String),
    region LowCardinality(String),
    city String,
    -- Page context
    url_path String,
    url_query String,
    page_title String,
    referrer_path String,
    referrer_query String,
    referrer_domain String,
    -- UTM tracking
    utm_source String,
    utm_medium String,
    utm_campaign String,
    utm_content String,
    utm_term String,
    -- Click IDs (advertising)
    gclid String,      -- Google
    fbclid String,     -- Facebook
    msclkid String,    -- Microsoft
    ttclid String,     -- TikTok
    li_fat_id String,  -- LinkedIn
    twclid String,     -- Twitter/X
    -- Event data
    event_type UInt32, -- 1=pageview, 2=custom event
    event_name String,
    tag String,
    distinct_id String,
    created_at DateTime64(3) DEFAULT now()
) ENGINE = MergeTree
PARTITION BY toYYYYMM(created_at)
ORDER BY (project_id, toStartOfHour(created_at), session_id, created_at)
PRIMARY KEY (project_id, toStartOfHour(created_at), session_id);

-- Event Properties (flexible key-value storage)
CREATE TABLE IF NOT EXISTS hanzo.event_properties (
    project_id UUID,
    session_id UUID,
    event_id UUID,
    url_path String,
    event_name String,
    property_key String,
    string_value Nullable(String),
    number_value Nullable(Decimal64(4)),
    date_value Nullable(DateTime64(3)),
    data_type UInt32, -- 1=string, 2=number, 3=date
    created_at DateTime64(3) DEFAULT now()
) ENGINE = MergeTree
ORDER BY (project_id, event_id, property_key, created_at);

-- Session Properties (user-level custom data)
CREATE TABLE IF NOT EXISTS hanzo.session_properties (
    project_id UUID,
    session_id UUID,
    property_key String,
    string_value Nullable(String),
    number_value Nullable(Decimal64(4)),
    date_value Nullable(DateTime64(3)),
    data_type UInt32,
    distinct_id String,
    created_at DateTime64(3) DEFAULT now()
) ENGINE = ReplacingMergeTree
ORDER BY (project_id, session_id, property_key);

-- =============================================================================
-- AI OBSERVABILITY (from LangFuse/hanzo-console)
-- =============================================================================

-- AI Traces (conversation threads, agent runs)
CREATE TABLE IF NOT EXISTS hanzo.ai_traces (
    id String,
    project_id UUID,
    timestamp DateTime64(3),
    name String,
    user_id Nullable(String),
    session_id Nullable(String),
    metadata Map(LowCardinality(String), String),
    release Nullable(String),
    version Nullable(String),
    public Bool DEFAULT false,
    bookmarked Bool DEFAULT false,
    tags Array(String),
    input Nullable(String) CODEC(ZSTD(3)),
    output Nullable(String) CODEC(ZSTD(3)),
    total_cost Nullable(Decimal64(12)),
    latency_ms Nullable(UInt64),
    created_at DateTime64(3) DEFAULT now(),
    updated_at DateTime64(3) DEFAULT now(),
    event_ts DateTime64(3),
    is_deleted UInt8 DEFAULT 0,
    INDEX idx_id id TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_user user_id TYPE bloom_filter() GRANULARITY 1,
    INDEX idx_session session_id TYPE bloom_filter() GRANULARITY 1,
    INDEX idx_metadata_key mapKeys(metadata) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_metadata_value mapValues(metadata) TYPE bloom_filter(0.01) GRANULARITY 1
) ENGINE = ReplacingMergeTree(event_ts, is_deleted)
PARTITION BY toYYYYMM(timestamp)
PRIMARY KEY (project_id, toDate(timestamp))
ORDER BY (project_id, toDate(timestamp), id);

-- AI Observations (LLM calls, spans, generations)
CREATE TABLE IF NOT EXISTS hanzo.ai_observations (
    id String,
    trace_id String,
    project_id UUID,
    type LowCardinality(String), -- 'generation', 'span', 'event'
    parent_observation_id Nullable(String),
    start_time DateTime64(3),
    end_time Nullable(DateTime64(3)),
    name String,
    metadata Map(LowCardinality(String), String),
    level LowCardinality(String), -- 'DEBUG', 'INFO', 'WARNING', 'ERROR'
    status_message Nullable(String),
    version Nullable(String),
    input Nullable(String) CODEC(ZSTD(3)),
    output Nullable(String) CODEC(ZSTD(3)),
    -- Model info
    model_name Nullable(String),
    model_id Nullable(String),
    model_parameters Nullable(String),
    -- Token usage
    prompt_tokens Nullable(UInt64),
    completion_tokens Nullable(UInt64),
    total_tokens Nullable(UInt64),
    usage_details Map(LowCardinality(String), UInt64),
    -- Cost tracking
    cost_details Map(LowCardinality(String), Decimal64(12)),
    total_cost Nullable(Decimal64(12)),
    -- Timing
    completion_start_time Nullable(DateTime64(3)),
    latency_ms Nullable(UInt64),
    time_to_first_token_ms Nullable(UInt64),
    -- Prompt management
    prompt_id Nullable(String),
    prompt_name Nullable(String),
    prompt_version Nullable(UInt16),
    created_at DateTime64(3) DEFAULT now(),
    updated_at DateTime64(3) DEFAULT now(),
    event_ts DateTime64(3),
    is_deleted UInt8 DEFAULT 0,
    INDEX idx_id id TYPE bloom_filter() GRANULARITY 1,
    INDEX idx_trace trace_id TYPE bloom_filter() GRANULARITY 1
) ENGINE = ReplacingMergeTree(event_ts, is_deleted)
PARTITION BY toYYYYMM(start_time)
PRIMARY KEY (project_id, type, toDate(start_time))
ORDER BY (project_id, type, toDate(start_time), id);

-- AI Scores (evaluations, ratings, metrics)
CREATE TABLE IF NOT EXISTS hanzo.ai_scores (
    id String,
    project_id UUID,
    trace_id String,
    observation_id Nullable(String),
    name String,
    value Decimal64(6),
    string_value Nullable(String),
    source LowCardinality(String), -- 'API', 'EVAL', 'ANNOTATION'
    comment Nullable(String),
    data_type LowCardinality(String), -- 'NUMERIC', 'CATEGORICAL', 'BOOLEAN'
    config_id Nullable(String),
    created_at DateTime64(3) DEFAULT now(),
    updated_at DateTime64(3) DEFAULT now(),
    event_ts DateTime64(3),
    is_deleted UInt8 DEFAULT 0,
    INDEX idx_trace trace_id TYPE bloom_filter() GRANULARITY 1
) ENGINE = ReplacingMergeTree(event_ts, is_deleted)
PARTITION BY toYYYYMM(created_at)
ORDER BY (project_id, name, toDate(created_at), id);

-- =============================================================================
-- BUSINESS METRICS (unified event tracking)
-- =============================================================================

-- Business Events (purchases, signups, conversions)
CREATE TABLE IF NOT EXISTS hanzo.business_events (
    id UUID DEFAULT generateUUIDv4(),
    project_id UUID,
    organization_id UUID,
    event_type LowCardinality(String), -- 'purchase', 'signup', 'subscription', 'api_call'
    event_name String,
    user_id Nullable(String),
    session_id Nullable(UUID),
    -- Financial
    revenue Nullable(Decimal64(4)),
    currency LowCardinality(String) DEFAULT 'USD',
    quantity Nullable(UInt32),
    -- Context
    source LowCardinality(String), -- 'web', 'api', 'mobile', 'agent'
    channel LowCardinality(String), -- 'organic', 'paid', 'referral'
    product_id Nullable(String),
    product_name Nullable(String),
    -- Custom properties
    properties Map(String, String),
    created_at DateTime64(3) DEFAULT now(),
    INDEX idx_user user_id TYPE bloom_filter() GRANULARITY 1,
    INDEX idx_product product_id TYPE bloom_filter() GRANULARITY 1
) ENGINE = MergeTree
PARTITION BY toYYYYMM(created_at)
ORDER BY (project_id, event_type, toStartOfHour(created_at), created_at);

-- API Usage Metrics
CREATE TABLE IF NOT EXISTS hanzo.api_metrics (
    id UUID DEFAULT generateUUIDv4(),
    project_id UUID,
    organization_id UUID,
    timestamp DateTime64(3) DEFAULT now(),
    endpoint String,
    method LowCardinality(String),
    status_code UInt16,
    latency_ms UInt32,
    -- Request context
    user_id Nullable(String),
    api_key_id Nullable(String),
    ip_address Nullable(String),
    user_agent Nullable(String),
    -- Resource usage
    tokens_used Nullable(UInt64),
    compute_units Nullable(Decimal64(4)),
    -- Billing
    cost Nullable(Decimal64(12)),
    -- Error tracking
    error_type Nullable(String),
    error_message Nullable(String)
) ENGINE = MergeTree
PARTITION BY toYYYYMM(timestamp)
ORDER BY (project_id, endpoint, toStartOfHour(timestamp), timestamp);

-- =============================================================================
-- INFRASTRUCTURE METRICS (compute, storage, network)
-- =============================================================================

-- Base Instance Metrics (PocketBase deployments)
CREATE TABLE IF NOT EXISTS hanzo.base_metrics (
    instance_id UUID,
    project_id UUID,
    timestamp DateTime64(3) DEFAULT now(),
    -- Resources
    cpu_percent Float32,
    memory_used_mb UInt32,
    memory_total_mb UInt32,
    disk_used_mb UInt64,
    disk_total_mb UInt64,
    -- Network
    network_rx_bytes UInt64,
    network_tx_bytes UInt64,
    -- Connections
    active_connections UInt32,
    -- Application metrics
    requests_per_second Float32,
    avg_response_time_ms Float32,
    error_rate Float32
) ENGINE = MergeTree
PARTITION BY toYYYYMM(timestamp)
ORDER BY (instance_id, timestamp)
TTL timestamp + INTERVAL 90 DAY;

-- App Deployment Metrics
CREATE TABLE IF NOT EXISTS hanzo.app_metrics (
    app_id UUID,
    project_id UUID,
    timestamp DateTime64(3) DEFAULT now(),
    -- Resources
    cpu_percent Float32,
    memory_used_mb UInt32,
    memory_limit_mb UInt32,
    -- Replicas
    desired_replicas UInt8,
    running_replicas UInt8,
    -- Network
    requests_total UInt64,
    requests_per_second Float32,
    avg_latency_ms Float32,
    p99_latency_ms Float32,
    -- Errors
    error_count UInt32,
    error_rate Float32,
    -- Container
    restarts UInt32,
    uptime_seconds UInt64
) ENGINE = MergeTree
PARTITION BY toYYYYMM(timestamp)
ORDER BY (app_id, timestamp)
TTL timestamp + INTERVAL 90 DAY;

-- =============================================================================
-- MATERIALIZED VIEWS (real-time aggregations)
-- =============================================================================

-- Hourly web analytics stats
CREATE MATERIALIZED VIEW IF NOT EXISTS hanzo.website_events_hourly_mv
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(hour)
ORDER BY (project_id, hour)
AS SELECT
    project_id,
    toStartOfHour(created_at) AS hour,
    uniqState(session_id) AS unique_sessions,
    uniqState(distinct_id) AS unique_visitors,
    countState() AS total_events,
    sumStateIf(1, event_type = 1) AS pageviews,
    sumStateIf(1, event_type = 2) AS custom_events
FROM hanzo.website_events
GROUP BY project_id, hour;

-- Daily AI usage stats
CREATE MATERIALIZED VIEW IF NOT EXISTS hanzo.ai_usage_daily_mv
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (project_id, day, model_name)
AS SELECT
    project_id,
    toDate(start_time) AS day,
    model_name,
    countState() AS total_calls,
    sumState(total_tokens) AS total_tokens,
    sumState(total_cost) AS total_cost,
    avgState(latency_ms) AS avg_latency
FROM hanzo.ai_observations
WHERE type = 'generation'
GROUP BY project_id, day, model_name;

-- Hourly API metrics
CREATE MATERIALIZED VIEW IF NOT EXISTS hanzo.api_metrics_hourly_mv
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(hour)
ORDER BY (project_id, endpoint, hour)
AS SELECT
    project_id,
    endpoint,
    toStartOfHour(timestamp) AS hour,
    countState() AS total_requests,
    sumStateIf(1, status_code >= 200 AND status_code < 300) AS success_count,
    sumStateIf(1, status_code >= 400) AS error_count,
    avgState(latency_ms) AS avg_latency,
    quantileState(0.99)(latency_ms) AS p99_latency,
    sumState(tokens_used) AS total_tokens,
    sumState(cost) AS total_cost
FROM hanzo.api_metrics
GROUP BY project_id, endpoint, hour;

-- =============================================================================
-- DICTIONARY TABLES (for JOINs and lookups)
-- =============================================================================

-- Model catalog for cost/token lookups
CREATE TABLE IF NOT EXISTS hanzo.model_catalog (
    id String,
    provider LowCardinality(String), -- 'openai', 'anthropic', 'together', 'hanzo'
    model_name String,
    display_name String,
    input_price Decimal64(12),  -- per 1M tokens
    output_price Decimal64(12), -- per 1M tokens
    context_window UInt32,
    max_output UInt32,
    supports_vision Bool DEFAULT false,
    supports_function_calling Bool DEFAULT false,
    updated_at DateTime64(3) DEFAULT now()
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY (provider, id);

-- =============================================================================
-- GRANTS & PERMISSIONS
-- =============================================================================

-- Create service user for console
-- CREATE USER IF NOT EXISTS hanzo_console IDENTIFIED BY 'secure_password';
-- GRANT SELECT, INSERT ON hanzo.* TO hanzo_console;

-- Create read-only user for analytics
-- CREATE USER IF NOT EXISTS hanzo_analytics_ro IDENTIFIED BY 'secure_password';
-- GRANT SELECT ON hanzo.* TO hanzo_analytics_ro;

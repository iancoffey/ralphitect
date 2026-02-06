# System Design: Webhook Dispatcher

## 1. High-Level Architecture
We will implement the "Transactional Outbox" pattern to ensure reliability.

`[API Service]` -> `(gRPC)` -> `[Webhook Service]` -> `[Postgres Queue Table]` -> `[Worker Pool]` -> `(HTTP)` -> `[External Client]`

## 2. Data Model (Postgres)
We will use a single table as a priority queue.

```sql
CREATE TABLE delivery_attempts (
    id UUID PRIMARY KEY,
    event_payload JSONB NOT NULL,
    target_url TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, PROCESSING, COMPLETED, FAILED, DEAD
    attempt_count INT DEFAULT 0,
    next_attempt_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_processing ON delivery_attempts (status, next_attempt_at) WHERE status IN ('PENDING', 'FAILED');

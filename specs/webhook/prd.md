# Product Requirement Document: Reliable Webhook Delivery Service

## 1. Objective
Build a dedicated microservice responsible for delivering event notifications to external customer endpoints with "at-least-once" delivery guarantees, exponential backoff, and strict idempotency.

## 2. Problem Statement
Current webhook delivery is tightly coupled to the monolithic API. Failures in customer endpoints cause thread pool exhaustion in the main app. We need to decouple this into an asynchronous worker queue.

## 3. User Stories
* **As an API User**, I want to register a URL endpoint so that I can receive JSON payloads when `order.created` events occur.
* **As a Developer**, I want the system to retry failed deliveries (HTTP 5xx) automatically so that transient network issues don't cause data loss.
* **As a Security Engineer**, I want all webhook payloads to be signed (HMAC-SHA256) so that customers can verify the sender identity.

## 4. Functional Requirements
1.  **Ingestion**: Accept an event payload + target URL via gRPC.
2.  **Persistence**: Store the event in a durable queue (Postgres or Redis Stream) before attempting delivery.
3.  **Retry Logic**:
    * Max Retries: 5
    * Strategy: Exponential Backoff (2s, 4s, 8s, 16s, 32s).
4.  **Security**:
    * Add header `X-Signature-256` containing the HMAC signature.
    * Add header `X-Request-Timestamp` to prevent replay attacks.

## 5. Non-Functional Requirements (Constraints)
* **Latency**: Ingestion acknowledgement < 50ms.
* **Throughput**: Support 5,000 events/second.
* **Observability**: Must emit Prometheus metrics for `delivery_attempts`, `success_rate`, and `dead_letter_queue_depth`.
* **Tech Stack**: Golang 1.22+, Postgres (pgx driver).

## 6. Definition of Done
* [ ] Unit tests coverage > 85%.
* [ ] Integration test simulating a "flaky" receiver (fails 3 times, succeeds on 4th).
* [ ] Load test verifying 5k/sec throughput without memory leaks.
i

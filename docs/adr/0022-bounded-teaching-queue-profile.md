# ADR-0022: Bounded teaching queue profile

## Status

Accepted for the initial host profile.

## Context

Teaching transports need an explicit scheduler and backpressure boundary. A
queue that is allowed to grow implicitly would make memory use and rejection
behavior dependent on the caller and would undermine deterministic operation.
At the same time, one fixed queue profile must not be confused with a global
limit on Twin-e learning capacity: deployments can use multiple caller-owned
queues and shards.

## Decision

Each caller-owned teaching queue is bounded by two configuration values:

- `TEACHING_MAX_QUEUED_REQUESTS = 64`
- `TEACHING_MAX_QUEUED_BYTES = 65536`

The byte bound counts complete encoded request frames, including transport
header and checksum bytes. The profile must fit at least one maximum-size
teaching wire frame. Both values are named constants in
`src/config/values.act` and are exposed through the public
`TeachingQueueProfile` contract.

Queue processing is caller-driven. The caller explicitly invokes bounded
processing work; the queue does not create a background loop, block on input,
or perform implicit filesystem I/O.

Admission rejects a request when either the request-count or encoded-byte
bound would be exceeded. Rejection is reported as a typed admission error and
does not mutate queue occupancy; requests are never silently dropped.

Per-call processing remains bounded by the compile-time profile value
`TEACHING_MAX_BATCH_ITEMS`. The value is declared once in
`src/config/values.act` and sizes both the batch and metrics arrays. Batch
metrics use the same fixed active-prefix bound and are returned to the caller;
no metrics collection grows with input history. Deployment profiles may
change this value and rebuild; total training capacity remains independent of
the selected per-call value.

These are the initial host profile values, not a limit on the number of
shards, users, queues, or total persisted knowledge. Queue ownership,
admission at capacity, scheduler behavior, and partial-batch reporting are
separate decisions and must remain explicit in the following contracts.

## Consequences

- No transport queue may claim unbounded capacity.
- Queue capacity can be changed through the canonical configuration module.
- The profile is testable without allocating queue storage or performing I/O.
- Processing cadence remains visible at the caller boundary and is
  deterministic for a given batch.
- Capacity failure is explicit and leaves the caller-owned occupancy state
  unchanged.
- Per-call work and returned metrics have fixed bounds independent of the
  total number of requests submitted over time.

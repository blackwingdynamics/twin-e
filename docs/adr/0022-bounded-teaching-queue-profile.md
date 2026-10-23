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
- Capacity rejection and processing semantics remain intentionally unimplemented
  until their own tests and contract are added.

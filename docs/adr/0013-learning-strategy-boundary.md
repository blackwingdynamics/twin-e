# ADR-0013: Bounded Learning Strategies and Training Boundaries

- **Status:** Accepted; planning baseline
- **Date:** 2026-10-19
- **Scope:** How caller-owned adapter output becomes bounded learned state
- **Related work:** ADR-0002, ADR-0007, ADR-0009, ADR-0010, ADR-0011,
  ADR-0012, Phase 7, Phase 8

## Context

Twin-e now has modality adapters that produce validated, integer-only
`AdapterEnvelope` values. It also has a bounded token-sequence training API
that creates context bindings, reinforces transitions, and reports training
metrics. These are two separate boundaries: an adapter describes input, while
the learning runtime decides which relationships become resident state.

The project needs an explicit learning plan before adding teacher, chat, or
other external integrations. A method must state what is learned, what is
reinforced, what is rejected, how capacity is handled, and how recall is
measured. Replaying input must remain deterministic and must not silently add
unbounded memory or persistence I/O.

## Decision

### 1. Learning unit

The first learning unit is a bounded ordered example. Its source is owned by
the caller; its adapter output is validated before training; and its training
representation is an existing `TokenSequence` or a future public equivalent
with the same bounded ownership contract. The unit may carry modality and
source metadata for routing and evaluation, but metadata alone does not become
an engine connection.

The learning runtime owns only the resulting bounded bindings, columns, and
transitions. It does not own the source document, provider session, UI state,
credentials, or transport retry queue.

### 2. Initial learning methods

The methods are introduced in this order:

1. **Single-example sequence learning:** create or reuse context bindings and
   reinforce the observed successor transitions. This is the current
   `train_token_sequence` behavior and is the baseline method.
2. **Deterministic replay:** train the same bounded example repeatedly and
   prove that existing bindings are reused, reinforcement is saturating, and
   replay does not create duplicate state.
3. **Contextual sequence learning:** train ordered examples where the same
   token has different predecessors or successors. Recall must demonstrate
   context separation and deterministic tie-breaking.
4. **Bounded curriculum batches:** submit a caller-defined finite sequence of
   examples, report per-example acceptance and metrics, and stop explicitly on
   capacity or validation errors. A batch must not imply an unbounded queue.
5. **Correction and competition policy:** represent competing successors as
   explicit alternatives. A correction is a documented training event that
   retains the earlier association and gives the replacement one additional
   bounded reinforcement. Selection and tie behavior are measurable; equal
   strengths use the existing lowest-index deterministic tie break.
6. **Cross-modality association:** bind compatible events from different
   modality envelopes only through a documented public integration contract.
   Modality adapters remain decoders; they do not invent semantic links.
7. **Decay and reclamation policy:** use the existing bounded decay and
   capacity/recovery boundaries only after replay, competition, and failure
   behavior are measured. Reclamation must be explicit and recoverable.

### 3. Teaching and external callers

A future teacher or chat service is a caller of the learning API, not part of
the adapter or IE core. It submits already available bounded examples and
receives typed admission and training metrics. Network transport, credentials,
prompt/session state, retries, and source acquisition remain outside
`src/adapters/` and the hot path.

No external provider is required for the first learning milestones. A local
fixture must be able to teach and recall bounded information deterministically.

### 4. Persistence boundary

Training mutates resident state only. `.brain` publication remains an
explicit caller-owned operation after a successful or intentionally retained
training transaction. A failed admission, capacity rejection, or failed save
must not be presented as successful learning.

### 5. Evidence rule

Every learning method requires executable acceptance and rejection tests before
its roadmap gate is marked complete. Evidence must include input size and
limits, metrics, repeatability, recall result, capacity behavior, and whether
the test used resident-only or persisted state. Hosted x86-64 evidence remains
separate from future Cortex-M evidence.

### 6. Teaching module structure and future pipelines

The learning-facing source tree will use a dedicated `src/teaching/` facade
above the existing adapters and IE training runtime:

```text
src/teaching/
├── teaching.act       # canonical public facade
├── contract.act       # bounded request, result, and error types
├── admission.act      # input validation before training mutation
├── metrics.act        # teaching and recall metrics
├── pipelines/
│   ├── direct.act     # fastest in-memory path
│   ├── batch.act      # finite batch submission
│   ├── replay.act     # deterministic repeated training
│   ├── multimodal.act # coordinated modality inputs
│   └── correction.act # competing and corrected associations
├── policies/
    ├── reinforcement.act
    ├── competition.act
    └── capacity.act
└── transport/                 # future input/output transport adapters
    ├── contract.act
    ├── stdin.act
    ├── wire.act
    ├── http.act
    ├── websocket.act
    └── unix_socket.act

```

The canonical facade and shared contract are stable boundaries. A pipeline
selects scheduling and learning policy; it does not duplicate adapter logic,
private IE state, or persistence implementation. Tests mirror the pipeline
names under `tests/` so each method has independent evidence.

Future transport options live under the planned `src/teaching/transport/`
boundary: local stdin/stdout, `std::wire`, HTTP endpoints, WebSockets, and Unix
sockets. These are delivery mechanisms, not learning methods. The first batch
implementation is caller-driven and fixed at TEACHING_MAX_BATCH_ITEMS = 8. It
processes requests in array order, reports a bounded result for every item,
skips invalid or unsupported items, and stops on the first runtime training
failure after retaining earlier accepted items. Each transport
adapter must translate requests into the same `TeachingRequest` contract and
remain outside `src/adapters/`, the IE core, and the training hot path. The
HTTP and WebSocket files are planned interfaces only until Actus has a suitable
TCP/socket standard library or an approved host bridge.

## Rejected alternatives

### One universal learning operation

Rejected because sequence replay, correction, cross-modality association, and
decay have different ownership, capacity, and evaluation requirements.

### Automatic learning from every adapter call

Rejected because conversion and learning are separate decisions. Callers must
explicitly choose when an accepted envelope becomes a training example.

### Unbounded history or replay queue

Rejected because bounded memory and deterministic failure behavior are core
Twin-e invariants.

### Automatic save after training

Rejected because persistence must remain explicit and outside hot-path
training; a save failure must not corrupt or replace live state.

## Consequences

Twin-e can grow from the current sequence trainer toward multimodal teaching
without coupling the engine to a provider or chat UI. The first deliverable is
not a general-purpose tutor: it is a reproducible local learning pipeline
whose accepted examples, reinforced transitions, recall, and capacity limits
are observable and testable.

# Phase 8 — Bounded Learning Strategies

## Status

**Planned.** This phase defines how validated adapter output becomes learned
Twin-e state. It does not add a provider, chat UI, network transport, or
automatic `.brain` persistence.

## Objective

Build a reproducible learning pipeline around the existing bounded training
runtime. The phase must explain how Twin-e learns an example, reinforces a
repeated example, separates context, handles corrections and capacity, links
compatible modalities, and proves recall without making claims about general
intelligence.

## Invariants

- Adapter conversion and learning admission remain separate explicit calls.
- Training input is bounded, integer-only, caller-owned, and deterministic.
- Existing bindings are reused; replay must not create duplicate state.
- Training performs no synchronous filesystem or network I/O.
- `.brain` save/load remains an explicit persistence boundary.
- Capacity, malformed input, and failed persistence are typed observable
  outcomes, not silent success.
- Every gate is closed only with executable tests and recorded evidence.

## Planned teaching structure

The learning entry point will be a `src/teaching/` facade. Adapters remain
responsible only for converting external data into bounded envelopes, while
the teaching layer selects how accepted examples are scheduled and learned:

```text
src/teaching/
├── teaching.act
├── contract.act
├── admission.act
├── metrics.act
├── pipelines/
│   ├── direct.act
│   ├── batch.act
│   ├── replay.act
│   ├── multimodal.act
│   └── correction.act
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

The first implementation target is `direct`, the in-memory path with the
lowest transport overhead. `batch`, `replay`, `multimodal`, and `correction`
will be added as separate pipelines over the same public contract. Their
tests will live beside the existing AIE tests under `tests/` and must prove
bounded work, deterministic results, and explicit failure behavior.

The planned transport boundary is `src/teaching/transport/`. It will contain
the future stdin/stdout, `std::wire`, HTTP, WebSocket, and Unix-socket
adapters. They will convert requests into the same teaching contract without
entering modality adapters or the AIE core. HTTP and WebSocket access are
future integration options, not requirements for the direct in-memory teaching
path; their files remain planned until Actus has a suitable TCP/socket
standard library or an approved host bridge.

## Gate 8.1 — Define the learning unit and public boundary

- [x] Define the bounded learning-example representation above
      `AdapterEnvelope` and existing `TokenSequence` APIs.
- [x] Define ownership, modality metadata, ordering, and rejection behavior.
- [x] Define the caller contract for submitting one example to training.
- [x] Confirm that teacher/chat/provider concerns stay outside the AIE core.

### Required evidence

- [x] ADR-0013 and a compiler-valid contract fixture agree on the boundary.
- [x] Invalid, empty, and oversized examples are rejected before mutation.

### Gate 8.1 evidence

`src/teaching/contract.act` defines the bounded `TeachingRequest`, policy mode,
typed rejection reasons, and result metrics. `src/teaching/admission.act`
validates the teaching version, replay bound, and nested adapter envelope
before any AIE state API is reachable. The canonical public facade is
`src/teaching/teaching.act`.

`tests/teaching_contract.act` is the compiler-valid contract fixture. It covers
valid adapter output, invalid request state, empty envelope, oversized
envelope, and oversized replay input. The fixture performs no fabric mutation,
filesystem I/O, network I/O, or persistence operation.

## Gate 8.2 — Baseline single-example teaching

- [x] Connect one accepted text adapter output to the existing bounded training
      entry point through public facades.
- [x] Report processed events, allocations, reinforced transitions, and active
      bindings.
- [x] Prove resident-only training performs no persistence or external I/O.

### Required evidence

- [x] A local fixture teaches one bounded example and recalls its learned
      transition.
- [x] Training metrics and failure paths are asserted.

### Gate 8.2 evidence

`src/teaching/pipelines/direct.act` implements the first teaching pipeline.
`teach_text_direct` calls `adapter::text`, reconstructs the bounded
`TokenSequence` contract from validated text events, and calls the existing
public `train_token_sequence` facade. It returns teaching metrics without
opening persistence or transport boundaries.

`tests/teaching_direct.act` proves one bounded `"AB"` example produces the
expected metrics and recalls `B` from prompt `A`. It also proves empty text is
rejected without changing the fabric active count. The fixture is resident-only
and performs no filesystem or network I/O.

## Gate 8.3 — Deterministic replay and reinforcement

- [x] Define repeated-example semantics and saturation behavior.
- [x] Prove replay reuses bindings and does not duplicate columns or links.
- [x] Measure state growth and reinforcement counters across repeated passes.

### Required evidence

- [x] Replay tests cover bounded repeated passes and invalid zero-pass input.
- [x] Snapshot/reload recall matches resident recall.

### Gate 8.3 evidence

`src/aie/runtime/training/sequence.act` now exposes a replay entry point that
locates the existing beginning-of-sequence root through the public binding and
arena contracts. It reuses that root and existing target bindings instead of
allocating a duplicate root for each pass. `src/teaching/pipelines/replay.act`
performs one initial training pass and then bounded replay passes up to
`TEACHING_MAX_REPLAY_PASSES`.

`tests/teaching_replay.act` trains `"AB"` three times and proves that only two
target columns are allocated, active bindings remain two, active columns remain
three including the root, and six transitions are reinforced. It also proves a
zero-pass request is rejected before fabric mutation and that the resident
recall matches recall after snapshot serialization and reload.

## Gate 8.4 — Context and sequence strategies

- [x] Define how predecessor context distinguishes otherwise identical token
      identities.
- [x] Define sequence boundaries, BOS/EOS handling, and deterministic tie
      breaking for competing successors.
- [x] Define rejection when a sequence exceeds available bounded capacity.

### Required evidence

- [x] Context separation and competing-successor tests pass.
- [x] Capacity rejection leaves the prior valid state recoverable.

### Gate 8.4 evidence

Sequence training derives each binding from the ordered predecessor/current
token pair. The first pair uses the fixed BOS token as predecessor; later pairs
use the preceding token, so identical token identities in different contexts
do not share a binding accidentally. Sequence admission rejects empty, invalid,
or oversized token sequences before mutation. Missing resident capacity is
reported as a bounded training error and does not publish a partial successor.

tests/aie_observation.act::test_observation_context_separates_predecessors
proves predecessor-sensitive encoding. The training suite proves deterministic
lowest-index selection when successor strengths tie and rejects a stronger
false-identity candidate. tests/aie_api.act::test_resident_recall_survives_capacity_rejection
proves that capacity rejection preserves the prior resident path and cache
state. BOS handling is exercised by the "AB" training and replay fixtures;
the final token remains a normal bounded event and EOS is not synthesized by
the training pipeline.

## Gate 8.5 — Bounded curriculum batches

- [x] Define finite caller-driven batches and per-example result reporting.
- [x] Bound batch size, resident work, and failure handling.
- [x] Define whether processing stops, skips, or quarantines a rejected item.

### Required evidence

- [x] Batch tests cover mixed valid/invalid input and deterministic ordering.
- [x] No unbounded queue or hidden allocation is introduced.

### Gate 8.5 evidence

The batch pipeline accepts a caller-owned fixed array with a maximum of eight
active requests. It processes the active prefix in order and returns one
bounded item result for each request. Invalid or unsupported items are skipped
and counted; a runtime training failure stops processing after earlier accepted
items, with no queue, retry loop, filesystem I/O, or hidden allocation.

The batch tests prove mixed valid/invalid ordering, per-item acceptance
results, deterministic accepted/rejected counts, and rejection of an oversized
batch before fabric mutation.

## Gate 8.6 — Correction and competition policy

- [x] Define how a new answer competes with an existing successor.
- [x] Define explicit correction events without silent deletion.
- [x] Measure tie, contradiction, and repeated-correction outcomes.

### Required evidence

- [x] Correction tests show the selected policy and preserve prior-state
      invariants on rejection.
- [x] Recall output reports ambiguity or deterministic selection explicitly.

### Gate 8.6 evidence

`src/teaching/pipelines/correction.act` treats a correction as an explicit
event. The original successor remains linked; the replacement is replayed
twice, giving the correction one additional reinforcement without deleting
the prior association. Equal strengths remain ambiguous and use the existing
lowest-index deterministic tie break during recall.

`tests/teaching_correction.act` proves that a correction preserves the old
successor, creates one competing replacement, reports ambiguity, and rejects
an invalid correction without mutating resident state. Repeated correction is
represented by the bounded replay reinforcement and remains saturating.

## Gate 8.7 — Cross-modality association

- [x] Define the public integration contract for associating compatible events
      from separate modality envelopes.
- [x] Keep modality decoders independent from semantic-link policy.
- [x] Define limits and rejection behavior for mismatched or oversized pairs.

### Required evidence

- [x] At least one text-plus-structured or text-plus-image fixture passes
      through public boundaries.
- [x] The fixture proves no adapter directly mutates private AIE state.

### Gate 8.7 evidence

`src/teaching/pipelines/multimodal.act` accepts only a bounded text-plus-
structured pair in this first implementation. Both envelopes are validated
through the public adapter contract, their events are namespaced into one
bounded sequence, and public `train_token_sequence` performs the learning.
The combined pair is limited to `TEACHING_MAX_ASSOCIATION_EVENTS = 16`; a
mismatched modality or oversized pair is rejected before fabric mutation.

`tests/teaching_multimodal.act` proves text and structured adapters reach the
public association boundary and that a text-plus-text pair is rejected with
zero active columns.

## Gate 8.8 — Decay, reclamation, and persistence interaction

- [x] Define when decay or reclamation may affect learned state.
- [x] Prove training does not synchronously flush or save `.brain` data.
- [x] Prove failed save/recovery leaves live learned state unchanged.

### Required evidence

- [x] Decay/reclamation tests cover valid state, capacity pressure, and
      recovery.
- [x] Persistence tests distinguish resident learning from published state.

### Gate 8.8 evidence

Decay remains an explicit caller-driven maintenance step through
`engine_clock_step`; teaching and replay only mutate resident fabric and
bindings and do not import or call filesystem persistence. Existing decay and
capacity tests cover reclamation and pressure behavior. The new
`tests/teaching_persistence.act` test trains resident state, corrupts a
snapshot header, and proves rejected recovery leaves the live active count and
packed state unchanged. Valid publication remains explicit through snapshot
serialization and the separate persistence boundary.

## Gate 8.9 — Full learning acceptance

- [x] Run formatter, lock, strict check, strict tests, and native build.
- [x] Record compiler revision, target, profile, input limits, metrics, and
      recall outputs.
- [x] Record known limits and unsupported learning behaviors.
- [x] Keep hosted evidence separate from embedded and hardware evidence.

### Gate 8.9 evidence

The full hosted acceptance run used Actus commit `2a6aa269`, installed binary
SHA-256 `d7184c4708ec2d8bf41cf61b3f10037980bd3063fe03bc2c9de7866d526fcc56`,
on `x86_64` Linux with the strict profile. `actus lock --check`, formatter
checks for all touched Actus sources, `actus check --strict`, and
`actus test --strict` passed; the final suite result was `99 passed; 0 failed`.
The strict native build produced `/tmp/twin-e-phase-8-persistence.aie` and
reported no floating-point instructions in generated native IR.

The tested input limits remain fixed and bounded: teaching sequences accept at
most 256 events, cross-modality associations at most 16 combined events, and
adapter envelopes at most 32 events. Direct teaching and replay recall the
deterministic `AB` successor; cross-modality teaching accepts the bounded
text-plus-structured pair and rejects mismatched modalities without mutation.
These are hosted compiler/runtime results only; no embedded or hardware
performance claim is made.

## Acceptance boundary

Phase 8 is complete when a local caller can submit bounded examples through a
documented public pipeline, Twin-e can learn and recall them deterministically,
replay and capacity behavior are measured, and persistence remains explicit.
This phase does not claim human-like understanding, emotional state, general
intelligence, or production-scale performance.

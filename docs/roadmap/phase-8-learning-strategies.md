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

- [ ] Connect one accepted text adapter output to the existing bounded training
      entry point through public facades.
- [ ] Report processed events, allocations, reinforced transitions, and active
      bindings.
- [ ] Prove resident-only training performs no persistence or external I/O.

### Required evidence

- [ ] A local fixture teaches one bounded example and recalls its learned
      transition.
- [ ] Training metrics and failure paths are asserted.

## Gate 8.3 — Deterministic replay and reinforcement

- [ ] Define repeated-example semantics and saturation behavior.
- [ ] Prove replay reuses bindings and does not duplicate columns or links.
- [ ] Measure state growth and reinforcement counters across repeated passes.

### Required evidence

- [ ] Replay tests cover one, two, and bounded repeated passes.
- [ ] Snapshot/reload recall matches resident recall.

## Gate 8.4 — Context and sequence strategies

- [ ] Define how predecessor context distinguishes otherwise identical token
      identities.
- [ ] Define sequence boundaries, BOS/EOS handling, and deterministic tie
      breaking for competing successors.
- [ ] Define rejection when a sequence exceeds available bounded capacity.

### Required evidence

- [ ] Context separation and competing-successor tests pass.
- [ ] Capacity rejection leaves the prior valid state recoverable.

## Gate 8.5 — Bounded curriculum batches

- [ ] Define finite caller-driven batches and per-example result reporting.
- [ ] Bound batch size, resident work, and failure handling.
- [ ] Define whether processing stops, skips, or quarantines a rejected item.

### Required evidence

- [ ] Batch tests cover mixed valid/invalid input and deterministic ordering.
- [ ] No unbounded queue or hidden allocation is introduced.

## Gate 8.6 — Correction and competition policy

- [ ] Define how a new answer competes with an existing successor.
- [ ] Define explicit correction events without silent deletion.
- [ ] Measure tie, contradiction, and repeated-correction outcomes.

### Required evidence

- [ ] Correction tests show the selected policy and preserve prior-state
      invariants on rejection.
- [ ] Recall output reports ambiguity or deterministic selection explicitly.

## Gate 8.7 — Cross-modality association

- [ ] Define the public integration contract for associating compatible events
      from separate modality envelopes.
- [ ] Keep modality decoders independent from semantic-link policy.
- [ ] Define limits and rejection behavior for mismatched or oversized pairs.

### Required evidence

- [ ] At least one text-plus-structured or text-plus-image fixture passes
      through public boundaries.
- [ ] The fixture proves no adapter directly mutates private AIE state.

## Gate 8.8 — Decay, reclamation, and persistence interaction

- [ ] Define when decay or reclamation may affect learned state.
- [ ] Prove training does not synchronously flush or save `.brain` data.
- [ ] Prove failed save/recovery leaves live learned state unchanged.

### Required evidence

- [ ] Decay/reclamation tests cover valid state, capacity pressure, and
      recovery.
- [ ] Persistence tests distinguish resident learning from published state.

## Gate 8.9 — Full learning acceptance

- [ ] Run formatter, lock, strict check, strict tests, and native build.
- [ ] Record compiler revision, target, profile, input limits, metrics, and
      recall outputs.
- [ ] Record known limits and unsupported learning behaviors.
- [ ] Keep hosted evidence separate from embedded and hardware evidence.

## Acceptance boundary

Phase 8 is complete when a local caller can submit bounded examples through a
documented public pipeline, Twin-e can learn and recall them deterministically,
replay and capacity behavior are measured, and persistence remains explicit.
This phase does not claim human-like understanding, emotional state, general
intelligence, or production-scale performance.

# Phase 10 — Teaching Ingestion and Transport Boundaries

## Status

**Planned.** Phase 8 defines and tests how accepted examples become learned
state. Phase 9 completes bounded auxiliary fan-out. This phase defines how a
caller supplies those examples to the teaching API without mixing input
transport, modality decoding, learning policy, or persistence.

## Objective

Provide a documented, bounded, testable way to submit teaching data to Twin-e.
The first usable path is local and in-memory. File, stdin, and `std::wire`
inputs are added only through the same public teaching contract. HTTP,
WebSocket, and Unix-socket support remain later transport implementations;
they must not force network code into the AIE core or the learning hot path.

This phase answers the practical question: “What do I call, what data do I
send, what result do I receive, and what happens when the input is rejected?”
It does not add a chat assistant, an external teacher/provider, automatic
persistence, or claims of general intelligence.

## Invariants

- Every input path produces the same bounded `TeachingRequest` contract.
- Transport framing never performs modality decoding or fabric mutation.
- Adapters decode source data; teaching admission validates it; pipelines learn
  it; persistence publishes it. These are separate boundaries.
- Input size, event count, replay passes, batch size, and queued work have
  explicit fixed limits.
- No synchronous filesystem or network I/O occurs in inference, forwarding,
  neurogenesis, or teaching mutation.
- Rejection is typed and occurs before resident state mutation.
- A transport failure cannot be reported as successful learning.
- `.brain` save/load remains an explicit caller-owned operation.
- Every gate is closed only after executable tests and recorded evidence pass.

## Planned source structure

The phase extends the already accepted teaching structure without moving
modality code into it:

```text
src/teaching/
├── teaching.act                 # one public teaching entry facade
├── contract.act                 # request/result/error contract
├── admission.act                # validation before mutation
├── metrics.act                  # bounded counters and outcomes
├── pipelines/
│   ├── direct.act                # existing in-memory baseline
│   ├── batch.act                 # existing finite batch path
│   ├── replay.act                # existing deterministic replay path
│   ├── multimodal.act            # existing bounded association path
│   └── correction.act             # existing correction path
└── transport/
    ├── contract.act              # framing and transport result contract
    ├── file.act                  # bounded offline dataset input
    ├── stdin.act                 # local interactive/pipe input
    ├── wire.act                  # framed std::wire input
    ├── http.act                  # future host boundary
    ├── websocket.act              # future host boundary
    └── unix_socket.act             # future host boundary
```

The transport files are not interchangeable teaching implementations. Each
transport parses its own bounded framing and then calls the same teaching
facade. HTTP, WebSocket, and Unix-socket files remain planned until Actus has
an approved host networking boundary; no fake socket implementation or hidden
foreign-language fallback is allowed.

## Gate 10.1 — Freeze the caller-facing teaching request

- [ ] Write the exact `TeachingRequest` fields and their fixed-width types.
- [ ] Write the exact result fields: accepted events, rejected events,
      replay passes, reinforced transitions, active bindings, and outcome.
- [ ] Define whether one request contains one example or a finite batch.
- [ ] Define request identity, modality metadata, ordering, and sequence
      boundaries.
- [ ] Define ownership for source buffers, adapter envelopes, and output
      metrics at every call site.
- [ ] Define the maximum request bytes, events, batch items, and replay passes.
- [ ] Update ADR-0013 only if this freezes a decision not already covered.

### Required evidence

- [ ] `tests/teaching_input_contract.act` compiles through the public facade.
- [ ] Valid, empty, malformed, and oversized requests have typed outcomes.
- [ ] The invalid cases prove zero resident-state mutation.

## Gate 10.2 — Keep the direct in-memory path canonical

- [ ] Make `teaching::teach` the single public entry point used by callers.
- [ ] Route direct, batch, replay, correction, and multimodal calls through
      the same admission and metrics contract.
- [ ] Reject any transport that bypasses `admission.act` or calls private AIE
      state directly.
- [ ] Prove direct teaching remains the lowest-overhead path with no I/O.
- [ ] Document one minimal caller example for teaching the sequence `AB` and
      recalling its successor.

### Required evidence

- [ ] `tests/teaching_direct_public.act` imports only the canonical facade.
- [ ] The test proves identical results through the public facade and the
      existing direct pipeline.
- [ ] A hot-path audit finds no file, socket, or persistence operation.

## Gate 10.3 — Add bounded offline file ingestion

- [ ] Define the file format used by the first offline dataset fixture.
- [ ] Define one record per line or one length-delimited record; do not allow
      ambiguous delimiter parsing.
- [ ] Bound file bytes, record count, record bytes, and per-record events.
- [ ] Validate the complete record before passing it to an adapter.
- [ ] Decide whether one malformed record rejects the whole file or produces a
      typed per-record rejection; record that decision in the contract.
- [ ] Keep file reading outside inference and resident teaching mutation.
- [ ] Ensure a failed read or malformed record leaves already published
      resident state unchanged according to the selected transaction policy.

### Required evidence

- [ ] A valid fixture teaches multiple records in deterministic order.
- [ ] Empty, truncated, oversized, and malformed files are rejected or
      reported according to the documented policy.
- [ ] Replaying the same file produces the same metrics and recall result.

## Gate 10.4 — Add stdin and pipe ingestion

- [ ] Define the stdin framing and end-of-input behavior.
- [ ] Distinguish clean end-of-input, malformed input, and transport read
      failure with typed outcomes.
- [ ] Bound the current record and total stream work; never collect an
      unbounded stdin stream in memory.
- [ ] Define flush/commit boundaries for a stream of records.
- [ ] Ensure a partial final record is rejected without being silently taught.
- [ ] Provide a reproducible Linux command that feeds a bounded fixture to the
      executable.

### Required evidence

- [ ] Valid stdin input reaches the same teaching contract as direct input.
- [ ] Empty input, partial input, oversized input, and early read failure are
      covered by tests.
- [ ] The executable reports per-request metrics without leaking source data.

## Gate 10.5 — Add framed `std::wire` transport

- [ ] Define the wire message type for a teaching request and its version.
- [ ] Define frame length, payload length, checksum, and maximum frame size.
- [ ] Define whether one frame is one request or whether a frame may contain a
      bounded batch.
- [ ] Reject unsupported versions, bad checksums, truncated frames, and
      oversized payloads before admission.
- [ ] Preserve request ordering and deterministic response correlation.
- [ ] Keep wire parsing independent from modality adapters and AIE state.

### Required evidence

- [ ] A split-frame fixture reconstructs one valid request deterministically.
- [ ] Corrupted, replayed, truncated, and oversized frames are rejected.
- [ ] A failed frame causes no partial teaching mutation.
- [ ] Native output confirms no floating-point instructions are introduced.

## Gate 10.6 — Define transport-independent batching and backpressure

- [ ] Define the maximum number of queued requests and maximum queued bytes.
- [ ] Choose caller-driven processing, bounded polling, or another explicit
      scheduler boundary.
- [ ] Define what happens at queue capacity: reject, stop, or report partial
      batch completion; do not silently drop data.
- [ ] Bound per-call work and metrics memory.
- [ ] Keep transport latency, adapter latency, admission latency, teaching
      latency, and persistence latency separate in benchmark output.
- [ ] Prove that no transport queue can grow without a fixed bound.

### Required evidence

- [ ] A queue-exhaustion fixture proves the live teaching state is unchanged by
      the rejected request.
- [ ] A mixed batch fixture proves deterministic ordering and explicit partial
      results.
- [ ] Repeated runs produce identical acceptance and rejection metrics.

## Gate 10.7 — Define the explicit persistence handoff

- [ ] Define when a caller may request `.brain` publication after teaching.
- [ ] Keep save/load outside transport parsing and learning mutation.
- [ ] Define the response state for “learned in resident memory” versus
      “successfully published”.
- [ ] Reject or clearly report a failed save without claiming persistence.
- [ ] Prove a failed save leaves live teaching state unchanged.
- [ ] Ensure restart recovery is tested through the existing shard-local
      persistence contract, including auxiliary data.

### Required evidence

- [ ] A teaching-then-save fixture distinguishes resident and published state.
- [ ] A failed-save fixture verifies unchanged live state.
- [ ] A restart fixture recalls the last complete published generation only.

## Gate 10.8 — Add observability and operator-facing diagnostics

- [ ] Define stable outcome names and typed error categories for each boundary.
- [ ] Report bounded counters without logging raw source content by default.
- [ ] Include request ID, modality, transport, limits, and outcome in metrics.
- [ ] Separate rejected input, adapter rejection, teaching rejection, transport
      failure, and persistence failure.
- [ ] Document which metrics are deterministic and which are timing-only.

### Required evidence

- [ ] Tests assert the public metrics shape for success and every failure
      category.
- [ ] A diagnostics fixture proves sensitive source payloads are not emitted
      in default output.
- [ ] Benchmark output reports each latency class separately.

## Gate 10.9 — Host networking decision boundary

- [ ] Decide whether HTTP, WebSocket, and Unix-socket support belongs in Actus
      std, a reviewed host bridge, or a later phase.
- [ ] Do not implement a network transport until the ownership, blocking-I/O,
      shutdown, and error contracts are accepted.
- [ ] If a host bridge is selected, define its ABI and keep it outside the AIE
      and teaching hot paths.
- [ ] If deferred, record the exact missing Actus capability and leave the
      transport modules planned rather than creating placeholders that claim
      support.

### Required evidence

- [ ] An ADR or ADR update records the decision and rejected alternatives.
- [ ] A compile-time visibility test proves deferred transports cannot be
      imported as if they were implemented.
- [ ] No HTTP/WebSocket claim is made until an executable integration test
      exists.

## Gate 10.10 — Full ingestion acceptance

- [ ] Run formatter checks for every touched Actus source.
- [ ] Run `actus lock --check`, `actus check --strict`, and `actus test --strict`.
- [ ] Run the native strict build and retain zero-float IR evidence.
- [ ] Run direct, file, stdin, and wire fixtures on the same bounded dataset.
- [ ] Record compiler revision, target, profile, input limits, metrics, and
      outputs in `docs/benchmarks/`.
- [ ] Record all unsupported transports and known limits.
- [ ] Keep hosted Linux evidence separate from future Cortex-M evidence.
- [ ] Mark Phase 10 complete only after every previous gate is green.

## Definition of done

Phase 10 is complete when a local caller can submit bounded teaching data by
direct API, file, stdin, and the selected framed transport; every path reaches
the same public teaching contract; rejection and capacity behavior are typed;
metrics distinguish each boundary; persistence remains explicit; and all
claims are backed by executable tests. HTTP, WebSocket, and Unix-socket
support are not considered complete without an accepted transport decision and
real integration evidence.

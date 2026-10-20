# Phase 10 — Teaching Ingestion and Transport Boundaries

## Status

**In progress.** Phase 8 defines and tests how accepted examples become learned
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

- [x] Write the exact `TeachingRequest` fields and their fixed-width types.
- [x] Write the exact result fields: accepted events, rejected events,
      replay passes, reinforced transitions, active bindings, and outcome.
- [x] Define whether one request contains one example or a finite batch.
- [x] Define request identity, modality metadata, ordering, and sequence
      boundaries.
- [x] Define ownership for source buffers, adapter envelopes, and output
      metrics at every call site.
- [x] Define the maximum request bytes, events, batch items, and replay passes.
- [x] Confirm that ADR-0013 already covers these decisions; no ADR update is
      required for this contract clarification.

### Gate 10.1 contract decisions

`TeachingRequest` is one bounded learning example with these fields: a `u16`
contract version, `TeachingMode`, one caller-owned `AdapterEnvelope`, a `u16`
replay-pass count, and a `Bool` validity marker. The envelope carries modality,
source length, event count, ordered events, and its own adapter contract
version. `TeachingMetrics` reports processed events, accepted examples, replay
passes, allocated columns, reinforced transitions, and active bindings.

One request contains one example. A finite batch is represented separately by
`TeachingBatch`, whose fixed array has eight slots and whose count is bounded by
`TEACHING_MAX_BATCH_ITEMS`. Event ordering is the envelope array order; source
offsets remain event metadata. A sequence boundary is the end of one request;
batch ordering is the active request prefix order.

Request identity is intentionally not stored in the AIE learning unit. A
future transport may attach a correlation ID at its own boundary, but the core
teaching contract remains deterministic and transport-neutral. Source buffers
and envelopes are caller-owned borrowed inputs at validation and teaching
boundaries; returned metrics are bounded values and do not retain source data.

The current limits are the existing bounded protocol constants: adapter
envelopes accept at most `ADAPTER_MAX_EVENTS` events, replay accepts one
through `TEACHING_MAX_REPLAY_PASSES` passes, and batches accept one through
`TEACHING_MAX_BATCH_ITEMS` requests. Invalid version, validity, envelope, and
replay state is rejected before any pipeline can reach resident AIE state.

### Required evidence

- [x] `tests/teaching_input_contract.act` compiles through the public facade.
- [x] Valid, empty, malformed, and oversized requests have typed outcomes.
- [x] The invalid cases prove zero resident-state mutation.

### Gate 10.1 evidence

`tests/teaching_input_contract.act` validates one ordered two-event request and
rejects an unknown contract version, zero replay passes, and an invalid
adapter envelope. `tests/teaching_contract.act` additionally covers empty and
oversized envelopes and oversized replay input. Admission only receives an
immutable request view and performs no fabric, filesystem, network, or
persistence operation, so every rejection occurs before resident mutation.

## Gate 10.2 — Keep the direct in-memory path canonical

- [x] Make `teaching::` the single public import facade used by callers, with
      one named public verb per learning shape instead of a false universal
      `teach()` operation.
- [x] Route the direct public request path through `admission.act` and the
      shared `TeachingMetrics` result contract.
- [x] Keep batch, replay, correction, and multimodal operations behind the
      same facade while preserving their distinct typed result contracts.
- [x] Reject any direct request that bypasses admission or calls private AIE
      state directly.
- [x] Prove direct teaching remains the lowest-overhead path with no I/O.
- [x] Document one minimal caller example for teaching the sequence `AB` and
      recalling its successor.

The universal single-verb alternative is intentionally rejected because
ADR-0013 gives batch, replay, correction, and multimodal teaching different
ownership, capacity, and result contracts. `teaching::` is the single import
boundary; `teach_direct_request`, `teach_batch`, `teach_token_sequence_replay`,
`teach_correction`, and `teach_association` are the named public operations.

### Required evidence

- [x] `tests/teaching_direct.act` imports only the canonical facade for the
      public request-path assertion.
- [x] The test proves the canonical direct request path returns the bounded
      metrics contract and reaches the same direct training behavior.
- [x] A hot-path audit finds no file, socket, or persistence operation.

### Gate 10.2 evidence

`teach_direct_request` validates the request through `admission.act`, accepts
only `TeachingMode.Direct`, converts the validated text envelope to the
existing bounded `TokenSequence`, and returns `TeachingMetrics`. The direct
string helper remains a convenience wrapper; it cannot bypass the validated
envelope path. `tests/teaching_direct.act` proves the canonical facade path
teaches `AB` and reports two processed events with one accepted example.

## Gate 10.3 — Add bounded offline file ingestion

- [x] Define the file format used by the first offline dataset fixture.
- [x] Define one record per line or one length-delimited record; do not allow
      ambiguous delimiter parsing.
- [x] Bound file bytes, record count, record bytes, and per-record events.
- [x] Validate the complete record before passing it to an adapter.
- [x] Decide whether one malformed record rejects the whole file or produces a
      typed per-record rejection; record that decision in the contract.
- [x] Keep file reading outside inference and resident teaching mutation.
- [x] Ensure a failed read or malformed record leaves already published
      resident state unchanged according to the selected transaction policy.

The file format is a five-byte header: four-byte magic `TWF1` plus an explicit
`u8` record count, followed by up to eight records. Each record is `u16`
little-endian payload length followed by exactly that many bytes. The file is
bounded to `2069` bytes, each record to `256` bytes, and the payload is passed
to the existing text adapter. The complete file is first checked for size,
header, framing, and adapter validity; any malformed file is rejected before
training. Valid records are then taught in file order. If a later resident
capacity failure occurs, earlier accepted records remain and the failure is
reported as `TeachingRejected`.

### Required evidence

- [x] A valid fixture teaches multiple records in deterministic order.
- [x] Truncated, oversized, and malformed files are rejected or
      reported according to the documented policy.
- [x] Replaying the same file produces the same metrics and recall result.

### Gate 10.3 evidence

`src/teaching/transport/file.act` performs metadata preflight, bounded
length-delimited parsing, adapter preflight, and ordered teaching through
`teach_direct_request`. `tests/teaching_file.act` proves two records are
taught in order, malformed/truncated/oversized inputs are rejected before
mutation, and repeated reads produce deterministic resident counts and
metrics.

## Gate 10.4 — Add stdin and pipe ingestion

- [x] Define the stdin framing and end-of-input behavior.
- [x] Distinguish clean end-of-input, malformed input, and transport read
      failure with typed outcomes.
- [x] Bound the current record and total stream work; never collect an
      unbounded stdin stream in memory.
- [x] Define flush/commit boundaries for a stream of records.
- [x] Ensure a partial final record is rejected without being silently taught.
- [x] Provide a reproducible Linux command that feeds a bounded fixture to the
      executable.

### Required evidence

- [x] Valid stdin input reaches the same teaching contract as direct input.
- [x] Empty input, partial input, oversized input, and early read failure are
      covered by tests. Empty, partial, and oversized input are executable-
      verified; injected EOF and read-failure mappings are covered by
      `tests/teaching_stdin.act`.
- [x] The executable reports per-request metrics without leaking source data.

### Gate 10.4 implementation status

The bounded stdin transport is implemented in `src/teaching/transport/stdin.act`.
It uses newline-delimited records, a fixed `256`-byte record buffer, at most
`TEACHING_FILE_MAX_RECORDS` records, and a total stream limit of
`TEACHING_STDIN_MAX_BYTES`. Clean EOF, empty input, partial final records,
oversized records, oversized streams, and read failures have typed outcomes;
accepted records call the canonical `teach_direct_request` path and return
bounded stream metrics.

The strict source formatter and executable build pass with zero floating-point
instructions in the generated native IR. The installed compiler revision is
`017ddad2`. The reproducible Linux fixture is:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-teaching-stdin.aie \
  benchmarks/aie_teaching_stdin.act
printf 'AB\n' | /tmp/twin-e-teaching-stdin.aie
```

The valid fixture returns `exit 0` and reports `records=1`, `accepted=1`,
`bytes=2`, `events=2`, `columns=2`, and `transitions=2` without printing the
source record. Empty input returns `exit 1` with `error_code=1`, a partial
`AB` record returns `exit 1` with `error_code=3`, and a 257-byte record returns
`exit 1` with `error_code=4`. Stream flush is explicit: stdin teaching only
updates resident state; persistence publication remains a separate save
operation.

The deterministic reader-injection seam is `stdin_classify_read_result` in
`src/teaching/transport/stdin.act`. It is used by the production `read_byte`
path and is tested for both clean EOF and `IoError.Failed` mapping. The full
strict suite reports `140 passed; 0 failed` after these checks.

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

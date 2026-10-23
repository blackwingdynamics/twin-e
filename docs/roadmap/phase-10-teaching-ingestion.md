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
they must not force network code into the IE core or the learning hot path.

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

src/cli/
├── cli.act                         # public CLI facade
├── contract.act                    # typed command configuration and errors
├── arguments.act                   # bounded argv and flag primitives
└── parser.act                      # command-shape validation

src/runner/runner.act               # engine operation orchestration
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

Request identity is intentionally not stored in the IE learning unit. A
future transport may attach a correlation ID at its own boundary, but the core
teaching contract remains deterministic and transport-neutral. Source buffers
and envelopes are caller-owned borrowed inputs at validation and teaching
boundaries; returned metrics are bounded values and do not retain source data.

The current limits are the existing bounded protocol constants: adapter
envelopes accept at most `ADAPTER_MAX_EVENTS` events, replay accepts one
through `TEACHING_MAX_REPLAY_PASSES` passes, and batches accept one through
`TEACHING_MAX_BATCH_ITEMS` requests. Invalid version, validity, envelope, and
replay state is rejected before any pipeline can reach resident IE state.

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
- [x] Reject any direct request that bypasses admission or calls private IE
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
  -o /tmp/twin-e-teaching-stdin.ie \
  benchmarks/ie_teaching_stdin.act
printf 'AB\n' | /tmp/twin-e-teaching-stdin.ie
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

## Gate 10.4.1 — Replace the demo entry point with a production teaching runner

The current package entry point is an IE demonstration program. It is useful
for a smoke check, but it is not a training runtime and must not be published
as the executable used by `twin-e-training`. This gate defines the first real
operator-facing entry point without changing the IE hot path.

### Production command contract

The package entry point accepts only an explicit bounded command shape:

```text
twin-e --init <brain.brain> --stdin [--save]
twin-e --load <brain.brain> --stdin [--save]
twin-e --init <brain.brain> --file <teaching.twf> [--save]
twin-e --load <brain.brain> --file <teaching.twf> [--save]
```

`--load` requires an existing published `.brain`; it never falls back to an
empty resident state. `--init` is the only explicit empty-state mode.
`--stdin` accepts the existing bounded newline teaching transport and
`--file` accepts the existing bounded length-delimited teaching transport.
`--save` is opt-in and publishes the updated combined brain only after the
teaching operation succeeds. The runner prints bounded status and metric
fields only; it never prints raw teaching records.

Stable exit codes are `0` for success, `2` for invalid command/configuration,
`3` for a missing, incompatible, corrupt, or partial brain, `4` for rejected
teaching input, and `5` for a failed explicit save.

- [Completed in Phase 11] Define the production command contract for loading a published brain,
      accepting bounded teaching input, reporting metrics, and requesting an
      explicit save.
- [Completed in Phase 11] Replace the demo-only package entry behavior with a production runner;
      keep the demonstration as a separate benchmark or example.
- [Completed in Phase 11] Define an explicit workspace/configuration input; do not hardcode the
      developer's home directory, dataset path, or brain path in source.
- [Completed in Phase 11] Require an explicit brain manifest or an explicit empty-brain creation
      mode; never silently start with an empty brain when a published brain was
      requested.
- [Completed in Phase 11] Define typed startup failures for missing, incompatible, corrupt, or
      partially published brain generations.
- [Completed in Phase 11] Route file and stdin teaching through the canonical `teaching::` facade;
      the runner must not access resident IE state directly.
- [Completed in Phase 11] Define stable process exit codes and bounded operator output. Default
      output must not print raw source records.
- [Completed in Phase 11] Keep the demo output and all fixed benchmark paths out of the production
      runner.

### Required evidence

- [Completed in Phase 11] A Linux executable starts from a clean workspace using only its explicit
      configuration.
- [Completed in Phase 11] Startup loads a valid published brain and rejects a missing or corrupt
      manifest before teaching begins.
- [Completed in Phase 11] A teaching request reaches the canonical facade and reports bounded
      metrics without source leakage.
- [Completed in Phase 11] Invalid configuration and invalid input produce stable non-zero exit
      codes without resident-state mutation.

## Gate 10.4.2 — Define the production brain lifecycle

This gate connects the production runner to the already accepted persistence
contract. A `.brain` artifact is learned state, not an executable. The runner
must load it from an explicit manifest and publish a new complete generation
only after an explicit save request.

- [Completed in Phase 10] Define the lifecycle states `Loaded`, `ResidentDirty`, `SaveRequested`,
      `Published`, and `SaveFailed` at the runner boundary.
- [Completed in Phase 11] Load the selected complete generation before accepting teaching input.
- [Completed in Phase 11] Keep teaching in resident memory; do not write synchronously from the
      inference or teaching mutation path.
- [Completed in Phase 11] Publish shard files before the manifest and never expose a partial
      generation as current.
- [Completed in Phase 11] Distinguish “accepted into resident memory” from “published to disk” in
      the public result and metrics.
- [Completed in Phase 11] Prove that a failed save leaves the live resident brain unchanged and
      does not claim persistence.
- [Completed in Phase 11] Prove that restart selects the newest complete generation and ignores an
      incomplete or incompatible generation.
- [Completed in Phase 11] Record dataset revision, Twin-e revision, compiler revision, target,
      binary checksum, limits, and output generation in the run manifest.
- [Completed in Phase 12] Keep the brain artifact repository separate from Twin-e source and from
      Actus source; connect them only through paths, manifests, and checksums.

### Required evidence

- [Completed in Phase 11] Load → teach → save → restart → recall passes with a real bounded
      dataset.
- [Completed in Phase 11] Failed-save and interrupted-publication fixtures preserve the previous
      published generation and the live resident state.
- [x] The run manifest and shard checksums identify the exact executable and
      input dataset used for the run.

      Evidence: `docs/benchmarks/phase-11-provenance.md` records the compiler
      and executable SHA-256, the ordered content hashes for every accepted
      TWF input, and the exact build/run commands. The published manifest and
      shard descriptors recorded by the Phase 11 production-acceptance run
      carry the shard count, ranges, and per-shard checksums before restart
      recovery.

## Gate 10.4.3 — Package a reproducible production release

- [Completed in Phase 11] Build a target-specific production executable from the production entry
      point with strict checking and zero-floating-point IR evidence.
- [Completed in Phase 12] Keep the executable, runtime manifest template, and operator
      instructions separate from `.brain` generations.
- [Completed in Phase 11] Publish a checksum for every executable and runtime manifest.
- [Completed in Phase 11] Provide a clean-workspace smoke command that loads a known complete brain
      generation and performs one bounded teaching or recall operation.
- [x] Reject a binary/manifest/compiler compatibility mismatch before loading
      resident state.
- [x] Define the rollback procedure to the previous executable and previous
      complete brain generation.
- [Completed in Phase 11] Record target, profile, compiler revision, source revision, and all
      input limits in the release evidence.

Evidence: ADR-0019 defines the compiled runtime compatibility profile in the
dynamic manifest header. Writers publish the profile version and validators
reject a mismatched value before logical state admission; the strict regression
test also recomputes the manifest checksum after tampering to prove the check
is not only checksum failure handling.

Rollback evidence: ADR-0020 defines the non-destructive executable/brain-pair
rollback procedure. `test_restart_recovery_selects_complete_auxiliary_generation`
rejects the newer incomplete generation and selects the previous complete one;
the compatibility regression test verifies that the selected executable
profile is checked before resident state loading.

### Required evidence

- [Completed in Phase 11] A clean Arch Linux workspace reproduces the release build and smoke run.
- [Completed in Phase 11] The published checksum and runtime metadata match the executable that
      produced the evidence.
- [x] A rollback fixture restores the previous executable/brain pair without
      mutating the newer generation.

## Gate 10.5 — Add framed `std::wire` transport

- [x] Define the wire message type for a teaching request and its version.
- [x] Define frame length, payload length, checksum, and maximum frame size.
- [x] Define whether one frame is one request or whether a frame may contain a
      bounded batch.
- [x] Reject unsupported versions, bad checksums, truncated frames, and
      oversized payloads before admission.
- [x] Preserve request ordering and deterministic response correlation.
- [x] Keep wire parsing independent from modality adapters and IE state.

### Required evidence

- [x] A split-frame fixture reconstructs one valid request deterministically.
- [x] Corrupted, replayed, truncated, and oversized frames are rejected.
- [x] A failed frame causes no partial teaching mutation.
- [x] Native output confirms no floating-point instructions are introduced.

## Gate 10.6 — Define transport-independent batching and backpressure

- [x] Define the maximum number of queued requests and maximum queued bytes.
- [x] Choose caller-driven processing, bounded polling, or another explicit
      scheduler boundary.
- [x] Define what happens at queue capacity: reject, stop, or report partial
      batch completion; do not silently drop data.
- [x] Bound per-call work and metrics memory through the canonical,
      compile-time `TEACHING_MAX_BATCH_ITEMS` profile.
- [Completed in Phase 11] Keep transport latency, adapter latency, admission
      latency, teaching latency, and persistence latency separate in benchmark
      output.
- [ ] Prove that no transport queue can grow without a fixed bound.

### Required evidence

- [ ] A queue-exhaustion fixture proves the live teaching state is unchanged by
      the rejected request.
- [ ] A mixed batch fixture proves deterministic ordering and explicit partial
      results.
- [ ] Repeated runs produce identical acceptance and rejection metrics.

## Gate 10.7 — Define the explicit persistence handoff

- [Completed in Phase 11] Define when a caller may request `.brain` publication after teaching.
- [Completed in Phase 11] Keep save/load outside transport parsing and learning mutation.
- [Completed in Phase 11] Define the response state for “learned in resident memory” versus
      “successfully published”.
- [Completed in Phase 11] Reject or clearly report a failed save without claiming persistence.
- [Completed in Phase 11] Prove a failed save leaves live teaching state unchanged.
- [Completed in Phase 11] Ensure restart recovery is tested through the existing shard-local
      persistence contract, including auxiliary data.

### Required evidence

- [Completed in Phase 11] A teaching-then-save fixture distinguishes resident and published state.
- [Completed in Phase 11] A failed-save fixture verifies unchanged live state.
- [Completed in Phase 11] A restart fixture recalls the last complete published generation only.

## Gate 10.8 — Add observability and operator-facing diagnostics

- [Completed in Phase 11] Define stable outcome names and typed error categories for each boundary.
- [Completed in Phase 11] Report bounded counters without logging raw source content by default.
- [ ] Include request ID, modality, transport, limits, and outcome in metrics.
- [ ] Separate rejected input, adapter rejection, teaching rejection, transport
      failure, and persistence failure.
- [Completed in Phase 11] Document which metrics are deterministic and which are timing-only.

### Required evidence

- [Completed in Phase 11] Tests assert the public metrics shape for success and every failure
      category.
- [Completed in Phase 11] A diagnostics fixture proves sensitive source payloads are not emitted
      in default output.
- [Completed in Phase 11] Benchmark output reports each latency class separately.

## Gate 10.9 — Host networking decision boundary

- [ ] Decide whether HTTP, WebSocket, and Unix-socket support belongs in Actus
      std, a reviewed host bridge, or a later phase.
- [ ] Do not implement a network transport until the ownership, blocking-I/O,
      shutdown, and error contracts are accepted.
- [ ] If a host bridge is selected, define its ABI and keep it outside the IE
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

- [Completed in Phase 12] Run formatter checks for every touched Actus source.
- [Completed in Phase 12] Run `actus lock --check`, `actus check --strict`, and `actus test --strict`.
- [Completed in Phase 12] Run the native strict build and retain zero-float IR evidence.
- [ ] Run direct, file, stdin, and wire fixtures on the same bounded dataset.
- [Completed in Phase 11] Record compiler revision, target, profile, input limits, metrics, and
      outputs in `docs/benchmarks/`.
- [Completed in Phase 11] Record all unsupported transports and known limits.
- [Completed in Phase 11] Keep hosted Linux evidence separate from future Cortex-M evidence.
- [ ] Mark Phase 10 complete only after every previous gate is green.

## Definition of done

### Phase 11 lifecycle handoff

The production lifecycle now continues through the multi-shard runner defined
in Phase 11: it loads one complete manifest generation, accepts bounded file
teaching input, publishes the complete shard generation explicitly, and
restores it into a fresh runner state. The hosted acceptance and known limits
are recorded in `docs/benchmarks/phase-11-production-acceptance.md` and
`docs/roadmap/phase-11-production-multi-shard-runtime.md`. This handoff does
not mark the separate Phase 10 transport or lifecycle gates complete.

Phase 10 is complete when a production runner, rather than the IE demo entry
point, can load a selected complete brain generation, accept bounded teaching
data by direct API, file, stdin, and the selected framed transport, and publish
an explicit new generation. Every path must reach the same public teaching
contract; rejection, capacity, startup, compatibility, and save behavior must
be typed; metrics must distinguish each boundary; and all claims must be
backed by executable tests and reproducible release evidence. HTTP, WebSocket,
and Unix-socket support are not considered complete without an accepted
transport decision and real integration evidence.

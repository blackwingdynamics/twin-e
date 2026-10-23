# ADR-0004: Phase 5 Runtime and Evidence Contracts

- **Status:** Accepted
- **Date:** 2026-10-05
- **Scope:** `.brain` persistence, tokenizer artifacts, bounded training,
  observation events, action routing, and Phase 5 evidence
- **Related work:** ADR-0001, ADR-0002, ADR-0003, Phase 5 roadmap

## Context

Phase 4 established a position-independent, manifest-driven storage system for
bounded shard files. Phase 5 extends that foundation into a runtime that can
restore learned state, train bounded token sequences, accept modality-neutral
observations, and emit validated actions.

These features cross several binary and runtime boundaries. Without one
explicit contract, a writer could produce a file that a later runtime accepts
with different tokenizer or context semantics, a failed load could partially
replace live state, or a benchmark could report a result without enough
information to reproduce it.

Phase 5 therefore needs stable compatibility rules, failure behavior, and an
evidence format before implementation work begins.

## Decision

Twin-e will implement Phase 5 as a versioned, deterministic, integer-only
runtime. Existing Phase 4 formats and public APIs remain compatible unless a
separate ADR approves a format or API change.

### 1. Compatibility identity

Every complete `.brain` generation must identify the profiles that determine
how its records are interpreted:

```text
brain_format_version
shard_format_version
tokenizer_version
context_version
codebook_version
minicolumn_stride_bytes
binding_stride_bytes
active_bit_profile
```

The values are compatibility metadata, not runtime pointers. A loader accepts
a generation only when every required value matches a supported profile and
all fixed strides and bounds are valid. Unknown future versions, unsupported
profiles, and mismatched tokenizer, context, or codebook metadata are typed
compatibility failures.

The current supported profile must be recorded in the Phase 5 implementation
and benchmark evidence. Changing a value that changes byte interpretation or
token identity requires a new version and an explicit migration decision.

### 2. Validation before publication

Loading and publishing follow the same safety rule:

1. Read the complete header and descriptor metadata.
2. Validate magic, versions, lengths, ranges, strides, checksums, and profile
   compatibility.
3. Validate all payload and sidecar records without mutating live state.
4. Construct the bounded candidate state.
5. Publish the candidate state only after every required validation succeeds.

If any step fails, the existing fabric, bindings, tokenizer metadata, and
context metadata remain unchanged. A partial file, temporary generation, or
stale descriptor is never a valid active generation.

### 3. Interrupted writes and recovery

Writers use the staged generation protocol from ADR-0003:

1. Write new shard data to temporary generation files.
2. Validate and checksum every temporary shard.
3. Write and validate the new manifest.
4. Publish the manifest generation atomically.
5. Remove obsolete temporary or superseded files only after publication.

Startup selects the newest complete generation whose manifest, descriptors,
shards, and compatibility metadata all validate. If publication is
interrupted, the previous complete generation remains usable and incomplete
files are ignored or reported as recoverable stale artifacts.

### 4. Hot-path boundary

Inference, coincidence evaluation, forwarding, training updates, and
neurogenesis operate on resident memory. They must not synchronously create,
write, rename, or checksum files. A newly changed shard becomes `Dirty` in
memory. Persistence happens only through an explicit save or flush boundary,
or through a separately documented background mechanism.

This boundary is part of the observable performance contract. Phase 5
benchmarks must report hot-path latency and persistence latency separately.

### 5. Deterministic runtime profile

Phase 5 remains integer-only. Token encoding, context binding, observation
encoding, successor selection, training updates, and benchmark expectations
must not require `f32`, `f64`, floating-point literals, or floating-point
instructions.

For identical supported inputs, profile versions, and initial state, the
runtime must produce identical serialized state, selected successor, action
event, and benchmark evidence fields. Tie-breaking and bounded limits must be
documented wherever multiple valid choices exist.

### 6. Artifact and event contracts

### 6.1 Bounded training input admission

The learning runtime accepts an already tokenized `TokenSequence` through the
public `validate_training_sequence` boundary. The boundary rejects invalid
tokenizer output, empty sequences, and sequences above the configured bounded
token capacity before any fabric or binding mutation occurs. It returns a
typed `TrainingInputError` and performs no allocation or filesystem I/O.

Later training operations must call this admission boundary before creating
context bindings, reinforcing successors, or allocating columns. This keeps
the event limit at the tokenizer contract and prevents an unbounded training
loop from being hidden inside the engine.

The resident training operation then processes the admitted sequence in order.
It derives one context key from each previous/current token pair, reuses an
existing binding when that pair is known, and otherwise allocates one bounded
column with the context code. The observed source-to-target axon is linked or
reinforced with saturating integer myelination. The arena capacity and fixed
binding count remain the admission limits; allocation failure returns a typed
training error and does not perform persistence I/O.

When more than one valid successor is available during generation, selection is
deterministic: the candidate with the strongest myelination wins, and equal
strengths are resolved by the lowest arena index. The regression fixture
`test_training_competing_successors_use_lowest_index_on_tie` verifies the tie
rule with two equally reinforced successors and a repeatable generated token.

Training recall must survive the existing snapshot boundary. The regression
fixture `test_training_recall_survives_snapshot_reload` trains the bounded
sequence `AB`, serializes the resulting fabric and bindings, restores them into
fresh resident state, and verifies that the restored state generates `B` from
the prompt `A`. This proves state continuity through the snapshot API without
claiming process restart behavior; the separate restart evidence remains part
of the persistence gates.

The repeatable training benchmark is `benchmarks/ie_training.act`. It reports
training duration separately from deterministic fields for processed events,
allocated columns, active bindings, and snapshot size. Its command, compiler
digest, conditions, and captured output are recorded in
`docs/benchmarks/phase-5-training.md`.

The tokenizer artifact must contain enough versioned vocabulary and merge-rule
metadata to reproduce encode and decode behavior after restart. The loader
must reject incompatible or oversized artifacts before replacing the active
tokenizer.

Observation events are bounded, modality-neutral values. They describe facts
such as obstacle, distance, person, motion, or direction without depending on
a camera, board, or device-driver ABI. Sensor adapters convert device data
into these events; the IE core consumes only validated events. Action adapters
receive bounded, validated actions such as `stop`, `move`, `turn`, `follow`,
or `signal`.

Malformed, unknown, stale, conflicting, or oversized events must return typed
errors or safe rejection results. They must not mutate live state or emit an
unvalidated action.

## Evidence contract

Every Phase 5 executable benchmark must record:

- the benchmark name and purpose;
- the exact command used;
- compiler version and binary digest;
- source commit and target profile;
- input sizes and configured bounds;
- deterministic output fields;
- pass or rejection result;
- latency or size units where measured;
- known host-only or debug-profile limitations.

Persistence evidence must distinguish logical state from resident memory and
must report whether the operation was a hot-path operation or an explicit
flush/save operation.

The canonical evidence line uses stable `key=value` fields, for example:

```text
IE_P5_CONTRACT profile=integer_v1 brain_format=1 tokenizer=1 context=1 codebook=1 deterministic=1 zero_float=1
```

Hot-path and persistence measurements use separate records:

```text
IE_P5_HOT_PATH inference_ns=<value> training_ns=<value> neurogenesis_ns=<value> disk_writes=0
IE_P5_PERSISTENCE save=1 flush_ns=<value> restart_recall=1 recovery=1
```

The placeholders above are a format contract, not unmeasured claims. A result
may be documented only after a real command produces the values.

## Consequences

### Positive consequences

- saved state can be rejected safely when its interpretation is incompatible;
- failed loads and interrupted saves cannot silently destroy live knowledge;
- hot-path measurements remain separate from disk and checkpoint latency;
- tokenizer, context, and observation behavior can be reproduced from versioned
  artifacts;
- hardware-neutral event and action boundaries keep the core testable on a
  normal computer before device integration;
- benchmark output becomes reviewable and comparable across commits.

### Costs

- every persisted artifact and benchmark needs explicit metadata;
- compatibility failures require typed handling and additional tests;
- deterministic behavior limits unconstrained runtime choices;
- the first Phase 5 implementation must maintain both in-memory and durable
  lifecycle states.

## Rejected alternatives

- Accepting any future or unknown format version and guessing its layout.
- Mutating live state while a file is still being validated.
- Writing a new shard synchronously from neurogenesis or inference.
- Coupling the core observation type directly to a camera, sensor, or board.
- Treating a passing host benchmark as proof of hardware performance.

## Acceptance criteria

Phase 5 contract work is complete when:

1. the supported compatibility profile is recorded and tested;
2. invalid, incompatible, truncated, and interrupted artifacts have defined
   rejection and recovery behavior;
3. the hot-path no-write rule is explicit;
4. deterministic integer-only evidence output is defined;
5. the Phase 5 implementation can add persistence, training, observations,
   actions, and hardware measurements without changing these rules implicitly.

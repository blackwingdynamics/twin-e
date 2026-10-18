# ADR-0010: Modality Adapter Boundary and Common Twin-e Input Contract

- **Status:** Accepted; implementation not started
- **Date:** 2026-10-19
- **Scope:** External-data adapters that convert text, images, audio, video,
  structured records, and binary input into Twin-e-compatible bounded input
- **Related work:** ADR-0001, ADR-0002, ADR-0007, ADR-0008, Phase 5.8

## Context

Twin-e must accept more than one kind of external data while keeping the AIE
core modality-neutral. Text, images, audio, video, structured records, and
binary payloads have different parsing, feature extraction, validation, and
source-boundary requirements. A single modality-specific encoder cannot safely
represent all of those inputs, and putting those concerns inside `src/aie/`
would couple the engine to external formats and violate its boundary.

The project also needs one stable call surface for future chat, teacher, and
sensor integrations. Each modality must therefore own its conversion logic,
while all converted data must pass through one bounded and versioned contract
before entering token, context, observation, training, or generation code.

## Decision

### 1. Module root and public namespace

The adapter subsystem will live under:

```text
src/adapter/
```

The singular `adapter` namespace is intentional and defines the public call
shape:

```text
adapter::text
adapter::image
adapter::audio
adapter::video
adapter::structured
adapter::binary
adapter::contract
```

The canonical facade will be `src/adapter/adapter.act`. No caller may bypass
this facade to import a private modality implementation. The facade and every
public child module require Actus documentation and regression coverage for
their public import path.

### 2. Modality modules

The first adapter set is fixed as follows:

- `text`: bounded byte, token, and context conversion for textual input;
- `image`: bounded visual feature or patch conversion;
- `audio`: bounded time-window and feature-event conversion;
- `video`: bounded frame or temporal-feature conversion;
- `structured`: validated records and typed field conversion;
- `binary`: bounded byte-oriented conversion for opaque or protocol payloads;
- `contract`: shared input types, limits, versions, validation, and conversion
  results.

Each modality owns its source-specific decoding and normalization. It must not
write directly into AIE arena state, choose successor links, or alter the
serialized `.brain` layout.

### 3. Common contract

Every modality must produce a versioned, bounded representation accepted by
`adapter::contract`. The contract must preserve, where applicable:

- modality identity and contract version;
- deterministic source ordering and bounded source offsets;
- bounded event count and payload size;
- integer-only normalized feature values;
- token, context, or observation identity;
- validation status and explicit rejection reasons.

The contract may feed existing tokenizer, encoding, and observation APIs, but
it must not silently invent an unbounded token stream, floating-point engine
state, or implicit filesystem operation.

### 4. Boundary and ownership

Adapters are translation boundaries, not a second AIE runtime. They may reject
malformed or oversized input before it reaches the engine, but AIE remains the
owner of bounded associative state, training, forwarding, neurogenesis, decay,
and persistence semantics. Adapter code must use the canonical AIE facade and
must not access private arena or persistence fields.

External I/O, network clients, UI integration, and provider-specific logic
remain outside the AIE hot path. An adapter invocation may receive already
available input, but inference, forwarding, coincidence evaluation, and
neurogenesis must not perform synchronous filesystem or network I/O.

### 5. Persistence and reproducibility

Adapters do not choose an implicit `.brain` location and do not auto-save
engine state. Persistence remains an explicit caller-owned operation using a
configured `Path`, with the existing validation and publication rules. Adapter
outputs must carry enough version and modality metadata for deterministic
replay and compatibility checks.

### 6. Implementation order

Implementation will proceed in this order:

1. define and test `adapter::contract`;
2. expose the canonical `adapter` facade and public child-module paths;
3. implement `adapter::text` against the existing bounded tokenizer and
   encoding contracts;
4. add `structured` and `binary` adapters;
5. add image, audio, and video adapters only after their bounded feature
   representation and resource envelope are documented;
6. add external chat or teacher integrations as separate boundary modules,
   without changing the core adapter contract or AIE persistence behavior.

## Rejected alternatives

### One universal encoder

Rejected because source-specific decoding and feature extraction cannot be
made correct or bounded by one generic encoder without hiding modality policy
and weakening validation.

### Modality code inside `src/aie/`

Rejected because it couples the engine to external formats and makes the AIE
core responsible for device, transport, or presentation concerns.

### Provider-specific adapters as the common contract

Rejected because a future chat, teacher, or external provider must not define
Twin-e's internal input identity or serialized compatibility rules.

### Automatic persistence from an adapter

Rejected because persistence is an explicit save boundary and must remain
outside inference, forwarding, and neurogenesis hot paths.

## Consequences

Twin-e gains a stable modality-neutral entry boundary while preserving
modality-specific correctness and bounded resource behavior. The initial
implementation requires a new public facade and contract tests before any
image, audio, video, chat, or teacher integration can be considered complete.
The adapter contract does not claim semantic understanding or lossless
conversion for arbitrary external data; each modality must document its
representation limits and rejected inputs.

## Evidence boundary

This ADR records the accepted architecture and naming only. No adapter module,
directory, external service, network endpoint, `.brain` default path, or
modality encoder is implemented by this decision.

# ADR-0010: Modality Adapter Boundary and Common Twin-e Input Contract

- **Status:** Accepted; implementation in progress
- **Date:** 2026-10-19
- **Scope:** External-data adapters that convert text, images, audio, video,
  structured records, and binary input into Twin-e-compatible bounded input
- **Related work:** ADR-0001, ADR-0002, ADR-0007, ADR-0008, Phase 5.8, Phase 7

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
src/adapters/
```

The filesystem root is plural, while the singular `adapter` namespace is the
intentional public call shape:

```text
adapter::text
adapter::image
adapter::audio
adapter::video
adapter::structured
adapter::binary
adapter::contract
```

The canonical facade source will be `src/adapters/adapters.act`. It defines
the public `adapter` namespace; therefore callers use `adapter::text`,
`adapter::image`, and the other public child paths. No caller may bypass this
facade to import a private modality implementation. The facade and every
public child module require Actus documentation and regression coverage for
their public import path.

The naming decision has no migration cost because the adapter directory and
facade do not exist yet. Before implementation, a path or namespace change
must be made as one documented design change. If implementation is rolled
back, the adapter directory and its tests are removed together; existing
tokenizer, sensor, action, AIE, and persistence APIs remain unchanged.

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

### 3.1 Common adapter envelope

The common adapter result is a bounded envelope containing metadata and an
ordered, fixed-capacity sequence of normalized integer events. The envelope is
not a replacement for `ObservationEvent`; it is the modality-neutral boundary
above the existing tokenizer, encoding, and observation facades.

The envelope carries:

- `contract_version`: the adapter contract version, separate from tokenizer,
  context, codebook, and observation versions;
- `modality`: a stable discriminator for text, image, audio, video,
  structured, or binary input;
- `event_count`: the number of valid events in the bounded sequence;
- `source_length`: the bounded length of the accepted source;
- `events`: ordered normalized events, each carrying a source offset, a
  feature discriminator, an integer identity/value pair, and bounded flags.

The initial hosted envelope limits are `256` events and a `u32` source length;
the event representation uses fixed-width integer fields only. These limits
are admission limits, not promises that every modality can represent every
source losslessly. A modality must reject input that cannot be represented
within its documented envelope before the AIE state is touched.

The contract defines these rejection classes: unsupported contract version,
unsupported modality, empty input where the modality forbids it, source or
event count overflow, invalid source ordering, unsupported source encoding,
out-of-range normalized values, and malformed modality data. Rejection returns
typed status and leaves tokenizer, observation, arena, and persistence state
unchanged.

The caller retains ownership of the source view. An adapter must not retain a
source pointer or view after the call, must not perform external I/O, and must
return a self-contained bounded result. The result may be passed to existing
public facades, but it must not expose private arena, binding, shard, or
persistence fields.

The text adapter is the first implemented modality. `adapter::text` delegates
byte tokenization and bounded BPE merging to the existing `tokenizer` facade,
preserves token identities and source byte spans, and exposes String and raw
byte-fallback entry points. The envelope is validated before it is returned;
empty, malformed, and oversized input is rejected without engine-state
mutation.

The structured adapter uses a fixed 32-key schema and fixed 32-field record;
all schema keys are required, ordered source offsets are explicit, keys must be
known and unique, values are bounded integers, and schema/record versions must
match the adapter contract. The binary adapter is intentionally opaque: it
preserves each byte's exact identity and offset and performs no protocol
inference.

### 3.2 Image, audio, and video representation envelopes

Gate 7.6 fixes the resource envelope before any encoder implementation:

- Image uses quantized patch/feature events. Width and height are each capped
  at `64`, channel count at `4`, and each quantized feature is an integer in
  `0..255`. Events are ordered by row, column, channel, then feature index;
  their source offset is the deterministic flattened patch position. The
  representation does not promise pixel-perfect reconstruction or preserve
  unsupported color profiles, alpha semantics, or arbitrary image metadata.
- Audio uses caller-provided integer feature events in bounded time windows.
  One window contains at most `4096` samples and `2` channels; normalized
  feature values are capped at the common `4095` integer limit. Events are
  ordered by window offset, channel, feature kind, and local time. The adapter
  will reject floating-point-only input, unsupported sample layouts, empty
  windows, and windows exceeding the limit. No claim of waveform or acoustic
  losslessness is made.
- Video uses ordered frame/patch events. A sequence contains at most `16`
  frames, each frame is capped at `64 x 64` and `4` channels. Events are
  ordered by frame identity, row, column, channel, then feature index; the
  source offset includes frame order before the local patch position. Missing,
  duplicated, or out-of-order frame identities, malformed frame dimensions,
  unsupported pixel formats, empty sequences, and oversized sequences are
  rejected before envelope publication. Temporal or pixel-perfect lossless
  reconstruction is not promised.

All three representations use integer-only feature values and must remain
within the common `256` event envelope. A source that would exceed that event
capacity is rejected even when its per-modality dimensions are individually
valid. Decoding, resampling, color conversion, compression handling, and
external I/O remain outside this contract until a later implementation ADR or
an explicit update to this decision.

The initial implementations follow this boundary. `adapter::image` consumes
already-quantized bytes, `adapter::audio` consumes bounded integer feature
events, and `adapter::video` consumes sparse integer frame features. None of
them decodes containers, performs floating-point conversion, performs external
I/O, or mutates AIE state; each returns only a validated common envelope.

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

### 4.1 In-memory invocation boundary

The caller owns the source input and invokes a modality adapter with an
immutable, already-available value. The adapter returns a self-contained
`Result<AdapterEnvelope, AdapterError>`; it does not retain the source view or
choose the next engine operation. The caller then validates the envelope and
explicitly maps its events into an existing public AIE input contract such as
`ObservationEvent`, `encode_observation`, or a later public training entry
point. This mapping belongs to the caller-facing integration layer, not to a
modality decoder and not to private arena code.

A future chat or teacher integration therefore submits its bounded text,
image, audio, video, structured, or binary input through the same in-memory
call boundary after its transport layer has completed. Credentials, network
retries, UI state, provider protocol, and message/session state remain outside
`src/adapters/` and outside the AIE core. The integration may choose which
public AIE operation to call, but it may not bypass the canonical adapter
contract or mutate private arena state.

### 5. Persistence and reproducibility

Adapters do not choose an implicit `.brain` location and do not auto-save
engine state. Persistence remains an explicit caller-owned operation using a
configured `Path`, with the existing validation and publication rules. Adapter
outputs must carry enough version and modality metadata for deterministic
replay and compatibility checks.

An adapter invocation alone therefore cannot publish, replace, or mutate a
`.brain` generation. A caller that wants persistence must invoke the existing
explicit save boundary separately, after its own state-management decision.

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

This ADR records the accepted architecture and naming. The initial bounded
adapter modules and the in-memory integration fixture are implemented under
`src/adapters/` and `tests/`; no external service, network endpoint, or
`.brain` default path is introduced. The accepted facade source remains
`src/adapters/adapters.act`, and the accepted public namespace remains
`adapter::...`.

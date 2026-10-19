# Phase 7 — Modality Adapters and the Common Twin-e Input Boundary

## Status

**Proposed.** This phase plans the adapter boundary described by ADR-0010. No
adapter implementation, external service, network endpoint, or automatic
`.brain` persistence is part of this planning change.

## Objective

Define and implement a bounded, integer-only translation boundary for external
data. Text, images, audio, video, structured records, and opaque binary input
must each use source-specific conversion while producing a common,
versioned representation that the existing tokenizer, encoding, observation,
training, and persistence contracts can validate.

The phase preserves the current boundary:

- the AIE core remains modality-neutral and owns associative state;
- adapters do not write directly to arena or persistence internals;
- inference, forwarding, coincidence evaluation, and neurogenesis remain free
  of synchronous filesystem and network I/O;
- all state and normalized features remain bounded and integer-only;
- hosted x86-64 evidence remains separate from future Cortex-M evidence.

## Mandatory gate evidence rule

Every gate in this phase must be confirmed by tests before it can be marked
complete. A design statement, successful compilation, or manual inspection
alone is not sufficient. Each gate must identify and run the applicable
contract, acceptance, rejection-path, integration, or benchmark tests, and
the reproducible command and result must be recorded in this roadmap or the
linked evidence document. A gate with missing, failing, or unexplained test
evidence remains open.

## Naming decision

The agreed filesystem root is:

```text
src/adapters/
```

The public call shape remains:

```text
adapter::contract
adapter::text
adapter::image
adapter::audio
adapter::video
adapter::structured
adapter::binary
```

ADR-0010 now records the same filesystem and facade names. The filesystem
name and public namespace must not diverge accidentally.

## Scope boundaries

Included:

- a shared adapter contract and validation rules;
- a canonical public facade and import-path tests;
- bounded text, structured, and binary adapters;
- documented representation envelopes for image, audio, and video;
- deterministic rejection, replay, and evidence fixtures;
- explicit integration boundaries for future chat or teacher providers.

Excluded:

- LLMs, OpenAI, chat UI, provider-specific network clients, or teacher
  services;
- automatic `.brain` save or load from an adapter;
- changes to the AIE arena layout, shard format, binding layout, or codebook
  width;
- floating-point engine state or unbounded dynamic collections;
- Cortex-M firmware and hardware claims, which remain in Phase 6;
- a universal encoder that hides modality-specific decoding policy.

## Gate 7.1 — Reconcile the accepted architecture

- [x] Update ADR-0010 so the filesystem root, facade filename, and public
      namespace agree with the accepted `src/adapters/` and `adapter::...`
      naming.
- [x] Record the implementation status as planned until code and evidence
      exist.
- [x] Define `adapter` as a public facade namespace backed by the plural
      `adapters` directory and `src/adapters/adapters.act`.
- [x] Confirm that no existing tokenizer, sensor, or action facade is
      silently renamed by this phase.
- [x] Add a decision note for the migration/rollback path before public
      modules are created.

### Gate evidence

- [x] ADR-0010 has no contradictory path or import examples.
- [x] The roadmap and ADR list the same modality set and implementation order.
- [x] The public import path and filesystem path are covered by a documented
      compiler-valid fixture plan.

### Gate 7.1 test evidence

The documentation consistency test checks that ADR-0010 and this roadmap use
the same filesystem root, facade source, and public namespace:

```sh
test "$(rg -c --no-filename 'src/adapters/' docs/adr/0010-modality-adapter-boundary.md)" -ge 1
test "$(rg -c --no-filename 'src/adapters/adapters\.act' docs/adr/0010-modality-adapter-boundary.md)" -ge 1
test "$(rg -c --no-filename 'adapter::(contract|text|image|audio|video|structured|binary)' docs/adr/0010-modality-adapter-boundary.md)" -ge 1
test "$(rg -c --no-filename 'src/adapters/' docs/roadmap/phase-7-modality-adapters.md)" -ge 1
```

Result: all four checks pass. No Actus source or adapter module exists yet;
compiler-valid import tests remain Gate 7.3 evidence.

## Gate 7.2 — Define the common adapter contract

- [x] Define the bounded common adapter envelope produced by every adapter;
      it sits above the existing `ObservationEvent` rather than replacing it.
- [x] Define modality identity, contract version, source ordering, source
      offset, payload length, and validation status fields.
- [x] Define bounded limits for event count, payload bytes, source offsets,
      and per-modality metadata.
- [x] Define explicit rejection reasons for malformed, unsupported, empty,
      and oversized input.
- [x] Define integer-only normalization ranges and forbid implicit floating
      point conversion.
- [x] Define deterministic replay requirements and tie-breaking rules.
- [x] Define ownership and lifetime at the adapter/facade call boundary.
- [x] Define which fields may feed tokenizer, encoding, observation, and
      training APIs without exposing private AIE state.

### Gate 7.2 design draft

The current contract draft defines a fixed-capacity envelope with a separate
adapter contract version, modality discriminator, event count, bounded source
length, and ordered integer events. The initial hosted admission envelope is
256 events with a `u32` source length. The event fields and rejection classes
are recorded in ADR-0010; implementation must not silently widen these limits.

- [x] Implement the contract types, validation, rejection paths, and
      no-state-mutation boundary.

### Gate 7.2 test evidence

The contract is covered by `tests/aie_adapter_contract.act` and the full strict
suite. The executable tests cover ordered acceptance, unsupported versions,
empty input, invalid source ordering, source-offset bounds, payload bounds,
and normalized-value bounds:

```sh
actus check --strict
actus test --strict
```

Evidence compiler: Actus `cf1cbda75bf4e14d1ad6c9f1bbf7a12c57f808eb`, the
compiler revision pinned by Twin-e CI. Result: `53 passed; 0 failed`. The
validator accepts only immutable input, performs no I/O, and returns before
any AIE state API is called; adapter facade integration remains a later Gate
7.3 concern.

### Gate evidence

- [ ] Contract types and limits are documented in an ADR or accepted update.
- [ ] Valid, empty, malformed, and oversized contract fixtures are specified.
- [ ] Rejection occurs before any engine-state mutation.

## Gate 7.3 — Create the canonical facade

- [x] Create the `src/adapters/` module root and canonical facade only after
      Gate 7.1 is accepted.
- [x] Expose `adapter::contract` through the facade.
- [x] Add public child-module paths for every planned modality without
      exposing private implementation helpers.
- [x] Add regression coverage for each public import path.
- [x] Keep the facade free of provider, transport, filesystem, and UI logic.
- [x] Keep the new modules below the repository source-size limits by
      responsibility-based decomposition.

### Gate evidence

- [x] Strict package checking accepts the facade and all public imports.
- [x] A facade-level test proves that private modality modules are not used
      as public entry points.
- [x] No existing public API or serialized layout changes incidentally.

### Gate 7.3 test evidence

`tests/aie_adapter_contract.act::test_adapter_facade_imports_all_public_namespaces`
checks the six public namespace markers through the canonical `adapters`
facade. The strict package and full test commands were run with the pinned
Actus compiler from the Gate 7.2 evidence.

Result: `54 passed; 0 failed`. The child modules contain namespace markers
only; modality conversion remains open under Gates 7.4–7.7.

## Gate 7.4 — Implement the text adapter

- [ ] Accept bounded text input using the existing byte tokenizer and BPE
      contracts.
- [ ] Preserve source byte offsets and malformed/non-UTF-8 behavior defined
      by the byte fallback contract.
- [ ] Produce the common adapter representation without duplicating token or
      context-generation logic.
- [ ] Define empty-input, maximum-length, repeated-byte, and mixed-BPE
      behavior.
- [ ] Prove deterministic output for repeated runs and equivalent input.
- [ ] Verify that the adapter performs no filesystem or network I/O.

### Gate evidence

- [ ] Valid text, empty text, oversized text, malformed bytes, repeated bytes,
      and mixed BPE fixtures pass.
- [ ] Text adapter output can be consumed through the canonical facade.
- [ ] Existing tokenizer and fallback tests remain green.

## Gate 7.5 — Implement structured and binary adapters

- [ ] Define the bounded schema for structured records, field ordering, and
      supported integer values.
- [ ] Reject unknown, duplicate, missing, malformed, and oversized fields
      before engine-state mutation.
- [ ] Define binary input as bounded opaque bytes with explicit source
      offsets; do not infer semantics from arbitrary byte groups.
- [ ] Preserve exact byte identity where the contract requires it.
- [ ] Define version and compatibility behavior for structured and binary
      payloads.
- [ ] Keep both adapters behind the same canonical facade and contract.

### Gate evidence

- [ ] Structured and binary acceptance/rejection fixtures are reproducible.
- [ ] Round-trip or deterministic replay evidence is recorded where lossless
      representation is promised.
- [ ] Oversized input is rejected before live AIE state changes.

## Gate 7.6 — Define image, audio, and video envelopes

- [ ] Select a bounded integer-only image representation: feature or patch
      events, dimensions, channels, and quantization limits.
- [ ] Select a bounded integer-only audio representation: time window,
      channel metadata, event resolution, and feature limits.
- [ ] Select a bounded integer-only video representation: frame identity,
      temporal order, frame envelope, and maximum sequence length.
- [ ] Document precision loss, unsupported formats, malformed frames, and
      resource limits for each modality.
- [ ] Define deterministic ordering and source offsets for every event.
- [ ] Do not implement an encoder until its resource envelope and rejection
      policy are accepted.

### Gate evidence

- [ ] Each modality has an accepted representation ADR or ADR-0010 update.
- [ ] Each envelope has bounded fixtures for valid, malformed, empty, and
      oversized input.
- [ ] No claim of semantic or lossless conversion is made without evidence.

## Gate 7.7 — Implement image, audio, and video adapters

- [ ] Implement the accepted image representation behind `adapter::image`.
- [ ] Implement the accepted audio representation behind `adapter::audio`.
- [ ] Implement the accepted video representation behind `adapter::video`.
- [ ] Keep decoding, normalization, and validation source-specific.
- [ ] Feed only the common bounded contract into the AIE-facing boundary.
- [ ] Add deterministic replay and rejection tests for each modality.
- [ ] Audit all three call paths for allocation, blocking I/O, and unbounded
      work.

### Gate evidence

- [ ] All three adapters pass strict checks and public-facade tests.
- [ ] Input limits are enforced before any live-state mutation.
- [ ] Benchmark output separates conversion cost from inference,
      forwarding, neurogenesis, and persistence cost.

## Gate 7.8 — Integration and external-boundary contract

- [ ] Define an in-memory adapter invocation boundary for callers that already
      possess input data.
- [ ] Define how a future chat or teacher integration submits adapter input
      without becoming part of the AIE core or adapter contract.
- [ ] Keep provider credentials, network retries, UI state, and transport
      outside `src/adapters/` unless a later ADR explicitly changes the
      boundary.
- [ ] Confirm that adapters do not choose an implicit `.brain` path or save
      engine state.
- [ ] Confirm explicit caller-owned persistence remains unchanged.

### Gate evidence

- [ ] An integration fixture proves adapter output reaches the existing public
      input boundary without private arena access.
- [ ] A hot-path audit finds no synchronous filesystem or network I/O.
- [ ] Persistence tests prove adapter invocation does not publish or mutate
      `.brain` state implicitly.

## Gate 7.9 — Full acceptance and documentation

- [ ] Run formatter checks for every touched `.act` source.
- [ ] Run `actus lock --check`, `actus check --strict`, and `actus test --strict`.
- [ ] Build the strict native executable and retain zero-float verification.
- [ ] Record compiler commit, target, profile, input limits, commands, and
      captured outputs for adapter benchmarks.
- [ ] Record known representation limits and unsupported formats.
- [ ] Update the adapter ADR, architecture documentation, and this roadmap
      with the accepted evidence.
- [ ] Keep hosted evidence separate from Phase 6 hardware evidence.

## Acceptance boundary

Phase 7 is complete only when every planned modality has a documented bounded
representation, the common contract and canonical facade are tested, the
implemented adapters pass strict and rejection-path evidence, and no adapter
performs hidden persistence or hot-path external I/O. Image, audio, and video
may remain explicitly deferred within this phase until their envelopes are
accepted; their absence must not be presented as implementation completeness.

## Non-goals

- Do not claim that adapter output is human-like understanding.
- Do not claim lossless conversion for arbitrary media.
- Do not make an LLM, chat interface, or provider API a prerequisite.
- Do not couple the adapter phase to STM32 hardware availability.
- Do not change the `.brain` format, arena layout, codebook profile, or
  persistence publication order as incidental adapter work.

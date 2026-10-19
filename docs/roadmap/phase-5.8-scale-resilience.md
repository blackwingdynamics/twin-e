# Phase 5.8 — Scale and Failure Resilience

## Status

Proposed. This phase is planning only until its gates are implemented and
supported by executable evidence.

## Purpose

Phase 5.8 hardens the hosted runtime against three risks identified during the
Phase 5 review:

1. sparse code collisions and noisy input at larger codebook populations;
2. memory and storage growth caused by byte fallback and unknown input;
3. resident-cache exhaustion, flush scheduling, and persistence recovery.

The phase preserves the current integer-only execution model, the 128-bit
codebook profile, the 64-byte minicolumn layout, shard-local bindings, and the
hot-path rule that inference and neurogenesis do not perform synchronous
filesystem I/O. Any change to those contracts requires a separate ADR.

## Scope boundaries

This phase does not immediately change the matching threshold, expand the
code width, aggregate arbitrary bytes, or introduce a background scheduler.
Those are decisions that require measurements and an accepted design first.

The phase does not claim general language understanding, production hardware
performance, or lossless recovery from every storage device failure. Evidence
must state the target, compiler version, profile, input population, and failure
model.

## Gate 5.8.1 — Codebook population and collision evidence

### Contract

- [x] Define the population under test: token IDs and bounded context keys.
- [x] Define whether a collision means an exact 128-bit duplicate, an
      above-threshold overlap, an ambiguous candidate set, or all three.
- [x] Record the active-bit count, codebook version, seed/profile, and input
      generation method in every result definition.
- [x] Define the acceptance policy for a duplicate or ambiguous code before
      changing runtime behavior.

The collision taxonomy, two-stage lookup contract, initial profile policy, and
noise evidence boundary are defined in `docs/adr/0009-codebook-collision-and-noise-contract.md`.
The executable stress measurements and regression evidence remain open below.

### Stress measurements

- [x] Add deterministic stress populations at 5,000, 50,000, 500,000,
      1,000,000, and 5,000,000 entries, subject to bounded host resources.
- [x] Measure exact duplicate count and first duplicate position.
- [x] Measure the full overlap distribution, including maximum overlap and the
      count of pairs at overlap 6, 7, and 8.
- [x] Measure retrieval candidates per query instead of relying only on a
      pairwise maximum across the complete population.
- [x] Measure false activation and missed activation rates with one or more
      missing or flipped active bits.
- [x] Record memory, runtime, and artifact size for every completed population.

The 500,000-entry streaming fixture remains cardinality-only, but the separate
Region-backed exact-duplicate fixture now records `exact_duplicate_count=0`,
`first_duplicate_token=500000`, `table_exhausted=false`, and a strict release
runtime of `133 ms` on hosted Linux x86-64. This closes only the 500,000-entry
exact-duplicate measurement slice. The complete population matrix, overlap and
candidate evidence, noisy-input rates, and memory/artifact envelope remain
open. The fixture's Region operations cover bounded bulk staging and
publication; they do not yet prove window-remapped lookup for every identity
probe. A scaled one-million-entry run also completed with
`exact_duplicate_count=0`, `first_duplicate_token=1000000`,
`table_exhausted=false`, and a strict release runtime of `304 ms`; the same
evidence boundary applies.
The five-million-entry run completed without table exhaustion but found
`exact_duplicate_count=14`, with the first duplicate at token `1409529`; its
lookup interval was `1417 ms` and the complete hosted process runtime was
`4.528 s`. The fixture returned exit code `1` because this is an intentional
duplicate-detection failure. This result exposes a collision in the current
codebook profile and does not close the population gate.
After the pre-release profile changed from eight to twelve active bits without
incrementing codebook version `1`, the one-million and five-million fixtures
were rerun. Both reported zero exact duplicates and no table exhaustion; the
lookup intervals were `313 ms` and `1547 ms`, with complete hosted runtimes of
`0.695 s` and `4.596 s`, respectively. This removes the observed exact
collision for the tested five-million population. The 5,000-token 12-bit
pairwise fixture also records the complete overlap histogram and a maximum
different-code overlap of `8` (overlap 6: `1748` pairs, overlap 7: `97`,
overlap 8: `2`). It now evaluates all 5,000 queries: exact `theta=12` returns
5,000 total candidates, maximum `1` per query, and `0` ambiguous queries;
relaxed `theta=11` has the same result for this population. The all-query
missing-bit test records `5000` missed intended queries at exact `theta=12`
with `0` false queries, and `0` missed or false queries at relaxed `theta=11`.
Runtime, peak resident memory, and executable artifact size for the completed
hosted runs are recorded in `docs/benchmarks/codebook-collision.md`. The
remaining memory-envelope work belongs to the byte-fallback and resident-cache
gates below.

### Correctness design

- [x] Specify a two-stage lookup contract: sparse bit matching produces
      candidates, then an exact identity check validates the selected context.
- [x] Decide how the exact identity is supplied to lookup, such as a context
      key, binding identity, or a versioned secondary signature.
- [x] Define deterministic tie-breaking only after exact identity validation;
      myelination alone must not hide an identity collision.
- [x] Add negative tests proving that an above-threshold false candidate cannot
      fire without passing the second-stage identity check.
- [x] Evaluate dynamic thresholding as candidate retrieval only; do not adopt
      a lower final firing threshold without false-positive evidence.
- [x] Record or update an ADR if the code width, active-bit profile, or
      serialized representation changes.

### Gate evidence

- [x] Add an executable benchmark and captured output to
      `docs/benchmarks/`.
- [x] Add deterministic regression tests for exact duplicates, near matches,
      noisy inputs, and ambiguous candidate sets.
- [x] Document the selected profile and its tested operating envelope.

## Gate 5.8.2 — Byte fallback memory envelope

### Input classes

- [x] Measure a representative BPE-friendly text corpus.
- [x] Measure UTF-8 text whose symbols are absent from the bounded vocabulary.
- [x] Measure malformed or adversarial byte sequences within the tokenizer
      input bound.
- [x] Measure repeated unknown input and unique unknown input separately.
- [x] Measure mixed known-token and byte-fallback input.

The tokenizer-side mixed case is recorded in
`docs/benchmarks/mixed-bpe-fallback.md`: a four-byte input emits one merged
known token and two preserved fallback bytes. Training-side accounting remains
open.

The tokenizer-side raw-byte envelope is recorded in
`docs/benchmarks/byte-fallback-envelope.md`: repeated and unique 64-byte
inputs preserve all events, raw UTF-8 and malformed two-byte samples are
preserved, and a declared length above the 256-byte bound is rejected. BPE
vocabulary-miss behavior remains open; training-side unknown-input accounting
is recorded in `docs/benchmarks/training-accounting.md`.

Training-side accounting is covered by `docs/benchmarks/training-accounting.md`.
It compares equal-length BPE, repeated byte fallback, unique byte fallback,
and mixed input in fresh bounded fabrics. The result separates emitted events,
reused context bindings, allocated columns, resident inline bytes, and fixed
`.brain` bytes; shard and manifest accounting remains a separate persistence
task.

### Accounting

- [x] Report input bytes, emitted token events, unique context bindings,
      allocated minicolumns, active shard count, resident bytes, and `.brain`
      bytes.
- [x] Separate payload bytes from binding metadata, column storage, shard
      headers, manifests, and alignment overhead.
- [x] Define the maximum admissible fallback run and the behavior when the
      bounded tokenizer or arena cannot admit another event.
- [x] Prove that repeated fallback input does not create unbounded duplicate
      bindings for an equivalent context.
- [x] Add a worst-case memory table comparing BPE, byte fallback, and mixed
      input under the same input length.

### Encoding decisions

- [x] Decide whether fallback identity is byte-level, validated Unicode
      scalar-level, or a bounded run-level representation.
- [x] Preserve deterministic source offsets and malformed-input behavior for
      the selected representation.
- [x] Do not aggregate bytes into a wider integer until token boundaries,
      compatibility metadata, and round-trip behavior are specified.
- [x] Define admission, reuse, and reclamation rules for fallback-derived
      bindings before changing tokenizer behavior. See ADR-0011; paired
      cleanup and capacity/persistence evidence remain implementation gates.
- [x] Verify that fallback processing remains allocation-free and performs no
      filesystem I/O on the hot path.

### Persistence and recovery evidence

- [x] Verify that fallback-heavy state remains valid under shard size and
      binding count limits. See
      `docs/benchmarks/phase-5-8-fallback-persistence.md`.
- [x] Measure `.brain` growth across repeated training and restart. The
      bounded fixture remains 5,702 bytes across both saves and reload.
- [x] Verify rejection of oversized fallback artifacts before live-state
      mutation. See the recorded `oversized_rejected=1 unchanged=1` result.
- [x] Verify that a failed save leaves the live fallback state unchanged. See
      the recorded `failed_save_unchanged=1` result.

## Gate 5.8.3 — Resident capacity and flush policy

### Capacity contract

- [x] Define resident capacity, dirty-shard high-watermark, pinned-shard
      policy, and flush queue capacity as explicit configuration values. See
      `src/config/values.act` and ADR-0012.
- [x] Define behavior when all resident slots are dirty or pinned. The cache
      returns `NoEvictable` and preserves the existing entries; see
      `docs/benchmarks/phase-5-cache-lifecycle.md`.
- [x] Guarantee that recall of already resident state can continue when a new
      mutation or shard admission is refused. See
      `tests/aie_api.act::test_resident_recall_survives_capacity_rejection`.
- [ ] Return a typed, observable capacity result without discarding the live
      fabric or dirty resident state.
- [ ] Define whether admission may retry, defer, or require an explicit flush
      boundary; no implicit synchronous disk write may be introduced.

### Flush scheduling

- [ ] Choose and document caller-driven flush, a runtime maintenance loop, or
      another scheduler boundary.
- [ ] Start flush work at the configured high-watermark before capacity is
      exhausted.
- [ ] Bound the amount of work and memory held by the flush queue.
- [ ] Keep flush latency separate from inference, forwarding, and neurogenesis
      latency in benchmark output.
- [ ] Define ordering for shard payload, binding payload, checksum, and
      manifest publication.
- [ ] Prove that a flush cannot publish a partially validated generation.

### Failure and recovery

- [ ] Add a checksum-failure test for a resident load and for a staged flush.
- [ ] Preserve the previous complete generation when the newest generation is
      corrupt, truncated, interrupted, or fails publication.
- [ ] Define whether recovery is read-only, retryable, or allows continued
      mutation in the existing resident generation.
- [ ] Verify that failed flush leaves the dirty resident shard usable.
- [ ] Verify that capacity recovery after a successful flush permits the
      deferred admission or neurogenesis operation.
- [ ] Verify that recovery never silently accepts a stale generation or a
      mismatched manifest descriptor.

### Gate evidence

- [ ] Add a deterministic four-slot exhaustion benchmark.
- [ ] Add a high-watermark flush benchmark with clean and dirty residents.
- [ ] Add corruption, interrupted-publication, retry, and previous-generation
      recovery fixtures.
- [ ] Record `disk_writes_hot_path=0`, capacity results, flush latency,
      committed generation, and recovery status.
- [ ] Run the full strict suite and retain complete diagnostics for any failure.

## Gate 5.8.4 — Integrated acceptance

- [ ] Run the codebook, fallback, and cache stress suites together under one
      documented compiler and host profile.
- [ ] Confirm that codebook ambiguity does not create an unsafe action or
      successor selection.
- [ ] Confirm that fallback pressure produces bounded errors or reclamation,
      never hidden growth.
- [ ] Confirm that cache exhaustion does not add synchronous filesystem I/O to
      inference or neurogenesis.
- [ ] Confirm that failed persistence preserves live state and the last valid
      generation.
- [ ] Update the relevant ADRs with the accepted designs and rejected options.
- [ ] Record the final limits, known failure modes, and follow-up work.
- [ ] Run `actus fmt --check` on every touched Actus source file.
- [ ] Run `actus lock --check`, `actus check --strict`, and `actus test --strict`.
- [ ] Run a strict native build and retain zero-floating-point verification.

## Definition of done

Phase 5.8 is complete only when every gate has implementation, tests, and
reproducible evidence. A passing compiler check alone does not close a gate.
Threshold changes, code-width changes, tokenizer representation changes, and
background scheduling changes require explicit design records before they are
implemented.

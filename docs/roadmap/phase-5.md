# AIE Phase 5 Roadmap

Phase 5 turns the working context-aware persistence engine into a durable,
trainable, and hardware-testable runtime. The phase covers the remaining
items that are outside the completed shard and manifest storage gates.

The order is intentional: durable `.brain` files and tokenizer artifacts come
first, then training, sensor input, action routing, and finally hardware
validation.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## P5.0 — Phase contracts and evidence

- [x] Create an ADR for the Phase 5 snapshot, tokenizer, training, and
  multimodal event contracts.
- [x] Define the supported `.brain` file version and compatibility policy.
- [x] Define failure behavior for interrupted writes, invalid artifacts, and
  incompatible runtime versions.
- [x] Define evidence output for every Phase 5 executable benchmark.
- [x] Keep all benchmarks deterministic and free of floating-point
  instructions unless a later ADR explicitly changes that rule.

### P5.0 evidence

ADR-0004 defines the compatibility profile, validation-before-publication
protocol, interrupted-write recovery behavior, hot-path no-write boundary,
integer-only determinism rule, and benchmark evidence format. The evidence
record shape is documented in `docs/benchmarks/phase-5-contracts.md`.

This gate records contracts only. No runtime benchmark result is claimed until
the corresponding implementation and executable measurement exist.

## P5.1 — Complete `.brain` file persistence

### Current implementation status

`src/aie/persistence/text_file.act` now provides a combined host save/load
boundary for the fixed fabric, TokenBinding state, and bounded BPE vocabulary.
The vocabulary-aware format has a fixed header, compatibility metadata,
complete fabric, binding, and vocabulary sections, and an integer checksum.
Loading validates the complete byte buffer before mutating live state.

The first executable evidence fixture is `benchmarks/aie_text_brain_file.act`,
with instructions in `docs/benchmarks/phase-5-brain-file.md`. It proves an
in-process save/clear/load round trip; it does not claim process-restart
recovery.

Recorded evidence confirms a 5,702-byte combined file round trip, corruption
rejection with unchanged live state, and strict native IR verification with no
floating-point instructions. The vocabulary-aware evidence is recorded
separately below.

The separate `benchmarks/aie_text_brain_bounds.act` fixture now covers
truncated and oversized rejection with unchanged live state. Its command and
output are recorded in `docs/benchmarks/phase-5-brain-bounds.md`. Vocabulary
artifacts and final size reporting are now covered by the vocabulary fixture.

The paired `aie_text_brain_restart_write.act` and
`aie_text_brain_restart_read.act` fixtures now define the separate-process
restart check. The exact commands and recorded evidence are in
`docs/benchmarks/phase-5-brain-restart.md`; the writer and reader both passed.
The vocabulary-aware process and corruption evidence is recorded in
`docs/benchmarks/phase-5-brain-vocabulary.md`.
The separate-process vocabulary restart evidence is recorded in
`docs/benchmarks/phase-5-brain-vocabulary-restart.md`.

The vocabulary persistence contract is recorded in
`docs/adr/0005-versioned-vocabulary-snapshot.md`. The legacy
fabric-and-binding API remains available, and the validated vocabulary-aware
save/load path is now implemented.

- [x] Add a public host save API for fabric, bindings, tokenizer metadata, and
  context metadata.
- [x] Add a public host load API that validates the complete file before
  mutating live state.
- [x] Reject truncated, oversized, corrupted, and incompatible `.brain` files.
- [x] Verify that a failed load leaves the existing fabric and bindings
  unchanged.
- [x] Persist the tokenizer vocabulary and merge-rule compatibility metadata.
- [x] Persist the context-codebook version and active-bit profile.
- [x] Add a restart benchmark that saves, exits, reloads, and recalls the same
  learned path.
- [x] Record the final `.brain` header, payload, binding, and artifact sizes.

## P5.1A — Hot-path storage isolation

This gate prevents disk I/O from becoming part of inference, forwarding, or
neurogenesis latency. A newly required shard must become available in memory
first; persistence is a later operation with an explicit lifecycle.

- [x] Create an ADR that defines the hot path, persistence path, and allowed
  synchronization boundaries.
- [x] Define the in-memory shard lifecycle: `Absent`, `Loading`, `Resident`,
  `Dirty`, `Flushing`, `Persisted`, and `Failed`.
- [x] Define the behavior when neurogenesis needs a slot and the current
  resident working set is full.
- [x] Allocate or activate a new shard in memory before linking the new
  minicolumn into the active fabric.
- [x] Mark the new or modified shard `Dirty` without writing to disk from the
  inference, forwarding, or neurogenesis call path.
- [x] Make shard growth bounded by configured resident capacity and return an
  explicit resource error when no safe expansion or eviction is possible.
- [x] Reject eviction of dirty or pinned shards unless an explicit flush policy
  has made them safe to evict.
- [x] Add a background or caller-driven flush operation that writes dirty
  shards to a temporary generation file, validates them, and publishes them
  atomically.
- [x] Add an explicit `save` or commit-boundary API for mission completion,
  text completion, and caller-requested persistence.
- [x] Define flush ordering for shard data, binding data, and manifest metadata
  so a committed generation is internally consistent.
- [x] Preserve the previous valid generation if a flush, rename, or process
  interruption fails.
- [x] Verify that a failed flush leaves the resident dirty shard and live fabric
  usable for continued inference.
- [x] Verify that a restart loads the newest complete generation and does not
  expose a partially written shard.
- [x] Add a benchmark that compares inference and neurogenesis latency with
  clean resident shards versus dirty resident shards.
- [x] Add a negative benchmark proving that no filesystem write occurs during
  the hot-path operation.
- [x] Measure flush latency separately from inference latency and report both
  values in the evidence document.
- [x] Document the configured resident shard capacity, dirty-shard limit,
  flush queue limit, and behavior under storage exhaustion.

Acceptance evidence:

```text
AIE_HOT_PATH samples=64 filesystem_writes=0
 inference_clean_ns=17444 inference_dirty_ns=17349
 neurogenesis_clean_ns=36744 neurogenesis_dirty_ns=39681
```

The benchmark source is `benchmarks/aie_hot_path_clean_dirty.act`. The
negative source audit is:

```sh
! rg -n 'std::io|write_file|read_file|remove_file|rename' \
  benchmarks/aie_hot_path_clean_dirty.act
```

### P5.1A save-boundary acceptance gates

These gates decompose the caller-driven save contract into independently
observable steps. They must be completed in order; a passing strict compile is
not evidence that a staged file was written, validated, or published.

- [x] **Gate A — Typed save-stage diagnostics**
  - [x] Distinguish write, staged-read, validation, and rename failures in the
    benchmark output without weakening the public `IoError` contract.
  - [x] Record the failing stage and complete typed error in the evidence
    document.
- [x] **Gate B — Staged write and validation**
  - [x] Prove that a dirty resident shard is written to the staged path with
    the expected payload, binding section, checksum, and metadata.
  - [x] Prove that invalid staged bytes are rejected before publication.
- [x] **Gate C — Atomic publication**
  - [x] Prove that a validated staged generation becomes the active file only
    after the rename step succeeds.
  - [x] Prove that the previous active generation remains available when
    publication fails.
- [x] **Gate D — Resident lifecycle after save**
  - [x] Mark the cache entry `Persisted` only after successful publication.
  - [x] Keep the resident shard `Dirty` and usable after any failed save.
- [x] **Gate E — Executable evidence and regression**
  - [x] Add a deterministic success benchmark and failure cases for each save
    stage.
  - [x] Record strict build output, zero-float verification, exit status, file
    state, and recovery behavior.
  - [x] Run the full strict Twin-e suite and close the parent P5.1A save API
    checkbox only after all gates pass.

## P5.2 — Production BPE vocabulary

- [x] Replace the one-merge fixture with a bounded multi-merge vocabulary.
- [x] Verify repeated ranked merge passes on a multi-token text fixture.
- [x] Verify byte fallback, BOS, EOS, unknown tokens, and merged-token decode.
- [x] Reject vocabulary files with incompatible versions, invalid ranks, or
  over-sized token spans.
- [x] Persist the bounded vocabulary and merge rules in the text snapshot.
- [x] Restore the vocabulary and verify encode/decode identity after restart.
- [x] Measure token-count reduction on a larger representative text corpus.

## P5.3 — Training and learning workflow

- [x] Define a bounded training input API for tokenized sequences.
- [ ] Create context-bound bindings from consecutive token events.
- [ ] Reinforce the observed successor path through myelination updates.
- [ ] Handle competing successors deterministically using the generation
  selection policy.
- [ ] Add bounded training limits for sequence length, events, and arena size.
- [ ] Verify that training changes recall behavior after a save and reload.
- [ ] Add a small text-learning benchmark with repeatable expected output.
- [ ] Measure training time, allocated columns, active bindings, and snapshot
  size.

## P5.4 — Modality-neutral observation events

- [ ] Define a modality-neutral event structure for bounded observations.
- [ ] Support event categories such as obstacle, distance, person, motion,
  and direction.
- [ ] Encode an observation into a deterministic sparse code without using
  floating-point instructions.
- [ ] Bind an observation to its temporal context in the same way as text
  tokens.
- [ ] Reject malformed, unknown, or over-sized observation events.
- [ ] Add an observation round-trip benchmark and serialized fixture.

## P5.5 — Sensor and action routing

- [ ] Add a sensor adapter boundary that accepts observation events without
  coupling the AIE core to a device driver.
- [ ] Route an observation through context lookup and successor selection.
- [ ] Define bounded actions such as stop, move, turn, follow, and signal.
- [ ] Add an action adapter boundary that emits validated action events.
- [ ] Add safety rules for missing, conflicting, stale, or repeated actions.
- [ ] Verify a deterministic obstacle-to-stop scenario.
- [ ] Verify a deterministic person-to-follow scenario.
- [ ] Keep sensor and action adapters hardware-neutral until hardware evidence
  is available.

## P5.6 — Hardware and scale validation

- [ ] Select a target CPU or embedded board for the first hardware profile.
- [ ] Measure resident memory, storage throughput, cache working set, and
  restart time on the target hardware.
- [ ] Measure coincidence evaluation, forwarding, training, and generation
  latency on the target hardware.
- [ ] Verify that the generated native artifact contains no floating-point
  instructions for the integer profile.
- [ ] Test persistence interruption and recovery on the target filesystem.
- [ ] Record the maximum tested logical columns, resident columns, shard count,
  and cache capacity.
- [ ] Document the difference between tested limits and theoretical scale.

## P5.7 — Release acceptance

- [ ] All `.brain` save/load and corruption tests pass in strict mode.
- [ ] Multi-merge BPE encode/decode and artifact compatibility tests pass.
- [ ] Training changes recall behavior and survives restart.
- [ ] Observation encoding and action routing pass deterministic fixtures.
- [ ] Target hardware benchmarks are recorded with reproducible commands.
- [ ] The phase has no unverified claims about intelligence, scale, latency,
  or hardware support.
- [ ] Update the project status and publish the final Phase 5 evidence report.

## Phase 5 completion criteria

Phase 5 is complete when the runtime can save and restore a trained
context-aware model, process a bounded production vocabulary, accept
modality-neutral observations, emit validated actions, and provide measured
hardware evidence for the supported profile.

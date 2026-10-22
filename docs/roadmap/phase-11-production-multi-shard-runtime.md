# Phase 11 — Production Multi-Shard Resident Runtime

## Status

In progress. Gate 11.1 is complete; later gates remain open.

## Objective

Replace the single-`CorticalFabric[64]` teaching limit with one bounded,
manifest-backed logical brain composed of deterministic resident shards. The
phase must make a real multi-record TWF training run possible without splitting
knowledge into unrelated brain files, silently dropping records, or adding
filesystem I/O to the learning hot path.

## Non-negotiable invariants

- One logical brain has one complete manifest generation.
- Every shard contains `Header -> Columns -> Bindings -> Auxiliary`.
- No global or per-shard auxiliary side file is introduced.
- Global arena indexes remain `u32` and position-independent.
- Every logical and resident bound is explicit and finite.
- A capacity failure never discards or mutates previously valid state.
- Teaching, inference, forwarding, and neurogenesis do not perform synchronous
  filesystem I/O.
- A manifest is published only after every referenced shard is validated.
- All gates require executable tests; documentation alone cannot close a gate.

## Gate 11.1 — Freeze the production capacity profile

- [x] Add named constants for maximum logical shards, shard capacity,
      resident working-set capacity, binding capacity, auxiliary capacity,
      request size, and manifest descriptor count.
- [x] Require `SHARD_COLUMN_CAPACITY` to be a power of two and derive the
      routing shift and mask from the validated capacity.
- [x] Set the initial production host profile to 1024 columns per shard.
- [x] Measure complete shard artifacts, including columns, headers, bindings,
      auxiliary data, checksums, and manifest metadata; do not infer full file
      size from the column array alone.
- [x] Record the selected values in one canonical config module.
- [x] Reject zero, overflowed, and internally inconsistent profiles before
      creating resident state.
- [x] Define the typed errors for logical-capacity exhaustion, resident-cache
      exhaustion, invalid shard routing, and incompatible profiles.
- [x] Add boundary tests for every configured maximum and one-over-limit case.
- [x] Update ADR-0015 with the measured host profile only after tests pass.
- [x] Benchmark shift/mask routing against the reference arithmetic model and
      record measured target/compiler results without claiming a fixed cycle
      count.

### Required evidence

- [x] A profile test prints the complete bound set and passes deterministically.
- [x] Invalid profiles are rejected without allocating or mutating a brain.

## Gate 11.2 — Introduce the canonical logical-brain facade

- [x] Define the public `LogicalBrain`/equivalent facade without exposing
      shard internals to the runner or benchmarks.
- [x] Define the bounded shard directory and resident-entry lifecycle.
- [x] Export the new child modules through one canonical persistence/runtime
      facade.
- [x] Preserve the existing single-shard behavior as shard zero under the new
      facade.
- [x] Add public API tests for empty creation, lookup, admission, and close.
- [x] Keep all ownership roles explicit at declarations and call sites.

### Required evidence

- [x] Existing single-shard tests pass through the new facade unchanged.
- [x] A facade-import regression test proves callers cannot bypass the public
      logical-brain boundary.

## Gate 11.3 — Implement deterministic global-index routing

- [x] Implement checked global-to-shard and shard-to-global conversions.
- [x] Reject multiplication, addition, and shard-ID overflow before mutation.
- [x] Validate that a local index belongs to the descriptor's declared range.
- [x] Preserve global `u32` axon targets across shard boundaries.
- [x] Add tests for first, last, boundary, unknown, and overflowed indexes.
- [x] Add cross-shard route tests with deterministic target selection.

### Required evidence

- [x] Routing round-trips every boundary index exactly.
- [x] Invalid indexes leave fabric, bindings, auxiliary state, and metrics
      unchanged.

## Gate 11.4 — Implement bounded shard admission and rotation

- [x] Teach into the current shard until its validated local capacity is full.
- [x] Allocate the next deterministic shard without replacing older knowledge.
- [x] Preserve request ordering and report the shard transition in bounded
      metrics.
- [x] Reject admission when the logical shard limit is reached.
- [x] Keep resident-cache admission consistent with ADR-0012.
- [x] Make the Production Teaching Runner perform a bounded explicit flush
      when the dirty high-watermark raises `shard_cache_flush_requested`,
      before retrying admission or creating another shard.
- [x] Reject or pause teaching on flush failure without dirty eviction or an
      unbounded flush queue.
- [x] Ensure a failed new-shard admission leaves the previous shard usable.
- [x] Do not write a shard synchronously from the teaching mutation path.

### Required evidence

- [x] A fixture crosses at least two shards and recalls records from both.
- [x] A logical-capacity fixture rejects the next record without mutation.
- [x] A failed rotation fixture preserves the last valid resident state.
- [x] A high-watermark fixture proves flush-then-continue behavior, and a
      failed-flush fixture proves resident and published state are unchanged.

The bounded logical admission boundary is covered by
`tests/aie_shard_admission.act` and `tests/aie_logical_teaching.act`. The
runner boundary now selects a dirty shard, commits the caller-provided explicit
flush result, and retries admission only after successful publication. Failed
flushes preserve dirty resident state. The CLI's legacy single-fabric file and
stdin adapters remain part of Gate 11.7 and are not claimed as complete here.

## Gate 11.5 — Integrate shard-local bindings and auxiliary state

- [x] Route every binding to the shard owning its source column.
- [x] Preserve global targets for cross-shard bindings.
- [x] Keep auxiliary records inside the owning shard's auxiliary section.
- [x] Validate binding and auxiliary ranges before applying any candidate data.
- [x] Prove paired allocation/reclamation cannot leak across shard boundaries.
- [x] Add duplicate, collision, overflow, and cross-shard rejection tests.

### Required evidence

- [x] A cross-shard binding round-trip preserves source and target identities.
- [x] Auxiliary recovery restores the same resident behavior after reload.
- [x] Invalid sidecar data is rejected before live-state mutation.

Gate 11.5 is covered by `tests/aie_logical_teaching.act`,
`tests/aie_logical_auxiliary.act`, `tests/aie_shard_routing.act`,
`tests/aie_fanout_sidecar.act`, `tests/aie_fanout_persistence_diagnostic.act`,
and the manifest auxiliary/recovery fixtures. The logical teaching facade keeps
bindings in the source shard's bounded binding array; auxiliary links retain
global target indexes while records remain in the source shard's auxiliary
state. The auxiliary tests cover duplicate, capacity, invalid-index, and
unadmitted-target rejection, snapshot validation before mutation, and paired
release/reuse in both the owning shard and a cross-shard isolation case.

## Gate 11.6 — Connect generation save, load, and recovery

- [x] Write complete dirty shard candidates with header, columns, bindings,
      auxiliary, and checksum.
- [x] Validate every candidate before publication.
- [x] Publish shard files before the manifest and the manifest last.
- [x] Include shard count, ranges, bounds, profile versions, and checksums in
      the manifest.
- [x] Reject incomplete, duplicated, overlapping, incompatible, truncated,
      and checksum-invalid generations.
- [x] Preserve the previous complete generation after failed publication.
- [x] Restore a multi-shard generation into a fresh logical brain.

### Required evidence

- [x] Load → teach across shards → save → restart → recall passes.
- [x] Interrupted publication selects the previous complete generation.
- [x] Failed save leaves both live resident state and active generation usable.

Gate 11.6 now has executable coverage for complete two-shard publication,
descriptor-order loading, duplicate/overlapping/incompatible manifest
rejection, truncated and checksum-invalid artifacts, mutation-free rejection,
previous-generation recovery, failed-save usability, and the full teaching
state lifecycle. The lifecycle test restores columns, bindings, and auxiliary
sections into a fresh `LogicalTeachingBrain`, teaches across the restored
shards, saves a new generation, restarts, and recalls both generations. The
strict suite is 168 tests with zero failures.

## Gate 11.7 — Replace the runner's single-fabric teaching path

- [x] Make the production runner own the logical-brain facade, not one raw
      `CorticalFabric[64]`.
- [x] Route direct, file, and stdin teaching through the canonical facade.
- [x] Keep configuration explicit and independent of developer home paths.
- [x] Distinguish resident acceptance from published persistence in output.
- [x] Preserve stable exit codes for routing, capacity, teaching, and save
      failures.
- [x] Ensure default output never prints raw source records.

### Required evidence

- [x] The three accepted Georgian TWF files train one logical brain across
      multiple shards.
- [x] Output reports total records, accepted records, shard transitions,
      allocated columns, and persistence status.
- [x] Restarting the runner recalls knowledge from every published shard.

Evidence (2026-10-22): `actus build --strict --emit exe` produced a native
runner with no floating-point instructions. Sequential `--config` runs over
`starter-0001.twf`, `starter-0002.twf`, and `starter-0003.twf` accepted
`8/8`, `8/8`, and `7/7` records; the third run reported
`shard_transitions=1` and `persistence_status=resident_only` before its
successful publication. A subsequent load/restart run accepted `8/8` records
and reported `shard_transitions=2`, proving that published shard state was
recalled before continued teaching. The full strict suite passed with
`169` tests and `0` failures.

## Gate 11.8 — Add scale, failure, and performance evidence

- [ ] Benchmark one-shard, two-shard, and configured-maximum profiles.
- [ ] Separate adapter, admission, routing, teaching, flush, and publication
      latency in benchmark output.
- [ ] Record peak resident memory, logical columns, shard count, binding count,
      auxiliary bytes, and artifact sizes.
- [ ] Test repeated training and restart without generation corruption.
- [ ] Test shard exhaustion, resident-cache pressure, failed save, checksum
      failure, and recovery.
- [ ] Retain compiler revision, target, executable checksum, dataset revision,
      profile, and exact commands.

### Required evidence

- [ ] Repeated runs produce identical logical results and bounded metrics.
- [ ] Native strict build confirms no floating-point instructions.
- [ ] No hot-path filesystem operation is observed during teaching/inference.

## Gate 11.9 — Production acceptance and ADR closure

- [ ] Run formatter checks for every touched Actus file.
- [ ] Run `actus lock --check`, `actus check --strict`, and `actus test --strict`.
- [ ] Run the strict native build and retain zero-float evidence.
- [ ] Run the complete multi-shard Georgian training acceptance.
- [ ] Record all known bounds and unsupported scale profiles.
- [ ] Update ADR-0015 from Proposed to Accepted only after every prior gate is
      green.
- [ ] Update Phase 10 lifecycle evidence to reference the multi-shard runner.

### Required evidence

- [ ] Clean Arch Linux workspace reproduces the complete acceptance run.
- [ ] One published generation can be loaded and recalled after restart.
- [ ] No temporary multiple-brain workaround is used anywhere in the evidence.

## Definition of done

Phase 11 is complete only when one production runner can teach the accepted
dataset into one bounded, multi-shard logical brain, publish a complete
manifest generation, restart, and recall the learned state from every shard.
All capacity, routing, persistence, recovery, and performance claims must be
backed by executable tests and reproducible evidence.

# Phase 4 Persistence Roadmap

This phase extends the fixed `.brain` snapshot into a bounded, recoverable
storage system for larger networks. One logical brain is represented by a
manifest and a bounded set of position-independent shard files.

This roadmap records the storage gates separately from the text-routing work
in `phase-4.md` so that persistence progress remains reviewable.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## P4S.0 — Storage contract

- [x] Accept ADR-0003 for manifest plus bounded shard storage.
- [x] Define position-independent global arena indexes for all axon targets.
- [x] Define fixed little-endian shard headers and compatibility versions.
- [x] Define manifest headers, ordered descriptors, generation, and checksums.
- [x] Define validation-before-mutation behavior for shard and manifest loads.
- [x] Define bounded selective loading by global column index.

## P4S.1 — Bounded shard format

- [x] Implement a fixed two-shard proof with 32 columns per shard.
- [x] Persist the 64-byte minicolumn records into real `.brain` shard files.
- [x] Restore both shards and preserve a cross-shard axon target.
- [x] Validate shard magic, version, ranges, strides, lengths, and compatibility.
- [x] Add payload checksums and reject corrupted shard data before mutation.
- [x] Verify strict native build and absence of floating-point instructions.

Evidence:

```text
AIE_BRAIN_SHARDS roundtrip=1 shard0=1 shard1=1 cross_shard_axon=32 corrupted_rejected=1
```

## P4S.2 — Manifest index

- [x] Implement the fixed manifest header and two shard descriptors.
- [x] Record generation, logical column count, active count, strides, and
  compatibility versions.
- [x] Record each shard range, payload geometry, state, and checksum.
- [x] Validate manifest length, header compatibility, descriptor ranges, and
  manifest checksum.
- [x] Reject a corrupted descriptor before it is used.
- [x] Resolve a global arena index into `shard_id` and `local_index`.

Evidence:

```text
AIE_BRAIN_MANIFEST roundtrip=1 generation=7 shards=2 checksums=2 lookup=1 corrupted_rejected=1
```

## P4S.3 — Selective loading

- [x] Read the manifest before selecting a shard.
- [x] Select the shard from a global column index.
- [x] Load only the selected shard file into the working fabric.
- [x] Verify that a lookup for global index `33` selects shard `1`, local index
  `1`.
- [x] Verify that unrelated shard state is not loaded by the selected-shard
  benchmark.

Evidence:

```text
selective_load=1
```

## P4S.4 — Generic shard profiles

- [x] Remove the separate shard `0` and shard `1` branches from global-index
  lookup; the current bounded profile now scans descriptors by count.
- [ ] Replace the fixed two-shard implementation with a manifest-driven shard
  descriptor collection.
- [ ] Move shard count, capacity, payload sizes, and file size into the global
  configuration profile.
- [ ] Support arbitrary valid global indexes without hardcoded shard branches.
- [ ] Validate non-overlapping, ordered, contiguous descriptor ranges.
- [ ] Reject duplicate shard IDs, gaps, overlaps, and arithmetic overflow.
- [ ] Add a three-or-more-shard round-trip with cross-shard links.

## P4S.5 — Descriptor and payload integrity

- [ ] Compare each manifest descriptor checksum with the checksum stored in its
  referenced shard header during load.
- [ ] Validate the shard file identity against the manifest descriptor before
  applying records.
- [ ] Add explicit tests for swapped shard files and wrong shard IDs.
- [ ] Add explicit tests for truncated manifests, oversized lengths, and
  malformed descriptor states.
- [ ] Preserve the live fabric unchanged for every failed manifest or shard
  validation path.

## P4S.6 — Binding and allocator persistence

- [ ] Store the `TokenBinding` sidecar in shard-owned payload records.
- [ ] Restore tokenizer, context, and codebook binding versions per shard.
- [ ] Persist global `free_list_head` and `active_count` through the manifest or
  a dedicated allocator section.
- [ ] Define deterministic global-index allocation across shard boundaries.
- [ ] Verify allocation, free, restore, and reallocation across multiple shards.

## P4S.7 — Generation and crash recovery

- [ ] Write changed shards to temporary generation files.
- [ ] Validate every temporary shard before publication.
- [ ] Write and validate a new manifest generation.
- [ ] Publish the new generation atomically through the supported filesystem
  API.
- [ ] Keep the previous complete generation recoverable during interruption.
- [ ] Select the newest complete valid generation at startup.
- [ ] Add interruption and stale-generation recovery fixtures.

## P4S.8 — Scale and operational evidence

- [ ] Benchmark candidate shard sizes and choose a supported production profile.
- [ ] Measure sequential traversal, random lookup, selective load, and flush
  latency.
- [ ] Measure manifest size, file count, cache working set, and restart time.
- [ ] Add a bounded shard cache with dirty-state tracking and eviction rules.
- [ ] Reject eviction of dirty or pinned shards without an explicit flush.
- [ ] Document the tested hardware limits and the difference between logical
  scale and resident memory.

## Phase completion criteria

This persistence phase is complete when an arbitrary manifest-driven shard set
can be written, validated, selectively loaded, and recovered across process
restart without mixing ranges, applying corrupted state, losing bindings, or
requiring the complete logical brain to fit in one in-memory buffer.

# ADR-0003: Sharded `.brain` Storage for Large Network State

- **Status:** Accepted
- **Date:** 2026-10-04
- **Scope:** `.brain` persistence, large fabric storage, snapshot recovery, and future disk-backed execution
- **Related work:** ADR-0001, ADR-0002, Phase 4 persistence follow-up

## Context

The current `.brain` design stores one fixed AIE fabric snapshot. The initial format is intentionally small:

```text
header                 12 bytes
64 minicolumns       4096 bytes
free-list metadata      8 bytes
                        --------
total                 4116 bytes
```

That format is useful for validating serialization, compatibility headers, and small demonstrations. It is not a suitable storage model for a large network. As the arena grows, a single in-memory Buffer becomes increasingly expensive and eventually impossible to allocate. A one-billion-column fabric already requires approximately 64 GB for minicolumn records alone, before token bindings, indexes, allocator metadata, checkpoints, and filesystem overhead.

The storage design must preserve learned state across process restarts without creating millions of filesystem entries or requiring the complete network to be loaded before one part can be inspected. It must also prevent records from different ranges or incompatible versions from being mixed silently.

## Decision

Twin-e will represent one logical brain as a **manifest plus bounded shard files**:

```text
brain/
├── manifest.brain
├── shard-000000.brain
├── shard-000001.brain
├── shard-000002.brain
└── ...
```

The brain remains one logical model. Shards are a storage and loading unit, not separate models and not separate knowledge domains by default.

The first large-storage profile will use a fixed shard capacity selected by a benchmark, with 64 MiB or 1 GiB as candidate profiles. The selected capacity is part of the storage manifest and cannot change silently during restore.

### 1. Manifest responsibilities

`manifest.brain` is a small position-independent index. It must contain at least:

- file magic and format version;
- header length and manifest length;
- brain identifier and storage profile identifier;
- minicolumn record size;
- shard capacity in records and bytes;
- total logical column count;
- active column count;
- tokenizer, context, and codebook compatibility versions;
- sidecar layout versions and record strides;
- shard count;
- ordered shard descriptors;
- checksum or integrity status for each descriptor;
- clean-shutdown or checkpoint state;
- an optional generation number for snapshot commits.

Each shard descriptor must identify:

```text
shard_id
first_column_index
column_count
payload_offset
payload_bytes
binding_offset
binding_bytes
checksum
state
```

All indexes are logical arena indexes. No raw process pointer, virtual address, or operating-system handle may be serialized.

### 2. Shard boundaries

A shard owns a contiguous range of logical arena indexes:

```text
global_index = shard.first_column_index + local_index
```

The shard stores the minicolumn records for that range and the matching position-independent sidecar records. A binding belongs to the same shard as its minicolumn slot. Cross-shard axons continue to use global `u32` arena indexes; they do not contain file offsets or pointers.

The free-list representation must remain globally valid. A future large-arena allocator may use per-shard free lists plus a manifest-level summary, but the mapping from an allocated global index to its shard must be deterministic.

### 3. File format inside a shard

Every shard is independently validated. Its header must identify:

- the brain format and shard format versions;
- the shard ID and first logical column index;
- the number of records in the shard;
- minicolumn stride and sidecar stride;
- payload sizes;
- tokenizer, context, and codebook versions;
- checksum coverage and value.

The payload uses explicit little-endian fields and fixed record strides. A reader must reject:

- an invalid magic value;
- an unsupported version;
- a mismatched shard ID or index range;
- an unexpected record stride;
- a truncated payload;
- an oversized or overflowing length;
- a checksum mismatch;
- incompatible tokenizer or context profiles.

Validation must finish before the shard mutates live fabric or binding state. The loader first reads and validates the header, then validates the payload length and integrity, and only then applies records to the arena.

### 4. Loading and memory behavior

The runtime will not require the complete brain to fit in one Buffer. The large-storage API will support:

1. opening a manifest;
2. validating the manifest and compatibility profile;
3. locating the shard for a global arena index;
4. loading one shard or a bounded group of shards;
5. reading or updating records in that working set;
6. flushing changed shards;
7. committing a new manifest generation.

The first implementation may use an explicit bounded shard cache. A later implementation may use memory mapping where the target and runtime support it. Memory mapping is an optimization; the position-independent file contract must not depend on a process address.

The cache must track at least:

- shard ID;
- loaded format versions;
- dirty state;
- generation or checkpoint number;
- last-use information;
- pin count or active users;
- checksum state.

An evicted dirty shard must be flushed or rejected. A clean shard may be discarded and loaded again from disk.

### 5. Save and recovery protocol

Saving uses a write-new-then-publish protocol:

1. write changed shard payloads to temporary files;
2. flush and validate each temporary shard;
3. write a new manifest generation referencing those shards;
4. flush the new manifest;
5. atomically publish the new manifest name or generation marker;
6. remove obsolete files only after the new generation is visible.

The previous complete generation remains recoverable if the process stops during a write. A manifest must never refer to a partially written shard.

Startup selects the newest complete generation whose descriptors and checksums validate. If no complete generation exists, loading fails with a typed error.

### 6. Knowledge isolation

Splitting storage into files does not by itself prevent knowledge collisions. Isolation is provided by stable IDs, explicit ranges, versioned sidecars, and validated indexes:

- every column has one global arena index;
- every sidecar entry is bound to that index;
- every axon target is interpreted as a global index;
- every shard declares its owned range;
- no loader may apply a record outside that range;
- incompatible profiles are rejected before merging state.

Separate directories or separate brain identifiers may be used for genuinely independent models, sessions, or knowledge packages. They are not needed for ordinary neuron sharding inside one brain.

### 7. Why not millions of `.brain` files?

One file per neuron or one file per tiny group creates operational costs that grow faster than the useful data:

- directory lookup and metadata overhead;
- excessive open and close operations;
- slower backup, copy, and integrity scans;
- difficult atomic commits across many files;
- higher risk of partial updates;
- filesystem limits on directory size or entry count;
- poor locality for sequential learning and recall.

Bounded shards keep the number of files manageable while preserving partial loading and partial updates. The shard size is a measured engineering choice, not an unlimited constant.

### 8. Large-file scale

The format must support large logical brains, but the supported limit is defined by the index width and implementation profile. With 64-byte minicolumns:

```text
1,000,000,000 columns ≈ 64 GB for minicolumn records alone
```

Terabyte-scale files are therefore possible as a storage architecture, but they require disk-backed access, bounded caches, indexes, checkpointing, and operational benchmarks. They must not be presented as fully resident memory until the target machine has demonstrated that capacity.

## Alternatives considered

### One monolithic `.brain` file

Rejected as the primary large-scale design. It is simple and remains useful for small snapshots, but it requires large contiguous buffers or a dedicated random-access container implementation and makes partial recovery harder.

### Millions of small `.brain` files

Rejected for neuron-level storage. It increases filesystem overhead and makes atomic updates and integrity checking unnecessarily difficult.

### One file per knowledge domain

Retained as an optional packaging feature for independent models, sessions, or importable knowledge packs. It does not replace shards inside one logical brain.

### Database-backed storage

Deferred. A database may be useful for metadata, experiments, or remote storage, but the first format must remain position-independent, deterministic, portable, and compatible with bounded native execution.

## Consequences

### Positive consequences

- learned state survives process restarts and partial working-set eviction;
- only changed shards need to be written during a checkpoint;
- large brains do not require one enormous Buffer;
- corruption can be detected at manifest and shard boundaries;
- global arena indexes preserve cross-shard axon links;
- backup and recovery operate on bounded, verifiable units.

### Costs

- the loader and writer become more complex;
- a global index must be translated to a shard and local offset;
- cross-shard traversal may require cache misses;
- manifest generations and temporary files require cleanup policy;
- shard size and cache size require hardware benchmarks;
- compatibility rules must cover both manifest and shard versions.

## Implementation gates

1. **Format gate:** define manifest and shard headers with exact byte offsets.
2. **Validation gate:** reject malformed, truncated, incompatible, or checksum-invalid shards before state mutation.
3. **Small-scale gate:** preserve the current 4116-byte snapshot behavior for tiny fabrics.
4. **Shard gate:** write and restore two shards with a cross-shard axon.
5. **Recovery gate:** interrupt a save and recover the previous complete generation.
6. **Cache gate:** load, evict, dirty, and flush bounded working sets.
7. **Scale gate:** benchmark shard sizes, file counts, sequential traversal, random lookup, checkpoint latency, and restart recovery.

No claim of terabyte-scale operation is accepted until the scale gate has measured the target storage and runtime behavior.

## Rejected assumptions

- More files automatically means safer knowledge storage.
- A shard boundary alone prevents semantic collisions.
- A complete brain must be loaded before one record can be read.
- A successful write call proves that a recoverable snapshot exists.
- A large logical file implies that the same amount of memory is resident.

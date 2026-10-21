# ADR-0015: Multi-Shard Resident Teaching Runtime

- **Status:** Accepted
- **Date:** 2026-10-21
- **Scope:** resident teaching capacity, shard routing, bounded shard
  allocation, runner integration, and large-dataset learning
- **Related work:** ADR-0003, ADR-0006, ADR-0011, ADR-0012, ADR-0013,
  ADR-0014, Phase 10, Phase 11

## Context

The current teaching runner owns one `CorticalFabric[64]`. This is a valid
bounded correctness profile, but it is not sufficient for a production
training run: a small accepted Georgian dataset can exhaust the 64 resident
minicolumn slots and return `TeachingRejected` even though every individual
TWF record is valid.

Splitting the input into unrelated brain files is not an acceptable production
solution. It loses the single-logical-brain contract and makes cross-record
recall, generation publication, and recovery ambiguous.

ADR-0003 already defines one logical brain as a manifest plus bounded shard
files. ADR-0012 defines the resident cache and caller-driven flush boundary.
This ADR defines the missing runtime layer that makes those decisions usable
by teaching: one logical resident brain composed of multiple bounded shards.

Acceptance of this ADR records the architecture and its constraints; it does
not claim that the Phase 11 implementation, benchmarks, or production training
evidence are complete.

## Decision

Twin-e will implement a bounded multi-shard resident runtime. A shard remains
the unit of fixed-capacity fabric storage; the brain is the ordered shard set.
Teaching, recall, persistence, and recovery operate on the logical brain
facade rather than on one hard-coded `CorticalFabric[64]`.

The first production profile will use explicit compile-time bounds for:

- maximum logical shard count;
- minicolumn capacity per shard;
- maximum resident shard working set;
- maximum shard-local binding and auxiliary capacity;
- maximum queued or in-flight teaching work;
- maximum generation descriptor count and manifest size.

No bound may be replaced with an unbounded collection or hidden allocation.
The selected values belong in `src/config/values.act`, are recorded in the
brain manifest, and are tested at their boundaries.

The initial production host profile uses `SHARD_COLUMN_CAPACITY = 1024`.
This value is a strict power-of-two invariant, with `SHARD_SHIFT = 10` and
`SHARD_MASK = 1023`. The 1024 columns occupy about 64 KiB before headers,
bindings, auxiliary records, checksums, and manifest metadata are included;
the complete artifact size must be measured rather than inferred from the
column array alone.

### Logical identity and routing

The global column identity is position-independent. Because the production
capacity is a power of two, production routing uses a shift and mask:

```text
shard_id       = global_column_index >> SHARD_SHIFT
local_index    = global_column_index & SHARD_MASK
global_index   = shard_id * SHARD_COLUMN_CAPACITY + local_index
```

Configuration validation must prove the power-of-two invariant and derive the
shift and mask from the selected capacity. The implementation must not claim a
fixed cycle count; routing cost is target- and compiler-dependent and is
measured by the Phase 11 benchmarks.

The runtime must reject overflow, an unknown shard, and an index outside the
declared logical brain capacity before resident mutation. Cross-shard axons
continue to store global `u32` indexes. They never store pointers, addresses,
file offsets, or process-local handles.

### Resident state

The resident brain owns a bounded shard directory and a bounded working set.
Each resident entry records at least:

- shard ID and logical range;
- lifecycle state;
- dirty and pinned state;
- generation/checkpoint identity;
- binding and auxiliary validation state;
- last-use or deterministic replacement metadata.

A full shard is not an error if another bounded logical shard can be admitted.
The runtime allocates the next deterministic shard, routes new capacity there,
and preserves the existing shard as part of the same logical brain. If the
configured logical shard limit or safe resident working set is exhausted, the
runtime returns a typed capacity error without discarding valid state.

The existing caller-driven flush boundary remains in force, and the Production
Teaching Runner is the explicit caller for its teaching path. When
`shard_cache_flush_requested` is raised at the dirty high-watermark, the
Runner must perform a bounded flush before retrying resident admission or
creating the next shard. If the flush fails, teaching pauses or rejects the
operation with a typed persistence error; dirty eviction and unbounded queue
growth are forbidden. This boundary does not add synchronous filesystem I/O
to inference, forwarding, neurogenesis, or coincidence hot paths.

### Shard-local data contract

Every shard owns all of its local state in one `.brain` shard file:

```text
Header -> Columns -> Bindings -> Auxiliary
```

There is no global auxiliary file and no per-shard auxiliary side file.
Bindings and auxiliary records use the shard's logical range and are validated
with the same generation and checksum rules as columns. Cross-shard references
remain global indexes and are validated against the manifest's logical range.

### Teaching behavior

The canonical teaching facade receives one logical brain handle. It must:

1. validate the complete request before mutation;
2. route each admitted operation to the deterministic shard;
3. allocate a new shard only at a validated capacity boundary;
4. preserve ordering and deterministic metrics across shard transitions;
5. distinguish accepted resident learning from published persistence;
6. return typed capacity, routing, compatibility, and persistence failures.

A record that cannot fit in the configured logical brain is rejected without
silently creating another brain, dropping data, or replacing older knowledge.

### Publication and recovery

Save uses the generation protocol from ADR-0003 and ADR-0012:

1. validate every dirty shard candidate;
2. write and validate complete shard files;
3. publish validated shard files;
4. build and validate a manifest describing the complete shard set;
5. publish the manifest last;
6. retain the previous complete generation until the new generation is
   recoverable.

The manifest is the publication point for the complete logical brain. A
partial shard set is never presented as current. Restart selects the newest
complete compatible generation and leaves the live resident state unchanged
when recovery or save fails.

## Rejected alternatives

### Multiple independent brain files

Rejected. It is a temporary demonstration technique, not one logical brain;
it prevents a single manifest from describing the learned state and makes
cross-shard recall and rollback ambiguous.

### Increasing one `CorticalFabric` to an arbitrary large array

Rejected as the primary design. It moves the same capacity problem into one
contiguous allocation, weakens memory bounds, and does not provide partial
loading or shard-local recovery.

### Dynamic or unbounded shard collections

Rejected. Production behavior must have explicit logical shard, resident
working-set, queue, and manifest bounds.

### Automatic filesystem writes during teaching

Rejected. Persistence remains an explicit caller boundary and cannot enter the
hot path as an implicit capacity workaround.

## Consequences

Positive consequences:

- one brain can learn beyond one shard while retaining deterministic bounds;
- shard-local persistence matches the accepted `.brain` architecture;
- capacity transitions are observable and testable;
- restart and rollback operate on complete generations;
- training data is not split into unrelated models.

Costs and limits:

- the runner, teaching facade, persistence facade, and tests must be changed;
- cross-shard routing and binding validation add implementation complexity;
- the supported logical brain size remains profile-bounded;
- no large-scale or production performance claim is valid before the required
  benchmarks pass on the target profile.

## Acceptance requirements

Phase 11 remains the implementation and evidence plan for this accepted
architecture. Multi-shard teaching, save/load, recovery, capacity rejection,
and deterministic benchmark evidence must pass before the production runtime
is declared complete; no temporary multiple-brain workaround satisfies that
requirement.

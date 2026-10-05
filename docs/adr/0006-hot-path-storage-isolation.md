# ADR-0006: Hot-Path Storage Isolation and Resident Shard Lifecycle

- **Status:** Accepted
- **Date:** 2026-10-05
- **Scope:** inference, forwarding, neurogenesis, shard residency, dirty state,
  and explicit persistence boundaries
- **Related work:** ADR-0003, ADR-0004, Phase 5 P5.1A

## Context

Twin-e keeps active fabric state in bounded resident memory and persists
position-independent shard data to disk. Inference, forwarding, and
neurogenesis are latency-sensitive operations. If any of those operations
create a file, write a shard, rename a generation, or calculate a disk
checksum synchronously, storage latency becomes part of the neural execution
path.

The cache already tracks loaded, dirty, pinned, and recently used shard
metadata. The runtime needs a precise lifecycle and an explicit boundary that
separates resident state changes from persistence work.

## Decision

### 1. Two execution paths

The runtime has two separate paths:

1. **Hot path:** coincidence evaluation, impulse forwarding, training updates,
   and neurogenesis. This path operates only on resident memory and bounded
   metadata.
2. **Persistence path:** load, flush, save, generation publication, recovery,
   and cleanup. This path may perform filesystem I/O only when invoked through
   an explicit caller boundary or a separately scheduled background worker.

The hot path must not synchronously call file creation, file writes, reads,
rename or publish operations, manifest updates, or disk checksum routines.

### 2. Resident shard lifecycle

Every managed shard follows this bounded lifecycle:

```text
Absent -> Loading -> Resident -> Dirty -> Flushing -> Persisted
                         |          |          |
                         +----------+----------+-> Failed
```

- `Absent`: no resident payload is available.
- `Loading`: a persistence operation is constructing a candidate payload.
- `Resident`: validated payload is active in memory and has no unsaved change.
- `Dirty`: resident payload has changed and must be flushed before eviction.
- `Flushing`: a caller or background worker is writing a staged generation.
- `Persisted`: the staged data and manifest generation were published.
- `Failed`: the last load or flush failed; the previous valid resident state
  remains usable when one exists.

State transitions are bounded and explicit. A failed flush does not discard a
dirty resident shard. A failed load does not publish a partial candidate.

### 3. Neurogenesis and resident capacity

Neurogenesis allocates or activates a resident slot before it links the new
minicolumn into the active fabric. The new shard or modified shard is marked
`Dirty` in memory. The link operation does not wait for disk persistence.

When resident capacity is full, the runtime may evict only a clean,
unpinned `Resident` shard. Dirty or pinned shards are not evictable. If no
safe slot exists, neurogenesis returns an explicit bounded resource error and
leaves the existing fabric unchanged.

### 4. Persistence boundary

The following operations are explicit persistence boundaries:

- caller-requested `save` or `commit`;
- mission or text-completion commit;
- a separately scheduled background flush;
- startup recovery and reload.

Flush ordering follows ADR-0003: stage shard data, validate and checksum it,
publish the shard generation, stage and publish compatible manifest metadata,
then mark the resident state `Persisted`. The previous complete generation
remains active until the new generation is fully published.

### 5. Evidence requirements

Hot-path evidence and persistence evidence must be reported separately. A
valid P5.1A benchmark records:

```text
AIE_HOT_PATH inference_ns=<value> neurogenesis_ns=<value>
 disk_writes_hot_path=0 dirty_shards=<value> flush_ns=<value>
 committed_generation=<value> recovery=1
```

The zero-write field must come from a negative filesystem-write check, not
from an assumption based only on source inspection. Flush latency is measured
outside inference and neurogenesis latency.

## Consequences

### Positive consequences

- storage latency cannot silently enter the neural execution path;
- new knowledge becomes usable in resident memory immediately;
- dirty state cannot be lost through ordinary eviction;
- failed persistence preserves live state and the previous valid generation;
- benchmarks can distinguish inference latency from save and flush latency.

### Costs

- the runtime must track lifecycle metadata in addition to shard payloads;
- callers must explicitly choose when persistence work occurs;
- bounded resident capacity can reject neurogenesis under pressure;
- recovery and flush tests require filesystem fixtures and generation evidence.

## Rejected alternatives

- Writing a new shard synchronously inside neurogenesis.
- Evicting dirty state and attempting to reconstruct it later.
- Treating a staged temporary file as an active generation.
- Measuring a save operation as if it were inference latency.

## Acceptance criteria

P5.1A is complete only when the lifecycle is implemented, resident capacity
and dirty eviction behavior are tested, explicit flush and save boundaries
are exercised, interrupted publication preserves the previous generation, and
the benchmark records zero filesystem writes on the hot path.

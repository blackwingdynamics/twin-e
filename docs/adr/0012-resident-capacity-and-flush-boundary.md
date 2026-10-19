# ADR-0012: Resident Capacity and Flush Boundary

- **Status:** Accepted
- **Date:** 2026-10-19
- **Scope:** resident shard cache capacity, dirty high-watermark, pinning,
  flush admission, and capacity failures
- **Related work:** ADR-0003, ADR-0004, ADR-0006, Phase 5.8 Gate 5.8.3

## Context

Twin-e already has a fixed four-entry shard metadata cache. Clean resident
entries can be replaced deterministically, while dirty and pinned entries are
protected. The cache benchmark and resident-neurogenesis tests show the
failure behavior, but the policy values and the boundary between hot-path
admission and persistence need one canonical contract.

## Decision

The current host profile uses these package constants:

| Constant | Value | Meaning |
|---|---:|---|
| `BRAIN_CACHE_CAPACITY` | `4` | Maximum resident shard metadata entries |
| `BRAIN_CACHE_DIRTY_HIGH_WATERMARK` | `3` | Dirty entries at which caller-driven flush should be scheduled |
| `BRAIN_CACHE_PINNED_EVICTION_POLICY` | `0` | Pinned entries are never evictable |
| `BRAIN_CACHE_FLUSH_QUEUE_CAPACITY` | `0` | No background queue; flushing is caller-driven |

These values are part of the host runtime profile. They are not a promise of
unbounded deployment capacity and must be recorded with future measurements.

### Admission and full-capacity behavior

1. A cache admission first refreshes an existing shard, then uses an empty
   slot, then selects the oldest clean, unpinned resident entry.
2. Dirty entries and entries with a nonzero pin count are never evicted.
3. If every slot is dirty or pinned, admission returns the typed
   `ShardCacheError.NoEvictable`; resident neurogenesis exposes the equivalent
   `ResidentNeurogenesisError.NoResidentCapacity`.
4. A rejected admission does not mutate the cache, fabric, bindings, or dirty
   resident payloads. Recall and inference for already resident state remain
   available.

### Flush scheduling boundary

The current scheduler boundary is caller-driven: the runtime reports the dirty
high-watermark, and the owning caller decides when to schedule or perform an
explicit flush. There is no runtime maintenance loop in this profile. Reaching
the high-watermark is an observable request, not permission for cache
insertion, inference, forwarding, or neurogenesis to write to disk.
Because the queue capacity is zero, no implicit deferred work is stored in the
runtime. A caller may flush before retrying admission; without that explicit
boundary, the bounded capacity error remains the result.

The admission contract is therefore explicit: a rejected admission is not
retried or deferred inside the current call. The caller receives the typed
capacity error, decides whether a flush is safe, performs that flush at its
own boundary, and may then issue a new admission request. If the caller does
not establish that boundary, the live fabric and dirty resident state remain
unchanged and the capacity error is final for that request.

The cache exposes `shard_cache_dirty_count` and
`shard_cache_flush_requested`. The latter becomes true when the configured
dirty high-watermark is reached, before all resident capacity is consumed.
This is a bounded in-memory signal for the caller; it neither queues flush
work nor performs filesystem I/O.

### Flush queue bound

`BRAIN_CACHE_FLUSH_QUEUE_CAPACITY` is `0` in the current host profile. The
runtime therefore retains zero pending flush requests and zero queue-owned
flush memory. A caller may hold one explicitly selected, bounded save request
while performing its flush, but that work is outside the runtime queue and is
not accumulated by admission or inference.

Latency evidence follows the same boundary: resident inference and
neurogenesis are measured without persistence calls, while explicit flush time
is reported separately as `flush_ns`. The reproducible host-profile record is
`docs/benchmarks/phase-5-hot-path.md`.

### Publication ordering

The canonical ordering for a complete shard generation is:

1. Validate bounded shard, payload, and shard-local binding inputs.
2. Build the complete staged shard, including payload, bindings, header, and
   checksum.
3. Write the staged shard and read it back for identity, layout, length, and
   checksum validation.
4. Publish the validated shard by atomic rename.
5. Build and checksum a staged manifest descriptor that references the
   published shard generation.
6. Validate the complete staged manifest and all referenced shard checksums.
7. Publish the manifest last by atomic rename.

The manifest is therefore the publication point for the complete generation;
it must never reference a shard or binding payload that has not already passed
validation. The current shard and manifest APIs expose these boundaries
separately, so this ordering is the contract and not a claim that one
multi-artifact transaction is already implemented.

The dynamic flush benchmark provides the shard-level failure evidence: a
corrupted staged checksum is rejected and the pre-existing active shard remains
valid (`partial_rejected=1`, `active_unchanged=1`).

Checksum failures are also covered at both required boundaries: resident shard
load rejects corrupted bytes without mutating the fabric
(`AIE_BRAIN_SHARDS ... corrupted_rejected=1 fabric_unchanged=1`), while the
staged binding-aware flush rejects invalid data before publication
(`AIE_BINDING_STAGE validation_rejected error=IoError.InvalidData`).

### Pinning

Pinning protects a resident shard for the lifetime of its active user. A pin
does not make dirty state flush automatically, and unpinning does not itself
perform I/O. A shard becomes eligible for replacement only when it is clean,
resident/persisted, and has a zero pin count.

## Evidence and remaining work

`benchmarks/aie_cache.act` records four-entry working-set behavior, dirty and
pinned rejection, clean replacement, and all-dirty full-pressure rejection.
`tests/aie_api.act` records typed resident-capacity failure without discarding
the live fabric. The remaining Gate 5.8.3 work is to implement/measure the
high-watermark trigger, flush ordering, latency separation, and failure/retry
recovery fixtures. This ADR does not claim those later gates are complete.

## Consequences

- capacity behavior is explicit and observable rather than an accidental
  property of an array bound;
- no hidden queue or synchronous disk write can appear during hot-path
  admission;
- callers must explicitly flush before retrying when safe capacity is absent;
- a future background scheduler requires a new profile decision and a
  nonzero, explicitly bounded queue value.

# Phase 5 Cache Lifecycle Evidence

This record covers the bounded in-memory shard-cache lifecycle gate. It proves
state behavior and safety rules for the cache benchmark; it is not a hardware
latency claim.

## Command and environment

- Source: `benchmarks/aie_cache.act`
- Command: `actus build --strict --emit exe -o /tmp/twin-e-cache-pressure.aie benchmarks/aie_cache.act`
- Run: `/tmp/twin-e-cache-pressure.aie`
- Profile: strict native executable
- Compiler binary digest: `322711227604bc52452f2ad015748f17df7facee1a9233c114a2bc4bdc6817bb`
- Floating point: native IR verification reported no floating-point instructions
- Cache capacity: four metadata entries

## Captured result

```text
built `/tmp/twin-e-cache-pressure.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_CACHE capacity=4 working_set=4 dirty_rejected=1 pinned_rejected=1 clean_evicted=1 replacement=1 full_pressure_rejected=1 high_watermark=3 dirty_before_signal=2 dirty_at_signal=3 flush_requested=1
```

## Meaning

- Four resident entries can be managed without an unbounded collection.
- A dirty entry is rejected by eviction until a persistence policy clears its
  dirty state.
- A pinned entry is protected from eviction.
- After unpinning, the deterministic replacement path evicts the oldest safe
  clean entry and installs the new resident entry.
- When all four entries are dirty, insertion returns the bounded resource
  failure and the requested shard is not published into the cache.
- The caller-driven flush signal remains off at two dirty entries and turns on
  at the configured high-watermark of three dirty entries.
- The cache now stores an explicit `ShardLifecycle` value instead of separate
  `loaded` and `dirty` booleans. The lifecycle enum includes the states needed
  by the later load, flush, publish, and failure gates.

This evidence closes the lifecycle-definition, full-capacity behavior, and
resident neurogenesis ordering, and caller-driven flush publication gates. The
flush path stages a checksummed shard, validates it, and publishes it with an
atomic rename. It does not claim that background scheduling or manifest
publication is implemented; those remain later P5.1A gates.

## Caller-driven flush evidence

- Source: `benchmarks/aie_shards_dynamic.act`
- Command: `actus build --strict --emit exe -o /tmp/twin-e-dynamic-flush.aie benchmarks/aie_shards_dynamic.act`
- Run: `/tmp/twin-e-dynamic-flush.aie`
- Compiler binary digest: `322711227604bc52452f2ad015748f17df7facee1a9233c114a2bc4bdc6817bb`

```text
built `/tmp/twin-e-dynamic-flush.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_SHARDS_DYNAMIC files=3 generated=1 staged_shard=1 validated=3 partial_rejected=1 truncated_rejected=1 active_unchanged=1 manifest_bound=2 swapped_rejected=1 dynamic_loaded=1 dynamic_collection=3 manifest_selected=1 dynamic_failed_unchanged=1 free_chain=5-2-0-null reallocated=2 payload_bytes=128
```

The benchmark now exercises the public `flush_dynamic_shard` boundary. The
operation writes a staged payload, validates it, and publishes it atomically;
the hot-path runtime does not call this operation. It also corrupts a staged
checksum before publication and records `partial_rejected=1` with
`active_unchanged=1`, and also rejects a truncated staged file with
`truncated_rejected=1`. Both failures leave the active generation valid.

## Resident neurogenesis API evidence

The public resident-neurogenesis APIs are covered by
`tests/aie_api.act::test_resident_shard_precedes_neurogenesis_link`. The test
verifies that a column is linked, the shard is present in the cache, and its
lifecycle is `Dirty` after the result-returning operation. The compatibility
wrapper `neurogenesis_with_resident_cache` keeps the optional success shape.
Both paths run without any filesystem call in the test path. Capacity
exhaustion is reported by the result API as `NoResidentCapacity`, while the
underlying cache benchmark records the corresponding bounded `NoEvictable`
decision.

The strict test command produced:

```text
test result: ok
18 passed; 0 failed
```

## Configured bounded capacity

The current host profile uses the following explicit limits:

- resident shard cache capacity: `BRAIN_CACHE_CAPACITY=4` entries;
- dirty-shard limit: four entries, because every resident entry may become
  dirty but no dirty entry is evictable;
- flush queue limit: `0` background queue entries; persistence is currently
  caller-driven through the explicit save boundary;
- storage exhaustion behavior: when all four entries are dirty or pinned,
  insertion returns the bounded `NoEvictable` decision and resident
  neurogenesis reports `NoResidentCapacity` without changing the existing
  fabric.

These are host-profile limits, not claims about an unbounded deployment. A
future background flush profile must define its queue capacity explicitly
before changing the zero-queue contract.

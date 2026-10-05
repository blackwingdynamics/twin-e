# Phase 5 Cache Lifecycle Evidence

This record covers the bounded in-memory shard-cache lifecycle gate. It proves
state behavior and safety rules for the cache benchmark; it is not a hardware
latency claim.

## Command and environment

- Source: `benchmarks/aie_cache.act`
- Command: `actus build --strict --emit exe -o /tmp/twin-e-cache-pressure.aie benchmarks/aie_cache.act`
- Run: `/tmp/twin-e-cache-pressure.aie`
- Profile: strict native executable
- Compiler binary digest: `df742fd2611d83aa9705522b9f7c1ea4b14ed98c7c485d8d07b18409597c7634`
- Floating point: native IR verification reported no floating-point instructions
- Cache capacity: four metadata entries

## Captured result

```text
built `/tmp/twin-e-cache-lifecycle-final.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_CACHE capacity=4 working_set=4 dirty_rejected=1 pinned_rejected=1 clean_evicted=1 replacement=1 full_pressure_rejected=1
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
- The cache now stores an explicit `ShardLifecycle` value instead of separate
  `loaded` and `dirty` booleans. The lifecycle enum includes the states needed
  by the later load, flush, publish, and failure gates.

This evidence closes the lifecycle-definition, full-capacity behavior, and
resident neurogenesis ordering gates. It does not claim that background
flushing or atomic publication is implemented; those remain later P5.1A gates.

## Resident neurogenesis API evidence

The public `neurogenesis_with_resident_cache` API is covered by
`tests/aie_api.act::test_resident_shard_precedes_neurogenesis_link`. The test
verifies that a column is linked, the shard is present in the cache, and its
lifecycle is `Dirty` after the operation. It also runs without any filesystem
call in the test path.

The strict test command produced:

```text
test result: ok
17 passed; 0 failed
```

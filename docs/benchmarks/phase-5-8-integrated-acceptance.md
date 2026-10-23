# Phase 5.8 Integrated Acceptance Evidence

The codebook, fallback, and cache stress fixtures were built and run under the
same host profile and compiler:

- Compiler:
  `/home/magradze/Projects/actus_project/actus/target/debug/actus`
- Compiler digest:
  `322711227604bc52452f2ad015748f17df7facee1a9233c114a2bc4bdc6817bb`
- Profile: strict native executable
- Native IR: every build verified no floating-point instructions

## Codebook stress

```text
IE_CODEBOOK_REGION population=token_ids size=5000000 codebook_version=1 active_bits=12 seed=11400714819323198485 generation=sequential_u32
IE_CODEBOOK_REGION occupied_slots=5000000
IE_CODEBOOK_REGION exact_duplicate_count=0
IE_CODEBOOK_REGION first_duplicate_token=5000000
IE_CODEBOOK_REGION table_exhausted=false
IE_CODEBOOK_REGION elapsed_ms=1635
```

## Fallback persistence stress

```text
IE_FALLBACK_PERSISTENCE first_brain_bytes=5702
 repeated_brain_bytes=5702
IE_FALLBACK_PERSISTENCE training_passes=2 events=62 active_bindings=62 active_columns=64 shard_columns=64 binding_slots=64
 growth_bytes=0 oversized_rejected=1 unchanged=1 failed_save_unchanged=1
```

## Cache pressure stress

```text
IE_CACHE capacity=4 working_set=4 dirty_rejected=1 pinned_rejected=1 clean_evicted=1 replacement=1 full_pressure_rejected=1 high_watermark=3 dirty_before_signal=2 dirty_at_signal=3 flush_requested=1
```

Together these runs show bounded codebook occupancy, no repeated-training
growth in the fallback artifact, explicit oversized-save rejection, and
bounded cache pressure with caller-visible flush signaling.

## Ambiguity safety

The strict suite also covers the safety boundary after codebook lookup:

```text
test_codebook_ambiguous_sparse_candidates_require_identity ... ok
test_action_routing_rejects_conflicting_successors ... ok
test_action_routing_rejects_repeated_action ... ok
test_action_routing_rejects_stale_sequence ... ok
```

An ambiguous sparse candidate therefore does not become an action or
successor by proximity alone; identity and action-sequence safety checks remain
required.

## Fallback and cache safety boundaries

The fallback stress run reported `growth_bytes=0`,
`oversized_rejected=1`, `unchanged=1`, and
`failed_save_unchanged=1`. This is bounded pressure behavior: repeated
training does not create hidden artifact growth, and rejected persistence
does not mutate the live state.

The resident hot-path fixture separately reports
`filesystem_writes=0` for clean and dirty inference and neurogenesis. Cache
exhaustion therefore returns a bounded result at the caller-driven persistence
boundary rather than adding synchronous filesystem work to those operations.

## Failed persistence safety

The save-boundary and generation-recovery fixtures report
`previous_generation_preserved`,
`dirty_after_failed_save resident_usable_after_failed_save`, and
`stale_rejected=1`. A failed save therefore leaves resident state available
for retry and does not replace the last complete persisted generation.

## Accepted limits and follow-up

The accepted host profile is:

- 12 active codebook bits, measured to 5,000,000 entries;
- four resident cache entries;
- dirty flush high-watermark at three entries;
- zero background flush queue capacity;
- integer-only state and strict native zero-float verification.

Known failure modes remain explicit: exact codebook identity can reject a
one-bit-loss query at threshold 12, noise tolerance is not implemented,
capacity exhaustion returns a bounded error until the caller flushes, and
hardware performance is not established by these host runs. Follow-up work is
larger-scale storage measurement, target-specific performance evidence, and a
separate noise-policy design if tolerant matching is required.

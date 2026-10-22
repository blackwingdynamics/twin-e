# Phase 11 failure-matrix evidence

## Covered boundaries

The strict test suite covers the Gate 11.8 failure matrix through these
executable tests:

- logical shard exhaustion: `tests/aie_shard_admission.act::test_logical_capacity_rejects_without_mutation`;
- resident-cache pressure: `test_failed_rotation_preserves_previous_resident_state`,
  `test_failed_flush_keeps_resident_state_dirty_and_usable`, and
  `test_explicit_flush_then_rotation_continues` in
  `tests/aie_shard_admission.act`;
- failed save with live-state preservation:
  `tests/aie_logical_save_failure.act::test_failed_logical_save_preserves_live_state`;
- checksum-invalid generation rejection and fallback selection:
  `tests/aie_manifest_recovery.act::test_restart_recovery_selects_complete_auxiliary_generation`;
- complete multi-shard descriptor rejection and recovery boundaries:
  `tests/aie_multi_shard_generation_boundaries.act::test_multi_shard_manifest_rejects_duplicate_overlap_and_incompatible_descriptors`.

The failed-save fixture teaches one logical shard, attempts publication through
a path whose parent does not exist, requires the save to return an error, and
then verifies that shard count, total logical columns, and generation are
unchanged.

## Validation

```sh
actus fmt --check tests/aie_logical_save_failure.act
actus lock --check
actus check --strict
actus test --strict
git diff --check
```

Observed on the Arch Linux host on 2026-10-22:

```text
test result: ok. 170 passed; 0 failed
```

This closes the Gate 11.8 failure-matrix checkbox. Compiler revision/target
provenance, native zero-float evidence, and hot-path filesystem auditing remain
separate open evidence requirements.

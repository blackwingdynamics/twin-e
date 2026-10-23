# Phase 11 repeated-training and restart evidence

## Scenario

`tests/ie_logical_persistence.act` now exercises three complete generations
with a fresh `LogicalTeachingBrain` for every restart boundary:

1. train the initial sequences and publish generation `1`;
2. load generation `1`, teach a continuation, and publish generation `2`;
3. load generation `2` into another fresh brain, teach a continuation that
   creates a third shard, and publish generation `3`;
4. load generation `3` into a final fresh brain and verify generation `3`, all
   previously recalled bindings, and the three-shard logical shape.

The fixture keeps shard paths distinct from the manifest path, so the third
shard cannot overwrite the manifest during the repeated-generation sequence.
The load assertion accepts every positive restored shard count instead of
assuming that every generation contains exactly two shards.

## Validation

Command:

```sh
actus fmt --check tests/ie_logical_persistence.act
actus check --strict
actus test --strict
```

Observed on the Arch Linux host on 2026-10-22:

```text
tests/ie_logical_persistence.act::test_logical_teaching_save_load_restart_recall ... ok
test result: ok. 169 passed; 0 failed
```

This evidence establishes repeated logical training and restart recovery
without generation corruption. It does not claim the Gate 11.8 failure-matrix,
native zero-float, or hot-path audit checks; those remain separate checkboxes.

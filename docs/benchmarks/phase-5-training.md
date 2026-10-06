# Phase 5 Training Evidence

This benchmark measures bounded token-sequence training and reports the
resulting resident state and fixed snapshot size. It does not claim hardware
performance or process restart behavior; the restart boundary is covered by
the persistence evidence.

## Command

```sh
actus build --strict --emit exe benchmarks/aie_training.act \
  -o /tmp/twin-e-training-benchmark.aie
/tmp/twin-e-training-benchmark.aie
```

## Conditions

- Source commit before evidence recording: `2303ca9`.
- Actus compiler binary: `/home/magradze/.cargo/bin/actus`.
- Compiler SHA-256: `7b81b7ee9d995bbf88fe02fc7fd9fe1ecf590c3b2506711207009cbf4b1b8c4d`.
- Profile: strict native executable.
- Input: 32 byte token sequence with the repeating pattern `AB`.
- Arena bound: 64 minicolumns.
- Binding bound: 64 token bindings.
- Numeric profile: integer-only; native IR reported no floating-point
  instructions.

## Captured output

```text
AIE_TRAINING events=32 recall_profile=AB bounded=1
AIE_TRAINING training_ns=14087
AIE_TRAINING allocated_columns=3
AIE_TRAINING active_bindings=3
AIE_TRAINING snapshot_bytes=5702
```

The training time is a host debug-profile observation and may vary between
runs. The allocated-column, active-binding, and fixed snapshot-size fields are
the deterministic acceptance fields for this fixture.

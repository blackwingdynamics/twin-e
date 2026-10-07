# Phase 5.6 Hosted Baseline

This document records the first Phase 5.6 measurements on the hosted target.
The results are reproducible host evidence. They are not measurements from a
board, sensor, actuator, cache line, or production deployment.

## Environment

- Date: 2026-10-07
- Target: `host`
- Profile: `debug`
- OS: Linux 7.2.7-arch1-1, x86_64
- CPU: Intel Core i7-14700KF, 28 logical CPUs
- Compiler: `/home/magradze/.cargo/bin/actus`
- Compiler SHA-256:
  `f33ea7dba571b8704a377d832d4d690a4a621f6802a90b1760f9b2688a284ead`
- Floating point: rejected by strict native IR verification

CPU frequency scaling was active during the run. The numbers must therefore
be treated as a baseline for this machine and profile, not as fixed latency
guarantees.

## AIE core baseline

Command:

```sh
actus fmt --check benchmarks/aie_p3_3.act
actus build benchmarks/aie_p3_3.act --strict --emit exe \
  -o /tmp/twin-e-p5-6-aie-baseline.aie
/tmp/twin-e-p5-6-aie-baseline.aie
```

Output:

```text
verified generated native IR: no floating-point instructions
AIE_BENCH iterations=10000 arena_columns=64
AIE_BENCH coincidence_ns=684293
AIE_BENCH forwarding_8axon_ns=3852296
AIE_BENCH free_list_ns=148345
AIE_BENCH full_step_ns=4465076
```

These are aggregate timings for 10,000 iterations. Dividing by the iteration
count gives approximate hosted debug averages of 68.4 ns for coincidence,
385.2 ns for eight-axon forwarding, 14.8 ns for one free-list pair, and 446.5
ns for one full wavefront step. They are not hardware-independent latency
claims.

## Training baseline

Command:

```sh
actus fmt --check benchmarks/aie_training.act
actus build benchmarks/aie_training.act --strict --emit exe \
  -o /tmp/twin-e-p5-6-training.aie
/tmp/twin-e-p5-6-training.aie
```

Output:

```text
verified generated native IR: no floating-point instructions
AIE_TRAINING events=32 recall_profile=AB bounded=1
AIE_TRAINING training_ns=11695
AIE_TRAINING allocated_columns=3
AIE_TRAINING active_bindings=3
AIE_TRAINING snapshot_bytes=5702
```

## Generation baseline

Command:

```sh
actus fmt --check benchmarks/aie_generation.act
actus build benchmarks/aie_generation.act --strict --emit exe \
  -o /tmp/twin-e-p5-6-generation.aie
/tmp/twin-e-p5-6-generation.aie
```

Output:

```text
verified generated native IR: no floating-point instructions
AIE_GENERATION generated=2 decoded_bytes=1 termination=eos \
cycle_generated=3 loop_guard=1 selected=highest_myelination
AIE_GENERATION generation_ns=26709
```

## Acceptance boundary

The hosted baseline closes the reproducible host measurement slice of Phase
5.6. Target-board selection, hardware cache measurements, sensor timing,
embedded filesystem interruption tests, and maximum scale claims remain open
until a specific target and test procedure are approved.

## Hosted persistence recovery

The host filesystem recovery fixtures were also executed under the same strict
compiler profile:

```sh
actus fmt --check benchmarks/aie_shard_bindings_dynamic.act
actus build --strict --emit exe \
  -o /tmp/twin-e-p5-6-save.aie \
  benchmarks/aie_shard_bindings_dynamic.act
/tmp/twin-e-p5-6-save.aie

actus fmt --check benchmarks/aie_shards_dynamic.act
actus build --strict --emit exe \
  -o /tmp/twin-e-p5-6-recovery.aie \
  benchmarks/aie_shards_dynamic.act
/tmp/twin-e-p5-6-recovery.aie
```

Observed output:

```text
AIE_BINDING_STAGE previous_generation_preserved
AIE_BINDING_STAGE dirty_after_failed_save
AIE_BINDING_STAGE validation_rejected error=IoError.InvalidData status=13
AIE_BINDING_STAGE persisted_after_successful_save
AIE_BINDING_STAGE payload_bindings_checksum_metadata_ok
AIE_SHARDS_DYNAMIC files=3 generated=1 staged_shard=1 validated=3 manifest_bound=2 swapped_rejected=1 dynamic_loaded=1 dynamic_collection=3 manifest_selected=1 dynamic_failed_unchanged=1 free_chain=5-2-0-null reallocated=2 payload_bytes=128
```

This proves the staged publication and incomplete-generation recovery contract
on the host filesystem. It does not prove power-loss atomicity, filesystem
durability barriers, or embedded storage behavior.

## Tested bounds

The recorded host fixtures cover 64 arena columns, 10,000 core iterations,
32 training events, three dynamic shard files, four cache entries, and 128
dynamic payload bytes. These are tested fixture sizes, not theoretical or
production limits.

## Hosted process restart timing

The fixed `.brain` restart fixture was built once for the writer and reader,
then each executable was run in ten separate processes. The measurement wraps
the complete process with the host monotonic clock, so it includes process
startup and should not be interpreted as raw filesystem throughput.

```text
writer_runs=10 writer_min_ns=1075878 writer_median_ns=1679171 writer_max_ns=2689142
reader_runs=10 reader_min_ns=1042084 reader_median_ns=1263094 reader_max_ns=2186530
snapshot_bytes=5702
```

This closes the hosted restart timing observation. Resident memory, cache
working set, and isolated storage throughput still require a dedicated profile
and remain open.

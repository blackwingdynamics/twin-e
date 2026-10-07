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

## Const-generic scale sweep

The scale fixture uses one generic implementation of the same wavefront
workload and specializes it for 64, 256, and 1024 arena columns. It passes a
pack-backed `CorticalFabric[N]` through an `ins` parameter and is built with
the Actus native lowering fix recorded in ADR-0072.

```sh
actus fmt --check benchmarks/aie_scale_sweep.act
actus check --strict benchmarks/aie_scale_sweep.act
actus build --strict --emit exe benchmarks/aie_scale_sweep.act \
  -o /tmp/twin-e-scale-sweep.aie
/tmp/twin-e-scale-sweep.aie
```

Compiler digest:

```text
f8f3a659e3b8a589018a833559ead567b2ad5dd0742192b656c1bf5d69dc0430
```

The earlier core, training, generation, persistence, and restart measurements
in this document retain their original compiler digest above the baseline
section. The scale sweep was rerun after the compiler lowering fix, so its
digest is recorded separately here.

Observed host output from one run (the current `std::io` integer printer emits
each value on its own line):

```text
verified generated native IR: no floating-point instructions
AIE_SCALE columns=64
 elapsed_ns=720423
AIE_SCALE columns=256
 elapsed_ns=710475
AIE_SCALE columns=1024
 elapsed_ns=701248
```

The workload touches one source and eight destinations, so this result is
evidence that the bounded representation and native ABI remain executable as
the resident arena grows. It is not a claim that the full arena is scanned on
every impulse, nor a hardware or maximum-capacity measurement.

## Current host hardware measurement

The current development computer was measured as the hosted Phase 5.6 target
on 2026-10-07. CPU frequency scaling was enabled, so these values are
repeatable observations for this machine and profile rather than fixed timing
guarantees.

```text
OS=Linux 7.2.7-arch1-1
architecture=x86_64
cpu=Intel(R) Core(TM) i7-14700KF
logical_cpus=28
compiler_sha256=f8f3a659e3b8a589018a833559ead567b2ad5dd0742192b656c1bf5d69dc0430

AIE_SCALE columns=64 elapsed_ns=470344
AIE_SCALE columns=256 elapsed_ns=462497
AIE_SCALE columns=1024 elapsed_ns=480865
AIE_HOT_PATH samples=64 filesystem_writes=0
 inference_clean_ns=10500
 inference_dirty_ns=9902
 neurogenesis_clean_ns=21149
 neurogenesis_dirty_ns=22333
AIE_HOT_PATH_RESIDENT_LOOKUP iterations=10000 filesystem_calls=0
 clean_ns=199820
 dirty_ns=212370
```

These are host-native debug-profile measurements. They do not close the
embedded target gate and must not be presented as ESP32, STM32, Nucleo, or
other board timings.

## Future hardware handoff

For every additional target, retain the same benchmark sources and record the
board, MCU, clock configuration, compiler digest, optimization profile,
toolchain, power state, sample count, and complete output. Repeat the scale,
resident hot-path, persistence, and zero-float checks without changing the
workload. Add a separate dated subsection for each target; do not overwrite
this host baseline or compare values across targets until clock and build
profiles are normalized.

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

This closes the hosted restart timing observation.

## Current compiler hosted rerun — 2026-10-07

The following measurements were repeated after installing the current Actus
compiler from the verified compiler branch.

```text
compiler_sha256=14181544766f3b8af67bc48b73170a339ff857cadcb2a1ff9c75bc6732d7fdb2
target=host
profile=debug

AIE_BENCH iterations=10000 arena_columns=64
AIE_BENCH coincidence_ns=687733
AIE_BENCH forwarding_8axon_ns=3825425
AIE_BENCH free_list_ns=147404
AIE_BENCH full_step_ns=4445861
AIE_TRAINING events=32 recall_profile=AB bounded=1
AIE_TRAINING training_ns=13078
AIE_TRAINING allocated_columns=3 active_bindings=3 snapshot_bytes=5702
AIE_GENERATION generated=2 decoded_bytes=1 termination=eos cycle_generated=3
loop_guard=1 selected=highest_myelination
AIE_GENERATION generation_ns=45934
AIE_HOT_PATH_RESIDENT_LOOKUP iterations=10000 filesystem_calls=0
AIE_HOT_PATH_RESIDENT_LOOKUP clean_ns=307346 dirty_ns=215276
AIE_CACHE capacity=4 working_set=4 dirty_rejected=1 pinned_rejected=1
clean_evicted=1 replacement=1 full_pressure_rejected=1
AIE_SCALE small_write_ns=41308 medium_write_ns=21869 large_write_ns=52917
sequential_ns=20050 random_lookup_ns=4233 selective_load_ns=2553
flush_ns=20819 restart_validation_ns=4841 files=3 max_profile_columns=32
```

Each executable was launched as a separate process and monitored with a
5 ms process and descendant RSS sampler. Observed peak resident sets were 88
KiB for the hot-path fixture, 88 KiB for the cache fixture, and 96 KiB for the
persistence fixture. The corresponding strict executable sizes were 7,673,272,
7,662,688, and 7,739,536 bytes. All exits were zero and every build reported
that no floating-point instructions were generated.

Storage throughput is represented by the bounded write profiles above. The
payload sizes are 128 bytes, 512 bytes, and 2,048 bytes for the small, medium,
and large profiles; the flush profile rewrites the 512-byte medium shard.
The benchmark also verifies three files, selective loading, checksum lookup,
and restart validation. These are host debug-profile observations and do not
close embedded board or filesystem durability gates.

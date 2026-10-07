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
filesystem interruption tests, and maximum scale claims remain open until a
specific target and test procedure are approved.

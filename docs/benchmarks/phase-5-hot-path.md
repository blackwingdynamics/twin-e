# Phase 5 Hot-Path and Persistence Baseline

These measurements are host-native debug-profile baselines. They are
reproducible executable evidence and do not represent hardware measurements.

## Hot-path command

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-hot-path.aie benchmarks/aie_p3_3.act
/tmp/twin-e-hot-path.aie
```

Observed output:

```text
built `/tmp/twin-e-hot-path.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_BENCH iterations=10000 arena_columns=64
AIE_BENCH coincidence_ns=687115
AIE_BENCH forwarding_8axon_ns=4989418
AIE_BENCH free_list_ns=151793
AIE_BENCH full_step_ns=4567788
```

The benchmark measures 10,000 repeated operations over a 64-column arena. The
reported values are aggregate nanoseconds for each loop, not per-operation
latency. The executable does not import filesystem persistence APIs, so the
fixture exercises resident computation only. A dedicated runtime filesystem
counter is still required before the negative hot-path write gate can close.

## Persistence command

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-persistence-scale.aie benchmarks/aie_persistence_scale.act
/tmp/twin-e-persistence-scale.aie
```

Observed output:

```text
built `/tmp/twin-e-persistence-scale.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_SCALE small_write_ns=39127
AIE_SCALE medium_write_ns=21749
AIE_SCALE large_write_ns=52435
AIE_SCALE sequential_ns=17434
AIE_SCALE random_lookup_ns=4107
AIE_SCALE selective_load_ns=2019
AIE_SCALE flush_ns=20761
AIE_SCALE restart_validation_ns=5063
AIE_SCALE files=3
AIE_SCALE max_profile_columns=32
```

`flush_ns` and `restart_validation_ns` are measured outside the resident
hot-path loop. These values are host-profile observations and should not be
used as CPU, board, or production latency claims.

## Clean and dirty resident metadata command

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-hot-path-resident.aie \
  benchmarks/aie_hot_path_resident_state.act
/tmp/twin-e-hot-path-resident.aie
```

Observed output:

```text
built `/tmp/twin-e-hot-path-resident.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_HOT_PATH_RESIDENT_LOOKUP iterations=10000 filesystem_calls=0
AIE_HOT_PATH_RESIDENT_LOOKUP clean_ns=335675 dirty_ns=340868
```

This compares bounded resident cache lookup with clean and dirty lifecycle
metadata. The fixture imports no filesystem module and reports the explicit
memory-only boundary. It is not a full neural neurogenesis latency result. An
earlier broader standalone neurogenesis fixture reached strict native build but
terminated with host exit status 132, so the full clean-versus-dirty
neurogenesis gate remains open until that runtime path is isolated and
reproduced.

## Remaining hot-path evidence

- compare clean and dirty resident shards using the same workload;
- add a runtime-backed negative filesystem-write counter or equivalent
  observable check;
- repeat the measurements on a selected target hardware profile.

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
AIE_HOT_PATH_RESIDENT_LOOKUP clean_ns=407107
 dirty_ns=202965
```

This compares bounded resident cache lookup with clean and dirty lifecycle
metadata. The fixture imports no filesystem module and reports the explicit
memory-only boundary. It is a cache lookup measurement, not a full neural
neurogenesis latency result.

## Additional hot-path evidence

The hot-path fixture has no filesystem write boundary. Reproduce the source
audit with:

  ```sh
  ! rg -n 'std::io|write_file|read_file|remove_file|rename' \
    benchmarks/aie_hot_path_clean_dirty.act
  ```

The audit command exits successfully when no filesystem API is present. The
fixture also keeps an explicit `HotPathAudit.filesystem_writes` value at zero
and fails if the hot-path code changes it. This is a source and runtime
boundary check; it is not a claim that the host operating system performed no
I/O outside the executable.

## Phase 5.1A gate-closing benchmark

```sh
actus fmt --check benchmarks/aie_hot_path_clean_dirty.act
actus build --strict --emit exe \
  -o /tmp/twin-e-hot-path-clean-dirty.aie \
  benchmarks/aie_hot_path_clean_dirty.act
/tmp/twin-e-hot-path-clean-dirty.aie
```

Observed output:

```text
built `/tmp/twin-e-hot-path-clean-dirty.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_HOT_PATH samples=64 filesystem_writes=0
 inference_clean_ns=13840
 inference_dirty_ns=9953
 neurogenesis_clean_ns=27363
 neurogenesis_dirty_ns=23245
```

The benchmark creates a fresh bounded fabric and resident cache for each of 64
samples. It measures inference and resident neurogenesis for both clean and
dirty cache metadata. Persistence is not called by either path; saving remains
an explicit operation measured separately above. These are host-native debug
profile totals and are not hardware latency claims.

The remaining evidence is target-specific: repeat the measurements on a
selected hardware profile.

## Phase 5.8 gate evidence record

The current host-profile evidence records the required boundaries as follows:

```text
disk_writes_hot_path=0
capacity=4
dirty_high_watermark=3
flush_ns=20761
committed_generation=10
recovery_status=stale_rejected=1 swapped_rejected=1
```

`disk_writes_hot_path=0` is represented by the resident fixture's
`filesystem_writes=0`; the explicit save and flush measurements remain outside
the inference and neurogenesis loops. Capacity and high-watermark behavior are
recorded in `docs/benchmarks/phase-5-cache-lifecycle.md`, while generation and
descriptor recovery are recorded in
`docs/benchmarks/phase-5-generation-recovery.md`.

The final strict validation for this gate also passed:

```text
actus lock --check: passed
actus check --strict: passed
actus test --strict: 46 passed; 0 failed
actus build --strict --emit exe: no floating-point instructions
```

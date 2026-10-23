# Phase 11 Gate 11.8 provenance

Recorded on 2026-10-22 from the clean Twin-e workspace on branch
`phase-10-teaching-ingestion`.

## Compiler and target

- Actus source revision: `6d2f396434ffdac8b20f7ed70b27dbf90996ca58`
- Actus binary: `/home/magradze/.cargo/bin/actus`
- Actus binary SHA-256:
  `9698eb742874ee8b331c18fc8a4db295c3dc676dd028600d241907d2fb8e6379`
- Rust toolchain: `rustc 1.98.0`, host `x86_64-unknown-linux-gnu`
- Host: Arch Linux x86_64, kernel `7.2.9-arch1-1`
- Compiler profile: `actus build --strict --emit exe`
- Native verification: the strict benchmark builds reported no floating-point
  instructions.

Fresh verification command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-gate-11-8-native-evidence \
  benchmarks/ie_logical_scale_profiles.act
```

Observed compiler result: `verified generated native IR: no floating-point
instructions`. The resulting executable SHA-256 is
`b4192449028f0dc71c64683757accb8ce93cbc66a379a17559537d351eb0f10d`.

## Benchmark artifacts

| Evidence | Build output SHA-256 |
| --- | --- |
| scale profiles | `b4192449028f0dc71c64683757accb8ce93cbc66a379a17559537d351eb0f10d` |
| latency boundaries | `33be1193a135073877ed32474815ab34737bb731cc1b888d55bbe2bda56cef37` |
| capacity and memory profile | `424e5dc80d6100ce3705132de507af12d65e74731804668caf93a97b36b0d230` |

## Dataset revision

The accepted Georgian baseline is not a Git checkout, so its reproducible
revision is the ordered content hash set below:

```text
starter-0001.twf  ea2a0e150d79c84b172099e8fb33832d55c2f9f34e4ddf8f37e70811bdd0267c
starter-0002.twf  70cb7e3b7213a1b4c3b9f60832ec57e56c09259dd4b98652692a8953e29aa771
starter-0003.twf  0868f57b8d9b2d7282f05f2e411fd817a45b1ee240109b575c346005a3c09890
```

Dataset root:
`/home/magradze/Projects/twin-e-data/twin-e-training/datasets/accepted/georgian-baseline`

## Exact commands

```sh
actus build --strict --emit exe -o /tmp/twin-e-gate-11-8-scale \
  benchmarks/ie_logical_scale_profiles.act
actus build --strict --emit exe -o /tmp/twin-e-gate-11-8-latency \
  benchmarks/ie_logical_latency.act
actus build --strict --emit exe -o /tmp/twin-e-gate-11-8-memory \
  benchmarks/ie_logical_profile.act
/tmp/twin-e-gate-11-8-scale
/tmp/twin-e-gate-11-8-latency
/tmp/twin-e-gate-11-8-memory
actus fmt --check tests/ie_logical_save_failure.act
actus lock --check
actus check --strict
actus test --strict
```

The benchmark inputs and selected bounded profile are recorded in the scale,
latency, and capacity evidence documents. The full strict suite currently
reports `170 passed; 0 failed`.

## Repeatability

Each Gate 11.8 executable was run twice. The normalized outputs compared
byte-for-byte after replacing only timing fields (`restore_ns`, `adapter_ns`,
`admission_ns`, `routing_ns`, `teaching_ns`, `flush_ns`, and
`publication_ns`) with the marker `<timing>`:

```text
scale=identical_logical_results_and_bounds
latency=identical_logical_results_and_bounds
memory=identical_logical_results_and_bounds
```

This proves repeatable logical results and bounded profile values while keeping
variable runtime latency measurements separate.

## Hot-path audit

Audit command:

```sh
rg -n "write_file|read_to_bytes|rename|delete|open_file|path_from" \
  src/ie/runtime src/ie/persistence/logical/teaching.act \
  src/runner/teaching.act src/runner/logical_teaching.act src/teaching
```

The runtime/training and logical teaching paths contain no filesystem calls.
`read_to_bytes` appears only in the explicit file-input transport adapters;
publication remains in the separate save path. The runner teaching boundary
passes an explicit flush result and does not open, write, rename, or publish a
file during inference or teaching.

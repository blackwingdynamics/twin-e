# AIE Roadmap

Current status and remaining work for the Actus Impulse Engine.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## Completed work

### Project and Actus structure

- [x] Created the `Actus.toml` package manifest.
- [x] Created the `src/main.act` entry point.
- [x] Created the `src/aie/aie.act` public facade.
- [x] Formatted all source files with the Actus formatter.
- [x] Applied the updated Actus compiler contract and repository guide.

### Minicolumn and memory layout

- [x] Created the 64-byte array-backed `Minicolumn` pack.
- [x] Defined the 512-bit field layout with little-endian packing.
- [x] Stored all links as `u32` arena indexes.
- [x] Defined `NULL_INDEX` as `4294967295u32`.
- [x] Added support for `Array[Minicolumn, 64]`.
- [x] Verified the 64-byte array stride for minicolumns.
- [~] A separate runtime alignment assertion is not present; layout and stride tests cover the current compiler contract.

### Fabric and free-list

- [x] Fabric initialization.
- [x] O(1) column allocation.
- [x] O(1) column deallocation.
- [x] Clearing all eight axons in `free_column`.
- [x] Updating the free-list head and active count.
- [x] Testing free-list allocation order.

### Coincidence engine and plasticity

- [x] Software `u64` population count.
- [x] 128-bit coincidence evaluation.
- [x] Threshold-based firing.
- [x] Sub-threshold charge accumulation.
- [x] Myelination reinforcement.
- [x] Lateral inhibition.
- [x] Refractory and inhibition state reset during sweeps.
- [x] Homeostatic idle counter.
- [x] Unified decay rule using `myelination < 100u8`.
- [x] Dynamic neurogenesis and novel wavefront seeding.
- [x] Linking a new column to an open axon slot on the active frontier.
- [x] Impulse forwarding across eight axon destinations.

### Serialization

- [x] 64-byte snapshot for one `Minicolumn`.
- [x] Restore for one `Minicolumn`.
- [x] Fabric column snapshot and restore APIs.
- [x] The full fabric snapshot stores `free_list_head` and `active_count` as separate metadata.
- [x] Added `.brain` snapshot magic, version, header-size, and payload-size metadata.
- [x] Serialization round-trip test.
- [x] Rejection tests for corrupted headers and truncated payload metadata.

### Tests and native verification

- [x] Cache stride test.
- [x] Bitwise coincidence test.
- [x] Lateral inhibition test.
- [x] Free-list integrity test.
- [x] All four tests pass through the package-aware Actus test runner.
- [x] Native executable build passes.
- [x] Native executable runs with `exit_code=0`.
- [x] Object emission passes.
- [x] `verify_no_float_ir = true` is enabled in `Actus.toml`.
- [x] Cranelift IR audit confirms that generated Actus IR contains no floating-point instructions.
- [x] Dedicated neurogenesis and linking test.
- [x] Dedicated homeostatic decay test.
- [x] Dedicated forwarding test covering all eight axons.
- [x] Dedicated serialization round-trip test.
- [x] Direct assertion of `forward_impulse`'s returned `Array[u32, 8]` values and all eight forwarding firing side effects.

## Remaining work by priority

### P0 — Complete functional contract coverage

- [x] Add `test_neurogenesis_and_linking` for allocation, seeding, and source axon attachment.
- [x] Add `test_homeostatic_decay` for the 240 idle-tick reclaim rule and low-myelination columns.
- [x] Add `test_forward_impulse` for all eight destinations and their firing side effects.
- [x] Add `test_serialization_roundtrip` covering column bytes and fabric metadata.

### P1 — Complete fabric snapshots

- [x] Add `free_list_head` to the snapshot format.
- [x] Add `active_count` to the snapshot format.
- [x] Add a snapshot header and version for the `.brain` format.
- [x] Add rejection tests for corrupted and truncated snapshots.

### P1 — Generic API

- [x] Recheck const-generic verb support in the new compiler; the compiler accepts generic verbs and the native regression test passes.
- [x] Generalize engine and fabric verbs to `CorticalFabric[N]`; serialization remains a fixed 64-column `.brain` format by contract.
- [x] Add a native specialization test for a const-generic verb.

### P2 — Source organization

P2 is tracked in [phase-2.md](phase-2.md).

## Final acceptance criteria

The AIE release is complete when:

- [x] All P0 tests pass.
- [x] A complete fabric snapshot round-trips with fabric metadata.
- [x] The generic API decision is backed by compiler evidence; generic verbs are supported by the current compiler.
- [x] Strict check, native build, executable run, and zero-float IR audit pass.

P2 source organization and package configuration are complete. See [phase-2.md](phase-2.md) for the detailed checklist and evidence.

### Directory layout

- [x] Move AIE modules into `layout/`, `runtime/`, and `persistence/` subdirectories using hierarchical canonical facades.
- [x] Verify parent-facade exports without direct nested imports; external code continues to use `import aie;`.

## Last verified toolchain result

The updated release Actus compiler verified:

```text
check --strict: passed
test --strict: 10 passed
object build: passed
executable build: passed
executable run: exit_code=0
zero-float IR audit: passed
```

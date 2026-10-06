# Phase 5 Save Boundary Evidence

## Scope

This record covers the first implementation pass for the caller-driven shard
save boundary. The save path keeps resident state in memory, writes a staged
`.brain` generation, validates the staged bytes, publishes the generation, and
only then reports the save as successful.

The benchmark is intentionally separate from inference and impulse forwarding.
It is allowed to perform filesystem I/O because it exercises the explicit save
boundary.

## Current implementation

- `src/aie/persistence/shard/save.act` owns the dirty-slot save request and
  changes the cache lifecycle to `Persisted` only after the flush returns
  successfully.
- `src/aie/persistence/shard/flush.act` writes the staged generation, reads it
  back, validates the header, payload, local bindings, and metadata, and then
  publishes it through rename.
- `benchmarks/aie_shard_bindings_dynamic.act` reports typed stage labels for
  path probing, writing, staged reads, validation, and cleanup failures.
- `docs/roadmap/phase-5.md` tracks the save boundary as ordered acceptance
  gates. The gates remain open until failure fixtures and recovery evidence are
  complete.

## Reproduction command

From the Twin-e repository root:

```sh
actus fmt --check benchmarks/aie_shard_bindings_dynamic.act
actus build --strict --emit exe \
  -o /tmp/twin-e-shard-bindings-save.aie \
  benchmarks/aie_shard_bindings_dynamic.act
rm -f /tmp/twin-e-binding-shard.brain /tmp/twin-e-stage.brain
/tmp/twin-e-shard-bindings-save.aie
```

## Observed success evidence

The current run produced:

```text
benchmarks/aie_shard_bindings_dynamic.act is formatted
built `/tmp/twin-e-shard-bindings-save.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_BINDING_STAGE start
AIE_BINDING_STAGE write_ok
AIE_BINDING_STAGE validate_ok
AIE_SHARD_BINDINGS_DYNAMIC columns=2 bindings=2 stride=24 validated=1
exit_status=0
```

The active file was created at `/tmp/twin-e-binding-shard.brain` and the staged
file was consumed by publication. This proves the successful write, validation,
and publication path for one two-column shard with two local bindings.

## Remaining evidence for Gate A

The following failure fixtures are still required before Gate A can close:

- force a staged write failure and record the typed `IoError`;
- force a staged read failure after the write step;
- corrupt staged bytes and record validation rejection before publication;
- force rename failure and prove that the previous active generation remains;
- record each exit status and filesystem state in this document.

## Regression baseline

The current repository baseline remains:

```text
actus lock --check       PASS
actus check --strict     PASS
actus test --strict      18 passed; 0 failed
actus build --strict     PASS; no floating-point instructions
```

These results do not close the save-boundary gates by themselves. The failure
and recovery fixtures above are part of the acceptance contract.

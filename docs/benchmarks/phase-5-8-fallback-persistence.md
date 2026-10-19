# Phase 5.8 fallback persistence and recovery evidence

This fixture exercises byte-fallback state at the fixed host limits. The
engine uses one 64-column resident fabric and a 64-slot binding sidecar. The
training sequence contains distinct raw byte fallback events, so the test
does not depend on a trained BPE vocabulary.

## Reproducible commands

The recorded run used the Actus compiler built from the separate Actus
repository:

```sh
actus=/home/magradze/Projects/actus_project/actus/target/debug/actus
sha256sum "$actus"
"$actus" fmt --check benchmarks/aie_fallback_persistence.act
"$actus" build --strict --emit exe -o /tmp/twin-e-fallback-persistence.aie \
  benchmarks/aie_fallback_persistence.act
/tmp/twin-e-fallback-persistence.aie
"$actus" fmt --check benchmarks/aie_fallback_restart_write.act
"$actus" fmt --check benchmarks/aie_fallback_restart_read.act
"$actus" build --strict --emit exe -o /tmp/twin-e-fallback-restart-write.aie \
  benchmarks/aie_fallback_restart_write.act
"$actus" build --strict --emit exe -o /tmp/twin-e-fallback-restart-read.aie \
  benchmarks/aie_fallback_restart_read.act
/tmp/twin-e-fallback-restart-write.aie
/tmp/twin-e-fallback-restart-read.aie
```

Conditions: Twin-e commit `acdcf6593c3a2e12752e3331436188f3b9e88c71`, host
Linux, strict native executable profile, compiler digest
`322711227604bc52452f2ad015748f17df7facee1a9233c114a2bc4bdc6817bb`.
Each strict build reported that generated native IR contained no
floating-point instructions.

## Recorded output

```text
AIE_FALLBACK_PERSISTENCE first_brain_bytes=5702 repeated_brain_bytes=5702
AIE_FALLBACK_PERSISTENCE training_passes=2 events=62 active_bindings=62 active_columns=64 shard_columns=64 binding_slots=64
 growth_bytes=0 oversized_rejected=1 unchanged=1 failed_save_unchanged=1
AIE_FALLBACK_RESTART save=1 events=63 active_bindings=63 active_columns=64 process=writer
AIE_FALLBACK_RESTART reload=1 events=63 active_bindings=63 active_columns=64 process=reader
```

The first executable fills the 64-column arena after two bounded training
passes: the second pass reuses the existing 62 fallback identities and uses
the remaining root slot. Two saves produce the same fixed 5,702-byte `.brain`
file, so repeated training and save do not grow the bounded artifact. The
separate writer and reader processes restore a 63-binding, 64-column
fallback-heavy state from fresh process memory.

The same executable appends one byte to the valid artifact and verifies that
the oversized file is rejected before sentinel live state changes. It also
attempts a save to the `/tmp` directory, which fails, and verifies that the
resident fallback state remains unchanged. These are host persistence checks;
they do not claim hardware or multi-shard scaling beyond the configured fixed
limits.

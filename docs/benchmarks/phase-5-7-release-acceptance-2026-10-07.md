# Phase 5.7 Release Acceptance Evidence — 2026-10-07

## Environment

- Target: hosted Linux x86-64
- Profile: strict hosted executable
- Compiler: `/home/magradze/.cargo/bin/actus`
- Compiler SHA-256:
  `14181544766f3b8af67bc48b73170a339ff857cadcb2a1ff9c75bc6732d7fdb2`
- Native IR policy: every build verified no floating-point instructions

## Reproduction commands

```sh
actus build --strict --emit exe benchmarks/aie_text_brain_file.act \
  -o /tmp/twin-e-p57-brain-file.aie
/tmp/twin-e-p57-brain-file.aie

actus build --strict --emit exe benchmarks/aie_text_brain_bounds.act \
  -o /tmp/twin-e-p57-brain-bounds.aie
/tmp/twin-e-p57-brain-bounds.aie

actus build --strict --emit exe benchmarks/aie_bpe.act \
  -o /tmp/twin-e-p57-bpe.aie
/tmp/twin-e-p57-bpe.aie

actus build --strict --emit exe benchmarks/aie_text_brain_vocabulary.act \
  -o /tmp/twin-e-p57-vocab.aie
/tmp/twin-e-p57-vocab.aie

actus build --strict --emit exe benchmarks/aie_brain_shards.act \
  -o /tmp/twin-e-p57-shards.aie
/tmp/twin-e-p57-shards.aie
```

## Observed results

```text
AIE_P5_BRAIN roundtrip=1 bytes=5702 fabric=1 bindings=1 compatibility=1 corrupted_rejected=1 unchanged=1
AIE_P5_BRAIN_BOUNDS truncated_rejected=1 oversized_rejected=1 unchanged=1
AIE_BPE input_bytes=2 output_tokens=3 special_tokens=2 decoded_bytes=2 merged_decode=2 artifact=valid rejected=1 invalid_rank_rejected=1 oversized_span_rejected=1 unknown_rejected=1
AIE_P5_BRAIN_VOCAB bytes=11106 rules=3 tokens=3 repeated_merge=1 reload_decode=1 compatibility=1 corrupted_rejected=1 unchanged=1
AIE_BRAIN_SHARDS roundtrip=1 shard0=1 shard1=1 cross_shard_axon=32 corrupted_rejected=1 fabric_unchanged=1
```

All five executables exited with status `0`. The evidence covers the combined
`.brain` round trip, corrupted and truncated input rejection, multi-merge
vocabulary persistence, artifact compatibility, shard-local state, and
cross-shard links. It is hosted evidence and does not claim embedded storage
durability or board performance.

## Training, restart, observation, and action evidence

Additional strict executions with the same compiler produced:

```text
AIE_TRAINING events=32 recall_profile=AB bounded=1
AIE_TRAINING training_ns=12917 allocated_columns=3 active_bindings=3 snapshot_bytes=5702
AIE_P5_RESTART save=1 bytes=5702 process=writer
AIE_P5_RESTART reload=1 recalled=1 process=reader
AIE_OBSERVATION_ROUNDTRIP bytes=20 code_roundtrip=1 active_bits=8
```

`actus test --strict` also passed the deterministic action, conflict, safety,
observation, and training fixtures: 34 passed, 0 failed. These results close
the hosted training/restart and deterministic observation/action acceptance
slice. Target-board evidence remains separate.

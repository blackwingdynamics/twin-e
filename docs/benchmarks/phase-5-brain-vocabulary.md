# Phase 5 Vocabulary Snapshot Benchmark

This benchmark writes the fixed fabric, token/context bindings, and a bounded
BPE vocabulary into one `.brain` file. It starts a fresh in-memory state,
reloads the file, decodes `ABCD`, and then rejects a corrupted vocabulary byte
without changing the live fabric or bindings.

## Recorded configuration

- Source fixture: `benchmarks/aie_text_brain_vocabulary.act`
- Source base: current `phase-5-gate-0-contracts` revision
- Compiler: installed `actus` strict profile
- Compiler SHA-256: `dded14d179fc5fe748b6ae2c43b7780cf2a845133055586226529ff88fd3dcef`
- Target: host native executable
- Vocabulary bounds: 128 merge rules, 256 token records, 8 bytes per token
- Fixture contents: 3 ranked merge rules and 3 merged token records

## Size breakdown

| Section | Bytes |
| --- | ---: |
| Combined header | 32 |
| Fabric section | 4,116 |
| Binding section | 1,554 |
| Vocabulary section | 5,404 |
| **Total** | **11,106** |

## Command

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-p5-brain-vocabulary.aie \
  benchmarks/aie_text_brain_vocabulary.act
/tmp/twin-e-p5-brain-vocabulary.aie
```

The strict build reported that generated native IR contains no floating-point
instructions. The executable produced:

```text
AIE_P5_BRAIN_VOCAB bytes=11106 rules=3 tokens=3 repeated_merge=1 reload_decode=1 compatibility=1 corrupted_rejected=1 unchanged=1
```

This proves bounded multi-merge vocabulary persistence, repeated ranked merge
passes, in-process reload decode identity, checksum or section rejection for
corrupted vocabulary data, and preservation of live state after the failed
load. The separate BPE benchmark covers byte fallback, BOS, EOS, and merged
token decoding. It does not prove a separate-process vocabulary restart or
measure vocabulary quality and token-count reduction on a representative
corpus; those remain P5.2 work.

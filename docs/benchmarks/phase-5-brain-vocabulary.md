# Phase 5 Vocabulary Snapshot Benchmark

This benchmark writes the fixed fabric, token/context bindings, and a bounded
BPE vocabulary into one `.brain` file. It starts a fresh in-memory state,
reloads the file, decodes `Hi`, and then rejects a corrupted vocabulary byte
without changing the live fabric or bindings.

## Recorded configuration

- Source fixture: `benchmarks/aie_text_brain_vocabulary.act`
- Source base: `7e5233b` before this implementation commit
- Compiler: installed `actus` strict profile
- Compiler SHA-256: `827fa0a8b43fdbf8562872459048037e82017484055a5a71e4d03a8890d9168b`
- Target: host native executable
- Vocabulary bounds: 128 merge rules, 256 token records, 8 bytes per token
- Fixture contents: 1 merge rule and 1 merged token record

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
AIE_P5_BRAIN_VOCAB bytes=11106 rules=1 tokens=1 restart_decode=1 compatibility=1 corrupted_rejected=1 unchanged=1
```

This proves bounded vocabulary persistence, in-process reload decode identity,
checksum or section rejection for corrupted vocabulary data, and preservation
of live state after the failed load. It does not prove a separate-process
vocabulary restart or measure vocabulary quality and token-count reduction on
a representative corpus; those remain P5.2 work.

# BPE Encoding Evidence

This fixture applies a deterministic ranked merge from a versioned bounded
vocabulary artifact. The rule `(65, 66) -> 1000` merges `AB` into one token
while the tokenizer rejects an incompatible artifact version.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-bpe.aie \
  benchmarks/aie_bpe.act
/tmp/twin-e-bpe.aie
```

## Recorded result

```text
AIE_BPE input_bytes=2 output_tokens=1 merged_id=1000 artifact=valid rejected=1
```

The implementation is bounded by the configured tokenizer size and merge-rule
capacity. UTF-8 decode and context-aware generation remain later gates.

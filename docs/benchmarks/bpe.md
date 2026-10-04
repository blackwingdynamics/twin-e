# BPE Encoding Evidence

This fixture applies a deterministic ranked merge from a versioned bounded
vocabulary artifact. The rule `(65, 66) -> 1000` merges `AB` into one token
while the tokenizer rejects an incompatible artifact version. A byte-fallback
vocabulary adds BOS/EOS markers and decodes the same text back to two bytes;
the merged token record `(1000 -> [65, 66])` also decodes back to the same two
bytes.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-bpe.aie \
  benchmarks/aie_bpe.act
/tmp/twin-e-bpe.aie
```

## Recorded result

```text
AIE_BPE input_bytes=2 output_tokens=3 special_tokens=2 decoded_bytes=2 merged_decode=2 artifact=valid rejected=1
```

The implementation is bounded by the configured tokenizer size and merge-rule
capacity. It now covers special tokens, byte fallback, and bounded byte
decode. Context-aware generation remains a later gate.

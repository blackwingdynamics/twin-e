# Mixed BPE and byte fallback

The mixed fixture feeds four raw bytes through the bounded tokenizer: the
known pair `[65, 66]`, followed by malformed bytes `[195, 40]`. One BPE rule
merges the known pair; the remaining bytes stay as byte-fallback tokens.

Command:

```text
actus fmt --check benchmarks/aie_mixed_bpe_fallback.act
actus build --strict --emit exe -o /tmp/twin-e-mixed-bpe-fallback.aie benchmarks/aie_mixed_bpe_fallback.act
/tmp/twin-e-mixed-bpe-fallback.aie
```

The source passes strict semantic checking and the fixed Actus compiler builds
and runs it with Cranelift. The compiler build used the release binary from
the `fix/native-call-cleanup-types` branch.

```text
AIE_MIXED_BPE_FALLBACK input_bytes=4 emitted_tokens=3 merged_known_pairs=1 fallback_bytes=2 malformed_preserved=true
```

This proves tokenizer-side mixing only: one known BPE pair is compacted and
two fallback bytes remain individually addressable. Training-side context
bindings, minicolumn allocation, resident memory, and `.brain` growth remain
open.

# Byte and BPE Token Count Evidence

This benchmark tokenizes the same fixed text through the byte adapter and the
bounded BPE merge pass:

```text
actus build benchmarks/ie_token_count.act --strict --emit exe \
  -o /tmp/twin-e-token-count.ie
/tmp/twin-e-token-count.ie
```

Expected output:

```text
IE_TOKEN_COUNTS text=Hello Giorgi byte_tokens=12
 bpe_tokens=11
 reduction=1
```

The byte path emits one token per byte. The current fixture applies one
validated bounded merge and reduces the sequence by one token. Larger merge
chains remain a separate tokenizer-quality task and are not claimed by this
benchmark.

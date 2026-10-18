# Larger Text Token Count Evidence

This benchmark compares byte tokenization with the bounded ranked BPE pass on
a repeated text fixture. The fixture is larger than the short `Hello Giorgi`
example and uses nine bounded rules for repeated word fragments.

## Command

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-token-count-corpus.aie \
  benchmarks/aie_token_count_corpus.act
/tmp/twin-e-token-count-corpus.aie
```

## Recorded result

```text
AIE_TOKEN_CORPUS byte_tokens=55
 bpe_tokens=27
 reduction=28
```

The result is a bounded fixture measurement, not a claim about a trained
production vocabulary or arbitrary natural-language compression. The strict
release build verified that the generated native IR contains no floating-point
instructions.

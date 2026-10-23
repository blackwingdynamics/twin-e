# Byte fallback envelope

## Command and profile

The bounded raw-byte fallback was measured with:

```text
actus fmt --check benchmarks/ie_byte_fallback_envelope.act
actus build --strict --emit exe -o /tmp/twin-e-byte-fallback.ie benchmarks/ie_byte_fallback_envelope.act
/tmp/twin-e-byte-fallback.ie
```

The strict native build reported `verified generated native IR: no
floating-point instructions`.

The tokenizer profile is `TOKENIZER_MAX_BYTES=256` with fixed
`TokenSequence` capacity `256`. The fallback does not decode bytes as Unicode
and does not allocate or perform filesystem I/O.

## Captured output

```text
IE_BYTE_FALLBACK max_input_bytes=256 fixed_token_capacity=256 repeated_bytes=64
 unique_bytes=64
 utf8_raw_bytes=2
 malformed_raw_bytes=2
 oversized_valid=false
```

The repeated and unique classes both preserve all 64 input bytes. The UTF-8
sample uses the raw two-byte encoding of a non-ASCII character and remains two
byte tokens. The malformed sample `[195, 40]` is also preserved as two byte
tokens; it is not silently dropped or replaced. A declared length of 257 bytes
is rejected and produces an invalid empty sequence.

## Evidence boundary

This closes only the bounded tokenizer-side behavior for repeated, unique,
UTF-8 raw, and malformed raw bytes. It does not measure BPE vocabulary misses,
mixed BPE/fallback training, context-binding growth, resident shards, or
`.brain` growth. Those require the training and persistence fixtures in Gate
5.8.2.

# String Tokenization and Codebook Recall Evidence

This fixture verifies the current text path from a native Actus `String` to
tokenizer output, sparse token codes, AIE training, and recalled UTF-8 bytes.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-token-code-string.aie \
  benchmarks/aie_string_example.act
/tmp/twin-e-token-code-string.aie
```

## Recorded result

```text
AIE_STRING_HELLO arena=1000 recalled=12/12
Hello Giorgi
9470
3092
```

The first line confirms that all 12 token positions were recalled in the
1,000-column arena. The second line is reconstructed from recalled payload
bytes and converted through `utf8_from_buffer`; it is not a prewritten result
message. The final two integer lines are the debug-host training/fill and
recall timings in nanoseconds.

The strict executable build also verified that generated native IR contains no
floating-point instructions.

This evidence uses the current byte-token transition adapter. It does not yet
represent a persisted BPE vocabulary, subword merge rules, or context-aware
sequence disambiguation.

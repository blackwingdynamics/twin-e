# Initial Token Codebook Collision Evidence

This benchmark evaluates the first deterministic integer-only 128-bit token
codebook profile used by the tokenizer and encoding facades.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-codebook-collision.aie \
  benchmarks/aie_codebook_collision.act
/tmp/twin-e-codebook-collision.aie
```

## Recorded result

The benchmark generated token IDs `0..4999`, assigned eight unique active bits
to every code, and compared every pair of different codes.

```text
AIE_CODEBOOK tokens=5000 active_bits=8
AIE_CODEBOOK max_different_overlap=6
AIE_CODEBOOK duplicate_pairs=0
AIE_CODEBOOK invalid_code_count=0
AIE_CODEBOOK elapsed_ns=95331169
```

The executable was built with strict checking and the compiler verified that
the generated native IR contains no floating-point instructions.

For this sample, the largest overlap between two different token codes was
six bits. No pair had overlap eight or greater, and every generated code had
exactly eight set bits. This supports using exact eight-bit matching for this
initial sample, subject to the limitations below.

## Limits of this evidence

- The sample uses numeric token IDs rather than a trained subword vocabulary.
- It reports the maximum and duplicate count, but not the full overlap
  histogram or a false-fire rate over a workload distribution.
- It does not test corrupted or partially observed wavefronts.
- The elapsed time is a debug-host measurement, not a release performance
  claim.

The codebook remains an initial profile until a vocabulary-backed benchmark
adds overlap distribution, threshold sweep, noisy recall, and context-aware
sequence cases.

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
AIE_CODEBOOK population=token_ids size=5000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK max_different_overlap=6
AIE_CODEBOOK duplicate_pairs=0
AIE_CODEBOOK invalid_code_count=0
AIE_CODEBOOK false_pairs_theta=8 count=0
AIE_CODEBOOK elapsed_ns=94388616
```

The executable was built with strict checking and the compiler verified that
the generated native IR contains no floating-point instructions.

For this sample, the largest overlap between two different token codes was
six bits. No pair had overlap eight or greater, and every generated code had
exactly eight set bits. This supports using exact eight-bit matching for this
initial sample, subject to the limitations below.

The threshold sweep counted different-code pairs that would fire at each
candidate threshold:

| Threshold | False pairs |
|---:|---:|
| 4 | 8,154 |
| 5 | 353 |
| 6 | 9 |
| 7 | 0 |
| 8 | 0 |

The initial exact-match profile therefore uses `k = 8` and `theta = 8` for
this sample. Lower thresholds may be useful for noisy input, but they require
an identity check or a separate noise benchmark before adoption.

## Limits of this evidence

- The sample uses numeric token IDs rather than a trained subword vocabulary.
- It reports pairwise overlap counts for this deterministic token-ID
  population, but not a false-fire rate over a workload distribution.
- It does not test corrupted or partially observed wavefronts.
- The elapsed time is a debug-host measurement, not a release performance
  claim.

The codebook remains an initial profile until a vocabulary-backed benchmark
adds noisy recall, workload-level candidate measurements, and context-aware
sequence cases.

## Phase 5.8.1 baseline rerun

The baseline was rerun after the codebook seed became an explicit shared
configuration value and the benchmark began recording its profile metadata.

Environment:

- Date: 2026-10-08
- Population: sequential token IDs
- Population size: 5,000
- Codebook version: `1`
- Active bits: `8`
- Seed: `11400714819323198485`
- Compiler: `/home/magradze/.cargo/bin/actus`
- Compiler SHA-256:
  `94ca52990794a8897e58de4af07d1805268876c07bbeee2c7bf6595e188409b2`
- Target/profile: hosted x86-64 / debug

Command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-codebook-collision-p5-8-noise.aie \
  benchmarks/aie_codebook_collision.act
/tmp/twin-e-codebook-collision-p5-8-noise.aie
```

Observed output:

```text
AIE_CODEBOOK population=token_ids size=5000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK max_different_overlap=6
AIE_CODEBOOK duplicate_pairs=0
AIE_CODEBOOK invalid_code_count=0
AIE_CODEBOOK overlap_bucket=0 count=7337055
AIE_CODEBOOK overlap_bucket=1 count=4129377
AIE_CODEBOOK overlap_bucket=2 count=910520
AIE_CODEBOOK overlap_bucket=3 count=112394
AIE_CODEBOOK overlap_bucket=4 count=7801
AIE_CODEBOOK overlap_bucket=5 count=344
AIE_CODEBOOK overlap_bucket=6 count=9
AIE_CODEBOOK overlap_bucket=7 count=0
AIE_CODEBOOK overlap_bucket=8 count=0
AIE_CODEBOOK false_pairs_theta=1 count=5160445
AIE_CODEBOOK false_pairs_theta=2 count=1031068
AIE_CODEBOOK false_pairs_theta=3 count=120548
AIE_CODEBOOK false_pairs_theta=4 count=8154
AIE_CODEBOOK false_pairs_theta=5 count=353
AIE_CODEBOOK false_pairs_theta=6 count=9
AIE_CODEBOOK false_pairs_theta=7 count=0
AIE_CODEBOOK false_pairs_theta=8 count=0
AIE_CODEBOOK noise=one_active_bit_removed
AIE_CODEBOOK exact_query_candidates_theta=8 count=1
AIE_CODEBOOK noisy_query_candidates_theta=8 count=0
AIE_CODEBOOK noisy_query_candidates_theta=7 count=1
AIE_CODEBOOK elapsed_ns=95762111
```

The strict build again verified that the generated native IR contains no
floating-point instructions. This rerun confirms the initial 5,000-token
profile and does not close the larger-population, vocabulary-backed, noisy
input, or ambiguous-candidate requirements of Phase 5.8.1.

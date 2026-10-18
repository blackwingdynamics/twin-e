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
  `2392d84b813973d7bc33d67ebc191a3bee5c55a7f5604564529eae52e28e87c9`
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
AIE_CODEBOOK elapsed_ns=91887120
```

The strict build again verified that the generated native IR contains no
floating-point instructions. This rerun confirms the initial 5,000-token
profile and does not close the larger-population, vocabulary-backed, noisy
input, or ambiguous-candidate requirements of Phase 5.8.1.

## Phase 5.8.1 — 50,000-entry exact-duplicate stress fixture

The first larger population uses a fixed open-address table with 131,072
slots and a bounded index derived from the generated code. It measures exact
duplicate admission without allocating a dynamic collection. This fixture is
intentionally narrower than the full Gate 5.8.1 contract: overlap
distributions and workload-level candidate rates remain separate
measurements.

Command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-codebook-population-50000.aie \
  benchmarks/aie_codebook_population_50000.act
/tmp/twin-e-codebook-population-50000.aie
```

The fixture records the population profile, occupied slots, exact duplicate
count, first duplicate position, table exhaustion, elapsed time, and the
strict native zero-floating-point result. Its acceptance condition is that all
50,000 identities occupy distinct codewords and the bounded table does not
exhaust.

Observed output:

```text
AIE_CODEBOOK_STRESS population=token_ids size=50000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_STRESS occupied_slots=50000
AIE_CODEBOOK_STRESS exact_duplicate_count=0
AIE_CODEBOOK_STRESS first_duplicate_token=50000
AIE_CODEBOOK_STRESS table_exhausted=false
AIE_CODEBOOK_STRESS elapsed_ns=515952685
```

The strict build verified that the generated native IR contains no
floating-point instructions. This closes the exact-duplicate measurement for
the 50,000-entry sequential token-ID fixture only. The 500,000-entry,
1,000,000-entry, and 5,000,000-entry populations, vocabulary-backed input,
and overlap/candidate workload evidence remain open.

## Phase 5.8.1 — 500,000-entry streaming cardinality fixture

The 500,000-entry run is intentionally streaming. It generates every code and
checks active-bit cardinality and profile version without materializing a
500,000-slot duplicate table. It also records a deterministic XOR fingerprint
of the generated masks. The fingerprint is reproducibility evidence; it is not
an exact collision detector.

Command:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-codebook-generation-500000.aie \
  benchmarks/aie_codebook_generation_500000.act
/tmp/twin-e-codebook-generation-500000.aie
```

This fixture therefore measures generation/cardinality scale only. Exact
duplicate detection at 500,000 entries remains open until a bounded resident
storage strategy can retain the required identity table without hidden
allocation or an unverified provider assumption.

Observed output:

```text
AIE_CODEBOOK_STREAM population=token_ids size=500000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_STREAM invalid_code_count=0
AIE_CODEBOOK_STREAM fingerprint_low=2013059615
AIE_CODEBOOK_STREAM fingerprint_high=718036136
AIE_CODEBOOK_STREAM elapsed_ns=22076607
```

The strict build verified that the generated native IR contains no
floating-point instructions. The result proves that all 500,000 generated
codes satisfied the configured eight-bit cardinality and version checks. It
does not prove zero exact duplicates for that population.

## Phase 5.8.1 — 500,000-entry exact-duplicate storage boundary

The exact-duplicate fixture now uses a bounded byte buffer for a
1,048,576-slot open-address table and a runtime-backed Region publication
boundary. Each slot stores both 64-bit code masks, so the measurement compares
complete generated codewords against previously admitted codewords rather
than comparing a fingerprint. Slot placement uses an integer mixing step over
both masks; using the sparse low mask directly caused severe clustering at the
500,000-entry population.

Command:

```sh
actus fmt --check benchmarks/aie_codebook_population_500000.act
actus build --strict --release --emit exe \
  benchmarks/aie_codebook_population_500000.act \
  -o /tmp/twin-e-codebook-500000-region-release.aie
/tmp/twin-e-codebook-500000-region-release.aie
```

Environment:

- target: hosted Linux x86-64;
- profile: strict release executable;
- compiler SHA-256: `e6293f8075d7982b95c1ec8b54eb18d97d1c2ec98f5cf9a8c70120522e38feda`;
- native IR: verified no floating-point instructions.

Observed output:

```text
AIE_CODEBOOK_REGION population=token_ids size=500000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_REGION occupied_slots=500000
AIE_CODEBOOK_REGION exact_duplicate_count=0
AIE_CODEBOOK_REGION first_duplicate_token=500000
AIE_CODEBOOK_REGION table_exhausted=false
AIE_CODEBOOK_REGION elapsed_ms=133
```

This closes the hosted 500,000-entry exact-duplicate measurement slice. It
does not close the complete Phase 5.8.1 gate: larger populations, overlap
distribution, candidate retrieval, noisy-input rates, and a complete memory
envelope remain open. The fixture's lookup table is bounded resident storage;
the Region path validates bulk staging and publication but is not evidence of
window-remapped lookup during every table probe.

## Phase 5.8.1 — 1,000,000-entry exact-duplicate measurement

The same bounded Region-backed fixture was scaled to a 2,097,152-slot table
for one million sequential token IDs. The complete generated codewords were
checked with the same mixed slot hash and exact two-mask comparison.

Command:

```sh
actus fmt --check benchmarks/aie_codebook_population_1000000.act
actus build --strict --release --emit exe \
  benchmarks/aie_codebook_population_1000000.act \
  -o /tmp/twin-e-codebook-1000000-region-release.aie
time /tmp/twin-e-codebook-1000000-region-release.aie
```

Observed output:

```text
AIE_CODEBOOK_REGION population=token_ids size=1000000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_REGION occupied_slots=1000000
AIE_CODEBOOK_REGION exact_duplicate_count=0
AIE_CODEBOOK_REGION first_duplicate_token=1000000
AIE_CODEBOOK_REGION table_exhausted=false
AIE_CODEBOOK_REGION elapsed_ms=304
0.69s user 0.01s system 99% cpu 0.701 total
```

The strict native build again verified no floating-point instructions. This
closes the hosted one-million-entry exact-duplicate measurement slice only;
the five-million population, overlap distribution, candidate retrieval,
noisy-input rates, and complete memory envelope remain open.

## Phase 5.8.1 — 5,000,000-entry exact-duplicate measurement

The Region-backed fixture was scaled to a 16,777,216-slot table for five
million sequential token IDs. The bounded table completed without exhaustion,
but the exact identity comparison found duplicate generated codewords. This is
an observed collision in the current deterministic codebook profile, not a
passing zero-duplicate result.

Command:

```sh
actus fmt --check benchmarks/aie_codebook_population_5000000.act
actus build --strict --release --emit exe \
  benchmarks/aie_codebook_population_5000000.act \
  -o /tmp/twin-e-codebook-population-5000000-region-release.aie
time /tmp/twin-e-codebook-population-5000000-region-release.aie
```

Environment:

- target: hosted Linux x86-64;
- profile: strict release executable;
- compiler SHA-256: `e6293f8075d7982b95c1ec8b54eb18d97d1c2ec98f5cf9a8c70120522e38feda`;
- resident buffers: 2 × 256 MiB;
- native IR: verified no floating-point instructions.

Observed output:

```text
AIE_CODEBOOK_REGION population=token_ids size=5000000 codebook_version=1 active_bits=8 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_REGION occupied_slots=4999986
AIE_CODEBOOK_REGION exact_duplicate_count=14
AIE_CODEBOOK_REGION first_duplicate_token=1409529
AIE_CODEBOOK_REGION table_exhausted=false
AIE_CODEBOOK_REGION elapsed_ms=1417
4.48s user 0.04s system 99% cpu 4.528 total
```

The executable returned exit code `1`, as required by the fixture when an
exact duplicate is found. The lookup interval was 1,417 ms; the complete
process runtime was 4.528 s. This result closes the five-million-entry
measurement as evidence of a current codebook collision, while overlap
distribution, candidate retrieval, noisy-input rates, and the complete memory
envelope remain open.

## Phase 5.8.1 — 12-bit profile rerun

The active-bit configuration was changed from eight to twelve while retaining
codebook version `1`, as permitted for the `0.1.0` pre-release with no trained
`.brain` artifacts in service. The same bounded fixtures were rerun against the
new profile.

Observed one-million-entry output:

```text
AIE_CODEBOOK_REGION population=token_ids size=1000000 codebook_version=1 active_bits=12 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_REGION occupied_slots=1000000
AIE_CODEBOOK_REGION exact_duplicate_count=0
AIE_CODEBOOK_REGION first_duplicate_token=1000000
AIE_CODEBOOK_REGION table_exhausted=false
AIE_CODEBOOK_REGION elapsed_ms=313
0.68s user 0.01s system 99% cpu 0.695 total
```

Observed five-million-entry output:

```text
AIE_CODEBOOK_REGION population=token_ids size=5000000 codebook_version=1 active_bits=12 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK_REGION occupied_slots=5000000
AIE_CODEBOOK_REGION exact_duplicate_count=0
AIE_CODEBOOK_REGION first_duplicate_token=5000000
AIE_CODEBOOK_REGION table_exhausted=false
AIE_CODEBOOK_REGION elapsed_ms=1547
4.54s user 0.04s system 99% cpu 4.596 total
```

Both strict release builds verified no floating-point instructions and both
executables returned exit code `0`. The 12-bit profile therefore closes the
exact-duplicate measurement for the tested one-million and five-million token
populations. It does not yet close overlap-distribution, candidate-retrieval,
noise-rate, or complete memory-envelope evidence.

The 5,000-token pairwise and noise fixture was also rerun with the current
profile:

```text
AIE_CODEBOOK population=token_ids size=5000 codebook_version=1 active_bits=12 seed=11400714819323198485 generation=sequential_u32
AIE_CODEBOOK max_different_overlap=8
AIE_CODEBOOK duplicate_pairs=0
AIE_CODEBOOK invalid_code_count=0
AIE_CODEBOOK false_pairs_theta=12 count=0
AIE_CODEBOOK noise=one_active_bit_removed
AIE_CODEBOOK exact_query_candidates_theta=12 count=1
AIE_CODEBOOK noisy_query_candidates_theta=12 count=0
AIE_CODEBOOK noisy_query_candidates_theta=11 count=1
```

The relaxed `theta=11` result is the intended one-bit-removal recovery
measurement; it remains candidate retrieval evidence and does not authorize
lowering the final firing threshold without exact identity validation.

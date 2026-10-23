# ADR-0001: Subword Tokens with Sparse Binary Encoding for IE Language Input

- **Status:** Accepted
- **Date:** 2026-10-04
- **Scope:** IE language input, training, recall, and text readout
- **Related work:** P3.1 public engine API, P3.2 executable demo, P3.3 performance baseline

## Context

Actus Impulse Engine (IE) is a sparse, event-driven neural runtime. Its core
does not use dense matrix multiplication, floating-point embeddings, or a
global activation pass. It receives a bounded `Wavefront`, evaluates binary
coincidence, propagates impulses through fixed axon slots, creates new
minicolumns for novel patterns, reinforces successful paths, and removes weak
idle columns through homeostatic decay.

The first `Hello Giorgi` evidence fixture proves that the current engine can
store and recall a short character sequence. The current version now obtains
the input through the String tokenizer facade and maps each returned token ID
through the versioned sparse codebook before creating a `Wavefront`. It remains
a small byte-token transition fixture, not a complete subword vocabulary for
larger corpora or real language input.

We need a text representation that provides:

- compact handling of common words and word fragments;
- a bounded vocabulary with a defined unknown and boundary policy;
- deterministic conversion into IE's 128-bit receptive-field format;
- stable persistence and replay across training and recall;
- a clean boundary between text processing and the low-level neural engine;
- compatibility with sparse event-driven execution.

## Decision

Use a **subword tokenizer** followed by a **versioned sparse binary codebook**.
The tokenizer produces subword token IDs. The encoder maps each token ID to a
128-bit sparse distributed representation composed of two `u64` masks. IE
receives only the encoded `Wavefront`; it does not parse UTF-8, own tokenizer
vocabulary rules, or inspect token strings during coincidence evaluation.

The first tokenizer implementation will use a deterministic BPE-style
subword vocabulary. The tokenizer algorithm is behind a package facade so the
vocabulary format and IE input contract remain stable if a later experiment
selects another subword training algorithm.

The tokenization and neural layers have these responsibilities:

```text
text -> tokenizer -> token IDs -> sparse codebook -> Wavefront -> IE
                                                        |
                                                        v
                         token IDs <- readout <- active columns and paths
```

### 1. Tokenizer contract

The tokenizer owns:

- normalized text input policy;
- vocabulary entries and token IDs;
- beginning-of-sequence, end-of-sequence, and boundary markers;
- unknown or byte-fallback behavior;
- deterministic encode and decode operations;
- vocabulary and tokenizer version identifiers.

Token IDs are opaque values outside the tokenizer. A token ID must not be
treated as a binary mask by taking its numeric bits directly. Numeric IDs are
labels; the codebook is the representation used by IE.

The tokenizer artifact must be persisted with the vocabulary, merge rules,
normalization version, fallback policy, and codebook version. A network state
must not be loaded with an incompatible tokenizer artifact.

The pre-release byte fallback is a bounded raw-byte adapter behind the same
tokenizer facade. It maps each input byte one-to-one to its byte token ID and
preserves the source offset, including for malformed UTF-8. It does not decode
Unicode scalars, aggregate bytes into wider tokens, allocate, or perform
filesystem I/O. The declared input length must be no greater than the fixed
`TOKENIZER_MAX_BYTES` bound; otherwise the sequence is invalid and empty.
This policy is intentionally separate from BPE unknown-token decoding and
remains subject to the Gate 5.8.2 training and persistence measurements.

### 2. Sparse codebook contract

The encoder maps each token ID to:

```text
TokenCode {
    mask_low:  u64,
    mask_high: u64,
    version:   u16,
}
```

The two masks form the 128-bit receptive field already accepted by `Wavefront`.
The codebook uses a fixed, bounded number of active bits per token. The active
bit count, codebook seed, collision policy, and coincidence threshold are one
versioned encoding profile and must be validated together.

The initial profile must be selected by a collision and recall benchmark. It
must satisfy these properties:

- identical tokens always produce identical masks;
- different common tokens produce sufficiently different masks;
- the overlap threshold allows intended recognition;
- accidental overlap does not frequently trigger unrelated columns;
- the profile is reproducible across processes and machines;
- no floating-point operation is required to encode or compare a token.

The benchmark must report the maximum overlap among *different* token codes,
the overlap distribution, duplicate codes, and the false-fire rate at every
candidate threshold. A threshold cannot simply be set above the maximum overlap
of all pairs: an exact match of a `k`-bit code has overlap `k`, so a threshold
above `k` would reject the token it is meant to recognize. For exact code
recognition, the initial profile should normally use `theta = k` and verify
that different codewords do not duplicate. If noise tolerance requires a lower
threshold, a second-stage codebook or identity verification is required.

The current IE policy threshold is a separate engine setting and must not be
copied blindly into a token profile. For example, a code with `k = 8` active
bits cannot reach a threshold of `20`. Token code density and coincidence
threshold therefore belong to one tested encoding profile.

The encoder may use a deterministic integer hash and a fixed codebook, but it
must not silently change a token's code when the process restarts. For the
current `0.1.0` pre-release, while no trained `.brain` artifacts are in
service, an intentional codebook profile change may remain under version `1`
when it is recorded in the ADRs and benchmark documentation. After persisted
trained artifacts become compatible data, codebook changes require a new
version and an explicit migration or retraining decision.

### 3. IE training contract

Training a token sequence follows this bounded event flow:

1. Normalize and tokenize the input text.
2. Encode each token ID using the versioned sparse codebook.
3. Submit the resulting wavefronts in sequence through the public IE API.
4. Let existing columns fire when their coincidence score reaches the profile
   threshold.
5. Reinforce the active path and its axon transition when the sequence is
   observed again.
6. Use neurogenesis when a novel token or context pattern has no suitable
   existing column.
7. Apply decay and free-list reclamation to weak, unused columns during clock
   steps.

The first implementation may store one token event per minicolumn. Later
context-aware columns may represent a token together with a bounded preceding
context. The context width must remain explicit and measurable; it must not
become an unbounded hidden state.

One token-only column is insufficient for high-order sequence disambiguation.
If the same token occurs in different contexts, its outgoing paths can point to
different next tokens. The production sequence representation must therefore
use a context state, such as a bounded preceding-token window or a
context-specific transition column. The active state, rather than the token
label alone, selects the next path. Repeated observations reinforce the
context-specific transition; decay removes unused context states.

The first context profile must declare its window size, for example `n = 2` or
`n = 3`, and benchmark ambiguity, memory growth, recall accuracy, and branching
behavior. A context column may share the token's input code, but its identity
must include the bounded context through a separate deterministic composition
or a versioned context key.

Training is associative and incremental. It strengthens observed paths and
creates bounded new state. It does not claim to reproduce transformer
backpropagation or dense next-token probability estimation.

### 4. IE recall contract

Recall uses the same tokenizer and codebook versions as training:

1. Tokenize the input context.
2. Encode the context tokens into wavefronts.
3. Submit them through the public engine API.
4. Read fired payloads, destination columns, and reinforced paths.
5. Decode the selected token IDs through the tokenizer.

The readout policy is a separate layer. IE returns bounded engine results; a
decoder chooses whether to return a recalled token, the next linked token, a
ranked bounded set, or a failure/unknown result. The low-level engine must not
embed text formatting into minicolumn evaluation.

## Initial collision evidence

The first codebook benchmark now generates 5,000 deterministic token codes,
checks that every code contains exactly eight unique active bits, compares all
pairs of different codes, and counts false pairs for each candidate threshold.
The recorded run reported a maximum different code overlap of six, zero
duplicate pairs, zero invalid code cardinality, and zero false pairs at
`theta=8`. The strict executable build also passed the zero-floating-point IR
check. The full command and limitations are recorded in
`docs/benchmarks/codebook-collision.md`.

This is a useful gate for the initial profile, not a final language-model
validation. The next benchmark must use a persisted tokenizer vocabulary and
add the overlap distribution, candidate threshold sweep, noisy recall, and
context-sensitive sequence cases described above.

## Why this decision fits IE

Subwords provide a practical middle ground:

- character units create long sequences and expensive long-range paths;
- whole-word units create a large vocabulary and poor unknown-word behavior;
- subwords reuse common prefixes, suffixes, stems, and word fragments;
- the vocabulary remains finite and can be persisted as a compact artifact;
- one token can be encoded as one bounded binary event for the engine.

Sparse binary codes also preserve the engine's core properties. Coincidence
uses integer bitwise operations and population counts. The runtime can keep
its fixed 64-byte minicolumn layout, indexed axons, local plasticity, and
zero-floating-point contract.

### Token identity and payload width

The current minicolumn `payload` field is `u8`, while a 2,000- or 5,000-token
vocabulary requires a wider token identity. A token ID must not be truncated
into that field. The initial design will keep the 64-byte minicolumn contract
and store token identity in a position-independent sidecar binding indexed by
arena column:

```text
TokenBinding {
    token_id:       u32,
    context_key:    u64,
    binding_flags:  u8,
}
```

The sidecar is part of the serialized network state and is addressed by the
same `u32` column index. The IE core can continue to return column indexes and
small event payloads; the readout layer resolves the index through the binding
table and returns the tokenizer's `u32` token ID. A future layout revision may
embed a wider identity, but that requires a new layout and persistence version.

## Alternatives considered

### Character-level encoding

Character-level input is retained for the smallest engine demonstrations and
compiler fixtures. It is rejected as the primary language representation
because common text becomes a long sequence and requires many more temporal
transitions.

### Whole-word vocabulary

Whole-word tokens are rejected as the primary representation because the
vocabulary grows quickly, spelling variants multiply entries, and unseen words
require a large unknown bucket or an additional fallback system.

### Direct token ID bits

Using the numeric token ID as `mask_low` or `mask_high` is rejected. Nearby IDs
would have arbitrary and often similar bit patterns, codebook behavior would
depend on vocabulary numbering, and changing the vocabulary would silently
change neural input semantics.

### Dense floating-point embeddings

Dense embeddings and GEMM-based processing are outside this engine's core
contract. They would change the memory, execution, and zero-floating-point
properties that IE is designed to measure.

### Transformer-compatible next-token probabilities

IE may eventually expose a bounded ranking or readout layer, but matching a
transformer's dense probability distribution is not part of this decision.
The first target is sparse associative sequence recall with measurable local
updates and bounded memory behavior.

## Consequences

### Positive consequences

- Text processing becomes separate from the cache-line-oriented engine core.
- The same token can be recognized consistently during training and recall.
- Subword reuse reduces sequence length compared with character-only input.
- Binary codebook encoding preserves integer-only native execution.
- Tokenizer and codebook versions make saved network state auditable.
- The engine can remain useful for non-text inputs because its input contract
  is still a `Wavefront`, not a text-specific type.

### Costs and risks

- A tokenizer artifact becomes part of model compatibility and deployment.
- Codebook collisions can cause false coincidences or unwanted firing.
- A 128-bit field limits the codebook profile and requires collision testing.
- Long-context behavior requires explicit context columns and additional
  memory.
- A 5,000-token vocabulary cannot be represented losslessly by the current
  `u8` minicolumn payload and needs the versioned sidecar binding.
- A large arena can consume substantial memory even when event processing is
  sparse. Sparse or paged allocation remains a later storage decision.
- The first implementation needs a deterministic decoder and unknown-token
  policy before it can claim general text generation.

## Implementation boundary

The following modules should remain separate:

```text
src/tokenizer/        vocabulary, normalization, BPE encode/decode
src/encoding/         token ID -> versioned 128-bit sparse code
src/ie/              wavefront evaluation, plasticity, propagation, decay
src/readout/          fired columns and token IDs -> text or structured result
```

The current repository may introduce these as package facades incrementally.
The IE facade should accept encoded wavefronts and expose engine results. It
should not import tokenizer implementation details into minicolumn or runtime
modules.

## Required Actus/compiler capabilities

The design depends on these language and compiler capabilities:

- bounded arrays of wavefronts, token IDs, and codebook entries;
- deterministic integer hashing or an equivalent integer-only codebook helper;
- safe bounded access to `String` UTF-8 data or a public tokenizer input API;
- construction of `String` output from decoded token data;
- native emission of generic runtime calls reached through nested facades;
- stable package configuration and persistence for tokenizer/codebook versions;
- sidecar token bindings indexed by position-independent arena index.

The current `Hello Giorgi` fixture proves the String tokenizer and sparse
codebook path end to end: it returns 12 tokens, encodes their token IDs into
128-bit codes, trains and recalls 1,000 arena columns, and reconstructs the
actual `Hello Giorgi` bytes. It remains a byte-token transition fixture; the
persisted subword vocabulary and BPE merge implementation are still pending.

## Delivery plan

1. Define tokenizer and codebook data contracts without changing IE core.
2. Add deterministic subword vocabulary loading and tokenization.
3. Add the 128-bit sparse encoder and collision/threshold benchmarks for 2,000
   and 5,000 token profiles.
4. Add sidecar token bindings and persistence version checks.
5. Define and benchmark a bounded context window for sequence disambiguation.
6. Add a training facade that submits token sequences through `step_wavefront`.
7. Add a bounded recall/readout facade that returns token IDs.
8. Add decode tests, persistence compatibility checks, and version rejection.
9. Measure text training and recall on fixed corpora and arena sizes.
10. Add paged or sparse arena storage only after correctness and profiling.

## Acceptance criteria

This decision is considered implemented when:

- the same tokenizer and codebook reproduce identical wavefronts across runs;
- a subword sequence can be trained and recalled through the public IE API;
- the codebook benchmark reports pairwise overlap, duplicate codes, and false
  fires for the declared vocabulary sizes;
- a bounded context window routes ambiguous repeated tokens to the correct
  next-token path;
- an unknown or incompatible tokenizer/codebook version is rejected explicitly;
- token IDs round-trip through sidecar bindings without `u8` truncation;
- training and recall remain integer-only and pass the zero-float IR audit;
- the readout returns token IDs or text without exposing raw arena pointers;
- benchmark results include tokenizer version, codebook version, vocabulary
  size, arena size, context width, compiler digest, and target profile.

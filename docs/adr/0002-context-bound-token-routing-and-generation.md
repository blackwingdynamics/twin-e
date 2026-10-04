# ADR-0002: Context-Bound Token Routing and Associative Generation

- **Status:** Accepted
- **Date:** 2026-10-04
- **Scope:** AIE sequence memory, token representation, context routing, and
  text generation
- **Related work:** ADR-0001, P3.1 public engine API, P3.2 executable demo,
  P3.6 tokenizer and sparse codebook foundation

## Context

The Actus Impulse Engine (AIE) currently provides a working sparse associative
substrate:

- each cortical minicolumn occupies a fixed 64-byte cache-line-shaped record;
- the arena uses position-independent `u32` indexes rather than raw pointers;
- the free list provides constant-time column allocation and reclamation;
- binary coincidence uses integer bitwise operations and population counts;
- firing reinforces myelination, propagates through bounded axon slots, and
  supports lateral inhibition and homeostatic decay;
- a String can be tokenized through the current byte-token adapter, encoded as
  a deterministic sparse 128-bit code, trained into the AIE arena, and recalled
  as `Hello Giorgi`.

The current representation identifies a token by its code alone. If the same
token appears in multiple sequences, its outgoing axon slots can represent
several unrelated successors. For example:

```text
Giorgi went home
Giorgi eats an apple
```

After both sequences are learned, a token-only `Giorgi` state does not contain
enough information to select the correct continuation. A token identity and a
bounded temporal context must participate in the state identity.

The current tokenizer is also a byte-token transition adapter. It proves the
String-to-AIE path, but byte-level sequences become long as input grows. A
versioned BPE-style subword vocabulary is needed to reduce sequence length,
provide reusable word fragments, and define unknown-token behavior.

Finally, the engine currently demonstrates recall of trained values. It does
not yet expose a bounded text-generation loop that selects a learned successor,
decodes it, and stops at an end-of-sequence marker.

## Decision

Adopt a context-bound sparse sequence architecture with three layers:

```text
text
  -> BPE tokenizer
  -> token IDs
  -> context-bound token identity
  -> sparse 128-bit Wavefront
  -> AIE transition graph
  -> selected token IDs
  -> tokenizer decoder
  -> text
```

The AIE core remains token- and text-agnostic. Tokenization, context-key
construction, successor selection, and decoding live behind package facades.

### 1. Temporal binding

For a bounded context window, the effective state is formed from the current
token and the preceding token or bounded preceding-token window. The first
profile uses a two-token state:

```text
state_t = bind(token_t, token_t-1)
```

The initial binding profile may use rotational XOR over the 128-bit code:

```text
Wavefront_t = TokenCode_t XOR ROTL(TokenCode_t-1, 7)
```

The implementation must treat this as a versioned encoding profile. The
rotation width, context window, seed, active-bit count, and collision policy
must be stored in package configuration and included in the profile version.

The current implementation already has a deterministic bounded context-key
contract and probe. The next implementation step is to bind that context
identity to token sidecar state and AIE routing. A rotational XOR implementation
must preserve a tested active-bit policy. XOR can cancel bits, so the resulting
code must be measured and either repaired by deterministic re-seeding or
encoded through a second-stage sparse codebook.

The context identity must satisfy these properties:

- the same ordered context always produces the same identity;
- changing the preceding token changes the identity with high probability;
- context width is explicit and bounded;
- different context states do not silently share one successor list;
- the identity is reproducible after process restart and snapshot reload;
- the operation uses integer-only native instructions.

### 1.1 Accepted implementation refinement: two-stage context encoding

The implementation will use a two-stage deterministic encoding profile as the
default:

```text
context_key = Hash64(token_t, token_t-1, context_version)
context_code = Codebook(context_key)
```

The codebook is responsible for producing exactly eight unique active bits in
the final 128-bit code. Directly XORing two sparse eight-bit codes is retained
as an experiment, not as the default production path, because XOR can cancel
bits and produce fewer than eight active bits. Any rotational XOR profile must
pass the same cardinality and collision gates before it can be selected.

The two-stage profile makes the invariant explicit: context hashing creates a
stable identity, and the codebook creates the stable sparse representation.
The context hash seed, hash version, codebook version, active-bit count, and
collision policy are one compatibility profile.

### 2. Context-bound token bindings

The minicolumn layout remains 64 bytes. Token identity and context identity are
stored in a position-independent sidecar indexed by the minicolumn arena index:

```text
TokenBinding {
    token_id:       u32,
    context_key:    u64,
    tokenizer_version: u16,
    context_version:   u16,
    binding_flags:   u8,
}
```

The binary layout is explicitly aligned and occupies 24 bytes:

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | `token_id: u32` |
| 4 | 4 | alignment reservation |
| 8 | 8 | `context_key: u64` |
| 16 | 2 | `tokenizer_version: u16` |
| 18 | 2 | `context_version: u16` |
| 20 | 1 | `binding_flags: u8` |
| 21 | 3 | trailing reservation |

The four-byte internal reservation aligns `context_key` to an eight-byte
boundary. The three-byte trailing reservation makes the complete sidecar entry
24 bytes. The implementation must verify the serialized byte offsets and
stride; it must not rely on an implicit host ABI layout.

The sidecar is part of the serialized network state. A minicolumn's small
`payload: u8` field must not be used as a truncated token ID. The readout layer
resolves a fired arena index through the sidecar and returns the full tokenizer
token ID.

Training a context-bound transition follows this flow:

1. tokenize the input using the active tokenizer artifact;
2. compute the bounded context identity for the current token;
3. encode the context-bound state into a sparse `Wavefront`;
4. find or create the corresponding minicolumn;
5. attach or reinforce the observed successor transition;
6. store the full token and context identity in the sidecar;
7. apply local decay to unused context states.

The context state, rather than the token label alone, selects the outgoing
transition list.

### 3. BPE tokenizer facade

The tokenizer facade will evolve from the current byte-token adapter to a
versioned BPE-style implementation. The facade owns:

- vocabulary entries and stable token IDs;
- merge rules and merge ordering;
- normalization version;
- beginning-of-sequence and end-of-sequence markers;
- unknown-token and byte-fallback policy;
- bounded encode and decode operations;
- vocabulary artifact compatibility checks.

The AIE package consumes token IDs and encoded wavefronts. It does not inspect
token strings or implement merge rules. The tokenizer and codebook versions
must be stored with snapshots and rejected when incompatible.

### 3.1 `.brain` persistence boundary

The `.brain` name identifies the position-independent binary snapshot format.
The current implementation provides in-memory `FabricSnapshot`,
`BindingSnapshot`, and `TextSnapshot` values plus serialization and restore
verbs. A host file is not created by those verbs. A later persistence gate must
add explicit `.brain` file save/load operations through the standard I/O
provider, preserve the compatibility headers, and reject truncated or
incompatible files before mutating the live fabric or binding sidecar.

The first BPE delivery must include a small persisted vocabulary fixture and a
benchmark comparing byte-token and subword sequence length. It must not claim
that every phrase becomes two or three tokens; token count depends on the
trained vocabulary and merge rules.

### 4. Associative generation

Generation is a bounded graph traversal over context-bound learned
transitions. It does not calculate a dense vocabulary-wide softmax.

The initial generation policy is:

1. accept a bounded prompt and tokenize it;
2. construct the current context state;
3. evaluate the active context-bound minicolumn;
4. collect valid successor candidates from its axon slots;
5. select the candidate with the strongest validated myelination;
6. decode and append the selected token;
7. advance the bounded context window;
8. stop on EOS, a caller-provided maximum token count, no valid successor, or
   an explicit energy/deadline limit.

The selection policy must define deterministic tie-breaking. The first profile
uses highest myelination followed by the lowest arena index. Later profiles may
add bounded exploration or top-k selection, but these are separate policies
and must remain integer-only and measurable.

### 4.1 Accepted generation loop guard

Generation must include a loop guard in addition to the maximum token limit.
The first implementation will track a bounded recent-column history and reject
or deprioritize a candidate that would repeat the same column three times in a
row. A refractory or temporary fatigue state may implement this policy, but it
must be scoped to the generation call and must not permanently mutate learned
myelination.

The guard exists for learned cycles such as:

```text
A -> B -> C -> A -> B -> C
```

The generation contract therefore stops or selects an alternative when the
repetition guard fires, and always stops at EOS, the caller's maximum token
count, no valid successor, or an explicit energy/deadline limit. The exact
recent-history bound and fallback selection rule must be benchmarked with a
cycle fixture.

Generation is associative continuation over learned transitions. It is not
Transformer probability estimation and does not claim semantic generalization
from unseen transitions.

## Current baseline

The current project evidence reports:

- 64-byte minicolumn records aligned to the intended cache-line layout;
- free-list allocation measured at approximately 24 ns in the current debug
  host benchmark;
- a 1,000-column String training and recall fixture with approximately 15 us
  training/fill and 1.3 us recall in the earlier recorded run;
- actual recalled output reconstructed as `Hello Giorgi`;
- a 5,000-code collision benchmark with eight unique active bits per code,
  maximum different-code overlap of six, and zero false pairs at `theta=8`;
- a deterministic bounded context-key probe.

These are host-specific prototype measurements. They are evidence for the
current implementation and workload, not universal hardware or production
throughput guarantees.

## Alternatives considered

### Token-only routing

Rejected for sequence memory because one token state cannot distinguish
different preceding contexts. It remains useful for the smallest associative
fixtures and non-sequential classification tasks.

### Dense self-attention or GEMM

Rejected for the AIE core because it changes the memory layout, execution
model, and zero-floating-point design contract.

### Unbounded context history

Rejected because it makes state growth, memory use, and recall behavior
unbounded. Context width must be explicit and benchmarked.

### Selecting the first valid axon

Rejected for generation because axon slot order is an allocation detail and
does not represent learned transition strength. Selection must use a defined
strength policy and deterministic tie-break.

### Highest myelination without context binding

Rejected because stronger edges still cannot resolve two unrelated successors
attached to the same token-only state.

## Consequences

### Positive consequences

- repeated tokens can have different successor paths in different contexts;
- sequence memory stays bounded by the declared context window;
- subword tokenization reduces temporal sequence length for common fragments;
- generation can run through integer-only local graph traversal;
- the 64-byte minicolumn contract remains stable;
- tokenizer, context, and codebook compatibility becomes explicit in snapshots.

### Costs and risks

- context states increase arena usage and sidecar storage;
- larger context windows increase neurogenesis and snapshot size;
- rotational XOR may alter active-bit cardinality and requires collision tests;
- a greedy myelination policy may over-select frequent paths;
- BPE quality depends on the vocabulary artifact and training corpus;
- associative generation cannot produce unseen transitions without a separate
  generalization mechanism.

## Implementation plan

1. Add and serialize the `TokenBinding` sidecar indexed by arena column.
2. Implement and benchmark rotational context binding with active-bit repair or
   a versioned second-stage codebook.
3. Add a two-context ambiguity fixture where identical tokens route to distinct
   successors.
4. Implement persisted BPE vocabulary, merge rules, EOS, unknown, and fallback
   behavior behind the tokenizer facade.
5. Compare byte-token and BPE sequence lengths on a fixed corpus.
6. Add bounded generation with myelination selection, tie-breaking, EOS, and
   maximum-length guards.
7. Record strict build, executable output, zero-float IR, recall accuracy,
   memory growth, and generation latency.

## Acceptance criteria

- identical token text in two bounded contexts selects different context
  bindings and does not merge their successor lists;
- context binding is deterministic across runs and snapshot reloads;
- the default context profile uses two-stage `Hash64` plus codebook encoding
  and produces exactly eight active bits;
- any rotational XOR experiment records its active-bit cardinality and is
  rejected if the declared profile is not preserved;
- `TokenBinding` serializes to 24 bytes with `context_key` at offset 8;
- the BPE facade encodes and decodes a persisted vocabulary fixture;
- the BPE path reduces token count for the declared benchmark corpus;
- generation returns a deterministic learned continuation and stops at EOS or
  the configured bound;
- a cyclic transition fixture terminates through the recent-history loop guard;
- all new paths pass strict checking, native executable build, executable run,
  and zero-floating-point IR verification;
- no raw operating-system pointers or floating-point operations are introduced.

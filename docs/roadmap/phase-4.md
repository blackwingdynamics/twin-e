# AIE Phase 4 Roadmap

Phase 4 turns the accepted context-bound text architecture in ADR-0002 into
measurable Actus implementations. The phase starts with contracts and
evidence gates so that context routing, BPE, and generation remain compatible
with the existing 64-byte AIE core.

**Current status:** Active. Phase 3 remains partially complete while the
configuration and compiler-parity items that Phase 4 depends on are closed.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## P4.0 — Pre-implementation contracts

- [x] Accept ADR-0002 for context-bound routing and associative generation.
- [x] Choose two-stage `Hash64(context) -> sparse codebook` as the default
  context encoding profile.
- [x] Keep rotational XOR as a measured experimental profile.
- [x] Define the 24-byte `TokenBinding` layout with `context_key` at offset 8.
- [x] Define generation EOS, maximum length, deterministic tie-break, and
  loop-guard requirements.
- [x] Add and verify the 24-byte serialized layout fixture for `TokenBinding`.
- [x] Add a context-code cardinality and collision benchmark for context pairs.

## P4.1 — Context-bound AIE state

- [ ] Add a position-independent `TokenBinding` sidecar indexed by arena slot.
- [x] Serialize and restore the sidecar with tokenizer and context versions.
- [x] Combine fabric and binding payloads into the final text snapshot wrapper.
- [ ] Reject snapshots with incompatible tokenizer, codebook, or context
  profiles.
- [~] Bind context identity to minicolumn lookup and neurogenesis; sidecar bind
  and lookup are implemented, while runtime-integrated state lookup remains.
- [x] Add an ambiguity fixture where the same token has two context-specific
  successors.
- [x] Verify that the two successor paths do not share one token-only state.

## P4.2 — BPE tokenizer

- [ ] Define a persisted vocabulary artifact and merge-rule format.
- [ ] Add BOS, EOS, unknown, and byte-fallback entries.
- [ ] Implement bounded deterministic BPE encoding behind `src/tokenizer/`.
- [ ] Implement decode from token IDs to bounded UTF-8 output.
- [ ] Compare byte-token and BPE token counts on a fixed text fixture.
- [ ] Verify artifact version compatibility during snapshot load.

## P4.3 — Associative generation

- [ ] Add a bounded generation API that accepts a tokenized prompt.
- [ ] Select valid successors by highest myelination, then lowest arena index.
- [ ] Add EOS and maximum-token termination.
- [ ] Add a bounded recent-column history loop guard.
- [ ] Verify a cyclic `A -> B -> C -> A` graph terminates safely.
- [ ] Decode generated token IDs through the tokenizer facade.
- [ ] Record generation latency, path length, and termination reason.

## P4.4 — Validation gates

- [ ] Strict check passes for all new modules.
- [ ] Native object and executable builds pass.
- [ ] Generated native IR contains no floating-point instructions.
- [ ] Context collision and active-bit cardinality evidence is recorded.
- [ ] TokenBinding serialization round-trip passes.
- [ ] Context ambiguity recall passes.
- [ ] BPE encode/decode round-trip passes.
- [ ] Cyclic generation terminates within the configured bound.
- [ ] Existing P3 String recall and codebook benchmarks remain green.

## Phase 4 completion criteria

Phase 4 is complete when a persisted BPE tokenizer produces context-bound
wavefronts, the AIE routes ambiguous tokens through distinct learned paths,
and the bounded generation API returns decoded text while safely terminating
on EOS, maximum length, missing successors, or a detected cycle.

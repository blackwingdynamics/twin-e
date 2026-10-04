# Context Ambiguity Routing Evidence

This fixture trains two ordered contexts with the same current token and
different preceding tokens. Each context receives a separate sparse code and
is connected to a different successor state.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-context-ambiguity.aie \
  benchmarks/aie_context_ambiguity.act
/tmp/twin-e-context-ambiguity.aie
```

## Recorded result

```text
AIE_CONTEXT_AMBIGUITY contexts=2 successors=2 isolated=1
```

The fixture verifies that the two context neurons are distinct, that their
TokenBinding sidecar entries resolve each `(token_id, context_key)` pair back
to its correct arena slot. The public context runtime step resolves both
identities through the sidecar and fires the matching source columns. Their
first axon destinations are different successor columns, and both context and
successor wavefronts fire successfully.
The strict executable build also passes the zero-floating-point IR audit.

This proves bounded context-specific source routing. It does not yet implement
the full generation API or BPE vocabulary decoding.

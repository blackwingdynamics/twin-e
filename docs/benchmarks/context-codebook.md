# Context Codebook Collision Evidence

This benchmark generates 5,000 distinct ordered two-token contexts, hashes
each context, and maps the result through the deterministic sparse codebook.
It verifies both code cardinality and pairwise collision behavior.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-context-collision.ie \
  benchmarks/ie_context_collision.act
/tmp/twin-e-context-collision.ie
```

## Recorded result

```text
IE_CONTEXT_CODEBOOK contexts=5000 active_bits=8
IE_CONTEXT_CODEBOOK max_different_overlap=6
IE_CONTEXT_CODEBOOK duplicate_pairs=0
IE_CONTEXT_CODEBOOK invalid_code_count=0
```

The two-stage context hash and codebook preserve exactly eight active bits for
all sampled contexts. No different context pair reaches the exact-match
threshold of eight bits. The strict executable build also passes the
zero-floating-point IR audit.

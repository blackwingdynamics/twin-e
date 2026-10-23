# Bounded Context Key Evidence

The context probe verifies the first sequence-aware identity contract. A
context key combines one preceding token ID and one current token ID using a
versioned integer-only hash profile. The resulting key is then encoded through
the same 128-bit sparse codebook used by ordinary token IDs.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-context-probe.ie \
  benchmarks/ie_context_probe.act
/tmp/twin-e-context-probe.ie
```

## Recorded result

```text
IE_CONTEXT window=2 deterministic=1 distinct=1
```

The probe verifies that the same bounded context reproduces the same key and
that changing the preceding token changes both the key and the sparse code.
The native IR contains no floating-point instructions.

This is an identity contract, not yet context-aware IE routing. The next
step is to attach context keys to token bindings and verify that ambiguous
sequence transitions recall the correct bounded path.

# Associative Generation Evidence

This fixture builds two bounded context transitions. The first continuation
selects the strongest successor, emits one ordinary token followed by EOS, and
decodes the generated sequence through the BPE facade. A second fixture creates
a cyclic transition graph and verifies that the recent-column history guard
stops it after three generated tokens.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-generation.aie \
  benchmarks/aie_generation.act
/tmp/twin-e-generation.aie
```

## Recorded result

```text
AIE_GENERATION generated=2 decoded_bytes=1 termination=eos cycle_generated=3 loop_guard=1 selected=highest_myelination
AIE_GENERATION generation_ns=<machine-dependent>
```

The generation API is bounded by the caller's maximum token count and the
configured recent history size. It follows learned context-bound edges and
does not perform vocabulary-wide probability estimation or infer unseen edges.

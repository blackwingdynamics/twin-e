# TokenBinding Layout Evidence

This probe verifies the explicit binary contract for the position-independent
token/context sidecar entry described by ADR-0002.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-binding-probe.aie \
  benchmarks/aie_binding_probe.act
/tmp/twin-e-binding-probe.aie
```

## Recorded result

```text
AIE_BINDING bytes=24 context_offset=8 verified=1
```

The probe writes representative values into the packed fields and verifies
their little-endian bytes in the backing storage. The native build also passes
the zero-floating-point IR audit.

This establishes the layout contract. It does not yet serialize a sidecar
array with a `.brain` fabric snapshot; that is the next P4.1 step.

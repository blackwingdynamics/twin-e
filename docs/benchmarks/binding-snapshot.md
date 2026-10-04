# TokenBinding Sidecar Snapshot Evidence

This probe verifies that the 24-byte `TokenBinding` entries can be serialized
into a position-independent sidecar payload and restored into a fresh binding
array.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-binding-snapshot.aie \
  benchmarks/aie_binding_snapshot.act
/tmp/twin-e-binding-snapshot.aie
```

## Recorded result

```text
AIE_BINDING_SNAPSHOT slot=3 roundtrip=1 context_offset=8
```

The probe verifies the sidecar header/version contract, restores a populated
slot, and checks the little-endian bytes at the absolute snapshot offset
`3 * 24 + 8 = 80` for its context key. The strict executable build also
passes the zero-floating-point IR audit.

The existing fabric-only `.brain` snapshot API remains unchanged. Combining
fabric and binding snapshots into the final text snapshot wrapper is the next
integration step.

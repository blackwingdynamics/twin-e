# Combined Text Snapshot Evidence

This probe verifies that the AIE fabric state and the TokenBinding sidecar can
be serialized into one `TextSnapshot` and restored together.

## Command

```text
actus build --strict --emit exe \
  -o /tmp/twin-e-text-snapshot.aie \
  benchmarks/aie_text_snapshot.act
/tmp/twin-e-text-snapshot.aie
```

## Recorded result

```text
AIE_TEXT_SNAPSHOT fabric=1 bindings=1 roundtrip=1
```

The probe restores fabric active count, payload, and myelination together with
the selected token ID, context key, and binding flags. The strict executable
build also passes the zero-floating-point IR audit.

The snapshot currently uses the fixed 64-column fabric contract. Generic arena
snapshot sizing and incompatible profile rejection remain separate tasks.

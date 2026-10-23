# Phase 11.8 latency boundaries

## Scope

This benchmark reports adapter, admission, routing, teaching, flush
completion, and publication as separate measurements. Adapter, admission,
routing, teaching, and flush completion run in memory. Publication measures
the explicit save boundary that writes the shard and then the manifest; it is
not included in teaching latency.

## Command

```sh
actus fmt --check benchmarks/ie_logical_latency.act
actus build --strict --emit exe \
  -o /tmp/twin-e-gate-11-8-latency \
  benchmarks/ie_logical_latency.act
/tmp/twin-e-gate-11-8-latency
```

Host: Arch Linux, x86_64, Linux `7.2.9-arch1-1`.
Executable SHA-256:
`33be1193a135073877ed32474815ab34737bb731cc1b888d55bbe2bda56cef37`.
The strict build reported that generated native IR contains no floating-point
instructions.

## Observed output

```text
IE_LOGICAL_LATENCY adapter_ns=15536
 admission_ns=1450
 routing_ns=109
 teaching_ns=97367
 flush_ns=163
 publication_ns=8159089
```

`flush_ns` is the resident dirty-state completion boundary supplied with a
successful caller result; it does not pretend that disk I/O happened there.
`publication_ns` is the separate filesystem-backed shard and manifest save.
These are one host run and are not fixed cycle or hardware claims.

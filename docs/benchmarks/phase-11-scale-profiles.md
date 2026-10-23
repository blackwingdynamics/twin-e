# Phase 11.8 scale profiles

## Scope

This benchmark measures the canonical logical-brain facade at the one-shard,
two-shard, and configured-maximum profiles. It restores validated in-memory
descriptors only; it does not perform filesystem I/O or claim persistence,
training, or hardware performance.

## Command

```sh
actus fmt --check benchmarks/ie_logical_scale_profiles.act
actus build --strict --emit exe \
  -o /tmp/twin-e-gate-11-8-scale \
  benchmarks/ie_logical_scale_profiles.act
/tmp/twin-e-gate-11-8-scale
```

Host: Arch Linux, x86_64, Linux `7.2.9-arch1-1`.
Executable SHA-256:
`b4192449028f0dc71c64683757accb8ce93cbc66a379a17559537d351eb0f10d`.
The strict build reported that generated native IR contains no floating-point
instructions.

## Observed output

```text
IE_LOGICAL_SCALE profile=one shards=1
 logical_columns=1024
 resident_capacity=4
 binding_capacity=1024
 auxiliary_capacity=8
 restore_ns=1025

IE_LOGICAL_SCALE profile=two shards=2
 logical_columns=2048
 resident_capacity=4
 binding_capacity=1024
 auxiliary_capacity=8
 restore_ns=362

IE_LOGICAL_SCALE profile=maximum shards=8
 logical_columns=8192
 resident_capacity=4
 binding_capacity=1024
 auxiliary_capacity=8
 restore_ns=376
```

The first Gate 11.8 checkbox is therefore supported: the one-, two-, and
configured-maximum logical profiles all restore successfully through the same
bounded facade. The latency values are one host run and are not fixed cycle or
hardware claims.

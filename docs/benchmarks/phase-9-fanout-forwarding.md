# Phase 9 auxiliary fan-out forwarding benchmark

This benchmark measures the existing eight-target inline path separately from
the gated nine-target path that consults one auxiliary record. It does not
measure filesystem persistence, allocation setup, or hardware performance.

## Command

```text
actus fmt --check benchmarks/ie_fanout_forwarding.act
actus check --strict benchmarks/ie_fanout_forwarding.act
actus build --strict --emit exe \
  -o /tmp/twin-e-fanout-forwarding.ie \
  benchmarks/ie_fanout_forwarding.act
/tmp/twin-e-fanout-forwarding.ie
```

Compiler profile: Actus strict hosted build with Cranelift on the local
`x86_64-unknown-linux-gnu` host. The native verification reported no
floating-point instructions.

## Result

```text
IE_FANOUT_FORWARDING iterations=10000 inline_targets=8 overflow_targets=9
IE_FANOUT_FORWARDING inline_only_ns=1414118
IE_FANOUT_FORWARDING overflow_ns=1581395
```

The overflow fixture took 167,277 ns more for 10,000 calls, approximately
11.8% above the inline-only fixture. This is a hosted prototype measurement,
not a hardware or production-performance claim. The fixture confirms separate
measurement boundaries; capacity-failure and memory-accounting evidence remain
separate gates.

## Capacity and traversal evidence

The same strict executable also reports the bounded-state and failure
contracts:

```text
IE_FANOUT_FORWARDING auxiliary_serialized_bytes=456
IE_FANOUT_FORWARDING auxiliary_record_capacity=8
IE_FANOUT_FORWARDING traversal_order_verified=1
IE_FANOUT_FORWARDING exhaustion_rejection_verified=1
```

The 456 bytes are the fixed auxiliary source directory, eight 40-byte records,
and the free-list/active-count metadata. `traversal_order_verified=1` confirms
inline targets are observed first and the auxiliary target follows; the
exhaustion metric confirms the ninth auxiliary record is rejected without
changing the bounded table. Repeated timing samples vary with host scheduling,
so the nanosecond values are evidence for separate measurement boundaries, not
a universal performance promise.

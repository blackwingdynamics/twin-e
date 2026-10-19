# Phase 9 auxiliary fan-out forwarding benchmark

This benchmark measures the existing eight-target inline path separately from
the gated nine-target path that consults one auxiliary record. It does not
measure filesystem persistence, allocation setup, or hardware performance.

## Command

```text
actus fmt --check benchmarks/aie_fanout_forwarding.act
actus check --strict benchmarks/aie_fanout_forwarding.act
actus build --strict --emit exe \
  -o /tmp/twin-e-fanout-forwarding.aie \
  benchmarks/aie_fanout_forwarding.act
/tmp/twin-e-fanout-forwarding.aie
```

Compiler profile: Actus strict hosted build with Cranelift on the local
`x86_64-unknown-linux-gnu` host. The native verification reported no
floating-point instructions.

## Result

```text
AIE_FANOUT_FORWARDING iterations=10000 inline_targets=8 overflow_targets=9
AIE_FANOUT_FORWARDING inline_only_ns=1414118
AIE_FANOUT_FORWARDING overflow_ns=1581395
```

The overflow fixture took 167,277 ns more for 10,000 calls, approximately
11.8% above the inline-only fixture. This is a hosted prototype measurement,
not a hardware or production-performance claim. The fixture confirms separate
measurement boundaries; capacity-failure and memory-accounting evidence remain
separate gates.

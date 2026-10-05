# Phase 5 `.brain` Bounds Benchmark

This benchmark verifies that truncated and oversized combined `.brain` files
are rejected before live fabric or binding state changes.

## Command

```sh
actus build --strict --emit exe -o /tmp/twin-e-p5-brain-bounds.aie benchmarks/aie_text_brain_bounds.act
/tmp/twin-e-p5-brain-bounds.aie
```

## Recorded result

```text
built `/tmp/twin-e-p5-brain-bounds.aie` (strict)
verified generated native IR: no floating-point instructions
AIE_P5_BRAIN_BOUNDS truncated_rejected=1 oversized_rejected=1 unchanged=1
```

The fixture runs on the host and uses the same public `write_text_brain` and
`read_text_brain` APIs as the runtime. It does not claim process-restart
recovery or hardware behavior.

# AIE Phase 3 Roadmap

Phase 3 turns the verified AIE core into an observable, callable, and
measurable runtime package.

**Current status:** `[~] Partially complete` — P3.1, P3.2, P3.3, and the
initial P3.6 tokenizer/codebook foundation are implemented. P3.4, P3.5, and
the remaining language-input evidence continue alongside Phase 4.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## Scope

Phase 3 covers the public engine API, an executable demonstration, performance
measurements, and compiler/LSP parity for the package-level configuration
facade.

## P3.1 — Real engine API

- [x] Define the public input API for submitting one `Wavefront` to an active
  frontier.
- [x] Define the public result type for fired columns, emitted payloads, and
  propagated destinations.
- [x] Add one bounded step function that evaluates, forwards, and applies local
  plasticity for a single wavefront.
- [x] Add a bounded clock-step API for homeostatic decay and inhibition reset.
- [x] Expose neurogenesis through the public facade with explicit allocation
  failure behavior.
- [x] Document ownership roles, mutation boundaries, index validity, and side
  effects for every public verb.
- [x] Add tests for one complete wavefront lifecycle from input to emitted
  payload.
- [x] Add tests for no-free-slot and invalid-index behavior.

P3.1 evidence: `step_wavefront`, `engine_clock_step`, and `neurogenesis` are
exported through the AIE facade. The strict suite contains 15 passing tests,
including public lifecycle, no-free-slot, and invalid-index coverage.

## P3.2 — Observable executable demo

- [x] Add a small integer-only demo scenario in the package entry workflow.
- [x] Demonstrate a column firing from a matching 128-bit wavefront.
- [x] Demonstrate lateral inhibition on a configured neighbor.
- [x] Demonstrate neurogenesis and axon attachment for a novel wavefront.
- [x] Demonstrate decay and free-list reclamation after idle ticks.
- [x] Expose deterministic exit status for success and failure cases.
- [x] Document the exact command and expected observable result.
- [x] Keep demo output independent of raw pointers, floating point, and host
  specific memory addresses.

P3.2 evidence: build and run the package entry with `actus build --strict
--emit exe -o /tmp/twin-e-p3-2-final.aie` produced the following output and
exit code `0`:

```text
AIE_DEMO firing payload=41 destination=2 inhibition=1
AIE_DEMO neurogenesis linked=1
AIE_DEMO decay reclaimed=1
AIE_DEMO complete
```

The output directly reports firing and payload propagation, lateral
inhibition, novel-column linking, and decay reclamation.

## P3.3 — Performance baseline

- [x] Define a reproducible benchmark fixture for 128-bit coincidence scoring.
- [x] Measure software population count throughput for representative masks.
- [x] Measure eight-axon forwarding throughput.
- [x] Measure O(1) allocation and deallocation through the free list.
- [x] Measure a complete wavefront step over a fixed arena size.
- [x] Record compiler version, target, optimization profile, arena size, and
  benchmark input data with every result.
- [ ] Add a regression threshold for accidental floating point or allocation
  regressions where the compiler exposes stable evidence.
- [x] Keep benchmark results separate from correctness tests.

P3.3 evidence: `benchmarks/aie_p3_3.act` builds with strict checking and the
zero-float IR audit, then exits with status `0`. A 10,000-iteration debug-host
run is recorded in `docs/benchmarks/p3-3.md` with the compiler digest, target,
profile, arena size, input masks, and elapsed nanosecond measurements.

## P3.4 — Compiler and LSP parity

- [ ] Verify `src/config/config.act` and `src/config/values.act` through the
  package facade in `actus check --strict`.
- [ ] Verify package constants imported by nested AIE modules during native
  object emission.
- [ ] Verify package constants imported by nested AIE modules during native
  executable emission.
- [ ] Verify constant use in scalar initializers, predicates, case guards, and
  aggregate literals.
- [ ] Add rejected compiler tests for private configuration declarations and
  direct child-module bypasses.
- [ ] Add LSP diagnostics, hover, definition, and semantic-token coverage for
  configuration constants.
- [ ] Verify formatter stability for the configuration facade and values file.
- [ ] Verify `actus test` compiles configuration modules without requiring
  runtime verbs in the configuration source.

## P3.5 — Configuration completion

- [ ] Move all runtime policy values into `src/config/values.act`.
- [ ] Keep binary layout offsets and fixed storage widths in their pack and
  serialization contracts.
- [ ] Add named constants for any new protocol or policy value before using it
  in runtime code.
- [ ] Add a configuration regression test for every public policy group.
- [ ] Document which settings are compile-time Actus constants and which belong
  in `Actus.toml`.

## P3.6 — Tokenizer and sparse codebook foundation

- [x] Add canonical tokenizer and encoding facades under `src/`.
- [x] Add a versioned byte-token transition contract.
- [x] Route a String input through tokenizer, codebook, Wavefront, and AIE
  recall.
- [x] Add a deterministic bounded context-key contract and probe.
- [x] Add a deterministic integer-only 128-bit token code encoder.
- [x] Add a 5,000-code pairwise collision benchmark.
- [x] Verify eight unique active bits per generated code.
- [x] Add overlap histogram and candidate threshold false-fire counts.
- [x] Record initial collision evidence and its limits.
- [ ] Implement persisted subword vocabulary and merge rules.
- [ ] Add overlap distribution, threshold sweep, and noisy recall evidence.
- [~] Add bounded context keys for sequence disambiguation; identity contract
  exists, but context-aware routing is still pending.

P3.6 evidence: the tokenizer and encoding probes pass strict checking. The
collision executable reports `max_different_overlap=6`,
`duplicate_pairs=0`, and `invalid_code_count=0` for token IDs `0..4999`; see
`docs/benchmarks/codebook-collision.md`.

## Acceptance criteria

Phase 3 is complete when:

- [ ] A caller can submit a wavefront through the public AIE API and observe a
  deterministic firing result.
- [ ] The executable demo shows firing, inhibition, neurogenesis, decay, and
  reclamation.
- [ ] Correctness tests and performance benchmarks are reproducible on the
  declared host target.
- [ ] Strict check, object build, executable build, executable run, and
  zero-float IR verification pass after the API and configuration changes.
- [ ] Package configuration works through semantic analysis, native lowering,
  test execution, formatter, and LSP tooling.
- [ ] All public APIs and configuration contracts have English Actus
  documentation.

## Evidence to record

- Compiler binary path and digest.
- `actus fmt --check` result.
- `actus check --strict` result.
- Full test count and result.
- Object and executable build results.
- Executable exit status and captured demo output.
- Zero-float IR audit result.
- Benchmark command, fixture, target, and measured results.

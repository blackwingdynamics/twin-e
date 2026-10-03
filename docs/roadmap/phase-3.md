# AIE Phase 3 Roadmap

Phase 3 turns the verified AIE core into an observable, callable, and
measurable runtime package.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## Scope

Phase 3 covers the public engine API, an executable demonstration, performance
measurements, and compiler/LSP parity for the package-level configuration
facade.

## P3.1 — Real engine API

- [ ] Define the public input API for submitting one `Wavefront` to an active
  frontier.
- [ ] Define the public result type for fired columns, emitted payloads, and
  propagated destinations.
- [ ] Add one bounded step function that evaluates, forwards, and applies local
  plasticity for a single wavefront.
- [ ] Add a bounded clock-step API for homeostatic decay and inhibition reset.
- [ ] Expose neurogenesis through the public facade with explicit allocation
  failure behavior.
- [ ] Document ownership roles, mutation boundaries, index validity, and side
  effects for every public verb.
- [ ] Add tests for one complete wavefront lifecycle from input to emitted
  payload.
- [ ] Add tests for no-free-slot and invalid-index behavior.

## P3.2 — Observable executable demo

- [ ] Add a small integer-only demo scenario in the package entry workflow.
- [ ] Demonstrate a column firing from a matching 128-bit wavefront.
- [ ] Demonstrate lateral inhibition on a configured neighbor.
- [ ] Demonstrate neurogenesis and axon attachment for a novel wavefront.
- [ ] Demonstrate decay and free-list reclamation after idle ticks.
- [ ] Expose deterministic exit status for success and failure cases.
- [ ] Document the exact command and expected observable result.
- [ ] Keep demo output independent of raw pointers, floating point, and host
  specific memory addresses.

## P3.3 — Performance baseline

- [ ] Define a reproducible benchmark fixture for 128-bit coincidence scoring.
- [ ] Measure software population count throughput for representative masks.
- [ ] Measure eight-axon forwarding throughput.
- [ ] Measure O(1) allocation and deallocation through the free list.
- [ ] Measure a complete wavefront step over a fixed arena size.
- [ ] Record compiler version, target, optimization profile, arena size, and
  benchmark input data with every result.
- [ ] Add a regression threshold for accidental floating point or allocation
  regressions where the compiler exposes stable evidence.
- [ ] Keep benchmark results separate from correctness tests.

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

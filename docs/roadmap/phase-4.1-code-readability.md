# Phase 4.1 — Readable Production Code

## Objective

Make the AIE source easier to read, review, extend, and operate without changing
its observable behavior. This phase applies the current Actus language surface
to the existing engine and persistence code. Every refactor must preserve the
current public contracts, binary layouts, ownership rules, and test behavior.

The result must look like maintained production software: a new contributor
should be able to identify the purpose, inputs, outputs, invariants, failure
paths, and ownership behavior of each public operation from the source.

## Scope

- `src/aie/`
- `src/tokenizer/`
- `src/encoding/`
- `src/config/`
- Relevant AIE tests and public documentation

This phase does not change the binary snapshot format, minicolumn layout,
token code contract, persistence protocol, or runtime semantics unless a
separate approved design decision is recorded first.

## Gates

### Gate 1 — Baseline and inventory

- [ ] Record the current branch, commit, compiler revision, and test result.
- [ ] Inventory functions longer than the repository's configured source limit.
- [ ] Inventory repeated blocks, repeated scalar temporaries, and repeated
      field or axon handling.
- [ ] Identify public facades and confirm that every implementation remains
      reachable through its canonical parent facade.
- [ ] Mark every planned refactor with the behavior it must preserve.

### Gate 2 — Module and responsibility boundaries

- [ ] Group source files by one clear responsibility: layout, runtime state,
      selection, generation, persistence, encoding, tokenization, or config.
- [ ] Keep public declarations in canonical facade files.
- [ ] Keep implementation helpers private unless an external module needs them.
- [ ] Remove imports that bypass a parent facade.
- [ ] Confirm that module movement does not create cycles or duplicate exports.
- [ ] Run strict module and facade checks after each boundary change.

### Gate 3 — Actus syntax modernization

- [ ] Replace statement-form `if` constructs that use an empty `else` with the
      supported statement-form guard syntax.
- [ ] Use `case` for typed result branching where it makes success and failure
      paths clearer.
- [ ] Use bounded `for` or `repeat` constructs where they improve readability
      without hiding fixed-size engine work.
- [ ] Preserve explicit ownership roles on every binding and argument.
- [ ] Preserve explicit integer widths and typed literals.
- [ ] Keep value-producing conditional expressions distinct from statement
      guards and require compatible value branches.

### Gate 4 — Repeated logic reduction

- [ ] Replace repeated axon, candidate, descriptor, or byte handling with
      bounded helpers or supported loops where the generated code remains
      deterministic.
- [ ] Do not introduce dynamic allocation into the impulse hot path.
- [ ] Do not replace fixed-size data with hidden pointers or unbounded
      collections.
- [ ] Keep tie-breaking, bounds checks, ownership transitions, and cleanup
      behavior explicit.
- [ ] Add regression tests for every helper that replaces repeated logic.

### Gate 5 — Production documentation and comments

- [ ] Add an Actus documentation block (`""" ... """`) to every public facade,
      public struct, public enum, and public verb.
- [ ] Each public verb documentation block states its purpose, inputs, outputs,
      ownership behavior, invariants, and failure behavior where applicable.
- [ ] Use `#` for short implementation comments; do not use Rust-style `//` or
      `///` comments in Actus source.
- [ ] Explain why a non-obvious branch, bound, offset, checksum step, or
      ownership transfer exists.
- [ ] Keep comments synchronized with the implementation and avoid comments
      that merely restate the next line of code.
- [ ] Ensure comments and documentation are excluded from source-limit counts
      according to the compiler contract.

### Gate 6 — Readability review

- [ ] Every touched function has one clear responsibility.
- [ ] Names describe domain meaning rather than temporary implementation shape.
- [ ] Nested control flow is bounded and easy to follow.
- [ ] Error propagation is visible at the point where it occurs.
- [ ] No unexplained numeric protocol value remains in touched code when a
      configuration constant or named layout constant is available.
- [ ] No empty `else` exists solely to satisfy the compiler.
- [ ] Review the diff manually for readability before running the final suite.

### Gate 7 — Behavioral and performance safety

- [ ] `actus fmt --check` passes for all touched Actus files.
- [ ] `actus check --strict` passes.
- [ ] `actus test --strict` passes with no filtered failures.
- [ ] Snapshot round-trip and corrupted-input tests pass.
- [ ] Public API lifecycle tests pass.
- [ ] No floating-point instructions are introduced into the engine build.
- [ ] Hot-path benchmarks remain within the established baseline or record and
      explain any measured change.
- [ ] The refactor does not add synchronous disk I/O to inference or
      neurogenesis hot paths.

### Gate 8 — Completion evidence

- [ ] Update this document with completed gates and the final commit reference.
- [ ] Record the exact compiler binary revision used for validation.
- [ ] Record strict check, test, benchmark, and zero-float evidence.
- [ ] Confirm that the working tree contains only intended changes.
- [ ] Create a focused commit with a message describing the completed
      readability work.

## Acceptance Criteria

Phase 4.1 is complete when all gates are checked, the public behavior and
binary contracts remain unchanged, the source is reviewed as readable by a
human contributor, production comments cover the public surface, and the full
strict validation suite passes.

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

- [x] Record the current branch, commit, compiler revision, and test result.
- [x] Inventory functions longer than the repository's configured source limit.
- [x] Inventory repeated blocks, repeated scalar temporaries, and repeated
      field or axon handling.
- [x] Identify public facades and confirm that every implementation remains
      reachable through its canonical parent facade.
- [x] Mark every planned refactor with the behavior it must preserve.

#### Gate 1 evidence

Baseline captured on branch `phase-4.1-gate-1-baseline` from commit
`bf5a414e57dfdd2dcf70fded0a32a4b9c9ecf3cc`.

- Actus compiler revision: `5bd8ae069922bf54e85ee3b8644e2f680a202a2f`.
- Installed compiler and release compiler SHA-256:
  `06f57a5cb7b7c6ba52d33a092032d53c7608700cc04ec378fbaadbba1f903074`.
- Source inventory: 42 `.act` files and 4,374 nonblank source lines.
- `actus lock --check`: passed.
- `actus check --strict`: passed.
- `actus test --strict`: 16 passed, 0 failed.

The configured conformance thresholds are 300 preferred file lines, 400
split-required file lines, 500 hard file lines, 30 preferred function lines,
40 split-required function lines, and 60 hard function lines.

The current function inventory above the preferred 30-line threshold is:

| File | Verb | Lines |
| --- | --- | ---: |
| `src/aie/persistence/file.act` | `read_brain_bytes` | 34 |
| `src/aie/persistence/shard.act` | `write_shard` | 57 |
| `src/aie/persistence/shard.act` | `read_shard_bytes` | 50 |
| `src/aie/persistence/shard.act` | `write_dynamic_shard` | 62 |
| `src/aie/persistence/shard.act` | `write_dynamic_shard_with_bindings` | 76 |
| `src/aie/persistence/shard.act` | `dynamic_shard_with_bindings_is_valid` | 42 |
| `src/aie/persistence/shard.act` | `dynamic_shard_bytes_are_valid` | 41 |
| `src/aie/persistence/shard.act` | `load_dynamic_shard_bytes` | 35 |
| `src/aie/runtime/coincidence.act` | `evaluate_minicolumn_core` | 41 |
| `src/aie/runtime/fabric.act` | `fabric_init_core` | 34 |
| `src/aie/runtime/forwarding.act` | `forward_group_a` | 31 |
| `src/aie/runtime/forwarding.act` | `forward_group_b` | 31 |
| `src/aie/runtime/forwarding.act` | `evaluate_active_source` | 34 |
| `src/aie/runtime/forwarding.act` | `forward_step_destinations` | 80 |
| `src/aie/runtime/generation.act` | `generate_associative_core` | 79 |
| `src/aie/runtime/neurogenesis.act` | `link_first_four` | 31 |
| `src/aie/runtime/neurogenesis.act` | `link_last_four` | 31 |
| `src/tokenizer/bpe.act` | `find_best_merge` | 32 |
| `src/tokenizer/bpe.act` | `bpe_decode_bytes` | 53 |
| `src/tokenizer/byte.act` | `tokenize_string` | 36 |

The primary file-level decomposition targets are:

- `src/aie/persistence/shard.act` — 640 physical lines, with serialization,
  validation, checksum, publication, and loading responsibilities mixed in one
  implementation boundary.
- `src/aie/runtime/forwarding.act` — 414 physical lines, with repeated fixed
  axon-slot forwarding and public step orchestration in one file.
- `src/tokenizer/bpe.act` — 305 physical lines, with vocabulary validation,
  merge selection, encoding, special-token handling, and decoding together.

The inventory also identified repeated logic that Gate 4 must address:

- fixed axon slot access and forwarding for slots 0 through 7;
- first-four and last-four axon linking in neurogenesis;
- repeated little-endian append/read operations across snapshot, shard, and
  manifest persistence;
- repeated descriptor and header validation expressions;
- repeated token sequence copying and bounded merge traversal.

The canonical public facades identified for preservation are:

- `src/aie/layout/layout.act`
- `src/aie/runtime/runtime.act`
- `src/aie/persistence/persistence.act`
- `src/aie/persistence/manifest/manifest.act`
- `src/aie/persistence/manifest/fixed/fixed.act`
- `src/aie/persistence/manifest/dynamic_manifest/dynamic_manifest.act`
- `src/config/config.act`
- `src/encoding/encoding.act`
- `src/tokenizer/tokenizer.act`

Planned refactors must preserve fixed binary offsets and widths, public facade
paths, ownership roles, checksum and validation behavior, deterministic axon
selection, bounded storage, and the current 16-test strict AIE baseline.

The standalone `actus conformance --strict` command currently reports a source
root scan error before producing a report. This is recorded as a tooling issue
for Gate 7; it does not invalidate the source inventory above.

### Gate 2 — Module and responsibility boundaries

- [x] Group source files by one clear responsibility: layout, runtime state,
      selection, generation, persistence, encoding, tokenization, or config.
- [x] Keep public declarations in canonical facade files.
- [x] Keep implementation helpers private unless an external module needs them.
- [x] Remove imports that bypass a parent facade.
- [x] Confirm that module movement does not create cycles or duplicate exports.
- [x] Run strict module and facade checks after each boundary change.

#### Gate 2 evidence

The boundary audit preserved public behavior and identified the existing
canonical facade structure for each public subsystem:

- `src/aie/aie.act` exports layout, runtime, and persistence through the AIE
  package facade.
- `src/aie/layout/layout.act` exports packed layout types.
- `src/aie/runtime/runtime.act` exports runtime state, selection, forwarding,
  context, neurogenesis, decay, and generation operations.
- `src/aie/persistence/persistence.act` exports serialization, file, shard,
  manifest, and cache operations.
- `src/aie/persistence/manifest/manifest.act` owns the manifest facade and
  exports its fixed and dynamic implementations through child facades.
- `src/aie/persistence/manifest/fixed/fixed.act` and
  `src/aie/persistence/manifest/dynamic_manifest/dynamic_manifest.act` keep
  their respective manifest implementations behind dedicated child facades.
- `src/config/config.act`, `src/encoding/encoding.act`, and
  `src/tokenizer/tokenizer.act` are the canonical facades for package-wide
  configuration, sparse encoding, and tokenization.

The import audit found no implementation import that bypasses these package
boundaries for a sibling public API. Direct imports of `config`, `std::fs`, and
`std::io` remain limited to modules that require those dependencies directly;
the corresponding domain APIs remain exported through their parent facades.
Implementation helpers remain private, while declarations marked `open` are
the intentional re-export surface required by the facade chain.

`actus check --strict` passed successfully after the audit. The compiler found
no module cycle, duplicate facade export, unresolved import, or invalid public
reachability.

As the readability work progressed, the oversized shard implementation was
split behind the same public `persistence::shard` facade. Its responsibilities
now live in `shard/shard.act`, `shard/codec.act`, `shard/fixed.act`,
`shard/dynamic_io.act`, `shard/dynamic_writer.act`,
`shard/dynamic_writer_core.act`, `shard/dynamic_bindings.act`,
`shard/dynamic_checksum.act`, and `shard/dynamic_validation.act`. The public
facade path and binary shard contract remain unchanged.

The oversized manifest generation implementation was also split behind the
existing `persistence::manifest::generation` facade. Its responsibilities now
live in `generation/generation.act`, `generation/codec.act`,
`generation/extension.act`, and `generation/selection.act`. The split keeps
manifest extension, selection, and encoding responsibilities separate without
changing the serialized format or public API.

Both decomposition groups are formatter-clean and satisfy strict source and
function limits. The full native strict suite now passes with 16 tests and 0
failures after the refactor. Gate 4 still tracks repeated domain operations that
are intentionally fixed-size or require a separate API decision.

The forwarding implementation is now split behind the same
`runtime::forwarding` facade. `forwarding/slots.act` owns bounded indexed
propagation over the eight-slot packed axon array, while `forwarding/step.act`
owns public wavefront-step orchestration. `forwarding/forwarding.act` is the
only child facade exposed to the runtime facade. The packed axon storage keeps
the original byte offsets while runtime access uses checked indexes.

The tokenizer BPE implementation is also split behind the existing tokenizer
facade. `bpe/types.act` owns vocabulary and token record types,
`bpe/merge.act` owns bounded merge selection and application, and
`bpe/api.act` owns public tokenization and decoding operations. The serialized
vocabulary contract and public tokenizer API remain unchanged.

The runtime generation implementation is split behind the existing
`runtime::generation` facade. `generation/history.act` owns the bounded
repetition history, `generation/selection.act` owns successor validation and
deterministic selection, and `generation/core.act` owns generation
orchestration. Successor selection reads the packed axon array through checked
indexed access.

### Gate 3 — Actus syntax modernization

- [ ] Replace statement-form `if` constructs that use an empty `else` with the
      supported statement-form guard syntax.
- [ ] Use `case` for typed result branching where it makes success and failure
      paths clearer.
- [ ] Use bounded `for` or `repeat` constructs where they improve readability
      without hiding fixed-size engine work.
- [ ] Preserve explicit ownership roles on every binding and argument.
- [ ] Preserve explicit integer widths and typed literals.

#### Current evidence

- [x] Audited `src/`, `benchmarks/`, and `tests/` for empty statement-form
      `else` blocks; none remain after the benchmark cleanup.
- [x] `actus check --strict` and `actus test --strict` pass after this cleanup
      with 16 tests passed and 0 failures.
- [x] Removed unnecessary file-level `limitless` exceptions from the small
      tokenizer, coincidence, and fixed snapshot files.
- [x] Split the snapshot reader, coincidence state update, and byte tokenizer
      helpers where strict function-size validation required clearer
      responsibilities.
- [x] Added an explicit `src/aie/api.act` facade for dynamic shard write and
      publish operations so nested persistence declarations cross the package
      boundary through a canonical public API.

The remaining Gate 3 items are still open. In particular, the wider migration
to `case` and bounded iteration must be completed and reviewed independently.
- [ ] Keep value-producing conditional expressions distinct from statement
      guards and require compatible value branches.

### Gate 4 — Repeated logic reduction

- [x] Replace repeated axon, candidate, descriptor, or byte handling with
      bounded helpers or supported loops where the generated code remains
      deterministic.
- [x] Do not introduce dynamic allocation into the impulse hot path.
- [x] Do not replace fixed-size data with hidden pointers or unbounded
      collections.
- [x] Keep tie-breaking, bounds checks, ownership transitions, and cleanup
      behavior explicit.
- [x] Add regression tests for every helper that replaces repeated logic.

#### Gate 4 evidence

- [x] Replaced the eight scalar packed fields `axon_0..axon_7` with the
      fixed-width `axons: Array[u32, 8]` field at the same base offset.
- [x] Replaced forwarding, successor selection, initialization, free-list
      cleanup, and neurogenesis linking with checked indexed accesses or
      bounded loops.
- [x] Updated tests and benchmarks to exercise indexed packed axon access.
- [x] Snapshot tests continue to pass, proving that the 64-byte storage bytes
      and serialized offsets remain compatible.
- [x] `actus check --strict` passes and `actus test --strict` passes with
      16 tests and 0 failures after the migration.

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

#### Gate 5 progress

- [x] Documented the public layout and runtime declarations used by the
      impulse path: `Minicolumn`, `Wavefront`, `CorticalFabric`, allocation and
      free-list operations, coincidence evaluation, axon linking, and impulse
      forwarding.
- [x] Kept the documentation in Actus `""" ... """` blocks and preserved
      explicit ownership and failure behavior in the implementation.
- [x] Documented the public BPE vocabulary types, validation operation, and
      tokenization/decoding operations.
- [x] Expanded the core runtime and BPE documentation to state inputs,
      outputs, ownership roles, bounds, invariants, and failure behavior.
- [ ] Complete the same documentation audit for persistence, encoding, and
      remaining public facade declarations.

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

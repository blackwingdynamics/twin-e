# Twin-e Agent and Contribution Contract

This document is the repository-level operating contract for coding agents and
contributors working on Twin-e. It supplements `ACTUS_CODING_AGENT_GUIDE.md`.
The Actus guide is the source of truth for language syntax and compiler
semantics. This document defines how those rules are applied in this project.

## 1. Project purpose

Twin-e is an Actus implementation of a bounded, integer-only associative
engine. The project combines sparse token encoding, context binding, bounded
neuron state, deterministic impulse propagation, neurogenesis, decay, and
position-independent persistence.

The current implementation is a deterministic systems prototype. Do not make
claims about general intelligence, production hardware performance, or
large-scale learning unless the repository contains reproducible evidence for
the claim.

## 2. Repository boundaries

Work in this repository unless the task explicitly changes repository scope.

- `src/` contains package code and the configured `main` entry point.
- `src/ie/` contains the engine, layout, runtime, and persistence modules.
- `src/config/` contains package-wide protocol and policy constants.
- `src/encoding/` contains token, context, binding, and sparse codebook logic.
- `src/tokenizer/` contains byte tokenization and bounded BPE logic.
- `tests/` contains correctness and public API tests.
- `benchmarks/` contains executable benchmark and evidence fixtures.
- `docs/adr/` contains accepted architectural decisions.
- `docs/benchmarks/` contains reproducible benchmark instructions and results.
- `docs/roadmap/` contains phase plans and gate evidence.
- `capsula/` and native build output are local generated artifacts and are
  ignored by Git.

Do not modify `/home/magradze/Projects/actus_project/actus` while working on
Twin-e. Compiler work belongs to the Actus repository and requires an explicit
request to switch repository scope. If Twin-e exposes a compiler limitation,
record the exact diagnostic and stop at that boundary instead of inventing a
language workaround.

## 3. Non-negotiable engineering rules

1. Preserve observable behavior unless an ADR or the user explicitly approves
   a behavior change.
2. Do not silently delete, reset, revert, or replace user code or uncommitted
   work.
3. Do not use Rust, C, C++, pseudo-Actus, or undocumented future Actus syntax
   in `.act` source.
4. Do not hide a compiler limitation with an unrelated wrapper, duplicated
   implementation, or arbitrary `meta limitless` exception.
5. Do not add synchronous filesystem I/O to inference, impulse forwarding,
   neurogenesis, coincidence evaluation, or other hot paths.
6. Do not add floating-point state or operations to the engine.
7. Do not introduce raw operating-system pointers into serialized state or
   arena links.
8. Do not replace bounded fixed storage with dynamic collections, hidden
   allocation, or an unbounded iterator.
9. Do not claim that a build or test proves hardware behavior. Hardware claims
   require a reproducible target-specific measurement.
10. If a compiler error blocks a requested change, preserve the attempted code,
    report the exact error, and state whether compiler work is required.

## 4. Actus source contract

Follow `ACTUS_CODING_AGENT_GUIDE.md` before adding or changing Actus code.

### 4.1 Ownership and bindings

Every binding and parameter must declare its role:

- `erg`: mutable owner or mutable local state;
- `abs`: immutable shared view;
- `dat`: ownership transfer; the source binding is consumed;
- `ins`: exclusive call-scoped mutable loan.

Keep the role at the call site as well as in the declaration. Do not repair a
role error by copying an arena element or weakening a parameter role. Indexed
places should be mutated in place when the operation owns an `ins` loan.

### 4.2 Syntax and types

- Declare functions with `verb`.
- Use capitalized Actus types and explicit integer widths.
- Give numeric literals an explicit suffix such as `0u32`, `1u64`, or `0u8`.
- Conditions must produce `Bool`; implicit truthiness is forbidden.
- Use `case` for typed `Option` and `Result` branching when it makes ownership
  and success/failure paths visible.
- Use bounded `for` or `repeat` only when the fixed bound improves readability.
  Keep `loop` when early termination or stateful control flow is clearer.
- Keep value-producing `if` expressions separate from statement guards.
- Do not add `f32`, `f64`, floating-point literals, or floating-point APIs.

### 4.3 Layout and persistence invariants

- Minicolumn storage remains exactly 64 bytes with the established field offsets.
- Arena links are `u32` indexes; `NULL_INDEX` is the only unconnected sentinel.
- Binary formats are position-independent and little-endian as specified.
- Token bindings remain shard-local when persisted with shard state.
- Checksums, version fields, descriptor bounds, and generation rules must be
  validated before state is published.
- Persistence publication follows staged write, validation, rename/publish, and
  manifest update ordering. A failed or partial write must not become active.
- Move protocol constants into `src/config/values.act` when they are shared.
  Do not duplicate configuration values across implementation modules.

### 4.4 Module visibility

Every implementation must be reachable through its canonical parent facade.
Keep private helpers private unless a real external consumer needs the symbol.
When a public child module is required, export it through the canonical facade
and add a regression test for the import path.

Do not bypass a parent facade from benchmarks or tests. A nested-facade error is
a module visibility or compiler problem that must be fixed at the proper
boundary.

## 5. Documentation and readability

- Public facades, constants, structs, enums, packs, and verbs require an Actus
  `""" ... """` documentation block.
- Public verb documentation must explain purpose, inputs, outputs, ownership,
  invariants, side effects, allocation behavior, and failure behavior where
  applicable.
- Use `#` for short implementation comments. Never use `//`, `///`, or foreign
  language comment syntax in Actus source.
- Explain non-obvious offsets, bounds, checksum exclusions, ownership transfers,
  cleanup paths, and deterministic tie-breaking.
- Keep names domain-oriented. Names such as `descriptor_checksum_offset` and
  `destination_index` are preferred over `o4`, `tmp`, or `value2`.
- Keep functions and files below the configured source limits by decomposition.
  Treat `meta limitless` as an exceptional, documented decision for generated
  or otherwise justified code, not as a normal escape hatch.
- Preserve documentation while formatting. Triple-quoted documentation is
  measured source; it is not a source-limit bypass.

## 6. Change workflow

Before editing:

1. Read this file, `ACTUS_CODING_AGENT_GUIDE.md`, the relevant roadmap, and
   related ADRs.
2. Check `git status --short --branch` and preserve existing work.
3. Identify the canonical facade and the tests that cover the behavior.
4. State the invariant being preserved and the evidence needed to accept the
   change.

While editing:

1. Keep changes narrow and responsibility-oriented.
2. Prefer small thematic commits over one mixed refactor commit.
3. Do not change public APIs, serialized layouts, constants, or ownership roles
   as incidental cleanup.
4. Update the relevant roadmap or ADR when the design or accepted contract
   changes.
5. If a needed language feature is missing, stop and report the compiler
   change required. Do not silently rewrite the design around it.

After editing, run the narrowest relevant checks first, then the full project
checks before declaring completion.

## 7. Required validation

From the repository root, use the installed Actus compiler and record failures
with their complete diagnostics.

### Formatting

Check every touched `.act` file:

```sh
actus fmt --check path/to/file.act
```

The formatter may be run on the file first with `actus fmt path/to/file.act`.

### Package and tests

```sh
actus lock --check
actus check --strict
actus test --strict
```

The strict IE baseline is currently 16 tests with 0 failures. Snapshot
round-trip, corrupted input, public API lifecycle, free-list, coincidence,
inhibition, neurogenesis, and decay behavior must remain covered.

### Native and zero-float evidence

For engine changes, build a strict executable and retain the compiler's native
IR verification result:

```sh
actus build --strict --emit exe -o /tmp/twin-e-engine.ie
```

The output must confirm that no floating-point instructions are generated.
Run relevant executable benchmarks and record command, compiler digest, target,
profile, input size, and captured output in `docs/benchmarks/` or the roadmap.

### Hot-path audit

Before accepting runtime changes, inspect the changed call path for
`write_file`, file creation, rename/publish, filesystem reads, or other blocking
I/O. Persistence belongs behind explicit save/commit operations or background
work; inference and neurogenesis must continue in memory.

## 8. ADR and roadmap rules

Create or update an ADR before implementing a change that affects:

- public API or module visibility;
- ownership or cleanup semantics;
- binary layout, `.brain` format, shard manifests, checksums, or recovery;
- token/context encoding or generation behavior;
- compiler or language requirements;
- performance or hardware assumptions.

Roadmap gates are evidence gates, not intentions. Mark a checkbox only after
the implementation, tests, and documentation support it. Record known limits,
compiler versions, benchmark conditions, and unresolved follow-up work.

## 9. Branches, commits, and pull requests

### Branches

Use a focused branch named after the phase or task, for example:

```text
phase-4.2-context-generation
fix-manifest-recovery
refactor-public-facades
```

Do not work directly on `main` for implementation changes.

### Commit messages

Use Conventional Commit style with a narrow scope:

```text
feat: add bounded context generation
fix: reject truncated shard payloads
refactor: split manifest validation
docs: record phase evidence
test: cover corrupted manifest headers
perf: record impulse benchmark baseline
```

Each commit should represent one reviewable idea. Do not mix compiler changes,
engine behavior changes, formatting-only changes, and unrelated documentation
in one commit. Never create an empty commit to simulate progress.

### Pull requests

Every PR description must include:

1. What changed and why.
2. Which public, ownership, binary, or performance contracts are affected.
3. Tests and commands executed, including exact failures if any.
4. Benchmark output and conditions when performance is relevant.
5. Compiler changes required or explicitly ruled out.
6. Migration, rollback, or compatibility impact.

Do not merge while required checks are red. Do not describe a benchmark as a
hardware result unless it was measured on that hardware.

## 10. Stop conditions

Stop and report before continuing when:

- a requested change requires a compiler feature not present in the guide or
  tests;
- a public facade, ABI, ownership role, binary offset, or serialized format
  would need an unapproved change;
- a test failure cannot be explained from the changed code;
- a persistence operation would add synchronous hot-path I/O;
- a proposed workaround would duplicate protocol constants or bypass a facade;
- the working tree contains unexpected user changes;
- the task would require deleting or resetting work.

The report must include the exact file, compiler diagnostic or evidence, the
smallest requested compiler/project change, and what remains untouched.

## 11. Definition of done

A Twin-e change is complete only when:

- the implementation follows the Actus guide and this contract;
- public documentation and relevant ADR/roadmap entries are updated;
- touched sources are formatter-clean;
- strict checking and relevant tests pass;
- native builds retain the zero-float guarantee where applicable;
- benchmark or hardware claims include reproducible evidence;
- no unexplained hot-path I/O or ownership shortcut was introduced;
- the diff is reviewable and the commit message accurately describes it.

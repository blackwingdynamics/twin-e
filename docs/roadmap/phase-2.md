# AIE Phase 2 Roadmap

Phase 2 organizes the AIE source tree, establishes hierarchical Actus
facades, and centralizes package-level configuration.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## P2.1 — Source organization

- [x] Split the former engine implementation into coincidence, forwarding,
  neurogenesis, and decay modules.
- [x] Organize AIE modules under `layout/`, `runtime/`, and `persistence/`.
- [x] Add canonical directory facades for each nested module.
- [x] Keep `src/aie/aie.act` as the public AIE facade.
- [x] Add public documentation to the facade and public split modules.
- [~] Retain narrowly scoped `meta limitless("verb")` exceptions where the
  compiler source-limit contract still requires them.

## P2.2 — Package configuration

- [x] Create the package-level `src/config/config.act` facade.
- [x] Create `src/config/values.act` for typed compile-time constants.
- [x] Centralize AIE sentinel, flag, threshold, decay, and snapshot constants.
- [x] Replace duplicated runtime policy literals with named configuration
  constants.
- [x] Keep binary layout offsets and fixed storage widths in their owning pack
  and serialization contracts.
- [x] Add a package configuration regression test.
- [x] Verify configuration constants through nested AIE modules during native
  object and executable emission.

## P2.3 — Validation

- [x] `actus fmt --check` passes.
- [x] `actus check --strict` passes.
- [x] All AIE tests pass.
- [x] Native object emission passes.
- [x] Native executable emission passes.
- [x] Native executable runs with exit code `0`.
- [x] Zero-float IR verification passes.
- [x] Ignore generated `capsula/` compiler output through `.gitignore`.

## P2 acceptance criteria

Phase 2 is complete when:

- [x] AIE source responsibilities are separated into nested canonical modules.
- [x] Package-level configuration is available through `import config;`.
- [x] Runtime and serialization code use named policy and format constants.
- [x] The complete strict/native validation pipeline passes.

## Evidence

The final Phase 2 verification recorded:

```text
fmt --check: passed
check --strict: passed
test --strict: 11 passed, 0 failed
object build: passed
executable build: passed
executable run: exit_code=0
zero-float IR audit: passed
```

# Phase 6 — Embedded Cortex-M Execution (Deferred)

## Status

**Planned / Deferred.** This phase is recorded for continuity and future
planning. It is not a prerequisite for the current hosted Twin-e milestones
and must not interrupt Region, persistence, training, or hosted acceptance
work.

## Objective

Make the bounded Twin-e execution core deployable as a freestanding firmware
component on STM32 Cortex-M targets, including STM32F4 and STM32H7 class
boards, while preserving the integer-only execution model, bounded storage,
ownership rules, and deterministic behavior already validated on the hosted
target.

## Current boundary

The current Actus compiler and Twin-e package are validated on hosted x86-64.
The full hosted program depends on facilities such as process execution and
filesystem-backed `.brain` persistence. A Cortex-M firmware image requires a
separate freestanding target contract and cannot be claimed from hosted build
success alone.

Cranelift target support, linker integration, and the Actus runtime provider
for Cortex-M must be verified in the Actus repository before this phase can
start. No compiler limitation should be hidden by changing Twin-e source into
an undocumented workaround.

## Deferred gates

### Gate 6.1 — Cortex-M target contract

- [ ] Define the supported Cortex-M target triples and ABI requirements.
- [ ] Add a compiler diagnostic for unsupported Cortex-M targets instead of
      producing a misleading hosted executable.
- [ ] Confirm whether the selected native backend can emit the required
      Cortex-M instruction set and calling convention.
- [ ] Define the linker, startup, memory-region, and runtime-provider contract.
- [ ] Record the exact Actus compiler feature or backend work required.

### Gate 6.2 — Freestanding Twin-e core boundary

- [ ] Separate the bounded impulse and learning core from hosted filesystem,
      process, and console facilities.
- [ ] Define a target-neutral storage provider interface for resident state.
- [ ] Keep `.brain` persistence behind an explicit provider; do not add disk
      I/O to inference, forwarding, or neurogenesis hot paths.
- [ ] Preserve zero-float native IR and bounded memory invariants.
- [ ] Add a freestanding build fixture that does not import hosted services.

### Gate 6.3 — STM32 runtime provider

- [ ] Implement the minimal runtime provider required by the freestanding
      Twin-e core.
- [ ] Provide bounded time, buffer, storage, and diagnostic interfaces through
      explicit target contracts.
- [ ] Define Flash, SD, or external-storage persistence separately from the
      hosted filesystem implementation.
- [ ] Validate alignment, integer widths, stack use, and resident memory limits
      for the selected MCU.

### Gate 6.4 — Native firmware build

- [ ] Build a reproducible firmware image for one selected STM32 target.
- [ ] Inspect the linked image, memory map, undefined symbols, and startup
      contract.
- [ ] Verify that no hosted runtime or filesystem symbol leaks into firmware.
- [ ] Record compiler revision, backend, linker, optimization profile, and
      complete build commands.

### Gate 6.5 — Hardware evidence

- [ ] Flash the image to the selected board using a reproducible procedure.
- [ ] Verify startup, bounded impulse execution, training, and persistence
      provider behavior on the board.
- [ ] Measure latency, resident memory, stack high-water mark, storage timing,
      and power conditions.
- [ ] Repeat the zero-float and failure-path checks on the target artifact.
- [ ] Keep board measurements separate from hosted benchmark claims.

## Acceptance boundary

This phase is complete only when one Cortex-M target has a reproducible
freestanding firmware build and hardware evidence. Until then, Twin-e remains
correctly classified as a hosted x86-64 prototype with a documented future
embedded path.

## Non-goals for the deferred phase

- Do not start this phase by rewriting working hosted Region or IE code.
- Do not introduce Rust, C, or undocumented Actus syntax into `.act` sources.
- Do not claim STM32 support from a compiler check, object build, or simulated
  target alone.
- Do not make embedded support a dependency of the current Twin-e roadmap.

# Phase 12 — Brain Directory and Manifest Discovery

## Status

Implementation in progress. The production source boundary is migrated; full
runtime evidence remains blocked by the installed Cranelift backend diagnostic
recorded below.

## Objective

Make the published brain directory the only filesystem location configured by
the runner. Discover `manifest.brain` and deterministically derive shard paths
from that directory without introducing a per-shard configuration list.

## Gate 12.1 — Replace per-shard configuration with `brain_dir`

- [x] Add the accepted `brain_dir` configuration contract.
- [x] Remove `brain` and `shard0`–`shard7` from the runner configuration schema.
- [x] Derive `manifest.brain` and six-digit shard paths centrally.
- [x] Load and validate the manifest before attempting shard restoration.
- [x] Preserve bounded shard-count and checksum validation.
- [ ] Add parser, path-derivation, empty-creation, save, reload, and
      multi-shard training tests.
- [x] Update the accepted architecture decision with the one-directory
      configuration and six-digit profile.

### Required evidence

- [ ] A config containing only `brain_dir` can initialize and publish a brain.
- [ ] A second run discovers the manifest and restores all published shards.
- [x] No production runner or persistence boundary contains one path entry per
      possible shard.
- [ ] Strict checks, full tests, and native zero-float validation pass.

## Current evidence

- `actus check --strict` passes for `src/main.act`.
- `actus fmt --check` passes for the touched path, logical persistence,
  manifest loading, and multi-shard fixture sources.
- `tests/aie_shard_filename.act` covers indexes `0`, `9`, `10`, `99`, `100`,
  and `999999`.
- `actus test --strict` currently reaches 171 discovered tests: 39 pass and
  132 stop at the same installed Cranelift shared-lowering limitation:
  `backend Cranelift shared does not support semantic-lowering ... enum case
  payload source type` at `SourceSpan { start: 9373, end: 9444 }`.
- `actus build --strict --emit exe` is blocked by the same compiler boundary;
  no Twin-e workaround or Actus repository change is included here.

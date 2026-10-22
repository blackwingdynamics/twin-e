# Phase 12 — Brain Directory and Manifest Discovery

## Status

Implementation complete. The runner and logical persistence boundaries use a
single brain directory; runtime and native acceptance evidence is green.

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
- [x] Add parser, path-derivation, empty-creation, save, reload, and
      multi-shard training tests.
- [x] Update the accepted architecture decision with the one-directory
      configuration and six-digit profile.

### Required evidence

- [x] A config containing only `brain_dir` can initialize and publish a brain.
- [x] A second run discovers the manifest and restores all published shards.
- [x] No production runner or persistence boundary contains one path entry per
      possible shard.
- [x] Strict checks, full tests, and native zero-float validation pass.

## Current evidence

- `actus check --strict` passes for `src/main.act`.
- `actus fmt --check` passes for the touched path, logical persistence,
  manifest loading, and multi-shard fixture sources.
- `tests/aie_shard_filename.act` covers indexes `0`, `9`, `10`, `99`, `100`,
  and `999999`.
- `actus test --strict`: 171 passed, 0 failed.
- `actus check --strict`: passed.
- `actus build --strict --emit exe -o /tmp/twin-e-engine.aie`: passed;
  generated native IR contains no floating-point instructions.
- `actus build --strict --emit exe benchmarks/aie_logical_latency.act`: passed;
  generated native IR contains no floating-point instructions.

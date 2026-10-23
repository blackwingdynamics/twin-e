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
- `actus test --strict`: 178 passed, 0 failed, including ordered dataset-index
  acceptance, unsorted-entry rejection, public writer round-trip tests, and
  resumable batch continuation from the last published relative name plus
  indexed teaching checkpoint/reload evidence.
- `actus check --strict`: passed.
- `actus build --strict --emit exe -o /tmp/twin-e-engine.aie`: passed;
  generated native IR contains no floating-point instructions.
- `actus build --strict --emit exe benchmarks/aie_logical_latency.act`: passed;
  generated native IR contains no floating-point instructions.

Directory training evidence: `source=directory` processed all three accepted
Georgian TWF files (23 records total) and published `manifest.brain` plus two
shard files in the configured brain directory; the run exited with status `0`.

## Gate 12.2 — Directory-based TWF batch ingestion

The runner accepts one `input` path per invocation and has an initial directory
enumerator. That is sufficient for a prototype publication step, but it is not
the production contract for a training dataset directory. Gate 12.2 adds a
deterministic dataset manifest index so large corpora can be split into
bounded, resumable batches without reintroducing a per-file configuration list.

### Contract

- [x] Add `source=directory` and `input_dir=<directory>` to the runner config.
- [x] Match the final path extension exactly as `.twf` for POSIX and Windows
      path storage; unrelated three-letter extensions are rejected.
- [x] Generate a validated dataset manifest index from only regular `.twf`
      files below the configured directory.
- [x] Sort discovered relative filenames deterministically when generating the
      index, then consume the published index order during teaching.
- [x] Enforce one named per-batch index bound without limiting total corpus
      size or the number of published brain generations.
- [x] Initialize the brain for the first file, then load the published
      generation before each subsequent indexed file and preserve the same
      `brain_dir`.
- [x] Publish a mandatory checkpoint after each successful indexed file so an
      interrupted batch does not discard already published generations.
- [ ] Reject an empty directory, unreadable entries, malformed TWF input, and
      a failed intermediate publication without silently continuing.
- [ ] Add batch metrics identifying file count, record count, accepted count,
      and the final generation.
- [ ] Add public config and runner tests covering one, multiple, unordered,
      empty, malformed, and partially failing directories.
- [ ] Update the training-repository instructions to generate and consume a
      dataset manifest index for a multi-file dataset.

### External prerequisite

The required bounded `std::fs` directory enumeration API is now available to
the installed Actus compiler. Twin-e consumes it through the typed
`read_dir`, `next_dir_entry`, `metadata`, and `close_dir` boundary; it does not
use hardcoded filenames, shell commands, or an unbounded collection.

The remaining Gate 12.2 checkboxes are still open until batch metrics and the
full malformed/partial-publication error matrix are implemented and evidenced.
The current tests validate directory scanning, published-index reading,
deterministic ordering, per-batch continuation, checkpoint/reload between two
files, and rejection of unsorted entries.

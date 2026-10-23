# Phase 12 — Brain Directory and Manifest Discovery

## Status

Gates 12.1 and 12.2 are complete. Gate 12.3 is the next implementation gate:
it closes the production directory-training flush boundary so a published
shard can leave the bounded resident working set before the next shard is
admitted.

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
- [x] Reject an empty directory, unreadable entries, malformed TWF input, and
      a failed publication without silently continuing; a malformed later file
      leaves the prior published generation intact.
- [x] Add batch metrics identifying file count, record count, accepted count,
      and the final generation.
- [x] Add public config and runner tests covering one, multiple, unordered,
      empty, malformed, and partially failing directories.
- [x] Update the training-repository instructions to generate and consume a
      dataset manifest index for a multi-file dataset.

### External prerequisite

The required bounded `std::fs` directory enumeration API is now available to
the installed Actus compiler. Twin-e consumes it through the typed
`read_dir`, `next_dir_entry`, `metadata`, and `close_dir` boundary; it does not
use hardcoded filenames, shell commands, or an unbounded collection.

The typed directory runner now stops on empty or unreadable directories,
invalid indexes, malformed or unreadable TWF files, checkpoint-load failures,
publication failures, and teaching rejection. Successful runs emit one bounded
`TWIN_E_DATASET_METRICS` record containing file count, record count, accepted
count, and final generation. The runner publishes after every accepted file;
the malformed-second-file test verifies that the first generation remains
loadable after the batch stops.

The public error-boundary and metrics tests bring the strict suite to 183
passed and 0 failed. The training repository documents directory input and
the generated deterministic manifest-index workflow without enumerating shard
paths in configuration.

## Gate 12.3 — Stream training across the bounded resident cache

Directory ingestion must remain continuous when the logical brain grows beyond
the four-slot resident working set. A successful shard publication is the
eviction boundary: the runner must flush the dirty resident shard, validate
the published artifact, mark the resident entry clean, and release its cache
slot before retrying admission for the next shard. Disk-backed logical shard
count remains governed by the brain manifest, not by resident cache capacity.

### Contract

- [x] Detect `FlushRequired` or an equivalent dirty high-watermark signal at
      the dataset teaching boundary before the next shard admission.
- [x] Flush and validate the selected dirty shard before releasing its
      resident slot; never discard dirty state before publication succeeds.
- [ ] Retry the pending shard admission after a successful flush without
      replaying or skipping the current TWF record.
- [ ] Preserve resident and published state unchanged when flush or admission
      fails, and return the typed failure instead of a generic success.
- [ ] Keep the resident cache bounded while allowing the manifest to reference
      every successfully published logical shard.
- [ ] Add a multi-file directory-training test that crosses the four-slot
      resident limit and completes in deterministic file order.
- [ ] Add a failed-flush test proving that dirty state remains usable and the
      next admission is not attempted as if publication had succeeded.
- [ ] Record the resulting metrics and exit behavior, then update ADR-0012
      and the training-repository instructions with the verified boundary.

### Acceptance evidence

- [ ] The existing three-file Georgian directory run completes without
      `ResidentCapacityExceeded`.
- [ ] All prior strict checks remain green and no filesystem I/O is added to
      inference, impulse forwarding, or neurogenesis hot paths.

Gate 12.3 first-check evidence: the dataset boundary now preserves the typed
`FlushRequired` signal from logical admission instead of collapsing it into
`ResidentCapacityExceeded`. `tests/aie_logical_teaching.act::test_dataset_boundary_reports_flush_request`
proves that three dirty resident shards are detected before the next dataset
file is admitted. The check itself is allocation-free and performs no
filesystem I/O; the following flush boundary consumes this signal explicitly.

Gate 12.3 second-check evidence: `logical_teaching_flush_dirty_residents`
publishes the dirty resident generation through the explicit persistence
boundary and marks entries persisted only after successful publication.
`tests/aie_logical_flush.act::test_logical_teaching_flush_marks_dirty_entries_persisted`
proves that the dirty count reaches zero after a successful flush, while the
existing failed-flush evidence proves that a failed publication preserves the
dirty resident state.

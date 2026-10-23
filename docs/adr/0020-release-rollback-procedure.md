# ADR-0020 — Production executable and brain rollback procedure

## Status

Accepted

## Context

A failed release must be reversible without deleting or mutating the newer
brain generation. The executable and its published brain generation are one
release pair: the executable's runtime compatibility profile must match the
manifest before resident state is loaded.

## Decision

Rollback is an operator-controlled, stop-and-verify sequence:

1. Stop the active runner and preserve the current executable, runtime
   manifest, and brain directory as immutable rollback evidence.
2. Select the previous complete executable/runtime-manifest pair from the
   release record and verify both published checksums before starting it.
3. Start that executable with the same brain directory. Startup validates the
   runtime compatibility profile before loading state.
4. If the newest brain manifest is invalid or incomplete, recovery selects the
   previous complete manifest generation. It never edits or deletes the newer
   generation during selection.
5. After recall succeeds, publish any new teaching as a new generation; do
   not overwrite the recovered generation in place.

Rollback is therefore a selection and validation operation, not a destructive
filesystem reset. A release record must retain the executable checksum,
runtime-manifest checksum, compatibility profile, and complete brain
generation identifier for each pair.

## Evidence

`tests/ie_manifest_recovery.act::test_restart_recovery_selects_complete_auxiliary_generation`
corrupts the newest manifest, validates the previous complete generation, and
confirms that generation selection returns the fallback slot. The full strict
suite passed with 192 tests. Runtime compatibility rejection is covered by
`tests/ie_manifest_compatibility.act`.

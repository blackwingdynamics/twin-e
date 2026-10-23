# ADR-0019 — Runtime compatibility profile for published brain manifests

## Status

Accepted

## Context

The manifest already validates its serialized format, layout strides, and
token/context/code versions. A compiled runner also needs to reject a manifest
written for a different runtime compatibility profile before any resident
brain state is loaded. The check belongs to manifest validation, not to a
post-load warning or a mutation-time workaround.

## Decision

The dynamic manifest header field at offset `42` is the runtime compatibility
version. Writers encode `BRAIN_RUNTIME_COMPATIBILITY_VERSION`; readers require
the same compile-time value as part of `manifest_dynamic_bytes_are_valid`.
The manifest checksum covers this field, so a modified compatibility value is
rejected even when a stale writer recomputes the checksum. The compiled
runner's compatibility profile is therefore checked before logical state
admission.

Changing the runtime layout, ownership contract, or compiler-dependent binary
ABI requires incrementing this version and publishing a migration or rollback
decision before loading older generations.

## Evidence

`tests/ie_manifest_recovery.act::test_manifest_rejects_runtime_compatibility_mismatch`
rewrites the compatibility field, recomputes the manifest checksum, and
verifies that validation rejects the generation before resident state is
available. Existing format, layout, and checksum tests remain unchanged.

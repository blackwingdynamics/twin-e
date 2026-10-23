# ADR-0007: Modality-Neutral Observation Events

- **Status:** Accepted
- **Date:** 2026-10-06
- **Scope:** bounded observation input and integer-only sparse encoding
- **Related work:** ADR-0001, ADR-0002, ADR-0004, Phase 5 roadmap

## Context

Twin-e must eventually accept facts from cameras, distance sensors, motion
detectors, and other devices. Device protocols and physical units must not
leak into the associative core. The core needs one bounded input contract that
can be tested on a normal computer before any hardware adapter exists.

## Decision

The public runtime accepts a fixed `ObservationEvent` containing:

- a closed `ObservationKind` category: `Obstacle`, `Distance`, `Person`,
  `Motion`, or `Direction`;
- two unsigned integer value fields;
- a bounded sequence number;
- an explicit observation contract version;
- a validity marker supplied by the adapter boundary.

Both value fields are limited by `OBSERVATION_MAX_VALUE`. Unsupported versions,
invalid events, and out-of-range values return typed `ObservationError`
variants before encoding or runtime mutation.

The event key is composed from the version, category discriminator, both value
fields, and sequence number using integer multiplication and XOR. The key is
passed through the existing versioned sparse codebook, so identical events
produce identical 128-bit codes with the configured active-bit count. No
floating-point operation, pointer, device ABI, allocation, or filesystem I/O
is involved.

Temporal observation identity composes the previous and current validated event
keys with the same bounded integer mixer before sparse encoding. Therefore the
same current event can produce different codes when its preceding observation
differs, while the event window remains explicitly bounded to two events.

The observation module is exposed through the canonical `ie` facade. Sensor
drivers will later translate device data into this event; they will not be
imported by the IE runtime.

## Evidence

`tests/ie_observation.act` verifies deterministic encoding, typed rejection of
an out-of-range value, separation of the same current event under two
different predecessors, fixed snapshot round-trip, and invalid-header
rejection. The `ObservationSnapshot` format is 20 bytes with a magic value,
format version, kind, validity marker, bounded values, sequence, and event
version. The executable fixture
`benchmarks/ie_observation_roundtrip.act` prints
`IE_OBSERVATION_ROUNDTRIP bytes=20 code_roundtrip=1 active_bits=8` and builds
with strict zero-floating-point verification.

## Consequences

- observation behavior is deterministic and host-testable;
- device integration can be added behind an adapter boundary;
- integer bounds and version checks are explicit;
- temporal identity and persistence require additional work before this is a
  complete sensor-to-action pipeline.

## Rejected alternatives

- importing camera, lidar, or motor-driver types into the engine;
- accepting arbitrary strings or dynamic maps as observation input;
- encoding floating-point sensor values directly;
- using an unversioned or unbounded event payload.

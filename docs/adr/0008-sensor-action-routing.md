# ADR-0008: Hardware-Neutral Sensor and Action Routing

- **Status:** Accepted
- **Date:** 2026-10-06
- **Scope:** Phase 5.5 observation admission, context routing, successor
  selection, and bounded action emission
- **Related work:** ADR-0004, ADR-0007, `docs/architecture.md`

## Context

Twin-e must accept environmental observations before any camera, IMU, lidar,
motor, or board driver is selected. The AIE core therefore needs a bounded
host-testable boundary that accepts validated `ObservationEvent` values and
does not import device APIs.

The same boundary must turn a trained context transition into a small set of
validated actions. Missing context, stale observations, ambiguous successors,
and repeated commands must be rejected before an action leaves the runtime.

## Decision

Phase 5.5 adds a hardware-neutral action module under the AIE runtime.

1. A sensor adapter admits an `ObservationEvent` only after the existing
   observation validator accepts it.
2. The current observation key is reduced to a bounded `u32` identity for the
   context sidecar. The full observation context key remains the binding
   identity, so no device-specific type enters the arena.
3. Routing computes the previous/current observation context, looks up the
   current binding, and uses the existing deterministic successor selector.
4. Successor token identities map to five bounded actions: `Stop`, `Move`,
   `Turn`, `Follow`, and `Signal`.
5. An action is emitted only when exactly one distinct valid action is
   available. Missing context, conflicting action identities, stale sequence
   numbers, repeated action identities, and invalid action tokens return typed
   errors.
6. Action events contain only bounded integer fields and arena indexes. They do
   not contain pointers, driver handles, filesystem paths, or dynamic data.
7. Sensor and action adapters remain in-memory and hardware-neutral. Transport
   and device integration belong to later bridge and USTARI phases.
8. Observation hashes are `u64` values, while the current binding table uses
   `u32` token IDs. The adapter projects the hash through the configured
   `OBSERVATION_TOKEN_MASK` before the checked narrowing cast. This keeps the
   conversion bounded and explicit; it does not claim collision-free identity
   for the projected domain.

## Safety rules

- A current sequence must be greater than its predecessor and any supplied
  last accepted sequence.
- Two valid successors with different action identities are a conflict, even
  when deterministic tie-breaking could select one of them.
- The same action identity cannot be emitted twice consecutively when the
  caller supplies the previous action identity.
- No matching context or no valid successor produces no action.
- An action event is validated again at the emission boundary.

## Consequences

- Obstacle-to-stop and person-to-follow behavior can be tested on a host with
  no hardware or filesystem access.
- AIE remains independent of Cognitive Engine and USTARI internals.
- Action token identifiers become part of the current runtime profile and must
  be versioned if their meaning changes.
- Hardware adapters can later translate the validated action event into motor
  or actuator commands without changing AIE routing.

## Non-goals

This ADR does not define motor timing, actuator safety certification, sensor
driver ABIs, USTARI frame encoding, or hardware performance claims.

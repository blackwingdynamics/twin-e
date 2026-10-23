# ADR-0021 — Teaching wire message contract

## Status

Accepted

## Context

Twin-e needs a framed wire transport without coupling IE state or modality
adapters to a network implementation. Actus already provides the target-neutral
`std::wire` frame, checksum, and incremental parser contracts. Twin-e therefore
needs only an application-level message identity inside that frame.

## Decision

Teaching wire messages live under `src/teaching/transport/wire/`.
`std::wire` owns frame version, flags, sequence encoding, payload length,
maximum frame size, and CRC validation. Twin-e owns:

- `TEACHING_WIRE_MESSAGE_ID` for a teaching request;
- `TEACHING_WIRE_MESSAGE_VERSION` for the application payload schema;
- `TeachingWireMessage` metadata describing the request sequence and bounded
  payload length;
- the complete frame length is `WIRE_HEADER_BYTES + payload_length +
  WIRE_CRC_BYTES`, and the exact result must not exceed
  `WIRE_MAX_FRAME_BYTES`;
- one frame carries exactly one teaching request; bounded batches use a
  separate transport-level contract and are not concatenated into one frame;
- complete-frame decoding delegates unsupported versions, bad checksums,
  truncation, and payload bounds to `std::wire` before the teaching message is
  exposed to admission;
- `sequence_num` is preserved as the deterministic response-correlation key
  and is admitted through the caller-owned `std::wire` sequence window;
- the wire contract imports only shared configuration and `std::wire`; it does
  not import modality adapters, teaching pipelines, IE state, or persistence;
- validation that the frame and application message versions match the
  supported contract and that the payload fits `std::wire`'s maximum.

The wire contract does not perform network I/O, decode modalities, or mutate IE
state. The canonical `teaching::transport` facade exports the `wire` child
module, while framing and checksum implementation remain in `std::wire`.

## Evidence

`tests/teaching_wire_contract.act` verifies stable message identity/version,
exact frame sizing, the maximum-frame boundary, and oversized-payload
rejection, plus the one-request-per-frame boundary. CRC calculation and
validation remain covered by `std::wire`'s canonical codec rather than being
duplicated in Twin-e. The decoder tests additionally cover valid delivery and
typed rejection of corrupt, truncated, and unsupported frames.
The wire facade tests exercise decoding and sequence admission without
constructing or mutating any IE state; a failed CRC decode also leaves the
caller payload buffer unchanged. The incremental parser fixture reconstructs a
single frame from two chunks. The reproducible native and test evidence is
recorded in `docs/benchmarks/teaching-wire.md`.

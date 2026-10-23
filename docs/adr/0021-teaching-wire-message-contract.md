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
- validation that the frame and application message versions match the
  supported contract and that the payload fits `std::wire`'s maximum.

The wire contract does not perform network I/O, decode modalities, or mutate IE
state. The canonical `teaching::transport` facade exports the `wire` child
module, while framing and checksum implementation remain in `std::wire`.

## Evidence

`tests/teaching_wire_contract.act` verifies stable message identity/version and
rejects an oversized payload. The strict suite passes with 194 tests.

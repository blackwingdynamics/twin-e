# AIE Phase 5 Roadmap

Phase 5 turns the working context-aware persistence engine into a durable,
trainable, and hardware-testable runtime. The phase covers the remaining
items that are outside the completed shard and manifest storage gates.

The order is intentional: durable `.brain` files and tokenizer artifacts come
first, then training, sensor input, action routing, and finally hardware
validation.

## Status legend

- `[x]` Completed and verified.
- `[ ]` Remaining work.
- `[~]` Partially complete or requiring additional evidence.

## P5.0 — Phase contracts and evidence

- [ ] Create an ADR for the Phase 5 snapshot, tokenizer, training, and
  multimodal event contracts.
- [ ] Define the supported `.brain` file version and compatibility policy.
- [ ] Define failure behavior for interrupted writes, invalid artifacts, and
  incompatible runtime versions.
- [ ] Define evidence output for every Phase 5 executable benchmark.
- [ ] Keep all benchmarks deterministic and free of floating-point
  instructions unless a later ADR explicitly changes that rule.

## P5.1 — Complete `.brain` file persistence

- [ ] Add a public host save API for fabric, bindings, tokenizer metadata, and
  context metadata.
- [ ] Add a public host load API that validates the complete file before
  mutating live state.
- [ ] Reject truncated, oversized, corrupted, and incompatible `.brain` files.
- [ ] Verify that a failed load leaves the existing fabric and bindings
  unchanged.
- [ ] Persist the tokenizer vocabulary and merge-rule compatibility metadata.
- [ ] Persist the context-codebook version and active-bit profile.
- [ ] Add a restart benchmark that saves, exits, reloads, and recalls the same
  learned path.
- [ ] Record the final `.brain` header, payload, binding, and artifact sizes.

## P5.2 — Production BPE vocabulary

- [ ] Replace the one-merge fixture with a bounded multi-merge vocabulary.
- [ ] Verify repeated ranked merge passes on a multi-token text fixture.
- [ ] Verify byte fallback, BOS, EOS, unknown tokens, and merged-token decode.
- [ ] Reject vocabulary files with incompatible versions, invalid ranks, or
  over-sized token spans.
- [ ] Persist the bounded vocabulary and merge rules in the text snapshot.
- [ ] Restore the vocabulary and verify encode/decode identity after restart.
- [ ] Measure token-count reduction on a larger representative text corpus.

## P5.3 — Training and learning workflow

- [ ] Define a bounded training input API for tokenized sequences.
- [ ] Create context-bound bindings from consecutive token events.
- [ ] Reinforce the observed successor path through myelination updates.
- [ ] Handle competing successors deterministically using the generation
  selection policy.
- [ ] Add bounded training limits for sequence length, events, and arena size.
- [ ] Verify that training changes recall behavior after a save and reload.
- [ ] Add a small text-learning benchmark with repeatable expected output.
- [ ] Measure training time, allocated columns, active bindings, and snapshot
  size.

## P5.4 — Modality-neutral observation events

- [ ] Define a modality-neutral event structure for bounded observations.
- [ ] Support event categories such as obstacle, distance, person, motion,
  and direction.
- [ ] Encode an observation into a deterministic sparse code without using
  floating-point instructions.
- [ ] Bind an observation to its temporal context in the same way as text
  tokens.
- [ ] Reject malformed, unknown, or over-sized observation events.
- [ ] Add an observation round-trip benchmark and serialized fixture.

## P5.5 — Sensor and action routing

- [ ] Add a sensor adapter boundary that accepts observation events without
  coupling the AIE core to a device driver.
- [ ] Route an observation through context lookup and successor selection.
- [ ] Define bounded actions such as stop, move, turn, follow, and signal.
- [ ] Add an action adapter boundary that emits validated action events.
- [ ] Add safety rules for missing, conflicting, stale, or repeated actions.
- [ ] Verify a deterministic obstacle-to-stop scenario.
- [ ] Verify a deterministic person-to-follow scenario.
- [ ] Keep sensor and action adapters hardware-neutral until hardware evidence
  is available.

## P5.6 — Hardware and scale validation

- [ ] Select a target CPU or embedded board for the first hardware profile.
- [ ] Measure resident memory, storage throughput, cache working set, and
  restart time on the target hardware.
- [ ] Measure coincidence evaluation, forwarding, training, and generation
  latency on the target hardware.
- [ ] Verify that the generated native artifact contains no floating-point
  instructions for the integer profile.
- [ ] Test persistence interruption and recovery on the target filesystem.
- [ ] Record the maximum tested logical columns, resident columns, shard count,
  and cache capacity.
- [ ] Document the difference between tested limits and theoretical scale.

## P5.7 — Release acceptance

- [ ] All `.brain` save/load and corruption tests pass in strict mode.
- [ ] Multi-merge BPE encode/decode and artifact compatibility tests pass.
- [ ] Training changes recall behavior and survives restart.
- [ ] Observation encoding and action routing pass deterministic fixtures.
- [ ] Target hardware benchmarks are recorded with reproducible commands.
- [ ] The phase has no unverified claims about intelligence, scale, latency,
  or hardware support.
- [ ] Update the project status and publish the final Phase 5 evidence report.

## Phase 5 completion criteria

Phase 5 is complete when the runtime can save and restore a trained
context-aware model, process a bounded production vocabulary, accept
modality-neutral observations, emit validated actions, and provide measured
hardware evidence for the supported profile.

# Twin-e Architecture

## 1. Purpose

Twin-e is a two-engine system written around Actus. The name describes the
two future computational halves:

1. **Actus Impulse Engine (AIE):** bounded associative state, sparse codes,
   minicolumns, impulse propagation, training, decay, and persistence.
2. **Actus Cognitive Engine:** deterministic symbolic state tracking and
   reasoning over validated Actus thought structures.

The two engines must remain separate. They communicate through explicit
protocol and adapter boundaries rather than importing each other's internal
types.

The current implementation priority is AIE. The Cognitive Engine, USTARI
transport, bridge adapters, and artificial endocrine system are architectural
targets for later phases unless a roadmap explicitly opens their work.

## 2. System boundary

```text
                         Twin-e
                            |
        +-------------------+-------------------+
        |                                       |
   AIE Impulse Engine                    Cognitive Engine
        |                                       |
        +-------------------+-------------------+
                            |
                    Bridge / Adapters
                            |
                    USTARI Wire Protocol
                            |
                 MCU, host, or future hardware

        Future cross-cutting modulation:
                    Artificial Endocrine System
```

The diagram describes ownership boundaries, not an implementation claim. A
layer becomes operational only after its own roadmap gates and reproducible
tests are complete.

## 3. Repository structure

```text
src/
├── aie/                 # Current primary implementation
│   ├── layout/           # 64-byte minicolumn and fixed arena layout
│   ├── runtime/          # Coincidence, forwarding, training, generation,
│   │                      # observations, neurogenesis, and decay
│   ├── persistence/      # .brain files, shards, manifests, and snapshots
│   └── aie.act            # Canonical AIE facade
│
├── config/               # Shared protocol and policy constants
├── encoding/             # Token, context, binding, and sparse codebook logic
├── tokenizer/            # Bounded byte and BPE tokenization
│
├── cognitive/            # Reserved for the future Cognitive Engine
├── wire/                 # Reserved for the USTARI frame protocol
├── bridge/               # Reserved for AIE/Cognitive adapters
└── endocrine/            # Reserved for the future endocrine layer
```

The reserved directories are architectural boundaries. They must not be
created merely to hold speculative code, and their future code must not be
placed inside `src/aie/` as a shortcut.

Documentation follows the same separation:

```text
docs/
├── architecture.md       # This document: stable system map
├── adr/                   # Accepted design decisions
├── benchmarks/            # Reproducible measurements and evidence
└── roadmap/               # Ordered implementation phases and gates
```

## 4. AIE: current primary engine

AIE is the only engine currently under active implementation in Twin-e. Its
responsibilities are:

- fixed 64-byte cortical minicolumn storage;
- integer-only 128-bit sparse coincidence evaluation;
- bounded arena allocation and free-list reuse;
- context-bound token and observation routing;
- deterministic impulse forwarding and successor selection;
- local learning, neurogenesis, myelination, inhibition, and decay;
- bounded generation and loop protection;
- position-independent `.brain` persistence and shard recovery;
- modality-neutral observation input and future action routing.

AIE must not contain symbolic reasoning, LLM integration, device-driver
types, transport framing, or endocrine policy.

The current priority order is:

1. finish the Phase 5 AIE runtime gates;
2. validate sensor-to-action routing with host-side deterministic fixtures;
3. complete persistence and restart evidence;
4. record hardware evidence only after a target is selected;
5. freeze a stable AIE boundary before starting the Cognitive Engine.

## 5. Cognitive Engine: future reasoning half

The Cognitive Engine will handle symbolic reasoning rather than impulse-level
associative state. Its planned responsibilities are:

- parse or receive bounded Actus thought blocks;
- represent agents, resources, facts, and state transitions;
- enforce `erg`, `abs`, and `dat` lifecycle rules at the reasoning boundary;
- reject use-after-move, double-use, invalid transfer, and invariant-breaking
  operations;
- return deterministic verified state to a synthesis or host layer.

The Cognitive Engine must own its own AST, scratchpad, verifier, and state
model. It may consume a public protocol message from AIE, but it must not
reach into AIE arena columns or mutate AIE storage directly.

The Cognitive Engine is not part of the current AIE implementation phase.

## 6. USTARI wire protocol

USTARI (`std::wire`) is the planned transport contract between embedded AIE
runtime and host-side components. It is a protocol layer, not an engine.

Its planned frame is:

```text
[12-byte header][payload 0..1024][CRC16-CCITT]
```

The fixed header contains a magic value, protocol version, flags, message ID,
channel ID, sequence number, and payload length. Encrypted channels may add an
AEAD tag according to the accepted USTARI specification.

USTARI owns:

- frame encoding and decoding;
- bounded payload validation;
- CRC calculation and verification;
- protocol and message versions;
- channel and message identifiers;
- sequence and replay-window validation;
- typed transport errors.

USTARI does not own AIE learning, Cognitive reasoning, sensor drivers, or
motor control. A wire frame must carry a versioned message payload, not an
internal engine struct whose layout can change without protocol approval.

## 7. Bridge and adapter layer

The bridge connects the two engines without merging them:

```text
sensor adapter → observation message → AIE
AIE result     → action/event message → bridge
bridge         → verified cognitive message → Cognitive Engine
```

Adapters translate between external or engine-specific representations and
versioned protocol messages. They must:

- validate inputs before entering an engine;
- preserve bounded sizes and integer-only semantics;
- make ownership transfer explicit;
- reject unknown versions and malformed messages;
- avoid synchronous filesystem I/O in the AIE hot path;
- remain hardware-neutral until target hardware evidence exists.

No adapter may bypass the canonical facade of an engine or expose private
arena, AST, or persistence state.

## 8. Artificial Endocrine System: later modulation layer

The Artificial Endocrine System (AES) is a later, optional modulation layer.
It represents global homeostatic values in one bounded 64-bit profile and may
modulate execution parameters such as threshold, reinforcement, inhibition,
and decay.

AES must not:

- replace AIE's local firing laws;
- create or delete topology directly;
- add floating-point operations;
- add heap allocation or unbounded state;
- make unsupported hardware or power claims;
- become a dependency required for ordinary AIE execution.

Its future location is `src/endocrine/`. AIE integration should occur through
a narrow modulation interface, for example an effective-parameter calculation,
so the unmodulated AIE profile remains testable and deterministic.

The endocrine specification is a design target. Its cycle counts, power
figures, stability claims, and hardware behavior require target-specific
evidence before they can be treated as accepted results.

## 9. Dependency direction

The permitted dependency direction is:

```text
config ───────────────┐
encoding ─────────────┤
tokenizer ────────────┤
                      ▼
                    AIE
                      ▲
                      │ public messages only
                  bridge / wire
                      │
                      ▼
                 Cognitive Engine

endocrine ──► optional AIE modulation boundary
```

The following dependencies are forbidden:

- AIE importing Cognitive Engine internals;
- Cognitive Engine indexing AIE arena storage;
- AIE importing USTARI transport implementation into hot-path logic;
- wire code depending on engine-private structs;
- endocrine code silently changing serialized layouts;
- sensor or motor drivers inside the engine core.

## 10. Change control

Create or update an ADR before changing any of the following:

- a public engine facade or bridge message;
- ownership or cleanup semantics;
- a serialized layout or wire frame;
- token, context, observation, or action identity;
- a dependency direction or module boundary;
- AIE modulation or endocrine behavior;
- a hardware or performance claim.

Roadmap checkboxes are evidence gates. They are marked only after the
implementation, tests, documentation, and known limitations are recorded.

Until a later roadmap phase explicitly opens another layer, implementation
work stays inside AIE and its existing public contracts. This keeps the
impulse engine reviewable while preserving a clear path for the second engine,
USTARI, adapters, and endocrine modulation.

# ADR-0009: Codebook Collision, Candidate Retrieval, and Noise Contract

- **Status:** Accepted for Phase 5.8.1 measurement
- **Date:** 2026-10-08
- **Scope:** Token and bounded context codebook measurement, collision
  classification, candidate retrieval, and noisy-input evidence
- **Related work:** ADR-0001, ADR-0002, ADR-0004, Phase 5.8 Gate 5.8.1

## Context

Twin-e encodes token IDs and bounded context keys as sparse 128-bit integer
codes. The current profile uses twelve active bits and exact coincidence at
`theta = 12`. The existing 5,000-code fixture is useful initial evidence, but
it does not establish the operating envelope for larger populations, noisy
wavefronts, or context-heavy workloads.

A single word, “collision”, is insufficient for this system. Equal codewords,
nearby codewords, and multiple valid candidates have different consequences
and require different measurements.

## Decision

### 1. Populations under test

The evidence must measure two populations separately:

1. **Token population:** deterministic token IDs from the active bounded
   vocabulary profile.
2. **Context population:** deterministic bounded context keys produced from
   ordered token or observation identities.

The report must never combine token and context populations into one count.
Each result records the population kind, cardinality, codebook version, active
bit count, seed/profile, and input-generation method.

### 2. Collision classification

The benchmark reports three independent conditions:

- **Exact duplicate:** two different identities produce the same complete
  128-bit code.
- **Threshold overlap:** two different codes share at least the configured
  coincidence threshold, even when their complete codewords differ.
- **Ambiguous candidate set:** one query produces more than one valid sparse
  candidate before exact identity validation.

The conditions must be reported separately. An above-threshold overlap is not
an exact identity collision, and an exact duplicate is not resolved by
myelination or candidate strength.

### 3. Lookup contract

Lookup has two explicit stages:

1. sparse bit matching produces a bounded candidate set;
2. exact identity validation checks the candidate's token identity and, when
   applicable, its bounded context identity and compatibility versions.

Only a candidate that passes the second stage may fire, be selected as a
successor, or be used for an action decision. A candidate that fails exact
identity validation is rejected even when its sparse overlap reaches the
threshold.

Deterministic tie-breaking is allowed only among candidates that have already
passed exact identity validation. Myelination may rank validated candidates;
it must not hide an identity collision.

For the current implementation, the exact identity is supplied by the
position-independent `TokenBinding` sidecar associated with the candidate
arena slot. Its `token_id`, `context_key`, tokenizer version, and context
version are compared after sparse candidate retrieval. The sparse `TokenCode`
and `Wavefront` remain fixed 128-bit representations; identity metadata is not
packed into the coincidence mask.

### 4. Initial profile policy

The current profile remains unchanged for this phase:

- representation: two `u64` masks forming a 128-bit code;
- active-bit count: `12`;
- codebook version: the configured version `1`;
- matching policy: exact twelve-bit recognition for the current profile;
- arithmetic: integer-only and allocation-free in the encoder and matcher.

### Pre-release profile update policy

Twin-e is currently a `0.1.0` unreleased prototype and no trained `.brain`
artifacts are in service. Therefore, changing the active-bit count during this
pre-release stage does not require a codebook-version increment or a migration
path for old brain files. The implemented change from eight to twelve active
bits is recorded as an update to the current codebook version `1`; benchmarks
and documentation record the new active-bit count. Once persisted trained
artifacts are treated as compatible data, any change to the codebook semantics
must again require an explicit compatibility decision.

This ADR does not approve a lower final firing threshold, a wider code, a new
hash profile, or a serialized representation change. Dynamic thresholding may
be measured as a candidate-retrieval experiment, but it cannot become the
final firing policy without false-positive and missed-recognition evidence.

### 5. Noise model

Noise evidence must use controlled bit flips or removals in the encoded
wavefront. The report must distinguish:

- exact input recognition;
- one-bit corruption;
- multiple-bit corruption;
- false activation of a different identity;
- missed activation of the intended identity.

The benchmark must state whether a noisy query is expected to be rejected or
recovered. No noise-tolerance behavior is accepted implicitly.

Noise tolerance means that a code can still be recognized when its sparse
wavefront is incomplete or contains a controlled bit error. For example, a
12-bit code with one active bit removed has an 11/12 overlap with the intended
code. An exact threshold of `12` correctly rejects that damaged input; a
threshold of `11` could recover it, but it also admits a larger false-candidate
risk. The same distinction applies to a flipped bit: one active bit is lost
and one previously inactive bit is added.

The current token-ID path does not need noise tolerance because a digital token
ID is either present or absent. This policy is primarily for future image,
audio, sensor, transmission, or other modality adapters where an observation
may be partial or corrupted. If noise tolerance is enabled, sparse matching
may only produce bounded candidates. A second-stage exact token or context
identity check must reject false candidates before firing, successor
selection, training, or action routing. Lowering the sparse threshold alone is
not an accepted noise-tolerance implementation.

### 6. Stress populations

The measurement plan uses deterministic bounded populations of:

```text
5,000
50,000
500,000
1,000,000
5,000,000
```

The largest population may be split into bounded runs when the host or
compiler resource limit requires it. A partial run must be labelled partial;
it must not be reported as complete evidence.

Every completed run records elapsed time, resident memory, output artifact
size, duplicate count, overlap distribution, candidate counts, and the exact
compiler binary digest.

## Rejected alternatives

### Lowering the final threshold immediately

Rejected because a lower threshold increases candidate retrieval but can also
increase false activation. It requires a second-stage identity contract and
measured false-positive behavior first.

### Using myelination as identity resolution

Rejected because a stronger path is not proof that its token or context
identity is correct.

### Treating every overlap as an identity collision

Rejected because overlap is a similarity measurement, while identity requires
the full token/context contract.

### Expanding the code width in this phase

Rejected as an unmeasured representation and persistence change. A wider code
requires a separate ADR, compatibility version, layout review, and migration
decision.

## Evidence boundary

This ADR defines the measurement and lookup contract. It does not claim that
the current profile is collision-free at arbitrary scale, tolerant of sensor
noise, or suitable for unrestricted language modelling. Those claims require
the completed Phase 5.8.1 evidence and remain unproven until then.


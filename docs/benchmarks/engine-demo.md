# Twin-e Engine Demonstration

This demonstration runs the current hosted Actus engine on a normal computer.
It shows the core impulse lifecycle and the observation snapshot round trip.
It does not claim sensor hardware or target-device behavior.

## Human-readable learning demo

This is the clearest demonstration for a non-technical audience. It trains the
engine on the phrase `Hello Giorgi`, asks it to recall the learned characters,
and prints the reconstructed answer.

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-human-demo.ie \
  benchmarks/ie_string_example.act
/tmp/twin-e-human-demo.ie
```

Expected output shape:

```text
TWIN-E HUMAN DEMO
I learned this phrase:
Hello Giorgi
I was asked to recall it. My answer is:
Hello Giorgi
Result: 12 of 12 characters recalled correctly.
Training time in nanoseconds:
<measured value>
Recall time in nanoseconds:
<measured value>
```

The second `Hello Giorgi` is reconstructed from the values recalled from the
engine. It is not printed as the answer string by the demo itself.

## Behavior demo: learning, context, and forgetting

This scenario emits only values produced by the engine. It starts with an
empty fabric, checks that no token is generated, learns two context-bound
paths, decodes both generated tokens through the demo vocabulary, ages the
weak memory, and checks that no token is generated after decay.

```sh
sh scripts/run-human-brain-demo.sh
```

The runner adds a short presentation pause between output lines. The engine
itself remains fully deterministic and does not contain a timing delay.

The underlying commands are:

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-human-brain-demo.ie \
  benchmarks/ie_human_brain_demo.act
/tmp/twin-e-human-brain-demo.ie
```

Observed runtime output:

```text
0
7
apple
home
0
0
```

The six lines are, in order: generated-token count before learning, active
column count after learning, the token generated for `Giorgi hungry`, the token
generated for `Giorgi tired`, active column count after decay, and generated-
token count after decay. `apple` and `home` come from generated token IDs
decoded through the bounded vocabulary. The demo returns a failure status if
an expected path is missing, if the two contexts converge on the wrong
successor, or if decay fails to remove the weak path.

## Engine lifecycle demo

From the Twin-e repository root:

```sh
actus build --strict --emit exe -o /tmp/twin-e-engine-demo.ie
/tmp/twin-e-engine-demo.ie
```

Expected output:

```text
built `/tmp/twin-e-engine-demo.ie` (strict)
verified generated native IR: no floating-point instructions
IE_DEMO firing payload=41 destination=2 inhibition=1
IE_DEMO neurogenesis linked=1
IE_DEMO decay reclaimed=1
IE_DEMO complete
```

The lines mean:

- one minicolumn matched the input and fired payload `41`;
- its impulse reached destination column `2`;
- lateral inhibition marked the configured neighbor;
- neurogenesis allocated and linked a new column;
- the idle weak column was reclaimed by decay;
- the complete sequence returned successfully.

## Observation persistence demo

```sh
actus build --strict --emit exe \
  -o /tmp/twin-e-observation-demo.ie \
  benchmarks/ie_observation_roundtrip.act
/tmp/twin-e-observation-demo.ie
```

Expected output:

```text
built `/tmp/twin-e-observation-demo.ie` (strict)
verified generated native IR: no floating-point instructions
IE_OBSERVATION_ROUNDTRIP bytes=20 code_roundtrip=1 active_bits=8
```

This confirms that one bounded observation can be serialized into a 20-byte
snapshot, restored, and encoded into the same eight-bit sparse code.

## Evidence boundary

Both commands were run with the strict Actus compiler on the hosted target.
The compiler verified zero floating-point instructions in the generated native
IR. Sensor adapters, action routing, and hardware measurements are future
work covered by the Phase 5 roadmap.

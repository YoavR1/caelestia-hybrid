# Presets

A preset is a config **layer beneath** the user's own settings (architecture.md, D8): explicit user
settings win, unset keys fall through to the preset. Config stores the preset *name*, never its
expanded values, so a preset can be improved later and existing users receive the improvement.

These files serve two jobs at once, and it is worth keeping them straight. Three of them name a
preset and nothing else, which is what a real user's config looks like. The other three set flags
*explicitly*, on purpose, to exercise the override path — a user who has touched a switch. All six
are inputs to `smoke-matrix.sh`.

| File | `hybrid.preset` | Overrides | What it is for |
|---|---|---|---|
| `recommended.json` | `recommended` | none | the default a fresh install gets |
| `midnight.json` | `midnight` | none | MiDnight's features, none of OP's |
| `op.json` | `op` | none | OP's features, none of MiDnight's |
| `all-on.json` | `recommended` | all 12 features true, all variants `op` | everything instantiated at once |
| `all-off.json` | `recommended` | all 12 features false, all variants `midnight` | nothing instantiated |
| `variants-flipped.json` | `recommended` | mixed features, variants deliberately inconsistent | no two components agreeing |

`all-on` and `all-off` are the interesting pair: they prove a flag gates *instantiation* rather than
visibility, because the components a preset turns off report zero instantiations, not zero visible
pixels.

"Custom" is not a file. It is the computed state when a user overrides any key.

## Status

The `hybrid` block is real: `plugin/src/Caelestia/Config/hybridconfig.hpp` backs it, every key has a
schema entry, and every flag has a consumer. A key that is *not* in that schema is rejected rather
than ignored — `settings::Node` warns on unknown keys, wrong types and bad enum values, and
`smoke-matrix.sh` treats those warnings as failures.

That last part matters more than it sounds. If a preset were silently accepted-and-ignored, the
matrix would boot the default config six times and report six passes. It does not, and that is
measured rather than assumed:

```
./hybrid/tools/smoke-matrix.sh --self-test
```

feeds the harness a preset that is valid JSON and invalid schema, and passes only when the run
**fails**. See trap T23.

## Adding a preset

Drop a `*.json` here and `smoke-matrix.sh` picks it up automatically. Add deliberately hostile ones
— they cost seconds and catch real breakage.

Two things to know before you do:

- **A typo is now a failed run, not a quiet default.** That is the point, but it does mean a preset
  has to match the compiled schema exactly. `hybrid.features.dokc` fails the matrix.
- **The variants have one implementation each until Phase 7**, so flipping them changes the config
  and not yet the shell. They are in the presets anyway, because the schema and the override path
  are what is being exercised.

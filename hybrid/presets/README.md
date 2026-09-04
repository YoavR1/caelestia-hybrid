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
| `all-on.json` | `recommended` | all 14 features true, all variants `op` | everything instantiated at once |
| `all-off.json` | `recommended` | all 14 features false, all variants `midnight` | nothing instantiated |
| `variants-flipped.json` | `recommended` | mixed features, variants deliberately inconsistent | no two components agreeing |
| `theme-nebula.json` | `recommended` | `paths.themeName` | the only preset touching a non-`hybrid` key: proves a themed path default resolves through `themeName` and falls back when it is unset |

`all-on` and `all-off` are the interesting pair: one boots with every component built at once, the
other with none of them.

Be precise about what that pair actually proves, because this file used to overclaim it. The matrix
asserts three things per run -- the shell stays up for the whole timeout, it logs no `ERROR` or
`WARN` that is not explicitly ignored, and every driven IPC call answers. **Nothing counts
instantiations.** So `all-off` proves a disabled feature does not *break* or *warn*; it does not
prove the component was never built. A feature gated with `visible: false` instead of `active:`
would pass both runs.

That the flags gate instantiation is enforced by review (see the `feature-import` skill and the
`qml-reviewer` agent), not by this harness. An instantiation census is worth building and does not
exist yet.

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

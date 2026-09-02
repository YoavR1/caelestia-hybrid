# Presets

A preset is a config **layer beneath** the user's own settings (architecture.md, D8): explicit user
settings win, unset keys fall through to the preset. Config stores the preset *name*, never its
expanded values, so a preset can be improved later and existing users receive the improvement.

| Preset | Intent |
|---|---|
| `midnight.json` | MiDnight implementations and features everywhere they exist |
| `op.json` | OP implementations and features everywhere they exist |
| `recommended.json` | The combination we think works best |

"Custom" is not a file. It is the computed state when a user overrides any key.

## Status

Until Phase 3, the `hybrid` block has no C++ backing, so these keys are quarantined by upstream's
settings system (trap T10) and the shell boots with defaults. That is fine and expected — the
presets still serve their Phase 1 purpose of giving `smoke-matrix.sh` distinct configs to boot.

Keys become real when Phase 3 adds them via the `config-property` skill.

## Adding a preset

Drop a `*.json` here and `smoke-matrix.sh` picks it up automatically. Add deliberately hostile ones
(everything on, everything off, every variant flipped) — they cost seconds and catch real breakage.

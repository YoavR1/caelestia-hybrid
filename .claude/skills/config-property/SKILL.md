---
name: config-property
description: >-
  Add, rename, or remove a setting in the Caelestia Hybrid shell — the config schema is compiled
  C++, not dynamic JSON, so this is a multi-file recipe spanning a config header, the config root,
  CMake, and Nexus UI. Use whenever adding a config option, feature flag, toggle, slider or
  preference, wiring a hybrid.features or hybrid.variants key, or when a hand-edited shell.json
  key does not appear in the settings UI.
---

# Adding a config property

Config is **compiled C++ with macros** (T10). Editing `shell.json` does not create a property —
unknown keys are set aside by `Settings/quarantine.cpp`. If a hand-added key "does nothing", this
is why, not a bug.

## Which config system am I in?

Check `plugin/src/Caelestia/Config/` before writing:

| Present | System | Base class | Registered in |
|---|---|---|---|
| `configobject.hpp`, `rootconfig.hpp`, `configlist.hpp` | **Old** (MiDnight/OP, pre-Phase-2) | `ConfigObject` | `config.hpp` → `GlobalConfig` |
| `../Settings/objectnode.hpp`, `rootnodes.hpp` | **Upstream** (Phase 2+) | `settings::ObjectNode` | `rootnodes.hpp` → `ConfigRoot` |

Match the tree you are actually in. Do not port one style into the other ad hoc.

## Macros (both systems)

| Macro | Meaning |
|---|---|
| `CONFIG_PROPERTY(Type, name, default)` | Per-layer property; can differ per screen |
| `CONFIG_GLOBAL_PROPERTY(Type, name, default)` | Global only; identical across screens |
| `CONFIG_SUBOBJECT(Class, name)` | Nested config object |

Use `CONFIG_GLOBAL_PROPERTY` for anything that is not sensibly per-monitor — credentials-adjacent
values, service toggles, CLI paths. Feature flags are global.

## Recipe — new property on an existing object

1. **Header.** Add the macro to the relevant `plugin/src/Caelestia/Config/<area>config.hpp`,
   grouped with related properties, in the file's existing order.
2. **Consume it in QML** as `GlobalConfig.<area>.<name>` (`import Caelestia.Config`).
3. **Nexus UI.** Add a row to the matching page under `modules/nexus/pages/`. Use the existing
   common controls — `SelectRow`, `SliderRow`, `StepperRow`, `SwitchRow` — rather than a bespoke
   control. Note both forks modified these common rows, so check the current signatures.
4. **Docs.** Add it to the README config table if that area has one.
5. **Verify** with the `shell-verify` gate.

## Recipe — new config object

Additionally:

1. Create `plugin/src/Caelestia/Config/<area>config.hpp`.

   Old system:
   ```cpp
   class HybridConfig : public ConfigObject {
       Q_OBJECT
       QML_ANONYMOUS
       CONFIG_GLOBAL_PROPERTY(QString, preset, u"recommended"_s)
   public:
       explicit HybridConfig(QObject* parent = nullptr) : ConfigObject(parent) {}
   };
   ```

   Upstream system:
   ```cpp
   class HybridConfig : public settings::ObjectNode {
       CONFIG_NODE(HybridConfig, settings::ObjectNode)
       QML_ANONYMOUS
       CONFIG_GLOBAL_PROPERTY(QString, preset, u"recommended"_s)
   };
   ```

2. **Register it on the root** — `CONFIG_SUBOBJECT(HybridConfig, hybrid)` in `config.hpp`'s
   `GlobalConfig` (old) or `rootnodes.hpp`'s `ConfigRoot` (new).
3. **Old system only:** add a matching `Q_MOC_INCLUDE("hybridconfig.hpp")` and a forward
   declaration. Omitting it produces a confusing moc-time failure, not a clear error.
4. **CMake.** Add the header to `plugin/src/Caelestia/Config/CMakeLists.txt`.
5. **Nexus page.** New page needs entries in both `modules/nexus/PageRegistry.qml` (label, icon,
   description, category) and `modules/nexus/PageCompRegistry.qml` (the component). Both forks
   modified both files — check current shape.

## The `hybrid` block

`hybrid` exists, in `plugin/src/Caelestia/Config/hybridconfig.hpp`:

- `preset` — an enum naming the preset, **never the expanded values** (D8), so presets can be
  improved for existing users. It serialises as a string: `"preset": "midnight"`.
- `features` — one boolean per imported feature, 12 of them
- `variants` — capped at ~6 entries (D4); growth means the design is drifting back toward the
  registry we rejected. Four so far.

Two things about it are unlike the rest of the schema, and both are load-bearing:

**Defaults are functions, not constants.** Every feature and variant resolves its default through a
`DefaultSpec` lambda that reads the selected preset, so a fresh config that names only a preset is
complete. Changing `preset` re-resolves them — but only the keys the user has *not* set, via
`isOverride()`, inside a `WriteScope(node, WriteOrigin::Layer)`. Writing under the ambient origin
would record the preset's values as user overrides and destroy exactly what D8 exists to preserve.

**A flag only exists once something reads it.** Four were removed for failing that test: two
features not imported yet, one upstream ships unconditionally, and `patternLock`, which never ships
as a toggle because it is a lock-screen bypass (D10, trap T3).

`hybrid/presets/*.json` are real configs now, not placeholders — a key that is not in the schema
fails the smoke matrix rather than being quietly ignored. See `hybrid/presets/README.md`.

## Migration

An existing `shell.json` with no `hybrid` block is just a user layer with defaults applied —
nothing corrupts, nothing needs migrating. Preserve that property:

- **Add** keys freely; absent keys take defaults.
- **Never repurpose** a key name with different semantics — old configs would silently take the
  new meaning.
- **Renaming** needs a migration step and a deprecation window. Prefer adding a new key and
  leaving the old one reading through.
- When Phase 2 lands the layer system, a preset becomes a layer *beneath* the user layer, so user
  settings continue to win by construction.

## Security note

Never add a config property that stores a credential, PIN, or unlock secret in plaintext.
`shell.json` is readable by any process running as that user — this is exactly the defect in OP's
pattern lock (T3). Secrets need hashing at minimum, and authentication belongs in PAM.

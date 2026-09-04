#pragma once

#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

#define ARG(...) __VA_ARGS__

namespace detail {

// Defined in hybridconfig.cpp, where the preset tables live. `self` is the node holding
// the key, so the lookup can find the selected preset through its parent.
bool presetFeature(const settings::Node* self, const QString& key);
HybridVariant::Enum presetVariant(const settings::Node* self, const QString& key);

} // namespace detail

// A feature or variant with no user value takes the selected preset's (D8).
#define FEATURE(name)                                                                                                  \
    CONFIG_GLOBAL_PROPERTY(bool, name, ARG([](const settings::Node* self) {                                            \
        return detail::presetFeature(self, u## #name##_s);                                                             \
    }))
#define VARIANT(name)                                                                                                  \
    CONFIG_GLOBAL_PROPERTY(caelestia::config::HybridVariant::Enum, name, ARG([](const settings::Node* self) {          \
        return detail::presetVariant(self, u## #name##_s);                                                             \
    }))

// One boolean per feature. This is the workhorse of the hybrid design (D3): the two forks
// are ~90% disjoint, so nearly everything they add is a feature that is either present or
// absent, not a choice between two implementations.
//
// A flag exists here only once something reads it. Four were removed for failing that:
//
//   gpuDetection  upstream ships it unconditionally (Services/gpu.cpp, the GpuType enum).
//                 A toggle for it would be a lie. OP's contribution is enhanced monitoring,
//                 which is a service merge (D5), not a feature.
//   patternLock   never ships as a toggle. It is a lock-screen bypass (D10, trap T3), and
//                 a switch offering to enable it is exactly the wrong artefact. Recorded
//                 in the traps, not in the user's settings schema.
//
// Each flag's *default* is the selected preset's value, resolved through the DefaultSpec
// function above (D8). A user who has never touched a flag follows the preset; one who has
// keeps their own value, because an override is never re-resolved.
//
// Everything here is global: a feature flag per monitor is meaningless.
class HybridFeatures : public settings::ObjectNode {
    CONFIG_NODE(HybridFeatures, settings::ObjectNode)

    FEATURE(dock)
    FEATURE(overview)
    FEATURE(clipboard)
    FEATURE(emojiPicker)
    FEATURE(windowSwitcher)
    FEATURE(keybindViewer)
    FEATURE(videoWallpaper)
    FEATURE(wallhaven)
    FEATURE(floatingLyrics)
    FEATURE(shimeji)
    FEATURE(badApple)
    FEATURE(dino)
    FEATURE(hotspot)
    FEATURE(btAgent)
    FEATURE(themeManager)
};

// The four components both forks genuinely implement. Capped at ~6 entries (D4): growth
// past that means the design is drifting back toward the implementation registry that was
// deliberately rejected.
class HybridVariants : public settings::ObjectNode {
    CONFIG_NODE(HybridVariants, settings::ObjectNode)

    VARIANT(lockCentre)
    VARIANT(audioPopout)
    VARIANT(desktopClock)
    VARIANT(colours)
};

class HybridConfig : public settings::ObjectNode {
    CONFIG_NODE_NO_CTOR(HybridConfig, settings::ObjectNode)
    QML_ANONYMOUS

    // The preset *name* is stored, never its expanded values (D8), so "recommended" can be
    // improved later and existing users receive the improvement. There is no `Custom`
    // enumerator: custom is the computed state when any flag differs from the preset, which
    // QML derives rather than stores.
    CONFIG_GLOBAL_ENUM_PROPERTY(HybridPreset, preset, HybridPreset::Recommended)
    CONFIG_GLOBAL_SUBOBJECT(HybridFeatures, features)
    CONFIG_GLOBAL_SUBOBJECT(HybridVariants, variants)

public:
    explicit HybridConfig(HybridConfig* fallback = nullptr, QObject* parent = nullptr, bool globalOnly = false);
};

#undef FEATURE
#undef VARIANT
#undef ARG

} // namespace caelestia::config

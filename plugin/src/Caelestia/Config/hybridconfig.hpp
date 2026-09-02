#pragma once

#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

// One boolean per imported feature. This is the workhorse of the hybrid design (D3): the
// two forks are ~90% disjoint, so nearly everything they add is a feature that is either
// present or absent, not a choice between two implementations.
//
// Defaults are the "recommended" preset. A preset selects a different set by layering
// underneath the user's config (D8), so a user who has never touched a flag follows the
// preset, and one who has keeps their own value.
//
// Everything here is global: a feature flag per monitor is meaningless.
class HybridFeatures : public settings::ObjectNode {
    CONFIG_NODE(HybridFeatures, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(bool, dock, true)
    CONFIG_GLOBAL_PROPERTY(bool, overview, true)
    CONFIG_GLOBAL_PROPERTY(bool, hotspot, true)
    CONFIG_GLOBAL_PROPERTY(bool, gpuDetection, true)
    CONFIG_GLOBAL_PROPERTY(bool, themeManager, true)
    CONFIG_GLOBAL_PROPERTY(bool, clipboard, true)
    CONFIG_GLOBAL_PROPERTY(bool, emojiPicker, true)
    CONFIG_GLOBAL_PROPERTY(bool, windowSwitcher, true)
    CONFIG_GLOBAL_PROPERTY(bool, keybindViewer, true)
    CONFIG_GLOBAL_PROPERTY(bool, videoWallpaper, true)
    CONFIG_GLOBAL_PROPERTY(bool, wallhaven, true)
    CONFIG_GLOBAL_PROPERTY(bool, floatingLyrics, true)
    CONFIG_GLOBAL_PROPERTY(bool, shimeji, false)
    CONFIG_GLOBAL_PROPERTY(bool, badApple, false)
    CONFIG_GLOBAL_PROPERTY(bool, dino, false)

    // OP's pattern lock is a lock-screen bypass, not a feature (D10, trap T3): its
    // `patternAvailable` is hardcoded true and unlocking calls `lock.unlock()` directly
    // rather than going through PAM. The flag exists so presets can state that it is off;
    // nothing reads it yet, and nothing should until the bypass is gone.
    CONFIG_GLOBAL_PROPERTY(bool, patternLock, false)
};

// The four components both forks genuinely implement. Capped at ~6 entries (D4): growth
// past that means the design is drifting back toward the implementation registry that was
// deliberately rejected.
class HybridVariants : public settings::ObjectNode {
    CONFIG_NODE(HybridVariants, settings::ObjectNode)

    CONFIG_GLOBAL_ENUM_PROPERTY(HybridVariant, lockCentre, HybridVariant::Midnight)
    CONFIG_GLOBAL_ENUM_PROPERTY(HybridVariant, audioPopout, HybridVariant::Op)
    CONFIG_GLOBAL_ENUM_PROPERTY(HybridVariant, desktopClock, HybridVariant::Midnight)
    CONFIG_GLOBAL_ENUM_PROPERTY(HybridVariant, colours, HybridVariant::Midnight)
};

class HybridConfig : public settings::ObjectNode {
    CONFIG_NODE(HybridConfig, settings::ObjectNode)

    // The preset *name* is stored, never its expanded values (D8), so "recommended" can be
    // improved later and existing users receive the improvement. There is no `Custom`
    // enumerator: custom is the computed state when any flag differs from the preset, which
    // QML derives rather than stores.
    CONFIG_GLOBAL_ENUM_PROPERTY(HybridPreset, preset, HybridPreset::Recommended)
    CONFIG_GLOBAL_SUBOBJECT(HybridFeatures, features)
    CONFIG_GLOBAL_SUBOBJECT(HybridVariants, variants)
};

} // namespace caelestia::config

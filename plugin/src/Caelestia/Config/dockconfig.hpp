#pragma once

#include <qstringlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

// OP's dock: a separate auto-hiding panel, as distinct from MiDnight's dock, which is a section
// inside the bar and configured under `bar.dock`. Both are selected by hybrid.variants.dock, so
// both config blocks exist and only the selected one is read.
//
// Ported from OP's ConfigObject-era class to settings::ObjectNode, which is the config system
// upstream rewrote in Phase 2 (D7). The keys and their defaults are unchanged.
class DockConfig : public settings::ObjectNode {
    CONFIG_NODE(DockConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, maxSlots, 5)
    CONFIG_PROPERTY(int, dragThreshold, 50)
    CONFIG_GLOBAL_PROPERTY(QStringList, pinnedApps, QStringList())
};

} // namespace caelestia::config

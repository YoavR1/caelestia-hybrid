#pragma once

#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

class ShimejiConfig : public settings::ObjectNode {
    CONFIG_NODE(ShimejiConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, autoHide, true)
    // Not `path`: settings::Node::path() is non-virtual, and a key of that name shadows
    // it silently (bugprone-derived-method-shadowing-base-method).
    CONFIG_PROPERTY(QString, directory, QStringLiteral("root:/assets/shimeji/pusheen/"))
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
    CONFIG_PROPERTY(int, count, 1)
    CONFIG_PROPERTY(QVariantMap, screenCounts, {})
};

} // namespace caelestia::config

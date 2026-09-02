#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

#include <qstring.h>

namespace caelestia::config {

class ShimejiConfig : public settings::ObjectNode {
    CONFIG_NODE(ShimejiConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(QString, path, QStringLiteral("root:/assets/shimeji/pusheen/"))
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
    CONFIG_PROPERTY(int, count, 1)
    CONFIG_PROPERTY(QVariantMap, screenCounts)};

} // namespace caelestia::config

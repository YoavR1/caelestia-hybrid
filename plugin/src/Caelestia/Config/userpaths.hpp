#pragma once

#include <qstandardpaths.h>
#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

class UserPaths : public settings::ObjectNode {
    CONFIG_NODE(UserPaths, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(
        QString, wallpaperDir, QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + u"/Wallpapers"_s)
    CONFIG_PROPERTY(
        QString, cacheDir, QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + u"/caelestia"_s)
    CONFIG_GLOBAL_PROPERTY(
        QString, lyricsDir, QStandardPaths::writableLocation(QStandardPaths::MusicLocation) + u"/Lyrics/"_s)
    CONFIG_PROPERTY(QString, sessionGif, u"root:/assets/session-sparkle.gif"_s)
    CONFIG_PROPERTY(QString, mediaGif, u"root:/assets/media-sparkle.gif"_s)
    CONFIG_PROPERTY(QString, noNotifsPic, u"root:/assets/no-notifs.png"_s)
    CONFIG_PROPERTY(QString, lockNoNotifsPic, u"root:/assets/no-notifs.png"_s)
};

} // namespace caelestia::config

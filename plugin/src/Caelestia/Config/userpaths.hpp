#pragma once

#include <qstandardpaths.h>
#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

// Lets a lambda default containing commas pass through a macro argument in one piece, as
// hybridconfig.hpp does for the same reason.
#define ARG(...) __VA_ARGS__

namespace detail {

// Defined in userpaths.cpp. `self` is the UserPaths node, so the theme name is read from the
// sibling key rather than passed in.
QString themeAsset(const settings::Node* self, const QString& file, const QString& fallback);

} // namespace detail

// A themed path defaults to the selected theme's copy of `file`, and to `fallback` when no
// theme is selected. Deliberately a *default* rather than a computed read-only value, which is
// what OP made these: a default can still be overridden per key, so a user who wants one
// specific asset from somewhere else keeps that when they switch themes, exactly as an
// explicitly set feature flag survives a preset change (D8). It also means an empty themeName
// is not a special case in every reader -- it is just the fallback.
#define THEMED_PATH(name, file, fallback)                                                                              \
    CONFIG_PROPERTY(QString, name, ARG([](const settings::Node* self) {                                                \
        return detail::themeAsset(self, u##file##_s, u##fallback##_s);                                                 \
    }))

class UserPaths : public settings::ObjectNode {
    CONFIG_NODE_NO_CTOR(UserPaths, settings::ObjectNode)
    // SETTINGS_NODE bundles this with the default constructor; taking the NO_CTOR form to add
    // one drops it, and without it every `Config.paths.*` reader in the tree reports
    // `Type "caelestia::config::UserPaths" ... not found`. HybridConfig carries it for the
    // same reason.
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(
        QString, wallpaperDir, QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + u"/Wallpapers"_s)
    CONFIG_PROPERTY(
        QString, cacheDir, QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + u"/caelestia"_s)
    CONFIG_GLOBAL_PROPERTY(
        QString, lyricsDir, QStandardPaths::writableLocation(QStandardPaths::MusicLocation) + u"/Lyrics/"_s)

    // The selected theme's folder name under assets/themes, or empty for none. The *name* is
    // stored rather than the expanded paths, so a theme's contents can change and existing
    // users get the change -- the same reasoning as D8 for presets.
    CONFIG_PROPERTY(QString, themeName, QString())

    THEMED_PATH(sessionGif, "session.gif", "root:/assets/session-sparkle.gif")
    THEMED_PATH(mediaGif, "media.gif", "root:/assets/media-sparkle.gif")
    THEMED_PATH(noNotifsPic, "notif.png", "root:/assets/no-notifs.png")
    THEMED_PATH(lockNoNotifsPic, "notif.png", "root:/assets/no-notifs.png")

public:
    explicit UserPaths(UserPaths* fallback = nullptr, QObject* parent = nullptr, bool globalOnly = false);
};

#undef THEMED_PATH
#undef ARG

} // namespace caelestia::config

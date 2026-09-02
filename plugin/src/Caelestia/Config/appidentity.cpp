#include <qcoreapplication.h>
#include <qstring.h>

namespace {

using Qt::StringLiterals::operator""_s;

// Quickshell sets applicationName ("quickshell") but not organizationName, and QSettings
// refuses to initialise without both:
//
//   QML Settings at @services/Wallpapers.qml: Failed to initialize QSettings instance.
//   Status code is: 1
//   The following application identifiers have not been set:
//   QList("organizationName", "organizationDomain")
//
// The two files using QtCore's `Settings` -- services/Wallpapers.qml (wallpaper-engine
// volume and silent) and services/WallpaperPauser.qml (its four pause options) -- therefore
// persisted nothing across restarts. Supplying the missing half is the whole fix; an
// explicit `location:` does not help, which is why WallpaperPauser had one and still failed.
//
// Only fills in what is unset, so a host that has its own identity keeps it. See trap T14.
void setAppIdentity() {
    if (QCoreApplication::organizationName().isEmpty())
        QCoreApplication::setOrganizationName(u"caelestia"_s);
    if (QCoreApplication::organizationDomain().isEmpty())
        QCoreApplication::setOrganizationDomain(u"caelestia.dots"_s);
    if (QCoreApplication::applicationName().isEmpty())
        QCoreApplication::setApplicationName(u"caelestia-shell"_s);
}

} // namespace

Q_COREAPP_STARTUP_FUNCTION(setAppIdentity)

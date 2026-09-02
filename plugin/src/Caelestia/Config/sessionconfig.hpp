#pragma once

#include <qmap.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;

// The session menu accepts user-defined buttons: any key under `session.icons` and
// `session.commands` that is not one of the four built-ins becomes an extra button.
//
// Upstream's node API already carries unknown keys through a load/save cycle -- see
// settings::Quarantine, which ObjectNode::syncJson fills and ObjectNode::toJson re-applies
// -- so these classes only have to *observe* them on the way past and expose them to QML.
// Key order is whatever QJsonObject iteration gives, which is alphabetical; see
// hybrid/docs/phase2-upstream-catchup.md for why the pre-merge order-preservation was
// dropped rather than ported.
class SessionIcons : public settings::ObjectNode {
    CONFIG_NODE(SessionIcons, settings::ObjectNode)

    CONFIG_PROPERTY(QString, logout, u"logout"_s)
    CONFIG_PROPERTY(QString, shutdown, u"power_settings_new"_s)
    CONFIG_PROPERTY(QString, hibernate, u"downloading"_s)
    CONFIG_PROPERTY(QString, reboot, u"cached"_s)

public:
    bool syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) override;

    [[nodiscard]] const QMap<QString, QString>& customIcons() const { return m_customIcons; }

    [[nodiscard]] const QStringList& customIconKeys() const { return m_customIconKeys; }

signals:
    void customIconsChanged();

private:
    QMap<QString, QString> m_customIcons;
    QStringList m_customIconKeys;
};

class SessionCommands : public settings::ObjectNode {
    CONFIG_NODE(SessionCommands, settings::ObjectNode)

    CONFIG_PROPERTY(QStringList, logout, { u"logout"_s })
    CONFIG_PROPERTY(QStringList, shutdown, { u"poweroff"_s })
    CONFIG_PROPERTY(QStringList, hibernate, { u"hibernate"_s })
    CONFIG_PROPERTY(QStringList, reboot, { u"reboot"_s })

public:
    bool syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) override;

    [[nodiscard]] const QMap<QString, QStringList>& customCommands() const { return m_customCommands; }

    [[nodiscard]] const QStringList& customCommandKeys() const { return m_customCommandKeys; }

signals:
    void customCommandsChanged();

private:
    QMap<QString, QStringList> m_customCommands;
    QStringList m_customCommandKeys;
};

class SessionConfig : public settings::ObjectNode {
    CONFIG_NODE_NO_CTOR(SessionConfig, settings::ObjectNode)
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, dragThreshold, 30)
    CONFIG_PROPERTY(bool, vimKeybinds, false)
    CONFIG_SUBOBJECT(SessionIcons, icons)
    CONFIG_SUBOBJECT(SessionCommands, commands)

    Q_PROPERTY(QVariantList buttons READ buttons NOTIFY buttonsChanged)
    Q_PROPERTY(QVariantList customButtons READ customButtons NOTIFY buttonsChanged)

public:
    explicit SessionConfig(SessionConfig* fallback = nullptr, QObject* parent = nullptr, bool globalOnly = false);

    // Every button: the four built-ins plus any user-defined key, each resolved to an icon
    // and a command.
    [[nodiscard]] QVariantList buttons() const;
    // Only the user-defined ones.
    [[nodiscard]] QVariantList customButtons() const;

signals:
    void buttonsChanged();

private:
    [[nodiscard]] QVariantList buildButtons(bool customOnly) const;
};

} // namespace caelestia::config

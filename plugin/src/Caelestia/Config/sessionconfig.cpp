#include "sessionconfig.hpp"

#include <qjsonobject.h>
#include <qmetatype.h>
#include <qset.h>

namespace caelestia::config {

namespace {

// The built-in buttons, in the order they are shown when nothing has been customised.
const QStringList& defaultKeys() {
    static const QStringList keys = { u"logout"_s, u"shutdown"_s, u"hibernate"_s, u"reboot"_s };
    return keys;
}

// Split an incoming object into the keys the schema knows about and the ones it does not.
// The unknown ones are what makes a custom button.
template <typename T, typename Convert>
bool collectCustom(const settings::Schema& schema, const QJsonValue& json, QMap<QString, T>& values, QStringList& keys,
    Convert convert) {
    QMap<QString, T> newValues;
    QStringList newKeys;

    if (json.isObject()) {
        const auto obj = json.toObject();
        for (auto it = obj.begin(); it != obj.end(); ++it) {
            newKeys << it.key();
            if (!schema.get(it.key()))
                newValues.insert(it.key(), convert(it.value()));
        }
    }

    if (newValues == values && newKeys == keys)
        return false;

    values = newValues;
    keys = newKeys;
    return true;
}

} // namespace

bool SessionIcons::syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) {
    const auto changed = collectCustom(schema(), json, m_customIcons, m_customIconKeys, [](const QJsonValue& v) {
        return v.toString();
    });

    const auto ok = settings::ObjectNode::syncJson(json, diagnostics);

    if (changed)
        emit customIconsChanged();

    return ok;
}

bool SessionCommands::syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) {
    const auto changed = collectCustom(schema(), json, m_customCommands, m_customCommandKeys, [](const QJsonValue& v) {
        return v.toVariant().toStringList();
    });

    const auto ok = settings::ObjectNode::syncJson(json, diagnostics);

    if (changed)
        emit customCommandsChanged();

    return ok;
}

SessionConfig::SessionConfig(SessionConfig* fallback, QObject* parent, bool globalOnly)
    : settings::ObjectNode(fallback, parent, globalOnly) {
    connect(m_icons, &SessionIcons::customIconsChanged, this, &SessionConfig::buttonsChanged);
    connect(m_commands, &SessionCommands::customCommandsChanged, this, &SessionConfig::buttonsChanged);
}

QVariantList SessionConfig::buttons() const {
    return buildButtons(false);
}

QVariantList SessionConfig::customButtons() const {
    return buildButtons(true);
}

QVariantList SessionConfig::buildButtons(bool customOnly) const {
    // Custom keys first, in the order they appeared, then the built-ins that are left.
    QStringList ordered;
    QSet<QString> seen;

    const auto append = [&ordered, &seen](const QStringList& keys, const QSet<QString>& skip) {
        for (const auto& key : keys) {
            if (!seen.contains(key) && !skip.contains(key)) {
                seen.insert(key);
                ordered << key;
            }
        }
    };

    const auto builtIn = customOnly ? QSet<QString>(defaultKeys().cbegin(), defaultKeys().cend()) : QSet<QString>();
    append(m_icons->customIconKeys(), builtIn);
    append(m_commands->customCommandKeys(), builtIn);
    if (!customOnly)
        append(defaultKeys(), {});

    QVariantList result;
    result.reserve(ordered.size());

    for (const auto& key : std::as_const(ordered)) {
        // A key is either in the schema, where value() resolves it through the fallback
        // layers, or it is custom and only exists in the map built during syncJson.
        QString icon = m_icons->customIcons().value(key, key);
        if (m_icons->schema().get(key)) {
            const auto val = m_icons->value(key);
            if (val.typeId() == QMetaType::QString)
                icon = val.toString();
        }

        QStringList command = m_commands->customCommands().value(key, QStringList{ key });
        if (m_commands->schema().get(key)) {
            const auto val = m_commands->value(key);
            if (val.typeId() == QMetaType::QStringList)
                command = val.toStringList();
        }

        result.append(QVariantMap{
            { u"key"_s, key },
            { u"icon"_s, icon },
            { u"command"_s, QVariant::fromValue(command) },
        });
    }

    return result;
}

} // namespace caelestia::config

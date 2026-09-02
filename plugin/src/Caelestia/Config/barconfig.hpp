#pragma once

#include <qjsonarray.h>
#include <qjsonobject.h>
#include <qmap.h>
#include <qstring.h>
#include <qstringlist.h>
#include <qvariantlist.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::config {

using Qt::StringLiterals::operator""_s;
using settings::vmap;

class BarScrollActions : public settings::ObjectNode {
    CONFIG_NODE(BarScrollActions, settings::ObjectNode)

    CONFIG_PROPERTY(bool, workspaces, true)
    CONFIG_PROPERTY(bool, volume, true)
    CONFIG_PROPERTY(bool, brightness, true)
};

class BarPopouts : public settings::ObjectNode {
    CONFIG_NODE(BarPopouts, settings::ObjectNode)

    CONFIG_PROPERTY(bool, activeWindow, true)
    CONFIG_PROPERTY(bool, tray, true)
    CONFIG_PROPERTY(bool, statusIcons, true)
};

class BarWorkspaces : public settings::ObjectNode {
    CONFIG_NODE(BarWorkspaces, settings::ObjectNode)

    CONFIG_PROPERTY(int, shown, 5)
    CONFIG_PROPERTY(bool, activeIndicator, true)
    CONFIG_PROPERTY(bool, occupiedBg, false)
    CONFIG_PROPERTY(bool, showWindows, true)
    CONFIG_PROPERTY(bool, showWindowsOnSpecialWorkspaces, true)
    CONFIG_PROPERTY(int, maxWindowIcons, 5)
    CONFIG_PROPERTY(bool, activeTrail, false)
    CONFIG_GLOBAL_PROPERTY(bool, perMonitorWorkspaces, true)
    // MiDnight renders workspaces itself (modules/bar/components/workspaces/Workspace.qml),
    // so `useIcon` and a plain-string `capitalisation` stay instead of upstream's
    // BarWorkspaceDisplay / BarWorkspaceCapitalisation enums. Converging on the enums means
    // taking upstream's Workspace.qml too -- see hybrid/docs/phase2-upstream-catchup.md.
    CONFIG_PROPERTY(bool, useIcon, true)
    CONFIG_PROPERTY(QString, label, u" "_s)
    CONFIG_PROPERTY(QString, occupiedLabel, u" 󰮯"_s)
    CONFIG_PROPERTY(QString, activeLabel, u" 󰮯"_s)
    CONFIG_PROPERTY(QString, capitalisation, u"preserve"_s)
    CONFIG_GLOBAL_PROPERTY(QVariantList, specialWorkspaceIcons, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, ignoredTags,
        DEFAULT_ARG({
            u"hide_in_bar"_s,
            u"xwl_popup"_s,
        }))
    CONFIG_GLOBAL_PROPERTY(QVariantList, windowIcons,
        DEFAULT_ARG({
            vmap({
                { u"regex"_s, u"steam(_app_(default|[0-9]+))?"_s },
                { u"icon"_s, u"sports_esports"_s },
            }),
        }))
    CONFIG_GLOBAL_PROPERTY(QVariantList, wsIcons, {})
};

class BarActiveWindow : public settings::ObjectNode {
    CONFIG_NODE(BarActiveWindow, settings::ObjectNode)

    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, showOnHover, true)
};

class BarTray : public settings::ObjectNode {
    CONFIG_NODE(BarTray, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, recolour, false)
    CONFIG_PROPERTY(bool, compact, false)
    CONFIG_GLOBAL_PROPERTY(QVariantList, iconSubs, {})
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenIcons, {})
};

class BarClock : public settings::ObjectNode {
    CONFIG_NODE(BarClock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showDate, false)
    CONFIG_PROPERTY(bool, showIcon, true)
};

class BarDock : public settings::ObjectNode {
    CONFIG_NODE(BarDock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, monitorCenter, true)
    CONFIG_PROPERTY(bool, recolourIcons, false)
};

class BarGithub : public settings::ObjectNode {
    CONFIG_NODE(BarGithub, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
};

class BarSpotify : public settings::ObjectNode {
    CONFIG_NODE(BarSpotify, settings::ObjectNode)

    CONFIG_PROPERTY(bool, background, false)
    CONFIG_PROPERTY(bool, showVisualiser, true)
    CONFIG_PROPERTY(int, maxTitleLength, 25)
    CONFIG_PROPERTY(bool, inverted, false)
    CONFIG_PROPERTY(bool, horizontalVolume, false)
    CONFIG_PROPERTY(bool, autoHide, false)
};

// Bar entries split into three anchored sections. `start` hugs the top/left edge,
// `center` sits at the monitor centre and `end` hugs the bottom/right edge.
class BarSections : public settings::ObjectNode {
    CONFIG_NODE(BarSections, settings::ObjectNode)

    CONFIG_LIST(EntryList, start,
        DEFAULT_ARG({
            LIST_ENTRY(logo, true),
            LIST_ENTRY(workspaces, true),
        }))
    CONFIG_LIST(EntryList, center,
        DEFAULT_ARG({
            LIST_ENTRY(activeWindow, true),
        }))
    CONFIG_LIST(EntryList, end,
        DEFAULT_ARG({
            LIST_ENTRY(tray, true),
            LIST_ENTRY(clock, true),
            LIST_ENTRY(statusIcons, true),
            LIST_ENTRY(power, true),
        }))

public:
    bool syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) override;
};

// Migrates the legacy flat `bar.entries` array into the three section lists. Only
// components part of the new default layout are kept, preserving their enabled state.
// Migrates the legacy flat `bar.entries` array into the three section lists. Only
// components part of the new default layout are kept, preserving their enabled state.
// Rewritten onto settings::ObjectNode::syncJson: rather than loading each list by hand and
// marking it visited, build the object the base class would have been given and delegate.
inline bool BarSections::syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) {
    if (!json.isArray())
        return settings::ObjectNode::syncJson(json, diagnostics);

    QMap<QString, bool> enabledById;
    for (const auto& value : json.toArray()) {
        const auto obj = value.toObject();
        enabledById.insert(obj.value(u"id"_s).toString(), obj.value(u"enabled"_s).toBool());
    }

    const auto migrated = [&enabledById](const QVariantList& entries) {
        QVariantList result;
        for (const auto& value : entries) {
            auto props = value.toMap();
            const auto id = props.value(u"id"_s).toString();
            if (enabledById.contains(id))
                props.insert(u"enabled"_s, enabledById.value(id));
            result.append(props);
        }
        return result;
    };

    QJsonObject sections;
    sections.insert(u"start"_s, QJsonArray::fromVariantList(migrated({
                                    LIST_ENTRY(logo, true),
                                    LIST_ENTRY(workspaces, true),
                                })));
    sections.insert(u"center"_s, QJsonArray::fromVariantList(migrated({
                                     LIST_ENTRY(activeWindow, true),
                                 })));
    sections.insert(u"end"_s, QJsonArray::fromVariantList(migrated({
                                  LIST_ENTRY(tray, true),
                                  LIST_ENTRY(clock, true),
                                  LIST_ENTRY(statusIcons, true),
                                  LIST_ENTRY(power, true),
                              })));

    return settings::ObjectNode::syncJson(sections, diagnostics);
}

class BarConfig : public settings::ObjectNode {
    CONFIG_NODE(BarConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, persistent, true)
    CONFIG_PROPERTY(bool, showOnHover, true)
    CONFIG_PROPERTY(int, dragThreshold, 20)
    CONFIG_PROPERTY(QString, position, u"left"_s)
    CONFIG_SUBOBJECT(BarScrollActions, scrollActions)
    CONFIG_SUBOBJECT(BarPopouts, popouts)
    CONFIG_SUBOBJECT(BarWorkspaces, workspaces)
    CONFIG_SUBOBJECT(BarActiveWindow, activeWindow)
    CONFIG_SUBOBJECT(BarTray, tray)
    CONFIG_SUBOBJECT(BarClock, clock)
    CONFIG_SUBOBJECT(BarDock, dock)
    CONFIG_SUBOBJECT(BarGithub, github)
    CONFIG_SUBOBJECT(BarSpotify, spotify)
    CONFIG_LIST(EntryList, statusIcons,
        DEFAULT_ARG({
            LIST_ENTRY(lockStatus, true),
            LIST_ENTRY(audio, false),
            LIST_ENTRY(microphone, false),
            LIST_ENTRY(kbLayout, false),
            LIST_ENTRY(network, true),
            LIST_ENTRY(bluetooth, true),
            LIST_ENTRY(battery, true),
            LIST_ENTRY(peripheralBattery, false),
            LIST_ENTRY(notifications, true),
        }))
    // MiDnight splits the bar into start/center/end sections; BarSections::syncJson
    // migrates upstream's flat `bar.entries` array into them.
    CONFIG_SUBOBJECT(BarSections, entries)
    CONFIG_PROPERTY(QStringList, excludedScreens, {})
    CONFIG_PROPERTY(QStringList, peripheralBatteryExcluded, {})
};

} // namespace caelestia::config

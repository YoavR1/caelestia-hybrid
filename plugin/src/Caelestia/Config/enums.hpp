#pragma once

#include <qobject.h>
#include <qqmlintegration.h>

namespace caelestia::config {

#define ENUM(Name, ...)                                                                                                \
    namespace Name {                                                                                                   \
                                                                                                                       \
    Q_NAMESPACE                                                                                                        \
    QML_ELEMENT                                                                                                        \
                                                                                                                       \
    enum Enum : quint8 {                                                                                               \
        __VA_ARGS__                                                                                                    \
    };                                                                                                                 \
    Q_ENUM_NS(Enum)                                                                                                    \
                                                                                                                       \
    };

ENUM(BarWorkspaceDisplay, Shapes, Text)
ENUM(BarWorkspaceCapitalisation, Preserve, Upper, Lower)
ENUM(LyricsBackend, Auto, Local, LRCLIB, NetEase)
// Intel is appended rather than slotted next to Nvidia. Config serialises enums by name
// (EnumCodec), so position is free there -- but modules/nexus/pages/ServicesPage.qml keeps a
// MenuItem list indexed by ordinal, and appending keeps every existing index correct.
ENUM(GpuType, Auto, Nvidia, Generic, None, Intel)
ENUM(NotifsFullscreen, On, Off)

// Which fork's implementation to use for one of the four genuine overlaps (D3/D4).
ENUM(HybridVariant, Midnight, Op)
// `custom` is deliberately absent -- it is computed, not stored (D8).
ENUM(HybridPreset, Recommended, Midnight, Op)

#undef ENUM

} // namespace caelestia::config

import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool workspaceDrawer

    // OP's overview is a separate top-level Scope with its own visibility flag, rather than a
    // panel inside modules/drawers. Both implementations of hybrid.variants.overview therefore
    // have their own state; the shortcut and IPC set whichever the variant selects.
    property bool overview

    // OP's dock is a drawer panel with its own visibility, like the others here. MiDnight's is a
    // bar section and has none -- it is simply part of the bar. hybrid.variants.dock selects
    // between them, and this also makes `qs ipc call drawers toggle dock` work.
    property bool dock

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}

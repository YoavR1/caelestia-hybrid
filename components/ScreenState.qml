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

    // OP's dock is a drawer panel with its own visibility, like the others here. MiDnight's is a
    // bar section and has none -- it is simply part of the bar. hybrid.variants.dock selects
    // between them.
    property bool dock

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}

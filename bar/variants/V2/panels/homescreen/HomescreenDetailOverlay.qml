import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// ── DETAIL OVERLAY (Phone-style sub-page sheet) ──
Item {
    id: detailOverlay
    required property var dashboardContent
    required property var root
    required property var panel

    readonly property var wifiDetailSection: wifiDetailLoader.item
    readonly property var btDetailSection: btDetailLoader.item
    readonly property var batDetailSection: batDetailLoader.item
    readonly property var stDetailSection: stDetailLoader.item
    readonly property var volDetailSection: volDetailLoader.item
    readonly property var sysDetailSection: sysDetailLoader.item
    readonly property var calDetailSection: calDetailLoader.item
    readonly property var notifDetailSection: notifDetailLoader.item
    readonly property var updatesDetailSection: updatesDetailLoader.item
    readonly property var notesDetailSection: notesDetailLoader.item
    readonly property var pluginsDetailSection: pluginsDetailLoader.item
    readonly property var themeDetailSection: themeLoader.item

    visible: (opacity > 0.001)
    opacity: dashboardContent.activeDetailView !== "" ? 1.0 : 0.0
    scale: dashboardContent.activeDetailView !== "" ? 1.0 : 0.98
    transform: Translate {
        y: dashboardContent.activeDetailView !== "" ? 0 : (root && root.barPosition === "bottom" ? 14 : -14)
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    z: 10

    // Subpage Header Bar
    Item {
        id: detailHeaderBar
        width: parent.width
        height: 0
        visible: false
        anchors.top: parent.top

        // Back button pill
        Rectangle {
            id: detailBackBtn
            height: 32
            width: backContentRow.width + 16
            radius: 16
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: detailBackMa.containsMouse ? root.fillHover : root.fillIdle
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: backContentRow
                anchors.centerIn: parent
                spacing: 5
                IconText {
                    text: "arrow_back"
                    color: root.ink
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Back"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            SpringPress {}
            MouseArea {
                id: detailBackMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }
        }

        // Section Title
        Text {
            anchors.centerIn: parent
            text: {
                switch (dashboardContent.activeDetailView) {
                    case "wifi": return "Wi-Fi & Network"
                    case "bluetooth": return "Bluetooth"
                    case "battery": return "Battery & Power"
                    case "screentime": return "Screen Time"
                    case "volume": return "Sound & Volume"
                    case "system": return "System & Power"
                    case "calendar": return "Calendar & Notes"
                    case "notifications": return "Notifications"
                    case "updates": return "Software Updates"
                    case "packages": return "Software Updates"
                    case "theme": return "Themes"
                    case "wallpaper": return "Wallpapers"
                    case "plugins": return "Omarchy Plugins"
                    case "notes": return "Notes"
                    default: return ""
                }
            }
            color: root.ink
            font.family: root.barFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        // Close button
        Rectangle {
            width: 32
            height: 32
            radius: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: detailCloseMa.containsMouse ? root.fillHover : root.fillIdle
            Behavior on color { ColorAnimation { duration: 150 } }

            IconText {
                anchors.centerIn: parent
                text: "close"
                color: root.ink
                font.pixelSize: 16
            }

            SpringPress {}
            MouseArea {
                id: detailCloseMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }
        }
    }

    // Subpage Content Area
    Item {
        id: detailContentArea
        anchors.fill: parent
        clip: true

        component DetailLoader: Loader {
            required property string viewName
            anchors.fill: parent
            active: dashboardContent.activeDetailView === viewName
            visible: active
            Connections {
                target: item
                ignoreUnknownSignals: true
                function onCloseRequested() {
                    dashboardContent.activeDetailView = ""
                    if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                }
            }
        }

        DetailLoader { id: wifiDetailLoader;  viewName: "wifi";          sourceComponent: WifiDetailSection          { root: dashboardContent.root; panel: dashboardContent.panel } }
        DetailLoader { id: btDetailLoader;    viewName: "bluetooth";     sourceComponent: BluetoothDetailSection     { root: dashboardContent.root; panel: dashboardContent.panel } }
        DetailLoader { id: batDetailLoader;   viewName: "battery";       sourceComponent: BatteryDetailSection       { root: dashboardContent.root; panel: dashboardContent.panel } }
        DetailLoader { id: stDetailLoader;    viewName: "screentime";    sourceComponent: ScreentimeDetailSection    { root: dashboardContent.root; panel: dashboardContent.panel } }
        DetailLoader { id: volDetailLoader;   viewName: "volume";        sourceComponent: VolumeDetailSection        { root: dashboardContent.root; panel: dashboardContent.panel } }
        DetailLoader {
            id: sysDetailLoader
            viewName: "system"
            onLoaded: if (item) item.forceActiveFocus()
            sourceComponent: SystemDetailSection { root: dashboardContent.root; panel: dashboardContent.panel }
        }
        DetailLoader {
            id: pluginsDetailLoader
            viewName: "plugins"
            onLoaded: if (item) item.forceActiveFocus()
            sourceComponent: PluginsDetailSection { root: dashboardContent.root; panel: dashboardContent.panel }
        }
        DetailLoader { id: calDetailLoader;   viewName: "calendar";      sourceComponent: CalendarDetailSection      { root: dashboardContent.root; panel: dashboardContent.panel } }
        DetailLoader {
            id: notifDetailLoader
            viewName: "notifications"
            sourceComponent: NotificationDetailSection {
                root: dashboardContent.root
                panel: dashboardContent.panel
            }
        }
        DetailLoader {
            id: updatesDetailLoader
            viewName: "updates"
            active: dashboardContent.activeDetailView === "updates" || dashboardContent.activeDetailView === "packages"
            sourceComponent: UpdatesDetailSection {
                root: dashboardContent.root
                panel: dashboardContent.panel
            }
        }
        DetailLoader {
            id: notesDetailLoader
            viewName: "notes"
            onLoaded: if (item) item.forceActiveFocus()
            sourceComponent: NotesDetailSection {
                root: dashboardContent.root
                panel: dashboardContent.panel
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                }
            }
        }
        DetailLoader {
            id: themeLoader
            viewName: "theme"
            active: dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper"
            visible: active
            onLoaded: if (item) item.forceActiveFocus()
            sourceComponent: ThemeWallpaperSwitcher {
                root: dashboardContent.root
                panel: dashboardContent.panel
                activeMode: dashboardContent.activeDetailView === "wallpaper" ? "wallpaper" : "theme"
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (dashboardContent.root) {
                        dashboardContent.root.dashboardDetail = ""
                        dashboardContent.root.dashboardExpanded = false
                    }
                }
            }
        }
    }
}

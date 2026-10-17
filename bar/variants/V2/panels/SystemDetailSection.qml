import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: systemSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property int focusedIndex: 0

    // Material 3 Expressive geometric vector paths (normalized to 64x64 box)
    readonly property string pathFlower: "M 62.5 32.0 L 62.1 35.0 L 61.1 37.8 L 59.4 40.3 L 57.1 42.4 L 54.4 44.0 L 51.3 44.9 L 48.1 45.2 L 44.7 44.7 L 45.2 48.1 L 44.9 51.3 L 44.0 54.4 L 42.4 57.1 L 40.3 59.4 L 37.8 61.1 L 35.0 62.1 L 32.0 62.5 L 29.0 62.1 L 26.2 61.1 L 23.7 59.4 L 21.6 57.1 L 20.0 54.4 L 19.1 51.3 L 18.8 48.1 L 19.3 44.7 L 15.9 45.2 L 12.7 44.9 L 9.6 44.0 L 6.9 42.4 L 4.6 40.3 L 2.9 37.8 L 1.9 35.0 L 1.5 32.0 L 1.9 29.0 L 2.9 26.2 L 4.6 23.7 L 6.9 21.6 L 9.6 20.0 L 12.7 19.1 L 15.9 18.8 L 19.3 19.3 L 18.8 15.9 L 19.1 12.7 L 20.0 9.6 L 21.6 6.9 L 23.7 4.6 L 26.2 2.9 L 29.0 1.9 L 32.0 1.5 L 35.0 1.9 L 37.8 2.9 L 40.3 4.6 L 42.4 6.9 L 44.0 9.6 L 44.9 12.7 L 45.2 15.9 L 44.7 19.3 L 48.1 18.8 L 51.3 19.1 L 54.4 20.0 L 57.1 21.6 L 59.4 23.7 L 61.1 26.2 L 62.1 29.0 Z"
    readonly property string pathArch: "M 2 32 A 30 30 0 0 1 62 32 L 62 46 A 16 16 0 0 1 46 62 L 18 62 A 16 16 0 0 1 2 46 Z"
    readonly property string pathScallop: "M 62.5 32.0 L 61.9 34.9 L 60.0 37.6 L 57.3 39.7 L 54.2 41.2 L 55.4 44.5 L 55.8 47.9 L 55.2 51.0 L 53.6 53.6 L 51.0 55.2 L 47.9 55.8 L 44.5 55.4 L 41.2 54.2 L 39.7 57.3 L 37.6 60.0 L 34.9 61.9 L 32.0 62.5 L 29.1 61.9 L 26.4 60.0 L 24.3 57.3 L 22.8 54.2 L 19.5 55.4 L 16.1 55.8 L 13.0 55.2 L 10.4 53.6 L 8.8 51.0 L 8.2 47.9 L 8.6 44.5 L 9.8 41.2 L 6.7 39.7 L 4.0 37.6 L 2.1 34.9 L 1.5 32.0 L 2.1 29.1 L 4.0 26.4 L 6.7 24.3 L 9.8 22.8 L 8.6 19.5 L 8.2 16.1 L 8.8 13.0 L 10.4 10.4 L 13.0 8.8 L 16.1 8.2 L 19.5 8.6 L 22.8 9.8 L 24.3 6.7 L 26.4 4.0 L 29.1 2.1 L 32.0 1.5 L 34.9 2.1 L 37.6 4.0 L 39.7 6.7 L 41.2 9.8 L 44.5 8.6 L 47.9 8.2 L 51.0 8.8 L 53.6 10.4 L 55.2 13.0 L 55.8 16.1 L 55.4 19.5 L 54.2 22.8 L 57.3 24.3 L 60.0 26.4 L 61.9 29.1 Z"
    readonly property string pathStar: "M 48.0 32.0 L 48.5 33.6 L 49.8 35.5 L 51.7 38.0 L 53.7 41.0 L 55.3 44.4 L 55.9 48.0 L 55.5 51.3 L 53.9 53.9 L 51.3 55.5 L 48.0 55.9 L 44.4 55.3 L 41.0 53.7 L 38.0 51.7 L 35.5 49.8 L 33.6 48.5 L 32.0 48.0 L 30.4 48.5 L 28.5 49.8 L 26.0 51.7 L 23.0 53.7 L 19.6 55.3 L 16.0 55.9 L 12.7 55.5 L 10.1 53.9 L 8.5 51.3 L 8.1 48.0 L 8.7 44.4 L 10.3 41.0 L 12.3 38.0 L 14.2 35.5 L 15.5 33.6 L 16.0 32.0 L 15.5 30.4 L 14.2 28.5 L 12.3 26.0 L 10.3 23.0 L 8.7 19.6 L 8.1 16.0 L 8.5 12.7 L 10.1 10.1 L 12.7 8.5 L 16.0 8.1 L 19.6 8.7 L 23.0 10.3 L 26.0 12.3 L 28.5 14.2 L 30.4 15.5 L 32.0 16.0 L 33.6 15.5 L 35.5 14.2 L 38.0 12.3 L 41.0 10.3 L 44.4 8.7 L 48.0 8.1 L 51.3 8.5 L 53.9 10.1 L 55.5 12.7 L 55.9 16.0 L 55.3 19.6 L 53.7 23.0 L 51.7 26.0 L 49.8 28.5 L 48.5 30.4 Z"

    readonly property var options: [
        {
            name: "Screensaver",
            icon: "wallpaper",
            accent: (root && root.color06) ? root.color06 : "#7aa89f",
            path: pathFlower,
            keyTag: "S"
        },
        {
            name: "Lock",
            icon: "lock",
            accent: (root && root.color04) ? root.color04 : "#658594",
            path: pathArch,
            keyTag: "L"
        },
        {
            name: "Shutdown",
            icon: "power_settings_new",
            accent: (root && root.color01) ? root.color01 : "#c4746e",
            path: pathScallop,
            keyTag: "P"
        },
        {
            name: "Reboot",
            icon: "restart_alt",
            accent: (root && root.color03) ? root.color03 : "#c8b36a",
            path: pathStar,
            keyTag: "R"
        }
    ]

    function triggerOption(index) {
        if (root) root.dashboardExpanded = false
        closeRequested()
        switch (index) {
            case 0: // Screensaver
                Quickshell.execDetached(["bash", "-c", "omarchy-launch-screensaver 2>/dev/null || omarchy-screensaver 2>/dev/null"])
                break
            case 1: // Lock
                Quickshell.execDetached(["bash", "-c", "$HOME/.config/hypr/scripts/custom-lock.sh 2>/dev/null || loginctl lock-session || hyprlock"])
                break
            case 2: // Shutdown
                Quickshell.execDetached(["systemctl", "poweroff"])
                break
            case 3: // Reboot
                Quickshell.execDetached(["systemctl", "reboot"])
                break
        }
    }

    focus: visible
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_1 || event.key === Qt.Key_S) {
            triggerOption(0)
            event.accepted = true
        } else if (event.key === Qt.Key_2 || event.key === Qt.Key_L) {
            triggerOption(1)
            event.accepted = true
        } else if (event.key === Qt.Key_3 || event.key === Qt.Key_P) {
            triggerOption(2)
            event.accepted = true
        } else if (event.key === Qt.Key_4 || event.key === Qt.Key_R) {
            triggerOption(3)
            event.accepted = true
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            focusedIndex = (focusedIndex === 1) ? 0 : ((focusedIndex === 3) ? 2 : focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            focusedIndex = (focusedIndex === 0) ? 1 : ((focusedIndex === 2) ? 3 : focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            focusedIndex = (focusedIndex === 2) ? 0 : ((focusedIndex === 3) ? 1 : focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            focusedIndex = (focusedIndex === 0) ? 2 : ((focusedIndex === 1) ? 3 : focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            triggerOption(focusedIndex)
            event.accepted = true
        }
    }

    // Dismiss submenu when clicking outside the dialog card
    MouseArea {
        id: backdropMa
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: Qt.ArrowCursor
        onClicked: systemSection.closeRequested()
    }

    // Material 3 Expressive Power Dialog Card
    Rectangle {
        id: dialogCard
        anchors.centerIn: parent
        width: 250
        height: 216
        radius: 28
        color: (root && root.ink) ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04) : "transparent"

        // 2x2 Action Button Grid
        Grid {
            id: actionGrid
            anchors.centerIn: parent
            columns: 2
            rowSpacing: 16
            columnSpacing: 36

            Repeater {
                model: systemSection.options

                Item {
                    id: actionItem
                    width: 72
                    height: 88

                    readonly property var opt: modelData
                    readonly property bool isSelected: systemSection.focusedIndex === index
                    readonly property bool isHovered: itemMa.containsMouse

                    // Creative Geometric M3 Shape Button
                    Item {
                        id: shapeContainer
                        width: 64
                        height: 64
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        scale: (actionItem.isHovered || actionItem.isSelected) ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                        Shape {
                            id: m3Shape
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: 0
                                strokeColor: "transparent"
                                fillColor: (actionItem.isHovered || actionItem.isSelected)
                                    ? actionItem.opt.accent
                                    : Qt.rgba(actionItem.opt.accent.r, actionItem.opt.accent.g, actionItem.opt.accent.b, 0.20)
                                Behavior on fillColor { ColorAnimation { duration: 160 } }

                                PathSvg {
                                    path: actionItem.opt.path
                                }
                            }
                        }

                        IconText {
                            anchors.centerIn: parent
                            text: actionItem.opt.icon
                            font.pixelSize: 26
                            color: (actionItem.isHovered || actionItem.isSelected)
                                ? (root ? root.paper : "#181825")
                                : actionItem.opt.accent
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }
                    }

                    // Button Title Label (No description, no borders)
                    Text {
                        anchors.top: shapeContainer.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: actionItem.opt.name
                        color: root ? root.ink : "#ffffff"
                        font.family: root ? root.barFont : "sans-serif"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        opacity: (actionItem.isHovered || actionItem.isSelected) ? 1.0 : 0.85
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: systemSection.triggerOption(index)
                        onEntered: systemSection.focusedIndex = index
                    }
                }
            }
        }
    }
}

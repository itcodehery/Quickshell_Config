import QtQuick
import ".."
import "../../modules"

Column {
    id: headerCol
    required property var archPanel
    readonly property var root: archPanel.root

    width: parent.width
    spacing: 10

    // ── badge toggle chip ──
    component BadgeChip: Rectangle {
        id: _bc
        property string label
        property bool active: false
        signal toggled()
        height: 26
        radius: height / 2
        color: active
            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, _bcMa.containsMouse ? 0.35 : 0.22)
            : (_bcMa.containsMouse ? archPanel.chipHover : archPanel.chipBg)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: _bc.active ? root.seal : root.sumi
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _bc.label
                color: _bc.active ? root.ink : root.sumi
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: _bc.active ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: _bcMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: _bc.toggled()
        }
    }

    // ── header ──
    Item {
        width: parent.width
        height: 40

        // Left: Squircle Icon + Title & Subtitle (Control Center style)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 38; height: 38; radius: 13
                anchors.verticalCenter: parent.verticalCenter
                color: archPanel.chipBg
                IconText {
                    anchors.centerIn: parent
                    text: "system_update"
                    color: root.seal
                    font.pixelSize: 20
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                UiText {
                    text: "Updates"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                UiText {
                    text: "Software & system updates"
                    color: root.sumiHi
                    font.family: root.barFont
                    font.pixelSize: 10
                }
            }
        }

        // Right: Badge toggles + Close Button
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Badges:"
                color: root.sumiHi
                font.family: root.barFont
                font.pixelSize: 10
                font.weight: Font.Medium
                rightPadding: 2
            }

            BadgeChip {
                width: 50
                label: "PKG"
                active: root.archBadgePackages
                onToggled: root.archBadgePackages = !root.archBadgePackages
            }
            BadgeChip {
                width: 68
                label: "Themes"
                active: root.archBadgeThemes
                onToggled: root.archBadgeThemes = !root.archBadgeThemes
            }
            BadgeChip {
                width: 56
                label: "Shell"
                active: root.archBadgeShell
                onToggled: root.archBadgeShell = !root.archBadgeShell
            }

            Item { width: 4; height: 1 }

            Rectangle {
                id: closeBtn
                width: 32; height: 32; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: closeMa.containsMouse ? archPanel.chipHover : archPanel.chipBg
                Behavior on color { ColorAnimation { duration: 120 } }
                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    color: closeMa.containsMouse ? root.seal : root.ink
                    font.pixelSize: 16
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: archPanel.closeOrCancelRemove()
                }
            }
        }
    }

    // ── Segmented Tab Switcher (Control Center style) ──
    Rectangle {
        width: parent.width
        height: 38
        radius: 19
        color: archPanel.cardBg

        Row {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: [
                    { id: "packages", label: "Packages", badge: root.archUpdates.length },
                    { id: "themes",   label: "Themes",   badge: root.themeUpdOutdated },
                    { id: "shell",    label: "Shell",    badge: root.shellUpdateBehind }
                ]

                Rectangle {
                    id: tabBtn
                    required property var modelData
                    width: root.evenW((parent.width - 8) / 3)
                    height: parent.height
                    radius: height / 2

                    readonly property bool active: root.activeUpdateTab === modelData.id
                    readonly property color fgColor: active ? root.paper : (tabMa.containsMouse ? root.seal : root.ink)

                    color: active
                        ? (tabMa.containsMouse ? Qt.lighter(root.seal, 1.08) : root.seal)
                        : (tabMa.containsMouse ? archPanel.chipHover : "transparent")
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tabBtn.modelData.label
                            color: tabBtn.fgColor
                            font.family: root.barFont
                            font.pixelSize: 13
                            font.weight: tabBtn.active ? Font.DemiBold : Font.Medium
                        }

                        Rectangle {
                            visible: tabBtn.modelData.badge > 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(18, badgeTxt.implicitWidth + 8)
                            height: 18
                            radius: 9
                            color: tabBtn.active
                                ? Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.22)
                                : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2)
                            UiText {
                                id: badgeTxt
                                anchors.centerIn: parent
                                text: String(tabBtn.modelData.badge)
                                color: tabBtn.fgColor
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }

                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeUpdateTab = tabBtn.modelData.id
                    }
                }
            }
        }
    }
}

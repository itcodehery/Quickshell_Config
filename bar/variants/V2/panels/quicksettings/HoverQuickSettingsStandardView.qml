import QtQuick
import ".."
import Quickshell
import "../../modules"

// ── Standard Quick Settings View: Single Compact Row ──
Row {
    id: standardQuickView
    required property var hoverPanel

    spacing: 6
    visible: opacity > 0.001
    opacity: hoverPanel.omarchyMenuOpen ? 0.0 : 1.0
    scale: hoverPanel.omarchyMenuOpen ? 0.95 : 1.0
    enabled: !hoverPanel.omarchyMenuOpen
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property real cardW: Math.floor((width - spacing) / 2)
    readonly property color accentFg: {
        var a = hoverPanel.accent
        var l = 0.299 * a.r + 0.587 * a.g + 0.114 * a.b
        return l > 0.55 ? "#121212" : "#ffffff"
    }

    // 1. GitHub Heatmap Card (Single Row Tile)
    Rectangle {
        id: btnHeatmap
        width: standardQuickView.cardW
        height: parent.height
        radius: 12
        readonly property bool isActive: hoverPanel.omarchyMenuOpen && hoverPanel.omarchyTab === 1
        color: isActive
            ? (hmHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
            : (hmHov.hovered
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06))
        border.width: 1
        border.color: isActive ? "transparent" : hoverPanel.root.cardBorderColor
        scale: hmHov.hovered ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 9
                color: btnHeatmap.isActive
                    ? Qt.rgba(standardQuickView.accentFg.r, standardQuickView.accentFg.g, standardQuickView.accentFg.b, 0.20)
                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    anchors.centerIn: parent
                    text: String.fromCodePoint(0xF09B) // GitHub icon
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 15
                    color: btnHeatmap.isActive ? standardQuickView.accentFg : hoverPanel.root.ink
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "GitHub"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: btnHeatmap.isActive ? standardQuickView.accentFg : hoverPanel.root.ink
                }

                Text {
                    text: "Activity heatmap"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: btnHeatmap.isActive
                        ? Qt.rgba(standardQuickView.accentFg.r, standardQuickView.accentFg.g, standardQuickView.accentFg.b, 0.8)
                        : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.55)
                }
            }
        }

        HoverHandler { id: hmHov; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (hoverPanel.omarchyMenuOpen && hoverPanel.omarchyTab === 1) {
                    hoverPanel.omarchyMenuOpen = false
                    hoverPanel.omarchyTab = 0
                } else {
                    hoverPanel.omarchyMenuOpen = true
                    hoverPanel.omarchyTab = 1
                }
            }
        }
    }

    // 2. Notes Card (Single Row Tile)
    Rectangle {
        id: notesCard
        property bool active: hoverPanel.root.dashboardExpanded && hoverPanel.root.dashboardDetail === "notes"
        width: standardQuickView.cardW
        height: parent.height
        radius: 12
        color: notesCardHov.hovered
            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
        border.width: 1
        border.color: active ? hoverPanel.accent : hoverPanel.root.cardBorderColor
        scale: notesCardHov.hovered ? 1.02 : 1.0
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 28
                height: 28
                radius: 9
                color: notesCard.active
                    ? hoverPanel.accent
                    : (notesCardHov.hovered
                        ? Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.22)
                        : Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.14))
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 140 } }

                IconText {
                    anchors.centerIn: parent
                    text: "\uE150"
                    font.pixelSize: 14
                    color: notesCard.active ? standardQuickView.accentFg : hoverPanel.accent
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Notes"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: hoverPanel.root.ink
                }

                Text {
                    text: "Dashboard notes"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.55)
                }
            }
        }

        HoverHandler { id: notesCardHov; cursorShape: Qt.PointingHandCursor }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                hoverPanel.root.dashboardExpanded = true
                hoverPanel.root.dashboardDetail = "notes"
            }
        }
    }
}

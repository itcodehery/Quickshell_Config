import QtQuick
import ".."
import Quickshell
import "../../modules"

// ── Omarchy Controls View: Single Compact Row ──
Item {
    id: omarchyView
    required property var hoverPanel

    readonly property color accentFg: {
        var a = hoverPanel.accent
        var l = 0.299 * a.r + 0.587 * a.g + 0.114 * a.b
        return l > 0.55 ? "#121212" : "#ffffff"
    }

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: hoverPanel.omarchyMenuOpen ? 1.0 : 0.0
    scale: hoverPanel.omarchyMenuOpen ? 1.0 : 0.95
    enabled: hoverPanel.omarchyMenuOpen
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    // Single-Row Settings View (when omarchyTab !== 1)
    Row {
        anchors.fill: parent
        spacing: 6
        visible: hoverPanel.omarchyTab !== 1

        // 1. Position Chip
        Rectangle {
            height: parent.height
            width: 72
            radius: 12
            color: posHov.hovered
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor
            scale: posHov.hovered ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Row {
                anchors.centerIn: parent
                spacing: 4
                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hoverPanel.root.barPosition === "bottom" ? "vertical_align_bottom" : "vertical_align_top"
                    font.pixelSize: 13
                    color: hoverPanel.root.ink
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hoverPanel.root.barPosition === "bottom" ? "Bottom" : "Top"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: hoverPanel.root.ink
                }
            }
            HoverHandler { id: posHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: hoverPanel.root.barPosition = hoverPanel.root.barPosition === "bottom" ? "top" : "bottom"
            }
        }

        // 2. Bar Border Chip
        Rectangle {
            height: parent.height
            width: 76
            radius: 12
            color: hoverPanel.root.barBorderEnabled
                ? (bbHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                : (bbHov.hovered
                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
            border.width: 1
            border.color: hoverPanel.root.barBorderEnabled ? "transparent" : hoverPanel.root.cardBorderColor
            scale: bbHov.hovered ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Row {
                anchors.centerIn: parent
                spacing: 4
                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "border_outer"
                    font.pixelSize: 13
                    color: hoverPanel.root.barBorderEnabled ? omarchyView.accentFg : hoverPanel.root.ink
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Border"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: hoverPanel.root.barBorderEnabled ? omarchyView.accentFg : hoverPanel.root.ink
                }
            }
            HoverHandler { id: bbHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: hoverPanel.root.barBorderEnabled = !hoverPanel.root.barBorderEnabled
            }
        }

        // 3. Project Chip
        Rectangle {
            height: parent.height
            width: 76
            radius: 12
            color: hoverPanel.projectActive
                ? (projHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                : (projHov.hovered
                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
            border.width: 1
            border.color: hoverPanel.projectActive ? "transparent" : hoverPanel.root.cardBorderColor
            scale: projHov.hovered ? 1.03 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }

            Row {
                anchors.centerIn: parent
                spacing: 4
                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hoverPanel.projectIcon !== "" ? hoverPanel.projectIcon : "cast"
                    font.pixelSize: 13
                    color: hoverPanel.projectActive ? omarchyView.accentFg : hoverPanel.root.ink
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hoverPanel.projectLabel !== "" ? hoverPanel.projectLabel : "Project"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: hoverPanel.projectActive ? omarchyView.accentFg : hoverPanel.root.ink
                }
            }
            HoverHandler { id: projHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        hoverPanel.projectPrevProc.running = false
                        hoverPanel.projectPrevProc.running = true
                    } else {
                        hoverPanel.projectCycleProc.running = false
                        hoverPanel.projectCycleProc.running = true
                    }
                }
            }
        }

        // 4. Bar Color Swatches Card
        Rectangle {
            height: parent.height
            width: parent.width - 72 - 76 - 76 - closeBtn.width - 24
            radius: 12
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor

            Row {
                anchors.centerIn: parent
                spacing: 8

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "palette"
                    font.pixelSize: 14
                    color: hoverPanel.accent
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 7

                    Repeater {
                        model: hoverPanel.root.barColorOptions
                        delegate: Rectangle {
                            id: swatchItem
                            required property string modelData
                            width: 18
                            height: 18
                            radius: 9
                            color: hoverPanel.root.paletteColor(modelData)
                            scale: swatchHov.hovered ? 1.18 : (hoverPanel.root.barColor === modelData ? 1.1 : 0.92)
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                            IconText {
                                anchors.centerIn: parent
                                visible: hoverPanel.root.barColor === swatchItem.modelData
                                text: "check"
                                color: hoverPanel.root.paletteContrastColor(swatchItem.modelData)
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }

                            HoverHandler { id: swatchHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hoverPanel.root.barColor = swatchItem.modelData
                            }
                        }
                    }
                }
            }
        }

        // 5. Close Button
        Rectangle {
            id: closeBtn
            width: parent.height
            height: parent.height
            radius: 12
            color: closeHov.hovered
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor
            IconText {
                anchors.centerIn: parent
                text: "close"
                font.pixelSize: 14
                color: hoverPanel.root.ink
            }
            HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: hoverPanel.omarchyMenuOpen = false
            }
        }
    }

    // Full-Height Heatmap View (when omarchyTab === 1)
    Item {
        id: heatmapFullView
        anchors.fill: parent
        visible: hoverPanel.omarchyTab === 1

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor
            clip: true

            Image {
                id: ghImg
                anchors.fill: parent
                anchors.margins: 4
                source: hoverPanel.ghSvgSource
                fillMode: Image.PreserveAspectFit
                cache: false
                visible: hoverPanel.ghSvgSource !== ""
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4
                width: 24; height: 24; radius: 12
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14)
                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 12
                    color: hoverPanel.root.ink
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        hoverPanel.omarchyTab = 0
                        hoverPanel.omarchyMenuOpen = false
                    }
                }
            }
        }
    }
}

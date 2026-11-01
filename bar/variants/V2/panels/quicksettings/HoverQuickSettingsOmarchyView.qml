import QtQuick
import ".."
import Quickshell
import "../../modules"

// ── Omarchy Controls & System Info View ──
Item {
    id: omarchyView
    required property var hoverPanel

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: hoverPanel.omarchyMenuOpen ? 1.0 : 0.0
    scale: hoverPanel.omarchyMenuOpen ? 1.0 : 0.95
    enabled: hoverPanel.omarchyMenuOpen
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    Column {
        anchors.fill: parent
        spacing: 6
        visible: hoverPanel.omarchyTab !== 1

        // Header Row: Logo · Host · Tab Selector (Options / System Info) · Close Button
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    width: 22
                    height: 22
                    radius: 7
                    color: hoverPanel.accent
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "\uE900"
                        color: hoverPanel.root.paper
                        font.family: "omarchy"
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hoverPanel.siHostname !== "" ? hoverPanel.siHostname : "Omarchy"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: hoverPanel.root.ink
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "·"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 11
                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hoverPanel.siOs !== "" ? hoverPanel.siOs : "Control Center"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.55)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Material 3 Expressive Segmented Tab Pill
                Rectangle {
                    height: 24
                    width: tabRow.implicitWidth + 8
                    radius: 12
                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)

                    Rectangle {
                        id: tabPill
                        height: 20
                        y: 2
                        radius: 10
                        color: hoverPanel.accent
                        x: hoverPanel.omarchyTab === 0 ? 2 : (tabBtnSettings.width + 4)
                        width: hoverPanel.omarchyTab === 0 ? tabBtnSettings.width : tabBtnSystem.width
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 2

                        Item {
                            id: tabBtnSettings
                            width: tabSetRow.implicitWidth + 12
                            height: 20

                            Row {
                                id: tabSetRow
                                anchors.centerIn: parent
                                spacing: 3
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "tune"
                                    font.pixelSize: 11
                                    color: hoverPanel.omarchyTab === 0 ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Options"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: hoverPanel.omarchyTab === 0 ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hoverPanel.omarchyTab = 0
                            }
                        }

                        Item {
                            id: tabBtnSystem
                            width: tabSysRow.implicitWidth + 12
                            height: 20

                            Row {
                                id: tabSysRow
                                anchors.centerIn: parent
                                spacing: 3
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "developer_board"
                                    font.pixelSize: 11
                                    color: hoverPanel.omarchyTab === 2 ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "System Info"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: hoverPanel.omarchyTab === 2 ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: hoverPanel.omarchyTab = 2
                            }
                        }
                    }
                }

                // Close X button
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: closeHov.hovered
                        ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                        : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 13
                        color: hoverPanel.root.ink
                    }
                    HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: hoverPanel.omarchyMenuOpen = false
                    }
                }
            }
        }

        // Content Container (80px tall)
        Item {
            id: tabContentContainer
            width: parent.width
            height: 80
            clip: true

            WheelHandler {
                onWheel: (event) => {
                    if (event.angleDelta.y < 0) hoverPanel.omarchyTab = Math.min(2, hoverPanel.omarchyTab + 1)
                    else if (event.angleDelta.y > 0) hoverPanel.omarchyTab = Math.max(0, hoverPanel.omarchyTab - 1)
                }
            }

            // ── Tab 0: Options (5 Quick Action Chips + Bar Color + Picker Style) ──
            Item {
                id: optionsTabContent
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: hoverPanel.omarchyTab === 0 ? 1.0 : 0.0
                x: hoverPanel.omarchyTab === 0 ? 0 : -20
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                enabled: hoverPanel.omarchyTab === 0

                Column {
                    anchors.fill: parent
                    spacing: 5

                    // Row 1: 5 Material 3 Expressive Action Chips
                    Row {
                        width: parent.width
                        height: 36
                        spacing: 6
                        readonly property real chipW: Math.floor((width - 4 * 6) / 5)

                        // 1. GitHub Heatmap (replaces Edit slots, opens directly in control panel)
                        Rectangle {
                            width: parent.chipW
                            height: parent.height
                            radius: 12
                            color: hoverPanel.omarchyTab === 1
                                ? (hmHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                : (hmHov.hovered
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                            border.width: 1
                            border.color: hoverPanel.omarchyTab === 1 ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                            scale: hmHov.hovered ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "data_object"
                                    font.pixelSize: 13
                                    color: hoverPanel.omarchyTab === 1 ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "GH Heatmap"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: hoverPanel.omarchyTab === 1 ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                            }
                            HoverHandler { id: hmHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    hoverPanel.omarchyTab = 1
                                }
                            }
                        }

                        // 2. Position
                        Rectangle {
                            width: parent.chipW
                            height: parent.height
                            radius: 12
                            color: posHov.hovered
                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.04)
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

                        // 3. Do not disturb
                        Rectangle {
                            width: parent.chipW
                            height: parent.height
                            radius: 12
                            color: hoverPanel.root.notifSilenced
                                ? (dndHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                : (dndHov.hovered
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                            border.width: 1
                            border.color: hoverPanel.root.notifSilenced ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                            scale: dndHov.hovered ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hoverPanel.root.notifSilenced ? "notifications_off" : "notifications"
                                    font.pixelSize: 13
                                    color: hoverPanel.root.notifSilenced ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "DND"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: hoverPanel.root.notifSilenced ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                            }
                            HoverHandler { id: dndHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { hoverPanel.dndProc.running = false; hoverPanel.dndProc.running = true }
                            }
                        }

                        // 4. Bar Border
                        Rectangle {
                            width: parent.chipW
                            height: parent.height
                            radius: 12
                            color: hoverPanel.root.barBorderEnabled
                                ? (bbHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                : (bbHov.hovered
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                            border.width: 1
                            border.color: hoverPanel.root.barBorderEnabled ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                            scale: bbHov.hovered ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "border_outer"
                                    font.pixelSize: 13
                                    color: hoverPanel.root.barBorderEnabled ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Bar Border"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: hoverPanel.root.barBorderEnabled ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                            }
                            HoverHandler { id: bbHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: hoverPanel.root.barBorderEnabled = !hoverPanel.root.barBorderEnabled
                            }
                        }

                        // 5. Project (Mirror / Extend / Display settings)
                        Rectangle {
                            width: parent.chipW
                            height: parent.height
                            radius: 12
                            color: hoverPanel.projectActive
                                ? (projHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                : (projHov.hovered
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                            border.width: 1
                            border.color: hoverPanel.projectActive ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                            scale: projHov.hovered ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hoverPanel.projectIcon !== "" ? hoverPanel.projectIcon : "cast"
                                    font.pixelSize: 13
                                    color: hoverPanel.projectActive ? hoverPanel.root.paper : hoverPanel.root.ink
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: hoverPanel.projectLabel !== "" ? hoverPanel.projectLabel : "Project"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: hoverPanel.projectActive ? hoverPanel.root.paper : hoverPanel.root.ink
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
                    }

                    // Row 2: Bar Color Swatches Card + Picker Style Card
                    Row {
                        width: parent.width
                        height: 38
                        spacing: 6

                        // Bar Color Swatches Card
                        Rectangle {
                            width: Math.floor(parent.width * 0.53)
                            height: parent.height
                            radius: 13
                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "palette"
                                    font.pixelSize: 14
                                    color: hoverPanel.accent
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Color"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.60)
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    Repeater {
                                        model: hoverPanel.root.barColorOptions
                                        delegate: Rectangle {
                                            id: swatchItem
                                            required property string modelData
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: hoverPanel.root.paletteColor(modelData)
                                            scale: swatchHov.hovered ? 1.18 : (hoverPanel.root.barColor === modelData ? 1.05 : 0.92)
                                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                                            IconText {
                                                anchors.centerIn: parent
                                                visible: hoverPanel.root.barColor === swatchItem.modelData
                                                text: "check"
                                                color: hoverPanel.root.paletteContrastColor(swatchItem.modelData)
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                            }

                                            HoverHandler { id: swatchHov; cursorShape: Qt.PointingHandCursor }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: hoverPanel.root.barColor = swatchItem.modelData
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Picker Style Card
                        Rectangle {
                            width: parent.width - Math.floor(parent.width * 0.53) - parent.spacing
                            height: parent.height
                            radius: 13
                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.04)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "dashboard_customize"
                                    font.pixelSize: 14
                                    color: hoverPanel.accent
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Picker"
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.60)
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Repeater {
                                        model: [
                                            { label: "Tanzaku", val: "tanzaku" },
                                            { label: "Hearthstone", val: "hearthstone" },
                                            { label: "Carousel", val: "carousel" },
                                            { label: "Gravemind", val: "gravemind" }
                                        ]
                                        delegate: Rectangle {
                                            id: pickerBtn
                                            required property var modelData
                                            readonly property bool isCur: hoverPanel.root.pickerStyle === modelData.val
                                            height: 24
                                            width: Math.max(48, pTxt.implicitWidth + 12)
                                            radius: 12
                                            color: isCur
                                                ? hoverPanel.accent
                                                : (pHov.hovered ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12) : "transparent")
                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Text {
                                                id: pTxt
                                                anchors.centerIn: parent
                                                text: pickerBtn.modelData.label
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 9
                                                font.weight: pickerBtn.isCur ? Font.Bold : Font.Normal
                                                color: pickerBtn.isCur ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }

                                            HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: hoverPanel.root.pickerStyle = pickerBtn.modelData.val
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Tab 2: System Info (Processor, Memory, Graphics, Display) ──
            HoverQuickSettingsSystemInfoTab {
                id: systemTabContent
                hoverPanel: omarchyView.hoverPanel
            }
        }
    }

    // ── Dedicated Full-Height Heatmap View (no headers, no tab switcher, floating close) ──
    Item {
        id: heatmapFullView
        anchors.fill: parent
        visible: hoverPanel.omarchyTab === 1

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.04)
            clip: true

            Text {
                anchors.centerIn: parent
                text: "Fetching heatmap..."
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                font.family: hoverPanel.root.barFont
                font.pixelSize: 11
                visible: hoverPanel.ghRefreshing && ghImg.status !== Image.Ready
            }

            Image {
                id: ghImg
                anchors.fill: parent
                anchors.margins: 4
                source: hoverPanel.ghSvgSource
                fillMode: Image.PreserveAspectFit
                cache: false
                visible: hoverPanel.ghSvgSource !== ""
            }

            // Floating action buttons on top right
            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6
                spacing: 6
                z: 10

                // Refresh button
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: hmRefMa.containsMouse
                        ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.20)
                        : Qt.rgba(hoverPanel.root.paper.r, hoverPanel.root.paper.g, hoverPanel.root.paper.b, 0.65)

                    IconText {
                        anchors.centerIn: parent
                        text: "refresh"
                        color: hmRefMa.containsMouse ? hoverPanel.accent : hoverPanel.root.ink
                        font.pixelSize: 13
                        opacity: hoverPanel.ghRefreshing ? 0.6 : 1.0

                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                            running: hoverPanel.ghRefreshing
                        }
                    }

                    MouseArea {
                        id: hmRefMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !hoverPanel.ghRefreshing
                        onClicked: {
                            hoverPanel.ghRefreshing = true
                            Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.cache/quickshell_ghchart_raw.svg"])
                            hoverPanel.fetchHeatmapProc.running = true
                        }
                    }
                }

                // Close button (returns back to Options)
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: hmCloseMa.containsMouse
                        ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.20)
                        : Qt.rgba(hoverPanel.root.paper.r, hoverPanel.root.paper.g, hoverPanel.root.paper.b, 0.65)

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 13
                        color: hoverPanel.root.ink
                    }

                    MouseArea {
                        id: hmCloseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: hoverPanel.omarchyTab = 0
                    }
                }
            }
        }
    }
}

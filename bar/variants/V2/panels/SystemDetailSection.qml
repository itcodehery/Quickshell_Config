import QtQuick
import QtQuick.Controls
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

    property string hostname: "heryarch"
    property string kernel: "Linux"
    property string uptimeStr: "0h 0m"
    property int focusedIndex: 0

    // Material 3 Expressive geometric vector paths (normalized to 64x64 box)
    readonly property string pathFlower: "M 62.5 32.0 L 62.1 35.0 L 61.1 37.8 L 59.4 40.3 L 57.1 42.4 L 54.4 44.0 L 51.3 44.9 L 48.1 45.2 L 44.7 44.7 L 45.2 48.1 L 44.9 51.3 L 44.0 54.4 L 42.4 57.1 L 40.3 59.4 L 37.8 61.1 L 35.0 62.1 L 32.0 62.5 L 29.0 62.1 L 26.2 61.1 L 23.7 59.4 L 21.6 57.1 L 20.0 54.4 L 19.1 51.3 L 18.8 48.1 L 19.3 44.7 L 15.9 45.2 L 12.7 44.9 L 9.6 44.0 L 6.9 42.4 L 4.6 40.3 L 2.9 37.8 L 1.9 35.0 L 1.5 32.0 L 1.9 29.0 L 2.9 26.2 L 4.6 23.7 L 6.9 21.6 L 9.6 20.0 L 12.7 19.1 L 15.9 18.8 L 19.3 19.3 L 18.8 15.9 L 19.1 12.7 L 20.0 9.6 L 21.6 6.9 L 23.7 4.6 L 26.2 2.9 L 29.0 1.9 L 32.0 1.5 L 35.0 1.9 L 37.8 2.9 L 40.3 4.6 L 42.4 6.9 L 44.0 9.6 L 44.9 12.7 L 45.2 15.9 L 44.7 19.3 L 48.1 18.8 L 51.3 19.1 L 54.4 20.0 L 57.1 21.6 L 59.4 23.7 L 61.1 26.2 L 62.1 29.0 Z"
    readonly property string pathArch: "M 2 32 A 30 30 0 0 1 62 32 L 62 46 A 16 16 0 0 1 46 62 L 18 62 A 16 16 0 0 1 2 46 Z"
    readonly property string pathScallop: "M 62.5 32.0 L 61.9 34.9 L 60.0 37.6 L 57.3 39.7 L 54.2 41.2 L 55.4 44.5 L 55.8 47.9 L 55.2 51.0 L 53.6 53.6 L 51.0 55.2 L 47.9 55.8 L 44.5 55.4 L 41.2 54.2 L 39.7 57.3 L 37.6 60.0 L 34.9 61.9 L 32.0 62.5 L 29.1 61.9 L 26.4 60.0 L 24.3 57.3 L 22.8 54.2 L 19.5 55.4 L 16.1 55.8 L 13.0 55.2 L 10.4 53.6 L 8.8 51.0 L 8.2 47.9 L 8.6 44.5 L 9.8 41.2 L 6.7 39.7 L 4.0 37.6 L 2.1 34.9 L 1.5 32.0 L 2.1 29.1 L 4.0 26.4 L 6.7 24.3 L 9.8 22.8 L 8.6 19.5 L 8.2 16.1 L 8.8 13.0 L 10.4 10.4 L 13.0 8.8 L 16.1 8.2 L 19.5 8.6 L 22.8 9.8 L 24.3 6.7 L 26.4 4.0 L 29.1 2.1 L 32.0 1.5 L 34.9 2.1 L 37.6 4.0 L 39.7 6.7 L 41.2 9.8 L 44.5 8.6 L 47.9 8.2 L 51.0 8.8 L 53.6 10.4 L 55.2 13.0 L 55.8 16.1 L 55.4 19.5 L 54.2 22.8 L 57.3 24.3 L 60.0 26.4 L 61.9 29.1 Z"
    readonly property string pathStar: "M 48.0 32.0 L 48.5 33.6 L 49.8 35.5 L 51.7 38.0 L 53.7 41.0 L 55.3 44.4 L 55.9 48.0 L 55.5 51.3 L 53.9 53.9 L 51.3 55.5 L 48.0 55.9 L 44.4 55.3 L 41.0 53.7 L 38.0 51.7 L 35.5 49.8 L 33.6 48.5 L 32.0 48.0 L 30.4 48.5 L 28.5 49.8 L 26.0 51.7 L 23.0 53.7 L 19.6 55.3 L 16.0 55.9 L 12.7 55.5 L 10.1 53.9 L 8.5 51.3 L 8.1 48.0 L 8.7 44.4 L 10.3 41.0 L 12.3 38.0 L 14.2 35.5 L 15.5 33.6 L 16.0 32.0 L 15.5 30.4 L 14.2 28.5 L 12.3 26.0 L 10.3 23.0 L 8.7 19.6 L 8.1 16.0 L 8.5 12.7 L 10.1 10.1 L 12.7 8.5 L 16.0 8.1 L 19.6 8.7 L 23.0 10.3 L 26.0 12.3 L 28.5 14.2 L 30.4 15.5 L 32.0 16.0 L 33.6 15.5 L 35.5 14.2 L 38.0 12.3 L 41.0 10.3 L 44.4 8.7 L 48.0 8.1 L 51.3 8.5 L 53.9 10.1 L 55.5 12.7 L 55.9 16.0 L 55.3 19.6 L 53.7 23.0 L 51.7 26.0 L 49.8 28.5 L 48.5 30.4 Z"

    readonly property var options: [
        {
            name: "Screensaver",
            desc: "Ambient screensaver",
            icon: "wallpaper",
            accent: (root && root.color06) ? root.color06 : "#7aa89f",
            path: pathFlower
        },
        {
            name: "Lock",
            desc: "Lock session",
            icon: "lock",
            accent: (root && root.color04) ? root.color04 : "#658594",
            path: pathArch
        },
        {
            name: "Shutdown",
            desc: "Power off",
            icon: "power_settings_new",
            accent: (root && root.color01) ? root.color01 : "#c4746e",
            path: pathScallop
        },
        {
            name: "Reboot",
            desc: "Restart system",
            icon: "restart_alt",
            accent: (root && root.color03) ? root.color03 : "#c8b36a",
            path: pathStar
        }
    ]

    // Live System Info Process
    Process {
        id: sysInfoProc
        command: ["bash", "-c", "echo $(hostname); uname -r; awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n")
                if (lines.length >= 1 && lines[0]) systemSection.hostname = lines[0].trim()
                if (lines.length >= 2 && lines[1]) systemSection.kernel = lines[1].trim()
                if (lines.length >= 3 && lines[2]) systemSection.uptimeStr = lines[2].trim()
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: systemSection.visible
        onTriggered: {
            sysInfoProc.running = false
            sysInfoProc.running = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            sysInfoProc.running = false
            sysInfoProc.running = true
            systemSection.focus = true
        }
    }

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
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_X) {
            closeRequested()
            event.accepted = true
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            focusedIndex = (focusedIndex + 1) % 4
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            focusedIndex = (focusedIndex - 1 + 4) % 4
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            triggerOption(focusedIndex)
            event.accepted = true
        }
        // Do NOT intercept H and L!
        // H and L are reserved for cycling between widgets (Calendar, Battery, Volume, etc.) in HomescreenDashboardContent!
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Matches Calendar Widget Design) ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: POWER MENU ACTIONS WIDGET ───────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Top Bar
            Item {
                id: leftTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26

                // Status Badge Pill
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    radius: 13
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    width: leftStatusRow.implicitWidth + 18

                    Row {
                        id: leftStatusRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6; height: 6; radius: 3
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#a9b665"
                        }

                        IconText {
                            text: "power_settings_new"
                            font.pixelSize: 13
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Power Menu"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Close Button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    color: closeLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 14
                        color: root.ink
                    }

                    MouseArea {
                        id: closeLeftMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: systemSection.closeRequested()
                    }
                }
            }

            // Left Column Body Content
            Item {
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    clip: true

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 12

                        // Horizontal Row of the 4 Power Options Filling Width with M3 Custom Geometric Shapes
                        Row {
                            id: horizontalPowerRow
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: systemSection.options

                                Item {
                                    id: optionCard
                                    required property var modelData
                                    required property int index

                                    readonly property bool isFocused: systemSection.focusedIndex === index
                                    readonly property bool isHovered: cardMa.containsMouse

                                    width: Math.floor((horizontalPowerRow.width - 3 * horizontalPowerRow.spacing) / 4)
                                    height: 104

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        // Material 3 Custom Geometric Shape Container
                                        Item {
                                            id: shapeContainer
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 52
                                            height: 52
                                            scale: (optionCard.isHovered || optionCard.isFocused) ? 1.08 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                            Item {
                                                width: 64
                                                height: 64
                                                anchors.centerIn: parent
                                                scale: 52 / 64.0
                                                transformOrigin: Item.Center

                                                Shape {
                                                    anchors.fill: parent
                                                    preferredRendererType: Shape.CurveRenderer

                                                    ShapePath {
                                                        strokeWidth: 0
                                                        strokeColor: "transparent"
                                                        fillColor: (optionCard.isHovered || optionCard.isFocused)
                                                            ? optionCard.modelData.accent
                                                            : Qt.rgba(optionCard.modelData.accent.r, optionCard.modelData.accent.g, optionCard.modelData.accent.b, 0.22)
                                                        Behavior on fillColor { ColorAnimation { duration: 160 } }

                                                        PathSvg {
                                                            path: optionCard.modelData.path
                                                        }
                                                    }
                                                }

                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: optionCard.modelData.icon
                                                    font.pixelSize: 26
                                                    color: (optionCard.isHovered || optionCard.isFocused)
                                                        ? (root ? root.paper : "#181825")
                                                        : optionCard.modelData.accent
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }
                                            }
                                        }

                                        // Label below shape
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: optionCard.modelData.name
                                            font.family: (root && root.barFont) ? root.barFont : "DM Sans"
                                            font.pixelSize: 11
                                            font.weight: optionCard.isFocused ? Font.Bold : Font.DemiBold
                                            color: (root && root.ink) ? root.ink : "#ffffff"
                                            opacity: (optionCard.isHovered || optionCard.isFocused) ? 1.0 : 0.75
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        id: cardMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: systemSection.focusedIndex = optionCard.index
                                        onClicked: systemSection.triggerOption(optionCard.index)
                                    }
                                }
                            }
                        }

                        // Navigation Hint & Action Indicator Pill
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: 30
                            radius: 15
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                IconText {
                                    text: "swap_vert"
                                    font.pixelSize: 12
                                    color: root.seal
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "[j] / [k] navigate • [Enter] to " + systemSection.options[systemSection.focusedIndex].name
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: root.ink
                                    opacity: 0.75
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: SYSTEM OVERVIEW & HOST TELEMETRY INFO ──────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: columnsRow.width - leftColContainer.width - columnsRow.spacing
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Top Bar
            Item {
                id: rightTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26

                // Section Title Pill
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    radius: 13
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    width: rightTitleRow.implicitWidth + 18

                    Row {
                        id: rightTitleRow
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            text: "computer"
                            font.pixelSize: 13
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Arch Linux"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Top Right: Uptime Badge + Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Uptime Pill
                    Rectangle {
                        height: 26
                        radius: 13
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        width: upRow.implicitWidth + 16

                        Row {
                            id: upRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "timelapse"
                                font.pixelSize: 11
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Up " + systemSection.uptimeStr
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: closeRightMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        MouseArea {
                            id: closeRightMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: systemSection.closeRequested()
                        }
                    }
                }
            }

            // Right Column Body Content
            Item {
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    clip: true

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8

                        // 1. Hero Ring Circle with System Icon
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 68
                            height: 68

                            // Outer track circle
                            Rectangle {
                                anchors.fill: parent
                                radius: 34
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                border.width: 4
                                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            }

                            // Dynamic Accent Ring
                            Rectangle {
                                anchors.fill: parent
                                radius: 34
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                                border.width: 3
                                border.color: root.seal
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                IconText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "desktop_windows"
                                    font.pixelSize: 22
                                    color: root.seal
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "SYSTEM"
                                    font.family: root.barFont
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: root.ink
                                    opacity: 0.45
                                }
                            }
                        }

                        // 2. Hostname & Kernel Info
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: systemSection.hostname
                                font.family: root.barFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: root.ink
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Linux " + systemSection.kernel
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.ink
                                opacity: 0.5
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // 3. Telemetry Stats Badges
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            // Session Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                width: sessionRow.implicitWidth + 12

                                Row {
                                    id: sessionRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "dashboard"
                                        font.pixelSize: 10
                                        color: root.ink
                                        opacity: 0.6
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Hyprland"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // User Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                                width: userRow.implicitWidth + 12

                                Row {
                                    id: userRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "person"
                                        font.pixelSize: 10
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: Quickshell.env("USER") || "user"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

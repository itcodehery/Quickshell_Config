import QtQuick
import ".."
import Quickshell
import "../../modules"

// ── Standard Quick Settings View ──
Row {
    id: standardQuickView
    required property var hoverPanel

    anchors.fill: parent
    spacing: 8
    visible: opacity > 0.001
    opacity: hoverPanel.omarchyMenuOpen ? 0.0 : 1.0
    scale: hoverPanel.omarchyMenuOpen ? 0.95 : 1.0
    enabled: !hoverPanel.omarchyMenuOpen
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // 2x2 Grid of Big Squircle Toggle Buttons
    Grid {
        id: toggleGrid
        columns: 2
        spacing: 8
        width: 116
        height: parent.height

        // Button 1: GitHub Heatmap Toggle (replaces Night Light)
        Rectangle {
            id: btn1Heatmap
            width: 54
            height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
            radius: 16
            readonly property bool isActive: hoverPanel.omarchyMenuOpen && hoverPanel.omarchyTab === 1
            color: isActive
                ? (btn1Hov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                : (btn1Hov.hovered
                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
            border.width: 1
            border.color: isActive ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
            scale: btn1Hov.hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Text {
                anchors.centerIn: parent
                text: String.fromCodePoint(0xF09B) // GitHub icon
                font.family: hoverPanel.root.barFont
                font.pixelSize: 20
                color: btn1Heatmap.isActive ? hoverPanel.root.paper : hoverPanel.root.ink
            }

            HoverHandler { id: btn1Hov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
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

        // Button 2: Lock / Screen lock
        Rectangle {
            width: 54
            height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
            radius: 16
            color: btn2Hov.hovered
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.04)
            scale: btn2Hov.hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }

            IconText {
                anchors.centerIn: parent
                text: "lock"
                font.pixelSize: 22
                color: hoverPanel.root.ink
            }

            HoverHandler { id: btn2Hov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/bin/qs-lock"])
            }
        }

        // Button 3: Wi-Fi Toggle
        Rectangle {
            width: 54
            height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
            radius: 16
            color: hoverPanel.wifiConnected
                ? (btn3Hov.hovered ? Qt.lighter(hoverPanel.wifiColor, 1.12) : hoverPanel.wifiColor)
                : (btn3Hov.hovered
                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
            border.width: 1
            border.color: hoverPanel.wifiConnected ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
            scale: btn3Hov.hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Column {
                anchors.centerIn: parent
                spacing: 1

                IconText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: hoverPanel.wifiConnected ? "signal_wifi_4_bar" : "signal_wifi_off"
                    font.pixelSize: 20
                    color: hoverPanel.root.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Wi-Fi"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: hoverPanel.wifiConnected ? hoverPanel.root.ink : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.6)
                }
            }

            HoverHandler { id: btn3Hov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: hoverPanel.toggleWifi()
            }
        }

        // Button 4: Notification Bell / DND
        Rectangle {
            width: 54
            height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
            radius: 16
            color: hoverPanel.root.notifSilenced
                ? (btn4Hov.hovered ? Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.35) : Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.22))
                : (btn4Hov.hovered
                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.04)
            scale: btn4Hov.hovered ? 1.05 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }

            Item {
                anchors.fill: parent
                IconText {
                    anchors.centerIn: parent
                    text: hoverPanel.root.notifSilenced ? "notifications_off" : "notifications"
                    font.pixelSize: 22
                    color: hoverPanel.root.notifSilenced ? hoverPanel.accent : hoverPanel.root.ink
                }

                // Unread Badge Dot
                Rectangle {
                    visible: hoverPanel.root.notifCount > 0 && !hoverPanel.root.notifSilenced
                    width: 7
                    height: 7
                    radius: 3.5
                    color: hoverPanel.accent
                    x: parent.width - width - 6
                    y: 6
                }
            }

            HoverHandler { id: btn4Hov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                    hoverPanel.root.dashboardExpanded = true
                    hoverPanel.root.dashboardDetail = "notifications"
                }
            }
        }
    }

    // Screentime Card (matching reference UI with fully rounded floating pill)
    Rectangle {
        id: screentimeCard
        width: Math.floor((parent.width - toggleGrid.width - 16) / 2)
        height: parent.height
        radius: 18
        color: briCardHov.hovered
            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.04)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                hoverPanel.root.dashboardExpanded = true
                hoverPanel.root.dashboardDetail = "screentime"
            }
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 2

            Text {
                text: "Screentime"
                font.family: hoverPanel.root.barFont
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
            }

            Text {
                text: hoverPanel.screentimeStr || "0m"
                font.family: hoverPanel.root.barFont
                font.pixelSize: 14
                font.weight: Font.Bold
                color: hoverPanel.root.ink
                elide: Text.ElideRight
            }
        }

        // Interactive bottom floating pill (fully rounded on all corners, matching reference image)
        Rectangle {
            id: stCapsule
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            height: 30
            radius: height / 2
            color: stMa.containsMouse
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
            Behavior on color { ColorAnimation { duration: 140 } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: "Today"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: hoverPanel.root.ink
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "||"
                    font.family: hoverPanel.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                    anchors.verticalCenter: parent.verticalCenter
                }

                IconText {
                    text: "hourglass_top"
                    font.pixelSize: 13
                    color: hoverPanel.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: stMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                    hoverPanel.root.dashboardExpanded = true
                    hoverPanel.root.dashboardDetail = "screentime"
                }
            }
        }

        HoverHandler { id: briCardHov }
    }

    // Updates & Notes Column (Updates section made smaller + Notes button)
    Column {
        id: updatesAndNotesCol
        width: Math.floor((parent.width - toggleGrid.width - 16) / 2)
        height: parent.height
        spacing: 6

        // 1. Updates Card (Compact section)
        Rectangle {
            id: packagesCard
            width: parent.width
            height: Math.floor((parent.height - parent.spacing) / 2)
            radius: 14
            color: pkgCardHov.hovered
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: Qt.rgba(255, 255, 255, 0.04)
            scale: pkgCardHov.hovered ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            readonly property int updateCount: (hoverPanel.root && hoverPanel.root.archUpdates) ? hoverPanel.root.archUpdates.length : 0

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 32
                    height: 32
                    radius: 10
                    color: (packagesCard.updateCount > 0 || hoverPanel.omarchyUpdateAvailable)
                        ? Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                        : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        text: packagesCard.updateCount > 0 ? "system_update" : (hoverPanel.omarchyUpdateAvailable ? "sync" : "check")
                        font.pixelSize: 17
                        color: (packagesCard.updateCount > 0 || hoverPanel.omarchyUpdateAvailable) ? hoverPanel.accent : "#4ADE80"
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: parent.width - 40

                    Text {
                        text: "Updates"
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: hoverPanel.root.ink
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: packagesCard.updateCount > 0
                            ? (packagesCard.updateCount + " available")
                            : (hoverPanel.omarchyUpdateAvailable ? "Omarchy update" : "Up to date")
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: (packagesCard.updateCount > 0 || hoverPanel.omarchyUpdateAvailable)
                            ? hoverPanel.accent
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.60)
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            HoverHandler { id: pkgCardHov; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                    hoverPanel.root.activeUpdateTab = "packages"
                    hoverPanel.root.dashboardExpanded = true
                    hoverPanel.root.dashboardDetail = "updates"
                }
            }
        }

        // 2. Notes Card / Button
        Rectangle {
            id: notesCard
            property bool active: hoverPanel.root.dashboardExpanded && hoverPanel.root.dashboardDetail === "notes"
            width: parent.width
            height: Math.floor((parent.height - parent.spacing) / 2)
            radius: 14
            color: notesCardHov.hovered
                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: active ? hoverPanel.accent : Qt.rgba(255, 255, 255, 0.04)
            scale: notesCardHov.hovered ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 32
                    height: 32
                    radius: 10
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
                        font.pixelSize: 16
                        color: notesCard.active ? hoverPanel.root.paper : hoverPanel.accent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    width: parent.width - 40

                    Text {
                        text: "Notes"
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: hoverPanel.root.ink
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: "Dashboard notes"
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.60)
                        elide: Text.ElideRight
                        width: parent.width
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
}

import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import "../../modules"

Rectangle {
    id: tileRoot
    z: isSelected ? 2 : 0

    property var dashContent: null
    readonly property var root: (dashContent && dashContent.root) ? dashContent.root : null
    property string tileId: ""
    property var span: 1          // 1 (1x1), 2 (1x2), 4 (2x2)
    property int tileIndex: -1
    property int gridPage: 0
    property int gridRow: 0
    property int gridCol: 0

    readonly property bool is1x1: span === 1 || span === "1x1"
    readonly property bool is1x2: span === 2 || span === "1x2"
    readonly property bool is2x2: span === 4 || span === "2x2"

    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color paperCol: (root && root.paper) ? root.paper : "#000000"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#22d3ee"
    readonly property color fillIdleCol: (root && root.fillIdle) ? root.fillIdle : Qt.rgba(1, 1, 1, 0.08)
    readonly property color fillHoverCol: (root && root.fillHover) ? root.fillHover : Qt.rgba(1, 1, 1, 0.14)
    readonly property color color01Col: (root && root.color01) ? root.color01 : "#f59e0b"
    readonly property color color03Col: (root && root.color03) ? root.color03 : "#10b981"
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "sans-serif"

    readonly property bool isSelected: dashContent ? (dashContent.selectedTileId === tileId) : false
    readonly property bool isBeingDragged: (dashContent && dashContent.draggingTileId) ? (dashContent.draggingTileId === tileId) : false
    readonly property bool isDropTarget: (dashContent && dashContent.dropTargetTileId === tileId && !isBeingDragged)

    height: is2x2 ? 122 : 56
    radius: is1x1 ? (isTileActive ? 18 : 28) : 28
    Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
    color: "transparent"
    border.width: 0
    clip: false

    // Tactile micro-press feedback
    scale: tileMa.pressed ? 0.96 : (isDropTarget ? 1.04 : 1.0)
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // ── Bouncy Spring Animation on Resize ──
    Behavior on width {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutBack
            easing.overshoot: 1.35
        }
    }
    Behavior on radius {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
    }

    opacity: isBeingDragged ? 0.28 : 1.0
    Behavior on opacity { NumberAnimation { duration: 150 } }

    // ── Active & Lit Status ──
    readonly property bool isActive: {
        if (!dashContent) return false
        switch (tileId) {
            case "wifi": return dashContent.activeDetailView === "wifi"
            case "bluetooth": return dashContent.activeDetailView === "bluetooth"
            case "notifications": return dashContent.activeDetailView === "notifications"
            case "screentime": return dashContent.activeDetailView === "screentime"
            case "nightlight": return (dashContent.nightMode || 0) > 0
            case "caffeine": return dashContent.caffeineActive || false
            case "battery": return dashContent.activeDetailView === "battery"
            case "plugins": return dashContent.activeDetailView === "plugins"
            case "updates": return dashContent.activeDetailView === "updates" || dashContent.activeDetailView === "packages"
            case "pomodoro": return (root && root.timerActive) || false
            case "theme": return dashContent.activeDetailView === "theme"
            case "wallpaper": return dashContent.activeDetailView === "wallpaper"
            case "notes": return dashContent.activeDetailView === "notes"
            case "calendar": return dashContent.activeDetailView === "calendar"
            case "settings": return dashContent.activeDetailView === "settings"
            default: return false
        }
    }

    readonly property bool isLit: {
        if (!dashContent) return false
        if (tileId === "wifi") return dashContent.currentWifiName !== "Wi-Fi" && dashContent.currentWifiName !== "Searching..."
        if (tileId === "bluetooth") return dashContent.btPowered || false
        if (tileId === "nightlight") return (dashContent.nightMode || 0) > 0
        if (tileId === "caffeine") return dashContent.caffeineActive || false
        if (tileId === "pomodoro") return ((root && root.timerActive) || (dashContent.showPomodoroPopup || false))
        return isActive
    }

    readonly property bool isTileActive: isLit || isActive

    // ── Tile Background Color ──
    readonly property color effectiveTileColor: {
        if (tileId === "nightlight" && dashContent) {
            let m = dashContent.nightMode || 0
            return m === 2 ? color01Col : (m === 1 ? color03Col : (tileMa.containsMouse ? fillHoverCol : fillIdleCol))
        }
        if (tileId === "caffeine" && dashContent && dashContent.caffeineActive) {
            return color03Col
        }
        if (tileId === "pomodoro" && root && root.timerActive) {
            return color03Col
        }
        // In 1x1 compact mode, when Wi-Fi/Bluetooth is connected/lit, highlight tile in seal theme color
        if (is1x1 && isLit) {
            return tileMa.containsMouse ? Qt.lighter(sealCol, 1.12) : sealCol
        }
        if (isActive) {
            return tileMa.containsMouse ? Qt.lighter(sealCol, 1.12) : sealCol
        }
        return tileMa.containsMouse ? fillHoverCol : fillIdleCol
    }

    readonly property color tileAccentCol: {
        if (tileId === "nightlight" && dashContent) {
            let m = dashContent.nightMode || 0
            return m === 2 ? color01Col : (m === 1 ? color03Col : sealCol)
        }
        if (tileId === "caffeine" && dashContent && dashContent.caffeineActive) return color03Col
        if (tileId === "pomodoro" && root && root.timerActive) return color03Col
        return sealCol
    }

    readonly property color beanColor: {
        if (isActive || (tileId === "caffeine" && dashContent && dashContent.caffeineActive) || (tileId === "pomodoro" && root && root.timerActive) || (tileId === "nightlight" && dashContent && dashContent.nightMode > 0) || (is1x1 && isLit)) {
            return paperCol
        }
        return tileAccentCol
    }

    // ── Tile Background & Border ──
    Rectangle {
        id: tileBg
        anchors.fill: parent
        radius: parent.radius
        color: tileRoot.effectiveTileColor
        border.color: tileRoot.isDropTarget ? tileRoot.sealCol : ((dashContent && dashContent.editTilesMode) ? Qt.rgba(tileRoot.tileAccentCol.r, tileRoot.tileAccentCol.g, tileRoot.tileAccentCol.b, 0.45) : "transparent")
        border.width: tileRoot.isDropTarget ? 2 : ((dashContent && dashContent.editTilesMode) ? 1.5 : 0)
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        z: 0
    }

    // ── Foreground Color for 1x2 text ──
    readonly property color fgColor: {
        if (isActive || (tileId === "caffeine" && dashContent && dashContent.caffeineActive) || (tileId === "pomodoro" && root && root.timerActive) || (tileId === "nightlight" && dashContent && dashContent.nightMode > 0)) {
            return paperCol
        }
        return inkCol
    }

    // ── Tile Title and Subtitle ──
    readonly property string tileTitle: {
        switch (tileId) {
            case "wifi": return "Wi-Fi"
            case "bluetooth": return "Bluetooth"
            case "notifications": return "Notifications"
            case "screentime": return "Screen Time"
            case "nightlight": return "Night Light"
            case "caffeine": return "Caffeine"
            case "battery": return "Battery"
            case "temperature": return "CPU Temp"
            case "plugins": return "Omarchy Plugins"
            case "updates": return "Updates"
            case "pomodoro": return "Pomodoro"
            case "quickshare": return "Quick Share"
            case "theme": return "Themes"
            case "wallpaper": return "Wallpapers"
            case "notes": return "Notes"
            case "calendar": return "Calendar"
            case "settings": return "Settings"
            default: return tileId
        }
    }

    readonly property string tileSubtitle: {
        switch (tileId) {
            case "wifi": return (dashContent && dashContent.currentWifiName) ? dashContent.currentWifiName : "Wi-Fi"
            case "bluetooth":
                if (!dashContent) return "Off"
                return dashContent.currentBtName === "Bluetooth"
                    ? (dashContent.btPowered ? "On" : "Off")
                    : dashContent.currentBtName
            case "notifications":
                let cnt = (root && root.notifCount) ? root.notifCount : 0
                return cnt > 0 ? (cnt + " new") : "All caught up"
            case "screentime": return "Usage & Trends"
            case "nightlight":
                let nm = (dashContent && dashContent.nightMode) ? dashContent.nightMode : 0
                return nm === 2 ? "Intense" : (nm === 1 ? "Soft" : "Off")
            case "caffeine": return (dashContent && dashContent.caffeineActive) ? "Active" : "Sleepy"
            case "battery":
                return (root && root.systemBatteryPercent !== undefined && root.systemBatteryPercent !== null)
                    ? (root.systemBatteryPercent + "%")
                    : "Power & Health"
            case "temperature": return ((dashContent && dashContent.cpuTemp) ? dashContent.cpuTemp : 45) + "°C"
            case "plugins": return "Extensions & Tools"
            case "updates":
                let up = (root && root.systemUpdatesAvailable) ? root.systemUpdatesAvailable : 0
                return up > 0 ? (up + " available") : "Up to date"
            case "pomodoro":
                if (!root || !root.timerActive) return "25m Focus"
                if (root.timerPaused) return "Paused"
                let sec = root.timerRemaining || 0
                let m = Math.floor(sec / 60)
                let s = sec % 60
                return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
            case "quickshare": return "LocalSend"
            case "theme": return "Color Scheme"
            case "wallpaper": return "Gallery & Picker"
            case "notes": return "Quick Notes"
            case "calendar": return "Events & Agenda"
            case "settings": return root ? (root.isBarNotch ? "Notch Mode" : "Pill Mode") : "Customize"
            default: return ""
        }
    }

    readonly property string tileIcon: {
        switch (tileId) {
            case "wifi": return "wifi"
            case "bluetooth": return "bluetooth"
            case "notifications":
                let c = (root && root.notifCount) ? root.notifCount : 0
                return c > 0 ? "notifications_active" : "notifications"
            case "screentime": return "hourglass_empty"
            case "nightlight": return "nightlight_round"
            case "caffeine": return "local_cafe"
            case "battery": return "bolt"
            case "temperature": return "thermostat"
            case "plugins": return "widgets"
            case "updates": return "system_update"
            case "pomodoro": return (root && root.timerActive) ? "timer" : "hourglass_top"
            case "quickshare": return "share"
            case "theme": return "palette"
            case "wallpaper": return "wallpaper"
            case "notes": return "edit_note"
            case "calendar": return "calendar_month"
            case "settings": return "settings"
            default: return "settings"
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── 1x2 TILE LAYOUT (Horizontal Pill: Icon + Text) ──────────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout1x2
        anchors.fill: parent
        visible: tileRoot.is1x2
        z: 2

        // Inner circle toggle button for Wi-Fi / Bluetooth
        Rectangle {
            id: innerToggleBtn
            visible: tileId === "wifi" || tileId === "bluetooth"
            width: 40
            height: 40
            radius: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            z: 10

            color: tileRoot.isActive
                ? (innerMa.containsMouse ? Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.28) : Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.16))
                : (tileRoot.isLit
                    ? (innerMa.containsMouse ? Qt.lighter(tileRoot.sealCol, 1.12) : tileRoot.sealCol)
                    : (innerMa.containsMouse ? Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.18) : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.10)))
            Behavior on color { ColorAnimation { duration: 160 } }

            IconText {
                anchors.centerIn: parent
                text: tileRoot.tileIcon
                color: tileRoot.isActive ? tileRoot.paperCol : (tileRoot.isLit ? tileRoot.paperCol : tileRoot.inkCol)
                font.pixelSize: 20
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                id: innerMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: (dashContent && dashContent.editTilesMode) ? Qt.OpenHandCursor : Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onPressed: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        tileTip.hide()
                        if (tileId === "nightlight" && dashContent) {
                            let pt = tileRoot.mapToItem(dashContent, 0, tileRoot.height)
                            dashContent.toggleNightLightPopup(pt.x + tileRoot.width / 2, pt.y)
                            mouse.accepted = true
                            return
                        }
                        if (dashContent) dashContent.toggleEditMode(tileId)
                        mouse.accepted = true
                    }
                }

                onClicked: (mouse) => {
                    tileTip.hide()
                    if (mouse.button === Qt.RightButton) return
                    if (dashContent && dashContent.editTilesMode) {
                        dashContent.selectedTileId = tileId
                        dashContent.forceActiveFocus()
                        return
                    }
                    if (!dashContent) return
                    if (tileId === "wifi") {
                        if (tileRoot.isLit) {
                            dashContent.currentWifiName = "Wi-Fi"
                        } else {
                            dashContent.currentWifiName = "Searching..."
                        }
                        Quickshell.execDetached(["bash", "-c", "nmcli radio wifi | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on"])
                        if (dashContent.statusTimer) dashContent.statusTimer.restart()
                    } else if (tileId === "bluetooth") {
                        if (dashContent.btPowered) {
                            dashContent.btPowered = false
                            dashContent.currentBtName = "Bluetooth"
                        } else {
                            dashContent.btPowered = true
                            dashContent.currentBtName = "Searching..."
                        }
                        Quickshell.execDetached(["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"])
                        if (dashContent.statusTimer) dashContent.statusTimer.restart()
                    }
                }
            }
        }

        // Standard Icon for other tiles
        IconText {
            id: standardIcon
            visible: tileId !== "wifi" && tileId !== "bluetooth"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 14
            text: tileRoot.tileIcon
            color: (tileId === "temperature" && dashContent) ? dashContent.cpuTempColor : tileRoot.fgColor
            font.pixelSize: 22
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        // Title and Subtitle Text Column
        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: (tileId === "wifi" || tileId === "bluetooth") ? innerToggleBtn.right : standardIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 2

            Text {
                text: tileRoot.tileTitle
                color: tileRoot.fgColor
                font.pixelSize: 13
                font.family: tileRoot.barFontFam
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Text {
                text: tileRoot.tileSubtitle
                color: tileRoot.fgColor
                opacity: (tileRoot.isLit || tileRoot.isActive) ? 0.85 : 0.60
                font.pixelSize: 11
                font.family: tileRoot.barFontFam
                elide: Text.ElideRight
                width: parent.width - (tileId === "pomodoro" && root && root.timerActive ? 32 : 0)
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        // Inline Stop / Reset button for Pomodoro in 1x2 mode
        Item {
            visible: tileId === "pomodoro" && (root && root.timerActive)
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
            width: 28
            height: 28
            z: 20

            Rectangle {
                anchors.fill: parent
                radius: 14
                color: pomoStopMa.containsMouse ? Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.28) : Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.16)
            }

            IconText {
                anchors.centerIn: parent
                text: "stop"
                color: tileRoot.fgColor
                font.pixelSize: 16
            }

            MouseArea {
                id: pomoStopMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    mouse.accepted = true
                    if (root) root.resetTimer()
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── 1x1 TILE LAYOUT (Compact Icon Button) ───────────────────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout1x1
        anchors.fill: parent
        visible: tileRoot.is1x1
        z: 2

        IconText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: tileId === "nightlight" ? -2 : 0
            text: tileRoot.tileIcon
            color: {
                if (tileId === "temperature" && dashContent) return dashContent.cpuTempColor
                // If active or lit, use contrasting paper color on the seal accent background
                if (tileRoot.isLit || tileRoot.isActive) return tileRoot.paperCol
                return tileMa.containsMouse ? tileRoot.sealCol : tileRoot.inkCol
            }
            font.pixelSize: 22
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        // Unread Notification badge dot
        Rectangle {
            visible: tileId === "notifications" && (root && (root.notifCount || 0) > 0)
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            width: 8
            height: 8
            radius: 4
            color: tileRoot.color01Col
        }

        // Dual indicator dashes for night light
        Row {
            visible: tileId === "nightlight"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3

            Rectangle {
                width: 5
                height: 3
                radius: 1.5
                color: (dashContent && dashContent.nightMode > 0) ? tileRoot.paperCol : tileRoot.inkCol
                opacity: (dashContent && dashContent.nightMode >= 1) ? 0.95 : 0.25
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                width: 5
                height: 3
                radius: 1.5
                color: (dashContent && dashContent.nightMode > 0) ? tileRoot.paperCol : tileRoot.inkCol
                opacity: (dashContent && dashContent.nightMode === 2) ? 0.95 : 0.25
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── 2x2 TILE LAYOUT (Rich Expanded Card) ────────────────────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout2x2
        anchors.fill: parent
        visible: tileRoot.is2x2
        z: 2

        // Top Row: Icon Badge (left) + Title / Subtitle Column (right)
        Item {
            id: header2x2
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            height: 38

            Rectangle {
                id: iconWrap2x2
                width: 38
                height: 38
                radius: 14
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: tileRoot.isActive
                    ? (iconWrap2x2Ma.containsMouse ? Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.28) : Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.16))
                    : (tileRoot.isLit
                        ? (iconWrap2x2Ma.containsMouse ? Qt.lighter(tileRoot.sealCol, 1.12) : tileRoot.sealCol)
                        : (iconWrap2x2Ma.containsMouse ? Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.18) : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.10)))
                Behavior on color { ColorAnimation { duration: 160 } }

                IconText {
                    anchors.centerIn: parent
                    text: tileRoot.tileIcon
                    color: tileRoot.isActive ? tileRoot.paperCol : (tileRoot.isLit ? tileRoot.paperCol : tileRoot.inkCol)
                    font.pixelSize: 20
                }

                MouseArea {
                    id: iconWrap2x2Ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        mouse.accepted = true
                        if (tileId === "wifi" || tileId === "bluetooth") {
                            innerMa.clicked(mouse)
                        } else if (dashContent) {
                            dashContent.triggerTileAction(tileId)
                        }
                    }
                }
            }

            Column {
                anchors.left: iconWrap2x2.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: tileRoot.tileTitle
                    color: tileRoot.fgColor
                    font.pixelSize: 13
                    font.family: tileRoot.barFontFam
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: parent.width
                }

                Text {
                    text: tileRoot.tileSubtitle
                    color: tileRoot.fgColor
                    opacity: 0.70
                    font.pixelSize: 11
                    font.family: tileRoot.barFontFam
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        // Center / Main Info Area
        Item {
            anchors.top: header2x2.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12

            // 1) Battery: big percent display
            Row {
                visible: tileId === "battery"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: 6
                Text {
                    text: (root && root.systemBatteryPercent !== undefined) ? root.systemBatteryPercent + "%" : "100%"
                    color: tileRoot.fgColor
                    font.pixelSize: 22
                    font.family: tileRoot.barFontFam
                    font.weight: Font.Bold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root && root.systemBatteryCharging) ? "Charging" : "Battery"
                    color: tileRoot.fgColor
                    opacity: 0.7
                    font.pixelSize: 11
                    font.family: tileRoot.barFontFam
                }
            }

            // 2) Pomodoro: Big timer + play/pause
            Row {
                visible: tileId === "pomodoro"
                anchors.centerIn: parent
                spacing: 8
                Text {
                    text: tileRoot.tileSubtitle
                    color: tileRoot.fgColor
                    font.pixelSize: 20
                    font.family: tileRoot.barFontFam
                    font.weight: Font.Bold
                }
            }

            // 3) CPU Temp
            Row {
                visible: tileId === "temperature"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                spacing: 6
                Text {
                    text: ((dashContent && dashContent.cpuTemp) ? dashContent.cpuTemp : 45) + "°C"
                    color: (dashContent && dashContent.cpuTempColor) ? dashContent.cpuTempColor : tileRoot.fgColor
                    font.pixelSize: 22
                    font.family: tileRoot.barFontFam
                    font.weight: Font.Bold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Temperature"
                    color: tileRoot.fgColor
                    opacity: 0.7
                    font.pixelSize: 11
                    font.family: tileRoot.barFontFam
                }
            }

            // 4) General Status Chip (for other tiles)
            Rectangle {
                visible: tileId !== "battery" && tileId !== "pomodoro" && tileId !== "temperature"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 24
                width: chipText.implicitWidth + 18
                radius: 12
                color: tileRoot.isActive
                    ? Qt.rgba(tileRoot.paperCol.r, tileRoot.paperCol.g, tileRoot.paperCol.b, 0.18)
                    : (tileRoot.isLit
                        ? Qt.rgba(tileRoot.sealCol.r, tileRoot.sealCol.g, tileRoot.sealCol.b, 0.22)
                        : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.08))

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: tileRoot.isLit ? "Active" : "Tap to open"
                    color: tileRoot.isActive ? tileRoot.paperCol : (tileRoot.isLit ? tileRoot.sealCol : tileRoot.inkCol)
                    font.pixelSize: 11
                    font.family: tileRoot.barFontFam
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── CORNER BEAN INDICATOR (Bottom-right highlight indicator) ─────────
    // ══════════════════════════════════════════════════════════════════════
    Shape {
        id: cornerBean
        anchors.fill: parent
        visible: opacity > 0
        opacity: tileRoot.isSelected ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        z: 25
        preferredRendererType: Shape.CurveRenderer

        readonly property real strokeW: tileRoot.is1x1 ? 4.5 : 5.5
        readonly property real r: Math.max(4, tileRoot.radius - 1.0)
        readonly property real cx: tileRoot.width - tileRoot.radius
        readonly property real cy: tileRoot.height - tileRoot.radius

        ShapePath {
            strokeColor: tileRoot.beanColor
            strokeWidth: cornerBean.strokeW
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: cornerBean.cx
                centerY: cornerBean.cy
                radiusX: cornerBean.r
                radiusY: cornerBean.r
                startAngle: 28
                sweepAngle: 34
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── RESIZE INDICATOR HANDLE (Image 2 Border Rectangle Grabber) ───────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: resizeIndicator
        visible: dashContent && dashContent.editTilesMode
        anchors.horizontalCenter: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 36
        z: 35

        // Vertical pill handle hugging the right border (Image 2 style)
        Rectangle {
            anchors.centerIn: parent
            width: 5
            height: 18
            radius: 2.5
            color: tileRoot.isSelected ? tileRoot.paperCol : tileRoot.tileAccentCol
            border.color: tileRoot.isSelected ? tileRoot.tileAccentCol : Qt.rgba(0, 0, 0, 0.25)
            border.width: 1

            scale: resizeMa.pressed ? 0.85 : (resizeMa.containsMouse ? 1.25 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: resizeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton

            property real startX: 0
            property real startY: 0
            property bool isResizingDrag: false

            onPressed: (mouse) => {
                startX = mouse.x
                startY = mouse.y
                isResizingDrag = false
                if (dashContent) dashContent.selectedTileId = tileRoot.tileId
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return
                let dx = mouse.x - startX
                let dy = mouse.y - startY
                if ((Math.abs(dx) > 18 || Math.abs(dy) > 18) && dashContent) {
                    isResizingDrag = true
                    if (tileRoot.is1x1 && dx > 18) {
                        dashContent.setTileSpan(tileId, 2)
                    } else if (tileRoot.is1x2) {
                        if (dy > 18) {
                            dashContent.setTileSpan(tileId, 4)
                        } else if (dx < -18) {
                            dashContent.setTileSpan(tileId, 1)
                        }
                    } else if (tileRoot.is2x2) {
                        if (dy < -18 || dx < -18) {
                            dashContent.setTileSpan(tileId, 2)
                        }
                    }
                }
            }

            onClicked: (mouse) => {
                if (!isResizingDrag && dashContent) {
                    dashContent.cycleTileSpan(tileId)
                }
            }
        }
    }

    // ── Tooltip for compact 1x1 view in normal mode ──
    TooltipMixin {
        id: tileTip
        root: tileRoot.root
        owner: tileRoot
        text: tileRoot.tileTitle + ": " + tileRoot.tileSubtitle
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── MAIN INTERACTION MOUSE AREA ──────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════════
    MouseArea {
        id: tileMa
        anchors.fill: parent
        z: 1
        hoverEnabled: true
        cursorShape: (dashContent && dashContent.editTilesMode) ? Qt.OpenHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real pressX: 0
        property real pressY: 0
        property bool dragInitiated: false

        onEntered: {
            if (dashContent && !dashContent.editTilesMode && tileRoot.is1x1) {
                tileTip.show()
            }
            if (dashContent && !dashContent.editTilesMode) {
                dashContent.selectedTileId = tileId
            }
        }
        onExited: {
            tileTip.hide()
        }

        onPressed: (mouse) => {
            pressX = mouse.x
            pressY = mouse.y
            dragInitiated = false

            if (mouse.button === Qt.RightButton) {
                tileTip.hide()
                if (tileId === "nightlight" && dashContent) {
                    let pt = tileRoot.mapToItem(dashContent, 0, tileRoot.height)
                    dashContent.toggleNightLightPopup(pt.x + tileRoot.width / 2, pt.y)
                    mouse.accepted = true
                    return
                }
                if (dashContent) dashContent.toggleEditMode(tileId)
                mouse.accepted = true
                return
            }

            if (dashContent) {
                dashContent.selectedTileId = tileId
                dashContent.forceActiveFocus()
            }
        }

        onPositionChanged: (mouse) => {
            if (!dashContent || !dashContent.editTilesMode || mouse.buttons !== Qt.LeftButton) return

            let dx = mouse.x - pressX
            let dy = mouse.y - pressY

            if (!dragInitiated && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
                dragInitiated = true
                let pt = tileMa.mapToItem(dashContent, mouse.x, mouse.y)
                dashContent.startDraggingTile(tileId, pt.x, pt.y)
            }

            if (dragInitiated) {
                let pt = tileMa.mapToItem(dashContent, mouse.x, mouse.y)
                dashContent.updateDraggingTile(pt.x, pt.y)
            }
        }

        onClicked: (mouse) => {
            tileTip.hide()
            if (mouse.button === Qt.RightButton) return
            if (dragInitiated) return
            if (!dashContent) return

            dashContent.selectedTileId = tileId
            dashContent.forceActiveFocus()

            if (dashContent.editTilesMode) {
                return
            }

            dashContent.triggerTileAction(tileId)
        }

        onReleased: (mouse) => {
            if (dragInitiated) {
                dragInitiated = false
                if (dashContent) dashContent.finishDraggingTile()
            }
        }
    }
}

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../modules"

Rectangle {
    id: tileRoot

    property var dashContent: null
    readonly property var root: (dashContent && dashContent.root) ? dashContent.root : null
    property string tileId: ""
    property int span: 1          // 1 (1x1) or 2 (1x2)
    property int tileIndex: -1
    property int gridPage: 0
    property int gridRow: 0
    property int gridCol: 0

    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color paperCol: (root && root.paper) ? root.paper : "#000000"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#22d3ee"
    readonly property color fillIdleCol: (root && root.fillIdle) ? root.fillIdle : Qt.rgba(1, 1, 1, 0.08)
    readonly property color fillHoverCol: (root && root.fillHover) ? root.fillHover : Qt.rgba(1, 1, 1, 0.14)
    readonly property color color01Col: (root && root.color01) ? root.color01 : "#f59e0b"
    readonly property color color03Col: (root && root.color03) ? root.color03 : "#10b981"
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "sans-serif"

    readonly property bool isSelected: (dashContent && dashContent.editTilesMode) ? (dashContent.selectedTileId === tileId) : false
    readonly property bool isBeingDragged: (dashContent && dashContent.draggingTileId) ? (dashContent.draggingTileId === tileId) : false
    readonly property bool isDropTarget: (dashContent && dashContent.dropTargetTileId === tileId && !isBeingDragged)

    height: 56
    radius: span === 2 ? 28 : 18
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
            case "cpu": return dashContent.activeDetailView === "cpu"
            case "memory": return dashContent.activeDetailView === "memory"
            case "notifications": return dashContent.activeDetailView === "notifications"
            case "screentime": return dashContent.activeDetailView === "screentime"
            case "nightlight": return (dashContent.nightMode || 0) > 0
            case "caffeine": return dashContent.caffeineActive || false
            case "battery": return dashContent.activeDetailView === "battery"
            case "plugins": return dashContent.activeDetailView === "plugins"
            case "updates": return dashContent.activeDetailView === "updates" || dashContent.activeDetailView === "packages"
            case "lockscreen": return dashContent.activeDetailView === "lockscreen"
            case "pomodoro": return (root && root.timerActive) || false
            case "theme": return dashContent.activeDetailView === "theme"
            case "wallpaper": return dashContent.activeDetailView === "wallpaper"
            case "notes": return dashContent.activeDetailView === "notes"
            case "calendar": return dashContent.activeDetailView === "calendar"
            default: return false
        }
    }

    readonly property bool isLit: {
        if (!dashContent) return false
        if (tileId === "wifi") return dashContent.currentWifiName !== "Wi-Fi" && dashContent.currentWifiName !== "Searching..."
        if (tileId === "bluetooth") return dashContent.btPowered || false
        if (tileId === "nightlight") return (dashContent.nightMode || 0) > 0
        if (tileId === "caffeine") return dashContent.caffeineActive || false
        if (tileId === "pomodoro") return (root && root.timerActive) || false
        return isActive
    }

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
        if (span === 1 && isLit) {
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

    // ── Tile Background & Border (Standard Rounded Rectangle matching Image 2) ──
    Rectangle {
        id: tileBg
        anchors.fill: parent
        radius: parent.radius
        color: tileRoot.effectiveTileColor
        border.color: tileRoot.isSelected ? tileRoot.tileAccentCol : (tileRoot.isDropTarget ? tileRoot.sealCol : (tileRoot.isActive ? tileRoot.paperCol : ((dashContent && dashContent.editTilesMode) ? Qt.rgba(tileRoot.tileAccentCol.r, tileRoot.tileAccentCol.g, tileRoot.tileAccentCol.b, 0.45) : "transparent")))
        border.width: tileRoot.isSelected ? 2 : (tileRoot.isDropTarget ? 2 : (tileRoot.isActive ? 2 : ((dashContent && dashContent.editTilesMode) ? 1.5 : 0)))
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
            case "cpu": return "CPU"
            case "memory": return "Memory"
            case "notifications": return "Notifications"
            case "screentime": return "Screen Time"
            case "nightlight": return "Night Light"
            case "caffeine": return "Caffeine"
            case "battery": return "Battery"
            case "temperature": return "CPU Temp"
            case "plugins": return "Omarchy Plugins"
            case "updates": return "Updates"
            case "lockscreen": return "Lock Screen"
            case "pomodoro": return "Pomodoro"
            case "quickshare": return "Quick Share"
            case "theme": return "Themes"
            case "wallpaper": return "Wallpapers"
            case "notes": return "Notes"
            case "calendar": return "Calendar"
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
            case "cpu": return ((root && root.systemCpuPercent !== undefined) ? root.systemCpuPercent : 0) + "%"
            case "memory":
                if (root && root.systemMemUsedGiB !== undefined && root.systemMemTotalGiB !== undefined) {
                    return root.systemMemUsedGiB.toFixed(1) + "/" + root.systemMemTotalGiB.toFixed(0) + "G"
                }
                return "0/0G"
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
            case "lockscreen": return "Settings & Security"
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
            default: return ""
        }
    }

    readonly property string tileIcon: {
        switch (tileId) {
            case "wifi": return "wifi"
            case "bluetooth": return "bluetooth"
            case "cpu": return "memory"
            case "memory": return "dns"
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
            case "lockscreen": return "lock"
            case "pomodoro": return (root && root.timerActive) ? "timer" : "hourglass_top"
            case "quickshare": return "share"
            case "theme": return "palette"
            case "wallpaper": return "wallpaper"
            case "notes": return "edit_note"
            case "calendar": return "calendar_month"
            default: return "settings"
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── 1x2 TILE LAYOUT (Horizontal Pill: Icon + Text) ──────────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout1x2
        anchors.fill: parent
        visible: tileRoot.span === 2

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

            color: tileRoot.isLit
                ? (innerMa.containsMouse ? Qt.lighter(tileRoot.sealCol, 1.12) : tileRoot.sealCol)
                : (innerMa.containsMouse ? Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.18) : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.10))
            Behavior on color { ColorAnimation { duration: 160 } }

            IconText {
                anchors.centerIn: parent
                text: tileRoot.tileIcon
                color: tileRoot.isLit ? tileRoot.paperCol : tileRoot.inkCol
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
                        if (dashContent) dashContent.toggleEditMode(tileId)
                        mouse.accepted = true
                    }
                }

                onClicked: (mouse) => {
                    tileTip.hide()
                    if (mouse.button === Qt.RightButton) return
                    if (dashContent && dashContent.editTilesMode) {
                        dashContent.selectedTileId = tileId
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
        visible: tileRoot.span === 1

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
    // ── RESIZE INDICATOR HANDLE (Image 3 Jellybean Notch Grabber) ────────
    // ══════════════════════════════════════════════════════════════════════
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
            cursorShape: Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton

            property real startX: 0
            property bool isResizingDrag: false

            onPressed: (mouse) => {
                startX = mouse.x
                isResizingDrag = false
                if (dashContent) dashContent.selectedTileId = tileRoot.tileId
            }

            onPositionChanged: (mouse) => {
                if (!pressed) return
                let dx = mouse.x - startX
                if (Math.abs(dx) > 16 && dashContent) {
                    isResizingDrag = true
                    if (dx > 16 && tileRoot.span === 1) {
                        dashContent.setTileSpan(tileId, 2)
                    } else if (dx < -16 && tileRoot.span === 2) {
                        dashContent.setTileSpan(tileId, 1)
                    }
                }
            }

            onClicked: (mouse) => {
                if (!isResizingDrag && dashContent) {
                    dashContent.toggleTileSpan(tileId)
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
        hoverEnabled: true
        cursorShape: (dashContent && dashContent.editTilesMode) ? Qt.OpenHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property real pressX: 0
        property real pressY: 0
        property bool dragInitiated: false

        onEntered: {
            if (dashContent && !dashContent.editTilesMode && tileRoot.span === 1) {
                tileTip.show()
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
                if (dashContent) dashContent.toggleEditMode(tileId)
                mouse.accepted = true
                return
            }

            if (dashContent && dashContent.editTilesMode) {
                dashContent.selectedTileId = tileId
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

            if (dashContent.editTilesMode) {
                dashContent.selectedTileId = tileId
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

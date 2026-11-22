import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import "../../modules"
import "../../modules/common"
import "../../motion"

ClippingRectangle {
    id: tileRoot
    z: isSelected ? 2 : 0

    property var dashContent: null
    readonly property var root: (dashContent && dashContent.root) ? dashContent.root : null
    property string tileId: ""
    property string tileShape: ""
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
    readonly property bool isHovered: tileMa.containsMouse

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

    // ── Live Telemetry Progress (0..1) for Dashboard Micro-Visualizations ──
    readonly property real telemetryRatio: {
        if (tileId === "battery" && root && root.systemBatteryPercent !== undefined && root.systemBatteryPercent !== null) {
            return Math.max(0, Math.min(1, root.systemBatteryPercent / 100.0))
        }
        if (tileId === "pomodoro" && root && root.timerActive) {
            var total = 1500
            var rem = root.timerRemaining || 0
            return Math.max(0, Math.min(1, 1.0 - (rem / total)))
        }
        if (tileId === "temperature" && dashContent) {
            return Math.max(0, Math.min(1, ((dashContent.cpuTemp || 45) - 25) / 70.0))
        }
        return 0
    }

    // ── Expressive M3E Shape Morphing (No Borders) ──
    height: is2x2 ? 122 : 56
    radius: {
        if (tileMa.pressed) return 13
        if (is1x1) return isTileActive ? 16 : (isHovered ? 18 : 28)
        if (is2x2) return isTileActive ? 18 : (isHovered ? 20 : 24)
        return isActive ? 16 : (isHovered ? 18 : 28)
    }
    border.width: 0

    Behavior on height { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.2 } }
    Behavior on width { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.2 } }
    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }

    // ── M3 Expressive SpringPress (Squishes self + nudges neighboring tiles on spring) ──
    SpringPress {
        id: tileSpring
        pressScale: 0.91
        pushReach: 165
        pushDistance: 10
        interactive: !(dashContent && dashContent.editTilesMode)
    }

    // Drop-target spring pop in edit mode (borderless)
    property real editPopScale: isDropTarget ? 1.06 : ((dashContent && dashContent.editTilesMode && isSelected) ? 1.03 : 1.0)
    Behavior on editPopScale { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.002 } }

    opacity: isBeingDragged ? 0.25 : 1.0
    Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }

    // ── Tile Surface Color (Borderless Layered Tonal System) ──
    readonly property color tileAccentCol: {
        if (tileId === "nightlight" && dashContent) {
            let m = dashContent.nightMode || 0
            return m === 2 ? color01Col : (m === 1 ? color03Col : sealCol)
        }
        if (tileId === "caffeine" && dashContent && dashContent.caffeineActive) return color03Col
        if (tileId === "pomodoro" && root && root.timerActive) return color03Col
        if (tileId === "temperature" && dashContent) return dashContent.cpuTempColor
        return sealCol
    }

    readonly property color effectiveTileColor: {
        if (tileId === "nightlight" && dashContent) {
            let m = dashContent.nightMode || 0
            if (m === 2) return isHovered ? Qt.lighter(color01Col, 1.08) : color01Col
            if (m === 1) return isHovered ? Qt.lighter(color03Col, 1.08) : color03Col
        }
        if (tileId === "caffeine" && dashContent && dashContent.caffeineActive) {
            return isHovered ? Qt.lighter(color03Col, 1.08) : color03Col
        }
        if (tileId === "pomodoro" && root && root.timerActive) {
            return isHovered ? Qt.lighter(color03Col, 1.08) : color03Col
        }
        if (is1x1 && isLit) {
            return isHovered ? Qt.lighter(sealCol, 1.10) : sealCol
        }
        if (isActive) {
            return isHovered ? Qt.lighter(sealCol, 1.10) : sealCol
        }
        // Subtle tonal elevation for connected 1x2 tiles & interactive hover
        if (is1x2 && isLit) {
            return isHovered
                ? Qt.rgba(sealCol.r * 0.25 + inkCol.r * 0.75, sealCol.g * 0.25 + inkCol.g * 0.75, sealCol.b * 0.25 + inkCol.b * 0.75, 0.16)
                : Qt.rgba(sealCol.r * 0.22 + inkCol.r * 0.78, sealCol.g * 0.22 + inkCol.g * 0.78, sealCol.b * 0.22 + inkCol.b * 0.78, 0.11)
        }
        if (isDropTarget) {
            return Qt.rgba(sealCol.r, sealCol.g, sealCol.b, 0.24)
        }
        return isHovered
            ? Qt.rgba(inkCol.r, inkCol.g, inkCol.b, 0.13)
            : Qt.rgba(inkCol.r, inkCol.g, inkCol.b, 0.068)
    }

    color: effectiveTileColor
    Behavior on color { ColorAnimation { duration: 180 } }

    readonly property bool hasSolidAccentBg: isActive
        || (tileId === "caffeine" && dashContent && dashContent.caffeineActive)
        || (tileId === "pomodoro" && root && root.timerActive)
        || (tileId === "nightlight" && dashContent && dashContent.nightMode > 0)
        || (is1x1 && isLit)

    readonly property color fgColor: {
        if (hasSolidAccentBg) {
            var bgCol = effectiveTileColor
            var luma = bgCol.r * 0.299 + bgCol.g * 0.587 + bgCol.b * 0.114
            return luma > 0.55 ? "#121212" : "#ffffff"
        }
        return inkCol
    }

    readonly property color beanColor: hasSolidAccentBg ? fgColor : tileAccentCol

    // ── Ambient Telemetry Wash & Tonal Depth Inside Tile (No Borders) ──
    Item {
        anchors.fill: parent
        z: 0

        // Live telemetry level wash (Battery %, Pomodoro progress, CPU Thermal)
        Rectangle {
            visible: tileRoot.telemetryRatio > 0 && !tileRoot.is1x1
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * tileRoot.telemetryRatio
            color: tileRoot.hasSolidAccentBg
                ? Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.14)
                : Qt.rgba(tileRoot.tileAccentCol.r, tileRoot.tileAccentCol.g, tileRoot.tileAccentCol.b, 0.14)
            Behavior on width { SpringAnimation { spring: Motion.spatialSlowSpring; damping: Motion.spatialSlowDamping; epsilon: 0.5 } }
        }

        // Soft radial tonal spotlight for lit 1x2 modules (Wi-Fi, Bluetooth)
        Rectangle {
            visible: tileRoot.is1x2 && tileRoot.isLit && !tileRoot.hasSolidAccentBg
            x: -16
            anchors.verticalCenter: parent.verticalCenter
            width: 84
            height: 84
            radius: 42
            color: tileRoot.tileAccentCol
            opacity: tileRoot.isHovered ? 0.18 : 0.11
            Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
        }

        // Subtle edit-mode tonal pulse
        Rectangle {
            anchors.fill: parent
            color: tileRoot.tileAccentCol
            opacity: (dashContent && dashContent.editTilesMode && tileRoot.isSelected) ? 0.14 : 0.0
            Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
        }
    }

    // ── Tile Title, Subtitle & Icon ──
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
            case "plugins": return "Plugins"
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
                return cnt > 0 ? (cnt + " unread") : "All caught up"
            case "screentime": return "Usage & Trends"
            case "nightlight":
                let nm = (dashContent && dashContent.nightMode) ? dashContent.nightMode : 0
                return nm === 2 ? "Intense" : (nm === 1 ? "Soft" : "Off")
            case "caffeine": return (dashContent && dashContent.caffeineActive) ? "Awake" : "Idle"
            case "battery":
                return (root && root.systemBatteryPercent !== undefined && root.systemBatteryPercent !== null)
                    ? (root.systemBatteryPercent + "%" + (root.systemBatteryCharging ? " · Charging" : ""))
                    : "Power & Health"
            case "temperature": return ((dashContent && dashContent.cpuTemp) ? dashContent.cpuTemp : 45) + "°C"
            case "plugins": return "Extensions"
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
            case "wallpaper": return "Gallery"
            case "notes": return "Quick Notes"
            case "calendar": return "Agenda"
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
    // ── 1x2 TILE LAYOUT (Dashboard Telemetry Module) ────────────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout1x2
        anchors.fill: parent
        visible: tileRoot.is1x2
        z: 2

        // Interactive Icon Pod (Morphs radius + has independent SpringPress for Wi-Fi/BT)
        Rectangle {
            id: innerToggleBtn
            width: 40
            height: 40
            radius: (tileRoot.isLit || tileRoot.isActive) ? 13 : (innerMa.containsMouse ? 15 : 20)
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            border.width: 0
            z: 10

            readonly property bool isRadioTile: tileId === "wifi" || tileId === "bluetooth"

            color: {
                if (tileRoot.hasSolidAccentBg) {
                    return innerMa.containsMouse
                        ? Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.24)
                        : Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.14)
                }
                if (tileRoot.isLit) {
                    return innerMa.containsMouse ? Qt.lighter(tileRoot.tileAccentCol, 1.12) : tileRoot.tileAccentCol
                }
                return innerMa.containsMouse
                    ? Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.16)
                    : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.08)
            }

            Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
            Behavior on color { ColorAnimation { duration: 160 } }

            SpringPress {
                pressScale: 0.84
                pushReach: 80
                pushDistance: 6
                interactive: innerToggleBtn.isRadioTile && !(dashContent && dashContent.editTilesMode)
            }

            IconText {
                anchors.centerIn: parent
                text: tileRoot.tileIcon
                color: {
                    if (tileId === "temperature" && dashContent && !tileRoot.hasSolidAccentBg) return dashContent.cpuTempColor
                    if (tileRoot.hasSolidAccentBg) return tileRoot.fgColor
                    if (tileRoot.isLit) return tileRoot.paperCol
                    return tileRoot.inkCol
                }
                font.pixelSize: 20
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                id: innerMa
                anchors.fill: parent
                enabled: innerToggleBtn.isRadioTile
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
                        dashContent.forceActiveFocus()
                        return
                    }
                    if (!dashContent) return
                    if (tileId === "wifi") {
                        dashContent.currentWifiName = tileRoot.isLit ? "Wi-Fi" : "Searching..."
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

        // Title and Subtitle Text Column
        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: innerToggleBtn.right
            anchors.leftMargin: 10
            anchors.right: rightStatusAccessory.left
            anchors.rightMargin: 6
            spacing: 1

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

            Row {
                width: parent.width
                spacing: 5

                // Live status dot for connected / active telemetry
                Rectangle {
                    visible: tileRoot.isLit && !tileRoot.hasSolidAccentBg
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: tileRoot.tileAccentCol
                }

                Text {
                    text: tileRoot.tileSubtitle
                    color: tileRoot.fgColor
                    opacity: (tileRoot.isLit || tileRoot.isActive) ? 0.85 : 0.60
                    font.pixelSize: 11
                    font.family: tileRoot.barFontFam
                    elide: Text.ElideRight
                    width: parent.width - (tileRoot.isLit && !tileRoot.hasSolidAccentBg ? 10 : 0)
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
        }

        // Right-side micro accessory (Stop button for Pomodoro, unread pill for Notifs, or subtle chevron on hover)
        Item {
            id: rightStatusAccessory
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
            width: pomoStopItem.visible ? 26 : (notifBadge1x2.visible ? notifBadge1x2.width : 14)
            height: 26
            z: 20

            // Inline Stop / Reset button for Pomodoro
            Item {
                id: pomoStopItem
                visible: tileId === "pomodoro" && (root && root.timerActive)
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    border.width: 0
                    color: pomoStopMa.containsMouse
                        ? Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.26)
                        : Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.14)
                }

                IconText {
                    anchors.centerIn: parent
                    text: "stop"
                    color: tileRoot.fgColor
                    font.pixelSize: 15
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

            // Unread Notification Count Pill
            Rectangle {
                id: notifBadge1x2
                visible: tileId === "notifications" && (root && (root.notifCount || 0) > 0) && !pomoStopItem.visible
                anchors.centerIn: parent
                height: 18
                width: Math.max(18, notifCountTxt.implicitWidth + 10)
                radius: 9
                border.width: 0
                color: tileRoot.hasSolidAccentBg ? tileRoot.fgColor : tileRoot.tileAccentCol

                Text {
                    id: notifCountTxt
                    anchors.centerIn: parent
                    text: (root && root.notifCount) ? String(root.notifCount) : ""
                    color: tileRoot.hasSolidAccentBg ? tileRoot.effectiveTileColor : tileRoot.paperCol
                    font.pixelSize: 10
                    font.family: tileRoot.barFontFam
                    font.weight: Font.Bold
                }
            }

            // Subtle hover arrow for detail-view tiles
            IconText {
                visible: !pomoStopItem.visible && !notifBadge1x2.visible
                    && (tileId === "wifi" || tileId === "bluetooth" || tileId === "screentime" || tileId === "plugins" || tileId === "battery" || tileId === "updates" || tileId === "theme" || tileId === "wallpaper" || tileId === "settings")
                anchors.centerIn: parent
                text: "chevron_right"
                color: tileRoot.fgColor
                font.pixelSize: 15
                opacity: tileRoot.isHovered ? 0.72 : 0.0
                x: tileRoot.isHovered ? 0 : -4
                Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
                Behavior on x { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── 1x1 TILE LAYOUT (Expressive Morphing Orb / Squircle) ────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout1x1
        anchors.fill: parent
        visible: tileRoot.is1x1
        z: 2

        IconText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: tileId === "nightlight" ? -2 : ((tileId === "battery" || tileId === "temperature") ? -5 : 0)
            text: tileRoot.tileIcon
            color: {
                if (tileId === "temperature" && dashContent && !tileRoot.hasSolidAccentBg) return dashContent.cpuTempColor
                if (tileRoot.isLit || tileRoot.isActive) return tileRoot.fgColor
                return tileRoot.isHovered ? tileRoot.sealCol : tileRoot.inkCol
            }
            font.pixelSize: (tileId === "battery" || tileId === "temperature") ? 19 : 22
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        // Compact live readout for Battery / CPU Temp in 1x1 mode
        Text {
            visible: tileId === "battery" || tileId === "temperature"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: tileId === "battery"
                ? ((root && root.systemBatteryPercent !== undefined) ? (root.systemBatteryPercent + "%") : "--")
                : (((dashContent && dashContent.cpuTemp) ? dashContent.cpuTemp : 45) + "°")
            color: (tileId === "temperature" && dashContent && !tileRoot.hasSolidAccentBg)
                ? dashContent.cpuTempColor
                : ((tileRoot.isLit || tileRoot.isActive) ? tileRoot.fgColor : tileRoot.inkCol)
            opacity: 0.82
            font.pixelSize: 10
            font.family: tileRoot.barFontFam
            font.weight: Font.Bold
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
            border.width: 0
            color: tileRoot.color01Col
        }

        // Dual indicator dashes for night light
        Row {
            visible: tileId === "nightlight"
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3

            Rectangle {
                width: 6
                height: 3
                radius: 1.5
                color: (dashContent && dashContent.nightMode > 0) ? tileRoot.fgColor : tileRoot.inkCol
                opacity: (dashContent && dashContent.nightMode >= 1) ? 0.95 : 0.25
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
            }

            Rectangle {
                width: 6
                height: 3
                radius: 1.5
                color: (dashContent && dashContent.nightMode > 0) ? tileRoot.fgColor : tileRoot.inkCol
                opacity: (dashContent && dashContent.nightMode === 2) ? 0.95 : 0.25
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── 2x2 TILE LAYOUT (Rich Expanded Dashboard Card) ──────────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: layout2x2
        anchors.fill: parent
        visible: tileRoot.is2x2
        z: 2

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
                radius: (tileRoot.isLit || tileRoot.isActive) ? 13 : 19
                border.width: 0
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: tileRoot.hasSolidAccentBg
                    ? Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.16)
                    : (tileRoot.isLit
                        ? tileRoot.sealCol
                        : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.10))
                Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                Behavior on color { ColorAnimation { duration: 160 } }

                IconText {
                    anchors.centerIn: parent
                    text: tileRoot.tileIcon
                    color: tileRoot.hasSolidAccentBg ? tileRoot.fgColor : (tileRoot.isLit ? tileRoot.paperCol : tileRoot.inkCol)
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

        Item {
            anchors.top: header2x2.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12

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

            Rectangle {
                visible: tileId !== "battery" && tileId !== "pomodoro" && tileId !== "temperature"
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 24
                width: chipText.implicitWidth + 18
                radius: 12
                border.width: 0
                color: tileRoot.hasSolidAccentBg
                    ? Qt.rgba(tileRoot.fgColor.r, tileRoot.fgColor.g, tileRoot.fgColor.b, 0.18)
                    : (tileRoot.isLit
                        ? Qt.rgba(tileRoot.sealCol.r, tileRoot.sealCol.g, tileRoot.sealCol.b, 0.22)
                        : Qt.rgba(tileRoot.inkCol.r, tileRoot.inkCol.g, tileRoot.inkCol.b, 0.08))

                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: tileRoot.isLit ? "Active" : "Tap to open"
                    color: tileRoot.hasSolidAccentBg ? tileRoot.fgColor : (tileRoot.isLit ? tileRoot.sealCol : tileRoot.inkCol)
                    font.pixelSize: 11
                    font.family: tileRoot.barFontFam
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // ── CORNER BEAN INDICATOR (Edit Mode tile-size toggle handle) ─────────
    // ══════════════════════════════════════════════════════════════════════
    Shape {
        id: cornerBean
        anchors.fill: parent
        visible: opacity > 0
        opacity: (dashContent && dashContent.editTilesMode) ? 1.0 : 0.0
        scale: resizeMa.pressed ? 0.92 : (resizeMa.containsMouse ? 1.06 : 1.0)
        Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
        Behavior on scale { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.002 } }
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
    // ── CORNER BEAN SIZE-TOGGLE HIT AREA (Edit Mode only) ───────────────
    // ══════════════════════════════════════════════════════════════════════
    Item {
        id: resizeIndicator
        visible: dashContent && dashContent.editTilesMode
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 30
        height: 30
        z: 35

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
                    } else if (tileRoot.is1x2 && dx < -18) {
                        dashContent.setTileSpan(tileId, 1)
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

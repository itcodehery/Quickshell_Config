import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// ── CARDLESS HUD TELEMETRY & INSTRUMENT MATRIX (Borderless, M3 Expressive Spring Physics) ──
Column {
    id: commandDeck
    required property var dashboardContent
    required property var root

    spacing: 18

    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#22d3ee"
    readonly property color color03Col: (root && root.color03) ? root.color03 : "#10b981"
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "Google Sans"

    readonly property color onSealCol: {
        var luma = sealCol.r * 0.299 + sealCol.g * 0.587 + sealCol.b * 0.114
        return luma > 0.55 ? "#121212" : "#ffffff"
    }

    readonly property bool wifiConnected: Boolean(dashboardContent && dashboardContent.currentWifiName !== "Wi-Fi" && dashboardContent.currentWifiName !== "Searching...")
    readonly property bool btPowered: Boolean(dashboardContent && dashboardContent.btPowered)
    readonly property bool caffeineOn: Boolean(dashboardContent && dashboardContent.caffeineActive)
    readonly property bool pomoOn: Boolean(root && root.timerActive)
    readonly property int battPct: (root && typeof root.systemBatteryPercent === "number") ? root.systemBatteryPercent : 100
    readonly property bool battCharging: Boolean(root && root.systemBatteryCharging)

    readonly property string pomoStatusText: {
        if (!pomoOn) return "Ready"
        if (root && root.timerPaused) return "Paused"
        var sec = (root && root.timerRemaining) ? root.timerRemaining : 0
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" + m : "" + m) + ":" + (s < 10 ? "0" + s : "" + s)
    }

    // ══════════════════════════════════════════════════════════════════
    // ── BAND 1: CONNECTIVITY & POWER HUD (Wi-Fi · Bluetooth · Power) ─
    // ══════════════════════════════════════════════════════════════════
    Row {
        width: parent.width
        height: 44
        spacing: 14

        // ── WI-FI ──
        Item {
            width: Math.round((parent.width - 28) * 0.38)
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36
                    radius: commandDeck.wifiConnected ? 18 : 12
                    border.width: 0
                    antialiasing: true
                    color: commandDeck.wifiConnected
                        ? (wifiIconMa.containsMouse ? Qt.lighter(commandDeck.sealCol, 1.08) : commandDeck.sealCol)
                        : Qt.rgba(commandDeck.inkCol.r, commandDeck.inkCol.g, commandDeck.inkCol.b, wifiIconMa.containsMouse ? 0.16 : 0.08)

                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 110; pushDistance: 7 }

                    IconText {
                        anchors.centerIn: parent
                        text: commandDeck.wifiConnected ? "wifi" : "wifi_off"
                        color: commandDeck.wifiConnected ? commandDeck.onSealCol : commandDeck.inkCol
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: wifiIconMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!dashboardContent) return
                            dashboardContent.currentWifiName = commandDeck.wifiConnected ? "Wi-Fi" : "Searching..."
                            Quickshell.execDetached(["bash", "-c", "nmcli radio wifi | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on"])
                            if (dashboardContent.statusTimer) dashboardContent.statusTimer.restart()
                        }
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46
                    height: wifiTextCol.implicitHeight

                    Column {
                        id: wifiTextCol
                        width: parent.width
                        spacing: 1

                        Text {
                            text: "WI-FI"
                            color: commandDeck.inkCol
                            opacity: 0.45
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            width: parent.width
                            text: dashboardContent ? dashboardContent.currentWifiName : "Wi-Fi"
                            color: wifiTextMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    MouseArea {
                        id: wifiTextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dashboardContent) dashboardContent.activeDetailView = "wifi"
                    }
                }
            }
        }

        // ── BLUETOOTH ──
        Item {
            width: Math.round((parent.width - 28) * 0.38)
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36
                    radius: commandDeck.btPowered ? 18 : 12
                    border.width: 0
                    antialiasing: true
                    color: commandDeck.btPowered
                        ? (btIconMa.containsMouse ? Qt.lighter(commandDeck.sealCol, 1.08) : commandDeck.sealCol)
                        : Qt.rgba(commandDeck.inkCol.r, commandDeck.inkCol.g, commandDeck.inkCol.b, btIconMa.containsMouse ? 0.16 : 0.08)

                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 110; pushDistance: 7 }

                    IconText {
                        anchors.centerIn: parent
                        text: commandDeck.btPowered ? "bluetooth" : "bluetooth_disabled"
                        color: commandDeck.btPowered ? commandDeck.onSealCol : commandDeck.inkCol
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: btIconMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!dashboardContent) return
                            if (dashboardContent.btPowered) {
                                dashboardContent.btPowered = false
                                dashboardContent.currentBtName = "Bluetooth"
                            } else {
                                dashboardContent.btPowered = true
                                dashboardContent.currentBtName = "Searching..."
                            }
                            Quickshell.execDetached(["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"])
                            if (dashboardContent.statusTimer) dashboardContent.statusTimer.restart()
                        }
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46
                    height: btTextCol.implicitHeight

                    Column {
                        id: btTextCol
                        width: parent.width
                        spacing: 1

                        Text {
                            text: "BLUETOOTH"
                            color: commandDeck.inkCol
                            opacity: 0.45
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            width: parent.width
                            text: !dashboardContent ? "Off" : (dashboardContent.currentBtName === "Bluetooth" ? (commandDeck.btPowered ? "On" : "Off") : dashboardContent.currentBtName)
                            color: btTextMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    MouseArea {
                        id: btTextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dashboardContent) dashboardContent.activeDetailView = "bluetooth"
                    }
                }
            }
        }

        // ── POWER ──
        Item {
            width: parent.width - Math.round((parent.width - 28) * 0.38) * 2 - 28
            height: parent.height

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: 1

                Text {
                    anchors.right: parent.right
                    text: commandDeck.battCharging ? "CHARGING" : "POWER"
                    color: commandDeck.inkCol
                    opacity: 0.45
                    font.family: commandDeck.barFontFam
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
                Row {
                    anchors.right: parent.right
                    spacing: 3
                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: commandDeck.battCharging ? "battery_charging_full" : "bolt"
                        color: commandDeck.battCharging ? commandDeck.color03Col : commandDeck.sealCol
                        font.pixelSize: 15
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: commandDeck.battPct + "%"
                        color: battMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol
                        font.family: commandDeck.barFontFam
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }
            }

            MouseArea {
                id: battMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (dashboardContent) dashboardContent.activeDetailView = "battery"
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // ── BAND 2: CARDLESS MODE & APPEARANCE HUD (Focus · Awake · Style) ──
    // ══════════════════════════════════════════════════════════════════
    Row {
        width: parent.width
        height: 44
        spacing: 14

        // ── FOCUS (POMODORO) ──
        Item {
            width: Math.round((parent.width - 28) * 0.38)
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36
                    radius: commandDeck.pomoOn ? 18 : 12
                    border.width: 0
                    antialiasing: true
                    color: commandDeck.pomoOn
                        ? commandDeck.color03Col
                        : Qt.rgba(commandDeck.inkCol.r, commandDeck.inkCol.g, commandDeck.inkCol.b, focusMa.containsMouse ? 0.16 : 0.08)

                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 110; pushDistance: 7 }

                    IconText {
                        anchors.centerIn: parent
                        text: commandDeck.pomoOn ? "timer" : "hourglass_top"
                        color: commandDeck.pomoOn ? "#121212" : (focusMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol)
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: focusMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dashboardContent) dashboardContent.showPomodoroPopup = !dashboardContent.showPomodoroPopup
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46
                    height: focusTextCol.implicitHeight

                    Column {
                        id: focusTextCol
                        width: parent.width
                        spacing: 1

                        Text {
                            text: "FOCUS"
                            color: commandDeck.inkCol
                            opacity: 0.45
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            width: parent.width
                            text: commandDeck.pomoStatusText
                            color: commandDeck.pomoOn ? commandDeck.color03Col : (focusTextMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol)
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    MouseArea {
                        id: focusTextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dashboardContent) dashboardContent.showPomodoroPopup = !dashboardContent.showPomodoroPopup
                    }
                }
            }
        }

        // ── AWAKE (CAFFEINE) ──
        Item {
            width: Math.round((parent.width - 28) * 0.38)
            height: parent.height

            Row {
                anchors.fill: parent
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36
                    radius: commandDeck.caffeineOn ? 18 : 12
                    border.width: 0
                    antialiasing: true
                    color: commandDeck.caffeineOn
                        ? commandDeck.color03Col
                        : Qt.rgba(commandDeck.inkCol.r, commandDeck.inkCol.g, commandDeck.inkCol.b, awakeMa.containsMouse ? 0.16 : 0.08)

                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 110; pushDistance: 7 }

                    IconText {
                        anchors.centerIn: parent
                        text: "local_cafe"
                        color: commandDeck.caffeineOn ? "#121212" : (awakeMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol)
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: awakeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dashboardContent) dashboardContent.toggleCaffeine()
                    }
                }

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 46
                    height: awakeTextCol.implicitHeight

                    Column {
                        id: awakeTextCol
                        width: parent.width
                        spacing: 1

                        Text {
                            text: "CAFFEINE"
                            color: commandDeck.inkCol
                            opacity: 0.45
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                        }
                        Text {
                            width: parent.width
                            text: commandDeck.caffeineOn ? "Awake" : "Idle"
                            color: commandDeck.caffeineOn ? commandDeck.color03Col : (awakeTextMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol)
                            font.family: commandDeck.barFontFam
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 140 } }
                        }
                    }

                    MouseArea {
                        id: awakeTextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (dashboardContent) dashboardContent.toggleCaffeine()
                    }
                }
            }
        }

        // ── APPEARANCE ORBS (Themes + Wallpapers) ──
        Item {
            width: parent.width - Math.round((parent.width - 28) * 0.38) * 2 - 28
            height: parent.height

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 36; height: 36
                    radius: themeMa.pressed ? 10 : (themeMa.containsMouse ? 14 : 18)
                    border.width: 0
                    antialiasing: true
                    color: Qt.rgba(commandDeck.inkCol.r, commandDeck.inkCol.g, commandDeck.inkCol.b, themeMa.containsMouse ? 0.16 : 0.08)
                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 90; pushDistance: 6 }

                    IconText {
                        anchors.centerIn: parent
                        text: "palette"
                        color: themeMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol
                        font.pixelSize: 18
                    }

                    TooltipMixin {
                        id: themeTip
                        root: commandDeck.root
                        owner: parent
                        text: "Themes"
                    }

                    MouseArea {
                        id: themeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: themeTip.show()
                        onExited: themeTip.hide()
                        onClicked: {
                            themeTip.hide()
                            if (dashboardContent) dashboardContent.activeDetailView = "theme"
                        }
                    }
                }

                Rectangle {
                    width: 36; height: 36
                    radius: wallMa.pressed ? 10 : (wallMa.containsMouse ? 14 : 18)
                    border.width: 0
                    antialiasing: true
                    color: Qt.rgba(commandDeck.inkCol.r, commandDeck.inkCol.g, commandDeck.inkCol.b, wallMa.containsMouse ? 0.16 : 0.08)
                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 90; pushDistance: 6 }

                    IconText {
                        anchors.centerIn: parent
                        text: "wallpaper"
                        color: wallMa.containsMouse ? commandDeck.sealCol : commandDeck.inkCol
                        font.pixelSize: 18
                    }

                    TooltipMixin {
                        id: wallTip
                        root: commandDeck.root
                        owner: parent
                        text: "Wallpapers"
                    }

                    MouseArea {
                        id: wallMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: wallTip.show()
                        onExited: wallTip.hide()
                        onClicked: {
                            wallTip.hide()
                            if (dashboardContent) dashboardContent.activeDetailView = "wallpaper"
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: batPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-battery"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    // ── Telemetry state ─────────────────────────────────────────────────
    property int    percent: 0
    property string status:  "unknown"
    property string batteryId: "BAT1"
    property string healthText: "100%"
    property string sizeText: "0 Wh"
    property string designSizeText: "0 Wh"
    property string energyNowText: "0 Wh"
    property string timeText: ""
    property string powerRate: "0"
    property int    cycles:   0
    property string voltageText: "0 V"
    property bool   acOnline: false
    property string techText: "Li-ion"
    property string modelText: ""

    readonly property bool charging: status === "charging"
    readonly property bool fullyCharged: status === "fully-charged" || (percent >= 98 && acOnline)

    function statusTitle(s) {
        var t = String(s || "unknown")
        if (t === "fully-charged") return "Full"
        return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1) : "Unknown"
    }

    // ── Top power processes ─────────────────────────────────────────────
    property var topProcesses: []

    // ── Popup visibility & focus ────────────────────────────────────────
    property real reveal: root.batteryVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.batteryVisible ? 160 : 120
            easing.type: root.batteryVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.batteryVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.batteryVisible = false }

    // ── Main Card ───────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: 350
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: batPanel.root
            ownerActive: batPanel.root.batteryVisible
            targetX: batPanel.root.batteryBarX
            reveal: batPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.batteryBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - batPanel.reveal)
            : (barBottom + gap) - 2 * (1 - batPanel.reveal)
        opacity: batPanel.reveal
        focus: root.batteryVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.batteryVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── TOP BRUTALIST HEADER ────────────────────────────────────
            Item {
                width: parent.width
                height: 22

                // Header title
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "POWER TELEMETRY"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Bold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // AC / Battery Status Tag
                    Rectangle {
                        height: 20
                        width: acRow.implicitWidth + 12
                        radius: 8
                        border.width: 0
                        border.color: batPanel.acOnline ? root.seal : root.sep
                        color: batPanel.acOnline ? root.fillActive : root.fillIdle
                        Row {
                            id: acRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: batPanel.acOnline ? "power" : "battery_std"
                                color: batPanel.acOnline ? root.seal : root.sumi
                                font.pixelSize: 11
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            UiText {
                                id: acTxt
                                text: batPanel.acOnline ? "AC ONLINE" : "ON BATTERY"
                                color: batPanel.acOnline ? root.seal : root.sumi
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 20; height: 20
                        radius: 8
                        border.width: 0
                        border.color: closeMa.containsMouse ? root.seal : root.sep
                        color: closeMa.containsMouse ? root.fillHover : root.fillIdle
                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: closeMa.containsMouse ? root.seal : root.sumi
                            font.pixelSize: 13
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.batteryVisible = false
                        }
                    }
                }
            }

            // Sub-header telemetry line
            Row {
                width: parent.width
                spacing: 6

                Rectangle {
                    height: 18
                    width: batIdTxt.implicitWidth + 8
                    radius: 8
                    border.width: 0
                    border.color: root.sep
                    color: root.fillIdle
                    UiText {
                        id: batIdTxt
                        anchors.centerIn: parent
                        text: batPanel.batteryId + " • " + batPanel.techText.toUpperCase()
                        color: root.sumi
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                Rectangle {
                    height: 18
                    width: hBadgeTxt.implicitWidth + 8
                    radius: 8
                    border.width: 0
                    border.color: root.sep
                    color: root.fillIdle
                    UiText {
                        id: hBadgeTxt
                        anchors.centerIn: parent
                        text: "HEALTH: " + batPanel.healthText
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                Rectangle {
                    height: 18
                    width: voltBadgeTxt.implicitWidth + 8
                    radius: 8
                    border.width: 0
                    border.color: root.sep
                    color: root.fillIdle
                    UiText {
                        id: voltBadgeTxt
                        anchors.centerIn: parent
                        text: batPanel.voltageText
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── MAIN BATTERY GAUGE BLOCK ────────────────────────────────
            Rectangle {
                width: parent.width
                height: 82
                radius: 8
                border.width: 0
                border.color: root.sep
                color: root.fillIdle

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // Primary metrics row: Big percentage + Status info
                    Item {
                        width: parent.width
                        height: 38

                        // Percentage on left
                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            UiText {
                                text: batPanel.percent + "%"
                                color: batPanel.charging ? root.indigo : root.seal
                                font.family: root.barFont
                                font.pixelSize: 34
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            IconText {
                                visible: batPanel.charging
                                text: "bolt"
                                color: root.indigo
                                font.pixelSize: 22
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Status & Time details on right
                        Column {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            UiText {
                                anchors.right: parent.right
                                text: batPanel.charging 
                                    ? ("CHARGING (+" + (batPanel.powerRate !== "" ? batPanel.powerRate : "0") + " W)")
                                    : (batPanel.fullyCharged 
                                        ? "FULLY CHARGED" 
                                        : ("DISCHARGING (-" + (batPanel.powerRate !== "" ? batPanel.powerRate : "0") + " W)"))
                                color: batPanel.charging ? root.indigo : root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            UiText {
                                anchors.right: parent.right
                                text: batPanel.timeText !== "" 
                                    ? (batPanel.timeText.toUpperCase() + (batPanel.charging ? " TO FULL" : " REMAINING"))
                                    : (batPanel.fullyCharged ? "ON AC ADAPTER" : "CALCULATING TIME...")
                                color: root.sumi
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                font.letterSpacing: 0.5
                            }
                        }
                    }

                    // ── Segmented Brutalist Bar (20 crisp blocks) ───────────
                    Item {
                        width: parent.width
                        height: 12

                        Row {
                            anchors.fill: parent
                            spacing: 3

                            Repeater {
                                model: 20
                                delegate: Rectangle {
                                    required property int index
                                    width: (parent.width - (19 * 3)) / 20
                                    height: parent.height
                                    radius: 4
                                    
                                    readonly property bool isFilled: (index + 1) * 5 <= batPanel.percent
                                    readonly property bool isNext: !isFilled && (index * 5 < batPanel.percent)

                                    border.width: 0
                                    border.color: isFilled 
                                        ? (batPanel.charging ? root.indigo : root.seal)
                                        : root.sep
                                    color: isFilled
                                        ? (batPanel.charging ? root.indigo : root.seal)
                                        : (isNext ? root.fillHover : root.fillIdle)
                                }
                            }
                        }
                    }
                }
            }

            // ── INTEGRATED POWER PROFILES (Major Utility!) ──────────────
            Column {
                width: parent.width
                spacing: 6

                Item {
                    width: parent.width
                    height: 16

                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "POWER PROFILE"
                        color: root.sumi
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }

                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CURRENT: " + root.powerProfileCurrent.toUpperCase()
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                Row {
                    width: parent.width
                    spacing: 6

                    // Power Saver Button
                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 26
                        radius: 8
                        readonly property bool isCurrent: root.powerProfileCurrent === "power-saver"
                        border.width: 0
                        border.color: isCurrent ? root.seal : (psMa.containsMouse ? root.seal : root.sep)
                        color: isCurrent ? root.seal : (psMa.containsMouse ? root.fillHover : root.fillIdle)

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            IconText {
                                text: "eco"
                                font.pixelSize: 12
                                color: parent.parent.isCurrent ? root.paper : (psMa.containsMouse ? root.seal : root.sumi)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            UiText {
                                text: "SAVER"
                                color: parent.parent.isCurrent ? root.paper : root.ink
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: psMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["powerprofilesctl", "set", "power-saver"])
                                root.powerProfileCurrent = "power-saver"
                            }
                        }
                    }

                    // Balanced Button
                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 26
                        radius: 8
                        readonly property bool isCurrent: root.powerProfileCurrent === "balanced"
                        border.width: 0
                        border.color: isCurrent ? root.seal : (balMa.containsMouse ? root.seal : root.sep)
                        color: isCurrent ? root.seal : (balMa.containsMouse ? root.fillHover : root.fillIdle)

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            IconText {
                                text: "balance"
                                font.pixelSize: 12
                                color: parent.parent.isCurrent ? root.paper : (balMa.containsMouse ? root.seal : root.sumi)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            UiText {
                                text: "BALANCED"
                                color: parent.parent.isCurrent ? root.paper : root.ink
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: balMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["powerprofilesctl", "set", "balanced"])
                                root.powerProfileCurrent = "balanced"
                            }
                        }
                    }

                    // Performance Button
                    Rectangle {
                        width: (parent.width - 12) / 3
                        height: 26
                        radius: 8
                        readonly property bool isCurrent: root.powerProfileCurrent === "performance"
                        border.width: 0
                        border.color: isCurrent ? root.seal : (perfMa.containsMouse ? root.seal : root.sep)
                        color: isCurrent ? root.seal : (perfMa.containsMouse ? root.fillHover : root.fillIdle)

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            IconText {
                                text: "bolt"
                                font.pixelSize: 12
                                color: parent.parent.isCurrent ? root.paper : (perfMa.containsMouse ? root.seal : root.sumi)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            UiText {
                                text: "PERF"
                                color: parent.parent.isCurrent ? root.paper : root.ink
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: perfMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached(["powerprofilesctl", "set", "performance"])
                                root.powerProfileCurrent = "performance"
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── 4 TELEMETRY TILES (Brutalist Grid) ──────────────────────
            Grid {
                width: parent.width
                columns: 2
                spacing: 6

                component BrutalStat: Rectangle {
                    property string tag: ""
                    property string val: ""
                    property string sub: ""
                    width: (parent.width - 6) / 2
                    height: 44
                    radius: 8
                    border.width: 0
                    border.color: root.sep
                    color: root.fillIdle

                    Column {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        UiText {
                            text: tag
                            color: root.sumi
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }

                        Row {
                            spacing: 4
                            UiText {
                                text: val
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                            }
                            UiText {
                                text: sub
                                color: root.sumi
                                font.family: root.barFont
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                                visible: sub !== ""
                            }
                        }
                    }
                }

                BrutalStat {
                    tag: batPanel.charging ? "CHARGE RATE" : "POWER DRAW"
                    val: (batPanel.powerRate !== "" ? batPanel.powerRate : "0") + " W"
                    sub: batPanel.charging ? "(IN)" : "(OUT)"
                }

                BrutalStat {
                    tag: "HEALTH CAPACITY"
                    val: batPanel.healthText
                    sub: "(" + batPanel.sizeText + ")"
                }

                BrutalStat {
                    tag: "CYCLE COUNT"
                    val: batPanel.cycles > 0 ? String(batPanel.cycles) : "N/A"
                    sub: "CYCLES"
                }

                BrutalStat {
                    tag: "VOLTAGE / DESIGN"
                    val: batPanel.voltageText
                    sub: "/" + batPanel.designSizeText
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── TOP POWER-CONSUMING APPS (Energy Consumers) ─────────────
            Column {
                width: parent.width
                spacing: 4

                Item {
                    width: parent.width
                    height: 16

                    UiText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TOP POWER CONSUMERS"
                        color: root.sumi
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                    }

                    UiText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ACTIVE"
                        color: root.seal
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }

                Repeater {
                    model: batPanel.topProcesses
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 22
                        radius: 8
                        border.width: 0
                        border.color: root.sep
                        color: root.fillIdle

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            UiText {
                                text: modelData.comm
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: parent.width - 120
                            }

                            Item { width: 1 }

                            UiText {
                                text: "PID " + modelData.pid
                                color: root.sumi
                                font.family: root.barFont
                                font.pixelSize: 9
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                height: 16
                                width: cpuTxt.implicitWidth + 8
                                radius: 8
                                color: root.fillActive
                                border.width: 0
                                border.color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                                UiText {
                                    id: cpuTxt
                                    anchors.centerIn: parent
                                    text: modelData.cpu + "%"
                                    color: root.seal
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── ACTION BUTTONS ──────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 6

                // Launch Btop Button
                Rectangle {
                    width: parent.width - 92
                    height: 28
                    radius: 8
                    color: btopMa.containsMouse ? root.fillPrimaryHover : root.seal
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            text: "open_in_new"
                            color: root.paper
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        UiText {
                            text: "OPEN BTOP MONITOR"
                            color: root.paper
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: btopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.batteryVisible = false
                            btopRunner.running = false
                            btopRunner.running = true
                        }
                    }
                }

                // Refresh Button
                Rectangle {
                    width: 86
                    height: 28
                    radius: 8
                    border.width: 0
                    border.color: refMa.containsMouse ? root.seal : root.sep
                    color: refMa.containsMouse ? root.fillHover : root.fillIdle
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: "refresh"
                            color: refMa.containsMouse ? root.seal : root.ink
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        UiText {
                            text: "REFRESH"
                            color: refMa.containsMouse ? root.seal : root.ink
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: refMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            batPanel.refreshBatteryData()
                            procData.running = false
                            procData.running = true
                        }
                    }
                }
            }
        }
    }

    // ── Telemetry Backend Process ───────────────────────────────────────
    function refreshBatteryData() {
        if (!batData.running) batData.running = true
    }

    Process {
        id: batData
        command: ["bash", "-c", 
            "BAT_PATH=$(upower -e 2>/dev/null | grep BAT | head -n1); " +
            "INFO=$(upower -i \"$BAT_PATH\" 2>/dev/null); " +
            "BAT=${BAT_PATH##*/}; BAT=${BAT#battery_}; " +
            "PCT=$(printf '%s\\n' \"$INFO\" | awk '/percentage/ { gsub(\"%\", \"\", $2); print int($2); exit }'); " +
            "STATE=$(printf '%s\\n' \"$INFO\" | awk '/state/ { print $2; exit }'); " +
            "RATE=$(printf '%s\\n' \"$INFO\" | awk '/energy-rate/ { rounded=sprintf(\"%.1f\", $2); sub(/\\.0$/, \"\", rounded); print rounded; exit }'); " +
            "SIZE=$(printf '%s\\n' \"$INFO\" | awk '/energy-full:/ { printf \"%.1f Wh\", $2; exit }'); " +
            "TIME=$(printf '%s\\n' \"$INFO\" | awk '/time to (empty|full)/ { value=$4; unit=$5; if (unit ~ /^minute/) printf \"%dm\", int(value); else { hours=int(value); minutes=int((value-hours)*60); if (minutes>0) printf \"%dh %dm\", hours, minutes; else printf \"%dh\", hours } exit }'); " +
            "SYS=/sys/class/power_supply/$BAT; " +
            "FULL=$(cat \"$SYS/energy_full\" 2>/dev/null || cat \"$SYS/charge_full\" 2>/dev/null || echo 0); " +
            "DESIGN=$(cat \"$SYS/energy_full_design\" 2>/dev/null || cat \"$SYS/charge_full_design\" 2>/dev/null || echo 0); " +
            "ENERGY_NOW=$(cat \"$SYS/energy_now\" 2>/dev/null || cat \"$SYS/charge_now\" 2>/dev/null || echo 0); " +
            "VOLT=$(cat \"$SYS/voltage_now\" 2>/dev/null || echo 0); " +
            "CYC=$(cat \"$SYS/cycle_count\" 2>/dev/null || echo 0); " +
            "HEALTH=$(awk -v f=\"$FULL\" -v d=\"$DESIGN\" 'BEGIN{ if(d>0){ h=f*100/d; if(h>100) h=100; printf \"%d%%\", h } }'); " +
            "AC=$(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -n1 || echo 0); " +
            "TECH=$(cat \"$SYS/technology\" 2>/dev/null || echo 'Li-ion'); " +
            "MODEL=$(cat \"$SYS/model_name\" 2>/dev/null || echo \"$BAT\"); " +
            "DESIGN_WH=$(awk -v d=\"$DESIGN\" 'BEGIN{ printf \"%.1f Wh\", d/1000000 }'); " +
            "NOW_WH=$(awk -v n=\"$ENERGY_NOW\" 'BEGIN{ printf \"%.1f Wh\", n/1000000 }'); " +
            "VOLT_V=$(awk -v v=\"$VOLT\" 'BEGIN{ printf \"%.2f V\", v/1000000 }'); " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$BAT\" \"${PCT:-0}\" \"${STATE:-unknown}\" \"$TIME\" \"${RATE:-0}\" \"${SIZE:-0 Wh}\" \"$HEALTH\" \"${CYC:-0}\" \"$VOLT_V\" \"$AC\" \"$TECH\" \"$MODEL\" \"$DESIGN_WH\" \"$NOW_WH\""
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length >= 14) {
                    batPanel.batteryId = parts[0] || "BAT1"
                    batPanel.percent = parseInt(parts[1]) || 0
                    batPanel.status = parts[2] || "unknown"
                    batPanel.timeText = parts[3] || ""
                    batPanel.powerRate = parts[4] || "0"
                    batPanel.sizeText = parts[5] || "0 Wh"
                    batPanel.healthText = parts[6] || "100%"
                    batPanel.cycles = parseInt(parts[7]) || 0
                    batPanel.voltageText = parts[8] || "0 V"
                    batPanel.acOnline = parts[9] === "1"
                    batPanel.techText = parts[10] || "Li-ion"
                    batPanel.modelText = parts[11] || ""
                    batPanel.designSizeText = parts[12] || "0 Wh"
                    batPanel.energyNowText = parts[13] || "0 Wh"
                }
            }
        }
    }

    // ── Process Monitor Process ─────────────────────────────────────────
    Process {
        id: procData
        command: ["bash", "-c", "ps -eo pid,pcpu,comm --sort=-pcpu | grep -vE 'ps|grep|tail|head|awk|python3|sh|bash' | tail -n +2 | head -n 3 | awk '{print $1\"|\"$2\"|\"$3}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                var procs = []
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i].trim()
                    if (l === "") continue
                    var p = l.split("|")
                    if (p.length >= 3) {
                        procs.push({
                            pid: p[0],
                            cpu: p[1],
                            comm: p[2]
                        })
                    }
                }
                batPanel.topProcesses = procs
            }
        }
    }

    Timer {
        interval: 4000
        running: root.batteryVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            batPanel.refreshBatteryData()
            procData.running = false
            procData.running = true
        }
    }

    Process { 
        id: btopRunner
        command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"] 
    }
}

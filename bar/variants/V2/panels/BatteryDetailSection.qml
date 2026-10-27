import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: batSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property var batObj: ({
        batteryId: "BAT1",
        percent: 100,
        status: "Full",
        acOnline: true,
        health: 100,
        health_str: "100%",
        cycles: 0,
        powerRate: 0.0,
        powerRate_str: "0.0 W",
        timeRemaining: "Fully Charged",
        profile: "balanced",
        topProcesses: []
    })

    ListModel { id: topProcModel }

    FontLoader {
        id: biggerFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Unknown Vendor/OpenType/Bigger/Bigger_Display.otf"
    }

    readonly property color accentColor: {
        var p = batSection.batObj.percent
        if (p < 20) return "#ea6962"
        if (p < 50) return "#e78a4e"
        return "#a9b665"
    }

    // Live charging sweep animation for the segmented reactor rail
    property real chargeSweep: 0.0
    NumberAnimation on chargeSweep {
        running: batSection.batObj.acOnline
        loops: Animation.Infinite
        from: 0.0
        to: 1.0
        duration: 1800
        easing.type: Easing.Linear
    }

    Process {
        id: batStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/battery_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    batSection.batObj = d

                    topProcModel.clear()
                    let procs = d.topProcesses || []
                    for (let i = 0; i < procs.length; i++) {
                        topProcModel.append(procs[i])
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: batPollTimer
        interval: 3000
        repeat: true
        running: batSection.visible
        triggeredOnStart: true
        onTriggered: {
            if (!batStatusProc.running) batStatusProc.running = true
        }
    }

    onVisibleChanged: {
        if (visible && !batStatusProc.running) batStatusProc.running = true
    }

    function doSetProfile(prof) {
        batSection.batObj.profile = prof
        let p = setProfileProcComp.createObject(batSection, { targetProfile: prof })
        p.running = true
    }

    Component {
        id: setProfileProcComp
        Process {
            property string targetProfile: ""
            command: ["python3", "/home/hery/.config/quickshell/bar/scripts/battery_info.py", "set-profile", targetProfile]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (!batStatusProc.running) batStatusProc.running = true
                }
            }
        }
    }

    // Process kill action
    Process {
        id: killProc
        stdout: StdioCollector {
            onStreamFinished: {
                batPollTimer.restart()
                if (!batStatusProc.running) batStatusProc.running = true
            }
        }
    }

    function doKillProcess(pid) {
        killProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/cpu_info.py", "kill", String(pid)]
        killProc.running = false
        killProc.running = true
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Matches Calendar Widget Design) ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: BATTERY GAUGE & POWER PROFILES WIDGET ──────────────
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
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 36
                z: 5

                // Top Right: Time Remaining Pill + Close Button
                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 6

                    // Time Remaining Pill
                    Rectangle {
                        visible: batSection.batObj.timeRemaining ? true : false
                        height: 24
                        radius: 12
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        width: timeRow.implicitWidth + 16

                        Row {
                            id: timeRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "schedule"
                                font.pixelSize: 11
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: batSection.batObj.timeRemaining || ""
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: closeLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 13
                            color: root.ink
                        }

                        SpringPress {}
                        MouseArea {
                            id: closeLeftMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: batSection.closeRequested()
                        }
                    }
                }
            }

            // Left Column Body Content
            Item {
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 0
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                ConnectedTabCard {
                    root: batSection.root
                    anchors.fill: parent
                    dotColor: batSection.accentColor
                    icon: {
                        if (batSection.batObj.acOnline) return "battery_charging_full"
                        if (batSection.batObj.percent >= 90) return "battery_full"
                        if (batSection.batObj.percent >= 60) return "battery_5_bar"
                        if (batSection.batObj.percent >= 30) return "battery_3_bar"
                        return "battery_1_bar"
                    }
                    text: batSection.batObj.percent + "% · " + (batSection.batObj.acOnline ? (batSection.batObj.percent >= 100 ? "Full" : "Charging") : "Battery")

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 7

                        // ── 1. HERO POWER HUD: BOLD PERCENT DISPLAY & STATUS ──
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: 38

                            // Left: Bold Display Percentage
                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    text: batSection.batObj.percent
                                    font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                                    font.pixelSize: 38
                                    font.weight: Font.Bold
                                    color: root.ink
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -3
                                }

                                Column {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    spacing: 0

                                    Text {
                                        text: "%"
                                        font.family: root.barFont
                                        font.pixelSize: 15
                                        font.weight: Font.Bold
                                        color: batSection.accentColor
                                    }

                                    Text {
                                        text: batSection.batObj.acOnline ? "AC POWER" : "BATTERY"
                                        font.family: root.barFont
                                        font.pixelSize: 8
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.6
                                        color: root.sumi
                                    }
                                }
                            }

                            // Right: High-Tech Status Pill
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 24
                                radius: 12
                                color: batSection.batObj.acOnline 
                                    ? Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.16)
                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                border.width: batSection.batObj.acOnline ? 1 : 0
                                border.color: Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.35)
                                width: statusRow.implicitWidth + 16

                                Row {
                                    id: statusRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    IconText {
                                        text: batSection.batObj.acOnline ? "bolt" : "battery_std"
                                        font.pixelSize: 12
                                        color: batSection.batObj.acOnline ? batSection.accentColor : root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: {
                                            if (batSection.batObj.acOnline) {
                                                return batSection.batObj.percent >= 100 ? "FULLY CHARGED" : "FAST CHARGING"
                                            }
                                            if (batSection.batObj.powerRate_str && batSection.batObj.powerRate_str !== "0.0 W") {
                                                return batSection.batObj.powerRate_str
                                            }
                                            return "DISCHARGING"
                                        }
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.5
                                        color: batSection.batObj.acOnline ? batSection.accentColor : root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // ── 2. FUTURISTIC SEGMENTED REACTOR ENERGY RAIL ──
                        Item {
                            id: railContainer
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: 14

                            Row {
                                id: segmentsRow
                                anchors.left: parent.left
                                anchors.right: terminalCap.left
                                anchors.rightMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Repeater {
                                    model: 10
                                    delegate: Rectangle {
                                        id: segRect
                                        required property int index
                                        readonly property bool isEnergized: batSection.batObj.percent >= (index * 10 + 2)
                                        readonly property bool isCurrentChargingHead: batSection.batObj.acOnline && (batSection.batObj.percent >= index * 10 && batSection.batObj.percent < (index + 1) * 10)
                                        readonly property real pulseDist: Math.abs(batSection.chargeSweep - ((index + 0.5) / 10.0))
                                        readonly property bool isPulseWave: batSection.batObj.acOnline && pulseDist < 0.16

                                        width: Math.floor((segmentsRow.width - (9 * segmentsRow.spacing)) / 10)
                                        height: 12
                                        radius: 3.5

                                        // High-tech glow and color transitions
                                        color: {
                                            if (isEnergized) {
                                                if (isPulseWave) {
                                                    return Qt.lighter(batSection.accentColor, 1.4)
                                                }
                                                return batSection.accentColor
                                            }
                                            if (isCurrentChargingHead) {
                                                return Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.45)
                                            }
                                            return Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                        }

                                        border.width: isCurrentChargingHead ? 1 : 0
                                        border.color: batSection.accentColor
                                        opacity: isEnergized ? (isPulseWave ? 1.0 : 0.88) : 0.45

                                        Behavior on color { ColorAnimation { duration: 180 } }
                                        Behavior on opacity { NumberAnimation { duration: 180 } }

                                        // Specular glass highlight reflection
                                        Rectangle {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 1
                                            height: 1.5
                                            radius: 1
                                            color: "white"
                                            opacity: segRect.isEnergized ? 0.35 : 0.06
                                        }
                                    }
                                }
                            }

                            // Symbolic Battery Anode Terminal Cap
                            Rectangle {
                                id: terminalCap
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3.5
                                height: 6
                                radius: 1.5
                                color: batSection.batObj.percent >= 98 ? batSection.accentColor : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                            }
                        }

                        // Capacity Sub-labels
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            height: 10

                            Text {
                                anchors.left: parent.left
                                text: "0%"
                                font.family: root.barFont
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: root.sumi
                                opacity: 0.6
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (batSection.batObj.energyNow_wh ? (batSection.batObj.energyNow_wh + " Wh / " + batSection.batObj.energyFull_wh + " Wh") : "")
                                font.family: root.barFont
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                color: root.sumi
                                opacity: 0.75
                            }

                            Text {
                                anchors.right: parent.right
                                text: "100%"
                                font.family: root.barFont
                                font.pixelSize: 8
                                font.weight: Font.Bold
                                color: root.sumi
                                opacity: 0.6
                            }
                        }

                        // ── 3. POWER PROFILE SELECTOR ──
                        PillTabs {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 4
                            fill: true
                            theme: root
                            fontSize: 10
                            tabHeight: 26
                            model: [
                                { id: "power-saver", label: "Saver" },
                                { id: "balanced", label: "Balanced" },
                                { id: "performance", label: "Performance" }
                            ]
                            current: batSection.batObj.profile
                            onActivated: (id) => batSection.doSetProfile(id)
                        }

                        // ── 4. TELEMETRY BADGES ROW ──
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            // Battery Health Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                width: healthRow.implicitWidth + 12

                                Row {
                                    id: healthRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "favorite"
                                        font.pixelSize: 10
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Health " + (batSection.batObj.health_str || (batSection.batObj.health + "%"))
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Cycles Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                width: cycleRow.implicitWidth + 12

                                Row {
                                    id: cycleRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "sync"
                                        font.pixelSize: 10
                                        color: root.sumiHi
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: batSection.batObj.cycles + " Cycles"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Voltage / Power Draw Rate Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.14)
                                border.width: 1
                                border.color: Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.25)
                                width: rateRow.implicitWidth + 12

                                Row {
                                    id: rateRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "bolt"
                                        font.pixelSize: 10
                                        color: batSection.accentColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: (batSection.batObj.powerRate_str && batSection.batObj.powerRate_str !== "0.0 W")
                                            ? batSection.batObj.powerRate_str
                                            : (batSection.batObj.voltage_str || "12.8 V")
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: batSection.accentColor
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: TOP POWER CONSUMERS (APP USAGE BREAKDOWN) ──────────
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
                            text: "bolt"
                            font.pixelSize: 13
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Power Consumers (" + topProcModel.count + ")"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Close Button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 12
                    color: closeRightMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 13
                        color: root.ink
                    }

                    SpringPress {}
                    MouseArea {
                        id: closeRightMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: batSection.closeRequested()
                    }
                }
            }

            // Processes List
            ListView {
                id: procListView
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                clip: true
                spacing: 6
                model: topProcModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 38
                    radius: 10
                    color: itemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        // App Icon
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: "bolt"
                                font.pixelSize: 12
                                color: root.ink
                                opacity: 0.7
                            }
                        }

                        // Name & PID
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24 - 8 - 100 - 8 - 28
                            spacing: 1
                            clip: true

                            Text {
                                text: model.name
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.ink
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: "PID " + model.pid + " • CPU Load"
                                font.family: root.barFont
                                font.pixelSize: 9
                                color: root.ink
                                opacity: 0.45
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // CPU Drain Bar & Percentage Badge
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            width: 100

                            // Progress Bar
                            Rectangle {
                                width: 50
                                height: 6
                                radius: 3
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    readonly property real cpuVal: parseFloat(model.cpu) || 0
                                    width: Math.max(4, Math.min(parent.width, Math.round(parent.width * (cpuVal / 50.0))))
                                    height: parent.height
                                    radius: parent.radius
                                    color: parent.cpuVal > 30 ? "#ea6962" : root.seal
                                }
                            }

                            Text {
                                text: model.cpu
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                                width: 36
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Kill Process Button (Shows on hover)
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: killBtnMa.containsMouse ? "#ea6962" : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: itemMa.containsMouse ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 12
                                color: killBtnMa.containsMouse ? "#ffffff" : root.ink
                            }

                            SpringPress {}
                            MouseArea {
                                id: killBtnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: batSection.doKillProcess(model.pid)
                            }
                        }
                    }

                    MouseArea {
                        id: itemMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }
}

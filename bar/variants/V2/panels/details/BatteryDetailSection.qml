import QtQuick
import ".."
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../modules"
import "../../motion"

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
        voltage: 0.0,
        voltage_str: "0.0 V",
        powerRate: 0.0,
        powerRate_str: "0.0 W",
        energyNow_wh: 0,
        energyFull_wh: 0,
        energyDesign_wh: 0,
        timeRemaining: "Fully Charged",
        model: "",
        technology: "Li-ion",
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

    readonly property color cardBg: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.045)
    readonly property color subCardBg: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)

    property real chargeSweep: 0.0
    NumberAnimation on chargeSweep {
        running: batSection.batObj.acOnline && batSection.visible
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
        var updated = Object.assign({}, batSection.batObj, { profile: prof })
        batSection.batObj = updated
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
    // ── BENTO TWO-COLUMN BATTERY & POWER DASHBOARD ───────────────────────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: mainColumns
        anchors.fill: parent
        anchors.margins: 8
        spacing: 14

        // ── LEFT COLUMN: HERO POWER CARD + PROFILES + TELEMETRY GRID ─────────
        Column {
            id: leftColumn
            width: Math.round((mainColumns.width - mainColumns.spacing) * 0.56)
            height: mainColumns.height
            spacing: 12

            // ── 1. HERO BATTERY CARD ──
            Rectangle {
                id: heroCard
                width: parent.width
                height: Math.round((leftColumn.height - 24) * 0.50)
                radius: 22
                color: batSection.cardBg
                border.width: 1
                border.color: Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.16)
                clip: true

                Item {
                    anchors.fill: parent
                    anchors.margins: 18

                    // Top section: Readout on left, Ring Gauge on right
                    Item {
                        id: heroUpper
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: segRailContainer.top
                        anchors.bottomMargin: 12

                        // Left: Eyebrow + Big Percentage + Status
                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Hardware & Source Eyebrow
                            Row {
                                spacing: 6

                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: batSection.accentColor
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (batSection.batObj.batteryId || "BAT1")
                                        + (batSection.batObj.technology ? (" · " + batSection.batObj.technology) : "")
                                        + " · "
                                        + (batSection.batObj.acOnline ? "AC POWER" : "ON BATTERY")
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.6
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                }
                            }

                            // Big Percentage
                            Row {
                                spacing: 4
                                height: 46

                                Text {
                                    text: batSection.batObj.percent
                                    font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                                    font.pixelSize: 46
                                    font.weight: Font.Bold
                                    color: root.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    id: pctSymbol
                                    text: "%"
                                    font.family: root.barFont
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: batSection.accentColor
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 6
                                }
                            }

                            // Status & Time Remaining Pill
                            Rectangle {
                                height: 24
                                radius: 12
                                width: heroStatusRow.implicitWidth + 16
                                color: batSection.batObj.acOnline
                                    ? Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.16)
                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                Row {
                                    id: heroStatusRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: batSection.batObj.acOnline ? "bolt" : "schedule"
                                        font.pixelSize: 12
                                        color: batSection.accentColor
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: {
                                            var s = batSection.batObj.status || "Unknown"
                                            var rem = batSection.batObj.timeRemaining || ""
                                            if (rem && rem !== "Fully Charged") return s + " · " + rem
                                            if (batSection.batObj.acOnline && batSection.batObj.percent >= 98) return "Fully Charged"
                                            return s
                                        }
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: root.ink
                                    }
                                }
                            }
                        }

                        // Right: Circular Arc Gauge
                        Item {
                            id: ringGauge
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(112, parent.height)
                            height: width

                            Canvas {
                                id: ringCanvas
                                anchors.fill: parent
                                readonly property real pct: Math.max(0, Math.min(100, batSection.batObj.percent || 0))
                                readonly property color acc: batSection.accentColor
                                readonly property color trackC: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                                onPctChanged: requestPaint()
                                onAccChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var cx = width / 2
                                    var cy = height / 2
                                    var r = Math.max(10, Math.min(cx, cy) - 7)
                                    var startAngle = -Math.PI / 2
                                    var endAngle = startAngle + Math.PI * 2 * (pct / 100.0)

                                    ctx.lineWidth = 8
                                    ctx.lineCap = "round"

                                    // Background track
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                    ctx.strokeStyle = trackC
                                    ctx.stroke()

                                    // Active progress arc
                                    if (pct > 0) {
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, r, startAngle, endAngle)
                                        ctx.strokeStyle = acc
                                        ctx.stroke()
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                IconText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        if (batSection.batObj.acOnline) return "battery_charging_full"
                                        if (batSection.batObj.percent >= 90) return "battery_full"
                                        if (batSection.batObj.percent >= 60) return "battery_5_bar"
                                        if (batSection.batObj.percent >= 30) return "battery_3_bar"
                                        return "battery_1_bar"
                                    }
                                    font.pixelSize: 22
                                    color: batSection.accentColor
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (batSection.batObj.powerRate_str && batSection.batObj.powerRate_str !== "0.0 W")
                                        ? batSection.batObj.powerRate_str
                                        : (batSection.batObj.voltage_str || "0.0 V")
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                }
                            }
                        }
                    }

                    // Bottom: 10-Segment Charge Rail + Wh Capacity Readout
                    Column {
                        id: segRailContainer
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Row {
                            width: parent.width
                            spacing: 5

                            Repeater {
                                model: 10
                                Rectangle {
                                    readonly property real segStart: index * 10
                                    readonly property real segFill: Math.max(0, Math.min(1, (batSection.batObj.percent - segStart) / 10.0))
                                    readonly property real sweepDist: Math.abs((index / 9.0) - batSection.chargeSweep)
                                    readonly property real sweepGlow: (batSection.batObj.acOnline && segFill > 0)
                                        ? Math.max(0, 1.0 - sweepDist * 3.5)
                                        : 0.0

                                    width: (parent.width - 9 * 5) / 10
                                    height: 10
                                    radius: 5
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                    clip: true

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * parent.segFill
                                        radius: 5
                                        color: Qt.lighter(batSection.accentColor, 1.0 + parent.sweepGlow * 0.45)
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 14

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "0%"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: (batSection.batObj.energyNow_wh !== undefined && batSection.batObj.energyFull_wh > 0)
                                    ? (batSection.batObj.energyNow_wh + " Wh / " + batSection.batObj.energyFull_wh + " Wh")
                                    : ""
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.65)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "100%"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                            }
                        }
                    }
                }
            }

            // ── 2. POWER PROFILE SELECTOR CARD ──
            Rectangle {
                id: profileCard
                width: parent.width
                height: Math.round((leftColumn.height - 24) * 0.24)
                radius: 20
                color: batSection.cardBg

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "POWER PROFILE"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var p = batSection.batObj.profile || "balanced"
                                if (p === "power-saver") return "Extended battery life"
                                if (p === "performance") return "Maximum performance"
                                return "Adaptive power & speed"
                            }
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.seal
                        }
                    }

                    Row {
                        width: parent.width
                        height: parent.height - 26
                        spacing: 8

                        Repeater {
                            model: [
                                { id: "power-saver", label: "Saver",       icon: "eco" },
                                { id: "balanced",    label: "Balanced",    icon: "balance" },
                                { id: "performance", label: "Performance", icon: "speed" }
                            ]

                            Rectangle {
                                readonly property bool isActive: (batSection.batObj.profile || "balanced") === modelData.id
                                width: (parent.width - 16) / 3
                                height: parent.height
                                radius: 14
                                color: isActive
                                    ? root.seal
                                    : (profMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06))
                                scale: profMa.pressed ? 0.96 : 1.0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon
                                        font.pixelSize: 15
                                        color: parent.parent.isActive ? root.paper : root.ink
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.label
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: parent.parent.isActive ? root.paper : root.ink
                                    }
                                }

                                MouseArea {
                                    id: profMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: batSection.doSetProfile(modelData.id)
                                }
                            }
                        }
                    }
                }
            }

            // ── 3. TELEMETRY BENTO GRID (4 METRIC TILES) ──
            Row {
                id: telemetryRow
                width: parent.width
                height: leftColumn.height - heroCard.height - profileCard.height - 24
                spacing: 10

                Repeater {
                    model: [
                        {
                            icon: "favorite",
                            title: "Health",
                            value: batSection.batObj.health_str || "100%",
                            sub: (batSection.batObj.energyFull_wh > 0 && batSection.batObj.energyDesign_wh > 0)
                                ? (batSection.batObj.energyFull_wh + " / " + batSection.batObj.energyDesign_wh + " Wh")
                                : "Battery Health",
                            tint: batSection.batObj.health < 75 ? "#e78a4e" : batSection.accentColor
                        },
                        {
                            icon: "autorenew",
                            title: "Cycles",
                            value: String(batSection.batObj.cycles || 0),
                            sub: "Charge Cycles",
                            tint: root.seal
                        },
                        {
                            icon: "bolt",
                            title: "Power Draw",
                            value: (batSection.batObj.powerRate_str && batSection.batObj.powerRate_str !== "0.0 W")
                                ? batSection.batObj.powerRate_str
                                : "Idle",
                            sub: batSection.batObj.acOnline ? "AC Input" : "Discharging",
                            tint: batSection.accentColor
                        },
                        {
                            icon: "electric_meter",
                            title: "Voltage",
                            value: batSection.batObj.voltage_str || "0.0 V",
                            sub: "Cell Voltage",
                            tint: root.ink
                        }
                    ]

                    Rectangle {
                        width: (telemetryRow.width - 30) / 4
                        height: telemetryRow.height
                        radius: 18
                        color: batSection.cardBg

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            Row {
                                spacing: 5

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.pixelSize: 13
                                    color: modelData.tint
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                                }
                            }

                            Item { width: 1; height: 2 }

                            Text {
                                width: parent.width
                                text: modelData.value
                                font.family: root.barFont
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: root.ink
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: modelData.sub
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // ── RIGHT COLUMN: POWER CONSUMERS LIST CARD ──────────────────────────
        Rectangle {
            id: rightColumnCard
            width: mainColumns.width - leftColumn.width - mainColumns.spacing
            height: mainColumns.height
            radius: 22
            color: batSection.cardBg
            clip: true

            // Header
            Item {
                id: rightHeader
                anchors.top: parent.top
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                height: 30

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: Qt.rgba(batSection.accentColor.r, batSection.accentColor.g, batSection.accentColor.b, 0.16)
                        anchors.verticalCenter: parent.verticalCenter

                        IconText {
                            anchors.centerIn: parent
                            text: "bolt"
                            font.pixelSize: 14
                            color: batSection.accentColor
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Power Consumers"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: root.ink
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        width: countTxt.implicitWidth + 12
                        radius: 10
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: String(topProcModel.count)
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.ink
                        }
                    }
                }

                // Close Button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26; radius: 13
                    color: closeRightMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 14
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

            // Empty State
            Text {
                anchors.centerIn: parent
                visible: topProcModel.count === 0
                text: "No active power consumers"
                font.family: root.barFont
                font.pixelSize: 12
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
            }

            // Process List
            ListView {
                id: procListView
                anchors.top: rightHeader.bottom
                anchors.topMargin: 12
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                clip: true
                spacing: 8
                model: topProcModel

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 48
                    radius: 14
                    color: itemMa.containsMouse ? root.fillHover : batSection.subCardBg
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        // App Icon
                        Rectangle {
                            width: 28; height: 28; radius: 14
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: "memory"
                                font.pixelSize: 14
                                color: root.ink
                                opacity: 0.75
                            }
                        }

                        // Name & PID
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 28 - 10 - 110 - 10 - 26 - 10
                            spacing: 2
                            clip: true

                            Text {
                                text: model.name
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: root.ink
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: "PID " + model.pid + " · CPU Load"
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.48)
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // CPU Drain Bar & Percentage
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            width: 110

                            Rectangle {
                                width: 62
                                height: 6
                                radius: 3
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    readonly property real cpuVal: parseFloat(model.cpu) || 0
                                    width: Math.max(4, Math.min(parent.width, Math.round(parent.width * (cpuVal / 50.0))))
                                    height: parent.height
                                    radius: parent.radius
                                    color: cpuVal > 30 ? "#ea6962" : root.seal
                                }
                            }

                            Text {
                                text: model.cpu
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Kill Process Button (Shows on hover)
                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: killBtnMa.containsMouse ? "#ea6962" : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: itemMa.containsMouse ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 13
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

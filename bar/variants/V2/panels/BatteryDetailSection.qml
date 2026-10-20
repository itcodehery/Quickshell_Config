import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"

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
                            color: batSection.batObj.percent < 20 ? "#ea6962" : (batSection.batObj.percent < 50 ? "#e78a4e" : "#a9b665")
                        }

                        IconText {
                            text: {
                                if (batSection.batObj.acOnline) return "battery_charging_full"
                                if (batSection.batObj.percent >= 90) return "battery_full"
                                if (batSection.batObj.percent >= 60) return "battery_5_bar"
                                if (batSection.batObj.percent >= 30) return "battery_3_bar"
                                return "battery_1_bar"
                            }
                            font.pixelSize: 14
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: batSection.batObj.percent + "% · " + (batSection.batObj.acOnline ? (batSection.batObj.percent >= 100 ? "Full" : "Charging") : "Battery")
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Top Right: Time Remaining Pill + Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Time Remaining Pill
                    Rectangle {
                        visible: batSection.batObj.timeRemaining ? true : false
                        height: 26
                        radius: 13
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
                                font.weight: Font.Bold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Close Button
                    Rectangle {
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
                            onClicked: batSection.closeRequested()
                        }
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
                        width: parent.width - 24
                        spacing: 8

                        // 1. Gauge Circle with Battery Percentage
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

                            // Dynamic Accent Glow Ring
                            Rectangle {
                                anchors.fill: parent
                                radius: 34
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                                border.width: 3
                                border.color: batSection.batObj.percent < 20 ? "#ea6962" : (batSection.batObj.percent < 50 ? "#e78a4e" : "#a9b665")
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: batSection.batObj.percent + "%"
                                    font.family: root.barFont
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: root.ink
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: batSection.batObj.acOnline ? "AC POWER" : "BATTERY"
                                    font.family: root.barFont
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: root.ink
                                    opacity: 0.45
                                }
                            }
                        }

                        // 2. Power Profile Segmented Selector
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 8
                            height: 28
                            radius: 14
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 2
                                spacing: 2

                                // Power Saver Option
                                Rectangle {
                                    readonly property bool active: batSection.batObj.profile === "power-saver"
                                    width: Math.floor((parent.width - 4) / 3)
                                    height: parent.height
                                    radius: 12
                                    color: active ? root.seal : (saverMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Saver"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: parent.active ? Font.Bold : Font.Normal
                                        color: parent.active ? root.paper : root.ink
                                        opacity: parent.active ? 1.0 : 0.65
                                    }

                                    MouseArea {
                                        id: saverMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: batSection.doSetProfile("power-saver")
                                    }
                                }

                                // Balanced Option
                                Rectangle {
                                    readonly property bool active: batSection.batObj.profile === "balanced"
                                    width: Math.floor((parent.width - 4) / 3)
                                    height: parent.height
                                    radius: 12
                                    color: active ? root.seal : (balMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Balanced"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: parent.active ? Font.Bold : Font.Normal
                                        color: parent.active ? root.paper : root.ink
                                        opacity: parent.active ? 1.0 : 0.65
                                    }

                                    MouseArea {
                                        id: balMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: batSection.doSetProfile("balanced")
                                    }
                                }

                                // Performance Option
                                Rectangle {
                                    readonly property bool active: batSection.batObj.profile === "performance"
                                    width: (parent.width - 4) - (Math.floor((parent.width - 4) / 3) * 2)
                                    height: parent.height
                                    radius: 12
                                    color: active ? root.seal : (perfMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Performance"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: parent.active ? Font.Bold : Font.Normal
                                        color: parent.active ? root.paper : root.ink
                                        opacity: parent.active ? 1.0 : 0.65
                                    }

                                    MouseArea {
                                        id: perfMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: batSection.doSetProfile("performance")
                                    }
                                }
                            }
                        }

                        // 3. Telemetry Stats Badges
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
                                        font.weight: Font.Bold
                                        color: root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Power Draw Rate or Cycle Count Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                                width: rateRow.implicitWidth + 12

                                Row {
                                    id: rateRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: (batSection.batObj.powerRate_str && batSection.batObj.powerRate_str !== "0.0 W") ? "bolt" : "sync"
                                        font.pixelSize: 10
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: (batSection.batObj.powerRate_str && batSection.batObj.powerRate_str !== "0.0 W") ? batSection.batObj.powerRate_str : (batSection.batObj.cycles + " Cycles")
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
                                font.weight: Font.Bold
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
                                font.weight: Font.Bold
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

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: cpuSection
    anchors.fill: parent

    required property var root
    property var panel: null

    readonly property int cpuPercent: (root && root.systemCpuPercent !== undefined) ? root.systemCpuPercent : 0

    signal closeRequested()

    property var cpuObj: ({
        model: "AMD Ryzen 5 5600H with Radeon Graphics",
        threads: 12,
        cores: 6,
        temp: 0,
        governor: "powersave",
        epp: "balance_performance",
        load: [0.0, 0.0, 0.0],
        freqs: [],
        topProcesses: []
    })

    ListModel { id: topProcModel }

    // Polling process for live CPU telemetry
    Process {
        id: cpuStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/cpu_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    cpuSection.cpuObj = d

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
        interval: 2000
        repeat: true
        running: cpuSection.visible
        onTriggered: {
            cpuStatusProc.running = false
            cpuStatusProc.running = true
        }
    }

    // Process kill process
    Process {
        id: killProc
        stdout: StdioCollector {
            onStreamFinished: {
                cpuStatusProc.running = false
                cpuStatusProc.running = true
            }
        }
    }

    function doKillProcess(pid) {
        killProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/cpu_info.py", "kill", String(pid)]
        killProc.running = false
        killProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            cpuStatusProc.running = false
            cpuStatusProc.running = true
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Matches Calendar Widget Design) ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: CPU GAUGE & TELEMETRY WIDGET ────────────────────────
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

                // Top Right: Temperature Badge + Close Button
                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 6

                    // Temp Pill
                    Rectangle {
                        visible: cpuSection.cpuObj.temp > 0
                        height: 24
                        radius: 12
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        width: tempRow.implicitWidth + 16

                        Row {
                            id: tempRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "thermostat"
                                font.pixelSize: 12
                                color: cpuSection.cpuObj.temp > 75 ? "#ea6962" : root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: cpuSection.cpuObj.temp + "°C"
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
                            onClicked: cpuSection.closeRequested()
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
                    root: cpuSection.root
                    anchors.fill: parent
                    dotColor: cpuSection.cpuPercent > 80 ? "#ea6962" : (cpuSection.cpuPercent > 40 ? "#e78a4e" : "#a9b665")
                    icon: "memory"
                    text: "CPU " + cpuSection.cpuPercent + "%"

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8

                        // 1. Gauge Circle with Utilization
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
                                border.color: cpuSection.cpuPercent > 80 ? "#ea6962" : (cpuSection.cpuPercent > 40 ? "#e78a4e" : root.seal)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: cpuSection.cpuPercent + "%"
                                    font.family: root.barFont
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: root.ink
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "LOAD"
                                    font.family: root.barFont
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: root.ink
                                    opacity: 0.45
                                }
                            }
                        }

                        // 2. CPU Model Info
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cpuSection.cpuObj.model ? cpuSection.cpuObj.model.replace(/with Radeon Graphics.*/i, "").trim() : "AMD Ryzen Processor"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: root.ink
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (cpuSection.cpuObj.cores > 0 ? (cpuSection.cpuObj.cores + " Cores • " + cpuSection.cpuObj.threads + " Threads") : "Multi-core processor")
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.ink
                                opacity: 0.5
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // 3. Telemetry Stats Badges
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            // Load Avg
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                width: loadRow.implicitWidth + 12

                                Row {
                                    id: loadRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "Avg"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        color: root.ink
                                        opacity: 0.45
                                    }
                                    Text {
                                        text: (cpuSection.cpuObj.load && cpuSection.cpuObj.load.length > 0) ? String(cpuSection.cpuObj.load[0]) : "0.0"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.ink
                                    }
                                }
                            }

                            // Governor Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                                width: govRow.implicitWidth + 12

                                Row {
                                    id: govRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "tune"
                                        font.pixelSize: 10
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: cpuSection.cpuObj.governor ? cpuSection.cpuObj.governor : "powersave"
                                        font.family: root.barFont
                                        font.pixelSize: 9
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
        // ── RIGHT COLUMN: TOP PROCESSES (CPU USAGE BREAKDOWN) ────────────────
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
                            text: "list_alt"
                            font.pixelSize: 13
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Top Processes (" + topProcModel.count + ")"
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
                        onClicked: cpuSection.closeRequested()
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

                        // Process App Icon
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: "terminal"
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
                                text: "PID " + model.pid + " • " + model.mem + " RAM"
                                font.family: root.barFont
                                font.pixelSize: 9
                                color: root.ink
                                opacity: 0.45
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // CPU Bar & Percentage Badge
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
                                    width: Math.max(4, Math.min(parent.width, Math.round(parent.width * (cpuVal / 100.0))))
                                    height: parent.height
                                    radius: parent.radius
                                    color: parent.cpuVal > 50 ? "#ea6962" : root.seal
                                }
                            }

                            Text {
                                text: model.cpu
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: (parseFloat(model.cpu) || 0) > 50 ? "#ea6962" : root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // End Process (Kill) Button
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: killMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.25) : "transparent"
                            border.width: killMa.containsMouse ? 1 : 0
                            border.color: "#ea6962"

                            IconText {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 12
                                color: killMa.containsMouse ? "#ea6962" : root.ink
                                opacity: killMa.containsMouse ? 1.0 : 0.4
                            }

                            SpringPress {}
                            MouseArea {
                                id: killMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cpuSection.doKillProcess(model.pid)
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

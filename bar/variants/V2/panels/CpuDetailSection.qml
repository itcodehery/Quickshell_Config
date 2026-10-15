import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: cpuSection
    anchors.fill: parent

    required property var root
    property var panel: null

    readonly property int cpuPercent: (root && root.systemCpuPercent !== undefined) ? root.systemCpuPercent : 0

    signal closeRequested()
    property int currentTab: 0 // 0: Telemetry, 1: Processes

    function nextSubOption() {
        if (currentTab < 1) {
            currentTab++
            return true
        }
        return false
    }

    function prevSubOption() {
        if (currentTab > 0) {
            currentTab--
            return true
        }
        return false
    }

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
    ListModel { id: coresModel }

    // Polling process for live CPU telemetry
    Process {
        id: cpuStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/cpu_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    cpuSection.cpuObj = d

                    // Update processes
                    topProcModel.clear()
                    let procs = d.topProcesses || []
                    for (let i = 0; i < procs.length; i++) {
                        topProcModel.append(procs[i])
                    }

                    // Update cores
                    coresModel.clear()
                    let freqs = d.freqs || []
                    for (let j = 0; j < freqs.length; j++) {
                        coresModel.append({
                            coreId: j,
                            freqMHz: freqs[j],
                            freqGHz: (freqs[j] / 1000).toFixed(2)
                        })
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

    Column {
        anchors.fill: parent
        spacing: 10

        // ================= HEADER BAR =================
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: root.seal
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        text: "memory"
                        color: root.paper
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "CPU & PERFORMANCE"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }

                    Row {
                        spacing: 6
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: cpuSection.cpuPercent > 80 ? "#f87171" : (cpuSection.cpuPercent > 40 ? "#fbbf24" : "#4ade80")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (cpuSection.cpuObj.cores > 0 ? (cpuSection.cpuObj.cores + " Cores / " + cpuSection.cpuObj.threads + " Threads") : "AMD Ryzen")
                                + (cpuSection.cpuObj.temp > 0 ? (" • " + cpuSection.cpuObj.temp + "°C") : "")
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Top action buttons
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Governor / EPP Badge
                Rectangle {
                    width: govTxt.implicitWidth + 24
                    height: 28
                    radius: 14
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: "speed"
                            color: root.seal
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: govTxt
                            text: (cpuSection.cpuObj.governor || "powersave").toUpperCase()
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        // ================= SEGMENTED TAB SWITCHER =================
        Row {
            width: parent.width
            height: 32
            spacing: 8

            Rectangle {
                width: (parent.width - 8) / 2
                height: 32
                radius: 16
                color: cpuSection.currentTab === 0 ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "speed"
                        color: cpuSection.currentTab === 0 ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Performance & Cores"
                        color: cpuSection.currentTab === 0 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cpuSection.currentTab = 0
                }
            }

            Rectangle {
                width: (parent.width - 8) / 2
                height: 32
                radius: 16
                color: cpuSection.currentTab === 1 ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "list_alt"
                        color: cpuSection.currentTab === 1 ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Top Processes"
                        color: cpuSection.currentTab === 1 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cpuSection.currentTab = 1
                }
            }
        }

        // ================= FULL-WIDTH SINGLE COLUMN CARD CONTENT =================
        Item {
            width: parent.width
            height: parent.height - 36 - 32 - 20
            clip: true

            // ---------------- CARD 1: TELEMETRY & HARDWARE (Full Width) ----------------
            Rectangle {
                id: card1
                anchors.fill: parent
                visible: cpuSection.currentTab === 0
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // SUBHEADER: Overall Load & Utilization
                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TOTAL CPU UTILIZATION"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: cpuSection.cpuPercent + "%"
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    // CPU Usage Bar
                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: parent.width * Math.min(1.0, cpuSection.cpuPercent / 100)
                            height: parent.height
                            radius: 3
                            color: cpuSection.cpuPercent > 80 ? "#f87171" : root.seal
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }

                    // Key-Value Rows
                    Column {
                        width: parent.width
                        spacing: 5

                        Row {
                            width: parent.width
                            Text { text: "Processor"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 11; width: 85 }
                            Text { text: cpuSection.cpuObj.model || "AMD Ryzen"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 85 }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Load Avg"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 11; width: 85 }
                            Text { 
                                text: (cpuSection.cpuObj.load && cpuSection.cpuObj.load.length >= 3)
                                    ? (cpuSection.cpuObj.load[0] + " · " + cpuSection.cpuObj.load[1] + " · " + cpuSection.cpuObj.load[2])
                                    : "—"
                                color: root.ink; font.family: root.barFont; font.pixelSize: 11
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Temperature"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 11; width: 85 }
                            Text { 
                                text: cpuSection.cpuObj.temp > 0 ? (cpuSection.cpuObj.temp + " °C") : "—"
                                color: cpuSection.cpuObj.temp > 85 ? "#f87171" : (cpuSection.cpuObj.temp > 70 ? "#fbbf24" : "#4ade80")
                                font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                            }
                        }

                        Row {
                            width: parent.width
                            Text { text: "Scaling Profile"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 11; width: 85 }
                            Text { 
                                text: (cpuSection.cpuObj.governor || "powersave") + (cpuSection.cpuObj.epp ? (" / " + cpuSection.cpuObj.epp) : "")
                                color: root.seal; font.family: root.barFont; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 85
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // SUBHEADER: Per-Core Clocks
                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "LOGICAL CORES (" + coresModel.count + " THREADS)"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                    }

                    // Per-Core Grid / ListView
                    Flickable {
                        width: parent.width
                        height: parent.height - 180
                        contentHeight: coreGrid.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Grid {
                            id: coreGrid
                            width: parent.width
                            columns: 2
                            spacing: 6

                            Repeater {
                                model: coresModel
                                delegate: Rectangle {
                                    width: (coreGrid.width - 6) / 2
                                    height: 32
                                    radius: 8
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.05)

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        Text {
                                            text: "C" + model.coreId
                                            color: root.seal
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            width: 20
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            width: parent.width - 28 - 44
                                            height: 4
                                            radius: 2
                                            color: Qt.rgba(1, 1, 1, 0.1)
                                            anchors.verticalCenter: parent.verticalCenter

                                            Rectangle {
                                                width: parent.width * Math.min(1.0, (model.freqMHz || 1000) / 4500)
                                                height: parent.height
                                                radius: 2
                                                color: root.seal
                                            }
                                        }

                                        Text {
                                            text: model.freqGHz + "G"
                                            color: root.ink
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- CARD 2: REAL-TIME PROCESS MONITOR (Full Width) ----------------
            Rectangle {
                id: card2
                anchors.fill: parent
                visible: cpuSection.currentTab === 1
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Header row
                    Item {
                        width: parent.width
                        height: 24

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TOP CPU PROCESSES"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: topProcModel.count + " active"
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }

                    // Column headers
                    Row {
                        width: parent.width
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        Text { text: "PROCESS"; color: root.ink; opacity: 0.4; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; width: parent.width - 170 }
                        Text { text: "CPU"; color: root.ink; opacity: 0.4; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; width: 50; horizontalAlignment: Text.AlignRight }
                        Text { text: "RAM"; color: root.ink; opacity: 0.4; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; width: 45; horizontalAlignment: Text.AlignRight }
                        Text { text: "ACTION"; color: root.ink; opacity: 0.4; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; width: 65; horizontalAlignment: Text.AlignRight }
                    }

                    // Processes ListView
                    ListView {
                        id: topProcList
                        width: parent.width
                        height: parent.height - 56
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: topProcModel

                        delegate: Rectangle {
                            width: topProcList.width
                            height: 38
                            radius: 10
                            color: procMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: procMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                // Name & PID
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 170
                                    spacing: 1

                                    Text {
                                        text: model.name
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: "PID: " + model.pid
                                        color: root.ink
                                        opacity: 0.4
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                    }
                                }

                                // CPU %
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.cpu
                                    color: (parseFloat(model.cpu) > 50) ? "#f87171" : ((parseFloat(model.cpu) > 15) ? root.seal : root.ink)
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    width: 50
                                    horizontalAlignment: Text.AlignRight
                                }

                                // RAM %
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.mem
                                    color: root.ink
                                    opacity: 0.6
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    width: 45
                                    horizontalAlignment: Text.AlignRight
                                }

                                // Stop Action Button
                                Rectangle {
                                    width: 52
                                    height: 22
                                    radius: 11
                                    color: killMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                                    border.width: 1
                                    border.color: killMa.containsMouse ? "#ef4444" : Qt.rgba(1, 1, 1, 0.08)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Stop"
                                        color: killMa.containsMouse ? "#fca5a5" : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }

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
                                id: procMa
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                            }
                        }
                    }
                }
            }
        }
    }
}

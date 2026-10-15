import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: memSection
    anchors.fill: parent

    required property var root
    property var panel: null

    readonly property int memPercent: (memObj && memObj.percent !== undefined) ? memObj.percent : ((root && root.systemMemPercent !== undefined) ? root.systemMemPercent : 0)

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

    property var memObj: ({
        percent: 0,
        used_gib: 0.0,
        total_gib: 16.0,
        free_gib: 0.0,
        avail_gib: 0.0,
        cached_gib: 0.0,
        buffers_gib: 0.0,
        active_bytes: 0,
        inactive_bytes: 0,
        shmem_bytes: 0,
        swap_percent: 0,
        swap_total_gib: 0.0,
        swap_used_gib: 0.0,
        swap_free_gib: 0.0,
        topProcesses: []
    })

    ListModel { id: topProcModel }

    // Live polling for memory info
    Process {
        id: memStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/memory_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    memSection.memObj = d

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
        id: memPollTimer
        interval: 2500
        repeat: true
        running: memSection.visible
        triggeredOnStart: true
        onTriggered: {
            if (!memStatusProc.running) {
                memStatusProc.running = true
            }
        }
    }

    onVisibleChanged: {
        if (visible && !memStatusProc.running) {
            memStatusProc.running = true
        }
    }

    function doKillProcess(pid) {
        let p = killProcComp.createObject(memSection, { targetPid: pid })
        p.running = true
    }

    Component {
        id: killProcComp
        Process {
            property string targetPid: ""
            command: ["python3", "/home/hery/.config/quickshell/bar/scripts/memory_info.py", "kill", targetPid]
            stdout: StdioCollector {
                onStreamFinished: {
                    memPollTimer.restart()
                    if (!memStatusProc.running) memStatusProc.running = true
                }
            }
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
                        text: "dns"
                        color: root.paper
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "MEMORY & PERFORMANCE"
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
                            color: memSection.memPercent > 85 ? "#f87171" : (memSection.memPercent > 60 ? "#fbbf24" : "#4ade80")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (memSection.memObj.used_gib > 0 ? (memSection.memObj.used_gib + " GB in use of " + memSection.memObj.total_gib + " GB RAM") : "RAM & Swap Monitor")
                                + (memSection.memObj.swap_total_gib > 0 ? (" • " + memSection.memObj.swap_used_gib + " / " + memSection.memObj.swap_total_gib + " GB Swap") : "")
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Top action button
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Refresh Button Pill
                Rectangle {
                    width: 84
                    height: 28
                    radius: 14
                    color: memRefMa.containsMouse ? root.fillHover : root.fillIdle
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        IconText {
                            text: "refresh"
                            color: root.ink
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Refresh"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: memRefMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!memStatusProc.running) memStatusProc.running = true
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
                color: memSection.currentTab === 0 ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "dns"
                        color: memSection.currentTab === 0 ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "RAM & Swap Telemetry"
                        color: memSection.currentTab === 0 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: memSection.currentTab = 0
                }
            }

            Rectangle {
                width: (parent.width - 8) / 2
                height: 32
                radius: 16
                color: memSection.currentTab === 1 ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "list_alt"
                        color: memSection.currentTab === 1 ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Top Consumers"
                        color: memSection.currentTab === 1 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: memSection.currentTab = 1
                }
            }
        }

        // ================= FULL-WIDTH SINGLE COLUMN CARD CONTENT =================
        Item {
            width: parent.width
            height: parent.height - 36 - 32 - 20
            clip: true

            // ---------------- CARD 1: RAM & SWAP TELEMETRY (Full Width) ----------------
            Rectangle {
                id: card1
                anchors.fill: parent
                visible: memSection.currentTab === 0
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    // SECTION 1: PHYSICAL RAM HERO
                    Column {
                        width: parent.width
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PHYSICAL RAM"
                                color: root.ink
                                opacity: 0.6
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            // Percentage Badge
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20
                                width: ramPctTxt.implicitWidth + 14
                                radius: 10
                                color: memSection.memPercent > 85 ? Qt.rgba(0.97, 0.44, 0.44, 0.2) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                border.width: 1
                                border.color: memSection.memPercent > 85 ? "#f87171" : root.seal

                                Text {
                                    id: ramPctTxt
                                    anchors.centerIn: parent
                                    text: memSection.memPercent + "%"
                                    color: memSection.memPercent > 85 ? "#f87171" : root.seal
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        // Stacked Memory Breakdown Bar
                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 5
                            color: Qt.rgba(1, 1, 1, 0.08)
                            clip: true

                            Row {
                                anchors.fill: parent

                                // In-Use / Active Fill
                                Rectangle {
                                    height: parent.height
                                    width: {
                                        let tot = memSection.memObj.total_gib || 1
                                        let u = memSection.memObj.used_gib || 0
                                        return parent.width * Math.max(0, Math.min(1.0, u / tot))
                                    }
                                    color: memSection.memPercent > 85 ? "#f87171" : root.seal
                                    radius: 5
                                    Behavior on width { NumberAnimation { duration: 250 } }
                                }

                                // Cached Fill
                                Rectangle {
                                    height: parent.height
                                    width: {
                                        let tot = memSection.memObj.total_gib || 1
                                        let c = memSection.memObj.cached_gib || 0
                                        return parent.width * Math.max(0, Math.min(1.0 - ((memSection.memObj.used_gib || 0) / tot), c / tot))
                                    }
                                    color: Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.85)
                                    radius: 5
                                    Behavior on width { NumberAnimation { duration: 250 } }
                                }
                            }
                        }

                        // 3 Clean, Spaced-Out Metric Cards
                        Row {
                            width: parent.width
                            spacing: 8

                            // In-Use Card
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: 54
                                radius: 12
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        IconText {
                                            text: "layers"
                                            color: root.seal
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "In Use"
                                            color: root.ink
                                            opacity: 0.7
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: memSection.memObj.used_gib + " GB"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Available Card
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: 54
                                radius: 12
                                color: Qt.rgba(0.29, 0.87, 0.5, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(0.29, 0.87, 0.5, 0.22)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        IconText {
                                            text: "check_circle"
                                            color: "#4ade80"
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Available"
                                            color: root.ink
                                            opacity: 0.7
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: memSection.memObj.avail_gib + " GB"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Cached Card
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: 54
                                radius: 12
                                color: Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.12)
                                border.width: 1
                                border.color: Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.22)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        IconText {
                                            text: "cached"
                                            color: root.color02
                                            font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Cached"
                                            color: root.ink
                                            opacity: 0.7
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: memSection.memObj.cached_gib + " GB"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // SECTION 2: SWAP MEMORY
                    Column {
                        width: parent.width
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "SWAP MEMORY"
                                color: root.ink
                                opacity: 0.6
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20
                                width: swapPctTxt.implicitWidth + 14
                                radius: 10
                                color: memSection.memObj.swap_percent > 70 ? Qt.rgba(0.97, 0.44, 0.44, 0.2) : Qt.rgba(root.sumiHi.r, root.sumiHi.g, root.sumiHi.b, 0.16)
                                border.width: 1
                                border.color: memSection.memObj.swap_percent > 70 ? "#f87171" : root.sumiHi

                                Text {
                                    id: swapPctTxt
                                    anchors.centerIn: parent
                                    text: memSection.memObj.swap_percent + "%"
                                    color: memSection.memObj.swap_percent > 70 ? "#f87171" : root.sumiHi
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        // Swap Progress Bar
                        Rectangle {
                            width: parent.width
                            height: 8
                            radius: 4
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                width: parent.width * Math.min(1.0, (memSection.memObj.swap_percent || 0) / 100)
                                height: parent.height
                                radius: 4
                                color: memSection.memObj.swap_percent > 70 ? "#f87171" : root.sumiHi
                                Behavior on width { NumberAnimation { duration: 250 } }
                            }
                        }

                        // Swap Stats Row
                        Row {
                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 34
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.06)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    IconText {
                                        text: "swap_horiz"
                                        color: root.sumiHi
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Used " + memSection.memObj.swap_used_gib + " GB"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - 8) / 2
                                height: 34
                                radius: 8
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.06)

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    IconText {
                                        text: "storage"
                                        color: root.ink
                                        opacity: 0.5
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Free " + memSection.memObj.swap_free_gib + " GB"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // SECTION 3: SYSTEM SUMMARY STATUS
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.05)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            IconText {
                                text: memSection.memPercent > 85 ? "warning" : "info"
                                color: memSection.memPercent > 85 ? "#f87171" : root.seal
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 24
                                elide: Text.ElideRight
                                text: memSection.memPercent > 85
                                    ? "High memory pressure. Heavy background tasks active."
                                    : (memSection.memPercent > 65
                                        ? "Moderate load. Memory headroom is stable."
                                        : "Memory pressure is low. System running smoothly.")
                                color: root.ink
                                opacity: 0.7
                                font.family: root.barFont
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            // ---------------- CARD 2: TOP MEMORY CONSUMERS (Full Width) ----------------
            Rectangle {
                id: card2
                anchors.fill: parent
                visible: memSection.currentTab === 1
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    // Subheader
                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TOP MEMORY CONSUMERS"
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
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // Process List
                    ListView {
                        id: memProcListView
                        width: parent.width
                        height: parent.height - 34
                        clip: true
                        spacing: 6
                        model: topProcModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: memProcListView.width
                            height: 44
                            radius: 12
                            color: memProcMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: memProcMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04)

                            MouseArea {
                                id: memProcMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                // Mini Process Icon
                                Rectangle {
                                    id: procIconRect
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "memory"
                                        color: root.seal
                                        font.pixelSize: 14
                                    }
                                }

                                // Badges & Actions (anchored to right)
                                Row {
                                    id: actionsRow
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    // RSS Memory Badge
                                    Rectangle {
                                        width: 68
                                        height: 22
                                        radius: 6
                                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: model.rss_human || (model.rss_mb + " MB")
                                            color: root.seal
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }
                                    }

                                    // %MEM Badge
                                    Rectangle {
                                        width: 42
                                        height: 22
                                        radius: 6
                                        color: Qt.rgba(1, 1, 1, 0.05)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: model.pmem || "0%"
                                            color: root.ink
                                            opacity: 0.8
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                        }
                                    }

                                    // Kill Button
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: memKillMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                                        border.width: memKillMa.containsMouse ? 1 : 0
                                        border.color: "#ef4444"
                                        anchors.verticalCenter: parent.verticalCenter

                                        IconText {
                                            anchors.centerIn: parent
                                            text: "close"
                                            color: memKillMa.containsMouse ? "#fca5a5" : root.ink
                                            opacity: memKillMa.containsMouse ? 1.0 : 0.4
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            id: memKillMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: memSection.doKillProcess(model.pid)
                                        }
                                    }
                                }

                                // Name & PID
                                Column {
                                    anchors.left: procIconRect.right
                                    anchors.leftMargin: 8
                                    anchors.right: actionsRow.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: model.name || "Unknown"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                    Text {
                                        text: "PID " + model.pid
                                        color: root.ink
                                        opacity: 0.4
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

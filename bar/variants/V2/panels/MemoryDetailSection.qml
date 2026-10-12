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

    // Polling process for live Memory telemetry
    Process {
        id: memStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/memory_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    memSection.memObj = d

                    // Update top processes list
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
        if (visible) {
            if (!memStatusProc.running) memStatusProc.running = true
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

        // ================= HEADER BAR (outside any container) =================
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
                        text: "MEMORY & SWAP"
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
                            text: (memSection.memObj.total_gib > 0 ? (memSection.memObj.total_gib + " GB Total RAM") : "RAM Monitor")
                                + (memSection.memObj.swap_total_gib > 0 ? (" • " + memSection.memObj.swap_total_gib + " GB Swap") : "")
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
                    width: 80
                    height: 28
                    radius: 14
                    color: memRefMa.containsMouse ? root.fillHover : root.fillIdle
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
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

        // ================= DUAL CARD CONTENT (borderless) =================
        Row {
            width: parent.width
            height: parent.height - 46
            spacing: 12

            // ---------------- CARD 1: RAM & SWAP UTILIZATION (46%) ----------------
            Rectangle {
                width: Math.round((parent.width - 12) * 0.46)
                height: parent.height
                radius: 20
                color: root.fillIdle
                border.width: 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                // RAM Gauge Section
                Column {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "RAM UTILIZATION"
                            color: root.ink
                            opacity: 0.7
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: memSection.memPercent + "% (" + memSection.memObj.used_gib + " / " + memSection.memObj.total_gib + " GB)"
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // Stacked Memory Breakdown Bar
                    Rectangle {
                        width: parent.width
                        height: 8
                        radius: 4
                        color: Qt.rgba(1, 1, 1, 0.08)
                        clip: true

                        Row {
                            anchors.fill: parent

                            // Used / Active Fill
                            Rectangle {
                                height: parent.height
                                width: {
                                    let tot = memSection.memObj.total_gib || 1
                                    let u = memSection.memObj.used_gib || 0
                                    return parent.width * Math.max(0, Math.min(1.0, u / tot))
                                }
                                color: memSection.memPercent > 85 ? "#f87171" : root.seal
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
                                color: Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.8)
                                Behavior on width { NumberAnimation { duration: 250 } }
                            }
                        }
                    }

                    // Legend Row - Contained 3-part pill layout with icons
                    Row {
                        width: parent.width
                        spacing: 6

                        // Used
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 28
                            radius: 8
                            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                IconText {
                                    text: "layers"
                                    color: root.seal
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Used " + memSection.memObj.used_gib + "G"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Cached
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 28
                            radius: 8
                            color: Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.12)
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                IconText {
                                    text: "cached"
                                    color: root.color02
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Cache " + memSection.memObj.cached_gib + "G"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Free
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 28
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.05)
                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                IconText {
                                    text: "check_circle"
                                    color: root.ink
                                    opacity: 0.6
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Free " + memSection.memObj.free_gib + "G"
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

                // Swap Gauge Section
                Column {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "SWAP UTILIZATION"
                            color: root.ink
                            opacity: 0.7
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: memSection.memObj.swap_percent + "% (" + memSection.memObj.swap_used_gib + " / " + memSection.memObj.swap_total_gib + " GB)"
                            color: root.sumiHi
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            width: parent.width * Math.min(1.0, (memSection.memObj.swap_percent || 0) / 100)
                            height: parent.height
                            radius: 3
                            color: memSection.memObj.swap_percent > 70 ? "#f87171" : root.sumiHi
                            Behavior on width { NumberAnimation { duration: 250 } }
                        }
                    }
                }

                // Divider
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                // Key-Value Rows with Icons
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "check_circle"; color: root.seal; font.pixelSize: 13; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Available"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 95; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: memSection.memObj.avail_gib + " GB"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 95 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "bolt"; color: root.color02; font.pixelSize: 13; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Active / Inactive"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 95; anchors.verticalCenter: parent.verticalCenter }
                        Text { 
                            text: (memSection.memObj.active_bytes > 0 ? (Math.round(memSection.memObj.active_bytes / (1024*1024*1024)*10)/10 + " GB / ") : "")
                                + (memSection.memObj.inactive_bytes > 0 ? (Math.round(memSection.memObj.inactive_bytes / (1024*1024*1024)*10)/10 + " GB") : "—")
                            color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 95 - 21; anchors.verticalCenter: parent.verticalCenter 
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "inventory_2"; color: root.ink; font.pixelSize: 13; opacity: 0.5; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Buffers"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 95; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: memSection.memObj.buffers_gib + " GB"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 95 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "share"; color: root.ink; font.pixelSize: 13; opacity: 0.5; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Shared (Shmem)"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 95; anchors.verticalCenter: parent.verticalCenter }
                        Text { 
                            text: (memSection.memObj.shmem_bytes > 0 ? Math.round(memSection.memObj.shmem_bytes / (1024*1024)) + " MB" : "0 MB")
                            color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 95 - 21; anchors.verticalCenter: parent.verticalCenter 
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "swap_horiz"; color: root.sumiHi; font.pixelSize: 13; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Swap Free"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 95; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: memSection.memObj.swap_free_gib + " GB"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 95 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // ==========================================
        // RIGHT CARD: Top Memory Processes (54%, borderless)
        // ==========================================
        Rectangle {
            width: Math.round((parent.width - 12) * 0.54)
            height: parent.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // SUBHEADER: Processes
                Item {
                    width: parent.width
                    height: 16
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TOP CONSUMERS"
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

                            // Badges & Actions (strictly anchored to right edge inside card)
                            Row {
                                id: actionsRow
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // RSS Memory Badge
                                Rectangle {
                                    width: 64
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
                                    width: 40
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

                            // Name & PID (fills space between icon and actions)
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


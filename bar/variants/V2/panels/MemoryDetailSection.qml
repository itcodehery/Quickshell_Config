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

    // Process kill action
    Process {
        id: killProc
        stdout: StdioCollector {
            onStreamFinished: {
                memPollTimer.restart()
                if (!memStatusProc.running) memStatusProc.running = true
            }
        }
    }

    function doKillProcess(pid) {
        killProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/memory_info.py", "kill", String(pid)]
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
        // ── LEFT COLUMN: RAM GAUGE & USAGE BREAKDOWN WIDGET ─────────────────
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
                            color: memSection.memPercent > 85 ? "#ea6962" : (memSection.memPercent > 65 ? "#e78a4e" : "#a9b665")
                        }

                        IconText {
                            text: "dns"
                            font.pixelSize: 13
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "RAM " + memSection.memPercent + "%"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Top Right: Swap Badge + Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Swap Pill
                    Rectangle {
                        visible: (memSection.memObj.swap_total_gib || 0) > 0
                        height: 26
                        radius: 13
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        width: swapRow.implicitWidth + 16

                        Row {
                            id: swapRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "swap_horiz"
                                font.pixelSize: 12
                                color: (memSection.memObj.swap_percent || 0) > 50 ? "#ea6962" : root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Swap " + (memSection.memObj.swap_percent !== undefined ? memSection.memObj.swap_percent : 0) + "%"
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
                            onClicked: memSection.closeRequested()
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

                        // 1. Gauge Circle with Memory Utilization
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
                                border.color: memSection.memPercent > 85 ? "#ea6962" : (memSection.memPercent > 65 ? "#e78a4e" : root.seal)
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 1

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: memSection.memPercent + "%"
                                    font.family: root.barFont
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    color: root.ink
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "USED"
                                    font.family: root.barFont
                                    font.pixelSize: 8
                                    font.weight: Font.Bold
                                    color: root.ink
                                    opacity: 0.45
                                }
                            }
                        }

                        // 2. RAM Gigabytes Summary & Progress Bar
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ((memSection.memObj.used_gib || 0).toFixed(1) + " GB used of " + (memSection.memObj.total_gib || 16.0).toFixed(1) + " GB")
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.ink
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // Sleek Layered Progress Bar
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 8
                                height: 6
                                radius: 3
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1)

                                // Cached segment
                                Rectangle {
                                    readonly property real totalG: Math.max(0.1, memSection.memObj.total_gib || 16.0)
                                    readonly property real usedG: memSection.memObj.used_gib || 0.0
                                    readonly property real cachedG: memSection.memObj.cached_gib || 0.0
                                    width: Math.min(parent.width, Math.round(parent.width * ((usedG + cachedG) / totalG)))
                                    height: parent.height
                                    radius: parent.radius
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                                }

                                // Active Used segment
                                Rectangle {
                                    readonly property real totalG: Math.max(0.1, memSection.memObj.total_gib || 16.0)
                                    readonly property real usedG: memSection.memObj.used_gib || 0.0
                                    width: Math.min(parent.width, Math.round(parent.width * (usedG / totalG)))
                                    height: parent.height
                                    radius: parent.radius
                                    color: memSection.memPercent > 85 ? "#ea6962" : (memSection.memPercent > 65 ? "#e78a4e" : root.seal)
                                }
                            }
                        }

                        // 3. Telemetry Stats Badges
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            // Available / Free Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                width: freeRow.implicitWidth + 12

                                Row {
                                    id: freeRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "Free"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        color: root.ink
                                        opacity: 0.45
                                    }
                                    Text {
                                        text: ((memSection.memObj.avail_gib || memSection.memObj.free_gib || 0).toFixed(1) + " GB")
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.ink
                                    }
                                }
                            }

                            // Cached Badge
                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                                width: cacheRow.implicitWidth + 12

                                Row {
                                    id: cacheRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: "Cache"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        color: root.seal
                                        opacity: 0.7
                                    }
                                    Text {
                                        text: ((memSection.memObj.cached_gib || 0).toFixed(1) + " GB")
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.seal
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: TOP MEMORY CONSUMERS (PROCESS BREAKDOWN) ───────────
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
                            text: "Top Consumers (" + topProcModel.count + ")"
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
                        onClicked: memSection.closeRequested()
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

                        // Memory App Icon
                        Rectangle {
                            width: 24; height: 24; radius: 12
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: "memory"
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
                                text: "PID " + model.pid + (model.rss_human ? (" • " + model.rss_human) : "")
                                font.family: root.barFont
                                font.pixelSize: 9
                                color: root.ink
                                opacity: 0.45
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Memory Bar & Percentage Badge
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
                                    readonly property real pmemVal: model.pmem_val !== undefined ? model.pmem_val : (parseFloat(model.pmem) || 0)
                                    // Scale to max ~20% of system memory
                                    width: Math.max(4, Math.min(parent.width, Math.round(parent.width * (pmemVal / 20.0))))
                                    height: parent.height
                                    radius: parent.radius
                                    color: parent.pmemVal > 15 ? "#ea6962" : root.seal
                                }
                            }

                            Text {
                                text: model.pmem
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
                                onClicked: memSection.doKillProcess(model.pid)
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

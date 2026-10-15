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
    property int currentTab: 0 // 0: Power & Health, 1: App Usage


    property var batObj: ({
        batteryId: "BAT1",
        percent: 100,
        status: "Full",
        acOnline: true,
        health: 100,
        health_str: "100%",
        cycles: 0,
        voltage: 0.0,
        voltage_str: "0 V",
        powerRate: 0.0,
        powerRate_str: "0 W",
        energyNow_wh: 0.0,
        energyFull_wh: 0.0,
        energyDesign_wh: 0.0,
        timeRemaining: "Fully Charged",
        model: "Battery",
        technology: "Li-ion",
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

    readonly property var profileList: ["power-saver", "balanced", "performance"]

    function nextSubOption() {
        if (currentTab === 0) {
            let cur = batObj.profile || "balanced"
            let idx = profileList.indexOf(cur)
            if (idx < profileList.length - 1 && idx >= 0) {
                doSetProfile(profileList[idx + 1])
                return true
            }
            currentTab = 1
            return true
        }
        return false
    }

    function prevSubOption() {
        if (currentTab === 1) {
            currentTab = 0
            return true
        } else if (currentTab === 0) {
            let cur = batObj.profile || "balanced"
            let idx = profileList.indexOf(cur)
            if (idx > 0) {
                doSetProfile(profileList[idx - 1])
                return true
            }
        }
        return false
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
                        text: batSection.batObj.acOnline ? "power" : (batSection.batObj.percent > 20 ? "battery_full" : "battery_alert")
                        color: root.paper
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "POWER & BATTERY"
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
                            color: batSection.batObj.acOnline ? "#4ade80" : (batSection.batObj.percent > 25 ? "#38bdf8" : "#f87171")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (batSection.batObj.status || "On Battery")
                                + (batSection.batObj.timeRemaining ? (" • " + batSection.batObj.timeRemaining) : "")
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

                // Status / Level Pill
                Rectangle {
                    width: 84
                    height: 28
                    radius: 14
                    color: batSection.batObj.acOnline ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : root.fillIdle
                    border.width: 1
                    border.color: batSection.batObj.acOnline ? root.seal : Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        IconText {
                            text: batSection.batObj.acOnline ? "bolt" : "battery_std"
                            color: batSection.batObj.acOnline ? root.seal : root.ink
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: batSection.batObj.percent + "%"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
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
                color: batSection.currentTab === 0 ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "bolt"
                        color: batSection.currentTab === 0 ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Power & Health"
                        color: batSection.currentTab === 0 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batSection.currentTab = 0
                }
            }

            Rectangle {
                width: (parent.width - 8) / 2
                height: 32
                radius: 16
                color: batSection.currentTab === 1 ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "list_alt"
                        color: batSection.currentTab === 1 ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "App Usage"
                        color: batSection.currentTab === 1 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: batSection.currentTab = 1
                }
            }
        }

        // ================= FULL-WIDTH SINGLE COLUMN CARD CONTENT =================
        Item {
            width: parent.width
            height: parent.height - 36 - 32 - 20
            clip: true

            // ---------------- CARD 1: BATTERY & POWER MANAGEMENT (Full Width) ----------------
            Rectangle {
                id: card1
                anchors.fill: parent
                visible: batSection.currentTab === 0
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    // SECTION 1: CHARGE LEVEL HERO
                    Column {
                        width: parent.width
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "CHARGE LEVEL"
                                color: root.ink
                                opacity: 0.6
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: batSection.batObj.percent + "% (" + (batSection.batObj.acOnline ? "AC Connected" : "Discharging") + ")"
                                color: batSection.batObj.percent <= 20 ? "#f87171" : (batSection.batObj.acOnline ? "#4ade80" : root.seal)
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }

                        // Big Gauge Bar
                        Rectangle {
                            width: parent.width
                            height: 10
                            radius: 5
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1.0, (batSection.batObj.percent || 0) / 100))
                                height: parent.height
                                radius: 5
                                color: batSection.batObj.percent <= 20 ? "#f87171" : (batSection.batObj.acOnline ? "#4ade80" : root.seal)
                                Behavior on width { NumberAnimation { duration: 300 } }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // SECTION 2: POWER PROFILES (SPACIOUS & MODERN)
                    Column {
                        width: parent.width
                        spacing: 8

                        Item {
                            width: parent.width
                            height: 18

                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "POWER PROFILE"
                                color: root.ink
                                opacity: 0.6
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: (batSection.batObj.profile || "balanced").toUpperCase()
                                color: root.seal
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        // 3 Profile Toggles in One Horizontal Line
                        Row {
                            width: parent.width
                            spacing: 6

                            // Performance Card
                            Rectangle {
                                width: Math.floor((parent.width - 12) / 3)
                                height: 38
                                radius: 10
                                property bool selected: batSection.batObj.profile === "performance"
                                color: selected
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                    : (perfMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03))
                                border.width: selected ? 1.5 : 1
                                border.color: selected
                                    ? root.seal
                                    : (perfMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3) : Qt.rgba(1, 1, 1, 0.05))

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "bolt"
                                        color: parent.parent.selected ? root.seal : "#f59e0b"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Performance"
                                        color: parent.parent.selected ? root.seal : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: parent.parent.selected ? Font.Bold : Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: perfMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: batSection.doSetProfile("performance")
                                }
                            }

                            // Balanced Card
                            Rectangle {
                                width: Math.floor((parent.width - 12) / 3)
                                height: 38
                                radius: 10
                                property bool selected: batSection.batObj.profile === "balanced"
                                color: selected
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                    : (balMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03))
                                border.width: selected ? 1.5 : 1
                                border.color: selected
                                    ? root.seal
                                    : (balMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3) : Qt.rgba(1, 1, 1, 0.05))

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "balance"
                                        color: parent.parent.selected ? root.seal : root.ink
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Balanced"
                                        color: parent.parent.selected ? root.seal : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: parent.parent.selected ? Font.Bold : Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: balMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: batSection.doSetProfile("balanced")
                                }
                            }

                            // Power Saver Card
                            Rectangle {
                                width: parent.width - 2 * Math.floor((parent.width - 12) / 3) - 12
                                height: 38
                                radius: 10
                                property bool selected: batSection.batObj.profile === "power-saver"
                                color: selected
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                    : (savMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03))
                                border.width: selected ? 1.5 : 1
                                border.color: selected
                                    ? root.seal
                                    : (savMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3) : Qt.rgba(1, 1, 1, 0.05))

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "eco"
                                        color: parent.parent.selected ? root.seal : "#10b981"
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Power Saver"
                                        color: parent.parent.selected ? root.seal : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: parent.parent.selected ? Font.Bold : Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: savMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: batSection.doSetProfile("power-saver")
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

                    // SECTION 3: HEALTH & VITALS
                    Column {
                        width: parent.width
                        spacing: 8

                        Text {
                            text: "HEALTH & TELEMETRY"
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }

                        Row {
                            width: parent.width
                            spacing: 8

                            // Health Card
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: 48
                                radius: 10
                                color: Qt.rgba(0.96, 0.25, 0.37, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(0.96, 0.25, 0.37, 0.22)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        IconText {
                                            text: "favorite"
                                            color: "#f43f5e"
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Health"
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
                                        text: batSection.batObj.health_str || "100%"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Cycle Count Card
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: 48
                                radius: 10
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        IconText {
                                            text: "autorenew"
                                            color: root.seal
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Cycles"
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
                                        text: batSection.batObj.cycles + " cyc"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            // Power Draw Card
                            Rectangle {
                                width: (parent.width - 16) / 3
                                height: 48
                                radius: 10
                                color: Qt.rgba(0.22, 0.74, 0.97, 0.10)
                                border.width: 1
                                border.color: Qt.rgba(0.22, 0.74, 0.97, 0.22)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 4
                                        IconText {
                                            text: "speed"
                                            color: "#38bdf8"
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Draw"
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
                                        text: batSection.batObj.acOnline ? "AC Power" : batSection.batObj.powerRate_str
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- CARD 2: TOP POWER CONSUMERS (Full Width) ----------------
            Rectangle {
                id: card2
                anchors.fill: parent
                visible: batSection.currentTab === 1
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
                            text: "TOP POWER CONSUMERS"
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
                        id: batProcListView
                        width: parent.width
                        height: parent.height - 34
                        clip: true
                        spacing: 6
                        model: topProcModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: batProcListView.width
                            height: 44
                            radius: 12
                            color: batItemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: batItemMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04)

                            MouseArea {
                                id: batItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "speed"
                                        color: root.seal
                                        font.pixelSize: 14
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 28 - 75 - 20
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
                                    }
                                }

                                // CPU/Power badge
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 65
                                    height: 22
                                    radius: 6
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.cpu || "0%"
                                        color: root.seal
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
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

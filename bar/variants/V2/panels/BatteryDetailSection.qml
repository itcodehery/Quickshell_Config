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
        let cur = batObj.profile || "balanced"
        let idx = profileList.indexOf(cur)
        if (idx < profileList.length - 1 && idx >= 0) {
            doSetProfile(profileList[idx + 1])
            return true
        }
        return false
    }

    function prevSubOption() {
        let cur = batObj.profile || "balanced"
        let idx = profileList.indexOf(cur)
        if (idx > 0) {
            doSetProfile(profileList[idx - 1])
            return true
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
                    width: 80
                    height: 28
                    radius: 14
                    color: batSection.batObj.acOnline ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : root.fillIdle
                    border.width: 1
                    border.color: batSection.batObj.acOnline ? root.seal : Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: batSection.batObj.acOnline ? "power" : "battery_charging_full"
                            color: root.ink
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

        // ================= DUAL CARD CONTENT (borderless) =================
        Row {
            width: parent.width
            height: parent.height - 46
            spacing: 12

            // ---------------- CARD 1: BATTERY & POWER TELEMETRY (46%) ----------------
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

                // Battery Gauge Section
                Column {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "CHARGE LEVEL"
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
                            text: batSection.batObj.percent + "% (" + (batSection.batObj.acOnline ? "AC Power" : "Discharging") + ")"
                            color: root.seal
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

                // Power Profiles Selector
                Column {
                    width: parent.width
                    spacing: 7

                    Text {
                        text: "POWER PROFILE"
                        color: root.ink
                        opacity: 0.7
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        // Performance
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 34
                            radius: 10
                            property bool selected: batSection.batObj.profile === "performance"
                            color: selected ? root.seal : (perfMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04))
                            border.width: 1
                            border.color: selected ? root.seal : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    text: "bolt"
                                    color: parent.parent.selected ? root.paper : root.ink
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "Performance"
                                    color: parent.parent.selected ? root.paper : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
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

                        // Balanced
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 34
                            radius: 10
                            property bool selected: batSection.batObj.profile === "balanced"
                            color: selected ? root.seal : (balMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04))
                            border.width: 1
                            border.color: selected ? root.seal : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    text: "balance"
                                    color: parent.parent.selected ? root.paper : root.ink
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "Balanced"
                                    color: parent.parent.selected ? root.paper : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
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

                        // Power Saver
                        Rectangle {
                            width: (parent.width - 12) / 3
                            height: 34
                            radius: 10
                            property bool selected: batSection.batObj.profile === "power-saver"
                            color: selected ? root.seal : (savMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04))
                            border.width: 1
                            border.color: selected ? root.seal : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    text: "eco"
                                    color: parent.parent.selected ? root.paper : root.ink
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "Power Saver"
                                    color: parent.parent.selected ? root.paper : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
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

                // Key-Value Rows with Icons
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "favorite"; color: "#f43f5e"; font.pixelSize: 13; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Battery Health"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 100; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: batSection.batObj.health_str + " (" + batSection.batObj.energyFull_wh + " / " + batSection.batObj.energyDesign_wh + " Wh)"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 100 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "refresh"; color: root.seal; font.pixelSize: 13; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Cycle Count"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 100; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: batSection.batObj.cycles + " cycles"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 100 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "electric_bolt"; color: "#fbbf24"; font.pixelSize: 13; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Voltage"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 100; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: batSection.batObj.voltage_str; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 100 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "speed"; color: "#38bdf8"; font.pixelSize: 13; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Power Draw"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 100; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: batSection.batObj.powerRate_str; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 100 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        IconText { text: "memory"; color: root.ink; font.pixelSize: 13; opacity: 0.5; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Technology"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 11; width: 100; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: batSection.batObj.technology + " (" + batSection.batObj.batteryId + ")"; color: root.ink; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 100 - 21; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // ==========================================
        // RIGHT CARD: Top Power Drainers (54%, borderless)
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
                        text: "ENERGY CONSUMPTION"
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



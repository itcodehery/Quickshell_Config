import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: wifiSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property var statusObj: ({
        connected: false,
        ssid: "",
        ip: "",
        iface: "",
        signal: 0,
        freq: "",
        linkSpeed: "",
        ping: "",
        wifiBlocked: false
    })

    property bool speedTestActive: false
    property string activeView: "status" // "status" or "networks"
    function nextSubOption() {
        if (activeView === "status") {
            activeView = "networks"
            return true
        }
        return false
    }
    function prevSubOption() {
        if (activeView === "networks") {
            activeView = "status"
            return true
        }
        return false
    }
    property string currentTab: "available" // "available" or "saved"
    property bool scanning: false
    property string selectedSsid: ""
    property string passwordInput: ""
    property string actionError: ""
    property bool connecting: false
    property string lastSpeedStamp: ""

    // Ignition sweep animation properties
    property real sweepSpeed: 0
    property bool isSweeping: false

    // Speed test component
    CloudflareSpeedTest {
        id: speedTest
        online: wifiSection.statusObj.connected
    }

    Connections {
        target: speedTest
        function onPhaseChanged() {
            if (speedTest.phase === "success") {
                wifiSection.lastSpeedStamp = new Date().toLocaleTimeString(Qt.locale("en_US"), "hh:mm AP")
            }
        }
    }

    readonly property real currentLiveSpeed: {
        if (speedTest.phase === "download") return speedTest.downloadMbps
        if (speedTest.phase === "upload") return speedTest.uploadMbps
        if (speedTest.phase === "success") return speedTest.downloadMbps
        return 0
    }

    readonly property real displayedSpeed: isSweeping ? sweepSpeed : currentLiveSpeed

    function formatMbps(v) {
        if (!(v > 0)) return "—"
        return (v >= 100 ? v.toFixed(0) : v.toFixed(1)) + " Mbps"
    }

    function formatPing(v) {
        if (!(v > 0)) return "—"
        return (v < 10 ? v.toFixed(1) : v.toFixed(0)) + " ms"
    }

    function edgeText() {
        if (speedTest.phase === "idle" || speedTest.phase === "cancelled") return "Cloudflare Ready"
        if (speedTest.phase === "offline") return "Offline"
        if (speedTest.phase === "error" || speedTest.phase === "timeout") return "Unavailable"
        if (speedTest.phase === "latency") return "Connecting…"
        var edge = speedTest.edgeCode !== "" ? "Cloudflare · " + speedTest.edgeCode : "Cloudflare Edge"
        return edge
    }

    function speedToProgress(mbps) {
        if (mbps <= 0) return 0.0
        if (mbps >= 500) return 1.0
        if (mbps <= 25) {
            return (mbps / 25) * 0.25
        } else if (mbps <= 100) {
            return 0.25 + ((mbps - 25) / 75) * 0.35
        } else {
            return 0.60 + ((mbps - 100) / 400) * 0.40
        }
    }

    function speedToAngle(mbps) {
        var p = speedToProgress(mbps)
        return -130 + p * 260
    }

    // Tachometer ignition needle sweep
    SequentialAnimation {
        id: ignitionSweepAnim
        PropertyAction { target: wifiSection; property: "isSweeping"; value: true }
        NumberAnimation {
            target: wifiSection
            property: "sweepSpeed"
            from: 0; to: 500
            duration: 450
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: wifiSection
            property: "sweepSpeed"
            from: 500; to: 0
            duration: 350
            easing.type: Easing.InOutQuad
        }
        PropertyAction { target: wifiSection; property: "isSweeping"; value: false }
        ScriptAction {
            script: {
                speedTest.start()
            }
        }
    }

    function startSpeedTestWithSweep() {
        wifiSection.speedTestActive = true
        if (speedTest.running) {
            speedTest.cancel()
        } else {
            ignitionSweepAnim.start()
        }
    }

    function exitSpeedTest() {
        if (speedTest.running) speedTest.cancel()
        wifiSection.speedTestActive = false
    }

    ListModel { id: availableModel }
    ListModel { id: savedModel }

    // Quick status updater (every 3 seconds)
    Process {
        id: statusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    wifiSection.statusObj = d
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: wifiSection.visible
        onTriggered: {
            statusProc.running = false
            statusProc.running = true
        }
    }

    // Full scan updater
    Process {
        id: scanProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "scan"]
        stdout: StdioCollector {
            onStreamFinished: {
                wifiSection.scanning = false
                try {
                    let res = JSON.parse(this.text.trim())
                    if (res.status) {
                        wifiSection.statusObj = res.status
                    }
                    if (res.available) {
                        availableModel.clear()
                        for (let i = 0; i < res.available.length; i++) {
                            availableModel.append(res.available[i])
                        }
                    }
                    if (res.saved) {
                        savedModel.clear()
                        for (let j = 0; j < res.saved.length; j++) {
                            savedModel.append(res.saved[j])
                        }
                    }
                } catch(e) {}
            }
        }
    }

    function refreshScan() {
        wifiSection.scanning = true
        wifiSection.actionError = ""
        scanProc.running = false
        scanProc.running = true
    }

    // Action process (connect, disconnect, forget, toggle-radio)
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                wifiSection.connecting = false
                try {
                    let res = JSON.parse(this.text.trim())
                    if (!res.success && res.error) {
                        wifiSection.actionError = res.error
                    } else {
                        wifiSection.actionError = ""
                        wifiSection.selectedSsid = ""
                        wifiSection.passwordInput = ""
                    }
                } catch(e) {}
                refreshScan()
            }
        }
    }

    function doConnect(ssid, pwd) {
        wifiSection.connecting = true
        wifiSection.actionError = ""
        if (pwd && pwd.length > 0) {
            actionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "connect", ssid, pwd]
        } else {
            actionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "connect", ssid]
        }
        actionProc.running = false
        actionProc.running = true
    }

    function doDisconnect(ssid) {
        wifiSection.actionError = ""
        actionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "disconnect", ssid || ""]
        actionProc.running = false
        actionProc.running = true
    }

    function doForget(ssid) {
        wifiSection.actionError = ""
        actionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "forget", ssid]
        actionProc.running = false
        actionProc.running = true
    }

    function doToggleRadio() {
        actionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/wifi_info.py", "toggle-radio"]
        actionProc.running = false
        actionProc.running = true
    }

    onVisibleChanged: {
        if (visible) {
            statusProc.running = false
            statusProc.running = true
            refreshScan()
        } else {
            if (speedTest.running) speedTest.cancel()
            speedTestActive = false
            selectedSsid = ""
            actionError = ""
            passwordInput = ""
        }
    }

    Column {
        anchors.fill: parent
        spacing: 10

        // ================= HEADER BAR (No close button) =================
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 18
                    color: wifiSection.statusObj.connected ? root.seal : root.fillIdle
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        text: wifiSection.statusObj.wifiBlocked ? "wifi_off" : "wifi"
                        color: wifiSection.statusObj.connected ? root.paper : root.ink
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: wifiSection.speedTestActive ? "CLOUDFLARE SPEEDOMETER" : "WI-FI & NETWORK"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }

                    Row {
                        spacing: 6
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: wifiSection.speedTestActive ? (speedTest.running ? "#38bdf8" : "#4ade80") : (wifiSection.statusObj.connected ? "#4ade80" : (wifiSection.statusObj.wifiBlocked ? "#f87171" : root.sumiHi))
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: wifiSection.speedTestActive 
                                ? (speedTest.running ? ("Live Speed Test • " + wifiSection.edgeText()) : ("Speedometer Cockpit • " + (wifiSection.lastSpeedStamp ? ("Last run: " + wifiSection.lastSpeedStamp) : "Ready")))
                                : (wifiSection.statusObj.wifiBlocked 
                                    ? "Wi-Fi is turned off" 
                                    : (wifiSection.statusObj.connected ? ("Connected to " + wifiSection.statusObj.ssid) : "Not connected"))
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

                // Radio Toggle Pill (when in normal mode)
                Rectangle {
                    visible: !wifiSection.speedTestActive
                    width: 76
                    height: 28
                    radius: 14
                    color: !wifiSection.statusObj.wifiBlocked ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : root.fillIdle
                    border.width: 1
                    border.color: !wifiSection.statusObj.wifiBlocked ? root.seal : Qt.rgba(1, 1, 1, 0.1)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: wifiSection.statusObj.wifiBlocked ? "power_settings_new" : "check"
                            color: !wifiSection.statusObj.wifiBlocked ? root.seal : root.ink
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: wifiSection.statusObj.wifiBlocked ? "OFF" : "ON"
                            color: !wifiSection.statusObj.wifiBlocked ? root.seal : root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiSection.doToggleRadio()
                    }
                }

                // Rescan Button (when in normal mode)
                Rectangle {
                    visible: !wifiSection.speedTestActive
                    width: 82
                    height: 28
                    radius: 14
                    color: rescanMa.containsMouse ? root.fillHover : root.fillIdle
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
                            RotationAnimation on rotation {
                                running: wifiSection.scanning
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1000
                            }
                        }
                        Text {
                            text: wifiSection.scanning ? "Scanning" : "Rescan"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: rescanMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiSection.refreshScan()
                    }
                }

                // Back to Wi-Fi button (when speedometer active)
                Rectangle {
                    visible: wifiSection.speedTestActive
                    width: 114
                    height: 28
                    radius: 14
                    color: backWifiMa.containsMouse ? root.fillHover : root.fillIdle
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        IconText {
                            text: "arrow_back"
                            color: root.ink
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Back to Wi-Fi"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: backWifiMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wifiSection.exitSpeedTest()
                    }
                }
            }
        }

        // ================= SEGMENTED TAB SWITCHER =================
        Row {
            width: parent.width
            height: 32
            spacing: 8
            visible: !wifiSection.speedTestActive

            Rectangle {
                width: (parent.width - 8) / 2
                height: 32
                radius: 16
                color: wifiSection.activeView === "status" ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "info"
                        color: wifiSection.activeView === "status" ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Connection Info"
                        color: wifiSection.activeView === "status" ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wifiSection.activeView = "status"
                }
            }

            Rectangle {
                width: (parent.width - 8) / 2
                height: 32
                radius: 16
                color: wifiSection.activeView === "networks" ? root.seal : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText {
                        text: "wifi_find"
                        color: wifiSection.activeView === "networks" ? root.paper : root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Networks (" + (availableModel.count || 0) + ")"
                        color: wifiSection.activeView === "networks" ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: wifiSection.activeView = "networks"
                }
            }
        }

        // ================= FULL-WIDTH SINGLE COLUMN CARD CONTENT =================
        Item {
            id: normalWifiRow
            width: parent.width
            height: parent.height - 36 - 32 - 20
            visible: !wifiSection.speedTestActive

            // Card 1: Connection & Telemetry (Full Width)
            Rectangle {
                anchors.fill: parent
                visible: wifiSection.activeView === "status"
                radius: 20
                color: root.fillIdle
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Network SSID Header
                    Item {
                        width: parent.width
                        height: 44

                        Row {
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                width: 42
                                height: 42
                                radius: 14
                                color: wifiSection.statusObj.connected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                                border.width: 1
                                border.color: wifiSection.statusObj.connected ? root.seal : Qt.rgba(1, 1, 1, 0.08)
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: wifiSection.statusObj.connected ? "wifi" : "wifi_off"
                                    color: wifiSection.statusObj.connected ? root.seal : root.ink
                                    font.pixelSize: 20
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 52
                                spacing: 1

                                Text {
                                    text: wifiSection.statusObj.connected ? wifiSection.statusObj.ssid : "Not Connected"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Row {
                                    spacing: 5
                                    Rectangle {
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: wifiSection.statusObj.connected ? "#4ade80" : "#f87171"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: wifiSection.statusObj.connected ? (wifiSection.statusObj.freq ? (wifiSection.statusObj.freq + " Wi-Fi") : "Connected") : "Disconnected"
                                        color: root.ink
                                        opacity: 0.6
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Signal Strength Gauge
                    Column {
                        width: parent.width
                        spacing: 4

                        Item {
                            width: parent.width
                            height: 14
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "SIGNAL STRENGTH"
                                color: root.ink
                                opacity: 0.5
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: wifiSection.statusObj.connected ? (wifiSection.statusObj.signal + "%") : "—"
                                color: root.seal
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                width: parent.width * (wifiSection.statusObj.connected ? Math.min(1.0, wifiSection.statusObj.signal / 100) : 0)
                                height: parent.height
                                radius: 3
                                color: (wifiSection.statusObj.signal > 60) ? root.seal : ((wifiSection.statusObj.signal > 30) ? "#fbbf24" : "#f87171")
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

                    // Material 3 Expressive Telemetry Rows
                    Column {
                        width: parent.width
                        spacing: 6

                        // IP Address
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                IconText { text: "router"; color: root.seal; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "IP"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 10; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: wifiSection.statusObj.ip || "—"; color: root.ink; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Medium; elide: Text.ElideRight; width: parent.width - 70 - 13 - 12; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        // Interface
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                IconText { text: "lan"; color: root.color02; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Interface"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 10; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: wifiSection.statusObj.iface || "—"; color: root.ink; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        // Link Speed
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                IconText { text: "speed"; color: "#38bdf8"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Link Speed"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 10; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: wifiSection.statusObj.linkSpeed || "—"; color: root.seal; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }

                        // Live Ping
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.03)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                IconText { text: "wifi_tethering"; color: "#4ade80"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Live Ping"; color: root.ink; opacity: 0.6; font.family: root.barFont; font.pixelSize: 10; width: 70; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: wifiSection.statusObj.ping || "—"; color: root.ink; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Medium; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        width: parent.width
                        height: 2
                    }

                    // HERO ACTION PILL: Launch Car Speedometer
                    Rectangle {
                        width: parent.width
                        height: 38
                        radius: 19
                        color: launchSpeedMa.containsMouse ? root.fillHover : root.seal
                        border.width: 1
                        border.color: launchSpeedMa.containsMouse ? root.paper : root.seal

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            IconText {
                                text: "speed"
                                color: launchSpeedMa.containsMouse ? root.ink : root.paper
                                font.pixelSize: 15
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Test Internet Speed"
                                color: launchSpeedMa.containsMouse ? root.ink : root.paper
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: launchSpeedMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiSection.startSpeedTestWithSweep()
                        }
                    }
                }
            }

            // Card 2: Networks Browser (Full Width)
            Rectangle {
                id: card2
                anchors.fill: parent
                visible: wifiSection.activeView === "networks"
                radius: 20
                color: root.fillIdle
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8

                    // Tabs Header Row
                    Item {
                        width: parent.width
                        height: 28

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 104
                                height: 26
                                radius: 13
                                color: wifiSection.currentTab === "available" ? root.fillActive : Qt.rgba(1, 1, 1, 0.04)
                                border.width: wifiSection.currentTab === "available" ? 1 : 0
                                border.color: root.seal

                                Text {
                                    anchors.centerIn: parent
                                    text: "Available (" + availableModel.count + ")"
                                    color: wifiSection.currentTab === "available" ? root.seal : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: wifiSection.currentTab === "available" ? Font.Bold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiSection.currentTab = "available"
                                        wifiSection.selectedSsid = ""
                                        wifiSection.actionError = ""
                                    }
                                }
                            }

                            Rectangle {
                                width: 90
                                height: 26
                                radius: 13
                                color: wifiSection.currentTab === "saved" ? root.fillActive : Qt.rgba(1, 1, 1, 0.04)
                                border.width: wifiSection.currentTab === "saved" ? 1 : 0
                                border.color: root.seal

                                Text {
                                    anchors.centerIn: parent
                                    text: "Saved (" + savedModel.count + ")"
                                    color: wifiSection.currentTab === "saved" ? root.seal : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: wifiSection.currentTab === "saved" ? Font.Bold : Font.Normal
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiSection.currentTab = "saved"
                                        wifiSection.selectedSsid = ""
                                        wifiSection.actionError = ""
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: wifiSection.connecting ? "Connecting…" : (wifiSection.actionError ? wifiSection.actionError : "")
                            color: wifiSection.actionError ? "#f87171" : root.seal
                            font.family: root.barFont
                            font.pixelSize: 10
                            elide: Text.ElideLeft
                            width: 110
                        }
                    }

                    // Inline Password / Connection Card
                    Rectangle {
                        width: parent.width
                        height: (wifiSection.selectedSsid !== "") ? 76 : 0
                        radius: 14
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3)
                        clip: true
                        visible: height > 0
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Row {
                                width: parent.width
                                Text {
                                    text: "Connect to: " + wifiSection.selectedSsid
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    width: parent.width - 24
                                }
                                IconText {
                                    text: "close"
                                    color: root.sumiHi
                                    font.pixelSize: 14
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            wifiSection.selectedSsid = ""
                                            wifiSection.passwordInput = ""
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 8

                                Rectangle {
                                    width: parent.width - 76
                                    height: 28
                                    radius: 14
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: pwdInput.activeFocus ? root.seal : Qt.rgba(1, 1, 1, 0.1)

                                    TextInput {
                                        id: pwdInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        echoMode: TextInput.Password
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        onTextEdited: wifiSection.passwordInput = text
                                        onAccepted: wifiSection.doConnect(wifiSection.selectedSsid, wifiSection.passwordInput)
                                    }
                                }

                                Rectangle {
                                    width: 68
                                    height: 28
                                    radius: 14
                                    color: root.seal

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: root.paper
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wifiSection.doConnect(wifiSection.selectedSsid, wifiSection.passwordInput)
                                    }
                                }
                            }
                        }
                    }

                    // Network ListView
                    ListView {
                        id: netListView
                        width: parent.width
                        height: parent.height - 36 - ((wifiSection.selectedSsid !== "") ? 84 : 0)
                        clip: true
                        spacing: 6
                        model: wifiSection.currentTab === "available" ? availableModel : savedModel
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: netListView.width
                            height: 44
                            radius: 12
                            color: netItemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: model.connected ? root.seal : (netItemMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04))

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10

                                // Left Wi-Fi Signal Icon
                                Rectangle {
                                    id: netIconRect
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: model.connected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    IconText {
                                        anchors.centerIn: parent
                                        text: (model.signal > 70) ? "wifi" : ((model.signal > 40) ? "network_wifi_3_bar" : "network_wifi_1_bar")
                                        color: model.connected ? root.seal : root.ink
                                        font.pixelSize: 15
                                    }
                                }

                                // Action buttons on right
                                Row {
                                    id: netActionsRow
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    // Disconnect Button
                                    Rectangle {
                                        visible: model.connected === true
                                        width: 72
                                        height: 24
                                        radius: 12
                                        color: discMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                                        border.width: discMa.containsMouse ? 1 : 0
                                        border.color: "#ef4444"

                                        Text {
                                            anchors.centerIn: parent
                                            text: discMa.containsMouse ? "Disconnect" : "Connected"
                                            color: discMa.containsMouse ? "#fca5a5" : root.seal
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                        }

                                        MouseArea {
                                            id: discMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wifiSection.doDisconnect(model.ssid)
                                        }
                                    }

                                    // Connect Button
                                    Rectangle {
                                        visible: !model.connected
                                        width: 60
                                        height: 24
                                        radius: 12
                                        color: connBtnMa.containsMouse ? root.seal : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Connect"
                                            color: connBtnMa.containsMouse ? root.paper : root.ink
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: connBtnMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (model.saved || model.security === "Open") {
                                                    wifiSection.doConnect(model.ssid, null)
                                                } else {
                                                    wifiSection.selectedSsid = model.ssid
                                                    wifiSection.passwordInput = ""
                                                    Qt.callLater(function() { pwdInput.forceActiveFocus() })
                                                }
                                            }
                                        }
                                    }

                                    // Forget button
                                    Rectangle {
                                        visible: model.saved === true
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: forgetMa.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : Qt.rgba(1, 1, 1, 0.06)

                                        IconText {
                                            anchors.centerIn: parent
                                            text: "delete"
                                            color: forgetMa.containsMouse ? "#fca5a5" : root.ink
                                            opacity: forgetMa.containsMouse ? 1 : 0.6
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            id: forgetMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: wifiSection.doForget(model.ssid)
                                        }
                                    }
                                }

                                // Center SSID & security info
                                Column {
                                    anchors.left: netIconRect.right
                                    anchors.leftMargin: 8
                                    anchors.right: netActionsRow.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: model.ssid || "Hidden Network"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: model.connected ? Font.Bold : Font.Medium
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Row {
                                        spacing: 5
                                        IconText {
                                            visible: model.security !== "Open"
                                            text: "lock"
                                            color: root.ink
                                            opacity: 0.4
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: (model.security ? (model.security + " • ") : "") + model.signal + "%"
                                            color: root.ink
                                            opacity: 0.45
                                            font.family: root.barFont
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: netItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                z: -1
                                onClicked: {
                                    if (!model.connected) {
                                        if (model.saved || model.security === "Open") {
                                            wifiSection.doConnect(model.ssid, null)
                                        } else {
                                            wifiSection.selectedSsid = model.ssid
                                            wifiSection.passwordInput = ""
                                            Qt.callLater(function() { pwdInput.forceActiveFocus() })
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =================================================================
        // MODE B: CAR SPEEDOMETER COCKPIT
        // (Appears when speed test has started, covering the ENTIRE right side!)
        // =================================================================
        Rectangle {
            id: fullSpeedometerCard
            width: parent.width
            height: parent.height - 46
            radius: 24
            color: root.fillIdle
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            clip: true
            visible: wifiSection.speedTestActive

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 6

                // Top Info Bar
                Item {
                    width: parent.width
                    height: 26

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            height: 24
                            width: exitPillTxt.implicitWidth + 24
                            radius: 12
                            color: exitSpeedMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    text: "arrow_back"
                                    color: root.ink
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: exitPillTxt
                                    text: "Wi-Fi Networks"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: exitSpeedMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiSection.exitSpeedTest()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (wifiSection.statusObj.ssid ? ("Testing " + wifiSection.statusObj.ssid) : "Internet Performance")
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }

                    // Cloudflare Edge Badge on Right
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        width: cfBadgeTxt.implicitWidth + 18
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "cloud"
                                color: root.seal
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                id: cfBadgeTxt
                                text: wifiSection.edgeText()
                                color: root.ink
                                opacity: 0.8
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // THE CAR SPEEDOMETER DIAL (Strictly budgeted to 215px height so nothing clips)
                Item {
                    id: speedometerCluster
                    width: parent.width
                    height: 215

                    // Canvas drawing the tachometer gauge dial
                    Canvas {
                        id: dialCanvas
                        anchors.fill: parent

                        property real liveVal: wifiSection.displayedSpeed
                        property string currPhase: speedTest.phase
                        property color arcColor: (currPhase === "upload") ? "#c084fc" : root.seal

                        onLiveValChanged: requestPaint()
                        onCurrPhaseChanged: requestPaint()
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()

                            var cx = width / 2
                            var cy = height / 2 + 5
                            var r = 94

                            var startAngle = 140 * Math.PI / 180
                            var endAngle = 400 * Math.PI / 180
                            var totalAngle = endAngle - startAngle

                            // 1. Outer subtle gauge ring
                            ctx.beginPath()
                            ctx.arc(cx, cy, r + 14, startAngle - 0.05, endAngle + 0.05, false)
                            ctx.lineWidth = 1
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05)
                            ctx.stroke()

                            // 2. Background Track Arc
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, startAngle, endAngle, false)
                            ctx.lineWidth = 7
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                            ctx.stroke()

                            // 3. High-Speed Redline Zone (300 to 500 Mbps, last ~25% of gauge)
                            var redlineStart = startAngle + totalAngle * 0.75
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, redlineStart, endAngle, false)
                            ctx.lineWidth = 7
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(0.95, 0.25, 0.25, 0.3)
                            ctx.stroke()

                            // 4. Glowing Active Progress Arc
                            var prog = wifiSection.speedToProgress(liveVal)
                            if (prog > 0.005) {
                                var activeAngle = startAngle + totalAngle * Math.min(1.0, prog)
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, startAngle, activeAngle, false)
                                ctx.lineWidth = 8
                                ctx.lineCap = "round"
                                ctx.strokeStyle = arcColor
                                ctx.stroke()
                            }

                            // 5. Speedometer Tick Marks
                            var ticks = [
                                { speed: 0, label: "0" },
                                { speed: 10, label: "10" },
                                { speed: 25, label: "25" },
                                { speed: 50, label: "50" },
                                { speed: 100, label: "100" },
                                { speed: 200, label: "200" },
                                { speed: 300, label: "300" },
                                { speed: 500, label: "500" }
                            ]

                            // Minor ticks
                            for (var i = 0; i <= 32; i++) {
                                var frac = i / 32.0
                                var tickAngle = startAngle + frac * totalAngle
                                var isMajor = (i % 4 === 0)
                                var inR = r - (isMajor ? 12 : 6)
                                var outR = r - 4

                                var cosA = Math.cos(tickAngle)
                                var sinA = Math.sin(tickAngle)

                                ctx.beginPath()
                                ctx.moveTo(cx + inR * cosA, cy + inR * sinA)
                                ctx.lineTo(cx + outR * cosA, cy + outR * sinA)
                                ctx.lineWidth = isMajor ? 1.8 : 0.9
                                ctx.strokeStyle = isMajor ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.12)
                                ctx.stroke()
                            }

                            // Major tick numbers
                            ctx.fillStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                            ctx.font = "bold 8.5px sans-serif"
                            ctx.textAlign = "center"
                            ctx.textBaseline = "middle"

                            for (var j = 0; j < ticks.length; j++) {
                                var t = ticks[j]
                                var p = wifiSection.speedToProgress(t.speed)
                                var a = startAngle + p * totalAngle
                                var numR = r - 20
                                var tx = cx + numR * Math.cos(a)
                                var ty = cy + numR * Math.sin(a)
                                ctx.fillText(t.label, tx, ty)
                            }
                        }
                    }

                    // RACING NEEDLE POINTER (Physical needle with spring bounce)
                    Item {
                        id: needlePivot
                        width: 215
                        height: 215
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 5

                        property real needleTarget: wifiSection.speedToAngle(wifiSection.displayedSpeed)

                        rotation: needleTarget
                        Behavior on rotation {
                            SpringAnimation {
                                spring: 2.8
                                damping: 0.35
                                epsilon: 0.1
                            }
                        }

                        // The tapered racing needle arm
                        Rectangle {
                            id: needleBlade
                            width: 3.0
                            height: 80
                            radius: 1.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.verticalCenter

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#ff2e63" }
                                GradientStop { position: 0.5; color: "#f43f5e" }
                                GradientStop { position: 1.0; color: root.seal }
                            }

                            // Glowing needle tip
                            Rectangle {
                                width: 5
                                height: 10
                                radius: 2.5
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                color: "#ff0055"
                            }
                        }
                    }

                    // Center Bezel Hub Cap
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 5
                        color: Qt.rgba(0.08, 0.08, 0.1, 0.95)
                        border.width: 2.5
                        border.color: Qt.rgba(1, 1, 1, 0.2)

                        Rectangle {
                            width: 16
                            height: 16
                            radius: 8
                            anchors.centerIn: parent
                            color: root.seal

                            Rectangle {
                                width: 5
                                height: 5
                                radius: 2.5
                                anchors.centerIn: parent
                                color: root.paper
                            }
                        }
                    }

                    // Center Digital HUD Readout (Below the center hub)
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: 24
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: wifiSection.displayedSpeed >= 100 
                                ? wifiSection.displayedSpeed.toFixed(0) 
                                : wifiSection.displayedSpeed.toFixed(1)
                            font.family: root.barFont
                            font.pixelSize: 32
                            font.weight: Font.Black
                            font.letterSpacing: -1
                            color: root.ink
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "MBPS"
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            color: (speedTest.phase === "upload") ? "#c084fc" : root.seal
                        }

                        // Active Phase Pill Badge
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 3
                            width: phasePillTxt.implicitWidth + 16
                            height: 18
                            radius: 9
                            color: speedTest.running ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: speedTest.running ? root.seal : Qt.rgba(1, 1, 1, 0.08)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                IconText {
                                    text: {
                                        if (speedTest.phase === "latency") return "speed"
                                        if (speedTest.phase === "download") return "arrow_downward"
                                        if (speedTest.phase === "upload") return "arrow_upward"
                                        if (speedTest.phase === "success") return "check_circle"
                                        return "play_arrow"
                                    }
                                    color: speedTest.running ? root.seal : root.ink
                                    opacity: speedTest.running ? 1.0 : 0.6
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: phasePillTxt
                                    text: {
                                        if (speedTest.phase === "latency") return "PINGING"
                                        if (speedTest.phase === "download") return "DOWNLOADING"
                                        if (speedTest.phase === "upload") return "UPLOADING"
                                        if (speedTest.phase === "success") return "COMPLETED"
                                        return "READY"
                                    }
                                    color: speedTest.running ? root.seal : root.ink
                                    opacity: speedTest.running ? 1.0 : 0.7
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // BOTTOM CONTROLS & TELEMETRY ROW
                // Unified single row across the full width: Ping + Download + Upload + Hero Button
                Row {
                    width: parent.width
                    height: 48
                    spacing: 8

                    // Ping Tile
                    Rectangle {
                        width: (parent.width - 24) * 0.22
                        height: parent.height
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: speedTest.phase === "latency" ? root.seal : Qt.rgba(1, 1, 1, 0.06)

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                IconText { text: "speed"; color: "#4ade80"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "PING"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text {
                                text: speedTest.phase === "latency" ? "…" : (speedTest.pingMs > 0 ? (wifiSection.formatPing(speedTest.pingMs)) : "—")
                                color: speedTest.pingMs > 0 ? "#4ade80" : root.ink
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Download Tile
                    Rectangle {
                        width: (parent.width - 24) * 0.26
                        height: parent.height
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: speedTest.phase === "download" ? root.seal : Qt.rgba(1, 1, 1, 0.06)

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                IconText { text: "arrow_downward"; color: root.seal; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "DOWNLOAD"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text {
                                text: speedTest.phase === "download" ? (wifiSection.formatMbps(speedTest.downloadMbps)) : (speedTest.downloadMbps > 0 ? wifiSection.formatMbps(speedTest.downloadMbps) : "—")
                                color: speedTest.downloadMbps > 0 ? root.seal : root.ink
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Upload Tile
                    Rectangle {
                        width: (parent.width - 24) * 0.26
                        height: parent.height
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: speedTest.phase === "upload" ? "#c084fc" : Qt.rgba(1, 1, 1, 0.06)

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                IconText { text: "arrow_upward"; color: "#c084fc"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "UPLOAD"; color: root.ink; opacity: 0.5; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text {
                                text: speedTest.phase === "upload" ? (wifiSection.formatMbps(speedTest.uploadMbps)) : (speedTest.uploadMbps > 0 ? wifiSection.formatMbps(speedTest.uploadMbps) : "—")
                                color: speedTest.uploadMbps > 0 ? "#c084fc" : root.ink
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    // Action Button (Cancel / Re-Test / Done)
                    Rectangle {
                        width: (parent.width - 24) * 0.26
                        height: parent.height
                        radius: 14
                        color: speedTest.running ? Qt.rgba(0.9, 0.2, 0.2, 0.25) : (speedActionMa.containsMouse ? root.fillHover : root.seal)
                        border.width: 1
                        border.color: speedTest.running ? "#ef4444" : (speedActionMa.containsMouse ? root.paper : root.seal)

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            IconText {
                                text: speedTest.running ? "stop" : (speedTest.phase === "success" ? "refresh" : "speed")
                                color: speedTest.running ? "#fca5a5" : (speedActionMa.containsMouse ? root.ink : root.paper)
                                font.pixelSize: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: speedTest.running ? "Stop" : (speedTest.phase === "success" ? "Re-Test" : "Start")
                                color: speedTest.running ? "#fca5a5" : (speedActionMa.containsMouse ? root.ink : root.paper)
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: speedActionMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (speedTest.running) {
                                    speedTest.cancel()
                                } else {
                                    wifiSection.startSpeedTestWithSweep()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

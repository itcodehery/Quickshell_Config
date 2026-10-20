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
    property string activeView: "status"
    function nextSubOption() { return false; }
    function prevSubOption() { return false; }

    property string currentTab: "available"
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

    function getSignalIcon(sig) {
        if (sig >= 75) return "signal_wifi_4_bar"
        if (sig >= 50) return "network_wifi_3_bar"
        if (sig >= 25) return "network_wifi_2_bar"
        return "network_wifi_1_bar"
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Matches Calendar Widget Design) ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: WI-FI STATUS & SPEEDOMETER WIDGET ───────────────────
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
                            color: wifiSection.statusObj.wifiBlocked ? "#ea6962" : (wifiSection.statusObj.connected ? "#a9b665" : root.sumiHi)
                        }

                        IconText {
                            text: wifiSection.statusObj.wifiBlocked ? "wifi_off" : "wifi"
                            font.pixelSize: 13
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: wifiSection.statusObj.wifiBlocked ? "Wi-Fi Off" : (wifiSection.statusObj.connected ? wifiSection.statusObj.ssid : "Disconnected")
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                // Top Right: Radio Toggle & Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Radio Power Toggle Pill
                    Rectangle {
                        width: 58; height: 26; radius: 13
                        color: !wifiSection.statusObj.wifiBlocked ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 1
                        border.color: !wifiSection.statusObj.wifiBlocked ? root.seal : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "power_settings_new"
                                font.pixelSize: 12
                                color: !wifiSection.statusObj.wifiBlocked ? root.seal : root.ink
                                opacity: !wifiSection.statusObj.wifiBlocked ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: wifiSection.statusObj.wifiBlocked ? "OFF" : "ON"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: !wifiSection.statusObj.wifiBlocked ? root.seal : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiSection.doToggleRadio()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: closeBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 0

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.ink
                            opacity: 0.85
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: closeBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiSection.closeRequested()
                        }
                    }
                }
            }

            // Left Column Body Content
            Column {
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 8

                // 1. Current Network Card (Minimal & Clean)
                Rectangle {
                    width: parent.width
                    height: wifiSection.statusObj.connected ? 98 : 62
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Row {
                            width: parent.width
                            spacing: 10

                            // Wi-Fi Icon
                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: wifiSection.statusObj.connected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                border.width: 1
                                border.color: wifiSection.statusObj.connected ? root.seal : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: wifiSection.statusObj.wifiBlocked ? "wifi_off" : wifiSection.getSignalIcon(wifiSection.statusObj.signal)
                                    color: wifiSection.statusObj.connected ? root.seal : root.ink
                                    font.pixelSize: 20
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 40 - 10
                                spacing: 2

                                Text {
                                    text: wifiSection.statusObj.wifiBlocked ? "Wi-Fi Off" : (wifiSection.statusObj.connected ? wifiSection.statusObj.ssid : "Not connected")
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.ink
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: wifiSection.statusObj.connected 
                                        ? ("Signal " + wifiSection.statusObj.signal + "% • " + (wifiSection.statusObj.freq.indexOf("5") === 0 ? "5 GHz" : "2.4 GHz"))
                                        : (wifiSection.statusObj.wifiBlocked ? "Turn on Wi-Fi to browse networks" : "Select a network on the right to connect")
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: root.ink
                                    opacity: 0.65
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                        }

                        // Disconnect action button if connected
                        Rectangle {
                            visible: wifiSection.statusObj.connected
                            width: parent.width
                            height: 26
                            radius: 13
                            color: discHeroMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.25) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            border.width: 1
                            border.color: discHeroMa.containsMouse ? "#ea6962" : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                IconText {
                                    text: "link_off"
                                    font.pixelSize: 12
                                    color: discHeroMa.containsMouse ? "#ea6962" : root.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Disconnect"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: discHeroMa.containsMouse ? "#ea6962" : root.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: discHeroMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiSection.doDisconnect(wifiSection.statusObj.ssid)
                            }
                        }
                    }
                }

                // 2. Speed Test Action Button (Full-width long button)
                Rectangle {
                    id: speedTestBtn
                    width: parent.width
                    height: 32
                    radius: 16
                    color: speedBtnMa.containsMouse
                        ? (speedTest.running ? Qt.rgba(0.92, 0.41, 0.38, 0.22) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22))
                        : (speedTest.running ? Qt.rgba(root.warn.r, root.warn.g, root.warn.b, 0.14) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06))
                    border.width: 1
                    border.color: speedBtnMa.containsMouse
                        ? (speedTest.running ? "#ea6962" : root.seal)
                        : (speedTest.running ? root.warn : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08))

                    Row {
                        anchors.centerIn: parent
                        spacing: 7

                        IconText {
                            text: speedTest.running
                                ? (speedBtnMa.containsMouse ? "close" : "speed")
                                : "speed"
                            font.pixelSize: 13
                            color: speedTest.running
                                ? (speedBtnMa.containsMouse ? "#ea6962" : root.warn)
                                : (speedBtnMa.containsMouse ? root.seal : root.ink)
                            anchors.verticalCenter: parent.verticalCenter
                            RotationAnimation on rotation {
                                running: speedTest.running && !speedBtnMa.containsMouse
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 1000
                            }
                        }

                        Text {
                            text: {
                                if (speedTest.running) {
                                    if (speedBtnMa.containsMouse) return "Cancel Speed Test"
                                    if (speedTest.phase === "download") return "Download: " + wifiSection.formatMbps(wifiSection.displayedSpeed)
                                    if (speedTest.phase === "upload") return "Upload: " + wifiSection.formatMbps(wifiSection.displayedSpeed)
                                    return "Measuring Ping…"
                                }
                                if (speedTest.phase === "success") {
                                    if (speedBtnMa.containsMouse) return "Test Again (" + wifiSection.formatMbps(speedTest.downloadMbps) + " ↓)"
                                    return wifiSection.formatMbps(speedTest.downloadMbps) + " ↓ • " + wifiSection.formatMbps(speedTest.uploadMbps) + " ↑ • " + wifiSection.formatPing(speedTest.latencyMs)
                                }
                                return "Run Speed Test"
                            }
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: speedTest.running
                                ? (speedBtnMa.containsMouse ? "#ea6962" : root.warn)
                                : (speedBtnMa.containsMouse ? root.seal : root.ink)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: speedBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (speedTest.running) speedTest.cancel()
                            else wifiSection.startSpeedTestWithSweep()
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: AVAILABLE WI-FI NETWORKS (CONNECT LIST) ────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
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

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "Available Networks"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        height: 18
                        radius: 9
                        width: countTxt.implicitWidth + 10
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: countTxt
                            anchors.centerIn: parent
                            text: availableModel.count
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.seal
                        }
                    }
                }

                // Action buttons: Rescan + Close
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Rescan Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: rescanBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 0

                        IconText {
                            id: rescanIcon
                            anchors.centerIn: parent
                            text: "refresh"
                            color: root.ink
                            opacity: 0.85
                            font.pixelSize: 14

                            RotationAnimation on rotation {
                                running: wifiSection.scanning
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 800
                            }
                        }

                        MouseArea {
                            id: rescanBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiSection.refreshScan()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: rightCloseMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 0

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.ink
                            opacity: 0.85
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: rightCloseMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiSection.closeRequested()
                        }
                    }
                }
            }

            // Error banner if any
            Rectangle {
                id: errorBanner
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: wifiSection.actionError !== "" ? 26 : 0
                visible: height > 0
                radius: 8
                color: Qt.rgba(root.warn.r, root.warn.g, root.warn.b, 0.2)
                border.width: 1
                border.color: root.warn

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    IconText { text: "error"; font.pixelSize: 13; color: root.warn }
                    Text {
                        text: wifiSection.actionError
                        font.family: root.barFont
                        font.pixelSize: 10
                        color: root.warn
                        font.weight: Font.Bold
                    }
                }
            }

            // Networks List View
            ListView {
                id: networksList
                anchors.top: errorBanner.visible ? errorBanner.bottom : rightTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                clip: true
                spacing: 4
                model: availableModel

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    id: netRow
                    width: networksList.width
                    height: (wifiSection.selectedSsid === model.ssid && !isCurrentlyConnected && !isOpenNetwork) ? 72 : 36
                    radius: 10
                    color: netRowMa.containsMouse ? root.fillHover : (isCurrentlyConnected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12) : "transparent")
                    border.width: isCurrentlyConnected ? 1 : 0
                    border.color: root.seal

                    readonly property bool isCurrentlyConnected: wifiSection.statusObj.connected && (wifiSection.statusObj.ssid === model.ssid)
                    readonly property bool isOpenNetwork: !model.security || model.security === "" || model.security.toLowerCase().indexOf("open") >= 0 || model.security.toLowerCase().indexOf("none") >= 0

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 6

                        // Header line
                        Row {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: netActionRow.left
                            anchors.rightMargin: 6
                            height: 24
                            spacing: 8

                            IconText {
                                text: wifiSection.getSignalIcon(model.signal)
                                font.pixelSize: 15
                                color: isCurrentlyConnected ? root.seal : root.ink
                                opacity: isCurrentlyConnected ? 1.0 : 0.8
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: model.ssid || "Hidden Network"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: isCurrentlyConnected ? Font.Bold : Font.Medium
                                color: isCurrentlyConnected ? root.seal : root.ink
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width - 80)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Open badge
                            Rectangle {
                                visible: isOpenNetwork
                                height: 16
                                radius: 4
                                width: 34
                                color: Qt.rgba(169/255, 182/255, 101/255, 0.2)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Open"
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: "#a9b665"
                                }
                            }

                            // Security Lock icon
                            IconText {
                                visible: !isOpenNetwork
                                text: "lock"
                                font.pixelSize: 11
                                color: root.ink
                                opacity: 0.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Action Buttons on Right
                        Row {
                            id: netActionRow
                            anchors.top: parent.top
                            anchors.right: parent.right
                            height: 24
                            spacing: 6

                            // Connected status badge
                            Rectangle {
                                visible: isCurrentlyConnected
                                height: 22
                                radius: 6
                                width: 72
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Connected"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.seal
                                }
                            }

                            // Disconnect Button if connected
                            Rectangle {
                                visible: isCurrentlyConnected
                                height: 22
                                radius: 6
                                width: 24
                                color: discMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: "link_off"
                                    font.pixelSize: 12
                                    color: root.warn
                                }

                                MouseArea {
                                    id: discMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiSection.doDisconnect(model.ssid)
                                }
                            }

                            // Connect Button (when open network or already saved)
                            Rectangle {
                                visible: !isCurrentlyConnected && (isOpenNetwork || model.saved) && wifiSection.selectedSsid !== model.ssid
                                height: 22
                                radius: 6
                                width: 60
                                color: connBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2)
                                border.width: 1
                                border.color: root.seal
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "Connect"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.seal
                                }

                                MouseArea {
                                    id: connBtnMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiSection.doConnect(model.ssid, "")
                                }
                            }
                        }

                        // Expanded Password Entry (when secured and selected)
                        Row {
                            visible: wifiSection.selectedSsid === model.ssid && !isCurrentlyConnected && !isOpenNetwork
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 28
                            spacing: 6

                            Rectangle {
                                height: 26
                                width: parent.width - 76 - 28
                                radius: 6
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1)
                                border.width: 1
                                border.color: pwdInput.activeFocus ? root.seal : "transparent"

                                TextInput {
                                    id: pwdInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: TextInput.Password
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    clip: true
                                    text: wifiSection.passwordInput
                                    onTextChanged: wifiSection.passwordInput = text
                                    onAccepted: wifiSection.doConnect(model.ssid, text)

                                    Text {
                                        visible: pwdInput.text.length === 0 && !pwdInput.activeFocus
                                        text: "Enter password…"
                                        color: root.ink
                                        opacity: 0.4
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Submit Connect Button
                            Rectangle {
                                height: 26
                                width: 70
                                radius: 6
                                color: submitMa.containsMouse ? root.fillPrimaryHover : root.seal
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: wifiSection.connecting ? "Connecting…" : "Connect"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.seal.hsvValue < 0.5 ? root.ink : root.paper
                                }

                                MouseArea {
                                    id: submitMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: wifiSection.doConnect(model.ssid, pwdInput.text)
                                }
                            }

                            // Cancel Button
                            Rectangle {
                                height: 26
                                width: 24
                                radius: 6
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.pixelSize: 13
                                    color: root.ink
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wifiSection.selectedSsid = ""
                                        wifiSection.passwordInput = ""
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: netRowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        z: -1
                        onClicked: {
                            if (!isCurrentlyConnected) {
                                if (isOpenNetwork || model.saved) {
                                    wifiSection.doConnect(model.ssid, "")
                                } else {
                                    wifiSection.selectedSsid = (wifiSection.selectedSsid === model.ssid ? "" : model.ssid)
                                    wifiSection.passwordInput = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

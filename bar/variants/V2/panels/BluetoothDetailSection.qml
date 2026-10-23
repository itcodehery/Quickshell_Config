import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: btSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property var btObj: ({
        powered: false,
        controllerName: "",
        controllerMac: "",
        discoverable: false,
        devices: []
    })

    property string currentTab: "paired" // "paired" or "all"
    property bool scanning: false
    property string actionError: ""
    property bool working: false

    function nextSubOption() {
        if (currentTab === "paired") {
            currentTab = "all"
            return true
        }
        return false
    }

    function prevSubOption() {
        if (currentTab === "all") {
            currentTab = "paired"
            return true
        }
        return false
    }

    ListModel { id: pairedModel }
    ListModel { id: allModel }
    ListModel { id: connectedModel }

    function getDeviceIcon(iconType) {
        if (!iconType) return "bluetooth"
        var lower = iconType.toLowerCase()
        if (lower.indexOf("headset") >= 0 || lower.indexOf("headphone") >= 0) return "headphones"
        if (lower.indexOf("audio") >= 0 || lower.indexOf("speaker") >= 0) return "speaker"
        if (lower.indexOf("phone") >= 0) return "smartphone"
        if (lower.indexOf("mouse") >= 0) return "mouse"
        if (lower.indexOf("keyboard") >= 0) return "keyboard"
        if (lower.indexOf("gamepad") >= 0) return "sports_esports"
        return "bluetooth"
    }

    // Polling process
    Process {
        id: btStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    btSection.btObj = d

                    pairedModel.clear()
                    allModel.clear()
                    connectedModel.clear()

                    let devs = d.devices || []
                    for (let i = 0; i < devs.length; i++) {
                        let item = devs[i]
                        allModel.append(item)
                        if (item.paired) pairedModel.append(item)
                        if (item.connected) connectedModel.append(item)
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: btSection.visible
        onTriggered: {
            btStatusProc.running = false
            btStatusProc.running = true
        }
    }

    // Action process
    Process {
        id: btActionProc
        stdout: StdioCollector {
            onStreamFinished: {
                btSection.working = false
                try {
                    let res = JSON.parse(this.text.trim())
                    if (!res.success && res.error) {
                        btSection.actionError = res.error
                    } else {
                        btSection.actionError = ""
                    }
                } catch(e) {}
                refresh()
            }
        }
    }

    function refresh() {
        btStatusProc.running = false
        btStatusProc.running = true
    }

    function doConnect(mac) {
        btSection.working = true
        btSection.actionError = ""
        btActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "connect", mac]
        btActionProc.running = false
        btActionProc.running = true
    }

    function doDisconnect(mac) {
        btSection.working = true
        btSection.actionError = ""
        btActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "disconnect", mac]
        btActionProc.running = false
        btActionProc.running = true
    }

    function doPair(mac) {
        btSection.working = true
        btSection.actionError = ""
        btActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "pair", mac]
        btActionProc.running = false
        btActionProc.running = true
    }

    function doRemove(mac) {
        btSection.working = true
        btSection.actionError = ""
        btActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "remove", mac]
        btActionProc.running = false
        btActionProc.running = true
    }

    function doTogglePower() {
        btActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "toggle-power"]
        btActionProc.running = false
        btActionProc.running = true
    }

    function doScan() {
        btSection.scanning = true
        btActionProc.command = ["python3", "/home/hery/.config/quickshell/bar/scripts/bluetooth_info.py", "scan"]
        btActionProc.running = false
        btActionProc.running = true
        scanTimer.restart()
    }

    Timer {
        id: scanTimer
        interval: 10000
        onTriggered: {
            btSection.scanning = false
            refresh()
        }
    }

    onVisibleChanged: {
        if (visible) {
            refresh()
        } else {
            scanning = false
            actionError = ""
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Seamless, matches Calendar widget) ──────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: BLUETOOTH OVERVIEW & SPOTLIGHT ──────────────────────
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

                // Top Right: Power Toggle & Close Button
                Row {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    spacing: 6

                    // Power Toggle Pill
                    Rectangle {
                        width: 56; height: 24; radius: 12
                        color: btSection.btObj.powered ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 1
                        border.color: btSection.btObj.powered ? root.seal : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "power_settings_new"
                                font.pixelSize: 12
                                color: btSection.btObj.powered ? root.seal : root.ink
                                opacity: btSection.btObj.powered ? 1.0 : 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: btSection.btObj.powered ? "ON" : "OFF"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: btSection.btObj.powered ? root.seal : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btSection.doTogglePower()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: closeLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

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
                            onClicked: btSection.closeRequested()
                        }
                    }
                }
            }

            // Left Column Body Content (Connected Device Info Only)
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
                    root: btSection.root
                    anchors.fill: parent
                    dotColor: !btSection.btObj.powered ? "#ea6962" : (connectedModel.count > 0 ? "#a9b665" : root.sumiHi)
                    icon: btSection.btObj.powered ? "bluetooth" : "bluetooth_disabled"
                    text: !btSection.btObj.powered ? "Bluetooth Off" : (connectedModel.count === 1 ? connectedModel.get(0).name : (connectedModel.count > 1 ? ("Connected (" + connectedModel.count + ")") : "Bluetooth On"))

                    // 1. Single Connected Device Spotlight (Centered, clean & minimal)
                    Column {
                        anchors.centerIn: parent
                        visible: connectedModel.count === 1
                        spacing: 12
                        width: parent.width - 32

                        // Device Icon Avatar
                        Rectangle {
                            width: 56; height: 56; radius: 28
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                            border.width: 1
                            border.color: root.seal

                            IconText {
                                anchors.centerIn: parent
                                text: connectedModel.count > 0 ? btSection.getDeviceIcon(connectedModel.get(0).icon) : "bluetooth"
                                font.pixelSize: 26
                                color: root.seal
                            }
                        }

                        // Device Name & MAC Address
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: connectedModel.count > 0 ? connectedModel.get(0).name : ""
                                font.family: root.barFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: root.ink
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignHCenter
                                width: parent.width
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: connectedModel.count > 0 ? connectedModel.get(0).mac : ""
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.ink
                                opacity: 0.4
                            }
                        }

                        // Badges Row: Connected Status + Battery (if reported)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8

                            Rectangle {
                                height: 22
                                radius: 11
                                color: Qt.rgba(0.66, 0.71, 0.40, 0.15)
                                border.width: 1
                                border.color: Qt.rgba(0.66, 0.71, 0.40, 0.3)
                                width: singleConnBadgeRow.implicitWidth + 14

                                Row {
                                    id: singleConnBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Rectangle {
                                        width: 6; height: 6; radius: 3
                                        color: "#a9b665"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Connected"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: "#a9b665"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            Rectangle {
                                visible: connectedModel.count > 0 && connectedModel.get(0).battery >= 0
                                height: 22
                                radius: 11
                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                width: singleBattBadgeRow.implicitWidth + 14

                                Row {
                                    id: singleBattBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "battery_charging_full"
                                        font.pixelSize: 11
                                        color: "#a9b665"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: (connectedModel.count > 0 && connectedModel.get(0).battery >= 0) ? (connectedModel.get(0).battery + "%") : ""
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // 2. Multiple Connected Devices List (if 2+ devices connected simultaneously)
                    ListView {
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: connectedModel.count > 1
                        clip: true
                        spacing: 8
                        model: connectedModel

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 60
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.03)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Rectangle {
                                    width: 40; height: 40; radius: 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                    border.width: 1
                                    border.color: root.seal

                                    IconText {
                                        anchors.centerIn: parent
                                        text: btSection.getDeviceIcon(model.icon)
                                        font.pixelSize: 18
                                        color: root.seal
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 40 - 80 - 20
                                    spacing: 2
                                    clip: true

                                    Text {
                                        text: model.name
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: root.ink
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Row {
                                        spacing: 6
                                        Rectangle {
                                            width: 5; height: 5; radius: 3
                                            color: "#a9b665"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: model.battery >= 0 ? ("Connected • " + model.battery + "%") : "Connected"
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            color: root.ink
                                            opacity: 0.6
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. Disconnected / Empty State
                    Column {
                        anchors.centerIn: parent
                        visible: connectedModel.count === 0
                        spacing: 10
                        width: parent.width - 40

                        Rectangle {
                            width: 52; height: 52; radius: 26
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)

                            IconText {
                                anchors.centerIn: parent
                                text: btSection.btObj.powered ? "bluetooth_searching" : "bluetooth_disabled"
                                font.pixelSize: 26
                                color: root.ink
                                opacity: 0.35
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4
                            width: parent.width

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btSection.btObj.powered ? "No Device Connected" : "Bluetooth is Off"
                                font.family: root.barFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: root.ink
                                opacity: 0.85
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btSection.btObj.powered ? "Select a device on the right to connect" : "Turn on Bluetooth to connect devices"
                                font.family: root.barFont
                                font.pixelSize: 11
                                color: root.ink
                                opacity: 0.45
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: DEVICE LIST & CONNECT ACTIONS ──────────────────────
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
                height: 28

                // Top Left: Tab switcher (Paired | All)
                PillTabs {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root
                    model: [
                        { id: "paired", label: "Paired (" + pairedModel.count + ")" },
                        { id: "all", label: "All (" + allModel.count + ")" }
                    ]
                    current: btSection.currentTab
                    onActivated: (id) => btSection.currentTab = id
                }

                // Top Right: Status / Scan / Close
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Working status text if busy
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: btSection.working
                        text: "Working…"
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: root.seal
                    }

                    // Scan Button
                    Rectangle {
                        height: 26
                        radius: 13
                        width: scanBtnRow.implicitWidth + 16
                        color: scanBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Row {
                            id: scanBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                text: "refresh"
                                font.pixelSize: 13
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                                RotationAnimation on rotation {
                                    running: btSection.scanning
                                    loops: Animation.Infinite
                                    from: 0; to: 360; duration: 1000
                                }
                            }

                            Text {
                                text: btSection.scanning ? "Scanning…" : "Scan"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: scanBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btSection.doScan()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: closeRightMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

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
                            onClicked: btSection.closeRequested()
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
                height: visible ? 24 : 0
                radius: 6
                color: Qt.rgba(0.92, 0.41, 0.38, 0.2)
                visible: btSection.actionError !== ""

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    IconText {
                        text: "error"
                        font.pixelSize: 12
                        color: "#ea6962"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: btSection.actionError
                        font.family: root.barFont
                        font.pixelSize: 10
                        color: "#ea6962"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Devices ListView
            Item {
                anchors.top: errorBanner.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                clip: true

                // Empty state
                Column {
                    anchors.centerIn: parent
                    visible: (btSection.currentTab === "paired" ? pairedModel.count : allModel.count) === 0
                    spacing: 6

                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "bluetooth_searching"
                        font.pixelSize: 32
                        color: root.ink
                        opacity: 0.3
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !btSection.btObj.powered 
                            ? "Bluetooth is turned off" 
                            : (btSection.currentTab === "paired" ? "No paired devices" : "No devices found")
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.ink
                        opacity: 0.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: btSection.btObj.powered
                        text: "Click Scan above to discover nearby devices"
                        font.family: root.barFont
                        font.pixelSize: 10
                        color: root.ink
                        opacity: 0.35
                    }
                }

                ListView {
                    id: btDeviceList
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: btSection.currentTab === "paired" ? pairedModel : allModel

                    delegate: Rectangle {
                        id: devItemRect
                        width: btDeviceList.width
                        height: 48
                        radius: 12
                        color: model.connected 
                            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                            : (devItemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03))
                        border.width: 1
                        border.color: model.connected 
                            ? root.seal 
                            : (devItemMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3) : Qt.rgba(1, 1, 1, 0.04))

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // Device Icon box
                            Rectangle {
                                width: 32; height: 32; radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: model.connected ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                IconText {
                                    anchors.centerIn: parent
                                    text: btSection.getDeviceIcon(model.icon)
                                    color: model.connected ? root.paper : root.ink
                                    font.pixelSize: 16
                                }
                            }

                            // Device Details Column
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 32 - rightDevBtns.width - 24
                                spacing: 1
                                clip: true

                                Text {
                                    text: model.name || "Unknown Device"
                                    color: model.connected ? root.seal : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 12
                                    font.weight: model.connected ? Font.Bold : Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Row {
                                    spacing: 6
                                    clip: true
                                    width: parent.width

                                    Row {
                                        visible: model.battery >= 0
                                        spacing: 2
                                        IconText {
                                            text: "battery_charging_full"
                                            color: "#a9b665"
                                            font.pixelSize: 11
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: model.battery + "%"
                                            color: "#a9b665"
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        text: model.mac
                                        color: root.ink
                                        opacity: 0.4
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                        width: model.battery >= 0 ? Math.max(30, parent.width - 50) : parent.width
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }

                            // Right Action Buttons
                            Row {
                                id: rightDevBtns
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // Connected State / Disconnect Button
                                Rectangle {
                                    visible: model.connected === true
                                    width: 76
                                    height: 24
                                    radius: 12
                                    color: devDiscMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.25) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                                    border.width: devDiscMa.containsMouse ? 1 : 0
                                    border.color: "#ea6962"

                                    Text {
                                        anchors.centerIn: parent
                                        text: devDiscMa.containsMouse ? "Disconnect" : "Connected"
                                        color: devDiscMa.containsMouse ? "#ea6962" : root.seal
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: devDiscMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: btSection.doDisconnect(model.mac)
                                    }
                                }

                                // Connect Button (paired but not connected)
                                Rectangle {
                                    visible: !model.connected && model.paired
                                    width: 60
                                    height: 24
                                    radius: 12
                                    color: connBtnMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Connect"
                                        color: connBtnMa.containsMouse ? root.paper : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: connBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: btSection.doConnect(model.mac)
                                    }
                                }

                                // Pair Button (unpaired)
                                Rectangle {
                                    visible: !model.paired
                                    width: 52
                                    height: 24
                                    radius: 12
                                    color: pairBtnMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Pair"
                                        color: pairBtnMa.containsMouse ? root.paper : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: pairBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: btSection.doPair(model.mac)
                                    }
                                }

                                // Forget / Delete Button (for paired devices)
                                Rectangle {
                                    visible: model.paired === true
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: remMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.25) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "delete"
                                        color: remMa.containsMouse ? "#ea6962" : root.ink
                                        opacity: remMa.containsMouse ? 1 : 0.6
                                        font.pixelSize: 12
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: remMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: btSection.doRemove(model.mac)
                                    }
                                }
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: devItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (model.connected) btSection.doDisconnect(model.mac)
                                else if (model.paired) btSection.doConnect(model.mac)
                                else btSection.doPair(model.mac)
                            }
                        }
                    }
                }
            }
        }
    }
}

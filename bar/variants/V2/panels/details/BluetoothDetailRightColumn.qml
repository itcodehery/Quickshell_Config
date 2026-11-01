import QtQuick
import ".."
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── RIGHT COLUMN: DEVICE LIST & CONNECT ACTIONS ──────────────────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: rightColContainer
    required property var root
    required property var btSection
    required property var pairedModel
    required property var allModel

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

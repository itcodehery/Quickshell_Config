import QtQuick
import ".."
import QtQuick.Controls
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── RIGHT COLUMN: AVAILABLE WI-FI NETWORKS (CONNECT LIST) ────────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: rightColContainer
    required property var root
    required property var wifiSection
    required property var availableModel

    radius: 20
    color: root.fillIdle
    border.width: root.isLightMode ? 1 : 0
    border.color: root.cardBorderColor
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

                SpringPress {}
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
                width: 24; height: 24; radius: 12
                color: rightCloseMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                border.width: 0

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    color: root.ink
                    opacity: 0.85
                    font.pixelSize: 13
                }

                SpringPress {}
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

                        SpringPress {}
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

                        SpringPress {}
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

                        SpringPress {}
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

                        SpringPress {}
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

            SpringPress {}
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

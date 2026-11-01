import QtQuick

Row {
    id: systemTilesRow
    required property var root

    property alias tile5Wrapper: tile5Wrapper
    property alias tile5InAnim: tile5InAnim
    property alias t5Trans: t5Trans
    property alias tile6Wrapper: tile6Wrapper
    property alias tile6InAnim: tile6InAnim
    property alias t6Trans: t6Trans

    height: parent.height
    spacing: 16

    // ── TILE 5: BATTERY & POWER BENTO (1 Col) ─────
    // Direction: Bottom-Center
    Item {
        id: tile5Wrapper
        width: 230
        height: parent.height
        opacity: 0.0
        scale: 0.94
        transform: Translate { id: t5Trans; x: 0; y: 24 }

        SequentialAnimation {
            id: tile5InAnim
            running: true
            PauseAnimation { duration: 320 }
            ParallelAnimation {
                NumberAnimation { target: tile5Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { target: tile5Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                NumberAnimation { target: t5Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }
        }

        Rectangle {
            id: batteryTile
            anchors.fill: parent
            radius: 26
            color: root.cardBg
            border.color: root.cardBorder
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.margins: 14

                // Header Row
                Row {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    spacing: 5

                    Text {
                        text: root.isCharging ? "bolt" : "battery_charging_full"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: root.isCharging ? root.color02 : root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Battery"
                        font.family: "Genova"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Center Percentage
                Row {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -4
                    spacing: 4

                    Text {
                        text: root.batteryPercent + "%"
                        font.family: "Genova"
                        font.pixelSize: 46
                        font.weight: Font.Bold
                        font.letterSpacing: -1.0
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Level Bar
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 8
                    height: 8
                    radius: 4
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(height, parent.width * (Math.max(0, Math.min(100, root.batteryPercent)) / 100))
                        radius: 4
                        color: root.isCharging ? root.color02 : (root.batteryPercent <= 20 ? root.color01 : root.seal)
                    }
                }

                // Status
                Text {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isCharging ? "Charging" : "On Battery"
                    font.family: "Genova"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: root.ink
                    opacity: 0.65
                }
            }
        }
    }

    // ── TILE 6: HARDWARE & SCREEN TIME BENTO (1 Col) ──
    // Direction: Bottom-Right
    Item {
        id: tile6Wrapper
        width: 230
        height: parent.height
        opacity: 0.0
        scale: 0.94
        transform: Translate { id: t6Trans; x: 0; y: 24 }

        SequentialAnimation {
            id: tile6InAnim
            running: true
            PauseAnimation { duration: 360 }
            ParallelAnimation {
                NumberAnimation { target: tile6Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { target: tile6Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                NumberAnimation { target: t6Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }
        }

        Rectangle {
            id: statsTile
            anchors.fill: parent
            radius: 26
            color: root.cardBg
            border.color: root.cardBorder
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.margins: 14

                Column {
                    id: statsCol
                    anchors.fill: parent
                    spacing: 10

                    readonly property real topH: Math.round((height - spacing) * 0.48)
                    readonly property real botH: height - topH - spacing

                    // Top Half: RAM & CPU Cards
                    Row {
                        id: statsTopRow
                        width: parent.width
                        height: statsCol.topH
                        spacing: 8

                        // CPU Metric Card
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 16
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            border.width: 1

                            Item {
                                anchors.fill: parent
                                anchors.margins: 10

                                Row {
                                    id: cpuHeader
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    spacing: 4

                                    Text {
                                        text: "developer_board"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 12
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "CPU"
                                        font.family: "Genova"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.seal
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    anchors.top: cpuHeader.bottom
                                    anchors.topMargin: 2
                                    anchors.left: parent.left
                                    text: root.cpuPercent + "%"
                                    font.family: "Genova"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    font.letterSpacing: -0.5
                                    color: root.ink
                                }

                                // Utilization bar
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(height, parent.width * (Math.max(0, Math.min(100, root.cpuPercent)) / 100))
                                        radius: 2
                                        color: root.cpuPercent > 80 ? root.color01 : root.seal

                                        Behavior on width {
                                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }
                        }

                        // RAM Metric Card
                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: parent.height
                            radius: 16
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                            border.width: 1

                            Item {
                                anchors.fill: parent
                                anchors.margins: 10

                                Row {
                                    id: ramHeader
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    spacing: 4

                                    Text {
                                        text: "memory"
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 12
                                        color: root.color06
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "RAM"
                                        font.family: "Genova"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.color06
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Text {
                                    anchors.top: ramHeader.bottom
                                    anchors.topMargin: 2
                                    anchors.left: parent.left
                                    text: root.memPercent + "%"
                                    font.family: "Genova"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    font.letterSpacing: -0.5
                                    color: root.ink
                                }

                                // Utilization bar
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: Math.max(height, parent.width * (Math.max(0, Math.min(100, root.memPercent)) / 100))
                                        radius: 2
                                        color: root.memPercent > 85 ? root.color01 : root.color06

                                        Behavior on width {
                                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Bottom Half: Screen Time Today Card
                    Rectangle {
                        width: parent.width
                        height: statsCol.botH
                        radius: 18
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: Qt.rgba(root.color03.r, root.color03.g, root.color03.b, 0.12)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "hourglass_empty"
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 20
                                    color: root.color03
                                    anchors.centerIn: parent
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: root.screentimeFormatted
                                    font.family: "Genova"
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    font.letterSpacing: -0.4
                                    color: root.ink
                                }

                                Text {
                                    text: "Screen Time Today"
                                    font.family: "Genova"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: root.ink
                                    opacity: 0.65
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

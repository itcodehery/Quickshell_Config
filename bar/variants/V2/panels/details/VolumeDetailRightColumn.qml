import QtQuick
import ".."
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── RIGHT COLUMN: AUDIO DEVICE INFO & DETAILS ────────────────────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: rightColContainer
    required property var root
    required property var volSection

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
                    text: "headphones"
                    font.pixelSize: 13
                    color: root.ink
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Audio Details"
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: root.ink
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Top Right: Mic Mute Pill + Close Button
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Mic Pill
            Rectangle {
                height: 26
                radius: 13
                color: micPillMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                width: micPillRow.implicitWidth + 16

                Row {
                    id: micPillRow
                    anchors.centerIn: parent
                    spacing: 4

                    IconText {
                        text: volSection.micMuted ? "mic_off" : "mic"
                        font.pixelSize: 11
                        color: volSection.micMuted ? "#ea6962" : root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: volSection.micMuted ? "Mic Off" : "Mic On"
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                SpringPress {}
                MouseArea {
                    id: micPillMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: volSection.toggleMicMute()
                }
            }

            // Close Button
            Rectangle {
                width: 26; height: 26; radius: 13
                color: closeRightMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 14
                    color: root.ink
                }

                SpringPress {}
                MouseArea {
                    id: closeRightMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: volSection.closeRequested()
                }
            }
        }
    }

    // Right Column Body Content
    Item {
        anchors.top: rightTopBar.bottom
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
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // 1. Output Device Card
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                            anchors.verticalCenter: parent.verticalCenter

                            IconText {
                                anchors.centerIn: parent
                                text: (volSection.defaultSinkDesc.toLowerCase().indexOf("head") !== -1 || volSection.defaultSinkDesc.toLowerCase().indexOf("duke") !== -1) ? "headphones" : "speaker"
                                font.pixelSize: 16
                                color: root.seal
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 32 - 10
                            spacing: 2
                            clip: true

                            Text {
                                text: volSection.defaultSinkDesc
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.ink
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: "Default Audio Output Sink"
                                font.family: root.barFont
                                font.pixelSize: 9
                                color: root.ink
                                opacity: 0.5
                            }
                        }
                    }
                }

                // 2. Telemetry Badges Row
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    // Server Badge
                    Rectangle {
                        height: 22
                        radius: 11
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                        border.width: 1
                        border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                        width: serverRow.implicitWidth + 12

                        Row {
                            id: serverRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "tune"
                                font.pixelSize: 10
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "PipeWire Audio"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Format Badge
                    Rectangle {
                        height: 22
                        radius: 11
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        width: fmtRow.implicitWidth + 12

                        Row {
                            id: fmtRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "graphic_eq"
                                font.pixelSize: 10
                                color: root.ink
                                opacity: 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "48 kHz • Stereo"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // 3. Microphone Input Live Peak Level Card
                Rectangle {
                    width: parent.width
                    height: 48
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 14

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                IconText {
                                    text: volSection.micMuted ? "mic_off" : "mic"
                                    font.pixelSize: 12
                                    color: volSection.micMuted ? "#ea6962" : root.seal
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Microphone Input"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: root.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                text: volSection.micMuted ? "MUTED" : (Math.round(volSection.micLevel * 100) + "%")
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: volSection.micMuted ? "#ea6962" : root.seal
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Peak Meter Bar
                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                            Rectangle {
                                width: Math.min(parent.width, Math.round(parent.width * (volSection.micMuted ? 0 : volSection.micLevel)))
                                height: parent.height
                                radius: parent.radius
                                color: volSection.micLevel > 0.8 ? "#ea6962" : (volSection.micLevel > 0.5 ? "#e78a4e" : "#a9b665")

                                Behavior on width { NumberAnimation { duration: 60 } }
                            }
                        }
                    }
                }

                // 4. Output Device Quick Switcher (if multiple sinks)
                Row {
                    width: parent.width
                    spacing: 6
                    visible: volSection.sinks.length > 1

                    Repeater {
                        model: volSection.sinks

                        Rectangle {
                            id: sinkChip
                            required property var modelData
                            readonly property bool isSelected: modelData.name === volSection.defaultSink
                            width: Math.floor((parent.width - (volSection.sinks.length - 1) * 6) / volSection.sinks.length)
                            height: 24
                            radius: 12
                            color: isSelected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2) : (chipMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04))
                            border.width: 1
                            border.color: isSelected ? root.seal : Qt.rgba(1, 1, 1, 0.06)

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                IconText {
                                    text: (sinkChip.modelData.desc.toLowerCase().indexOf("head") !== -1 || sinkChip.modelData.desc.toLowerCase().indexOf("duke") !== -1) ? "headphones" : "speaker"
                                    font.pixelSize: 10
                                    color: sinkChip.isSelected ? root.seal : root.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: sinkChip.modelData.desc
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: sinkChip.isSelected ? Font.Bold : Font.Normal
                                    color: sinkChip.isSelected ? root.seal : root.ink
                                    elide: Text.ElideRight
                                    width: parent.parent.width - 24
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            SpringPress {}
                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: volSection.setDefaultSink(sinkChip.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}

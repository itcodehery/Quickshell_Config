import QtQuick
import ".."
import "../../modules"

// ── Tab 2: System Info (Processor, Memory, Graphics, Display) ──
Item {
    id: systemTabContent
    required property var hoverPanel

    anchors.fill: parent
    visible: opacity > 0.001
    opacity: hoverPanel.omarchyTab === 2 ? 1.0 : 0.0
    x: hoverPanel.omarchyTab === 2 ? 0 : 20
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    enabled: hoverPanel.omarchyTab === 2

    Row {
        anchors.fill: parent
        spacing: 6
        readonly property real cardW: Math.floor((width - 3 * 6) / 4)

        // 1. Processor
        Rectangle {
            width: parent.cardW
            height: parent.height
            radius: 14
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Item {
                    anchors.top: parent.top
                    width: parent.width
                    height: 24

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 8
                        color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                        IconText {
                            anchors.centerIn: parent
                            text: "developer_board"
                            font.pixelSize: 14
                            color: hoverPanel.accent
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18; radius: 9
                        width: cpuChipText.implicitWidth + 10
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                        Text {
                            id: cpuChipText
                            anchors.centerIn: parent
                            text: hoverPanel._vendorOf(hoverPanel.siCpu) !== "" ? hoverPanel._vendorOf(hoverPanel.siCpu) : "CPU"
                            font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                            color: hoverPanel.accent
                        }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    Text {
                        text: "Processor"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                    }
                    Text {
                        width: parent.width
                        text: hoverPanel.siCpu !== "" ? hoverPanel.cpuModel(hoverPanel.siCpu) : "AMD Ryzen"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                        color: hoverPanel.root.ink
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 2. Memory
        Rectangle {
            width: parent.cardW
            height: parent.height
            radius: 14
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Item {
                    anchors.top: parent.top
                    width: parent.width
                    height: 24

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 8
                        color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                        IconText {
                            anchors.centerIn: parent
                            text: "memory"
                            font.pixelSize: 14
                            color: hoverPanel.accent
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18; radius: 9
                        width: ramChipText.implicitWidth + 10
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                        Text {
                            id: ramChipText
                            anchors.centerIn: parent
                            text: "RAM"
                            font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                            color: hoverPanel.accent
                        }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    Text {
                        text: "Memory"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                    }
                    Text {
                        width: parent.width
                        text: hoverPanel.siRam !== "" ? hoverPanel.siRam : "16 GB"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                        color: hoverPanel.root.ink
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 3. Graphics
        Rectangle {
            width: parent.cardW
            height: parent.height
            radius: 14
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Item {
                    anchors.top: parent.top
                    width: parent.width
                    height: 24

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 8
                        color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                        IconText {
                            anchors.centerIn: parent
                            text: "videogame_asset"
                            font.pixelSize: 14
                            color: hoverPanel.accent
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18; radius: 9
                        width: Math.min(60, gpuChipText.implicitWidth + 10)
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                        Text {
                            id: gpuChipText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 6)
                            elide: Text.ElideRight
                            text: hoverPanel.gpuChip(hoverPanel.siGpu) !== "" ? hoverPanel.gpuChip(hoverPanel.siGpu) : "GPU"
                            font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                            color: hoverPanel.accent
                        }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    Text {
                        text: "Graphics"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                    }
                    Text {
                        width: parent.width
                        text: hoverPanel.siGpu !== "" ? hoverPanel.gpuModel(hoverPanel.siGpu) : "Graphics"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                        color: hoverPanel.root.ink
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 4. Display
        Rectangle {
            width: parent.cardW
            height: parent.height
            radius: 14
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
            border.width: 1
            border.color: hoverPanel.root.cardBorderColor

            Item {
                anchors.fill: parent
                anchors.margins: 8

                Item {
                    anchors.top: parent.top
                    width: parent.width
                    height: 24

                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 8
                        color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                        IconText {
                            anchors.centerIn: parent
                            text: "desktop_windows"
                            font.pixelSize: 14
                            color: hoverPanel.accent
                        }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18; radius: 9
                        width: Math.min(64, dispChipText.implicitWidth + 10)
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                        Text {
                            id: dispChipText
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, parent.width - 6)
                            elide: Text.ElideRight
                            text: hoverPanel.displayChip(hoverPanel.siDisplay) !== "" ? hoverPanel.displayChip(hoverPanel.siDisplay) : "Display"
                            font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                            color: hoverPanel.accent
                        }
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    Text {
                        text: "Display"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                    }
                    Text {
                        width: parent.width
                        text: hoverPanel.siDisplay !== "" ? hoverPanel.displayModel(hoverPanel.siDisplay) : "1920 × 1080"
                        font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                        color: hoverPanel.root.ink
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

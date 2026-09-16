import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../OmarchyPower.js" as OmarchyPower

PanelWindow {
    id: batPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-battery"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property int    percent: 0
    property string status:  "unknown"
    property string batteryId: ""
    property string healthText: ""
    property string sizeText: ""
    property string timeLabel: "Time left"
    property string timeText: ""
    property string powerRate: ""
    property int    cycles:   0
    readonly property string healthLabel: batteryId !== "" ? "Health (" + batteryId + ")" : "Health"
    readonly property bool charging: status === "charging"
    function refreshBatteryData() {
        if (!batData.running) batData.running = true
    }
    function statusTitle(s) {
        var t = String(s || "unknown")
        if (t === "fully-charged") return "Full"
        return t.length > 0 ? t.charAt(0).toUpperCase() + t.slice(1) : "Unknown"
    }

    property real reveal: root.batteryVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.batteryVisible ? 160 : 120
            easing.type: root.batteryVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.batteryVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    component InfoRow: Item {
        property string label: ""
        property string value: ""
        property color valueColor: batPanel.root.ink

        width: parent ? parent.width : 0
        height: 16
        visible: value !== ""

        UiText {
            id: infoLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: label
            color: batPanel.root.sumiHi
            font.family: batPanel.root.barFont
            font.pixelSize: 10
        }
        UiText {
            anchors.left: infoLabel.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: value
            color: valueColor
            font.family: batPanel.root.barFont
            font.pixelSize: 10
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignRight
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.batteryVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: batPanel.root
            ownerActive: batPanel.root.batteryVisible
            targetX: batPanel.root.batteryBarX
            reveal: batPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.batteryBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - batPanel.reveal)
            : (barBottom + gap) - 2 * (1 - batPanel.reveal)
        opacity: batPanel.reveal
        focus: root.batteryVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.batteryVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "Battery"
                    color: root.ink; font.family: root.barFont; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.batteryVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Item {
                width: parent.width
                height: 110

                Row {
                    anchors.centerIn: parent
                    spacing: 24

                    Item {
                        width: 52; height: 100
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Rectangle {
                            width: 20; height: 6; radius: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            color: root.sumi
                        }
                        
                        Rectangle {
                            width: 52; height: 96
                            anchors.bottom: parent.bottom
                            radius: 10
                            color: "transparent"
                            border.width: 2
                            border.color: batPanel.charging ? root.indigo : root.sumi
                            
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 4
                                height: Math.max(0, (parent.height - 8) * (batPanel.percent / 100))
                                radius: 6
                                color: batPanel.charging ? root.indigo : root.seal
                                Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutElastic; easing.overshoot: 1.2 } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Canvas {
                                id: bolt
                                visible: batPanel.charging
                                anchors.centerIn: parent
                                width: 18; height: 26
                                property color boltColor: root.paper
                                onBoltColorChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.beginPath()
                                    ctx.moveTo(width * 0.55, 0)
                                    ctx.lineTo(width * 0.12, height * 0.55)
                                    ctx.lineTo(width * 0.45, height * 0.55)
                                    ctx.lineTo(width * 0.38, height)
                                    ctx.lineTo(width * 0.88, height * 0.45)
                                    ctx.lineTo(width * 0.55, height * 0.45)
                                    ctx.closePath()
                                    ctx.fillStyle = bolt.boltColor
                                    ctx.fill()
                                }
                                Component.onCompleted: requestPaint()
                            }
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        UiText {
                            text: batPanel.percent + "%"
                            color: batPanel.charging ? root.indigo : root.seal
                            font.family: root.barFont
                            font.pixelSize: 48
                            font.weight: Font.Bold
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        UiText {
                            text: batPanel.statusTitle(batPanel.status)
                            color: batPanel.charging ? root.indigo : root.ink
                            font.family: root.barFont
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            font.letterSpacing: 1
                        }

                        UiText {
                            visible: batPanel.timeText !== ""
                            text: batPanel.timeText + (batPanel.charging ? " to full" : " remaining")
                            color: root.sumiHi
                            font.family: root.barFont
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Grid {
                width: parent.width
                columns: 2
                spacing: 8

                component StatBox: Rectangle {
                    property string label: ""
                    property string val: ""
                    width: (parent.width - 8) / 2
                    height: 52
                    radius: root.panelRadius
                    color: root.fillActive
                    visible: val !== ""

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        UiText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: label
                            color: root.sumiHi
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.letterSpacing: 1
                        }
                        UiText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: val
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                StatBox { label: batPanel.charging ? "CHARGE RATE" : "POWER DRAW"; val: batPanel.powerRate !== "" ? batPanel.powerRate + " W" : "" }
                StatBox { label: "HEALTH"; val: batPanel.healthText }
                StatBox { label: "CYCLES"; val: batPanel.cycles > 0 ? String(batPanel.cycles) : "" }
                StatBox { label: "CAPACITY"; val: batPanel.sizeText }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Rectangle {
                width: parent.width
                height: 28; radius: root.panelButtonRadius
                color: btopMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText { anchors.centerIn: parent; text: "Open btop"; color: root.paper; font.family: root.barFont; font.pixelSize: 11 }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.batteryVisible = false; btopRunner.running = false; btopRunner.running = true }
                }
            }
        }
    }

    Process {
        id: batData
        command: ["bash", "-c", OmarchyPower.batteryDataCmd]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length >= 9) {
                    batPanel.batteryId = parts[0] || ""
                    batPanel.percent = parseInt(parts[1]) || 0
                    batPanel.status = parts[2] || "unknown"
                    batPanel.timeLabel = parts[3] || "Time left"
                    batPanel.timeText = parts[4] || ""
                    batPanel.powerRate = parts[5] || ""
                    batPanel.sizeText = parts[6] || ""
                    batPanel.healthText = parts[7] || ""
                    batPanel.cycles = parseInt(parts[8]) || 0
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: root.batteryVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: batPanel.refreshBatteryData()
    }

    Process { id: btopRunner; command: ["bash", "-c", "omarchy-launch-floating-terminal-with-presentation 'btop'"] }
}

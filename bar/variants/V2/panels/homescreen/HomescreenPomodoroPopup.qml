import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// ── POMODORO TIMER POPUP (Sleek Material You modal to view, pause, or disable the timer) ──
Item {
    id: pomodoroPopupBackdrop
    required property var dashboardContent
    required property var root

    z: 1000
    visible: opacity > 0.001
    opacity: dashboardContent.showPomodoroPopup ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 180 } }

    // Dimmer background (Clicking closes the popup)
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        MouseArea {
            anchors.fill: parent
            onClicked: dashboardContent.showPomodoroPopup = false
        }
    }

    // Pomodoro Card
    Rectangle {
        id: pomodoroCard
        anchors.centerIn: parent
        width: 310
        height: 220
        radius: 20
        color: Qt.rgba(root.paper.r * 0.92 + 0.04, root.paper.g * 0.92 + 0.04, root.paper.b * 0.92 + 0.04, 0.97)
        border.color: root.islandBorder
        border.width: 1

        scale: dashboardContent.showPomodoroPopup ? 1.0 : 0.92
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        // Prevent clicks inside card from closing
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header
            Item {
                width: parent.width
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "timer"
                        color: (root && root.timerActive) ? root.color03 : root.seal
                        font.pixelSize: 20
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Pomodoro Timer"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }

                // Close button
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        radius: 13
                        color: closePomoMa.containsMouse ? root.fillHover : "transparent"
                    }

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        color: root.ink
                        opacity: 0.7
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: closePomoMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dashboardContent.showPomodoroPopup = false
                    }
                }
            }

            // Countdown Display
            Column {
                width: parent.width
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!root || !root.timerActive) return "25:00"
                        let sec = root.timerRemaining || 0
                        let m = Math.floor(sec / 60)
                        let s = sec % 60
                        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
                    }
                    font.family: root.barFont
                    font.pixelSize: 36
                    font.weight: Font.Bold
                    color: (root && root.timerActive && !root.timerPaused) ? root.color03 : root.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        if (!root || !root.timerActive) return "Ready to focus"
                        if (root.timerPaused) return "Paused"
                        return (root.timerLabel || "Focus") + " • In Progress"
                    }
                    font.family: root.barFont
                    font.pixelSize: 12
                    color: root.ink
                    opacity: 0.65
                }
            }

            // Action Controls Row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                // Start / Resume / Pause button
                Rectangle {
                    height: 38
                    width: (root && root.timerActive) ? 124 : 160
                    radius: 19
                    color: (root && root.timerActive && !root.timerPaused) ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22) : root.seal
                    border.color: root.seal
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (!root || !root.timerActive || root.timerPaused) ? "play_arrow" : "pause"
                            color: (!root || !root.timerActive || root.timerPaused) ? root.paper : root.seal
                            font.pixelSize: 18
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (!root || !root.timerActive) ? "Start 25m" : (root.timerPaused ? "Resume" : "Pause")
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: (!root || !root.timerActive || root.timerPaused) ? root.paper : root.seal
                        }
                    }

                    MouseArea {
                        id: pStartMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root) {
                                if (!root.timerActive) root.startTimer(25, "Focus")
                                else root.toggleTimer()
                            }
                        }
                    }
                }

                // Disable / Reset button
                Rectangle {
                    visible: root && root.timerActive
                    height: 38
                    width: 124
                    radius: 19
                    color: Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.18)
                    border.color: root.color01
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "stop"
                            color: root.color01
                            font.pixelSize: 18
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Disable / Reset"
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.color01
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root) root.resetTimer()
                        }
                    }
                }
            }

            // Quick Presets (when timer is idle)
            Row {
                visible: !root || !root.timerActive
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Repeater {
                    model: [
                        { label: "25m Focus", mins: 25, type: "Focus" },
                        { label: "5m Break", mins: 5, type: "Short Break" },
                        { label: "15m Break", mins: 15, type: "Long Break" }
                    ]

                    Rectangle {
                        height: 26
                        width: chipTxt.implicitWidth + 16
                        radius: 13
                        color: chipMa.containsMouse ? root.fillHover : root.fillIdle

                        Text {
                            id: chipTxt
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: root.barFont
                            font.pixelSize: 11
                            color: root.ink
                            opacity: 0.85
                        }

                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root) root.startTimer(modelData.mins, modelData.type)
                            }
                        }
                    }
                }
            }
        }
    }
}

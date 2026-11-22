import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// ── DETACHED BOTTOM-LEFT POMODORO TIMER CARD (Collapsed on start, expands downward on hover) ──
Rectangle {
    id: pomoCard
    required property var dashboardContent
    required property var root
    property real bootProgress: 1.0

    readonly property bool isTimerActive: Boolean(root && root.timerActive)
    readonly property bool isTimerPaused: Boolean(root && root.timerPaused)
    readonly property int timerRemaining: (root && typeof root.timerRemaining === "number") ? root.timerRemaining : 0
    readonly property string timerLabel: (root && root.timerLabel) ? root.timerLabel : "Focus"
    readonly property bool isPomodoroVisible: isTimerActive || Boolean(dashboardContent && dashboardContent.showPomodoroPopup)
    readonly property bool isExpanded: cardHover.hovered

    // Track total duration for accurate progress ring
    property int totalSeconds: 1500
    onTimerRemainingChanged: {
        if (timerRemaining > totalSeconds) totalSeconds = timerRemaining
        if (!isTimerActive) totalSeconds = 1500
    }
    readonly property real progressRatio: (isTimerActive && totalSeconds > 0)
        ? Math.max(0, Math.min(1, 1.0 - (timerRemaining / totalSeconds)))
        : 0.0

    readonly property string formattedTime: {
        if (!isTimerActive) return "25:00"
        var m = Math.floor(timerRemaining / 60)
        var s = timerRemaining % 60
        return (m < 10 ? "0" + m : "" + m) + ":" + (s < 10 ? "0" + s : "" + s)
    }

    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#a3e635"
    readonly property color activeCol: (root && root.color03) ? root.color03 : sealCol
    readonly property color accentCol: isTimerActive ? activeCol : sealCol
    readonly property color onAccentCol: {
        var luma = accentCol.r * 0.299 + accentCol.g * 0.587 + accentCol.b * 0.114
        return luma > 0.55 ? "#121212" : "#ffffff"
    }
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "Google Sans"

    radius: isExpanded ? 24 : 18
    border.width: 0
    antialiasing: true
    color: Qt.rgba(
        paperCol.r * 0.78 + accentCol.r * 0.22,
        paperCol.g * 0.78 + accentCol.g * 0.22,
        paperCol.b * 0.78 + accentCol.b * 0.22,
        0.95
    )

    opacity: isPomodoroVisible ? bootProgress : 0.0
    scale: isPomodoroVisible ? 1.0 : 0.92
    visible: opacity > 0.01

    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
    Behavior on scale { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.002 } }
    Behavior on color { ColorAnimation { duration: 240 } }

    HoverHandler {
        id: cardHover
    }

    // ── COLLAPSED VIEW (Compact live timer pill card) ──
    Item {
        id: collapsedView
        anchors.fill: parent
        anchors.margins: 10
        opacity: pomoCard.isExpanded ? 0.0 : 1.0
        scale: pomoCard.isExpanded ? 0.96 : 1.0
        visible: opacity > 0.01
        enabled: !pomoCard.isExpanded

        Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
        Behavior on scale { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.002 } }

        // Left: Circular Progress Ring + Icon
        Item {
            id: collapsedRingBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            height: 50

            Canvas {
                id: ringCanvas
                anchors.fill: parent
                readonly property real prog: pomoCard.progressRatio
                readonly property color actC: pomoCard.accentCol
                readonly property color trkC: pomoCard.inkCol
                onProgChanged: requestPaint()
                onActCChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2
                    var cy = height / 2
                    var r = Math.min(cx, cy) - 4
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(trkC.r, trkC.g, trkC.b, 0.14)
                    ctx.lineWidth = 4
                    ctx.stroke()

                    if (prog > 0.005) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * prog)
                        ctx.strokeStyle = actC
                        ctx.lineWidth = 4
                        ctx.lineCap = "round"
                        ctx.stroke()
                    }
                }
            }

            IconText {
                anchors.centerIn: parent
                text: pomoCard.isTimerActive ? (pomoCard.isTimerPaused ? "pause" : "timer") : "hourglass_top"
                color: pomoCard.accentCol
                font.pixelSize: 20
            }
        }

        // Right: Countdown + Status
        Column {
            anchors.left: collapsedRingBox.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                text: pomoCard.formattedTime
                color: pomoCard.inkCol
                font.family: pomoCard.barFontFam
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            Text {
                width: parent.width
                text: !pomoCard.isTimerActive
                    ? "Ready to focus"
                    : (pomoCard.isTimerPaused ? (pomoCard.timerLabel + " · Paused") : (pomoCard.timerLabel + " · Running"))
                color: pomoCard.accentCol
                font.family: pomoCard.barFontFam
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    // ── EXPANDED VIEW (Full Pomodoro Controls on Hover) ──
    Item {
        id: expandedView
        anchors.fill: parent
        anchors.margins: 12
        opacity: pomoCard.isExpanded ? 1.0 : 0.0
        scale: pomoCard.isExpanded ? 1.0 : 0.96
        visible: opacity > 0.01
        enabled: pomoCard.isExpanded

        Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
        Behavior on scale { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.002 } }

        // Top Row: Label + Quick Presets (when idle) or Close button
        Item {
            id: topExpandedRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 28

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "timer"
                    color: pomoCard.accentCol
                    font.pixelSize: 16
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pomoCard.isTimerActive ? pomoCard.timerLabel : "Pomodoro"
                    color: pomoCard.inkCol
                    font.family: pomoCard.barFontFam
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: [
                        { label: "25m", mins: 25, type: "Focus" },
                        { label: "5m", mins: 5, type: "Short Break" },
                        { label: "15m", mins: 15, type: "Long Break" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        visible: !pomoCard.isTimerActive
                        height: 24
                        width: presetTxt.implicitWidth + 14
                        radius: 12
                        border.width: 0
                        color: presetMa.containsMouse
                            ? pomoCard.accentCol
                            : Qt.rgba(pomoCard.inkCol.r, pomoCard.inkCol.g, pomoCard.inkCol.b, 0.10)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SpringPress { pressScale: 0.90; pushReach: 80; pushDistance: 5 }

                        Text {
                            id: presetTxt
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: presetMa.containsMouse ? pomoCard.onAccentCol : pomoCard.inkCol
                            font.family: pomoCard.barFontFam
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }

                        MouseArea {
                            id: presetMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (pomoCard.root) {
                                    pomoCard.totalSeconds = parent.modelData.mins * 60
                                    pomoCard.root.startTimer(parent.modelData.mins, parent.modelData.type)
                                }
                                if (pomoCard.dashboardContent) pomoCard.dashboardContent.showPomodoroPopup = false
                            }
                        }
                    }
                }

                // Dismiss button when idle (not active)
                Rectangle {
                    visible: !pomoCard.isTimerActive
                    width: 24
                    height: 24
                    radius: 12
                    border.width: 0
                    color: closeMa.containsMouse
                        ? Qt.rgba(pomoCard.inkCol.r, pomoCard.inkCol.g, pomoCard.inkCol.b, 0.18)
                        : Qt.rgba(pomoCard.inkCol.r, pomoCard.inkCol.g, pomoCard.inkCol.b, 0.08)

                    SpringPress { pressScale: 0.88; pushReach: 60; pushDistance: 4 }

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        color: pomoCard.inkCol
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (pomoCard.dashboardContent) pomoCard.dashboardContent.showPomodoroPopup = false
                    }
                }
            }
        }

        // Bottom Row: Big Countdown on Left + Play/Pause & Reset on Right
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56

            Column {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: pomoCard.formattedTime
                    color: pomoCard.inkCol
                    font.family: pomoCard.barFontFam
                    font.pixelSize: 30
                    font.weight: Font.Bold
                }

                Text {
                    text: !pomoCard.isTimerActive
                        ? "Tap start for 25m focus"
                        : (pomoCard.isTimerPaused ? "Paused" : "Stay focused")
                    color: pomoCard.inkCol
                    opacity: 0.65
                    font.family: pomoCard.barFontFam
                    font.pixelSize: 11
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Play / Pause Morphing Pill
                Rectangle {
                    height: 36
                    width: pomoCard.isTimerActive ? 46 : 74
                    radius: (pomoCard.isTimerActive && !pomoCard.isTimerPaused) ? 12 : 18
                    border.width: 0
                    color: pomoCard.accentCol

                    Behavior on width { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.2 } }
                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }

                    SpringPress { pressScale: 0.90; pushReach: 90; pushDistance: 6 }

                    Row {
                        anchors.centerIn: parent
                        spacing: 4

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (!pomoCard.isTimerActive || pomoCard.isTimerPaused) ? "play_arrow" : "pause"
                            color: pomoCard.onAccentCol
                            font.pixelSize: 18
                        }

                        Text {
                            visible: !pomoCard.isTimerActive
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Start"
                            color: pomoCard.onAccentCol
                            font.family: pomoCard.barFontFam
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!pomoCard.root) return
                            if (!pomoCard.isTimerActive) {
                                pomoCard.totalSeconds = 1500
                                pomoCard.root.startTimer(25, "Focus")
                                if (pomoCard.dashboardContent) pomoCard.dashboardContent.showPomodoroPopup = false
                            } else {
                                pomoCard.root.toggleTimer()
                            }
                        }
                    }
                }

                // Stop / Reset Button
                Rectangle {
                    visible: pomoCard.isTimerActive
                    width: 36
                    height: 36
                    radius: 18
                    border.width: 0
                    color: stopMa.containsMouse
                        ? Qt.rgba(pomoCard.inkCol.r, pomoCard.inkCol.g, pomoCard.inkCol.b, 0.20)
                        : Qt.rgba(pomoCard.inkCol.r, pomoCard.inkCol.g, pomoCard.inkCol.b, 0.10)

                    SpringPress { pressScale: 0.88; pushReach: 80; pushDistance: 5 }

                    IconText {
                        anchors.centerIn: parent
                        text: "stop"
                        color: pomoCard.inkCol
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: stopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pomoCard.root) pomoCard.root.resetTimer()
                            if (pomoCard.dashboardContent) pomoCard.dashboardContent.showPomodoroPopup = false
                        }
                    }
                }
            }
        }
    }
}

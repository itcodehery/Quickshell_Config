import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "../modules"

// Docked status pill in the top-right corner of the screen.
// Integrates hardware privacy indicator dots (mic, camera, screen-share)
// and battery status (when media is playing) into a single cohesive pill,
// matching the dimensions and styling of the floating lyrics pill.
PanelWindow {
    id: privacyWin
    required property var root
    required property var targetScreen
    property var mprisPanel: null

    screen: targetScreen
    color: "transparent"

    anchors {
        top: root.barPosition === "top"
        bottom: root.barPosition === "bottom"
        right: true
    }
    margins {
        top: 4
        bottom: 4
        right: 14
    }

    readonly property real pillHeight: (root && root.pillH) ? root.pillH : 24
    readonly property real maxPillWidth: 260
    implicitWidth: maxPillWidth
    implicitHeight: root.v2BarHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-status-pill"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: pill }

    // Privacy sources
    readonly property bool hasPrivacy: root.privacyAnyActive
    readonly property var dots: {
        var list = []
        if (root.privacyMic) list.push({ key: "mic", color: "#F59E0B" })
        if (root.privacyCam) list.push({ key: "cam", color: "#10B981" })
        if (root.privacyScreen) list.push({ key: "screen", color: root.screenRecording ? "#EF4444" : "#3B82F6" })
        return list
    }

    // UPower battery data
    readonly property var dev: UPower.displayDevice
    readonly property bool hasBattery: (dev !== null && dev.isLaptopBattery) || (root && root.hasBattery)
    readonly property int percent: {
        if (!dev) return 0
        var p = dev.percentage
        return Math.round(p <= 1.0 ? p * 100 : p)
    }
    readonly property int devState: dev ? dev.state : UPowerDeviceState.Unknown
    readonly property bool charging: devState === UPowerDeviceState.Charging
    readonly property bool full:     devState === UPowerDeviceState.FullyCharged
    readonly property bool low:      hasBattery && !charging && !full && percent <= 20

    // Time estimate
    readonly property real timeToEmpty: dev ? dev.timeToEmpty : 0
    readonly property real timeToFull:  dev ? dev.timeToFull  : 0
    readonly property string timeText:  charging ? fmtDuration(timeToFull) : fmtDuration(timeToEmpty)
    function fmtDuration(s) {
        if (!s || s <= 0) return ""
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        return h > 0 ? (h + "h " + m + "m") : (m + "m")
    }

    readonly property string statusText:
        full ? "Full"
        : charging ? "Charging"
        : devState === UPowerDeviceState.Discharging ? "Discharging"
        : "On battery"
    readonly property string tooltipText: statusText + " · " + percent + "%"
                                          + (timeText ? " · " + timeText : "")

    // Media & visibility logic
    readonly property bool isMediaPlaying: mprisPanel && mprisPanel.active && (mprisPanel.playing || (mprisPanel.player && mprisPanel.player.playbackState === MprisPlaybackState.Playing))
    readonly property bool showBattery: isMediaPlaying && hasBattery
    readonly property bool showPrivacy: hasPrivacy && dots.length > 0
    readonly property bool shouldShow: showBattery || showPrivacy

    visible: shouldShow || (pill && pill.opacity > 0.01)

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        height: privacyWin.pillHeight
        radius: height / 2
        color: root.barBg

        readonly property real contentWidth: contentRow.implicitWidth
        width: Math.max(28, contentWidth + 20)

        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        opacity: privacyWin.shouldShow ? 1.0 : 0.0
        scale: privacyWin.shouldShow ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        readonly property color battColor: (privacyWin.charging || privacyWin.full) ? root.indigo : root.seal

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: (privacyWin.showBattery && privacyWin.showPrivacy) ? 8 : 0

            // Battery information (shown when media is playing)
            Row {
                id: battRow
                visible: privacyWin.showBattery
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Item {
                    id: batt
                    width: 19
                    height: 10
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property real ratio: Math.max(0, Math.min(1, privacyWin.percent / 100))

                    property real pulse: 1.0
                    opacity: privacyWin.low ? pulse : 1.0
                    SequentialAnimation {
                        running: privacyWin.visible && privacyWin.low
                        loops: Animation.Infinite
                        NumberAnimation { target: batt; property: "pulse"; from: 1.0; to: 0.3; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { target: batt; property: "pulse"; from: 0.3; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
                    }

                    Rectangle {
                        id: body
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 9
                        radius: 2.5
                        color: "transparent"
                        border.width: 1.2
                        border.color: pill.battColor
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Rectangle {
                            visible: privacyWin.charging
                            anchors.fill: parent
                            anchors.margins: 1.8
                            radius: 1.2
                            color: Qt.rgba(pill.battColor.r, pill.battColor.g, pill.battColor.b, 0.28)
                        }

                        Rectangle {
                            id: fill
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 1.8
                            width: Math.max(batt.ratio > 0 ? 1.5 : 0, (parent.width - 3.6) * batt.ratio)
                            radius: 1.2
                            clip: true
                            color: pill.battColor
                            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Rectangle {
                                visible: privacyWin.charging && !privacyWin.full
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 6
                                radius: parent.radius
                                color: Qt.rgba(1, 1, 1, 0.18)
                                property real pos: 0
                                x: (parent.width + width) * pos - width
                                SequentialAnimation on pos {
                                    running: privacyWin.charging && !privacyWin.full
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0; to: 1; duration: 1100; easing.type: Easing.InOutSine }
                                    PauseAnimation { duration: 500 }
                                }
                            }
                        }

                        Canvas {
                            id: bolt
                            visible: privacyWin.charging || privacyWin.full
                            anchors.centerIn: parent
                            width: 6
                            height: 8
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

                    Rectangle {
                        anchors.left: body.right
                        anchors.leftMargin: -0.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2.5
                        height: 5
                        radius: 1.2
                        color: pill.battColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: privacyWin.percent + "%"
                    color: pill.battColor
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // Privacy indicator dots (mic, camera, screen-share)
            Row {
                id: dotRow
                visible: privacyWin.showPrivacy
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: privacyWin.dots
                    delegate: Rectangle {
                        id: dot
                        required property var modelData
                        width: 8
                        height: 8
                        radius: 4
                        color: modelData.color

                        SequentialAnimation on opacity {
                            running: privacyWin.visible && privacyWin.showPrivacy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: privacyWin.showBattery
            cursorShape: privacyWin.showBattery ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (privacyWin.showBattery) {
                    if (root.dashboardExpanded) {
                        if (root.dashboardDetail === "battery") {
                            root.dashboardDetail = ""
                        } else {
                            root.dashboardDetail = "battery"
                        }
                    } else {
                        root.dashboardDetail = "battery"
                        root.dashboardExpanded = true
                    }
                }
            }
        }
    }
}

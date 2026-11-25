import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import "../../modules"
import "../../motion"

// Docked status pill in the top-right corner of the screen.
// Borderless live battery-fill progress pill + privacy indicator dots.
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
        top: root.isBarNotch ? 0 : 4
        bottom: root.isBarNotch ? 0 : 4
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

    readonly property real ratio: Math.max(0, Math.min(1, percent / 100.0))

    // Media & visibility logic
    readonly property bool isMediaActive: Boolean(mprisPanel && mprisPanel.active)
    readonly property bool showBattery: isMediaActive && hasBattery
    readonly property bool showPrivacy: hasPrivacy && dots.length > 0
    readonly property bool shouldShow: showBattery || showPrivacy

    visible: shouldShow || (pill && pill.opacity > 0.01)

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        height: privacyWin.pillHeight
        radius: height / 2
        border.width: 0
        color: root.isBarVignette ? "transparent" : root.barBg

        readonly property real contentWidth: contentRow.implicitWidth
        width: Math.max(32, contentWidth + 20)

        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        opacity: privacyWin.shouldShow ? 1.0 : 0.0
        scale: privacyWin.shouldShow ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        readonly property color battColor: privacyWin.low
            ? "#f87171"
            : ((privacyWin.charging || privacyWin.full) ? root.color03 : root.seal)

        // Live tonal battery level fill inside the pill (hidden in cardless vignette mode)
        ClippingRectangle {
            visible: privacyWin.showBattery && !root.isBarVignette
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * privacyWin.ratio
                color: pill.battColor
                opacity: privacyWin.charging ? 0.24 : 0.16
                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 220 } }
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: (privacyWin.showBattery && privacyWin.showPrivacy) ? 8 : 0

            // Borderless battery readout (bolt/icon + bold %)
            Row {
                id: battRow
                visible: privacyWin.showBattery
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: privacyWin.charging ? "battery_charging_full" : "bolt"
                    color: pill.battColor
                    font.pixelSize: 14
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: privacyWin.percent + "%"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
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
                        width: 7
                        height: 7
                        radius: 3.5
                        color: modelData.color

                        SequentialAnimation on opacity {
                            running: privacyWin.visible && privacyWin.showPrivacy
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
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

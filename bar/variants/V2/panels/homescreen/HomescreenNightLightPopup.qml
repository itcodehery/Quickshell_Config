import QtQuick
import ".."
import Quickshell
import "../../modules"
import "../../modules/common"
import "../../motion"

// ── NIGHT LIGHT INTENSITY POPUP ──
// Compact floating popup containing a smaller slider matching the dashboard slider design
Item {
    id: nightPopupRoot
    required property var dashboardContent
    required property var root

    z: 1050
    anchors.fill: parent
    visible: opacity > 0.001
    opacity: dashboardContent.showNightLightPopup ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // Backdrop click dismisses the popup
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: dashboardContent.showNightLightPopup = false
    }

    // Debounce timer for smooth dragging updates
    Timer {
        id: liveSunsetDebounce
        interval: 60
        repeat: false
        onTriggered: {
            if (dashboardContent && typeof dashboardContent.applyNightTemperature === "function") {
                dashboardContent.applyNightTemperature(nightSlider.localValue)
            }
        }
    }

    // Small Floating Card
    Rectangle {
        id: popupCard
        width: 246
        height: 82
        radius: 18

        // Coordinate positioning with clamping to keep it fully on-screen
        readonly property real desiredX: dashboardContent.nightPopupTargetX - width / 2
        readonly property real clampedX: Math.max(12, Math.min(dashboardContent.width - width - 12, desiredX))

        readonly property bool placeAbove: (dashboardContent.nightPopupTargetY + height + 10) > dashboardContent.height
        readonly property real clampedY: placeAbove
            ? Math.max(10, dashboardContent.nightPopupTargetY - height - 8)
            : Math.max(10, Math.min(dashboardContent.height - height - 10, dashboardContent.nightPopupTargetY + 8))

        x: clampedX
        y: clampedY

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        scale: dashboardContent.showNightLightPopup ? 1.0 : 0.88
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }

        color: Qt.rgba(root.barBg.r, root.barBg.g, root.barBg.b, 0.98)
        border.color: "transparent"
        border.width: 0

        // Consume mouse events inside card
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {}
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── Header Row ──
            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "nightlight_round"
                        color: dashboardContent.nightLightIntensity > 0 ? (root.color03 || root.seal) : root.ink
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Night Light"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: dashboardContent.nightLightIntensity > 0
                            ? (Math.round(6000 - (dashboardContent.nightLightIntensity / 100) * 3800) + "K • " + Math.round(dashboardContent.nightLightIntensity) + "%")
                            : "Off"
                        color: dashboardContent.nightLightIntensity > 0 ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    // Quick Close icon button
                    Item {
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 9
                            color: closeMa.containsMouse ? root.fillHover : "transparent"
                        }

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.ink
                            opacity: 0.6
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: dashboardContent.showNightLightPopup = false
                        }
                    }
                }
            }

            // ── Small Slider Container (Matching Dashboard Slider Design) ──
            Item {
                id: nightSlider
                width: parent.width
                height: 30

                property bool sliding: false
                property int localValue: dashboardContent.nightLightIntensity
                readonly property real effectiveVal: sliding ? localValue : dashboardContent.nightLightIntensity

                Connections {
                    target: dashboardContent
                    function onNightLightIntensityChanged() {
                        if (!nightSlider.sliding) nightSlider.localValue = dashboardContent.nightLightIntensity
                    }
                }

                // Night Light Warmth Icon on Left
                IconText {
                    id: nightIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "bedtime"
                    color: root.ink
                    font.pixelSize: 16
                }

                // Value indicator (visible when sliding)
                Text {
                    anchors.left: nightIcon.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(nightSlider.effectiveVal) + "%"
                    color: root.ink
                    font.pixelSize: 10
                    font.family: root.barFont
                    font.weight: Font.DemiBold
                    opacity: nightSlider.sliding ? 0.9 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Slider Track Item
                Item {
                    id: nightTrack
                    anchors.left: nightIcon.right
                    anchors.leftMargin: nightSlider.sliding ? 32 : 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    StyledSliderTrack {
                        anchors.fill: parent
                        root: nightPopupRoot.root
                        value: nightSlider.effectiveVal
                        sliding: nightSlider.sliding
                        accentColor: root.seal
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    function updateFromPos(mouseX) {
                        let relX = mouseX - nightTrack.x
                        let pct = Math.max(0, Math.min(100, Math.round((relX / Math.max(1, nightTrack.width)) * 100)))
                        nightSlider.localValue = pct
                        liveSunsetDebounce.restart()
                        return pct
                    }

                    onPressed: (mouse) => {
                        nightSlider.sliding = true
                        updateFromPos(mouse.x)
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) updateFromPos(mouse.x)
                    }
                    onReleased: (mouse) => {
                        let pct = updateFromPos(mouse.x)
                        nightSlider.sliding = false
                        liveSunsetDebounce.stop()
                        dashboardContent.setNightIntensity(pct)
                    }
                }
            }
        }
    }
}

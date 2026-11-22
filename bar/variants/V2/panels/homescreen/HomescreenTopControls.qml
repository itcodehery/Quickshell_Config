import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../modules/common"
import "../../motion"

Item {
    id: topControlArea
    required property var dashboardContent
    required property var root
    required property var audioData

    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#22d3ee"
    readonly property color color01Col: (root && root.color01) ? root.color01 : "#f59e0b"
    readonly property color color03Col: (root && root.color03) ? root.color03 : "#10b981"
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "Google Sans"

    // ── SLIDERS (Original StyledSliderTrack paired with M3E Morphing Orbs) ──
    Column {
        id: slidersCol
        anchors.fill: parent
        spacing: 10
        visible: opacity > 0.001
        opacity: dashboardContent.editTilesMode ? 0.0 : 1.0
        Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }

        // ── Brightness Row ──
        Row {
            width: parent.width
            height: 36
            spacing: 12

            // Brightness Slider Container
            Item {
                id: briSlider
                width: parent.width - 36 - 12
                height: 36

                property bool sliding: false
                property int localValue: dashboardContent.currentBrightness
                readonly property real effectiveVal: sliding ? localValue : dashboardContent.currentBrightness

                // Left Brightness Orb (matches HUD orbs below)
                Rectangle {
                    id: briIconWrap
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36
                    radius: 18
                    border.width: 0
                    antialiasing: true
                    color: Qt.rgba(topControlArea.inkCol.r, topControlArea.inkCol.g, topControlArea.inkCol.b, 0.08)

                    IconText {
                        anchors.centerIn: parent
                        text: "light_mode"
                        color: topControlArea.sealCol
                        font.pixelSize: 18
                    }
                }

                // Value indicator (visible when sliding)
                Text {
                    anchors.left: briIconWrap.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(briSlider.effectiveVal) + "%"
                    color: topControlArea.inkCol
                    font.pixelSize: 11
                    font.family: topControlArea.barFontFam
                    font.weight: Font.DemiBold
                    opacity: briSlider.sliding ? 0.9 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
                }

                // Slider Track Item (original StyledSliderTrack)
                Item {
                    id: briTrack
                    anchors.left: briIconWrap.right
                    anchors.leftMargin: briSlider.sliding ? 40 : 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    Behavior on anchors.leftMargin { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.5 } }

                    StyledSliderTrack {
                        anchors.fill: parent
                        root: topControlArea.root
                        value: briSlider.effectiveVal
                        sliding: briSlider.sliding
                        accentColor: topControlArea.sealCol
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    function updateFromPos(mouseX) {
                        let relX = mouseX - briTrack.x
                        let pct = Math.max(0, Math.min(100, Math.round((relX / Math.max(1, briTrack.width)) * 100)))
                        briSlider.localValue = pct
                        return pct
                    }

                    onPressed: (mouse) => {
                        briSlider.sliding = true
                        updateFromPos(mouse.x)
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) updateFromPos(mouse.x)
                    }
                    onReleased: (mouse) => {
                        let pct = updateFromPos(mouse.x)
                        briSlider.sliding = false
                        dashboardContent.currentBrightness = pct
                        Quickshell.execDetached(["bash", "-c", "brightnessctl set " + pct + "%"])
                    }
                }
            }

            // Night Light Morphing Orb (36x36)
            Rectangle {
                id: localNightToggle
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36
                readonly property int mode: dashboardContent.nightMode
                radius: mode > 0 ? 18 : (localNightMa.containsMouse ? 14 : 12)
                border.width: 0
                antialiasing: true

                color: mode === 2
                    ? topControlArea.color01Col
                    : (mode === 1 ? topControlArea.color03Col : Qt.rgba(topControlArea.inkCol.r, topControlArea.inkCol.g, topControlArea.inkCol.b, localNightMa.containsMouse ? 0.16 : 0.08))

                Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                Behavior on color { ColorAnimation { duration: 180 } }

                SpringPress { pressScale: 0.84; pushReach: 100; pushDistance: 6 }

                IconText {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    text: "nightlight_round"
                    color: localNightToggle.mode > 0 ? topControlArea.paperCol : topControlArea.inkCol
                    opacity: localNightToggle.mode > 0 ? 1.0 : 0.72
                    font.pixelSize: 16
                }

                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 5
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Rectangle {
                        width: 5; height: 2.5; radius: 1.25
                        color: localNightToggle.mode > 0 ? topControlArea.paperCol : topControlArea.inkCol
                        opacity: localNightToggle.mode >= 1 ? 0.95 : 0.28
                    }
                    Rectangle {
                        width: 5; height: 2.5; radius: 1.25
                        color: localNightToggle.mode > 0 ? topControlArea.paperCol : topControlArea.inkCol
                        opacity: localNightToggle.mode === 2 ? 0.95 : 0.28
                    }
                }

                MouseArea {
                    id: localNightMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            let pt = localNightToggle.mapToItem(dashboardContent, 0, localNightToggle.height)
                            dashboardContent.toggleNightLightPopup(pt.x + localNightToggle.width / 2, pt.y)
                        } else {
                            dashboardContent.cycleNightMode()
                        }
                    }
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0) {
                            if (dashboardContent.nightMode < 2) dashboardContent.setNightMode(dashboardContent.nightMode + 1)
                        } else if (wheel.angleDelta.y < 0) {
                            if (dashboardContent.nightMode > 0) dashboardContent.setNightMode(dashboardContent.nightMode - 1)
                        }
                    }
                }
            }
        }

        // ── Audio / Volume Row ──
        Row {
            width: parent.width
            height: 36
            spacing: 12

            // Audio Slider Container
            Item {
                id: audSlider
                width: parent.width - 36 - 12
                height: 36

                property bool sliding: false
                property int localValue: audioData.volume
                readonly property real effectiveVal: sliding ? localValue : audioData.volume

                // Left Speaker Mute Orb (matches HUD orbs below)
                Rectangle {
                    id: audIconWrap
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 36
                    radius: audioData.muted ? 12 : 18
                    border.width: 0
                    antialiasing: true
                    color: audioData.muted
                        ? topControlArea.color01Col
                        : Qt.rgba(topControlArea.inkCol.r, topControlArea.inkCol.g, topControlArea.inkCol.b, muteMa.containsMouse ? 0.16 : 0.08)

                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 160 } }

                    SpringPress { pressScale: 0.84; pushReach: 100; pushDistance: 6 }

                    IconText {
                        anchors.centerIn: parent
                        text: audioData.muted ? "volume_off" : (audSlider.effectiveVal > 50 ? "volume_up" : (audSlider.effectiveVal > 0 ? "volume_down" : "volume_mute"))
                        color: audioData.muted ? "#121212" : topControlArea.sealCol
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: muteMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                    }
                }

                // Value indicator (visible when sliding)
                Text {
                    anchors.left: audIconWrap.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(audSlider.effectiveVal) + "%"
                    color: topControlArea.inkCol
                    font.pixelSize: 11
                    font.family: topControlArea.barFontFam
                    font.weight: Font.DemiBold
                    opacity: audSlider.sliding ? 0.9 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { SpringAnimation { spring: Motion.effectsSpring; damping: Motion.effectsDamping; epsilon: 0.01 } }
                }

                // Slider Track Item (original StyledSliderTrack)
                Item {
                    id: audTrack
                    anchors.left: audIconWrap.right
                    anchors.leftMargin: audSlider.sliding ? 40 : 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    Behavior on anchors.leftMargin { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.5 } }

                    StyledSliderTrack {
                        anchors.fill: parent
                        root: topControlArea.root
                        value: audSlider.effectiveVal
                        sliding: audSlider.sliding
                        accentColor: audioData.muted ? root.fillHover : topControlArea.sealCol
                        unfilledColor: audioData.muted ? root.fillIdle : (root.isLightMode ? Qt.rgba(topControlArea.inkCol.r, topControlArea.inkCol.g, topControlArea.inkCol.b, 0.08) : Qt.rgba(topControlArea.sealCol.r, topControlArea.sealCol.g, topControlArea.sealCol.b, 0.25))
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    function updateFromPos(mouseX) {
                        let relX = mouseX - audTrack.x
                        let pct = Math.max(0, Math.min(100, Math.round((relX / Math.max(1, audTrack.width)) * 100)))
                        audSlider.localValue = pct
                        return pct
                    }

                    onPressed: (mouse) => {
                        audSlider.sliding = true
                        updateFromPos(mouse.x)
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) updateFromPos(mouse.x)
                    }
                    onReleased: (mouse) => {
                        let pct = updateFromPos(mouse.x)
                        audSlider.sliding = false
                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%"])
                    }
                }
            }

            // Audio Settings / Detail Orb (36x36)
            Rectangle {
                id: audSettingsToggle
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36
                readonly property bool isSel: dashboardContent.activeDetailView === "volume"
                radius: isSel ? 18 : (audTuneMa.containsMouse ? 14 : 12)
                border.width: 0
                antialiasing: true
                color: isSel
                    ? topControlArea.sealCol
                    : Qt.rgba(topControlArea.inkCol.r, topControlArea.inkCol.g, topControlArea.inkCol.b, audTuneMa.containsMouse ? 0.16 : 0.08)

                Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                Behavior on color { ColorAnimation { duration: 160 } }

                SpringPress { pressScale: 0.84; pushReach: 100; pushDistance: 6 }

                IconText {
                    anchors.centerIn: parent
                    text: "tune"
                    color: audSettingsToggle.isSel ? topControlArea.paperCol : topControlArea.inkCol
                    font.pixelSize: 16
                }

                MouseArea {
                    id: audTuneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (dashboardContent.activeDetailView === "volume") {
                            dashboardContent.activeDetailView = ""
                            if (root) root.dashboardDetail = ""
                        } else {
                            dashboardContent.activeDetailView = "volume"
                            if (root) root.dashboardDetail = "volume"
                        }
                    }
                }
            }
        }
    }
}

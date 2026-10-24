import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

// Dedicated docked lyrics pill anchored to the top-left (or bottom-left) of the screen.
// Matches the exact height and vertical alignment of the inner clock pill in the bar (pillH: 24px).
// Window width is fixed to 480 to avoid Wayland buffer reconfiguration stutters during playback.
// The pill animates internally at full display refresh rate, and `mask` passes clicks outside the pill through.
PanelWindow {
    id: lyricsPanel
    required property var root
    required property var mprisPanel

    screen: root.activePopupScreen
    color: "transparent"

    anchors {
        top: root.barPosition === "top"
        bottom: root.barPosition === "bottom"
        left: true
    }
    margins {
        top: 4
        bottom: 4
        left: 14
    }

    readonly property real pillHeight: (root && root.pillH) ? root.pillH : 24
    readonly property real maxPillWidth: 460
    implicitWidth: maxPillWidth + 20
    implicitHeight: root.v2BarHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-lyrics-pill"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: lyricsPill }

    visible: mprisPanel && mprisPanel.showingLyrics && mprisPanel.active

    readonly property bool hasLyrics: mprisPanel && mprisPanel.lyricsTrackId !== "" && mprisPanel.lyricsTrackId === mprisPanel.currentTrackId && mprisPanel.lyricsList && mprisPanel.lyricsList.length > 0

    readonly property string targetLyricText: {
        if (hasLyrics && mprisPanel.currentLyricIndex >= 0 && mprisPanel.currentLyricIndex < mprisPanel.lyricsList.length) {
            return mprisPanel.lyricsList[mprisPanel.currentLyricIndex].text
        }
        if (hasLyrics) return "..."
        if (mprisPanel && mprisPanel._isFetchingLyrics) return "Searching lyrics…"
        return "No lyrics found"
    }

    Rectangle {
        id: lyricsPill
        anchors.verticalCenter: parent.verticalCenter
        height: lyricsPanel.pillHeight
        radius: height / 2
        color: root.barBg

        readonly property real activeTextWidth: textSwitcher.useB ? textB.implicitWidth : textA.implicitWidth
        width: Math.min(lyricsPanel.maxPillWidth, Math.max(50, activeTextWidth + 38))

        Behavior on width {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        opacity: (mprisPanel && mprisPanel.showingLyrics && mprisPanel.active) ? 1.0 : 0.0
        scale: (mprisPanel && mprisPanel.showingLyrics && mprisPanel.active) ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 9
            spacing: 6

            IconText {
                id: musicIcon
                text: "music_note"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                color: root.seal
            }

            // Dual-buffered text container for butter-smooth lyrics transitions
            Item {
                id: textSwitcher
                width: Math.min(380, Math.max(10, textSwitcher.useB ? textB.implicitWidth : textA.implicitWidth))
                height: lyricsPill.height
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Behavior on width {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                property bool useB: false
                property string currentShownText: ""
                property int lastLyricIndex: -1
                property bool initialized: false

                function transitionTo(newText, force) {
                    if (!force && newText === currentShownText) return
                    currentShownText = newText

                    var curIdx = (lyricsPanel.hasLyrics && mprisPanel) ? mprisPanel.currentLyricIndex : -1
                    var movingBackwards = lyricsPanel.hasLyrics && (curIdx >= 0) && (lastLyricIndex >= 0) && (curIdx < lastLyricIndex)
                    if (lyricsPanel.hasLyrics && curIdx >= 0) lastLyricIndex = curIdx
                    else lastLyricIndex = -1

                    var dir = movingBackwards ? -1 : 1
                    var enterY = 6 * dir
                    var exitY = -6 * dir

                    animSwitch.stop()

                    if (!useB) {
                        textB.text = newText
                        transB.y = enterY
                        textB.opacity = 0.0
                        textB.scale = 0.98

                        animExitTrans.target = transA
                        animExitTrans.to = exitY
                        animExitOpacity.target = textA
                        animExitScale.target = textA

                        animEnterTrans.target = transB
                        animEnterTrans.to = 0
                        animEnterOpacity.target = textB
                        animEnterScale.target = textB

                        useB = true
                    } else {
                        textA.text = newText
                        transA.y = enterY
                        textA.opacity = 0.0
                        textA.scale = 0.98

                        animExitTrans.target = transB
                        animExitTrans.to = exitY
                        animExitOpacity.target = textB
                        animExitScale.target = textB

                        animEnterTrans.target = transA
                        animEnterTrans.to = 0
                        animEnterOpacity.target = textA
                        animEnterScale.target = textA

                        useB = false
                    }

                    animSwitch.restart()
                }

                ParallelAnimation {
                    id: animSwitch

                    NumberAnimation {
                        id: animExitTrans
                        property: "y"
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        id: animExitOpacity
                        property: "opacity"
                        to: 0.0
                        duration: 160
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        id: animExitScale
                        property: "scale"
                        to: 0.97
                        duration: 180
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        id: animEnterTrans
                        property: "y"
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        id: animEnterOpacity
                        property: "opacity"
                        to: 1.0
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        id: animEnterScale
                        property: "scale"
                        to: 1.0
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                UiText {
                    id: textA
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 380)
                    transform: Translate { id: transA }
                }

                UiText {
                    id: textB
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 380)
                    transform: Translate { id: transB }
                }

                Connections {
                    target: lyricsPanel
                    function onTargetLyricTextChanged() {
                        if (!textSwitcher.initialized) return
                        textSwitcher.transitionTo(lyricsPanel.targetLyricText, false)
                    }
                }

                Connections {
                    target: mprisPanel ? mprisPanel : null
                    function onCurrentLyricIndexChanged() {
                        if (!textSwitcher.initialized || !lyricsPanel.hasLyrics) return
                        textSwitcher.transitionTo(lyricsPanel.targetLyricText, true)
                    }
                }

                Component.onCompleted: {
                    var initText = lyricsPanel.targetLyricText
                    currentShownText = initText
                    textA.text = initText
                    textA.opacity = 1.0
                    textA.scale = 1.0
                    transA.y = 0
                    textB.text = ""
                    textB.opacity = 0.0
                    textB.scale = 0.98
                    transB.y = 6
                    useB = false
                    if (lyricsPanel.hasLyrics && mprisPanel) lastLyricIndex = mprisPanel.currentLyricIndex
                    initialized = true
                }
            }
        }
    }
}

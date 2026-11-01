import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell.Hyprland
import "../modules"

Item {
    id: collapsedRoot
    required property var barSlot
    required property var island
    anchors.fill: parent

    property alias centerRowItem: centerRowItem
    property alias islandCollapsedItem: islandCollapsedItem
    property alias islandCollapsedRightSlot: islandCollapsedRightSlot
    property alias islandTimerItem: islandTimerItem

    BarSlotRow {
        id: centerRowItem
        barSlot: collapsedRoot.barSlot
        island: collapsedRoot.island
        height: 24
        anchors.verticalCenter: parent.verticalCenter
        x: collapsedRoot.island.fitPadding
        rmodel: collapsedRoot.barSlot.centerModel
        baseCount: collapsedRoot.barSlot.centerBaseSlotCount
        maxExtraCount: collapsedRoot.barSlot.centerExtraSlotLimit
        visible: opacity > 0.001
        opacity: collapsedRoot.island.islandCollapsedOpacity * (1.0 - collapsedRoot.island.overlayProgress)
    }

    Rectangle {
        id: islandCollapsedItem
        anchors.verticalCenter: parent.verticalCenter
        x: centerRowItem.x + centerRowItem.implicitWidth + 4
        
        readonly property bool mediaActive: collapsedRoot.barSlot.mprisPanel && collapsedRoot.barSlot.mprisPanel.active
        readonly property bool hasLyrics: (!collapsedRoot.barSlot.mprisPanel || !collapsedRoot.barSlot.mprisPanel.showingLyrics) && mediaActive && collapsedRoot.barSlot.mprisPanel.lyricsTrackId !== "" && collapsedRoot.barSlot.mprisPanel.lyricsTrackId === collapsedRoot.barSlot.mprisPanel.currentTrackId && collapsedRoot.barSlot.mprisPanel.lyricsList && collapsedRoot.barSlot.mprisPanel.lyricsList.length > 0 && collapsedRoot.barSlot.mprisPanel.currentLyricIndex >= 0
        readonly property string lyricText: hasLyrics ? collapsedRoot.barSlot.mprisPanel.lyricsList[collapsedRoot.barSlot.mprisPanel.currentLyricIndex].text : ""
        
        readonly property string windowTitle: Hyprland && Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
        
        readonly property string displayText: hasLyrics ? lyricText : (windowTitle !== "" ? windowTitle : "Desktop")
        readonly property real maxTextWidth: hasLyrics ? (collapsedRoot.barSlot.width - 120) : 350
        
        property string currentShownText: ""
        property int lastLyricIndex: -1
        property bool useB: false

        readonly property real activeTextWidth: useB ? textB.implicitWidth : textA.implicitWidth
        readonly property real visibleWidth: Math.min(Math.max(activeTextWidth + 20, 56), maxTextWidth + 20)
        width: visibleWidth
        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
        height: 24
        radius: height / 2
        color: "transparent"
        clip: true
        opacity: collapsedRoot.island.islandCollapsedOpacity * (1.0 - collapsedRoot.island.overlayProgress)
        visible: opacity > 0.001

        property bool initialized: false

        function transitionTo(newText, force) {
            if (!force && newText === currentShownText) return
            currentShownText = newText

            var curIdx = (hasLyrics && collapsedRoot.barSlot.mprisPanel) ? collapsedRoot.barSlot.mprisPanel.currentLyricIndex : -1
            var movingBackwards = hasLyrics && (curIdx >= 0) && (lastLyricIndex >= 0) && (curIdx < lastLyricIndex)
            if (hasLyrics && curIdx >= 0) {
                lastLyricIndex = curIdx
            } else {
                lastLyricIndex = -1
            }

            // Vertical drift direction: +1 scrolls down-to-up, -1 scrolls up-to-down
            var dir = movingBackwards ? -1 : 1
            var enterY = 7 * dir
            var exitY = -7 * dir

            animSwitch.stop()

            if (!useB) {
                // Switch to B
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
                // Switch to A
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

            // Exit animation (fast fade out & subtle drift)
            NumberAnimation {
                id: animExitTrans
                property: "y"
                duration: 170
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
                duration: 170
                easing.type: Easing.OutQuad
            }

            // Enter animation (smooth glide & crisp fade in)
            NumberAnimation {
                id: animEnterTrans
                property: "y"
                duration: 230
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: animEnterOpacity
                property: "opacity"
                to: 1.0
                duration: 210
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: animEnterScale
                property: "scale"
                to: 1.0
                duration: 230
                easing.type: Easing.OutCubic
            }
        }

        onDisplayTextChanged: {
            if (!islandCollapsedItem.initialized) return
            if (islandCollapsedItem.displayText !== islandCollapsedItem.currentShownText) {
                islandCollapsedItem.transitionTo(islandCollapsedItem.displayText, false)
            }
        }

        Connections {
            target: collapsedRoot.barSlot.mprisPanel ? collapsedRoot.barSlot.mprisPanel : null
            function onCurrentLyricIndexChanged() {
                if (!islandCollapsedItem.initialized || !islandCollapsedItem.hasLyrics) return
                var idx = collapsedRoot.barSlot.mprisPanel.currentLyricIndex
                if (idx === islandCollapsedItem.lastLyricIndex) return
                islandCollapsedItem.transitionTo(islandCollapsedItem.displayText, true)
            }
        }

        Component.onCompleted: {
            currentShownText = displayText
            textA.text = displayText
            textA.opacity = 1.0
            textA.scale = 1.0
            transA.y = 0
            textB.text = ""
            textB.opacity = 0.0
            textB.scale = 0.98
            transB.y = 7
            useB = false
            if (hasLyrics && collapsedRoot.barSlot.mprisPanel) {
                lastLyricIndex = collapsedRoot.barSlot.mprisPanel.currentLyricIndex
            }
            initialized = true
        }

        Text {
            id: textA
            anchors.centerIn: parent
            text: ""
            color: collapsedRoot.barSlot.root.ink
            font.family: collapsedRoot.barSlot.root.barFont || "Genova"
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: islandCollapsedItem.hasLyrics ? Text.ElideNone : Text.ElideRight
            width: Math.min(implicitWidth, islandCollapsedItem.maxTextWidth)
            transform: Translate { id: transA; y: 0 }
        }

        Text {
            id: textB
            anchors.centerIn: parent
            text: ""
            color: collapsedRoot.barSlot.root.ink
            font.family: collapsedRoot.barSlot.root.barFont || "Genova"
            font.pixelSize: 12
            font.weight: Font.Medium
            elide: islandCollapsedItem.hasLyrics ? Text.ElideNone : Text.ElideRight
            width: Math.min(implicitWidth, islandCollapsedItem.maxTextWidth)
            opacity: 0.0
            transform: Translate { id: transB; y: 7 }
        }
    }
    ListModel {
        id: islandMediaModel
        ListElement { gid: "G9"; type: "widget"; extra: false }
    }

    ListModel {
        id: islandBatteryModel
        ListElement { gid: "G12"; type: "widget"; extra: false }
    }

    BarSlotRow {
        id: islandCollapsedRightSlot
        barSlot: collapsedRoot.barSlot
        island: collapsedRoot.island
        anchors.verticalCenter: parent.verticalCenter
        x: islandCollapsedItem.x + islandCollapsedItem.width + (islandCollapsedRightSlot.width > 0 ? 4 : 0)
        visible: opacity > 0.001
        opacity: collapsedRoot.island.islandCollapsedOpacity * (1.0 - collapsedRoot.island.overlayProgress)
        rmodel: islandCollapsedItem.mediaActive ? islandMediaModel : islandBatteryModel
        baseCount: 1
        maxExtraCount: 0
    }

    Rectangle {
        id: islandTimerItem
        anchors.verticalCenter: parent.verticalCenter
        x: islandCollapsedRightSlot.x + islandCollapsedRightSlot.width + (islandTimerItem.width > 0 ? 4 : 0)

        readonly property bool active: collapsedRoot.barSlot.root.timerActive && !islandCollapsedItem.mediaActive
        readonly property real targetWidth: active ? (timerRow.implicitWidth + 14) : 0
        width: targetWidth
        Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        height: 24
        radius: height / 2
        color: Qt.rgba(collapsedRoot.barSlot.accent.r, collapsedRoot.barSlot.accent.g, collapsedRoot.barSlot.accent.b, 0.14)
        border.color: Qt.rgba(collapsedRoot.barSlot.accent.r, collapsedRoot.barSlot.accent.g, collapsedRoot.barSlot.accent.b, 0.32)
        border.width: 1
        clip: true
        opacity: (active ? 1.0 : 0.0) * collapsedRoot.island.islandCollapsedOpacity * (1.0 - collapsedRoot.island.overlayProgress)
        visible: opacity > 0.001

        Row {
            id: timerRow
            anchors.centerIn: parent
            spacing: 5

            Item {
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: Qt.rgba(collapsedRoot.barSlot.root.ink.r, collapsedRoot.barSlot.root.ink.g, collapsedRoot.barSlot.root.ink.b, 0.22)
                    border.width: 1.5
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: collapsedRoot.barSlot.root.timerPaused ? Qt.rgba(collapsedRoot.barSlot.root.ink.r, collapsedRoot.barSlot.root.ink.g, collapsedRoot.barSlot.root.ink.b, 0.45) : collapsedRoot.barSlot.accent
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: 7
                            centerY: 7
                            radiusX: 5.75
                            radiusY: 5.75
                            startAngle: -90
                            sweepAngle: {
                                if (collapsedRoot.barSlot.root.timerMode === "stopwatch") {
                                    return ((collapsedRoot.barSlot.root.timerRemaining % 60) / 60.0) * 360
                                }
                                var init = Math.max(1, collapsedRoot.barSlot.root.timerInitial)
                                var rem = Math.max(0, collapsedRoot.barSlot.root.timerRemaining)
                                return (1.0 - (rem / init)) * 360
                            }
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var sec = collapsedRoot.barSlot.root.timerRemaining
                    var h = Math.floor(sec / 3600)
                    var m = Math.floor((sec % 3600) / 60)
                    var s = sec % 60
                    function pad(n) { return n < 10 ? "0" + n : String(n) }
                    return h > 0 ? (h + ":" + pad(m) + ":" + pad(s)) : (pad(m) + ":" + pad(s))
                }
                font.family: "Genova"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: collapsedRoot.barSlot.root.timerPaused ? Qt.rgba(collapsedRoot.barSlot.root.ink.r, collapsedRoot.barSlot.root.ink.g, collapsedRoot.barSlot.root.ink.b, 0.6) : collapsedRoot.barSlot.accent
            }
        }

        TooltipMixin {
            id: timerTip
            root: collapsedRoot.barSlot.root
            owner: islandTimerItem
            text: collapsedRoot.barSlot.root.timerLabel + " · " + (collapsedRoot.barSlot.root.timerPaused ? "Paused" : "Running") + "\nLeft-click: Pause/Resume · Right-click: Reset"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: timerTip.show()
            onExited: timerTip.hide()
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    collapsedRoot.barSlot.root.resetTimer()
                } else {
                    collapsedRoot.barSlot.root.toggleTimer()
                }
            }
        }
    }
}

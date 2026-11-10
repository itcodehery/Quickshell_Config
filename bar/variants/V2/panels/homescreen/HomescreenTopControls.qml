import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

Item {
    id: topControlArea
    required property var dashboardContent
    required property var root
    required property var audioData

    // --- SLIDERS (Thinner bar with taller drag line matching reference design) ---
    Column {
        id: slidersCol
        anchors.fill: parent
        spacing: 10
        visible: opacity > 0.001
        opacity: dashboardContent.editTilesMode ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    
        // ── Brightness Row ──
        Row {
            width: parent.width
            height: 38
            spacing: 10
            
            // Brightness Slider Container
            Item {
                id: briSlider
                width: parent.width - 38 - 10
                height: 38
                
                property bool sliding: false
                property int localValue: dashboardContent.currentBrightness
                readonly property real effectiveVal: sliding ? localValue : dashboardContent.currentBrightness
                
                // Brightness Icon on Left
                IconText {
                    id: briIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "light_mode"
                    color: root.ink
                    font.pixelSize: 20
                }
                
                // Value indicator (visible when sliding)
                Text {
                    anchors.left: briIcon.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(briSlider.effectiveVal) + "%"
                    color: root.ink
                    font.pixelSize: 11
                    font.family: root.barFont
                    font.weight: Font.DemiBold
                    opacity: briSlider.sliding ? 0.9 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Slider Track Item
                Item {
                    id: briTrack
                    anchors.left: briIcon.right
                    anchors.leftMargin: briSlider.sliding ? 36 : 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    readonly property real trackW: width
                    readonly property real handleX: Math.round((Math.max(0, Math.min(100, briSlider.effectiveVal)) / 100) * Math.max(1, trackW - 4))
                    readonly property real gap: 4
                    readonly property real barHeight: 14

                    // Filled Track (Left of drag line)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, briTrack.handleX - briTrack.gap)
                        height: briTrack.barHeight
                        radius: briTrack.barHeight / 2
                        color: root.seal
                        Behavior on width { enabled: !briSlider.sliding; NumberAnimation { duration: 120 } }
                    }

                    // Unfilled Track (Right of drag line)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.min(briTrack.trackW, briTrack.handleX + 4 + briTrack.gap)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: briTrack.barHeight
                        radius: briTrack.barHeight / 2
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                        Behavior on anchors.leftMargin { enabled: !briSlider.sliding; NumberAnimation { duration: 120 } }
                    }

                    // Vertical Drag Line (Taller than the bar)
                    Rectangle {
                        id: briHandle
                        x: briTrack.handleX
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 26
                        radius: 2
                        color: root.seal
                        Behavior on x { enabled: !briSlider.sliding; NumberAnimation { duration: 120 } }
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
            
            // Night Light Toggle (38x38, dual-mode: Soft / Intense)
            Rectangle {
                id: localNightToggle
                width: 38
                height: 38
                radius: 19
                
                readonly property int mode: dashboardContent.nightMode
                
                color: mode === 2 ? root.color01 : (mode === 1 ? root.color03 : root.fillIdle)
                
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                HoverHandler {
                    id: localNightHov
                }
                
                IconText { 
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    text: "nightlight_round"
                    color: localNightToggle.mode > 0 ? root.paper : root.ink
                    opacity: localNightToggle.mode > 0 ? 1.0 : 0.6
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                // Dual toggle indicator dashes
                Row {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3

                    Rectangle {
                        width: 5
                        height: 3
                        radius: 1.5
                        color: localNightToggle.mode > 0 ? root.paper : root.ink
                        opacity: localNightToggle.mode >= 1 ? 0.95 : 0.25
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }

                    Rectangle {
                        width: 5
                        height: 3
                        radius: 1.5
                        color: localNightToggle.mode > 0 ? root.paper : root.ink
                        opacity: localNightToggle.mode === 2 ? 0.95 : 0.25
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
                
                MouseArea {
                    id: localNightMa
                    anchors.fill: parent
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
            height: 38
            spacing: 10
            
            // Audio Slider Container
            Item {
                id: audSlider
                width: parent.width - 38 - 10
                height: 38
                
                property bool sliding: false
                property int localValue: audioData.volume
                readonly property real effectiveVal: sliding ? localValue : audioData.volume
                
                // Speaker Icon on Left (clickable to toggle mute)
                Rectangle {
                    id: audIconWrap
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: "transparent"

                    IconText { 
                        anchors.centerIn: parent
                        text: audioData.muted ? "volume_off" : (audSlider.effectiveVal > 50 ? "volume_up" : (audSlider.effectiveVal > 0 ? "volume_down" : "volume_mute"))
                        color: audioData.muted ? root.color01 : root.ink
                        font.pixelSize: 20 
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        }
                    }
                }

                // Value indicator (visible when sliding)
                Text {
                    anchors.left: audIconWrap.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(audSlider.effectiveVal) + "%"
                    color: root.ink
                    font.pixelSize: 11
                    font.family: root.barFont
                    font.weight: Font.DemiBold
                    opacity: audSlider.sliding ? 0.9 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                // Slider Track Item
                Item {
                    id: audTrack
                    anchors.left: audIconWrap.right
                    anchors.leftMargin: audSlider.sliding ? 36 : 14
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 28
                    Behavior on anchors.leftMargin { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    readonly property real trackW: width
                    readonly property real handleX: Math.round((Math.max(0, Math.min(100, audSlider.effectiveVal)) / 100) * Math.max(1, trackW - 4))
                    readonly property real gap: 4
                    readonly property real barHeight: 14

                    // Filled Track (Left of drag line)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, audTrack.handleX - audTrack.gap)
                        height: audTrack.barHeight
                        radius: audTrack.barHeight / 2
                        color: audioData.muted ? root.fillHover : root.seal
                        Behavior on width { enabled: !audSlider.sliding; NumberAnimation { duration: 120 } }
                    }

                    // Unfilled Track (Right of drag line)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.min(audTrack.trackW, audTrack.handleX + 4 + audTrack.gap)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: audTrack.barHeight
                        radius: audTrack.barHeight / 2
                        color: audioData.muted ? root.fillIdle : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                        Behavior on anchors.leftMargin { enabled: !audSlider.sliding; NumberAnimation { duration: 120 } }
                    }

                    // Vertical Drag Line (Taller than the bar)
                    Rectangle {
                        id: audHandle
                        x: audTrack.handleX
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: 26
                        radius: 2
                        color: audioData.muted ? root.fillHover : root.seal
                        Behavior on x { enabled: !audSlider.sliding; NumberAnimation { duration: 120 } }
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
            
            // Audio Settings / Detail Toggle (38x38)
            Rectangle {
                id: audSettingsToggle
                width: 38
                height: 38
                radius: 19
                color: dashboardContent.activeDetailView === "volume" ? root.seal : root.fillIdle
                
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                HoverHandler {
                    id: audTuneHov
                }
                
                IconText { 
                    anchors.centerIn: parent
                    text: "tune"
                    color: dashboardContent.activeDetailView === "volume" ? root.paper : root.ink
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                SpringPress {}
                MouseArea {
                    id: audTuneMa
                    anchors.fill: parent
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
    } // end slidersCol

    // ── EDIT TILES HEADER (Direct copy of UI from image) ──
    Item {
        id: editTilesHeader
        anchors.fill: parent
        visible: opacity > 0.001
        opacity: dashboardContent.editTilesMode ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        // Top Action Bar
        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32

            // Back arrow button (<-)
            Rectangle {
                width: 32
                height: 32
                radius: 16
                color: backMa.containsMouse ? root.fillHover : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    color: root.ink
                    font.pixelSize: 20
                }

                TooltipMixin {
                    id: backTip
                    root: dashboardContent.root
                    owner: parent
                    text: "Exit tile editing"
                }

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: backTip.show()
                    onExited: backTip.hide()
                    onClicked: {
                        backTip.hide()
                        dashboardContent.editTilesMode = false
                        dashboardContent.saveTilesLayout()
                    }
                }
            }

            Item { width: Math.max(10, parent.width - 32 - rightBtns.width - 10); height: 1 }

            Row {
                id: rightBtns
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                // Move Earlier / Left button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    visible: dashboardContent.selectedTileId !== ""
                    color: movePrevMa.containsMouse ? root.fillHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        color: root.ink
                        font.pixelSize: 22
                    }

                    TooltipMixin {
                        id: movePrevTip
                        root: dashboardContent.root
                        owner: parent
                        text: "Move selected tile left/earlier"
                    }

                    MouseArea {
                        id: movePrevMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: movePrevTip.show()
                        onExited: movePrevTip.hide()
                        onClicked: {
                            dashboardContent.moveSelectedTile(-1)
                        }
                    }
                }

                // Move Later / Right button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    visible: dashboardContent.selectedTileId !== ""
                    color: moveNextMa.containsMouse ? root.fillHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        color: root.ink
                        font.pixelSize: 22
                    }

                    TooltipMixin {
                        id: moveNextTip
                        root: dashboardContent.root
                        owner: parent
                        text: "Move selected tile right/later"
                    }

                    MouseArea {
                        id: moveNextMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: moveNextTip.show()
                        onExited: moveNextTip.hide()
                        onClicked: {
                            dashboardContent.moveSelectedTile(1)
                        }
                    }
                }

                // Cycle Size button (1x1 -> 1x2 -> 2x2)
                Rectangle {
                    width: sizeRow.implicitWidth + 14
                    height: 32
                    radius: 16
                    visible: dashboardContent.selectedTileId !== ""
                    color: sizeBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.14)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: sizeRow
                        anchors.centerIn: parent
                        spacing: 4

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "aspect_ratio"
                            color: root.seal
                            font.pixelSize: 15
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property var curSpan: dashboardContent.selectedTileId ? dashboardContent.getTileSpan(dashboardContent.selectedTileId) : 1
                            text: curSpan === 4 ? "2x2" : (curSpan === 2 ? "1x2" : "1x1")
                            color: root.ink
                            font.pixelSize: 11
                            font.family: root.barFont
                            font.weight: Font.DemiBold
                        }
                    }

                    TooltipMixin {
                        id: sizeTip
                        root: dashboardContent.root
                        owner: parent
                        text: "Cycle tile size: 1x1, 1x2, 2x2"
                    }

                    MouseArea {
                        id: sizeBtnMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: sizeTip.show()
                        onExited: sizeTip.hide()
                        onClicked: {
                            if (dashboardContent.selectedTileId) {
                                dashboardContent.cycleTileSpan(dashboardContent.selectedTileId)
                            }
                        }
                    }
                }

                // Undo / Reset button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: undoMa.containsMouse ? root.fillHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "undo"
                        color: root.ink
                        font.pixelSize: 20
                    }

                    TooltipMixin {
                        id: undoTip
                        root: dashboardContent.root
                        owner: parent
                        text: "Reset tiles to default"
                    }

                    MouseArea {
                        id: undoMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: undoTip.show()
                        onExited: undoTip.hide()
                        onClicked: {
                            undoTip.hide()
                            dashboardContent.resetTilesLayout()
                        }
                    }
                }

                // "Done" pill button (styled like the pill in the screenshot)
                Rectangle {
                    height: 32
                    width: doneText.implicitWidth + 24
                    radius: 16
                    color: doneMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: doneText
                        anchors.centerIn: parent
                        text: "Done"
                        color: root.paper
                        font.pixelSize: 12
                        font.family: root.barFont
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        id: doneMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: {
                            dashboardContent.editTilesMode = false
                            dashboardContent.saveTilesLayout()
                        }
                    }
                }
            }
        }

        // Title & Subtitle: "Edit tiles" / "Select tiles to rearrange and resize"
        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2
            anchors.left: parent.left
            anchors.leftMargin: 4
            spacing: 2

            Text {
                text: "Edit tiles"
                color: root.ink
                font.pixelSize: 18
                font.family: root.barFont
                font.weight: Font.DemiBold
            }

            Text {
                text: "Select tiles to rearrange and resize"
                color: root.ink
                opacity: 0.65
                font.pixelSize: 11
                font.family: root.barFont
            }
        }
    }
}

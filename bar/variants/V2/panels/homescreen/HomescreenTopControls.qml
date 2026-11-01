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

    // --- SLIDERS (Full Material You size) ---
    Column {
        id: slidersCol
        anchors.fill: parent
        spacing: 10
        visible: opacity > 0.001
        opacity: dashboardContent.editTilesMode ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    
        // Brightness Container
        Row {
            width: parent.width
            spacing: 10
            
            // Brightness Slider
            Rectangle {
                id: briSlider
                width: parent.width - 38 - 8
                height: 38
                radius: 19
                color: root.fillIdle
                
                property bool sliding: false
                property int localValue: dashboardContent.currentBrightness
                
                Item {
                    id: briFillItem
                    property real val: briSlider.sliding ? briSlider.localValue : dashboardContent.currentBrightness
                    property real gap: val > 85 ? 19 * (100 - val) / 15 : 19
                    property real barOpacity: val > 85 ? (100 - val) / 15 : 1
                    
                    width: Math.max(parent.height, parent.width * (val / 100))
                    height: parent.height
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    
                    // The actual fill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(parent.height, parent.width - briFillItem.gap)
                        radius: 9.5 + (9.5 * (1 - briFillItem.barOpacity))
                        color: root.seal
                        
                        // fully rounded on the left
                        Rectangle {
                            width: parent.height
                            height: parent.height
                            radius: height / 2
                            color: root.seal
                            anchors.left: parent.left
                        }
                    }
                    
                    // The vertical bar with "padding"
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: parent.height
                        color: "transparent"
                        opacity: briFillItem.barOpacity
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 3
                            height: parent.height - 14
                            radius: 1.5
                            color: root.seal
                        }
                    }
                }
                
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    spacing: 10
                    IconText { 
                        anchors.verticalCenter: parent.verticalCenter
                        text: "light_mode"
                        color: root.paper
                        font.pixelSize: 18 
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(briFillItem.val) + "%"
                        color: briFillItem.width > 64 ? root.paper : root.ink
                        font.pixelSize: 12
                        font.family: root.barFont
                        font.weight: Font.DemiBold
                        opacity: briSlider.sliding ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onPressed: { briSlider.sliding = true }
                    onPositionChanged: (mouse) => {
                        if (pressed) briSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                    }
                    onReleased: (mouse) => {
                        briSlider.sliding = false
                        let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                        dashboardContent.currentBrightness = pct
                        Quickshell.execDetached(["bash", "-c", "brightnessctl set " + pct + "%"])
                    }
                }
            }
            
            // Night Light Toggle (44x44, dual-mode: Soft / Intense)
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
                            dashboardContent.setNightMode(0)
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

        // Audio Container
        Row {
            width: parent.width
            spacing: 10
            
            // Audio Slider
            Rectangle {
                id: audSlider
                width: parent.width - 38 - 8
                height: 38
                radius: 19
                color: root.fillIdle
                
                property bool sliding: false
                property int localValue: audioData.volume
                
                Item {
                    id: audFillItem
                    property real val: audSlider.sliding ? audSlider.localValue : audioData.volume
                    property real gap: val > 85 ? 19 * (100 - val) / 15 : 19
                    property real barOpacity: val > 85 ? (100 - val) / 15 : 1
                    
                    width: Math.max(parent.height, parent.width * (val / 100))
                    height: parent.height
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    
                    // The actual fill
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(parent.height, parent.width - audFillItem.gap)
                        radius: 9.5 + (9.5 * (1 - audFillItem.barOpacity))
                        color: audioData.muted ? root.fillHover : root.seal
                        
                        // fully rounded on the left
                        Rectangle {
                            width: parent.height
                            height: parent.height
                            radius: height / 2
                            color: audioData.muted ? root.fillHover : root.seal
                            anchors.left: parent.left
                        }
                    }
                    
                    // The vertical bar with "padding"
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: parent.height
                        color: "transparent"
                        opacity: audFillItem.barOpacity
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: 3
                            height: parent.height - 14
                            radius: 1.5
                            color: audioData.muted ? root.fillHover : root.seal
                        }
                    }
                }
                
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    spacing: 10
                    IconText { 
                        anchors.verticalCenter: parent.verticalCenter
                        text: audioData.muted ? "volume_off" : "volume_up"
                        color: audioData.muted ? root.ink : root.paper
                        font.pixelSize: 18 
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(audFillItem.val) + "%"
                        color: audioData.muted ? root.ink : (audFillItem.width > 64 ? root.paper : root.ink)
                        font.pixelSize: 12
                        font.family: root.barFont
                        font.weight: Font.DemiBold
                        opacity: audSlider.sliding ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
                
                MouseArea {
                    anchors.fill: parent
                    onPressed: { audSlider.sliding = true }
                    onPositionChanged: (mouse) => {
                        if (pressed) audSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                    }
                    onReleased: (mouse) => {
                        audSlider.sliding = false
                        let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
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

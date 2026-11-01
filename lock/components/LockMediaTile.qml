import QtQuick
import Quickshell
import Quickshell.Widgets

// ── TILE 3: MEDIA PLAYER / NOW PLAYING (2 Cols) ──
// Direction: Top-Right
Item {
    id: tile3Wrapper
    required property var root
    property alias tile3InAnim: tile3InAnim
    property alias t3Trans: t3Trans

    width: 468
    height: parent.height
    opacity: 0.0
    scale: 0.94
    transform: Translate { id: t3Trans; x: 0; y: 24 }

    SequentialAnimation {
        id: tile3InAnim
        running: true
        PauseAnimation { duration: 240 }
        ParallelAnimation {
            NumberAnimation { target: tile3Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: tile3Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            NumberAnimation { target: t3Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
    }

    Rectangle {
        id: mediaTile
        anchors.fill: parent
        radius: 26
        color: root.cardBg
        border.color: root.cardBorder
        border.width: 1
        clip: true

        // Inner clipping container ensures full-bleed album art rounds to corners
        ClippingRectangle {
            anchors.fill: parent
            radius: 26
            color: "transparent"

            // Full-bleed album art background
            Image {
                id: cardBgArt
                anchors.fill: parent
                source: root.activePlayer ? (root.activePlayer.trackArtUrl || "") : ""
                sourceSize: Qt.size(512, 512)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.hasMedia && status === Image.Ready
            }

            // Smooth darkening and tint overlays so text/buttons pop
            Rectangle {
                anchors.fill: parent
                visible: root.hasMedia
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.38) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                }
            }
        }

        // --- When media is active ---
        Item {
            anchors.fill: parent
            visible: root.hasMedia

            // TOP ROW: App Icon + Status Tag (Left) + Output Pill (Right)
            Item {
                id: topRow
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // App icon (Spotify logo if available, or music icon)
                    Item {
                        width: 20; height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: spotLogo
                            anchors.fill: parent
                            source: (root.activePlayer && /spotify/i.test(root.activePlayer.identity || ""))
                                ? "file://" + Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/spotify.svg"
                                : ""
                            visible: source !== "" && status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: "Material Symbols Rounded"
                            color: "#ffffff"
                            font.pixelSize: 18
                            visible: !spotLogo.visible
                        }
                    }

                    // Status Tag: NOW PLAYING / PAUSED
                    Rectangle {
                        id: statusTag
                        height: 20
                        radius: 6
                        color: root.isMediaPlaying ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.35)
                        border.color: Qt.rgba(1, 1, 1, 0.20)
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: statusTxt.implicitWidth + 12

                        Text {
                            id: statusTxt
                            anchors.centerIn: parent
                            text: root.isMediaPlaying ? "NOW PLAYING" : "PAUSED"
                            color: "#ffffff"
                            font.family: "Genova"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.8
                        }
                    }
                }

                // Output Pill on right
                Rectangle {
                    id: outputPill
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    width: outRow.implicitWidth + 14

                    Row {
                        id: outRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: "speaker"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 13
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: {
                                var idn = (root.activePlayer && root.activePlayer.identity) ? root.activePlayer.identity : "This device"
                                return idn.length > 16 ? idn.substring(0, 14) + "…" : idn
                            }
                            font.family: "Genova"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // MIDDLE ROW: Title & Artist (Left) + Pill Play/Pause Button (Right)
            Item {
                id: midRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: 44

                // Track Title & Artist
                Column {
                    id: textCol
                    anchors.left: parent.left
                    anchors.right: playPill.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Song Title with Marquee
                    Item {
                        id: marqueeTitleContainer
                        width: parent.width
                        height: 22
                        clip: true

                        readonly property bool shouldMarquee: marqueeTitleContainer.width > 20 && marqueeTitleText.implicitWidth > (marqueeTitleContainer.width + 4)

                        function resetMarquee() {
                            marqueeAnim.stop()
                            marqueeTitleText.x = 0
                            if (shouldMarquee) marqueeAnim.start()
                        }

                        onWidthChanged: resetMarquee()
                        onShouldMarqueeChanged: resetMarquee()

                        Text {
                            id: marqueeTitleText
                            text: root.activePlayer ? (root.activePlayer.trackTitle || "No media") : "No media"
                            color: "#ffffff"
                            font.family: "Genova"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter

                            onTextChanged: marqueeTitleContainer.resetMarquee()

                            SequentialAnimation on x {
                                id: marqueeAnim
                                loops: Animation.Infinite
                                running: marqueeTitleContainer.shouldMarquee
                                onRunningChanged: {
                                    if (!running) marqueeTitleText.x = 0
                                }
                                PauseAnimation { duration: 2000 }
                                NumberAnimation {
                                    from: 0
                                    to: -(marqueeTitleText.implicitWidth - marqueeTitleContainer.width + 16)
                                    duration: Math.max(1200, (marqueeTitleText.implicitWidth - marqueeTitleContainer.width) * 25)
                                    easing.type: Easing.Linear
                                }
                                PauseAnimation { duration: 1800 }
                                NumberAnimation {
                                    to: 0
                                    duration: 400
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }
                    }

                    Text {
                        text: root.activePlayer ? (root.activePlayer.trackArtist || "Nothing in queue") : "Nothing in queue"
                        color: Qt.rgba(1, 1, 1, 0.80)
                        font.family: "Genova"
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                // Large Squircle Play/Pause Button (Material You style)
                Rectangle {
                    id: playPill
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 14
                    color: playMa.pressed ? Qt.rgba(1, 1, 1, 0.12) : (playMa.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.18))
                    border.color: Qt.rgba(1, 1, 1, 0.20)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // Geometric pause bars
                    Row {
                        anchors.centerIn: parent
                        spacing: 4.5
                        visible: root.isMediaPlaying

                        Rectangle {
                            width: 4.5
                            height: 16
                            radius: 2.25
                            color: "#ffffff"
                        }
                        Rectangle {
                            width: 4.5
                            height: 16
                            radius: 2.25
                            color: "#ffffff"
                        }
                    }

                    // Play arrow icon
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1.5
                        text: "play_arrow"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 28
                        color: "#ffffff"
                        visible: !root.isMediaPlaying
                    }

                    MouseArea {
                        id: playMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.activePlayer) root.activePlayer.togglePlaying()
                    }
                }
            }

            // BOTTOM ROW: Prev + Wavy Progress Bar + Next + Song Length
            Row {
                id: bottomRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 12
                height: 24
                spacing: 8

                // Previous Button
                Item {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: "#ffffff"
                        opacity: (root.activePlayer && root.activePlayer.canGoPrevious) ? 0.95 : 0.4
                    }

                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        scale: pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        onClicked: if (root.activePlayer) root.activePlayer.previous()
                    }
                }

                // Wavy Seekable Progress Bar
                Item {
                    id: wavyBarContainer
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(80, parent.width - 24 - 24 - (positionTxt ? positionTxt.implicitWidth : 36) - (8 * 3))
                    height: 24

                    property real progress: root.curLen > 0 
                        ? Math.max(0, Math.min(1, root.curPos / root.curLen)) 
                        : 0

                    Canvas {
                        id: waveCanvas
                        anchors.fill: parent
                        property real wavePhase: 0
                        property real waveAmp: root.isMediaPlaying ? 3.5 : 0

                        Behavior on waveAmp {
                            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                        }
                        onWaveAmpChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cy = height / 2
                            var p = wavyBarContainer.progress
                            var progressX = Math.max(0, Math.min(width, width * p))
                            var scrubberW = 4
                            var scrubberH = (seekArea.pressed || seekArea.containsMouse) ? 14 : 10
                            var baseAmp = waveCanvas.waveAmp

                            // 1. Unplayed straight horizontal line
                            if (progressX < width) {
                                ctx.beginPath()
                                ctx.moveTo(progressX, cy)
                                ctx.lineTo(width, cy)
                                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.32)
                                ctx.lineWidth = 3
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }

                            // 2. Played portion: wavy sine line when playing, flat straight line when paused
                            if (progressX > 0) {
                                var wavelength = 34
                                ctx.beginPath()
                                ctx.moveTo(0, cy)
                                if (baseAmp > 0.05) {
                                    for (var x = 0; x <= progressX; x += 1.5) {
                                        var distToEnd = progressX - x
                                        var taper = distToEnd < 14 ? (distToEnd / 14) : 1.0
                                        var y = cy + baseAmp * taper * Math.sin((x / wavelength) * 2 * Math.PI - wavePhase)
                                        ctx.lineTo(x, y)
                                    }
                                } else {
                                    ctx.lineTo(progressX, cy)
                                }
                                ctx.strokeStyle = "#ffffff"
                                ctx.lineWidth = 3
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }

                            // 3. Vertical pill scrubber head
                            ctx.beginPath()
                            ctx.moveTo(progressX, cy - scrubberH / 2)
                            ctx.lineTo(progressX, cy + scrubberH / 2)
                            ctx.strokeStyle = "#ffffff"
                            ctx.lineWidth = scrubberW
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }

                    Timer {
                        interval: 33
                        running: root.isMediaPlaying
                        repeat: true
                        onTriggered: {
                            waveCanvas.wavePhase += 0.08
                            waveCanvas.requestPaint()
                        }
                    }

                    Connections {
                        target: root
                        function onCurPosChanged() { waveCanvas.requestPaint() }
                        function onCurLenChanged() { waveCanvas.requestPaint() }
                        function onIsMediaPlayingChanged() { waveCanvas.requestPaint() }
                    }

                    // Floating Timestamp Tooltip during scrub / hover
                    Rectangle {
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 4
                        x: Math.max(0, Math.min(parent.width - width, wavyBarContainer.width * wavyBarContainer.progress - width / 2))
                        width: timeTxt.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Qt.rgba(0, 0, 0, 0.85)
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                        border.width: 1
                        visible: (seekArea.containsMouse || seekArea.pressed) && root.curLen > 0

                        Text {
                            id: timeTxt
                            anchors.centerIn: parent
                            text: root.fmtTime(root.curPos) + " / " + root.fmtTime(root.curLen)
                            color: "#ffffff"
                            font.family: "Genova"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            root.seekTo(mouse.x / width)
                            waveCanvas.requestPaint()
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                root.seekTo(mouse.x / width)
                                waveCanvas.requestPaint()
                            }
                        }
                    }
                }

                // Next Button
                Item {
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "skip_next"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 22
                        color: "#ffffff"
                        opacity: (root.activePlayer && root.activePlayer.canGoNext) ? 0.95 : 0.4
                    }

                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        scale: pressed ? 0.88 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        onClicked: if (root.activePlayer) root.activePlayer.next()
                    }
                }

                // Current Song Position Display
                Text {
                    id: positionTxt
                    text: root.fmtTime(root.curPos)
                    color: Qt.rgba(1, 1, 1, 0.85)
                    font.family: "Genova"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // --- When no media is active ---
        Item {
            anchors.fill: parent
            visible: !root.hasMedia

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "graphic_eq"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 34
                    color: root.seal
                    opacity: 0.6
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "No Media Playing"
                    font.family: "Genova"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: root.ink
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "Play music from Spotify or browser"
                    font.family: "Genova"
                    font.pixelSize: 10
                    color: root.ink
                    opacity: 0.45
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}

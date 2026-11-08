import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// --- MATERIAL YOU MEDIA PLAYER WITH EXTENDED LYRICS SECTION ---
Item {
    id: mediaWithLyricsGroup
    required property var dashboardContent
    required property var root
    required property var panel
    required property var mprisSel
    required property var mprisArt
    required property var audioData
    property var mprisPanel: dashboardContent ? dashboardContent.mprisPanel : null

    readonly property real lyricsVisibleHeight: Math.max(60, height - mediaCard.height)

    visible: opacity > 0.001
    opacity: dashboardContent.showMediaPlayer ? 1.0 : 0.0
    scale: dashboardContent.showMediaPlayer ? 1.0 : 0.96
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // Extended Lyrics Drawer (Starts from the back of the media player and extends down)
    HomescreenLyricsDrawer {
        id: lyricsExtender
        z: 1
        anchors.fill: parent
        dashboardContent: mediaWithLyricsGroup.dashboardContent
        root: mediaWithLyricsGroup.root
        mprisSel: mediaWithLyricsGroup.mprisSel
        mediaCard: mediaCard
        lyricsVisibleHeight: mediaWithLyricsGroup.lyricsVisibleHeight
    }

    // --- MATERIAL YOU MEDIA PLAYER ---
    Rectangle {
        id: mediaCard
        z: 2
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 144
        radius: 22

        readonly property bool isSpotify: mprisSel.player && /spotify/i.test((mprisSel.player.identity || "") + " " + (mprisSel.player.dbusName || ""))
        readonly property bool isYouTube: mprisSel.player && (/youtube/i.test(mprisSel.player.trackTitle || "") || /youtube/i.test(mprisSel.player.identity || "") || /firefox|zen|chromium|chrome|brave/i.test(mprisSel.player.identity || "") || /firefox|zen|chromium|chrome|brave/i.test(mprisSel.player.dbusName || ""))

        WheelHandler {
            target: null
            onWheel: (event) => {
                if (!dashboardContent.hasMultiplePlayers) return
                if (event.angleDelta.x > 30 || event.angleDelta.y < -40) {
                    mprisSel.nextPlayer()
                } else if (event.angleDelta.x < -30 || event.angleDelta.y > 40) {
                    mprisSel.prevPlayer()
                }
            }
        }

        readonly property bool hasDominant: mprisArt.dominantColor && String(mprisArt.dominantColor) !== "#00000000" && String(mprisArt.dominantColor) !== "transparent"
        readonly property color domCol: hasDominant ? mprisArt.dominantColor : root.seal
        readonly property bool hasVibrantDom: hasDominant && (domCol.r * 0.299 + domCol.g * 0.587 + domCol.b * 0.114 > 0.18)
        color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r * 0.45, mediaCard.domCol.g * 0.45, mediaCard.domCol.b * 0.45, 0.5) : root.fillIdle
        border.color: hasVibrantDom ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.45) : root.islandBorder
        border.width: 1
        // Clean pastel / paper color for the pill play button matching Android Material You
        readonly property color pillBg: {
            if (!hasDominant) return root.paper
            var maxC = Math.max(domCol.r, domCol.g, domCol.b)
            var minC = Math.min(domCol.r, domCol.g, domCol.b)
            var sat = maxC > 0 ? (maxC - minC) / maxC : 0
            // If dominant color is murky/dark/grey, fall back to clean, bright root.paper
            if (sat < 0.25 || maxC < 0.35) {
                return root.paper
            }
            // Soft pastel tint of root.paper
            return Qt.tint(root.paper, Qt.rgba(domCol.r, domCol.g, domCol.b, 0.35))
        }

        Behavior on color { ColorAnimation { duration: 300 } }
        Behavior on border.color { ColorAnimation { duration: 300 } }

        // Inner clipping container ensures artwork and overlays are clipped to the rounded corners
        ClippingRectangle {
            anchors.fill: parent
            radius: 22
            color: "transparent"

            // Full-bleed album art background
            Image {
                id: cardBgArt
                anchors.fill: parent
                source: mprisArt.source || root.lastMediaArtUrl
                sourceSize: Qt.size(512, 512)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            // Smooth darkening and tint overlays so text/buttons pop
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.50) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.70) }
                }
            }

            Rectangle {
                anchors.fill: parent
                color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.28) : "transparent"
            }
        }

        // TOP ROW: App Icon / Switcher (Left) + Output / Clock Controls (Right)
        Item {
            id: topRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 22

            Row {
                id: topRowLeft
                anchors.left: parent.left
                anchors.right: topRowRight.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                clip: true

                // ── Multi-Player Source Switcher (modeled after DesktopContextMenu wallpaper picker) ──
                Row {
                    id: playerSwitcherRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    visible: dashboardContent.hasMultiplePlayers

                    Repeater {
                        model: dashboardContent.hasMultiplePlayers ? mprisSel.playersList : []
                        delegate: ClippingRectangle {
                            id: playerPillItem
                            required property var modelData
                            required property int index
                            readonly property bool isCurrent: index === mprisSel.selectedIndex
                            width: isCurrent ? 84 : 22
                            height: 22
                            radius: 11
                            color: isCurrent ? Qt.rgba(1, 1, 1, 0.28) : (playerPillMa.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.36))
                            border.color: isCurrent ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.18)
                            border.width: 1

                            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            // Artwork / Thumbnail background preview if available
                            Image {
                                anchors.fill: parent
                                source: modelData.trackArtUrl || ""
                                sourceSize: Qt.size(96, 96)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                opacity: playerPillItem.isCurrent ? 0.35 : 0.55
                                visible: status === Image.Ready
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                // App Icon
                                Item {
                                    width: 14; height: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property bool isSpot: /spotify/i.test((modelData.identity || "") + " " + (modelData.dbusName || ""))
                                    readonly property bool isYt: /youtube/i.test(modelData.trackTitle || "") || /firefox|zen|chromium|chrome|brave/i.test(modelData.identity || "")

                                    Image {
                                        anchors.fill: parent
                                        source: "file:///home/darshan/.config/quickshell/bar/assets/icons/spotify.svg"
                                        visible: parent.isSpot
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 3
                                        color: "#e50914"
                                        visible: !parent.isSpot && parent.isYt

                                        IconText {
                                            anchors.centerIn: parent
                                            text: "play_arrow"
                                            color: "#ffffff"
                                            font.pixelSize: 9
                                        }
                                    }

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "music_note"
                                        color: "#ffffff"
                                        font.pixelSize: 13
                                        visible: !parent.isSpot && !parent.isYt
                                    }
                                }

                                // Identity Name when expanded
                                Text {
                                    visible: playerPillItem.isCurrent
                                    text: {
                                        var idStr = modelData.identity || "Media"
                                        return idStr.length > 7 ? idStr.substring(0, 6) + "…" : idStr
                                    }
                                    color: "#ffffff"
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Checkmark badge when active
                                IconText {
                                    visible: playerPillItem.isCurrent
                                    text: "check"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: playerPillMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mprisSel.selectPlayer(index)
                            }

                            TooltipMixin {
                                root: dashboardContent.root
                                owner: parent
                                text: modelData.trackTitle ? (modelData.trackTitle + " (" + (modelData.identity || "Media") + ")") : (modelData.identity || "Media Player")
                            }
                        }
                    }
                }

                // Single-player App icon badge (visible when only 1 player active)
                Item {
                    width: 20; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !dashboardContent.hasMultiplePlayers

                    Image {
                        id: spotLogo
                        anchors.fill: parent
                        source: "file:///home/darshan/.config/quickshell/bar/assets/icons/spotify.svg"
                        visible: mediaCard.isSpotify && status === Image.Ready
                    }

                    Rectangle {
                        id: ytBadge
                        anchors.fill: parent
                        radius: 5
                        color: "#e50914"
                        visible: !spotLogo.visible && mediaCard.isYouTube

                        IconText {
                            anchors.centerIn: parent
                            text: "play_arrow"
                            color: "#ffffff"
                            font.pixelSize: 13
                        }
                    }

                    IconText {
                        anchors.centerIn: parent
                        text: "music_note"
                        color: "#ffffff"
                        font.pixelSize: 18
                        visible: !spotLogo.visible && !ytBadge.visible
                    }
                }

                // Last Played / Now Playing Tag (Visible when not multiple players)
                Rectangle {
                    id: statusTag
                    height: 20
                    radius: 6
                    visible: !dashboardContent.hasMultiplePlayers
                    color: (dashboardContent.curTitle === "" && root.lastMediaTitle !== "")
                        ? Qt.rgba(1, 1, 1, 0.30)
                        : (mprisSel.playing ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.30))
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: statusTxt.implicitWidth + 12

                    Text {
                        id: statusTxt
                        anchors.centerIn: parent
                        text: {
                            if (dashboardContent.curTitle === "" && root.lastMediaTitle !== "") return "LAST PLAYED"
                            if (mprisSel.playing) return "NOW PLAYING"
                            return "PAUSED"
                        }
                        color: "#ffffff"
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                    }
                }
            }

            // Right side controls
            Row {
                id: topRowRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Switch to Clock Widget Button
                Rectangle {
                    id: switchToClockBtn
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: switchToClockMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "schedule"
                        font.pixelSize: 13
                        color: switchToClockMa.containsMouse ? root.seal : (root ? root.ink : "#ffffff")
                    }

                    TooltipMixin {
                        root: dashboardContent.root
                        owner: switchToClockBtn
                        text: "Show Clock"
                    }

                    SpringPress {}
                    MouseArea {
                        id: switchToClockMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            dashboardContent.showMediaManually = false
                        }
                    }
                }

                // Output Pill (e.g. "This device" / Audio Sink)
                Rectangle {
                    id: outputPill
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

                        IconText {
                            text: "speaker"
                            font.pixelSize: 13
                            color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: {
                                var desc = (audioData.sink && audioData.sink.description) ? audioData.sink.description : "This device"
                                return desc.length > 18 ? desc.substring(0, 16) + "…" : desc
                            }
                            color: "#ffffff"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    TooltipMixin {
                        root: dashboardContent.root
                        owner: outputPill
                        text: audioData.sink ? (audioData.sink.description || "Audio Output") : "Audio Output"
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
            anchors.verticalCenterOffset: -1
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

                // Song Title with Marquee (only scrolls when title overflows container)
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
                        text: root.lastMediaTitle || "No media"
                        color: "#ffffff"
                        font.family: root.barFont
                        font.pixelSize: 17
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
                    text: root.lastMediaArtist || "Nothing in queue"
                    color: Qt.rgba(1, 1, 1, 0.80)
                    font.family: root.barFont
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // Pill Play/Pause Button (Material You rectangle pill style)
            Rectangle {
                id: playPill
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 54
                height: 34
                radius: 17
                readonly property color iconCol: {
                    var c = mediaCard.pillBg
                    var luma = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
                    return luma > 0.55 ? "#1e1b18" : "#ffffff"
                }
                color: playMa.pressed ? Qt.darker(mediaCard.pillBg, 1.15) : (playMa.containsMouse ? Qt.lighter(mediaCard.pillBg, 1.08) : mediaCard.pillBg)
                border.color: Qt.rgba(0, 0, 0, 0.08)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                // Geometric pause bars (100% mathematically centered)
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: mprisSel.playing

                    Rectangle {
                        width: 3.5
                        height: 14
                        radius: 1.75
                        color: playPill.iconCol
                    }
                    Rectangle {
                        width: 3.5
                        height: 14
                        radius: 1.75
                        color: playPill.iconCol
                    }
                }

                // Play arrow icon (when paused)
                IconText {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1.5
                    text: "play_arrow"
                    font.pixelSize: 22
                    color: playPill.iconCol
                    visible: !mprisSel.playing
                }

                SpringPress {}
                MouseArea {
                    id: playMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (mprisSel.player) mprisSel.player.togglePlaying()
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

                IconText {
                    anchors.centerIn: parent
                    text: "skip_previous"
                    font.pixelSize: 22
                    color: "#ffffff"
                    opacity: (mprisSel.player && mprisSel.player.canGoPrevious) ? 0.95 : 0.4
                }

                SpringPress {}
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    onClicked: if (mprisSel.player) mprisSel.player.previous()
                }
            }

            // Wavy Seekable Progress Bar
            Item {
                id: wavyBarContainer
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(80, parent.width - 24 - 24 - (positionTxt ? positionTxt.implicitWidth : 36) - (8 * 3))
                height: 24

                property real progress: dashboardContent.curLen > 0 
                    ? Math.max(0, Math.min(1, dashboardContent.curPos / dashboardContent.curLen)) 
                    : 0

                Canvas {
                    id: waveCanvas
                    anchors.fill: parent
                    property real wavePhase: 0
                    property real waveAmp: mprisSel.playing ? 3.5 : 0

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

                        // 1. Unplayed straight horizontal line (from progressX to width)
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
                            var wavelength = 34 // Slightly increased frequency
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

                        // 3. Vertical pill scrubber head (fixed vertically in center: stationary at cy)
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
                    running: mprisSel.playing && panel.expanded
                    repeat: true
                    onTriggered: {
                        waveCanvas.wavePhase += 0.08
                        waveCanvas.requestPaint()
                    }
                }

                Connections {
                    target: dashboardContent
                    function onCurPosChanged() { waveCanvas.requestPaint() }
                    function onCurLenChanged() { waveCanvas.requestPaint() }
                }

                Connections {
                    target: mprisSel
                    function onPlayingChanged() { waveCanvas.requestPaint() }
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
                    visible: (seekArea.containsMouse || seekArea.pressed) && dashboardContent.curLen > 0

                    Text {
                        id: timeTxt
                        anchors.centerIn: parent
                        text: dashboardContent.fmtTime(dashboardContent.curPos) + " / " + dashboardContent.fmtTime(dashboardContent.curLen)
                        color: "#ffffff"
                        font.family: root.barFont
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
                        dashboardContent.seekTo(mouse.x / width)
                        waveCanvas.requestPaint()
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            dashboardContent.seekTo(mouse.x / width)
                            waveCanvas.requestPaint()
                        }
                    }
                }
            }

            // Next Button
            Item {
                width: 24; height: 24
                anchors.verticalCenter: parent.verticalCenter

                IconText {
                    anchors.centerIn: parent
                    text: "skip_next"
                    font.pixelSize: 22
                    color: "#ffffff"
                    opacity: (mprisSel.player && mprisSel.player.canGoNext) ? 0.95 : 0.4
                }

                SpringPress {}
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: pressed ? 0.88 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    onClicked: if (mprisSel.player) mprisSel.player.next()
                }
            }

            // Current Song Position Display
            Text {
                id: positionTxt
                text: dashboardContent.fmtTime(dashboardContent.curPos)
                color: Qt.rgba(1, 1, 1, 0.85)
                font.family: root.barFont
                font.pixelSize: 12
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    } // end mediaCard
} // end mediaWithLyricsGroup

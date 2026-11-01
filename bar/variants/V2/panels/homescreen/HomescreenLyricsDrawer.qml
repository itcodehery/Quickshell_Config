import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// Extended Lyrics Drawer (Starts from the back of the media player and extends down)
Rectangle {
    id: lyricsExtender
    required property var dashboardContent
    required property var root
    required property var mprisSel
    required property var mediaCard
    required property real lyricsVisibleHeight
    property var mprisPanel: dashboardContent ? dashboardContent.mprisPanel : null

    radius: 22

    readonly property bool hasBrightDom: mediaCard.hasDominant && (mediaCard.domCol.r * 0.299 + mediaCard.domCol.g * 0.587 + mediaCard.domCol.b * 0.114 > 0.15)
    color: mediaCard.hasDominant
        ? Qt.rgba(mediaCard.domCol.r * 0.32, mediaCard.domCol.g * 0.32, mediaCard.domCol.b * 0.32, lyricsMa.containsMouse ? 0.75 : 0.60)
        : (lyricsMa.containsMouse ? root.fillHover : root.fillIdle)
    border.color: mediaCard.hasDominant
        ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, lyricsMa.containsMouse ? 0.50 : 0.32)
        : (lyricsMa.containsMouse ? root.islandBorder : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16))
    border.width: 1

    Behavior on color { ColorAnimation { duration: 250 } }
    Behavior on border.color { ColorAnimation { duration: 250 } }

    // Frosted acrylic glass styling with ambient dominant glow
    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "transparent"

        // Specular glass gradient
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Qt.rgba(1, 1, 1, lyricsMa.containsMouse ? 0.08 : 0.04)
                }
                GradientStop {
                    position: 0.40
                    color: Qt.rgba(1, 1, 1, 0.01)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // Subtle dominant ambient glow
        Rectangle {
            anchors.fill: parent
            visible: mediaCard.hasDominant
            opacity: lyricsMa.containsMouse ? 0.30 : 0.18
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: mediaCard.domCol
                }
                GradientStop {
                    position: 0.85
                    color: "transparent"
                }
            }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }

    SpringPress {}
    MouseArea {
        id: lyricsMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (dashboardContent.mprisPanel) {
                dashboardContent.mprisPanel.showingLyrics = !dashboardContent.mprisPanel.showingLyrics
            }
        }
    }

    // Visible extension area extending below mediaCard
    Item {
        id: lyricVisibleArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: lyricsExtender.lyricsVisibleHeight

        // Floating Pill Actions (Right aligned)
        Row {
            id: lyricsActionsRow
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Reload Lyrics Icon Button
            Rectangle {
                id: reloadLyricsBtn
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: reloadLyricsMa.containsMouse ? (lyricsPillTag.isShowing ? Qt.rgba(1, 1, 1, 0.30) : root.fillHover) : Qt.rgba(1, 1, 1, 0.14)
                border.color: Qt.rgba(1, 1, 1, 0.28)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    id: reloadIcon
                    anchors.centerIn: parent
                    text: "refresh"
                    font.pixelSize: 13
                    color: (mprisPanel && mprisPanel._isFetchingLyrics) ? root.seal : (root ? root.ink : "#ffffff")

                    RotationAnimation on rotation {
                        running: mprisPanel ? mprisPanel._isFetchingLyrics : false
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                    }
                }

                TooltipMixin {
                    id: reloadLyricsTip
                    root: dashboardContent.root
                    owner: reloadLyricsBtn
                    text: "Reload lyrics"
                }

                SpringPress {}
                MouseArea {
                    id: reloadLyricsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var trackId = dashboardContent.currentTrackId
                        if (mprisPanel) {
                            if (trackId && mprisPanel._lyricsCache) {
                                delete mprisPanel._lyricsCache[trackId]
                            }
                            mprisPanel.lyricsTrackId = ""
                            mprisPanel._lyricsRetryCount = 0
                            mprisPanel._isFetchingLyrics = false
                            mprisPanel.fetchLyrics()
                        }
                        dashboardContent.localLyricsTrackId = ""
                        dashboardContent.fetchLocalLyrics()
                    }
                }
            }

            // Floating Pill Toggle Tag
            Rectangle {
                id: lyricsPillTag
                height: 24
                radius: 12
                readonly property bool isShowing: (dashboardContent.mprisPanel && dashboardContent.mprisPanel.showingLyrics)
                color: isShowing
                    ? mediaCard.pillBg
                    : (lyricsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                border.color: isShowing
                    ? (mediaCard.hasVibrantDom ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.45) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15))
                    : Qt.rgba(1, 1, 1, 0.28)
                border.width: 1
                width: tagRow.implicitWidth + 14

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    id: tagRow
                    anchors.centerIn: parent
                    spacing: 5

                    IconText {
                        text: lyricsPillTag.isShowing ? "visibility" : "subtitles"
                        font.pixelSize: 12
                        color: lyricsPillTag.isShowing ? root.ink : "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: lyricsPillTag.isShowing ? "FLOAT ON" : "LYRICS"
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        color: lyricsPillTag.isShowing ? root.ink : "#FFFFFF"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Realtime Animated Multi-line Lyrics Viewport (Vertically centered)
        Item {
            id: lyricTextContainer
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: lyricsActionsRow.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 12
            clip: true

            // Fallback container when no synced lyrics available
            Column {
                id: fallbackLyricsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                visible: !dashboardContent.hasSyncedLyrics

                Text {
                    text: mprisSel.active ? (dashboardContent.curTitle !== "" ? dashboardContent.curTitle : "No synced lyrics available") : "Play music to see lyrics"
                    color: "#FFFFFF"
                    font.family: root.barFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Text {
                    text: mprisSel.active
                        ? (dashboardContent.curArtist !== "" ? dashboardContent.curArtist + "  •  No synced lyrics" : "No synced lyrics available")
                        : "Tap to open lyrics panel"
                    color: Qt.rgba(1, 1, 1, 0.50)
                    font.family: root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    width: parent.width
                    visible: text !== ""
                }
            }

            // Reel column when synced lyrics are available - max 2 lines visible at a time
            Item {
                id: syncedReelViewport
                anchors.fill: parent
                visible: dashboardContent.hasSyncedLyrics
                clip: true

                Column {
                    id: lyricReelCol
                    width: parent.width
                    spacing: 4

                    property real glideOffset: 0
                    readonly property real baseRestingY: {
                        var twoLinesH = line1Text.implicitHeight + (lyricReelCol.nextText !== "" ? (spacing + line2Text.implicitHeight) : 0)
                        return Math.max(0, Math.round((syncedReelViewport.height - twoLinesH) / 2))
                    }

                    y: baseRestingY + glideOffset

                    property int curIdx: -1
                    property string activeText: ""
                    property string nextText: ""
                    property string thirdText: ""
                    property string pendingActiveText: ""
                    property string pendingNextText: ""

                    function resetImmediate() {
                        glideOffset = 0
                        line1Text.opacity = 1.0
                        line2Text.opacity = lyricReelCol.nextText !== "" ? 0.50 : 0.0
                        line3Text.opacity = 0.0
                        line3Text.text = ""
                    }

                    // Active lyric (Current line) - multi-line WordWrap with comfortable spacing
                    Text {
                        id: line1Text
                        width: parent.width
                        text: lyricReelCol.activeText
                        color: "#FFFFFF"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                        opacity: 1.0
                    }

                    // Upcoming preview lyric (Next line) - glides up to line 1 during reel animation
                    Text {
                        id: line2Text
                        width: parent.width
                        text: lyricReelCol.nextText
                        color: "#FFFFFF"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                        opacity: text !== "" ? 0.50 : 0.0
                    }

                    // Incoming preview lyric (Only fades in as next line during reel animation, invisible at rest)
                    Text {
                        id: line3Text
                        width: parent.width
                        text: lyricReelCol.thirdText
                        color: "#FFFFFF"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                        opacity: 0.0
                    }
                }

                // High-performance, silky smooth vertical glide animation
                ParallelAnimation {
                    id: lyricReelAnim
                    property real shiftDistance: -(line1Text.implicitHeight + lyricReelCol.spacing)

                    NumberAnimation {
                        target: lyricReelCol
                        property: "glideOffset"
                        from: 0
                        to: lyricReelAnim.shiftDistance
                        duration: 340
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: line1Text
                        property: "opacity"
                        to: 0.0
                        duration: 260
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: line2Text
                        property: "opacity"
                        to: 1.0
                        duration: 320
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: line3Text
                        property: "opacity"
                        to: 0.50
                        duration: 320
                        easing.type: Easing.OutQuad
                    }

                    onFinished: {
                        lyricReelCol.activeText = lyricReelCol.pendingActiveText
                        lyricReelCol.nextText = lyricReelCol.pendingNextText
                        lyricReelCol.thirdText = ""
                        lyricReelCol.glideOffset = 0
                        line1Text.opacity = 1.0
                        line2Text.opacity = lyricReelCol.nextText !== "" ? 0.50 : 0.0
                        line3Text.opacity = 0.0
                    }
                }

                function updateFromIndex(idx) {
                    if (!dashboardContent.hasSyncedLyrics || idx < 0) {
                        if (lyricReelAnim.running) lyricReelAnim.stop()
                        lyricReelCol.curIdx = -1
                        lyricReelCol.activeText = ""
                        lyricReelCol.nextText = ""
                        lyricReelCol.thirdText = ""
                        lyricReelCol.resetImmediate()
                        return
                    }

                    var list = dashboardContent.activeLyricsList
                    var newAct = (list && list[idx]) ? list[idx].text : ""
                    var newNext = (list && idx + 1 < list.length) ? list[idx + 1].text : ""
                    var newThird = (list && idx + 2 < list.length) ? list[idx + 2].text : ""

                    if (lyricReelCol.curIdx >= 0 && idx === lyricReelCol.curIdx + 1 && !lyricReelAnim.running) {
                        // Sequential advance: smoothly glide next lyric into current container
                        lyricReelCol.pendingActiveText = newAct
                        lyricReelCol.pendingNextText = newNext
                        lyricReelCol.thirdText = newThird
                        lyricReelCol.curIdx = idx
                        lyricReelAnim.shiftDistance = -(line1Text.implicitHeight + lyricReelCol.spacing)
                        lyricReelAnim.restart()
                    } else {
                        // Non-sequential change (seek, track skip, initial load): update directly
                        if (lyricReelAnim.running) lyricReelAnim.stop()
                        lyricReelCol.curIdx = idx
                        lyricReelCol.activeText = newAct
                        lyricReelCol.nextText = newNext
                        lyricReelCol.thirdText = ""
                        lyricReelCol.resetImmediate()
                    }
                }

                Connections {
                    target: dashboardContent
                    function onCurrentTrackIdChanged() {
                        syncedReelViewport.updateFromIndex(-1)
                    }
                    function onActiveLyricIndexChanged() {
                        syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                    }
                    function onHasSyncedLyricsChanged() {
                        syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                    }
                }

                Component.onCompleted: {
                    syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                }
            }
        }
    }
}

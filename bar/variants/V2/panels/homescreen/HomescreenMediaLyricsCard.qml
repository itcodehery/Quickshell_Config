import QtQuick
import QtQuick.Effects
import ".."
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../../modules"
import "../../motion"

// ── CINEMATIC BOTTOM-RIGHT MEDIA + LYRICS CARD (Detached from main dashboard card) ──
Item {
    id: mediaWithLyricsGroup
    required property var dashboardContent
    required property var root
    required property var panel
    required property var mprisSel
    required property var mprisArt
    required property var audioData

    readonly property bool isMediaVisible: mprisSel && mprisSel.player !== null
    readonly property bool isExpanded: unifiedMediaCard.isHovered
    // Collapsed chrome: leftMargin(8) + art(56 at h=72) + gap(10) + rightMargin(12) + 2px buffer
    readonly property real preferredCollapsedWidth: minimalView.showLyricLine
        ? Math.ceil(lyricLineText.implicitWidth + 88)
        : 0

    opacity: isMediaVisible ? (dashboardContent ? dashboardContent.mediaBoot : 1.0) : 0.0
    scale: isMediaVisible ? 1.0 : 0.96
    visible: opacity > 0.01
    z: 1

    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color baseInkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#a3e635"
    readonly property bool isLight: (root && root.isLightMode) ? true : false

    readonly property bool hasVibrantDom: Boolean(
        mprisArt && mprisArt.dominantColor
        && String(mprisArt.dominantColor) !== "#00000000"
        && String(mprisArt.dominantColor) !== "transparent"
    )
    readonly property color domCol: hasVibrantDom ? mprisArt.dominantColor : sealCol
    readonly property string artSrc: (mprisArt && mprisArt.source)
        ? mprisArt.source
        : ((mprisSel.player && mprisSel.player.trackArtUrl) ? mprisSel.player.trackArtUrl : "")

    // Deep atmospheric base tint (blurred album art layers on top for depth)
    readonly property color dockBg: hasVibrantDom
        ? Qt.rgba(
            paperCol.r * 0.58 + domCol.r * 0.42,
            paperCol.g * 0.58 + domCol.g * 0.42,
            paperCol.b * 0.58 + domCol.b * 0.42,
            0.94
          )
        : Qt.rgba(paperCol.r, paperCol.g, paperCol.b, isLight ? 0.95 : 0.92)

    readonly property bool useDarkCardText: !hasVibrantDom && artSrc === "" && isLight
    readonly property color inkCol: useDarkCardText ? "#141414" : "#f8fafc"
    readonly property color subInkCol: useDarkCardText ? Qt.rgba(0.08, 0.08, 0.08, 0.68) : Qt.rgba(1, 1, 1, 0.70)

    // Luminous accent lifted from dominant artwork color
    readonly property color accentCol: hasVibrantDom
        ? Qt.rgba(
            Math.min(1, domCol.r * 0.55 + 0.48),
            Math.min(1, domCol.g * 0.55 + 0.48),
            Math.min(1, domCol.b * 0.55 + 0.48),
            1.0
          )
        : sealCol

    readonly property color onAccentCol: {
        var luma = accentCol.r * 0.299 + accentCol.g * 0.587 + accentCol.b * 0.114
        return luma > 0.55 ? "#121212" : "#ffffff"
    }

    readonly property bool isPlaying: mprisSel.player && mprisSel.player.playbackState === MprisPlaybackState.Playing

    // Poll MPRIS position smoothly while playing so the progress bar & timestamps update live
    Timer {
        interval: 500
        repeat: true
        running: mediaWithLyricsGroup.visible && mediaWithLyricsGroup.isPlaying && Boolean(mprisSel.player)
        onTriggered: if (mprisSel.player) mprisSel.player.positionChanged()
    }

    readonly property var mp: dashboardContent ? dashboardContent.mprisPanel : null
    readonly property bool hasMprisLyrics: Boolean(
        mp && mp.lyricsTrackId !== "" && mp.lyricsTrackId === mp.currentTrackId && mp.lyricsList && mp.lyricsList.length > 0
    )
    readonly property bool hasDashLyrics: Boolean(
        dashboardContent && dashboardContent.hasSyncedLyrics && dashboardContent.activeLyricsList && dashboardContent.activeLyricsList.length > 0
    )
    readonly property bool hasLyrics: hasMprisLyrics || hasDashLyrics
    readonly property var activeLyricsList: hasMprisLyrics ? mp.lyricsList : (hasDashLyrics ? dashboardContent.activeLyricsList : [])
    readonly property int activeLyricIndex: hasMprisLyrics ? Math.max(0, mp.currentLyricIndex) : (hasDashLyrics ? Math.max(0, dashboardContent.activeLyricIndex) : -1)
    readonly property string currentLyricText: {
        if (hasLyrics && activeLyricIndex >= 0 && activeLyricIndex < activeLyricsList.length) {
            return activeLyricsList[activeLyricIndex].text || "♪"
        }
        if (mp && mp._isFetchingLyrics) return "Searching lyrics..."
        return ""
    }

    readonly property string trackTitleOnly: (mprisSel.player && mprisSel.player.trackTitle) ? mprisSel.player.trackTitle : "Not Playing"
    readonly property string trackArtistOnly: (mprisSel.player && mprisSel.player.trackArtist) ? mprisSel.player.trackArtist : ""
    readonly property string trackDisplayText: trackArtistOnly !== "" ? (trackArtistOnly + " — " + trackTitleOnly) : trackTitleOnly

    readonly property string playerDisplayName: {
        if (!mprisSel || !mprisSel.player) return ""
        var id = (mprisSel.player.identity || "").trim()
        var de = (mprisSel.player.desktopEntry || "").toLowerCase()
        var db = (mprisSel.player.dbusName || "").toLowerCase()
        var combined = (id + " " + de + " " + db).toLowerCase()
        if (combined.indexOf("spotify") !== -1) return "Spotify"
        if (combined.indexOf("zen") !== -1) return "Zen"
        if (combined.indexOf("firefox") !== -1) return "Firefox"
        if (combined.indexOf("chromium") !== -1) return "Chromium"
        if (combined.indexOf("chrome") !== -1) return "Chrome"
        if (combined.indexOf("brave") !== -1) return "Brave"
        if (combined.indexOf("vlc") !== -1) return "VLC"
        if (combined.indexOf("mpv") !== -1) return "mpv"
        if (id !== "") return id
        if (de !== "") return de.charAt(0).toUpperCase() + de.slice(1)
        return "Player"
    }

    function jumpToMediaWorkspace() {
        if (!mprisSel || !mprisSel.player) return
        var p = mprisSel.player
        var key = playerDisplayName.toLowerCase()
        var de = (p.desktopEntry || "").toLowerCase()
        var id = (p.identity || "").toLowerCase()
        var title = (p.trackTitle || "").toLowerCase().slice(0, 24)

        var useLua = (root && root.theme && root.theme.hyprUsesLua) ? "1" : "0"

        var py = [
            "import json, subprocess, sys",
            "key, de, ident, title, use_lua = sys.argv[1:6]",
            "clients = json.loads(subprocess.check_output(['hyprctl', 'clients', '-j']))",
            "tokens = [t for t in [key, de, ident] if t]",
            "best, best_score = None, 0",
            "for c in clients:",
            "    cls = (c.get('class') or '').lower()",
            "    icls = (c.get('initialClass') or '').lower()",
            "    ctitle = (c.get('title') or '').lower()",
            "    score = 0",
            "    for t in tokens:",
            "        if t in cls or t in icls:",
            "            score = max(score, 5)",
            "    if score > 0 and title and title in ctitle:",
            "        score += 10",
            "    elif score == 0 and title and len(title) >= 4 and title in ctitle:",
            "        score = 3",
            "    if score > best_score:",
            "        best, best_score = c, score",
            "if best:",
            "    ws = (best.get('workspace') or {}).get('id')",
            "    addr = best.get('address')",
            "    if ws and int(ws) > 0:",
            "        if use_lua == '1':",
            "            subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{ workspace = \"{ws}\" }})'])",
            "        else:",
            "            subprocess.run(['hyprctl', 'dispatch', 'workspace', str(ws)])",
            "    if addr and use_lua != '1':",
            "        subprocess.run(['hyprctl', 'dispatch', 'focuswindow', 'address:' + addr])"
        ].join("\n")

        if (root) root.dashboardExpanded = false
        Quickshell.execDetached(["python3", "-c", py, key, de, id, title, useLua])
    }

    function fmtTime(secs) {
        if (!secs || isNaN(secs) || secs < 0) return "0:00"
        var s = Math.floor(secs)
        var m = Math.floor(s / 60)
        var rem = s % 60
        return m + ":" + (rem < 10 ? "0" + rem : rem)
    }

    // ── SINGLE UNIFIED MEDIA CARD WITH ATMOSPHERIC BLURRED ARTWORK BACKDROP ──
    ClippingRectangle {
        id: unifiedMediaCard
        anchors.fill: parent
        radius: isHovered ? 24 : 18
        Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        color: mediaWithLyricsGroup.dockBg
        Behavior on color { ColorAnimation { duration: 350 } }

        HoverHandler {
            id: cardHover
        }
        readonly property bool isHovered: cardHover.hovered

        // Blurred full-bleed album artwork ambiance
        Item {
            anchors.fill: parent
            visible: mediaWithLyricsGroup.artSrc !== ""
            z: 0

            Image {
                id: backdropArtImg
                anchors.fill: parent
                source: mediaWithLyricsGroup.artSrc
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                opacity: unifiedMediaCard.isHovered ? 0.82 : 0.55
                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.92
                    blurMax: 52
                    saturation: 0.40
                    brightness: -0.18
                }
            }

            // Directional cinematic scrim for rich contrast and glowing color depth
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(0.05, 0.06, 0.07, unifiedMediaCard.isHovered ? 0.72 : 0.62)
                    }
                    GradientStop {
                        position: 0.52
                        color: Qt.rgba(0.05, 0.06, 0.07, unifiedMediaCard.isHovered ? 0.60 : 0.52)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(
                            mediaWithLyricsGroup.domCol.r * 0.22,
                            mediaWithLyricsGroup.domCol.g * 0.22,
                            mediaWithLyricsGroup.domCol.b * 0.22,
                            unifiedMediaCard.isHovered ? 0.74 : 0.64
                        )
                    }
                }
            }

            // Subtle radial spotlight glow behind right controls
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: -40
                anchors.verticalCenter: parent.verticalCenter
                width: 200
                height: 200
                radius: 100
                color: mediaWithLyricsGroup.accentCol
                opacity: unifiedMediaCard.isHovered ? 0.14 : 0.06
                Behavior on opacity { NumberAnimation { duration: 260 } }
            }
        }

        // ── LEFT: INTERACTIVE SQUARE ALBUM ARTWORK ──
        Item {
            id: artContainer
            anchors.left: parent.left
            anchors.leftMargin: unifiedMediaCard.isHovered ? 12 : 8
            anchors.top: parent.top
            anchors.topMargin: unifiedMediaCard.isHovered ? 12 : 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: unifiedMediaCard.isHovered ? 12 : 8
            width: height
            z: 4

            Behavior on anchors.leftMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            ClippingRectangle {
                id: cardAlbumArt
                anchors.fill: parent
                radius: unifiedMediaCard.isHovered ? 16 : 13
                Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                color: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.10)
                scale: artMa.pressed ? 0.94 : (artMa.containsMouse ? 1.03 : 1.0)
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                Image {
                    anchors.fill: parent
                    source: mediaWithLyricsGroup.artSrc
                    fillMode: Image.PreserveAspectCrop
                    visible: mediaWithLyricsGroup.artSrc !== ""
                    asynchronous: true
                    smooth: true
                }

                IconText {
                    anchors.centerIn: parent
                    text: "music_note"
                    font.pixelSize: unifiedMediaCard.isHovered ? 30 : 22
                    color: mediaWithLyricsGroup.accentCol
                    visible: mediaWithLyricsGroup.artSrc === ""
                }

                // Subtle hover overlay to jump to player window
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.36)
                    opacity: (unifiedMediaCard.isHovered && artMa.containsMouse) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "open_in_new"
                        color: "#ffffff"
                        font.pixelSize: 20
                    }
                }

                MouseArea {
                    id: artMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mediaWithLyricsGroup.jumpToMediaWorkspace()
                }
            }
        }

        // ── RIGHT STAGE: COLLAPSED LISTTILE <-> EXPANDED CINEMATIC CONTROLS ──
        Item {
            id: rightStage
            anchors.left: artContainer.right
            anchors.leftMargin: unifiedMediaCard.isHovered ? 14 : 10
            anchors.right: parent.right
            anchors.rightMargin: unifiedMediaCard.isHovered ? 14 : 12
            anchors.top: parent.top
            anchors.topMargin: unifiedMediaCard.isHovered ? 11 : 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: unifiedMediaCard.isHovered ? 11 : 6
            clip: true
            z: 4

            Behavior on anchors.leftMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on anchors.rightMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on anchors.topMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // ── DEFAULT (NON-HOVERED) VIEW: Compact listtile (Song, Artist, optional Synced Lyric) ──
            Column {
                id: minimalView
                readonly property bool showLyricLine: mediaWithLyricsGroup.currentLyricText !== ""
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: showLyricLine ? 1 : 2
                opacity: unifiedMediaCard.isHovered ? 0.0 : 1.0
                scale: unifiedMediaCard.isHovered ? 0.97 : 1.0
                visible: opacity > 0.01
                enabled: !unifiedMediaCard.isHovered

                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                Text {
                    width: parent.width
                    text: mediaWithLyricsGroup.trackTitleOnly
                    color: mediaWithLyricsGroup.inkCol
                    font.family: "Google Sans"
                    font.pixelSize: minimalView.showLyricLine ? 14 : 15
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    width: parent.width
                    visible: mediaWithLyricsGroup.trackArtistOnly !== ""
                    text: mediaWithLyricsGroup.trackArtistOnly
                    color: mediaWithLyricsGroup.subInkCol
                    font.family: "Google Sans"
                    font.pixelSize: minimalView.showLyricLine ? 11 : 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    id: lyricLineText
                    width: parent.width
                    visible: minimalView.showLyricLine
                    text: mediaWithLyricsGroup.currentLyricText
                    color: mediaWithLyricsGroup.accentCol
                    font.family: "Google Sans"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // ── HOVERED (EXPANDED) VIEW: Full Cinematic Material 3 Media Player ──
            Item {
                id: controlsView
                anchors.fill: parent
                opacity: unifiedMediaCard.isHovered ? 1.0 : 0.0
                scale: unifiedMediaCard.isHovered ? 1.0 : 0.97
                visible: opacity > 0.01
                enabled: unifiedMediaCard.isHovered

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                // ── ROW 1 (TOP): TITLE + ARTIST ON LEFT | GLASS ACTION PILLS ON RIGHT ──
                Item {
                    id: topRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 36

                    Column {
                        anchors.left: parent.left
                        anchors.right: rightMetaCluster.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: mediaWithLyricsGroup.trackTitleOnly
                            color: mediaWithLyricsGroup.inkCol
                            font.family: "Google Sans"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            width: parent.width
                            visible: mediaWithLyricsGroup.trackArtistOnly !== ""
                            text: mediaWithLyricsGroup.trackArtistOnly
                            color: mediaWithLyricsGroup.subInkCol
                            font.family: "Google Sans"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Top-Right Frosted Action Pills (Float Lyrics + Volume)
                    Row {
                        id: rightMetaCluster
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 2
                        spacing: 6

                        Rectangle {
                            id: floatTogglePill
                            height: 24
                            width: floatToggleRow.implicitWidth + 16
                            radius: 12
                            visible: Boolean(mediaWithLyricsGroup.mp)
                            readonly property bool isFloating: Boolean(mediaWithLyricsGroup.mp && mediaWithLyricsGroup.mp.showingLyrics)
                            color: isFloating
                                ? mediaWithLyricsGroup.accentCol
                                : (floatToggleMa.containsMouse
                                    ? Qt.rgba(1, 1, 1, 0.20)
                                    : Qt.rgba(1, 1, 1, 0.11))
                            border.width: 0
                            scale: floatToggleMa.pressed ? 0.93 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            Row {
                                id: floatToggleRow
                                anchors.centerIn: parent
                                spacing: 4

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "lyrics"
                                    color: floatTogglePill.isFloating ? mediaWithLyricsGroup.onAccentCol : mediaWithLyricsGroup.accentCol
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: floatTogglePill.isFloating ? "Floating" : "Lyrics"
                                    color: floatTogglePill.isFloating ? mediaWithLyricsGroup.onAccentCol : mediaWithLyricsGroup.inkCol
                                    font.family: "Google Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: floatToggleMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (mediaWithLyricsGroup.mp) {
                                        mediaWithLyricsGroup.mp.showingLyrics = !mediaWithLyricsGroup.mp.showingLyrics
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: volPill
                            height: 24
                            width: audioPillRow.implicitWidth + 16
                            radius: 12
                            color: audioOutMa.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.20)
                                : Qt.rgba(1, 1, 1, 0.11)
                            border.width: 0
                            scale: audioOutMa.pressed ? 0.93 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            Row {
                                id: audioPillRow
                                anchors.centerIn: parent
                                spacing: 4

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (audioData && audioData.muted) ? "volume_off" : ((audioData && audioData.isHeadphone) ? "headphones" : "volume_up")
                                    color: (audioData && audioData.muted) ? mediaWithLyricsGroup.accentCol : mediaWithLyricsGroup.inkCol
                                    font.pixelSize: 13
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (audioData && audioData.volume !== undefined) ? (Math.round(audioData.volume) + "%") : "Audio"
                                    color: mediaWithLyricsGroup.inkCol
                                    font.family: "Google Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: audioOutMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                    } else {
                                        dashboardContent.activeDetailView = "volume"
                                    }
                                }
                                onWheel: (wheel) => {
                                    if (wheel.angleDelta.y > 0) {
                                        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"])
                                    } else if (wheel.angleDelta.y < 0) {
                                        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"])
                                    }
                                }
                            }
                        }
                    }
                }

                // ── ROW 2 (MIDDLE): MATERIAL 3 EXPRESSIVE WAVY PROGRESS SCRUBBER ──
                Item {
                    id: scrubberRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 2
                    height: 22

                    readonly property real posSecs: mprisSel.player ? (mprisSel.player.position || 0) : 0
                    readonly property real lenSecs: mprisSel.player ? (mprisSel.player.length || 0) : 0
                    readonly property real liveRatio: (lenSecs > 0) ? Math.max(0, Math.min(1, posSecs / lenSecs)) : 0
                    readonly property real displayRatio: seekArea.dragging ? seekArea.dragRatio : liveRatio
                    readonly property real displayPosSecs: seekArea.dragging ? (seekArea.dragRatio * lenSecs) : posSecs
                    readonly property string elapsedStr: mediaWithLyricsGroup.fmtTime(displayPosSecs)
                    readonly property string remainingStr: lenSecs > 0
                        ? ("-" + mediaWithLyricsGroup.fmtTime(Math.max(0, lenSecs - displayPosSecs)))
                        : "0:00"

                    Text {
                        id: elapsedLbl
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        text: scrubberRow.elapsedStr
                        color: mediaWithLyricsGroup.subInkCol
                        font.family: "Google Sans"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Text {
                        id: remainingLbl
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        horizontalAlignment: Text.AlignRight
                        text: scrubberRow.remainingStr
                        color: mediaWithLyricsGroup.subInkCol
                        font.family: "Google Sans"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Item {
                        id: waveTrackBox
                        anchors.left: elapsedLbl.right
                        anchors.leftMargin: 4
                        anchors.right: remainingLbl.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        height: 22

                        Canvas {
                            id: wavySeekCanvas
                            anchors.fill: parent
                            property real progress: scrubberRow.displayRatio
                            property real wavePhase: 0.0
                            property real waveAmp: (mediaWithLyricsGroup.isPlaying && !seekArea.dragging) ? 2.6 : 0.0
                            readonly property color activeC: mediaWithLyricsGroup.accentCol
                            readonly property color trackC: mediaWithLyricsGroup.inkCol

                            Behavior on waveAmp { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                            NumberAnimation on wavePhase {
                                from: 0.0
                                to: Math.PI * 2
                                duration: 1500
                                loops: Animation.Infinite
                                running: unifiedMediaCard.isHovered && mediaWithLyricsGroup.isPlaying && !seekArea.dragging
                            }

                            onProgressChanged: requestPaint()
                            onWavePhaseChanged: requestPaint()
                            onWaveAmpChanged: requestPaint()
                            onActiveCChanged: requestPaint()
                            onWidthChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                if (width <= 8) return

                                var cy = height / 2
                                var pad = 4
                                var usableW = width - pad * 2
                                var thumbX = pad + usableW * Math.max(0, Math.min(1, progress))
                                var gap = 6

                                // Unplayed track (right of thumb)
                                if (thumbX + gap < width - pad) {
                                    ctx.beginPath()
                                    ctx.moveTo(thumbX + gap, cy)
                                    ctx.lineTo(width - pad, cy)
                                    ctx.strokeStyle = Qt.rgba(trackC.r, trackC.g, trackC.b, 0.22)
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }

                                // Played wavy line (left of thumb)
                                var endX = Math.max(pad, thumbX - gap)
                                if (endX > pad + 1) {
                                    ctx.beginPath()
                                    var freq = 0.26
                                    for (var x = pad; x <= endX; x += 2) {
                                        // Taper wave near endpoints so it joins smoothly
                                        var distFromEnd = Math.min(x - pad, endX - x)
                                        var taper = Math.min(1.0, distFromEnd / 10.0)
                                        var y = cy + Math.sin(x * freq - wavePhase) * waveAmp * taper
                                        if (x === pad) ctx.moveTo(x, y)
                                        else ctx.lineTo(x, y)
                                    }
                                    ctx.strokeStyle = activeC
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.stroke()
                                }
                            }
                        }

                        // Vertical capsule playhead thumb
                        Rectangle {
                            id: seekThumb
                            x: 4 + (waveTrackBox.width - 8) * scrubberRow.displayRatio - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: seekArea.containsMouse || seekArea.dragging ? 5 : 4
                            height: seekArea.containsMouse || seekArea.dragging ? 16 : 13
                            radius: width / 2
                            color: mediaWithLyricsGroup.accentCol
                            Behavior on width { NumberAnimation { duration: 120 } }
                            Behavior on height { NumberAnimation { duration: 120 } }
                        }

                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            property bool dragging: false
                            property real dragRatio: 0

                            function ratioFromX(mouseX) {
                                var usable = Math.max(1, waveTrackBox.width - 8)
                                return Math.max(0, Math.min(1, (mouseX - 4) / usable))
                            }
                            function commitSeek(frac) {
                                if (mprisSel.player && mprisSel.player.canSeek && mprisSel.player.length > 0) {
                                    mprisSel.player.position = frac * mprisSel.player.length
                                }
                            }
                            onPressed: (mouse) => {
                                dragging = true
                                dragRatio = ratioFromX(mouse.x)
                                commitSeek(dragRatio)
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    dragRatio = ratioFromX(mouse.x)
                                    commitSeek(dragRatio)
                                }
                            }
                            onReleased: (mouse) => {
                                dragRatio = ratioFromX(mouse.x)
                                commitSeek(dragRatio)
                                dragging = false
                            }
                            onCanceled: dragging = false
                        }
                    }
                }

                // ── ROW 3 (BOTTOM): SOURCE/LYRIC STATUS ON LEFT | SCULPTED TRANSPORT CONTROLS ON RIGHT ──
                Item {
                    id: bottomRow
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 32

                    // Left: Player badge + subtle live lyric preview
                    Row {
                        anchors.left: parent.left
                        anchors.right: transportCluster.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Rectangle {
                            id: sourceBadge
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22
                            width: sourceBadgeRow.implicitWidth + 14
                            radius: 11
                            color: sourceMa.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.16)
                                : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Row {
                                id: sourceBadgeRow
                                anchors.centerIn: parent
                                spacing: 5

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: mediaWithLyricsGroup.isPlaying ? mediaWithLyricsGroup.accentCol : mediaWithLyricsGroup.subInkCol
                                    opacity: mediaWithLyricsGroup.isPlaying ? 1.0 : 0.6

                                    SequentialAnimation on opacity {
                                        running: unifiedMediaCard.isHovered && mediaWithLyricsGroup.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 0.35; duration: 750; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 0.35; to: 1.0; duration: 750; easing.type: Easing.InOutSine }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: mediaWithLyricsGroup.playerDisplayName
                                    color: mediaWithLyricsGroup.inkCol
                                    opacity: 0.88
                                    font.family: "Google Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                id: sourceMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mediaWithLyricsGroup.jumpToMediaWorkspace()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, parent.width - sourceBadge.width - parent.spacing)
                            visible: mediaWithLyricsGroup.currentLyricText !== "" && width > 40
                            text: mediaWithLyricsGroup.currentLyricText
                            color: mediaWithLyricsGroup.accentCol
                            opacity: 0.90
                            font.family: "Google Sans"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            font.italic: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Right: Sculpted Material 3 Transport Controls
                    Row {
                        id: transportCluster
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            anchors.verticalCenter: parent.verticalCenter
                            color: prevMa.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.20)
                                : Qt.rgba(1, 1, 1, 0.09)
                            scale: prevMa.pressed ? 0.88 : (prevMa.containsMouse ? 1.06 : 1.0)
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            IconText {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                color: mediaWithLyricsGroup.inkCol
                                font.pixelSize: 18
                            }
                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mprisSel.player && mprisSel.player.canGoPrevious) mprisSel.player.previous()
                            }
                        }

                        // Hero Morphing Play/Pause Button (pill when paused -> expressive squircle when playing)
                        Rectangle {
                            width: mediaWithLyricsGroup.isPlaying ? 46 : 52
                            height: 32
                            radius: mediaWithLyricsGroup.isPlaying ? 11 : 16
                            anchors.verticalCenter: parent.verticalCenter
                            color: mediaWithLyricsGroup.accentCol
                            scale: playMa.pressed ? 0.90 : (playMa.containsMouse ? 1.05 : 1.0)
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                            Behavior on radius { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            IconText {
                                anchors.centerIn: parent
                                text: mediaWithLyricsGroup.isPlaying ? "pause" : "play_arrow"
                                color: mediaWithLyricsGroup.onAccentCol
                                font.pixelSize: 20
                            }
                            MouseArea {
                                id: playMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mprisSel.player) mprisSel.player.togglePlaying()
                            }
                        }

                        Rectangle {
                            width: 30; height: 30; radius: 15
                            anchors.verticalCenter: parent.verticalCenter
                            color: nextMa.containsMouse
                                ? Qt.rgba(1, 1, 1, 0.20)
                                : Qt.rgba(1, 1, 1, 0.09)
                            scale: nextMa.pressed ? 0.88 : (nextMa.containsMouse ? 1.06 : 1.0)
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            IconText {
                                anchors.centerIn: parent
                                text: "skip_next"
                                color: mediaWithLyricsGroup.inkCol
                                font.pixelSize: 18
                            }
                            MouseArea {
                                id: nextMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (mprisSel.player && mprisSel.player.canGoNext) mprisSel.player.next()
                            }
                        }
                    }
                }
            }
        }
    }
}

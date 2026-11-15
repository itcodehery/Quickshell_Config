import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../../modules"
import "../../motion"

// ── COMPACT UNIFIED BOTTOM MEDIA + LYRICS CARD (Detached from main dashboard card) ──
Item {
    id: mediaWithLyricsGroup
    required property var dashboardContent
    required property var root
    required property var panel
    required property var mprisSel
    required property var mprisArt
    required property var audioData

    readonly property bool isMediaVisible: mprisSel && mprisSel.player !== null

    opacity: isMediaVisible ? 1.0 : 0.0
    scale: isMediaVisible ? 1.0 : 0.96
    visible: opacity > 0.01
    z: 5

    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#a3e635"
    readonly property bool isLight: (root && root.isLightMode) ? true : false

    readonly property color domCol: (mprisArt && mprisArt.hasDominantColor) ? mprisArt.dominantColor : sealCol
    readonly property bool hasVibrantDom: (mprisArt && mprisArt.hasDominantColor) ? true : false

    readonly property color dockBg: hasVibrantDom
        ? Qt.rgba(
            paperCol.r * 0.65 + domCol.r * 0.35,
            paperCol.g * 0.65 + domCol.g * 0.35,
            paperCol.b * 0.65 + domCol.b * 0.35,
            isLight ? 0.94 : 0.88
          )
        : Qt.rgba(paperCol.r, paperCol.g, paperCol.b, isLight ? 0.94 : 0.88)

    readonly property color accentCol: hasVibrantDom
        ? Qt.rgba(
            Math.min(1, domCol.r * 0.55 + 0.45),
            Math.min(1, domCol.g * 0.55 + 0.45),
            Math.min(1, domCol.b * 0.55 + 0.45),
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
    readonly property string currentLyricText: {
        if (hasMprisLyrics) {
            var mIdx = Math.max(0, mp.currentLyricIndex)
            if (mIdx < mp.lyricsList.length) {
                return mp.lyricsList[mIdx].text || "♪"
            }
        }
        if (hasDashLyrics) {
            var dIdx = Math.max(0, dashboardContent.currentLyricIndex)
            if (dIdx < dashboardContent.activeLyricsList.length) {
                return dashboardContent.activeLyricsList[dIdx].text || "♪"
            }
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

    // Single Unified Compact Card for both Media Player & Lyrics
    Rectangle {
        id: unifiedMediaCard
        anchors.fill: parent
        radius: 22
        color: mediaWithLyricsGroup.dockBg
        border.width: 0

        // Left: Square Album Art spanning the combined height of the media bar + lyrics bar
        ClippingRectangle {
            id: cardAlbumArt
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            width: height
            radius: 14
            color: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.10)

            readonly property string artSrc: (mprisArt && mprisArt.source) ? mprisArt.source : ((mprisSel.player && mprisSel.player.trackArtUrl) ? mprisSel.player.trackArtUrl : "")

            Image {
                anchors.fill: parent
                source: cardAlbumArt.artSrc
                fillMode: Image.PreserveAspectCrop
                visible: cardAlbumArt.artSrc !== ""
                asynchronous: true
            }

            IconText {
                anchors.centerIn: parent
                text: "music_note"
                font.pixelSize: 24
                color: mediaWithLyricsGroup.accentCol
                visible: cardAlbumArt.artSrc === ""
            }
        }

        Column {
            anchors.left: cardAlbumArt.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            spacing: 6

            // ── ROW 1: COMPACT MEDIA PLAYER CONTROLS & SEEK BAR (36px) ──
            Item {
                width: parent.width
                height: 36

                // Left/Center: Compact Interactive Progress Pill
                Rectangle {
                    id: seekBarPill
                    anchors.left: parent.left
                    anchors.right: rightControlsCluster.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    radius: 13
                    color: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.08)
                    clip: true

                    readonly property real posSecs: mprisSel.player ? mprisSel.player.position : 0
                    readonly property real lenSecs: mprisSel.player ? mprisSel.player.length : 0
                    readonly property real ratio: (lenSecs > 0) ? Math.max(0, Math.min(1, posSecs / lenSecs)) : 0
                    readonly property string elapsedStr: mediaWithLyricsGroup.fmtTime(posSecs)
                    readonly property string remainingStr: lenSecs > 0
                        ? ("-" + mediaWithLyricsGroup.fmtTime(Math.max(0, lenSecs - posSecs)))
                        : "0:00"

                    Component {
                        id: trackBadgeComp
                        Row {
                            id: badgeRow
                            property color titleColor: mediaWithLyricsGroup.inkCol
                            property color chipBg: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.12)
                            property color chipTextColor: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.85)
                            spacing: 6
                            readonly property real maxTotalW: Math.max(80, seekBarPill.width - 116)
                            readonly property real chipReserve: mediaWithLyricsGroup.trackArtistOnly !== "" ? Math.min(artistText.implicitWidth + 14, maxTotalW * 0.42) : 0

                            Text {
                                id: titleText
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, Math.max(40, badgeRow.maxTotalW - badgeRow.chipReserve - (badgeRow.chipReserve > 0 ? badgeRow.spacing : 0)))
                                text: mediaWithLyricsGroup.trackTitleOnly
                                color: badgeRow.titleColor
                                font.family: "Genova"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Rectangle {
                                visible: mediaWithLyricsGroup.trackArtistOnly !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                width: Math.min(artistText.implicitWidth + 12, badgeRow.maxTotalW * 0.42)
                                radius: 8
                                color: badgeRow.chipBg

                                Text {
                                    id: artistText
                                    anchors.centerIn: parent
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignHCenter
                                    text: mediaWithLyricsGroup.trackArtistOnly
                                    color: badgeRow.chipTextColor
                                    font.family: "Genova"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: seekBarPill.elapsedStr
                        color: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.75)
                        font.family: "Genova"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Loader {
                        anchors.centerIn: parent
                        sourceComponent: trackBadgeComp
                        onLoaded: {
                            item.titleColor = mediaWithLyricsGroup.inkCol
                            item.chipBg = Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.12)
                            item.chipTextColor = Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.85)
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: seekBarPill.remainingStr
                        color: Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.75)
                        font.family: "Genova"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }

                    Item {
                        id: progressClip
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * seekBarPill.ratio
                        clip: true

                        Rectangle {
                            width: seekBarPill.width
                            height: seekBarPill.height
                            radius: seekBarPill.radius
                            color: mediaWithLyricsGroup.accentCol
                            opacity: 0.92
                        }

                        Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: seekBarPill.elapsedStr
                            color: mediaWithLyricsGroup.onAccentCol
                            font.family: "Genova"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }

                        Loader {
                            x: Math.round((seekBarPill.width - width) / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            sourceComponent: trackBadgeComp
                            onLoaded: {
                                item.titleColor = mediaWithLyricsGroup.onAccentCol
                                item.chipBg = Qt.rgba(mediaWithLyricsGroup.onAccentCol.r, mediaWithLyricsGroup.onAccentCol.g, mediaWithLyricsGroup.onAccentCol.b, 0.20)
                                item.chipTextColor = mediaWithLyricsGroup.onAccentCol
                            }
                        }

                        Text {
                            x: seekBarPill.width - width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: seekBarPill.remainingStr
                            color: mediaWithLyricsGroup.onAccentCol
                            font.family: "Genova"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        function seekToMouse(mouseX) {
                            if (mprisSel.player && mprisSel.player.canSeek && mprisSel.player.length > 0) {
                                var frac = Math.max(0, Math.min(1, mouseX / seekBarPill.width))
                                mprisSel.player.position = frac * mprisSel.player.length
                            }
                        }
                        onPressed: (mouse) => seekToMouse(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) seekToMouse(mouse.x) }
                    }
                }

                // Right: Transport Controls + "See on <Player>" + Audio Output Pill
                Row {
                    id: rightControlsCluster
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: prevMa.containsMouse
                            ? Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.14)
                            : Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.06)
                        scale: prevMa.pressed ? 0.90 : 1.0
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                        IconText {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            color: mediaWithLyricsGroup.inkCol
                            font.pixelSize: 16
                        }
                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mprisSel.player && mprisSel.player.canGoPrevious) mprisSel.player.previous()
                        }
                    }

                    Rectangle {
                        width: 44; height: 28; radius: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: mediaWithLyricsGroup.accentCol
                        scale: playMa.pressed ? 0.92 : (playMa.containsMouse ? 1.04 : 1.0)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                        IconText {
                            anchors.centerIn: parent
                            text: mediaWithLyricsGroup.isPlaying ? "pause" : "play_arrow"
                            color: mediaWithLyricsGroup.onAccentCol
                            font.pixelSize: 18
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
                        width: 28; height: 28; radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: nextMa.containsMouse
                            ? Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.14)
                            : Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.06)
                        scale: nextMa.pressed ? 0.90 : 1.0
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                        IconText {
                            anchors.centerIn: parent
                            text: "skip_next"
                            color: mediaWithLyricsGroup.inkCol
                            font.pixelSize: 16
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mprisSel.player && mprisSel.player.canGoNext) mprisSel.player.next()
                        }
                    }

                    Rectangle {
                        height: 26
                        width: seeOnRow.implicitWidth + 16
                        radius: 13
                        visible: mediaWithLyricsGroup.playerDisplayName !== ""
                        color: seeOnMa.containsMouse
                            ? Qt.rgba(mediaWithLyricsGroup.accentCol.r, mediaWithLyricsGroup.accentCol.g, mediaWithLyricsGroup.accentCol.b, 0.26)
                            : Qt.rgba(mediaWithLyricsGroup.accentCol.r, mediaWithLyricsGroup.accentCol.g, mediaWithLyricsGroup.accentCol.b, 0.14)
                        scale: seeOnMa.pressed ? 0.94 : 1.0
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                        Row {
                            id: seeOnRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "open_in_new"
                                color: mediaWithLyricsGroup.accentCol
                                font.pixelSize: 13
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "See on " + mediaWithLyricsGroup.playerDisplayName
                                color: mediaWithLyricsGroup.inkCol
                                font.family: "Genova"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: seeOnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mediaWithLyricsGroup.jumpToMediaWorkspace()
                        }
                    }

                    Rectangle {
                        height: 26
                        width: audioPillRow.implicitWidth + 16
                        radius: 13
                        color: audioOutMa.containsMouse
                            ? Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.14)
                            : Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.08)
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            id: audioPillRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (audioData && audioData.isMuted) ? "volume_off" : ((audioData && audioData.isHeadphone) ? "headphones" : "volume_up")
                                color: mediaWithLyricsGroup.inkCol
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (audioData && audioData.volume !== undefined) ? (Math.round(audioData.volume) + "%") : "Audio"
                                color: mediaWithLyricsGroup.inkCol
                                font.family: "Genova"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: audioOutMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dashboardContent.activeDetailView = "volume"
                        }
                    }
                }
            }

            // ── ROW 2: COMPACT SYNCED LYRICS STRIP (26px) ──
            Item {
                width: parent.width
                height: 26

                Rectangle {
                    id: lyricIconBadge
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    radius: 12
                    color: Qt.rgba(mediaWithLyricsGroup.accentCol.r, mediaWithLyricsGroup.accentCol.g, mediaWithLyricsGroup.accentCol.b, 0.16)

                    IconText {
                        anchors.centerIn: parent
                        text: "music_note"
                        font.pixelSize: 13
                        color: mediaWithLyricsGroup.accentCol
                    }
                }

                Text {
                    anchors.left: lyricIconBadge.right
                    anchors.leftMargin: 10
                    anchors.right: floatTogglePill.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: mediaWithLyricsGroup.currentLyricText !== ""
                        ? mediaWithLyricsGroup.currentLyricText
                        : "No synced lyrics"
                    color: mediaWithLyricsGroup.currentLyricText !== ""
                        ? mediaWithLyricsGroup.inkCol
                        : Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.45)
                    font.family: "Genova"
                    font.pixelSize: 12
                    font.weight: mediaWithLyricsGroup.currentLyricText !== "" ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    id: floatTogglePill
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: floatToggleRow.implicitWidth + 16
                    radius: 12
                    border.width: 0
                    visible: Boolean(mediaWithLyricsGroup.mp)
                    readonly property bool isFloating: Boolean(mediaWithLyricsGroup.mp && mediaWithLyricsGroup.mp.showingLyrics)
                    color: isFloating
                        ? mediaWithLyricsGroup.accentCol
                        : (floatToggleMa.containsMouse
                            ? Qt.rgba(mediaWithLyricsGroup.accentCol.r, mediaWithLyricsGroup.accentCol.g, mediaWithLyricsGroup.accentCol.b, 0.22)
                            : Qt.rgba(mediaWithLyricsGroup.inkCol.r, mediaWithLyricsGroup.inkCol.g, mediaWithLyricsGroup.inkCol.b, 0.08))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: floatToggleRow
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "lyrics"
                            font.pixelSize: 12
                            color: floatTogglePill.isFloating ? mediaWithLyricsGroup.onAccentCol : mediaWithLyricsGroup.accentCol
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: floatTogglePill.isFloating ? "Floating" : "Float"
                            font.family: "Genova"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: floatTogglePill.isFloating ? mediaWithLyricsGroup.onAccentCol : mediaWithLyricsGroup.inkCol
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
            }
        }
    }
}

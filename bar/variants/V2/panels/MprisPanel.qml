import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../modules"

PanelWindow {
    id: mprisPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-mpris"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    // ── pick a REAL active player ───────────────────────────────────
    // Selection (incl. ghost-filtering) lives in MprisSelect so the bar
    // widget and this panel always agree on the active player.
    MprisSelect { id: sel }
    readonly property var  player:  sel.player
    readonly property bool active:  sel.active
    readonly property bool playing: sel.playing
    MprisArtwork { id: artwork; player: mprisPanel.player }

    readonly property string playerName: {
        if (!player) return ""
        var n = player.identity || player.dbusName || ""
        return n.replace(/^org\.mpris\.MediaPlayer2\./, "")
    }

    // ── lyrics state ────────────────────────────────────────────────
    property var lyricsList: []
    property int currentLyricIndex: -1
    property bool showingLyrics: false

    property string currentTrackId: mprisPanel.player ? ((mprisPanel.player.trackTitle || "") + "||" + (mprisPanel.player.trackArtist || "")) : ""
    onCurrentTrackIdChanged: {
        var title = mprisPanel.player ? (mprisPanel.player.trackTitle || "") : ""
        var artist = mprisPanel.player ? (mprisPanel.player.trackArtist || "") : ""
        lyricsList = []
        currentLyricIndex = -1
        
        if (title === "") return
        
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://lrclib.net/api/get?track_name=" + encodeURIComponent(title) + "&artist_name=" + encodeURIComponent(artist));
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        var synced = data.syncedLyrics;
                        if (synced) {
                            var lines = synced.split('\n');
                            var result = [];
                            for (var i = 0; i < lines.length; i++) {
                                var line = lines[i];
                                var match = line.match(/^\[(\d+):(\d+\.\d+)\](.*)/);
                                if (match) {
                                    var time = parseInt(match[1]) * 60 + parseFloat(match[2]);
                                    var text = match[3].trim();
                                    if (text !== "") {
                                        result.push({time: time, text: text});
                                    }
                                }
                            }
                            lyricsList = result;
                        }
                    } catch(e) {}
                }
            }
        }
        xhr.send();
    }
    
    onCurPosChanged: {
        var idx = -1;
        for (var i = 0; i < lyricsList.length; i++) {
            if (mprisPanel.curPos >= lyricsList[i].time) {
                idx = i;
            } else {
                break;
            }
        }
        if (idx !== currentLyricIndex) {
            currentLyricIndex = idx;
        }
    }

    // ── live position polling (for the progress bar) ────────────────
    // Quickshell only refreshes `position` sporadically, so we extrapolate
    // locally while playing and resync whenever the player reports a fresh value.
    property real curPos: 0
    property real curLen: 0
    property real _lastRead: -1
    Timer {
        interval: 500; repeat: true
        running: (mprisPanel.visible || showingLyrics) && mprisPanel.active
        triggeredOnStart: true
        onTriggered: {
            if (!mprisPanel.player) return
            var p = mprisPanel.player.position || 0
            mprisPanel.curLen = mprisPanel.player.length || 0
            if (Math.abs(p - mprisPanel._lastRead) > 0.05) {
                mprisPanel.curPos = p            // player gave a fresh value
                mprisPanel._lastRead = p
            } else if (mprisPanel.playing) {
                var cap = mprisPanel.curLen > 0 ? mprisPanel.curLen : p + 1e9
                mprisPanel.curPos = Math.min(cap, mprisPanel.curPos + 0.5)
            }
        }
    }
    onPlayingChanged: { _lastRead = -1 }   // force a resync on play/pause
    function fmtTime(s) {
        if (!s || s < 0) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec)
    }

    // ── visualizer state ────────────────────────────────────────────
    readonly property int bands: 12
    property var levels:  []     // smoothed, what we draw
    property var targets: []     // raw cava input
    property real phase: 0       // drives the synthetic idle wave
    property var cavaPalette: []

    function fallbackCavaPalette() {
        cavaPalette = [
            root.color06, root.color04, root.color05, root.color07,
            root.color03, root.color01
        ]
    }

    function parseCavaTheme(raw) {
        var text = String(raw || "")
        var colors = []
        for (var i = 1; i <= 16; i++) {
            var re = new RegExp("^\\s*gradient_color_" + i
                + "\\s*=\\s*['\\\"]?\\s*(#[0-9a-fA-F]{6,8})", "m")
            var match = text.match(re)
            if (match) colors.push(match[1])
        }
        if (colors.length >= 2) cavaPalette = colors
        else fallbackCavaPalette()
    }

    Component.onCompleted: {
        var a = [], b = []
        for (var i = 0; i < bands; i++) { a.push(0.06); b.push(0.0) }
        levels = a; targets = b
        fallbackCavaPalette()
    }

    FileView {
        id: cavaThemeFile
        path: root.omarchyCurrentRoot + "/theme/cava_theme"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: mprisPanel.parseCavaTheme(cavaThemeFile.text())
        onLoadFailed: mprisPanel.fallbackCavaPalette()
    }

    property real reveal: root.mprisVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.mprisVisible ? 160 : 120
            easing.type: root.mprisVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.mprisVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── cava: real system-audio spectrum (runs only while playing) ──
    // Native PipeWire capture avoids the Pulse compatibility buffer. CAVA's
    // default noise reduction is intentionally very slow (77); a lower value
    // plus direct samples keeps the panel visually close to the audible beat.
    Process {
        id: cava
        running: mprisPanel.visible && mprisPanel.playing
        command: ["bash", "-c",
            "command -v cava >/dev/null 2>&1 || exit 0; " +
            "exec cava -p <(printf '%s\\n' " +
            "'[general]' 'bars = 12' 'framerate = 30' 'autosens = 1' 'sleep_timer = 0' " +
            "'[input]' 'method = pipewire' 'source = auto' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'[smoothing]' 'monstercat = 0' 'waves = 0' 'noise_reduction = 20')"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            // Drive the bars directly from CAVA; no extra QML smoothing or lag.
            onRead: function(line) {
                if (!mprisPanel.playing) return
                var parts = line.split(";")
                var previous = mprisPanel.levels
                var out = []
                for (var i = 0; i < mprisPanel.bands; i++) {
                    var v = parseInt(parts[i]); v = isNaN(v) ? 0 : Math.min(1, v / 100)
                    var current = previous[i] === undefined ? 0 : previous[i]
                    // Fast attack keeps the beat punctual; a gentler release
                    // removes the nervous sample-to-sample flicker.
                    var response = v >= current ? 0.72 : 0.24
                    out.push(current + (v - current) * response)
                }
                mprisPanel.levels = out
            }
        }
    }

    // ── idle wave: only when active+paused (cava drives the bars while playing) ─
    Timer {
        interval: 33; repeat: true
        running: mprisPanel.visible && mprisPanel.active && !mprisPanel.playing
        onTriggered: {
            mprisPanel.phase += 0.12
            var out = []
            var lv = mprisPanel.levels
            for (var i = 0; i < mprisPanel.bands; i++) {
                var goal
                if (mprisPanel.active) {
                    goal = 0.05                 // paused → flat rest
                } else {
                    // no song: gentle symmetric idle wave
                    var d = Math.abs(i - (mprisPanel.bands - 1) / 2)
                    goal = 0.10 + 0.09 * (0.5 + 0.5 * Math.sin(mprisPanel.phase - i * 0.55))
                                * (1 - d / mprisPanel.bands)
                }
                var cur = lv[i] === undefined ? 0.06 : lv[i]
                out.push(cur + (goal - cur) * 0.25)   // gentle ease for the idle state
            }
            mprisPanel.levels = out
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.mprisVisible = false }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: mprisPanel.root
            ownerActive: mprisPanel.root.mprisVisible
            targetX: mprisPanel.root.mprisBarX
            reveal: mprisPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.mprisBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - mprisPanel.reveal)
            : (barBottom + gap) - 2 * (1 - mprisPanel.reveal)
        opacity: mprisPanel.reveal
        focus: root.mprisVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.mprisVisible = false; event.accepted = true }
            else if (event.key === Qt.Key_Space && mprisPanel.player) {
                mprisPanel.player.togglePlaying(); event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.centerIn: parent
                    text: "N O W   P L A Y I N G"
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 11
                    font.letterSpacing: 2; font.weight: Font.DemiBold
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.mprisVisible = false }
                }
            }

            // ── ACTIVE: art + track info ──
            Column {
                width: parent.width
                spacing: 16
                visible: mprisPanel.active

                // Large album art
                Item {
                    width: 220; height: 220
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: root.fillActive
                        clip: true
                        Image {
                            id: panelCoverArt
                            anchors.fill: parent
                            source: artwork.source
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                        IconText {
                            anchors.centerIn: parent
                            visible: panelCoverArt.status !== Image.Ready
                            text: ""   // music_note
                            font.pixelSize: 64
                            color: root.seal
                        }
                    }
                }

                // Track Info Centered
                Column {
                    width: parent.width
                    spacing: 4
                    Item {
                        width: parent.width
                        height: titleText.implicitHeight
                        clip: true
                        UiText {
                            id: titleText
                            text: mprisPanel.player ? (mprisPanel.player.trackTitle || "Unknown") : ""
                            color: root.ink; font.family: root.mono; font.pixelSize: 16; font.weight: Font.Bold
                            
                            x: implicitWidth <= parent.width ? (parent.width - implicitWidth) / 2 : scrollAnim.currentX
                            property real maxScroll: Math.max(0, implicitWidth - parent.width)
                            
                            SequentialAnimation {
                                id: scrollAnim
                                running: titleText.maxScroll > 0 && mprisPanel.active
                                loops: Animation.Infinite
                                property real currentX: 0
                                
                                PauseAnimation { duration: 1500 }
                                NumberAnimation { 
                                    target: scrollAnim
                                    property: "currentX"
                                    to: -titleText.maxScroll
                                    duration: titleText.maxScroll * 30
                                    easing.type: Easing.InOutSine
                                }
                                PauseAnimation { duration: 1500 }
                                NumberAnimation { 
                                    target: scrollAnim
                                    property: "currentX"
                                    to: 0
                                    duration: titleText.maxScroll * 30
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                    UiText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: mprisPanel.player ? (mprisPanel.player.trackArtist || "") : ""
                        color: root.sumiHi; font.family: root.mono; font.pixelSize: 13
                        elide: Text.ElideRight
                        visible: text !== ""
                    }
                }
            }

            // ── progress bar ──
            Item {
                width: parent.width
                height: 14
                visible: mprisPanel.active && mprisPanel.curLen > 0
                
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: mprisPanel.fmtTime(mprisPanel.curPos)
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                }
                
                Rectangle {
                    id: track
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 40; anchors.rightMargin: 40
                    anchors.verticalCenter: parent.verticalCenter
                    height: 4; radius: 2
                    color: root.fillActive
                    Rectangle {
                        height: parent.height; radius: 2
                        color: root.seal
                        width: parent.width * (mprisPanel.curLen > 0
                            ? Math.min(1, mprisPanel.curPos / mprisPanel.curLen) : 0)
                        Behavior on width { NumberAnimation { duration: 450 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -12
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (!mprisPanel.player || mprisPanel.curLen <= 0) return
                            var newPos = Math.max(0, Math.min(1, mouse.x / width)) * mprisPanel.curLen
                            // Quickshell's player exposes `position` and we can set it.
                            if (typeof mprisPanel.player.setPosition === "function") {
                                mprisPanel.player.setPosition(newPos)
                            } else {
                                mprisPanel.player.position = newPos
                            }
                        }
                    }
                }
                
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: mprisPanel.fmtTime(mprisPanel.curLen)
                    color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                }
            }

            // ── controls ──
            Item {
                width: parent.width
                height: 48
                visible: mprisPanel.active
                
                Row {
                    anchors.centerIn: parent
                    spacing: 32

                    IconText {
                        text: ""
                        font.pixelSize: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: (mprisPanel.player && mprisPanel.player.canGoPrevious) ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (mprisPanel.player) mprisPanel.player.previous() }
                    }
                    
                    Rectangle {
                        width: 72; height: 48; radius: 24
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                        IconText {
                            anchors.centerIn: parent
                            text: mprisPanel.playing ? "" : ""
                            font.pixelSize: 24
                            color: root.paper
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (mprisPanel.player) mprisPanel.player.togglePlaying() }
                    }

                    IconText {
                        text: ""
                        font.pixelSize: 22
                        anchors.verticalCenter: parent.verticalCenter
                        color: (mprisPanel.player && mprisPanel.player.canGoNext) ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (mprisPanel.player) mprisPanel.player.next() }
                    }
                }
                
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "LRC"
                    font.family: root.mono; font.pixelSize: 12; font.weight: Font.Bold
                    color: lyricsList.length > 0 
                           ? (showingLyrics ? root.ink : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4))
                           : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1)
                    MouseArea { 
                        anchors.fill: parent; 
                        cursorShape: Qt.PointingHandCursor; 
                        onClicked: { if(lyricsList.length > 0) showingLyrics = !showingLyrics }
                    }
                }
            }

            // ── visualizer + no-song message ──
            Item {
                width: parent.width
                height: 40

                Canvas {
                    id: viz
                    anchors.fill: parent
                    visible: mprisPanel.active
                    opacity: mprisPanel.playing ? 1.0 : 0.5
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        var lv = mprisPanel.levels
                        if (!lv || lv.length === 0) return
                        var n = lv.length
                        var bw = 5
                        var totalGap = width - n * bw
                        var gap = totalGap / (n + 1)
                        var maxH = height - 2
                        var r = bw / 2
                        var palette = mprisPanel.cavaPalette
                        var gradient = ctx.createLinearGradient(0, height, 0, 0)
                        if (palette && palette.length > 1) {
                            for (var stop = 0; stop < palette.length; stop++)
                                gradient.addColorStop(stop / (palette.length - 1), palette[stop])
                            ctx.fillStyle = gradient
                        } else {
                            ctx.fillStyle = root.seal
                        }
                        for (var i = 0; i < n; i++) {
                            var bh = Math.max(bw, lv[i] * maxH)
                            var x = gap + i * (bw + gap)
                            var y = height - bh
                            ctx.beginPath()
                            ctx.moveTo(x + r, y)
                            ctx.lineTo(x + bw - r, y)
                            ctx.arcTo(x + bw, y, x + bw, y + r, r)
                            ctx.lineTo(x + bw, y + bh)
                            ctx.lineTo(x, y + bh)
                            ctx.lineTo(x, y + r)
                            ctx.arcTo(x, y, x + r, y, r)
                            ctx.closePath()
                            ctx.fill()
                        }
                    }
                    Connections {
                        target: mprisPanel
                        function onLevelsChanged() { viz.requestPaint() }
                        function onCavaPaletteChanged() { viz.requestPaint() }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    visible: !mprisPanel.active
                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No song playing"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.55)
                        font.family: root.mono; font.pixelSize: 14; font.weight: Font.Medium
                    }
                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "no active player"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                        font.family: root.mono; font.pixelSize: 11
                    }
                }
            }
        }    }
}
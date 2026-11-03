import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "components"
import "utils/LockLyrics.js" as LockLyrics

ShellRoot {
    id: lockRoot
    readonly property var root: lockRoot

    // ── Live Time ──
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: lockRoot.now = new Date()
    }

    // ── FontLoader for "Bigger" Display Font ──
    FontLoader {
        id: lockBiggerFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Unknown Vendor/OpenType/Bigger/Bigger_Display.otf"
    }

    // ── Dynamic Greeting according to time of day ──
    readonly property string greeting: {
        var h = root.now.getHours()
        if (h >= 5 && h < 12) return "Good Morning, Hery"
        if (h >= 12 && h < 17) return "Good Afternoon, Hery"
        if (h >= 17 && h < 22) return "Good Evening, Hery"
        return "Good Night, Hery"
    }

    // ── Dynamic Theme Colors (synced with Omarchy colors.toml) ──
    property color ink: "#d3c6aa"
    property color paper: "#2d353b"
    property color seal: "#7fbbb3"
    property color color01: "#e67e80" // Red
    property color color02: "#a7c080" // Green
    property color color03: "#dbbc7f" // Yellow
    property color color04: "#7fbbb3" // Blue
    property color color05: "#d699b6" // Magenta
    property color color06: "#83c092" // Cyan
    property color color07: "#9da9a0" // Bright / Light fg
    property color sumi: "#475258"    // Muted
    readonly property color sumiHi: Qt.rgba(sumi.r*0.45 + ink.r*0.55, sumi.g*0.45 + ink.g*0.55, sumi.b*0.45 + ink.b*0.55, 1.0)

    function toHex(col) {
        if (!col) return "#ffffff"
        var r = Math.round(col.r * 255).toString(16).padStart(2, "0")
        var g = Math.round(col.g * 255).toString(16).padStart(2, "0")
        var b = Math.round(col.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    readonly property color cardBg: Qt.rgba(paper.r * 0.25 + 0.05, paper.g * 0.25 + 0.05, paper.b * 0.25 + 0.05, 0.78)
    readonly property color cardBorder: Qt.rgba(ink.r, ink.g, ink.b, 0.12)
    readonly property color fillIdle: Qt.rgba(ink.r, ink.g, ink.b, 0.08)

    // ── Configuration State (from lock/config.json) ──
    property string clockStyle: "stacked"
    property bool showBattery: true
    property bool showDate: true

    FileView {
        id: cfgView
        path: Quickshell.env("HOME") + "/.config/quickshell/lock/config.json"
        printErrors: false
        onLoaded: {
            try {
                var raw = String(text() || "").trim()
                if (raw) {
                    var c = JSON.parse(raw)
                    if (c.clockStyle !== undefined) root.clockStyle = c.clockStyle
                    if (c.showBattery !== undefined) root.showBattery = c.showBattery
                    if (c.showDate !== undefined) root.showDate = c.showDate
                }
            } catch (e) {
                console.log("Error parsing lock config:", e)
            }
        }
    }

    // ── Battery & Power State (Direct sysfs with BAT1/BAT0 support) ──
    property int batteryPercent: 100
    property string batteryStatus: "Discharging"
    readonly property bool isCharging: batteryStatus === "Charging" || batteryStatus === "Full"

    FileView {
        path: "/sys/class/power_supply/BAT1/capacity"
        printErrors: false
        onLoaded: {
            var c = parseInt(String(text() || "").trim())
            if (!isNaN(c) && c >= 0) root.batteryPercent = c
        }
    }

    FileView {
        path: "/sys/class/power_supply/BAT1/status"
        printErrors: false
        onLoaded: {
            var s = String(text() || "").trim()
            if (s) root.batteryStatus = s
        }
    }

    FileView {
        path: "/sys/class/power_supply/BAT0/capacity"
        printErrors: false
        onLoaded: {
            var c = parseInt(String(text() || "").trim())
            if (!isNaN(c) && c >= 0) root.batteryPercent = c
        }
    }

    FileView {
        path: "/sys/class/power_supply/BAT0/status"
        printErrors: false
        onLoaded: {
            var s = String(text() || "").trim()
            if (s) root.batteryStatus = s
        }
    }

    // ── Weather State & Card Theme ──
    property string weatherTemp: "21"
    property string weatherDesc: "Partly Cloudy"
    property string weatherCity: "Bangalore"
    property string weatherIcon: "partly_cloudy_day"
    property string weatherWind: "12 km/h"

    readonly property var weatherPhrase: {
        var t = parseInt(root.weatherTemp)
        if (isNaN(t)) t = 20
        var desc = (root.weatherDesc || "").toLowerCase()

        var cond1 = "clear"
        var cond2 = "and pleasant"

        if (desc.indexOf("rain") !== -1 || desc.indexOf("drizzle") !== -1 || desc.indexOf("shower") !== -1) {
            cond1 = "rainy"
            cond2 = t <= 18 ? "and cold" : "and wet"
        } else if (desc.indexOf("thunder") !== -1 || desc.indexOf("storm") !== -1) {
            cond1 = "stormy"
            cond2 = "with thunder"
        } else if (desc.indexOf("snow") !== -1 || desc.indexOf("ice") !== -1 || desc.indexOf("flurr") !== -1) {
            cond1 = "snowy"
            cond2 = "and freezing"
        } else if (desc.indexOf("cloud") !== -1 || desc.indexOf("overcast") !== -1) {
            cond1 = desc.indexOf("partly") !== -1 ? "partly cloudy" : "overcast"
            cond2 = t >= 26 ? "and warm" : (t <= 16 ? "and chilly" : "and cool")
        } else if (desc.indexOf("fog") !== -1 || desc.indexOf("mist") !== -1 || desc.indexOf("haze") !== -1) {
            cond1 = "misty"
            cond2 = "and humid"
        } else {
            cond1 = "sunny"
            cond2 = t >= 26 ? "and warm" : (t <= 16 ? "and crisp" : "and clear")
        }
        return { cond1: cond1, cond2: cond2 }
    }

    Process {
        id: weatherProc
        running: true
        command: ["curl", "-fs", "--max-time", "3", "https://wttr.in?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim())
                    if (d.current_condition && d.current_condition[0]) {
                        var c = d.current_condition[0]
                        root.weatherTemp = c.temp_C || "21"
                        if (c.weatherDesc && c.weatherDesc[0]) {
                            root.weatherDesc = c.weatherDesc[0].value || "Partly Cloudy"
                        }
                        if (c.windspeedKmph) {
                            root.weatherWind = c.windspeedKmph + " km/h"
                        }
                        var desc = root.weatherDesc.toLowerCase()
                        if (desc.indexOf("rain") !== -1 || desc.indexOf("shower") !== -1) {
                            root.weatherIcon = "rainy"
                        } else if (desc.indexOf("thunder") !== -1 || desc.indexOf("storm") !== -1) {
                            root.weatherIcon = "thunderstorm"
                        } else if (desc.indexOf("snow") !== -1) {
                            root.weatherIcon = "ac_unit"
                        } else if (desc.indexOf("cloud") !== -1 || desc.indexOf("overcast") !== -1) {
                            root.weatherIcon = "cloud"
                        } else {
                            root.weatherIcon = "wb_sunny"
                        }
                    }
                    if (d.nearest_area && d.nearest_area[0] && d.nearest_area[0].areaName && d.nearest_area[0].areaName[0]) {
                        root.weatherCity = d.nearest_area[0].areaName[0].value || "Bangalore"
                    }
                } catch (e) {}
            }
        }
    }

    // ── Live System Hardware & Screentime Metrics ──
    property int cpuPercent: 18
    property int memPercent: 49
    property string screentimeFormatted: "43m"

    Process {
        id: sysInfoProc
        running: true
        command: ["python3", "-c", "import json, os, subprocess; m=json.loads(subprocess.check_output(['python3', os.path.expanduser('~/.config/quickshell/bar/scripts/memory_info.py'), 'status'])); s=json.loads(subprocess.check_output(['python3', os.path.expanduser('~/.config/quickshell/bar/scripts/screentime_info.py'), 'today'])); print(json.dumps({'mem': m.get('percent', 49), 'screen': s.get('today_formatted', '43m')}))"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim())
                    if (d.mem !== undefined) root.memPercent = d.mem
                    if (d.screen !== undefined) root.screentimeFormatted = d.screen
                } catch(e) {}
            }
        }
    }

    // ── MPRIS Live Player ──
    function isRealPlayer(p) {
        if (!p) return false
        if (/playerctld/i.test((p.dbusName || "") + " " + (p.identity || ""))) return false
        if (p.playbackState === MprisPlaybackState.Stopped) return false
        var hasMeta = (p.trackTitle && p.trackTitle.length > 0)
        return hasMeta || p.playbackState === MprisPlaybackState.Playing
    }

    readonly property var activePlayer: {
        var vals = Mpris.players.values
        var paused = null
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (!root.isRealPlayer(p)) continue
            if (p.playbackState === MprisPlaybackState.Playing) return p
            if (p.playbackState === MprisPlaybackState.Paused && paused === null) paused = p
        }
        return paused
    }

    readonly property bool hasMedia: activePlayer !== null && activePlayer.trackTitle.length > 0
    readonly property bool isMediaPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing

    property real curPos: 0
    property real curLen: 0
    property real _lastRead: -1

    function fmtTime(s) {
        if (!s || s <= 0 || isNaN(s)) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec)
    }

    function seekTo(ratio) {
        if (!root.activePlayer || root.curLen <= 0) return
        var target = Math.max(0, Math.min(1, ratio)) * root.curLen
        if (typeof root.activePlayer.setPosition === "function") {
            root.activePlayer.setPosition(target)
        } else {
            root.activePlayer.position = target
        }
        root.curPos = target
    }

    Timer {
        id: posTimer
        interval: 250
        repeat: true
        running: root.hasMedia
        triggeredOnStart: true
        onTriggered: {
            if (!root.activePlayer) return
            var p = root.activePlayer.position || 0
            root.curLen = root.activePlayer.length || 0
            if (Math.abs(p - root._lastRead) > 0.05) {
                root.curPos = p
                root._lastRead = p
            } else if (root.isMediaPlaying) {
                root.curPos = Math.min(root.curLen, root.curPos + 0.25)
            }
            if (root.hasMedia && root.currentTrackId !== "" && root.lyricsTrackId !== root.currentTrackId && !root._isFetchingLyrics) {
                root.triggerLyricsRefresh()
            }
        }
    }

    // ── MPRIS Live Synced Lyrics System ──
    property var lyricsList: []
    property int currentLyricIndex: -1
    property string lyricsTrackId: ""
    property int _lyricsFetchSeq: 0
    property bool _isFetchingLyrics: false
    property int _lyricsRetryCount: 0
    property var _lyricsCache: ({})

    readonly property string currentTrackId: {
        if (!activePlayer) return ""
        var t = activePlayer.trackTitle || ""
        var a = activePlayer.trackArtist || ""
        return (t || a) ? (t.trim() + "||" + a.trim()) : ""
    }

    readonly property bool hasLyrics: lyricsTrackId !== "" && lyricsTrackId === currentTrackId && lyricsList && lyricsList.length > 0
    readonly property string currentLyricText: {
        if (hasLyrics && currentLyricIndex >= 0 && currentLyricIndex < lyricsList.length) {
            return lyricsList[currentLyricIndex].text
        }
        if (hasLyrics && currentLyricIndex < 0) return "..."
        if (_isFetchingLyrics) return "Searching lyrics…"
        if (hasMedia && activePlayer && activePlayer.trackTitle) {
            return activePlayer.trackTitle + (activePlayer.trackArtist ? " · " + activePlayer.trackArtist : "")
        }
        return ""
    }

    Component.onCompleted: {
        root.triggerLyricsRefresh()
    }

    Connections {
        target: root.activePlayer ? root.activePlayer : null
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { root.triggerLyricsRefresh() }
        function onTrackArtistChanged() { root.triggerLyricsRefresh() }
    }

    onActivePlayerChanged: triggerLyricsRefresh()
    onCurrentTrackIdChanged: triggerLyricsRefresh()
    onCurPosChanged: syncLyricIndex()

    function triggerLyricsRefresh() {
        var trackId = root.currentTrackId
        if (trackId === "") {
            lyricsList = []
            currentLyricIndex = -1
            lyricsTrackId = ""
            _lyricsRetryCount = 0
            _isFetchingLyrics = false
            return
        }
        if (_lyricsCache[trackId]) {
            lyricsTrackId = trackId
            lyricsList = _lyricsCache[trackId]
            syncLyricIndex()
            _lyricsRetryCount = 0
            _isFetchingLyrics = false
            return
        }
        if (lyricsTrackId !== trackId) {
            lyricsList = []
            currentLyricIndex = -1
            lyricsTrackId = ""
            _lyricsRetryCount = 0
            _isFetchingLyrics = false
        }
        fetchLyrics()
    }

    Timer {
        id: lyricsPollTimer
        interval: root._lyricsRetryCount < 4 ? 3000 : (root._lyricsRetryCount < 10 ? 6000 : 12000)
        repeat: true
        running: root.hasMedia && root.currentTrackId !== "" && root.lyricsTrackId !== root.currentTrackId
        onTriggered: {
            if (!root._isFetchingLyrics) {
                root.fetchLyrics()
            }
        }
    }

    function syncLyricIndex() {
        if (!lyricsList || lyricsList.length === 0) {
            if (currentLyricIndex !== -1) currentLyricIndex = -1
            return
        }
        var pos = root.curPos
        var idx = -1
        for (var i = 0; i < lyricsList.length; i++) {
            if (pos >= lyricsList[i].time) {
                idx = i
            } else {
                break
            }
        }
        if (idx !== currentLyricIndex) {
            currentLyricIndex = idx
        }
    }

    function cleanTrackTitle(str) {
        return LockLyrics.cleanTrackTitle(str)
    }

    function parseLrc(lrcText) {
        return LockLyrics.parseLrc(lrcText)
    }

    function fetchLyrics() {
        LockLyrics.fetchLyrics(root)
    }

    // ── Dynamic Theme Colors Loader ──
    Process {
        id: colorsLoader
        command: ["bash", "-c", "cat ~/.local/state/omarchy/current/theme/colors.toml 2>/dev/null || cat ~/.config/omarchy/current/theme/colors.toml 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var m = lines[i].match(/^\s*([A-Za-z_0-9]+)\s*=\s*"([^"]+)"/)
                    if (m) {
                        var k = m[1].toLowerCase()
                        var v = m[2]
                        if (k === "foreground" || k === "fg") root.ink = v
                        else if (k === "background" || k === "bg") root.paper = v
                        else if (k === "accent") root.seal = v
                        else if (k === "red" || k === "color1") root.color01 = v
                        else if (k === "green" || k === "color2") root.color02 = v
                        else if (k === "yellow" || k === "color3") root.color03 = v
                        else if (k === "blue" || k === "color4") root.color04 = v
                        else if (k === "magenta" || k === "color5") root.color05 = v
                        else if (k === "cyan" || k === "color6") root.color06 = v
                        else if (k === "bright_fg" || k === "light_foreground" || k === "light_fg" || k === "color7") root.color07 = v
                        else if (k === "muted" || k === "dark_fg") root.sumi = v
                    }
                }
            }
        }
    }

    // ── Authentication State ──
    property string enteredPassword: ""
    property string pendingPassword: ""
    property bool authenticating: false
    property string failureMessage: ""
    property int failedAttempts: 0
    property bool unlocking: false

    function submitPassword(pwd) {
        if (authenticating || unlocking || !pwd) return
        pendingPassword = pwd
        authenticating = true
        failureMessage = ""

        if (!passwordPam.start()) {
            handleFailure()
            return
        }

        Qt.callLater(respondToPasswordPrompt)
    }

    function respondToPasswordPrompt() {
        if (!authenticating || !passwordPam.active || !passwordPam.responseRequired) return
        passwordPam.respond(pendingPassword)
    }

    function handleFailure() {
        authenticating = false
        pendingPassword = ""
        enteredPassword = ""
        failedAttempts++
        failureMessage = "Incorrect password"
        failureResetTimer.restart()
    }

    Timer {
        id: failureResetTimer
        interval: 1600
        onTriggered: {
            root.failureMessage = ""
            hiddenInput.text = ""
            hiddenInput.forceActiveFocus()
        }
    }

    signal startUnlockAnimation()

    function unlockSession() {
        if (unlocking) return
        unlocking = true
        authenticating = false
        failureMessage = ""
        unlockSafetyTimer.restart()
        root.startUnlockAnimation()
    }

    function completeUnlock() {
        unlockSafetyTimer.stop()
        sessionLock.locked = false
    }

    Timer {
        id: unlockSafetyTimer
        interval: 450
        repeat: false
        onTriggered: {
            root.completeUnlock()
        }
    }

    PamContext {
        id: passwordPam
        config: "omarchy-lock-password"
        user: Quickshell.env("USER")

        onResponseRequiredChanged: root.respondToPasswordPrompt()
        onPamMessage: root.respondToPasswordPrompt()

        onCompleted: function(result) {
            authenticating = false
            pendingPassword = ""

            if (result === PamResult.Success) {
                root.unlockSession()
            } else {
                root.handleFailure()
            }
        }

        onError: function(error) {
            root.handleFailure()
        }
    }

    // ── Calendar Date Calculations (State & Navigation) ──
    property int selYear: root.now.getFullYear()
    property int selMonth: root.now.getMonth()
    property int selDay: root.now.getDate()

    readonly property var months: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    readonly property var daysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    function getWeekDayItem(offset) {
        var d = new Date(selYear, selMonth, selDay + offset)
        var y = d.getFullYear()
        var m = d.getMonth()
        var dayNum = d.getDate()
        var isToday = (y === root.now.getFullYear() && m === root.now.getMonth() && dayNum === root.now.getDate())
        return {
            dateObj: d,
            year: y,
            month: m,
            day: dayNum,
            dayName: daysShort[d.getDay()],
            isToday: isToday
        }
    }

    function stepDay(delta) {
        var target = new Date(selYear, selMonth, selDay + delta)
        selYear = target.getFullYear()
        selMonth = target.getMonth()
        selDay = target.getDate()
    }

    function jumpToToday() {
        selYear = root.now.getFullYear()
        selMonth = root.now.getMonth()
        selDay = root.now.getDate()
    }

    readonly property bool isSelectedToday: {
        return selYear === root.now.getFullYear() &&
               selMonth === root.now.getMonth() &&
               selDay === root.now.getDate()
    }

    // ── Session Lock ──
    WlSessionLock {
        id: sessionLock
        locked: true

        onLockedChanged: {
            if (!locked) {
                Qt.callLater(function() {
                    Qt.quit()
                })
            }
        }

        WlSessionLockSurface {
            id: lockSurface
            color: "transparent"

            Item {
                id: screenRoot
                anchors.fill: parent

                // ── Dynamic Frosted Workspace Depth Properties ──
                property alias bgBlur: lockBackground.bgBlur
                property alias bgBrightness: lockBackground.bgBrightness
                property alias bgScale: lockBackground.bgScale
                property alias bgDim: lockBackground.bgDim
                property alias transitionStarted: lockBackground.transitionStarted

                function startEntranceTransition() {
                    lockBackground.startEntranceTransition()
                }

                // ── 0-2. FROSTED WORKSPACE DEPTH BACKGROUND ────────────────
                LockBackground {
                    id: lockBackground
                }

                // ── 3. HIDDEN TEXT INPUT (Focuses globally for instant password typing) ──
                TextInput {
                    id: hiddenInput
                    anchors.fill: parent
                    opacity: 0.0
                    focus: true
                    activeFocusOnPress: true
                    echoMode: TextInput.Normal

                    onTextChanged: {
                        root.enteredPassword = text
                        if (root.failureMessage) root.failureMessage = ""
                    }

                    onAccepted: {
                        if (text.trim().length > 0) {
                            root.submitPassword(text)
                        }
                    }

                    Keys.onEscapePressed: {
                        text = ""
                        root.enteredPassword = ""
                        root.failureMessage = ""
                    }
                }

                // Global Click to always refocus hiddenInput
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: hiddenInput.forceActiveFocus()
                }

                // ── 4. TOP HEADER: GREETING (TOP-LEFT) & LIVE LYRICS (TOP-RIGHT) ─
                LockHeader {
                    id: greetingContainer
                    root: lockRoot
                    anchors.left: bentoContainer.left
                    anchors.right: bentoContainer.right
                    anchors.bottom: bentoContainer.top
                    anchors.bottomMargin: 12
                }

                // ── 5. BENTO GRID OF DASHBOARD WIDGETS (Centered, iOS/Bento Style) ──
                Item {
                    id: bentoContainer
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -6
                    width: 960
                    height: 376

                    Column {
                        anchors.fill: parent
                        spacing: 16

                        // ═════════════════════════════════════════════════
                        // ── BENTO ROW 1: Clock (1) · Weather (1) · Media (2) ─
                        // ═════════════════════════════════════════════════
                        Row {
                            width: parent.width
                            height: 180
                            spacing: 16

                            LockClockWeather {
                                id: clockWeatherRow
                                root: lockRoot
                                biggerFont: lockBiggerFont
                            }

                            LockMediaTile {
                                id: tile3Wrapper
                                root: lockRoot
                            }
                        }

                        // ═════════════════════════════════════════════════
                        // ── BENTO ROW 2: Calendar (2) · Battery (1) · Stats (1) ─
                        // ═════════════════════════════════════════════════
                        Row {
                            width: parent.width
                            height: 180
                            spacing: 16

                            LockCalendarTile {
                                id: tile4Wrapper
                                root: lockRoot
                            }

                            LockSystemTiles {
                                id: systemTilesRow
                                root: lockRoot
                            }
                        }
                    }
                }

                // ── 6. SLEEK FROSTED PASSWORD PILL (Bottom Row) ───────────────
                LockPasswordPill {
                    id: passwordArea
                    root: lockRoot
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ── 7. UNLOCK EXIT ANIMATION (Tiles fly out in their respective directions) ──
                Connections {
                    target: lockRoot
                    function onStartUnlockAnimation() {
                        try {
                            greetingContainer.greetingInAnim.stop()
                            passwordArea.pwdInAnim.stop()
                            clockWeatherRow.tile1InAnim.stop()
                            clockWeatherRow.tile2InAnim.stop()
                            tile3Wrapper.tile3InAnim.stop()
                            tile4Wrapper.tile4InAnim.stop()
                            systemTilesRow.tile5InAnim.stop()
                            systemTilesRow.tile6InAnim.stop()
                            unlockExitAnim.restart()
                        } catch (e) {
                            console.log("Exit anim error:", e)
                            lockRoot.completeUnlock()
                        }
                    }
                }

                ParallelAnimation {
                    id: unlockExitAnim
                    onFinished: {
                        lockRoot.completeUnlock()
                    }

                    // Background snapshot un-frosts and returns to 1:1 desktop state seamlessly
                    ParallelAnimation {
                        NumberAnimation { target: screenRoot; property: "bgBlur"; to: 0.0; duration: 250; easing.type: Easing.OutQuad }
                        NumberAnimation { target: screenRoot; property: "bgScale"; to: 1.00; duration: 260; easing.type: Easing.OutQuad }
                        NumberAnimation { target: screenRoot; property: "bgBrightness"; to: 0.0; duration: 250; easing.type: Easing.OutQuad }
                        NumberAnimation { target: screenRoot; property: "bgDim"; to: 0.0; duration: 250; easing.type: Easing.OutQuad }
                    }

                    // Top Greeting fades and glides up
                    ParallelAnimation {
                        NumberAnimation { target: greetingContainer; property: "opacity"; to: 0.0; duration: 180; easing.type: Easing.InQuad }
                        NumberAnimation { target: greetingContainer.greetingTranslate; property: "y"; to: -20; duration: 220; easing.type: Easing.InQuad }
                    }

                    // Password Area fades out quickly
                    NumberAnimation { target: passwordArea; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.OutQuad }

                    // Top Row Bento Cards (Tile 1, 2, 3) glide up smoothly
                    ParallelAnimation {
                        NumberAnimation { target: clockWeatherRow.tile1Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockWeatherRow.tile1Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockWeatherRow.t1Trans; property: "y"; to: -32; duration: 240; easing.type: Easing.InQuad }

                        NumberAnimation { target: clockWeatherRow.tile2Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockWeatherRow.tile2Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                        NumberAnimation { target: clockWeatherRow.t2Trans; property: "y"; to: -32; duration: 240; easing.type: Easing.InQuad }

                        NumberAnimation { target: tile3Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                        NumberAnimation { target: tile3Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                        NumberAnimation { target: tile3Wrapper.t3Trans; property: "y"; to: -32; duration: 240; easing.type: Easing.InQuad }
                    }

                    // Bottom Row Bento Cards (Tile 4, 5, 6) glide down smoothly
                    SequentialAnimation {
                        PauseAnimation { duration: 20 }
                        ParallelAnimation {
                            NumberAnimation { target: tile4Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { target: tile4Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                            NumberAnimation { target: tile4Wrapper.t4Trans; property: "y"; to: 32; duration: 240; easing.type: Easing.InQuad }

                            NumberAnimation { target: systemTilesRow.tile5Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { target: systemTilesRow.tile5Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                            NumberAnimation { target: systemTilesRow.t5Trans; property: "y"; to: 32; duration: 240; easing.type: Easing.InQuad }

                            NumberAnimation { target: systemTilesRow.tile6Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { target: systemTilesRow.tile6Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                            NumberAnimation { target: systemTilesRow.t6Trans; property: "y"; to: 32; duration: 240; easing.type: Easing.InQuad }
                        }
                    }
                }
            }
        }
    }
}

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

ShellRoot {
    id: root

    // ── Live Time ──
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ── FontLoader for "Bigger" Display Font ──
    FontLoader {
        id: biggerFont
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
        if (!str) return ""
        return str.replace(/\s*[\(\[](feat\.|ft\.|remaster|live|official|deluxe|bonus|version|radio|edit|mono|stereo|anniversary).*?[\)\]]/gi, "")
                  .replace(/\s*-\s*(remaster|live|radio|deluxe|bonus|anniversary).*$/gi, "")
                  .trim()
    }

    function parseLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return []
        var parsed = []
        var offsetSec = 0
        var offsetMatch = /\[offset:\s*([+-]?\d+)\]/i.exec(lrcText)
        if (offsetMatch) {
            offsetSec = (parseFloat(offsetMatch[1]) || 0) / 1000.0
        }

        var lines = lrcText.split('\n')
        var tagRegex = /\[(\d{1,2}):(\d{2}(?:\.\d+)?)\]/g
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || /^\[[a-zA-Z]+:/.test(line)) continue
            var timestamps = []
            var match
            tagRegex.lastIndex = 0
            while ((match = tagRegex.exec(line)) !== null) {
                var m = parseFloat(match[1])
                var s = parseFloat(match[2])
                timestamps.push((m * 60) + s)
            }
            if (timestamps.length > 0) {
                var txt = line.replace(/\[\d{1,2}:\d{2}(?:\.\d+)?\]/g, "").trim()
                if (txt.length > 0) {
                    for (var t = 0; t < timestamps.length; t++) {
                        var adjustedTime = Math.max(0, timestamps[t] + offsetSec)
                        parsed.push({ time: adjustedTime, text: txt })
                    }
                }
            }
        }
        parsed.sort(function(a, b) { return a.time - b.time })
        return parsed
    }

    function fetchLyrics() {
        var p = root.activePlayer
        var title = p ? (p.trackTitle || "").trim() : ""
        var artist = p ? (p.trackArtist || "").trim() : ""
        var album = p ? (p.trackAlbum || "").trim() : ""
        var dur = Math.round(p ? (p.length || root.curLen || 0) : (root.curLen || 0))
        var trackId = (title || artist) ? (title + "||" + artist) : ""

        if (!p || title === "" || trackId === "") {
            _isFetchingLyrics = false
            return
        }

        if (_lyricsCache[trackId]) {
            lyricsTrackId = trackId
            lyricsList = _lyricsCache[trackId]
            syncLyricIndex()
            _isFetchingLyrics = false
            return
        }

        if (_isFetchingLyrics) return
        _isFetchingLyrics = true
        var seq = ++_lyricsFetchSeq
        _lyricsRetryCount++

        var cleaned = cleanTrackTitle(title)
        var targetTitle = cleaned !== "" ? cleaned : title

        function finish(success, parsed) {
            _isFetchingLyrics = false
            if (seq !== root._lyricsFetchSeq || root.currentTrackId !== trackId) return
            if (success && parsed && parsed.length > 0) {
                root._lyricsCache[trackId] = parsed
                root.lyricsTrackId = trackId
                root.lyricsList = parsed
                root.syncLyricIndex()
            }
        }

        function pickBestResult(resp) {
            if (!resp) return null
            if (!Array.isArray(resp) && resp.syncedLyrics) {
                return parseLrc(resp.syncedLyrics)
            }
            if (Array.isArray(resp) && resp.length > 0) {
                var candidates = []
                for (var i = 0; i < resp.length; i++) {
                    var item = resp[i]
                    if (item && item.syncedLyrics && typeof item.syncedLyrics === "string" && item.syncedLyrics.trim().length > 0) {
                        var diff = dur > 0 && item.duration ? Math.abs(item.duration - dur) : 9999
                        candidates.push({ item: item, diff: diff })
                    }
                }
                if (candidates.length === 0) return null
                candidates.sort(function(a, b) { return a.diff - b.diff })
                return parseLrc(candidates[0].item.syncedLyrics)
            }
            return null
        }

        function query(url, nextFallback) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, true)
            xhr.setRequestHeader("User-Agent", "Quickshell-Lyrics/2.0 (Linux)")
            xhr.timeout = 5000
            xhr.ontimeout = function() { if (nextFallback) nextFallback(); else finish(false, null); }
            xhr.onerror = function() { if (nextFallback) nextFallback(); else finish(false, null); }
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (seq !== root._lyricsFetchSeq || root.currentTrackId !== trackId) {
                        _isFetchingLyrics = false
                        return
                    }
                    if (xhr.status === 200) {
                        try {
                            var resp = JSON.parse(xhr.responseText)
                            var parsed = pickBestResult(resp)
                            if (parsed && parsed.length > 0) {
                                finish(true, parsed)
                                return
                            }
                        } catch(e) {}
                    }
                    if (nextFallback) nextFallback()
                    else finish(false, null)
                }
            }
            xhr.send()
        }

        var getUrl = dur > 0
            ? ("https://lrclib.net/api/get?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist) + (album ? "&album_name=" + encodeURIComponent(album) : "") + "&duration=" + dur)
            : ""
        var searchUrl1 = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist)
        var searchUrl2 = "https://lrclib.net/api/search?q=" + encodeURIComponent(targetTitle + " " + artist)

        if (getUrl !== "") {
            query(getUrl, function() {
                query(searchUrl1, function() {
                    query(searchUrl2, null)
                })
            })
        } else {
            query(searchUrl1, function() {
                query(searchUrl2, null)
            })
        }
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
                property real bgBlur: 0.0
                property real bgBrightness: 0.0
                property real bgScale: 1.00
                property real bgDim: 0.0
                property bool transitionStarted: false

                function startEntranceTransition() {
                    if (!transitionStarted && screenRoot.width > 0 && screenRoot.height > 0) {
                        transitionStarted = true
                        transitionAnim.restart()
                    }
                }

                onWidthChanged: if (desktopSnapshot.status === Image.Ready) startEntranceTransition()
                onHeightChanged: if (desktopSnapshot.status === Image.Ready) startEntranceTransition()

                Timer {
                    id: fallbackTransitionTimer
                    interval: 180
                    running: !screenRoot.transitionStarted
                    onTriggered: screenRoot.startEntranceTransition()
                }

                ParallelAnimation {
                    id: transitionAnim

                    NumberAnimation {
                        target: screenRoot
                        property: "bgBlur"
                        from: 0.0
                        to: 0.88
                        duration: 520
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: screenRoot
                        property: "bgBrightness"
                        from: 0.0
                        to: -0.20
                        duration: 520
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: screenRoot
                        property: "bgScale"
                        from: 1.00
                        to: 0.97
                        duration: 560
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: screenRoot
                        property: "bgDim"
                        from: 0.0
                        to: 0.38
                        duration: 520
                        easing.type: Easing.OutCubic
                    }
                }

                // ── 0. DEEP BASE RECTANGLE ──────────────────────────────────
                Rectangle {
                    anchors.fill: parent
                    color: "#0a0c0e"
                }

                // ── 1. DESKTOP SNAPSHOT (With dynamic wallpaper fallback) ───
                Image {
                    id: desktopSnapshot
                    anchors.fill: parent
                    source: "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-lock-bg.png"
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: false
                    visible: false
                    onStatusChanged: {
                        if (status === Image.Error) {
                            source = "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
                        } else if (status === Image.Ready) {
                            screenRoot.startEntranceTransition()
                        }
                    }
                }

                // ── 2. FROSTED WORKSPACE DEPTH LAYER ────────────────────────
                Item {
                    id: bgContainer
                    anchors.fill: parent
                    scale: screenRoot.bgScale
                    transformOrigin: Item.Center

                    MultiEffect {
                        id: bgEffect
                        source: desktopSnapshot
                        anchors.fill: parent
                        blurEnabled: true
                        blurMax: 48
                        blur: screenRoot.bgBlur
                        brightness: screenRoot.bgBrightness
                        saturation: -0.08
                    }
                }

                // Darkening overlay & edge vignette
                Rectangle {
                    id: dimOverlay
                    anchors.fill: parent
                    color: "#000000"
                    opacity: screenRoot.bgDim
                }

                Rectangle {
                    anchors.fill: parent
                    opacity: screenRoot.bgDim * 0.75
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.40) }
                        GradientStop { position: 0.15; color: Qt.rgba(0, 0, 0, 0.0) }
                        GradientStop { position: 0.85; color: Qt.rgba(0, 0, 0, 0.0) }
                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    }
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
                Item {
                    id: greetingContainer
                    anchors.left: bentoContainer.left
                    anchors.right: bentoContainer.right
                    anchors.bottom: bentoContainer.top
                    anchors.bottomMargin: 12
                    height: 20

                    opacity: 0.0
                    transform: Translate { id: greetingTranslate; y: -12 }

                    SequentialAnimation {
                        id: greetingInAnim
                        running: true
                        PauseAnimation { duration: 120 }
                        ParallelAnimation {
                            NumberAnimation { target: greetingContainer; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                            NumberAnimation { target: greetingTranslate; property: "y"; to: 0; duration: 420; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        id: greetingTxt
                        text: root.greeting
                        font.family: "Genova"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                        color: root.ink
                        opacity: 0.70
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignLeft
                    }

                    // Live Lyrics Line (Top-Right corner above Bento Tiles, Right-Aligned)
                    Item {
                        id: lyricContainer
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        width: Math.min(680, Math.max(0, parent.width - greetingTxt.implicitWidth - 24))
                        clip: true
                        visible: root.hasMedia && root.currentLyricText !== ""
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Row {
                            id: lyricRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Text {
                                text: "music_note"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 13
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Item {
                                id: lyricSwitcher
                                height: 20
                                width: Math.min(640, Math.max(10, lyricSwitcher.useB ? textB.implicitWidth : textA.implicitWidth))
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter

                                property bool useB: false
                                property string currentShownText: ""
                                property bool initialized: false

                                function transitionTo(newText) {
                                    if (!newText || newText === currentShownText) return
                                    currentShownText = newText
                                    animSwitch.stop()

                                    if (!useB) {
                                        textB.text = newText
                                        transB.y = 5
                                        textB.opacity = 0.0

                                        animExitTrans.target = transA
                                        animExitTrans.to = -5
                                        animExitOpacity.target = textA

                                        animEnterTrans.target = transB
                                        animEnterTrans.to = 0
                                        animEnterOpacity.target = textB

                                        useB = true
                                    } else {
                                        textA.text = newText
                                        transA.y = 5
                                        textA.opacity = 0.0

                                        animExitTrans.target = transB
                                        animExitTrans.to = -5
                                        animExitOpacity.target = textB

                                        animEnterTrans.target = transA
                                        animEnterTrans.to = 0
                                        animEnterOpacity.target = textA

                                        useB = false
                                    }

                                    animSwitch.restart()
                                }

                                ParallelAnimation {
                                    id: animSwitch

                                    NumberAnimation {
                                        id: animExitTrans
                                        property: "y"
                                        duration: 160
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        id: animExitOpacity
                                        property: "opacity"
                                        to: 0.0
                                        duration: 140
                                        easing.type: Easing.OutQuad
                                    }

                                    NumberAnimation {
                                        id: animEnterTrans
                                        property: "y"
                                        duration: 220
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        id: animEnterOpacity
                                        property: "opacity"
                                        to: 1.0
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Text {
                                    id: textA
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: "Genova"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.5
                                    color: root.seal
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 640)
                                    transform: Translate { id: transA }
                                }

                                Text {
                                    id: textB
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.family: "Genova"
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    font.letterSpacing: 0.5
                                    color: root.seal
                                    horizontalAlignment: Text.AlignRight
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, 640)
                                    transform: Translate { id: transB }
                                }

                                Connections {
                                    target: root
                                    function onCurrentLyricTextChanged() {
                                        if (!lyricSwitcher.initialized) {
                                            lyricSwitcher.init(root.currentLyricText)
                                            return
                                        }
                                        lyricSwitcher.transitionTo(root.currentLyricText)
                                    }
                                }

                                function init(txt) {
                                    currentShownText = txt
                                    textA.text = txt
                                    textA.opacity = 1.0
                                    transA.y = 0
                                    textB.text = ""
                                    textB.opacity = 0.0
                                    transB.y = 5
                                    useB = false
                                    initialized = true
                                }

                                Component.onCompleted: {
                                    if (root.currentLyricText !== "") {
                                        init(root.currentLyricText)
                                    }
                                }
                            }
                        }
                    }
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

                            // ── TILE 1: CLOCK (Stacked or Inline) ─────────
                            // Direction: Top-Left
                            Item {
                                id: tile1Wrapper
                                width: 230
                                height: parent.height
                                opacity: 0.0
                                scale: 0.94
                                transform: Translate { id: t1Trans; x: 0; y: 24 }

                                SequentialAnimation {
                                    id: tile1InAnim
                                    running: true
                                    PauseAnimation { duration: 160 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile1Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile1Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t1Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                }

                                Rectangle {
                                    id: clockTile
                                    anchors.fill: parent
                                    radius: 26
                                    color: root.cardBg
                                    border.color: root.cardBorder
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 16

                                        // Top Pill Header
                                        Row {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            spacing: 5
                                            Text {
                                                text: "schedule"
                                                font.family: "Material Symbols Rounded"
                                                font.pixelSize: 13
                                                color: root.seal
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: "Clock"
                                                font.family: "Genova"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: root.seal
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        // Stacked Clock View
                                        Column {
                                            visible: root.clockStyle === "stacked"
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: 6
                                            spacing: -10

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: {
                                                    var h = root.now.getHours()
                                                    return h < 10 ? "0" + h : String(h)
                                                }
                                                font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                                                font.pixelSize: 48
                                                font.weight: Font.Bold
                                                color: root.ink
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: {
                                                    var m = root.now.getMinutes()
                                                    return m < 10 ? "0" + m : String(m)
                                                }
                                                font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                                                font.pixelSize: 48
                                                font.weight: Font.Bold
                                                color: root.ink
                                                opacity: 0.45
                                            }
                                        }

                                        // Inline Clock View
                                        Column {
                                            visible: root.clockStyle !== "stacked"
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: 6
                                            spacing: 4

                                            Text {
                                                text: Qt.formatTime(root.now, "HH:mm")
                                                font.family: "Genova"
                                                font.pixelSize: 42
                                                font.weight: Font.Bold
                                                color: root.ink
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                            Text {
                                                text: ":" + Qt.formatTime(root.now, "ss")
                                                font.family: "Genova"
                                                font.pixelSize: 14
                                                font.weight: Font.Bold
                                                color: root.seal
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }

                                        // Bottom Row
                                        Row {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 6

                                            Text {
                                                text: root.now.getHours() < 12 ? "AM" : "PM"
                                                font.family: "Genova"
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: root.seal
                                            }
                                            Text {
                                                text: "·"
                                                color: root.sumi
                                                font.pixelSize: 10
                                            }
                                            Text {
                                                text: Qt.formatDate(root.now, "ddd, d MMM")
                                                font.family: "Genova"
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                color: root.ink
                                                opacity: 0.70
                                            }
                                        }
                                    }
                                }
                            }

                            // ── TILE 2: WEATHER CARD (Editorial Conversational Style) ──
                            // Direction: Top-Center
                            Item {
                                id: tile2Wrapper
                                width: 230
                                height: parent.height
                                opacity: 0.0
                                scale: 0.94
                                transform: Translate { id: t2Trans; x: 0; y: 24 }

                                SequentialAnimation {
                                    id: tile2InAnim
                                    running: true
                                    PauseAnimation { duration: 200 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile2Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile2Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t2Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                }

                                Rectangle {
                                    id: weatherTile
                                    anchors.fill: parent
                                    radius: 26
                                    color: root.cardBg
                                    border.color: root.cardBorder
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 20

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            textFormat: Text.RichText
                                            text: "<span style='color:" + root.toHex(root.color07) + "'>It’s </span>" +
                                                  "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherTemp + "°</span>" +
                                                  "<span style='color:" + root.color07 + "'> now</span><br>" +
                                                  "<span style='color:" + root.toHex(root.color07) + "'>in </span>" +
                                                  "<span style='color:" + root.toHex(root.seal) + "; font-weight:700'>" + root.weatherCity + ".</span><br>" +
                                                  "<span style='color:" + root.toHex(root.color07) + "'>Will be </span>" +
                                                  "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherPhrase.cond1 + "</span><br>" +
                                                  "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherPhrase.cond2 + ".</span>"
                                            font.family: "Genova"
                                            font.pixelSize: 20
                                            font.weight: Font.Normal
                                            lineHeight: 1.35
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }

                            // ── TILE 3: MEDIA PLAYER / NOW PLAYING (2 Cols) ──
                            // Direction: Top-Right
                            Item {
                                id: tile3Wrapper
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
                                                            ? "file://" + Quickshell.env("HOME") + "/.config/quickshell/bar/spotify.svg"
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
                        }

                        // ═════════════════════════════════════════════════
                        // ── BENTO ROW 2: Calendar (2) · Battery (1) · Stats (1) ─
                        // ═════════════════════════════════════════════════
                        Row {
                            width: parent.width
                            height: 180
                            spacing: 16

                            // ── TILE 4: CURVED WEEK CALENDAR WIDGET (2 Cols) ─
                            // Direction: Bottom-Left
                            Item {
                                id: tile4Wrapper
                                width: 468
                                height: parent.height
                                opacity: 0.0
                                scale: 0.94
                                transform: Translate { id: t4Trans; x: 0; y: 24 }

                                SequentialAnimation {
                                    id: tile4InAnim
                                    running: true
                                    PauseAnimation { duration: 280 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile4Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile4Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t4Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                }

                                Rectangle {
                                    id: calTile
                                    anchors.fill: parent
                                    radius: 26
                                    color: root.cardBg
                                    border.color: root.cardBorder
                                    border.width: 1
                                    clip: true

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 14

                                        // 1. Top Bar: Calendar Badge & Today Button
                                        Item {
                                            id: calTopBar
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 24

                                            Row {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                Text {
                                                    text: "calendar_month"
                                                    font.family: "Material Symbols Rounded"
                                                    font.pixelSize: 13
                                                    color: root.seal
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Text {
                                                    text: root.months[root.selMonth] + " " + root.selDay
                                                    font.family: "Genova"
                                                    font.pixelSize: 12
                                                    font.weight: Font.Bold
                                                    color: root.ink
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            // Jump to Today Pill Button
                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 22
                                                radius: 11
                                                color: todayBtnMa.containsMouse ? root.fillIdle : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                                width: todayPillRow.implicitWidth + 14

                                                Row {
                                                    id: todayPillRow
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Rectangle {
                                                        width: 5; height: 5; radius: 2.5
                                                        color: root.isSelectedToday ? root.color02 : root.seal
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Text {
                                                        text: "Today"
                                                        font.family: "Genova"
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: root.seal
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }

                                                MouseArea {
                                                    id: todayBtnMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.jumpToToday()
                                                }
                                            }
                                        }

                                        // 2. Curved Days Band
                                        Item {
                                            id: curvedWeekView
                                            anchors.top: calTopBar.bottom
                                            anchors.topMargin: 4
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 90
                                            clip: true

                                            readonly property real archHeight: 12.0
                                            readonly property real ribbonBaseY: 44.0
                                            readonly property real ribbonThickness: 34.0
                                            readonly property real sidePad: 8.0
                                            readonly property real trackWidth: width - (sidePad * 2)

                                            function archOffsetY(t) {
                                                return 4.0 * archHeight * t * (1.0 - t)
                                            }

                                            property real scrollOffset: 0.0
                                            property real targetOffset: 0.0

                                            function stopScrollAnim() {
                                                if (scrollAnim.running) scrollAnim.stop()
                                                scrollOffset = 0
                                                targetOffset = 0
                                            }

                                            NumberAnimation {
                                                id: scrollAnim
                                                target: curvedWeekView
                                                property: "scrollOffset"
                                                duration: 200
                                                easing.type: Easing.OutCubic
                                                onFinished: {
                                                    var delta = Math.round(curvedWeekView.scrollOffset)
                                                    if (delta !== 0) {
                                                        root.stepDay(delta)
                                                        curvedWeekView.scrollOffset = 0
                                                        curvedWeekView.targetOffset = 0
                                                    }
                                                }
                                            }

                                            function scrollBy(delta) {
                                                targetOffset = Math.round(targetOffset) + delta
                                                targetOffset = Math.max(-4, Math.min(4, targetOffset))
                                                scrollAnim.stop()
                                                scrollAnim.from = scrollOffset
                                                scrollAnim.to = targetOffset
                                                scrollAnim.duration = Math.max(180, Math.min(280, 150 + Math.abs(targetOffset - scrollOffset) * 40))
                                                scrollAnim.start()
                                            }

                                            // Upward Curved Background Ribbon Shape
                                            Shape {
                                                id: curveShape
                                                anchors.fill: parent
                                                antialiasing: true
                                                preferredRendererType: Shape.CurveRenderer

                                                ShapePath {
                                                    strokeColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                                                    strokeWidth: 1
                                                    capStyle: ShapePath.RoundCap
                                                    joinStyle: ShapePath.RoundJoin
                                                    fillColor: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.08)

                                                    startX: curvedWeekView.sidePad
                                                    startY: curvedWeekView.ribbonBaseY

                                                    PathQuad {
                                                        x: curvedWeekView.sidePad + curvedWeekView.trackWidth
                                                        y: curvedWeekView.ribbonBaseY
                                                        controlX: curvedWeekView.sidePad + (curvedWeekView.trackWidth / 2)
                                                        controlY: curvedWeekView.ribbonBaseY - (curvedWeekView.archHeight * 2)
                                                    }

                                                    PathLine {
                                                        x: curvedWeekView.sidePad + curvedWeekView.trackWidth
                                                        y: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness
                                                    }

                                                    PathQuad {
                                                        x: curvedWeekView.sidePad
                                                        y: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness
                                                        controlX: curvedWeekView.sidePad + (curvedWeekView.trackWidth / 2)
                                                        controlY: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness - (curvedWeekView.archHeight * 2)
                                                    }

                                                    PathLine {
                                                        x: curvedWeekView.sidePad
                                                        y: curvedWeekView.ribbonBaseY
                                                    }
                                                }
                                            }

                                            // Fixed Summit Center Circular Badge at peak of the curve
                                            Rectangle {
                                                id: summitCenterBadge
                                                width: 28
                                                height: 28
                                                radius: 14
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                y: Math.round(curvedWeekView.ribbonBaseY - curvedWeekView.archHeight + (curvedWeekView.ribbonThickness / 2) - 14)
                                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.32)
                                                border.width: 1.5
                                                border.color: root.seal
                                                z: 1
                                            }

                                            // Global Wheel Handler over the curved week view
                                            WheelHandler {
                                                target: null
                                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                                onWheel: (event) => {
                                                    if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                                                        curvedWeekView.scrollBy(1)
                                                    } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                                                        curvedWeekView.scrollBy(-1)
                                                    }
                                                }
                                            }

                                            // Dynamic sliding day items along the custom curve (-5 to +5)
                                            Repeater {
                                                model: [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5]
                                                delegate: Item {
                                                    id: dayDelegate
                                                    required property int modelData
                                                    required property int index

                                                    readonly property var itemData: root.getWeekDayItem(modelData)
                                                    readonly property real u: modelData - curvedWeekView.scrollOffset
                                                    readonly property real t: (u + 3.5) / 7.0
                                                    readonly property real posX: curvedWeekView.sidePad + (t * curvedWeekView.trackWidth)
                                                    readonly property real clampedT: Math.max(0.0, Math.min(1.0, t))
                                                    readonly property real curveH: curvedWeekView.archOffsetY(clampedT)
                                                    readonly property real posY: curvedWeekView.ribbonBaseY - curveH + (curvedWeekView.ribbonThickness / 2)

                                                    readonly property real dist: Math.abs(u)
                                                    readonly property bool isCenter: dist < 0.4
                                                    readonly property real itemOpacity: {
                                                        if (dist <= 0.4) return 1.0
                                                        if (dist >= 3.5) return 0.0
                                                        return Math.max(0.0, 1.0 - (dist / 3.5) * 0.75)
                                                    }

                                                    visible: itemOpacity > 0.01
                                                    z: 2

                                                    x: Math.round(posX - (width / 2))
                                                    y: 0
                                                    width: Math.round(curvedWeekView.trackWidth / 7.2)
                                                    height: curvedWeekView.height

                                                    // Day Name sitting ABOVE the circular badge & ribbon
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        y: Math.round(posY - (isCenter ? 30 : 28))
                                                        text: dayDelegate.itemData.dayName
                                                        font.family: "Genova"
                                                        font.pixelSize: 10
                                                        font.weight: isCenter ? Font.Bold : Font.Normal
                                                        color: isCenter ? root.ink : root.sumi
                                                        opacity: dayDelegate.itemOpacity
                                                    }

                                                    // Day Number sitting INSIDE the ribbon / summit badge
                                                    Text {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        y: Math.round(posY - (height / 2))
                                                        text: dayDelegate.itemData.day
                                                        font.family: "Genova"
                                                        font.pixelSize: isCenter ? 12 : 11
                                                        font.weight: isCenter ? Font.Bold : Font.Medium
                                                        color: root.ink
                                                        opacity: dayDelegate.itemOpacity
                                                    }

                                                    // Center / Today Marker Dot
                                                    Rectangle {
                                                        visible: dayDelegate.itemData.isToday && dayDelegate.itemOpacity > 0.1
                                                        width: 4
                                                        height: 4
                                                        radius: 2
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        y: Math.round(posY + (isCenter ? 15 : 13))
                                                        color: root.seal
                                                        opacity: dayDelegate.itemOpacity
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var targetDelta = Math.round(u)
                                                            if (targetDelta !== 0) curvedWeekView.scrollBy(targetDelta)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // 3. Bottom Strip: Date Summary & Navigation
                                        Row {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: 8

                                            Rectangle {
                                                width: 20; height: 20; radius: 10
                                                color: prevDayMa.containsMouse ? root.fillIdle : "transparent"
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "chevron_left"
                                                    font.family: "Material Symbols Rounded"
                                                    font.pixelSize: 14
                                                    color: root.ink
                                                }
                                                MouseArea {
                                                    id: prevDayMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: curvedWeekView.scrollBy(-1)
                                                }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: {
                                                    var selDate = new Date(root.selYear, root.selMonth, root.selDay)
                                                    var label = Qt.formatDate(selDate, "ddd, MMM d")
                                                    return root.isSelectedToday ? ("Today · " + label) : label
                                                }
                                                font.family: "Genova"
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: root.ink
                                            }

                                            Rectangle {
                                                width: 20; height: 20; radius: 10
                                                color: nextDayMa.containsMouse ? root.fillIdle : "transparent"
                                                anchors.verticalCenter: parent.verticalCenter
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "chevron_right"
                                                    font.family: "Material Symbols Rounded"
                                                    font.pixelSize: 14
                                                    color: root.ink
                                                }
                                                MouseArea {
                                                    id: nextDayMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: curvedWeekView.scrollBy(1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── TILE 5: BATTERY & POWER BENTO (1 Col) ─────
                            // Direction: Bottom-Center
                            Item {
                                id: tile5Wrapper
                                width: 230
                                height: parent.height
                                opacity: 0.0
                                scale: 0.94
                                transform: Translate { id: t5Trans; x: 0; y: 24 }

                                SequentialAnimation {
                                    id: tile5InAnim
                                    running: true
                                    PauseAnimation { duration: 320 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile5Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile5Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t5Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                }

                                Rectangle {
                                    id: batteryTile
                                    anchors.fill: parent
                                    radius: 26
                                    color: root.cardBg
                                    border.color: root.cardBorder
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 14

                                        // Header Row
                                        Row {
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            spacing: 5

                                            Text {
                                                text: root.isCharging ? "bolt" : "battery_charging_full"
                                                font.family: "Material Symbols Rounded"
                                                font.pixelSize: 14
                                                color: root.isCharging ? root.color02 : root.seal
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Text {
                                                text: "Battery"
                                                font.family: "Genova"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: root.seal
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        // Center Percentage
                                        Row {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -4
                                            spacing: 4

                                            Text {
                                                text: root.batteryPercent + "%"
                                                font.family: "Genova"
                                                font.pixelSize: 46
                                                font.weight: Font.Bold
                                                font.letterSpacing: -1.0
                                                color: root.ink
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        // Level Bar
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 18
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: parent.width - 8
                                            height: 8
                                            radius: 4
                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: Math.max(height, parent.width * (Math.max(0, Math.min(100, root.batteryPercent)) / 100))
                                                radius: 4
                                                color: root.isCharging ? root.color02 : (root.batteryPercent <= 20 ? root.color01 : root.seal)
                                            }
                                        }

                                        // Status
                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: root.isCharging ? "Charging" : "On Battery"
                                            font.family: "Genova"
                                            font.pixelSize: 10
                                            font.weight: Font.Medium
                                            color: root.ink
                                            opacity: 0.65
                                        }
                                    }
                                }
                            }

                            // ── TILE 6: HARDWARE & SCREEN TIME BENTO (1 Col) ──
                            // Direction: Bottom-Right
                            Item {
                                id: tile6Wrapper
                                width: 230
                                height: parent.height
                                opacity: 0.0
                                scale: 0.94
                                transform: Translate { id: t6Trans; x: 0; y: 24 }

                                SequentialAnimation {
                                    id: tile6InAnim
                                    running: true
                                    PauseAnimation { duration: 360 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile6Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile6Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t6Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                }

                                Rectangle {
                                    id: statsTile
                                    anchors.fill: parent
                                    radius: 26
                                    color: root.cardBg
                                    border.color: root.cardBorder
                                    border.width: 1

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 14

                                        Column {
                                            id: statsCol
                                            anchors.fill: parent
                                            spacing: 10

                                            readonly property real topH: Math.round((height - spacing) * 0.48)
                                            readonly property real botH: height - topH - spacing

                                            // Top Half: RAM & CPU Cards
                                            Row {
                                                id: statsTopRow
                                                width: parent.width
                                                height: statsCol.topH
                                                spacing: 8

                                                // CPU Metric Card
                                                Rectangle {
                                                    width: (parent.width - 8) / 2
                                                    height: parent.height
                                                    radius: 16
                                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                                    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                                    border.width: 1

                                                    Item {
                                                        anchors.fill: parent
                                                        anchors.margins: 10

                                                        Row {
                                                            id: cpuHeader
                                                            anchors.top: parent.top
                                                            anchors.left: parent.left
                                                            spacing: 4

                                                            Text {
                                                                text: "developer_board"
                                                                font.family: "Material Symbols Rounded"
                                                                font.pixelSize: 12
                                                                color: root.seal
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }

                                                            Text {
                                                                text: "CPU"
                                                                font.family: "Genova"
                                                                font.pixelSize: 10
                                                                font.weight: Font.Bold
                                                                color: root.seal
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                        }

                                                        Text {
                                                            anchors.top: cpuHeader.bottom
                                                            anchors.topMargin: 2
                                                            anchors.left: parent.left
                                                            text: root.cpuPercent + "%"
                                                            font.family: "Genova"
                                                            font.pixelSize: 18
                                                            font.weight: Font.Bold
                                                            font.letterSpacing: -0.5
                                                            color: root.ink
                                                        }

                                                        // Utilization bar
                                                        Rectangle {
                                                            anchors.bottom: parent.bottom
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            height: 4
                                                            radius: 2
                                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                                                            Rectangle {
                                                                anchors.left: parent.left
                                                                anchors.top: parent.top
                                                                anchors.bottom: parent.bottom
                                                                width: Math.max(height, parent.width * (Math.max(0, Math.min(100, root.cpuPercent)) / 100))
                                                                radius: 2
                                                                color: root.cpuPercent > 80 ? root.color01 : root.seal

                                                                Behavior on width {
                                                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // RAM Metric Card
                                                Rectangle {
                                                    width: (parent.width - 8) / 2
                                                    height: parent.height
                                                    radius: 16
                                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                                    border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                                    border.width: 1

                                                    Item {
                                                        anchors.fill: parent
                                                        anchors.margins: 10

                                                        Row {
                                                            id: ramHeader
                                                            anchors.top: parent.top
                                                            anchors.left: parent.left
                                                            spacing: 4

                                                            Text {
                                                                text: "memory"
                                                                font.family: "Material Symbols Rounded"
                                                                font.pixelSize: 12
                                                                color: root.color06
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }

                                                            Text {
                                                                text: "RAM"
                                                                font.family: "Genova"
                                                                font.pixelSize: 10
                                                                font.weight: Font.Bold
                                                                color: root.color06
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                        }

                                                        Text {
                                                            anchors.top: ramHeader.bottom
                                                            anchors.topMargin: 2
                                                            anchors.left: parent.left
                                                            text: root.memPercent + "%"
                                                            font.family: "Genova"
                                                            font.pixelSize: 18
                                                            font.weight: Font.Bold
                                                            font.letterSpacing: -0.5
                                                            color: root.ink
                                                        }

                                                        // Utilization bar
                                                        Rectangle {
                                                            anchors.bottom: parent.bottom
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            height: 4
                                                            radius: 2
                                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                                                            Rectangle {
                                                                anchors.left: parent.left
                                                                anchors.top: parent.top
                                                                anchors.bottom: parent.bottom
                                                                width: Math.max(height, parent.width * (Math.max(0, Math.min(100, root.memPercent)) / 100))
                                                                radius: 2
                                                                color: root.memPercent > 85 ? root.color01 : root.color06

                                                                Behavior on width {
                                                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Bottom Half: Screen Time Today Card
                                            Rectangle {
                                                width: parent.width
                                                height: statsCol.botH
                                                radius: 18
                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                                                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                                border.width: 1

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 12

                                                    Rectangle {
                                                        width: 40
                                                        height: 40
                                                        radius: 20
                                                        color: Qt.rgba(root.color03.r, root.color03.g, root.color03.b, 0.12)
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        Text {
                                                            text: "hourglass_empty"
                                                            font.family: "Material Symbols Rounded"
                                                            font.pixelSize: 20
                                                            color: root.color03
                                                            anchors.centerIn: parent
                                                        }
                                                    }

                                                    Column {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        Text {
                                                            text: root.screentimeFormatted
                                                            font.family: "Genova"
                                                            font.pixelSize: 18
                                                            font.weight: Font.Bold
                                                            font.letterSpacing: -0.4
                                                            color: root.ink
                                                        }

                                                        Text {
                                                            text: "Screen Time Today"
                                                            font.family: "Genova"
                                                            font.pixelSize: 10
                                                            font.weight: Font.Medium
                                                            color: root.ink
                                                            opacity: 0.65
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 6. SLEEK FROSTED PASSWORD PILL (Bottom Row) ───────────────
                Item {
                    id: passwordArea
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 48
                    anchors.horizontalCenter: parent.horizontalCenter

                    readonly property bool isTyping: root.enteredPassword.length > 0 && !root.failureMessage && !root.authenticating
                    readonly property bool isIdle: root.enteredPassword.length === 0 && !root.failureMessage && !root.authenticating

                    width: Math.max(220, isTyping ? (dotsRow.implicitWidth + 36) : (isIdle ? (idleRow.implicitWidth + 36) : (root.authenticating ? 160 : errorText.implicitWidth + 36)))
                    height: 38
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    opacity: 0.0
                    transform: Translate { id: pwdShake; x: 0; y: 16 }

                    SequentialAnimation {
                        id: pwdInAnim
                        running: true
                        PauseAnimation { duration: 320 }
                        ParallelAnimation {
                            NumberAnimation { target: passwordArea; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                            NumberAnimation { target: pwdShake; property: "y"; to: 0; duration: 420; easing.type: Easing.OutCubic }
                        }
                    }

                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: pwdShake; property: "x"; to: -14; duration: 40 }
                        NumberAnimation { target: pwdShake; property: "x"; to: 14; duration: 80 }
                        NumberAnimation { target: pwdShake; property: "x"; to: -8; duration: 60 }
                        NumberAnimation { target: pwdShake; property: "x"; to: 8; duration: 60 }
                        NumberAnimation { target: pwdShake; property: "x"; to: 0; duration: 40 }
                    }

                    Connections {
                        target: root
                        function onFailedAttemptsChanged() {
                            if (root.failedAttempts > 0) {
                                shakeAnim.restart()
                            }
                        }
                    }

                    // Glass Capsule Background
                    Rectangle {
                        id: pillBg
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(root.paper.r * 0.25 + 0.04, root.paper.g * 0.25 + 0.04, root.paper.b * 0.25 + 0.04, 0.72)
                        border.color: root.failureMessage.length > 0 ? Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.50) :
                                      (passwordArea.isTyping ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.40) :
                                       Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12))
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    // 1. Idle State: Breathing Lock Icon + "Type Password to Unlock"
                    Row {
                        id: idleRow
                        anchors.centerIn: parent
                        spacing: 8
                        visible: passwordArea.isIdle
                        opacity: idleBreathing.pulseOpacity

                        Text {
                            text: "lock"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 14
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Type Password to Unlock"
                            font.family: "Genova"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.letterSpacing: 0.2
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        id: idleBreathing
                        property real pulseOpacity: 0.85
                        SequentialAnimation {
                            running: passwordArea.isIdle
                            loops: Animation.Infinite
                            NumberAnimation { target: idleBreathing; property: "pulseOpacity"; to: 0.55; duration: 1500; easing.type: Easing.InOutSine }
                            NumberAnimation { target: idleBreathing; property: "pulseOpacity"; to: 0.95; duration: 1500; easing.type: Easing.InOutSine }
                        }
                    }

                    // 2. Typing State: Glowing Dots
                    Row {
                        id: dotsRow
                        anchors.centerIn: parent
                        spacing: 10
                        visible: passwordArea.isTyping

                        Repeater {
                            model: root.enteredPassword.length
                            delegate: Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: root.seal

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: root.seal
                                    opacity: 0.35
                                    z: -1
                                }
                            }
                        }
                    }

                    // 3. Authenticating State: Spinner + Verifying
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.authenticating

                        Text {
                            text: "sync"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 16
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter

                            NumberAnimation on rotation {
                                running: root.authenticating
                                loops: Animation.Infinite
                                from: 0; to: 360
                                duration: 900
                            }
                        }

                        Text {
                            text: "Verifying..."
                            font.family: "Genova"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // 4. Error Message
                    Text {
                        id: errorText
                        anchors.centerIn: parent
                        text: root.failureMessage
                        font.family: "Genova"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: root.color01
                        visible: root.failureMessage.length > 0 && !root.authenticating
                    }
                }

                // ── 7. UNLOCK EXIT ANIMATION (Tiles fly out in their respective directions) ──
                Connections {
                    target: root
                    function onStartUnlockAnimation() {
                        try {
                            greetingInAnim.stop()
                            pwdInAnim.stop()
                            tile1InAnim.stop()
                            tile2InAnim.stop()
                            tile3InAnim.stop()
                            tile4InAnim.stop()
                            tile5InAnim.stop()
                            tile6InAnim.stop()
                            unlockExitAnim.restart()
                        } catch (e) {
                            console.log("Exit anim error:", e)
                            root.completeUnlock()
                        }
                    }
                }

                ParallelAnimation {
                    id: unlockExitAnim
                    onFinished: {
                        root.completeUnlock()
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
                        NumberAnimation { target: greetingTranslate; property: "y"; to: -20; duration: 220; easing.type: Easing.InQuad }
                    }

                    // Password Area fades out quickly
                    NumberAnimation { target: passwordArea; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.OutQuad }

                    // Top Row Bento Cards (Tile 1, 2, 3) glide up smoothly
                    ParallelAnimation {
                        NumberAnimation { target: tile1Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                        NumberAnimation { target: tile1Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                        NumberAnimation { target: t1Trans; property: "y"; to: -32; duration: 240; easing.type: Easing.InQuad }

                        NumberAnimation { target: tile2Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                        NumberAnimation { target: tile2Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                        NumberAnimation { target: t2Trans; property: "y"; to: -32; duration: 240; easing.type: Easing.InQuad }

                        NumberAnimation { target: tile3Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                        NumberAnimation { target: tile3Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                        NumberAnimation { target: t3Trans; property: "y"; to: -32; duration: 240; easing.type: Easing.InQuad }
                    }

                    // Bottom Row Bento Cards (Tile 4, 5, 6) glide down smoothly
                    SequentialAnimation {
                        PauseAnimation { duration: 20 }
                        ParallelAnimation {
                            NumberAnimation { target: tile4Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { target: tile4Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                            NumberAnimation { target: t4Trans; property: "y"; to: 32; duration: 240; easing.type: Easing.InQuad }

                            NumberAnimation { target: tile5Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { target: tile5Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                            NumberAnimation { target: t5Trans; property: "y"; to: 32; duration: 240; easing.type: Easing.InQuad }

                            NumberAnimation { target: tile6Wrapper; property: "opacity"; to: 0.0; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { target: tile6Wrapper; property: "scale"; to: 0.95; duration: 240; easing.type: Easing.InQuad }
                            NumberAnimation { target: t6Trans; property: "y"; to: 32; duration: 240; easing.type: Easing.InQuad }
                        }
                    }
                }
            }
        }
    }
}

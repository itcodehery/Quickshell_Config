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
        Qt.callLater(function() {
            Quickshell.execDetached(["bash", "-c", "kill -9 $QS_LOCK_PID 2>/dev/null; qs kill -p ~/.config/quickshell/lock/shell.qml 2>/dev/null; pkill -f 'quickshell/lock/shell.qml' 2>/dev/null"])
            Qt.quit()
        })
    }

    Timer {
        id: unlockSafetyTimer
        interval: 650
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
                    Quickshell.execDetached(["bash", "-c", "kill -9 $QS_LOCK_PID 2>/dev/null; qs kill -p ~/.config/quickshell/lock/shell.qml 2>/dev/null; pkill -f 'quickshell/lock/shell.qml' 2>/dev/null"])
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

                // ── 0. DEEP BLACK FOUNDATION LAYER ───────────────────────────
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                }

                // ── 1. CURRENT WALLPAPER WITH 15% OPACITY & BLUR ON TOP ──────
                Image {
                    id: wallpaperRaw
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
                    fillMode: Image.PreserveAspectCrop
                    cache: true
                    visible: false
                }

                MultiEffect {
                    id: blurredWallpaperEffect
                    source: wallpaperRaw
                    anchors.fill: parent
                    blurEnabled: true
                    blur: 0.85
                    blurMax: 48
                    opacity: 0.25
                }

                // ── 2. WATERDROP INK SWEEP (Desktop Snapshot sweeps into blurred wallpaper from corners) ──
                property real maxDropRadius: Math.ceil(Math.sqrt((screenRoot.width * screenRoot.width) + (screenRoot.height * screenRoot.height)) / 2) + 120
                property real dropRadius: maxDropRadius
                property bool dropFinished: false

                NumberAnimation on dropRadius {
                    id: waterdropAnim
                    from: screenRoot.maxDropRadius
                    to: 0
                    duration: 1200
                    easing.type: Easing.InOutCubic
                    onFinished: screenRoot.dropFinished = true
                }

                // Unblurred desktop snapshot being masked
                Image {
                    id: desktopSnapshot
                    anchors.fill: parent
                    source: "file:///tmp/qs-lock-bg.png"
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    visible: false
                    onStatusChanged: {
                        if (status === Image.Error) {
                            source = "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
                        }
                    }
                }

                // Circular Hole Item (keeps desktop snapshot inside the circle)
                Item {
                    id: maskHoleContainer
                    anchors.fill: parent
                    visible: false

                    Rectangle {
                        id: holeCircle
                        width: Math.max(0, screenRoot.dropRadius * 2)
                        height: Math.max(0, screenRoot.dropRadius * 2)
                        radius: Math.max(0, screenRoot.dropRadius)
                        anchors.centerIn: parent
                        color: "#ffffff"
                    }
                }

                // GPU MultiEffect Mask: renders snapshot inside the circle, revealing the 15% blurred wallpaper outside from the corners!
                MultiEffect {
                    id: waterdropEffect
                    source: desktopSnapshot
                    anchors.fill: parent
                    visible: !screenRoot.dropFinished
                    maskEnabled: true
                    maskSource: maskHoleContainer
                    maskInverted: false
                    maskThresholdMin: 0.0
                    maskSpreadAtMin: 0.30
                }

                // Liquid ripple contraction ring
                Rectangle {
                    visible: !screenRoot.dropFinished && screenRoot.dropRadius > 4
                    width: Math.max(0, screenRoot.dropRadius * 2)
                    height: Math.max(0, screenRoot.dropRadius * 2)
                    radius: Math.max(0, screenRoot.dropRadius)
                    anchors.centerIn: parent
                    color: "transparent"
                    border.width: 3
                    border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.40 * Math.min(1.0, screenRoot.dropRadius / 250))
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

                // ── 4. TOP CENTER GREETING (Clean single row at top center) ────
                Item {
                    id: greetingContainer
                    anchors.top: parent.top
                    anchors.topMargin: 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: greetingTxt.implicitWidth
                    height: greetingTxt.implicitHeight

                    opacity: 0.0
                    transform: Translate { id: greetingTranslate; y: -12 }

                    SequentialAnimation {
                        id: greetingInAnim
                        running: true
                        PauseAnimation { duration: 520 }
                        ParallelAnimation {
                            NumberAnimation { target: greetingContainer; property: "opacity"; to: 0.70; duration: 450; easing.type: Easing.OutCubic }
                            NumberAnimation { target: greetingTranslate; property: "y"; to: 0; duration: 500; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        id: greetingTxt
                        text: root.greeting
                        font.family: "DM Sans"
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.letterSpacing: 0.5
                        color: root.ink
                        anchors.centerIn: parent
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
                                scale: 0.72
                                transform: Translate { id: t1Trans; x: -80; y: -70 }

                                SequentialAnimation {
                                    id: tile1InAnim
                                    running: true
                                    PauseAnimation { duration: 600 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile1Wrapper; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile1Wrapper; property: "scale"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                        NumberAnimation { target: t1Trans; property: "x"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t1Trans; property: "y"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                                font.family: "DM Sans"
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
                                                font.family: "DM Sans"
                                                font.pixelSize: 42
                                                font.weight: Font.Bold
                                                color: root.ink
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                            Text {
                                                text: ":" + Qt.formatTime(root.now, "ss")
                                                font.family: "DM Sans"
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
                                                font.family: "DM Sans"
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
                                                font.family: "DM Sans"
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
                                scale: 0.72
                                transform: Translate { id: t2Trans; x: 0; y: -80 }

                                SequentialAnimation {
                                    id: tile2InAnim
                                    running: true
                                    PauseAnimation { duration: 740 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile2Wrapper; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile2Wrapper; property: "scale"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                        NumberAnimation { target: t2Trans; property: "y"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                                  "<span style='color:" + root.toHex(root.color07) + "'> now</span><br>" +
                                                  "<span style='color:" + root.toHex(root.color07) + "'>in </span>" +
                                                  "<span style='color:" + root.toHex(root.seal) + "; font-weight:700'>" + root.weatherCity + ".</span><br>" +
                                                  "<span style='color:" + root.toHex(root.color07) + "'>Will be </span>" +
                                                  "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherPhrase.cond1 + "</span><br>" +
                                                  "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherPhrase.cond2 + ".</span>"
                                            font.family: "DM Sans"
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
                                scale: 0.72
                                transform: Translate { id: t3Trans; x: 80; y: -70 }

                                SequentialAnimation {
                                    id: tile3InAnim
                                    running: true
                                    PauseAnimation { duration: 880 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile3Wrapper; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile3Wrapper; property: "scale"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                        NumberAnimation { target: t3Trans; property: "x"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t3Trans; property: "y"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                                        font.family: "DM Sans"
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
                                                        font.family: "DM Sans"
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
                                                        font.family: "DM Sans"
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
                                                    font.family: "DM Sans"
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
                                                        font.family: "DM Sans"
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
                                                font.family: "DM Sans"
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
                                                font.family: "DM Sans"
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                color: root.ink
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                            Text {
                                                text: "Play music from Spotify or browser"
                                                font.family: "DM Sans"
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
                                scale: 0.72
                                transform: Translate { id: t4Trans; x: -80; y: 70 }

                                SequentialAnimation {
                                    id: tile4InAnim
                                    running: true
                                    PauseAnimation { duration: 1020 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile4Wrapper; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile4Wrapper; property: "scale"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                        NumberAnimation { target: t4Trans; property: "x"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t4Trans; property: "y"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                                    font.family: "DM Sans"
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
                                                        font.family: "DM Sans"
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
                                                        font.family: "DM Sans"
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
                                                        font.family: "DM Sans"
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
                                                font.family: "DM Sans"
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
                                scale: 0.72
                                transform: Translate { id: t5Trans; x: 0; y: 80 }

                                SequentialAnimation {
                                    id: tile5InAnim
                                    running: true
                                    PauseAnimation { duration: 1160 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile5Wrapper; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile5Wrapper; property: "scale"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                        NumberAnimation { target: t5Trans; property: "y"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                                font.family: "DM Sans"
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
                                                font.family: "DM Sans"
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
                                            font.family: "DM Sans"
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
                                scale: 0.72
                                transform: Translate { id: t6Trans; x: 80; y: 70 }

                                SequentialAnimation {
                                    id: tile6InAnim
                                    running: true
                                    PauseAnimation { duration: 1300 }
                                    ParallelAnimation {
                                        NumberAnimation { target: tile6Wrapper; property: "opacity"; to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: tile6Wrapper; property: "scale"; to: 1.0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                        NumberAnimation { target: t6Trans; property: "x"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                        NumberAnimation { target: t6Trans; property: "y"; to: 0; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
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
                                            anchors.fill: parent
                                            spacing: 10

                                            // Top Half: RAM & CPU Pills
                                            Row {
                                                width: parent.width
                                                spacing: 8

                                                // CPU Mini Metric
                                                Rectangle {
                                                    width: (parent.width - 8) / 2
                                                    height: 52
                                                    radius: 14
                                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                                    Column {
                                                        anchors.centerIn: parent
                                                        spacing: 2
                                                        Text {
                                                            text: "CPU"
                                                            font.family: "DM Sans"
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                            color: root.seal
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                        }
                                                        Text {
                                                            text: root.cpuPercent + "%"
                                                            font.family: "DM Sans"
                                                            font.pixelSize: 14
                                                            font.weight: Font.Bold
                                                            color: root.ink
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                        }
                                                    }
                                                }

                                                // RAM Mini Metric
                                                Rectangle {
                                                    width: (parent.width - 8) / 2
                                                    height: 52
                                                    radius: 14
                                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                                    Column {
                                                        anchors.centerIn: parent
                                                        spacing: 2
                                                        Text {
                                                            text: "RAM"
                                                            font.family: "DM Sans"
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                            color: root.seal
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                        }
                                                        Text {
                                                            text: root.memPercent + "%"
                                                            font.family: "DM Sans"
                                                            font.pixelSize: 14
                                                            font.weight: Font.Bold
                                                            color: root.ink
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                        }
                                                    }
                                                }
                                            }

                                            // Bottom Half: Screen Time Today
                                            Rectangle {
                                                width: parent.width
                                                height: 64
                                                radius: 16
                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                                Row {
                                                    anchors.centerIn: parent
                                                    spacing: 10

                                                    Text {
                                                        text: "hourglass_empty"
                                                        font.family: "Material Symbols Rounded"
                                                        font.pixelSize: 22
                                                        color: root.seal
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }

                                                    Column {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 1

                                                        Text {
                                                            text: root.screentimeFormatted
                                                            font.family: "DM Sans"
                                                            font.pixelSize: 16
                                                            font.weight: Font.Bold
                                                            color: root.ink
                                                        }

                                                        Text {
                                                            text: "Screen Time Today"
                                                            font.family: "DM Sans"
                                                            font.pixelSize: 9
                                                            font.weight: Font.Medium
                                                            color: root.ink
                                                            opacity: 0.60
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

                // ── 6. BORDERLESS / BACKGROUNDLESS PASSWORD FIELD (Bottom Row) ─
                Item {
                    id: passwordArea
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 48
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(260, dotsRow.implicitWidth + 30)
                    height: 40

                    opacity: (root.enteredPassword.length > 0 || root.failureMessage.length > 0 || root.authenticating) ? 1.0 : 0.0
                    visible: opacity > 0.001
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    transform: Translate { id: pwdShake; x: 0 }

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

                    // Masked Glowing Dots (Zero border, Zero background)
                    Row {
                        id: dotsRow
                        anchors.centerIn: parent
                        spacing: 12
                        visible: root.enteredPassword.length > 0 && !root.failureMessage && !root.authenticating

                        Repeater {
                            model: root.enteredPassword.length
                            delegate: Rectangle {
                                width: 10
                                height: 10
                                radius: 5
                                color: root.seal
                                scale: 1.0

                                // Subtle glow aura
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: root.seal
                                    opacity: 0.35
                                    z: -1
                                }
                            }
                        }
                    }

                    // Authenticating indicator
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: root.authenticating

                        Text {
                            text: "sync"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 18
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
                            font.family: "DM Sans"
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    // Error Message
                    Text {
                        anchors.centerIn: parent
                        text: root.failureMessage
                        font.family: "DM Sans"
                        font.pixelSize: 13
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

                    // Top Greeting fades and glides up
                    ParallelAnimation {
                        NumberAnimation { target: greetingContainer; property: "opacity"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
                        NumberAnimation { target: greetingTranslate; property: "y"; to: -24; duration: 250; easing.type: Easing.InCubic }
                    }

                    // Password Area fades out immediately
                    NumberAnimation { target: passwordArea; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.OutQuad }

                    // Tile 1: Top-Left flies back out to Top-Left (x: -120, y: -100)
                    SequentialAnimation {
                        PauseAnimation { duration: 0 }
                        ParallelAnimation {
                            NumberAnimation { target: tile1Wrapper; property: "opacity"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                            NumberAnimation { target: tile1Wrapper; property: "scale"; to: 0.65; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t1Trans; property: "x"; to: -120; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t1Trans; property: "y"; to: -100; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                        }
                    }

                    // Tile 2: Top-Center flies back out to Top (y: -120)
                    SequentialAnimation {
                        PauseAnimation { duration: 40 }
                        ParallelAnimation {
                            NumberAnimation { target: tile2Wrapper; property: "opacity"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                            NumberAnimation { target: tile2Wrapper; property: "scale"; to: 0.65; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t2Trans; property: "y"; to: -120; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                        }
                    }

                    // Tile 3: Top-Right flies back out to Top-Right (x: 120, y: -100)
                    SequentialAnimation {
                        PauseAnimation { duration: 80 }
                        ParallelAnimation {
                            NumberAnimation { target: tile3Wrapper; property: "opacity"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                            NumberAnimation { target: tile3Wrapper; property: "scale"; to: 0.65; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t3Trans; property: "x"; to: 120; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t3Trans; property: "y"; to: -100; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                        }
                    }

                    // Tile 4: Bottom-Left flies back out to Bottom-Left (x: -120, y: 100)
                    SequentialAnimation {
                        PauseAnimation { duration: 120 }
                        ParallelAnimation {
                            NumberAnimation { target: tile4Wrapper; property: "opacity"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                            NumberAnimation { target: tile4Wrapper; property: "scale"; to: 0.65; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t4Trans; property: "x"; to: -120; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t4Trans; property: "y"; to: 100; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                        }
                    }

                    // Tile 5: Bottom-Center flies back out to Bottom (y: 120)
                    SequentialAnimation {
                        PauseAnimation { duration: 160 }
                        ParallelAnimation {
                            NumberAnimation { target: tile5Wrapper; property: "opacity"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                            NumberAnimation { target: tile5Wrapper; property: "scale"; to: 0.65; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t5Trans; property: "y"; to: 120; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                        }
                    }

                    // Tile 6: Bottom-Right flies back out to Bottom-Right (x: 120, y: 100)
                    SequentialAnimation {
                        PauseAnimation { duration: 200 }
                        ParallelAnimation {
                            NumberAnimation { target: tile6Wrapper; property: "opacity"; to: 0.0; duration: 240; easing.type: Easing.InCubic }
                            NumberAnimation { target: tile6Wrapper; property: "scale"; to: 0.65; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t6Trans; property: "x"; to: 120; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                            NumberAnimation { target: t6Trans; property: "y"; to: 100; duration: 320; easing.type: Easing.InBack; easing.overshoot: 1.15 }
                        }
                    }

                    // Screen background smoothly dissolves to reveal live session
                    SequentialAnimation {
                        PauseAnimation { duration: 220 }
                        NumberAnimation { target: screenRoot; property: "opacity"; to: 0.0; duration: 300; easing.type: Easing.InOutQuad }
                    }
                }
            }
        }
    }
}

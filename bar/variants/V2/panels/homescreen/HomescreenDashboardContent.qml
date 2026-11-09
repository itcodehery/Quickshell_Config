import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQml.Models
import "../../modules"
import "../../motion"
import "HomescreenHelpers.js" as Helpers

Item {
    id: dashboardContent
    anchors.fill: parent
    implicitHeight: 220
    focus: true

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            if (tilesModel.count === 0) initTiles()
            if (!root || !root.dashboardDetail) {
                activeDetailView = ""
                selectCategoryByIndex(0)
            }
            if (selectedTileId === "" && tilesModel.count > 0) {
                selectedTileId = tilesModel.get(0).id
            }
        }
    }
    Component.onCompleted: {
        forceActiveFocus()
        initTiles()
        if (!root || !root.dashboardDetail) {
            activeDetailView = ""
            selectCategoryByIndex(0)
        }
        if (selectedTileId === "" && tilesModel.count > 0) {
            selectedTileId = tilesModel.get(0).id
        }
        recalculateGridLayout()
    }

    SpringPress {}
    MouseArea {
        anchors.fill: parent
        // Prevent clicks anywhere on the dashboard background from closing the dashboard
        onClicked: { dashboardContent.forceActiveFocus() }
    }

    // ── Resizable & Movable Tiles State ──
    property bool editTilesMode: false
    property string selectedTileId: ""
    property string draggingTileId: ""
    property int dragTileSpan: 1
    property bool caffeineActive: false
    property int cpuTemp: 45
    readonly property color cpuTempColor: cpuTemp < 52 ? "#22d3ee" : (cpuTemp < 72 ? "#fbbf24" : "#f87171")

    readonly property var defaultTiles: [
        { id: "wifi", span: 2 },
        { id: "bluetooth", span: 2 },
        { id: "notifications", span: 2 },
        { id: "screentime", span: 2 },
        { id: "nightlight", span: 1 },
        { id: "caffeine", span: 1 },
        { id: "battery", span: 1 },
        { id: "temperature", span: 1 },
        { id: "plugins", span: 2 },
        { id: "updates", span: 1 },
        { id: "pomodoro", span: 1 },
        { id: "quickshare", span: 1 },
        { id: "theme", span: 1 },
        { id: "wallpaper", span: 1 }
    ]

    readonly property real gridCardPadding: 10
    readonly property real gridInnerWidth: leftCol.width - gridCardPadding * 2
    readonly property real tileUnitWidth: Math.floor((gridInnerWidth - 30) / 4)
    readonly property real tileDoubleWidth: tileUnitWidth * 2 + 10
    readonly property real pageStride: 122 + 12
    property int totalPageCount: 1
    property bool showPomodoroPopup: false

    readonly property alias tilesModel: tilesModel
    ListModel {
        id: tilesModel
        Component.onCompleted: dashboardContent.initTiles()
    }

    property string dropTargetTileId: ""

    readonly property var tilesPager: tilesPagerContainer.tilesPager

    function recalculateGridLayout() {
        Helpers.recalculateGridLayout(dashboardContent, tilesModel, tilesPager, smoothScrollAnim)
    }

    function setTileSpan(id, newSpan) {
        Helpers.setTileSpan(dashboardContent, tilesModel, id, newSpan)
    }

    function toggleTileSpan(id) {
        Helpers.cycleTileSpan(dashboardContent, tilesModel, id)
    }

    function cycleTileSpan(id) {
        Helpers.cycleTileSpan(dashboardContent, tilesModel, id)
    }

    function getTileSpan(id) {
        return Helpers.getTileSpan(tilesModel, id)
    }

    function toggleEditMode(id) {
        Helpers.toggleEditMode(dashboardContent, tilesModel, id)
    }

    function moveSelectedTile(dir) {
        Helpers.moveSelectedTile(dashboardContent, tilesModel, dir)
    }

    function startDraggingTile(id, globalX, globalY) {
        Helpers.startDraggingTile(dashboardContent, dragPreviewItem, id, globalX, globalY)
    }

    function updateDraggingTile(globalX, globalY) {
        Helpers.updateDraggingTile(dashboardContent, tilesModel, tilesPager, autoScrollTimer, dragPreviewItem, globalX, globalY)
    }

    function finishDraggingTile() {
        Helpers.finishDraggingTile(dashboardContent, tilesModel)
    }

    function getTilePageIndex(id) {
        return Helpers.getTilePageIndex(tilesModel, id)
    }

    function navigateTile(dir) {
        Helpers.navigateTile(dashboardContent, tilesModel, dir)
    }

    function triggerTileAction(tileId) {
        Helpers.triggerTileAction(dashboardContent, tileId)
    }

    function launchQuickshare() {
        Quickshell.execDetached(["localsend"])
    }

    function toggleCaffeine() {
        if (dashboardContent.caffeineActive) {
            Quickshell.execDetached(["pkill", "-f", "why=caffeine"])
            dashboardContent.caffeineActive = false
        } else {
            Quickshell.execDetached(["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=caffeine", "sleep", "infinity"])
            dashboardContent.caffeineActive = true
        }
    }

    function refreshCpuTemp() {
        tempUpdater.running = false
        tempUpdater.running = true
    }

    function initTiles() {
        Helpers.initTiles(dashboardContent, tilesModel, tilesLayoutFile)
    }

    function loadDefaultTiles() {
        Helpers.loadDefaultTiles(dashboardContent, tilesModel)
    }

    function loadCustomTiles(savedList) {
        Helpers.loadCustomTiles(dashboardContent, tilesModel, savedList)
    }

    function saveTilesLayout() {
        Helpers.saveTilesLayout(tilesModel, saveLayoutProc)
    }

    function resetTilesLayout() {
        loadDefaultTiles()
        saveTilesLayout()
    }

    readonly property var detailOrder: ["", "wifi", "bluetooth", "notifications", "screentime", "plugins", "updates", "notes", "battery", "calendar", "volume", "system", "theme", "wallpaper"]

    function selectCategoryByIndex(idx) {
        if (idx < 0) idx = 0
        if (idx >= detailOrder.length) idx = detailOrder.length - 1
        let cat = detailOrder[idx]
        dashboardContent.activeDetailView = cat
        if (root) root.dashboardDetail = cat

        // Keep left-hand tilesPager in sync so active tile is visible
        goToPage(getTilePageIndex(cat))

        dashboardContent.forceActiveFocus()
    }

    function jumpNextCategory() {
        let curIdx = detailOrder.indexOf(dashboardContent.activeDetailView)
        let nextIdx = (curIdx + 1) % detailOrder.length
        selectCategoryByIndex(nextIdx)
    }

    function jumpPrevCategory() {
        let curIdx = detailOrder.indexOf(dashboardContent.activeDetailView)
        if (curIdx <= 0) curIdx = detailOrder.length
        let prevIdx = curIdx - 1
        selectCategoryByIndex(prevIdx)
    }

    function nextOption() {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeDetailSection && themeDetailSection.moveSel) themeDetailSection.moveSel(1)
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailSection) sysDetailSection.focusedIndex = (sysDetailSection.focusedIndex + 1) % 4
            return
        }
        jumpNextCategory()
    }

    function prevOption() {
        if (dashboardContent.activeDetailView === "notes" ||
            (calDetailSection && calDetailSection.isInputFocused) ||
            (notesDetailSection && notesDetailSection.isInputFocused)) {
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeDetailSection && themeDetailSection.moveSel) themeDetailSection.moveSel(-1)
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailSection) sysDetailSection.focusedIndex = (sysDetailSection.focusedIndex - 1 + 4) % 4
            return
        }
        jumpPrevCategory()
    }

    Keys.onPressed: (event) => {
        Helpers.handleKeyPressed(dashboardContent, event)
    }
    
    property int targetPageIndex: 0

    NumberAnimation {
        id: smoothScrollAnim
        target: tilesPager
        property: "contentY"
        duration: 260
        easing.type: Easing.OutCubic
        onFinished: {
            if (tilesPager) {
                tilesPager.contentY = targetPageIndex * pageStride
            }
        }
    }
    
    function pageUp() {
        let cur = smoothScrollAnim.running ? targetPageIndex : Math.round(tilesPager.contentY / pageStride)
        if (cur > 0) {
            goToPage(cur - 1)
        } else {
            goToPage(0)
        }
    }
    
    function pageDown() {
        let cur = smoothScrollAnim.running ? targetPageIndex : Math.round(tilesPager.contentY / pageStride)
        if (cur < totalPageCount - 1) {
            goToPage(cur + 1)
        } else {
            goToPage(totalPageCount - 1)
        }
    }

    function goToPage(idx) {
        if (!tilesPager) return
        if (idx < 0) idx = 0
        if (idx >= totalPageCount) idx = totalPageCount - 1
        targetPageIndex = idx
        smoothScrollAnim.stop()
        smoothScrollAnim.to = idx * pageStride
        smoothScrollAnim.start()
    }

    function snapToNearestPage() {
        if (!tilesPager || smoothScrollAnim.running || dashboardContent.draggingTileId !== "") return
        let nearest = Math.max(0, Math.min(totalPageCount - 1, Math.round(tilesPager.contentY / pageStride)))
        goToPage(nearest)
    }

    Timer {
        id: autoScrollTimer
        interval: 350
        property int dir: 0
        onTriggered: {
            if (dashboardContent.draggingTileId === "") return
            if (dir < 0) pageUp()
            else if (dir > 0) pageDown()
        }
    }

    FileView {
        id: tilesLayoutFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell_tiles_layout.json"
        watchChanges: false
        onLoaded: {
            try {
                let txt = tilesLayoutFile.text().trim()
                if (txt.length > 0) {
                    let parsed = JSON.parse(txt)
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        dashboardContent.loadCustomTiles(parsed)
                        return
                    }
                }
            } catch(e) {}
            dashboardContent.loadDefaultTiles()
        }
    }

    Process {
        id: saveLayoutProc
        property string jsonContent: "[]"
        command: ["python3", "-c", "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", Quickshell.env("HOME") + "/.local/state/quickshell_tiles_layout.json", jsonContent]
    }

    Process {
        id: caffeineCheckProc
        running: true
        command: ["bash", "-c", "pgrep -f 'why=caffeine' > /dev/null && echo 'on' || echo 'off'"]
        stdout: StdioCollector {
            onStreamFinished: dashboardContent.caffeineActive = (this.text.trim() === "on")
        }
    }

    Process {
        id: tempReader
        running: true
        command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = parseInt(this.text.trim())
                if (!isNaN(t)) dashboardContent.cpuTemp = Math.round(t / 1000)
            }
        }
    }

    Process {
        id: tempUpdater
        command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = parseInt(this.text.trim())
                if (!isNaN(t)) dashboardContent.cpuTemp = Math.round(t / 1000)
            }
        }
    }

    Timer {
        interval: 2500; repeat: true; running: panel ? panel.expanded : true
        onTriggered: { tempUpdater.running = false; tempUpdater.running = true }
    }

    property var root
    property var panel
    property string activeDetailView: root && root.dashboardDetail ? root.dashboardDetail : ""

    readonly property var wifiDetailSection: detailOverlay.wifiDetailSection
    readonly property var btDetailSection: detailOverlay.btDetailSection
    readonly property var batDetailSection: detailOverlay.batDetailSection
    readonly property var stDetailSection: detailOverlay.stDetailSection
    readonly property var volDetailSection: detailOverlay.volDetailSection
    readonly property var sysDetailSection: detailOverlay.sysDetailSection
    readonly property var calDetailSection: detailOverlay.calDetailSection
    readonly property var notifDetailSection: detailOverlay.notifDetailSection
    readonly property var updatesDetailSection: detailOverlay.updatesDetailSection
    readonly property var notesDetailSection: detailOverlay.notesDetailSection
    readonly property var pluginsDetailSection: detailOverlay.pluginsDetailSection
    readonly property var themeDetailSection: detailOverlay.themeDetailSection

    Connections {
        target: dashboardContent.root
        ignoreUnknownSignals: true
        function onDashboardDetailChanged() {
            if (dashboardContent.root && dashboardContent.activeDetailView !== dashboardContent.root.dashboardDetail) {
                dashboardContent.activeDetailView = dashboardContent.root.dashboardDetail || ""
            }
        }
    }

    onActiveDetailViewChanged: {
        if (root && root.dashboardDetail !== activeDetailView) {
            root.dashboardDetail = activeDetailView
        }
        if (activeDetailView === "") {
            pageUp()
        }
    }

    AudioData { id: audioData }

    property int currentBrightness: 50
    Process {
        running: true
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }
    Timer {
        interval: 3000; repeat: true; running: panel.expanded
        onTriggered: { briUpdater.running = false; briUpdater.running = true }
    }
    Process {
        id: briUpdater
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }

    property string currentWifiName: "Wi-Fi"
    property string currentBtName: "Bluetooth"
    property bool btPowered: false

    property int nightMode: 0 // 0: Off, 1: Soft (4500K), 2: Intense (3000K)
    property real lastNightChange: 0

    function cycleNightMode() {
        let nextMode = (nightMode + 1) % 3
        setNightMode(nextMode)
    }

    function setNightMode(mode) {
        lastNightChange = Date.now()
        nightMode = mode
        if (mode === 0) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset"])
        } else if (mode === 1) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.02; done; exec hyprsunset -t 4500"])
        } else if (mode === 2) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.02; done; exec hyprsunset -t 3000"])
        }
    }

    Process {
        id: nightUpdater
        running: true
        command: ["bash", "-c", "out=$(pgrep -a hyprsunset); if [ -z \"$out\" ]; then echo 'off'; elif echo \"$out\" | grep -q '3000'; then echo 'intense'; else echo 'soft'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - dashboardContent.lastNightChange < 1500) return
                let s = this.text.trim()
                if (s === "intense") dashboardContent.nightMode = 2
                else if (s === "soft") dashboardContent.nightMode = 1
                else dashboardContent.nightMode = 0
            }
        }
    }

    property alias statusTimer: statusTimer
    Timer {
        id: statusTimer
        interval: 3000; repeat: true; running: panel.expanded; triggeredOnStart: true
        onTriggered: {
            wifiUpdater.running = false; wifiUpdater.running = true
            btUpdater.running = false; btUpdater.running = true
            nightUpdater.running = false; nightUpdater.running = true
        }
    }
    
    Process {
        id: wifiUpdater
        command: ["bash", "-c", "nmcli -t -c no -f TYPE,NAME connection show --active | grep 802-11-wireless | cut -d':' -f2- | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = this.text.trim()
                if (s !== "" && dashboardContent.currentWifiName === "Searching...") {
                    statusTimer.interval = 3000 // reset back
                }
                dashboardContent.currentWifiName = s === "" ? "Wi-Fi" : s
            }
        }
    }
    
    Process {
        id: btUpdater
        command: ["bash", "-c", "if bluetoothctl show | grep -q 'Powered: yes'; then echo on; else echo off; fi; bluetoothctl devices Connected | head -n1 | cut -d ' ' -f 3-"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n")
                let powered = (lines[0] || "").trim() === "on"
                let s = (lines[1] || "").trim()
                if (powered && dashboardContent.currentBtName === "Searching...") {
                    statusTimer.interval = 3000
                }
                dashboardContent.btPowered = powered
                dashboardContent.currentBtName = s === "" ? "Bluetooth" : s
            }
        }
    }

    property alias mprisSel: mprisSel
    MprisSelect { id: mprisSel }
    MprisArtwork { id: mprisArt; player: mprisSel.player; root: dashboardContent.root }
    
    property string curTitle: mprisSel.player ? (mprisSel.player.trackTitle || "") : ""
    property string curArtist: mprisSel.player ? (mprisSel.player.trackArtist || "") : ""
    property string curArtUrl: mprisArt.source
    readonly property bool hasMultiplePlayers: mprisSel.count > 1

    // ── Live Time & Date State for Aesthetic Clock Widget ──
    FontLoader {
        id: biggerFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Unknown Vendor/OpenType/Bigger/Bigger_Display.otf"
    }

    property date now: new Date()
    Timer {
        interval: 1000
        running: panel.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: dashboardContent.now = new Date()
    }

    readonly property string clockHours: {
        var h = dashboardContent.now.getHours()
        if (root && root.clock12h) {
            h = h % 12
            if (h === 0) h = 12
        }
        return h < 10 ? "0" + h : String(h)
    }

    readonly property string clockMinutes: {
        var m = dashboardContent.now.getMinutes()
        return m < 10 ? "0" + m : String(m)
    }

    readonly property string clockAmPm: {
        if (!root || !root.clock12h) return ""
        return dashboardContent.now.getHours() < 12 ? "AM" : "PM"
    }

    readonly property string timeGreeting: {
        var h = dashboardContent.now.getHours()
        if (h >= 5 && h < 12) return "Good Morning"
        if (h >= 12 && h < 17) return "Good Afternoon"
        if (h >= 17 && h < 22) return "Good Evening"
        return "Night Owl"
    }

    function getWeekNumber() {
        return Helpers.getWeekNumber(dashboardContent.now)
    }

    readonly property int dayProgressPercent: {
        var totalSecs = dashboardContent.now.getHours() * 3600 + dashboardContent.now.getMinutes() * 60 + dashboardContent.now.getSeconds()
        return Math.min(100, Math.max(0, Math.round((totalSecs / 86400) * 100)))
    }

    readonly property string remainingHoursToday: {
        var remMins = 1440 - (dashboardContent.now.getHours() * 60 + dashboardContent.now.getMinutes())
        var remH = Math.floor(remMins / 60)
        var remM = remMins % 60
        return remH + "h " + remM + "m left"
    }

    // Media Display Mode: Show Media Player only if actively playing or manually requested while paused
    property bool showMediaManually: false
    readonly property bool isMediaPlaying: mprisSel.playing && curTitle !== ""
    readonly property bool showMediaPlayer: isMediaPlaying || (showMediaManually && curTitle !== "")

    Connections {
        target: mprisSel
        function onPlayingChanged() {
            if (mprisSel.playing && dashboardContent.curTitle !== "") {
                dashboardContent.showMediaManually = true
            }
        }
    }
    
    property real curPos: 0
    property real curLen: 0
    property real _lastRead: -1
    
    function fmtTime(s) {
        return Helpers.fmtTime(s)
    }

    function seekTo(ratio) {
        Helpers.seekTo(dashboardContent, mprisSel, ratio)
    }

    Timer {
        id: posTimer
        interval: 250; repeat: true
        running: mprisSel.active
        triggeredOnStart: true
        onTriggered: {
            if (!mprisSel.player) return
            var p = mprisSel.player.position || 0
            dashboardContent.curLen = mprisSel.player.length || 0
            if (Math.abs(p - dashboardContent._lastRead) > 0.05) {
                dashboardContent.curPos = p
                dashboardContent._lastRead = p
            } else if (mprisSel.playing) {
                dashboardContent.curPos = Math.min(dashboardContent.curLen, dashboardContent.curPos + 0.25)
            }
        }
    }

    Connections {
        target: mprisSel
        function onPlayerChanged() {
            dashboardContent.curPos = 0
            dashboardContent._lastRead = -1
            dashboardContent.curLen = mprisSel.player ? (mprisSel.player.length || 0) : 0
            dashboardContent.fetchLocalLyrics()
        }
    }

    readonly property string currentTrackId: {
        var t = curTitle ? curTitle.trim() : ""
        var a = curArtist ? curArtist.trim() : ""
        return (t || a) ? (t + "||" + a) : ""
    }

    property var mprisPanel: null
    property var localLyricsList: []
    property int localLyricIndex: -1
    property string localLyricsTrackId: ""
    property int _localLyricsFetchSeq: 0

    readonly property bool mprisHasTrackLyrics: mprisPanel !== null && mprisPanel !== undefined && mprisPanel.lyricsTrackId !== "" && mprisPanel.lyricsTrackId === currentTrackId && mprisPanel.lyricsList && mprisPanel.lyricsList.length > 0
    readonly property bool localHasTrackLyrics: localLyricsTrackId !== "" && localLyricsTrackId === currentTrackId && localLyricsList && localLyricsList.length > 0

    readonly property var activeLyricsList: mprisHasTrackLyrics ? mprisPanel.lyricsList : (localHasTrackLyrics ? localLyricsList : [])
    readonly property int activeLyricIndex: mprisHasTrackLyrics ? mprisPanel.currentLyricIndex : (localHasTrackLyrics ? localLyricIndex : -1)
    readonly property bool hasSyncedLyrics: mprisSel.active && activeLyricsList && activeLyricsList.length > 0 && activeLyricIndex >= 0 && activeLyricIndex < activeLyricsList.length
    readonly property string activeLyricText: hasSyncedLyrics ? activeLyricsList[activeLyricIndex].text : ""
    readonly property string nextLyricText: (hasSyncedLyrics && (activeLyricIndex + 1) < activeLyricsList.length) ? activeLyricsList[activeLyricIndex + 1].text : ""

    function syncLocalLyricIndex() {
        Helpers.syncLocalLyricIndex(dashboardContent)
    }

    function cleanTrackTitle(str) {
        return Helpers.cleanTrackTitle(str)
    }

    function parseLocalLrc(lrcText) {
        return Helpers.parseLocalLrc(lrcText)
    }

    function fetchLocalLyrics() {
        Helpers.fetchLocalLyrics(dashboardContent)
    }

    onCurTitleChanged: {
        if (root && curTitle !== "") root.lastMediaTitle = curTitle
        fetchLocalLyrics()
    }
    onCurArtistChanged: {
        if (root && curArtist !== "") root.lastMediaArtist = curArtist
        fetchLocalLyrics()
    }
    onCurArtUrlChanged: { if (root && curArtUrl !== "") root.lastMediaArtUrl = curArtUrl }

    Connections {
        target: mprisSel.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { dashboardContent.fetchLocalLyrics() }
        function onTrackArtistChanged() { dashboardContent.fetchLocalLyrics() }
    }

    onCurPosChanged: {
        if (localLyricsList && localLyricsList.length > 0) {
            syncLocalLyricIndex()
        }
    }

    onRootChanged: {
        if (root) {
            recalculateGridLayout()
            if (mprisSel.player && mprisSel.player.trackTitle) {
                root.lastMediaTitle = mprisSel.player.trackTitle || ""
                root.lastMediaArtist = mprisSel.player.trackArtist || ""
            }
            if (mprisArt.source) root.lastMediaArtUrl = mprisArt.source
        }
    }

    // ── MAIN CONTROLS (Two Columns: Controls on Left, Media Player on Right) ──
    Item {
        id: mainControls
        anchors.fill: parent
        visible: (opacity > 0.001)
        opacity: dashboardContent.activeDetailView === "" ? 1.0 : 0.0
        scale: dashboardContent.activeDetailView === "" ? 1.0 : 0.98
        transform: Translate {
            y: dashboardContent.activeDetailView === "" ? 0 : (root && root.barPosition === "bottom" ? -10 : 10)
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 14

            // ── LEFT COLUMN: Sliders & Quick Settings Tiles ──
            Column {
                id: leftCol
                width: Math.round((parent.width - parent.spacing) / 2)
                spacing: 10

                // ── TOP CONTROL AREA (Sliders in Normal Mode, Edit Header in Edit Mode) ──
                HomescreenTopControls {
                    id: topControlArea
                    width: parent.width
                    height: 86
                    dashboardContent: dashboardContent
                    root: dashboardContent.root
                    audioData: audioData
                }

                // --- MATERIAL YOU TILES (Dynamic Pager with Resizable & Movable Tiles) ---
                HomescreenTilesPager {
                    id: tilesPagerContainer
                    width: parent.width
                    height: 142
                    dashboardContent: dashboardContent
                    tilesModel: tilesModel
                    smoothScrollAnim: smoothScrollAnim
                }
            } // end leftCol

            // ── RIGHT COLUMN: Media Player & Lyrics Drawer ──
            Item {
                id: rightCol
                width: parent.width - leftCol.width - parent.spacing
                height: leftCol.height

                // --- MATERIAL YOU MEDIA PLAYER WITH EXTENDED LYRICS SECTION ---
                HomescreenMediaLyricsCard {
                    id: mediaWithLyricsGroup
                    anchors.fill: parent
                    dashboardContent: dashboardContent
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                    mprisSel: mprisSel
                    mprisArt: mprisArt
                    audioData: audioData
                }

                // --- COOL AESTHETIC TIME & DATE WIDGET (Zero borders, unified canvas) ---
                HomescreenClockWidget {
                    id: timeDateWidget
                    anchors.fill: parent
                    dashboardContent: dashboardContent
                    root: dashboardContent.root
                    mprisSel: mprisSel
                    biggerFont: biggerFont
                }
            } // end rightCol
        } // end Row

        // ── Dragged Tile Floating Preview (Follows mouse across any page) ──
        Item {
            id: dragPreviewItem
            visible: dashboardContent.draggingTileId !== ""
            enabled: false
            z: 9999
            width: (dashboardContent.dragTileSpan === 2 || dashboardContent.dragTileSpan === 4) ? dashboardContent.tileDoubleWidth : dashboardContent.tileUnitWidth
            height: (dashboardContent.dragTileSpan === 4) ? 122 : 56
            scale: 1.05
            opacity: 0.92

            property real currentMouseX: 0
            property real currentMouseY: 0
            x: currentMouseX - width / 2
            y: currentMouseY - height / 2

            DashboardTile {
                anchors.fill: parent
                dashContent: dashboardContent
                tileId: dashboardContent.draggingTileId || "wifi"
                span: dashboardContent.dragTileSpan
                tileIndex: -1
            }
        }
    } // end mainControls

    // ── DETAIL OVERLAY (Phone-style sub-page sheet) ──
    HomescreenDetailOverlay {
        id: detailOverlay
        anchors.fill: parent
        dashboardContent: dashboardContent
        root: dashboardContent.root
        panel: dashboardContent.panel
    }

    // ── POMODORO TIMER POPUP (Sleek Material You modal to view, pause, or disable the timer) ──
    HomescreenPomodoroPopup {
        id: pomodoroPopupBackdrop
        anchors.fill: parent
        dashboardContent: dashboardContent
        root: dashboardContent.root
    }
}

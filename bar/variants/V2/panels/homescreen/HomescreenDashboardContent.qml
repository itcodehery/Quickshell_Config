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
        if (root && root.dashboardExpanded) {
            startJarvisBoot()
        }
    }

    // ── Jarvis M3 Expressive Boot-Up Choreography ──
    property real orbitalBootProgress: 1.0
    property real leftSlidersBoot: 1.0
    property real leftTilesBoot: 1.0
    property real mediaBoot: 1.0
    property real pomodoroBoot: 1.0

    function startJarvisBoot() {
        jarvisBootAnim.stop()
        timeDateWidget.pillProgress = 0.0
        timeDateWidget.pillTextProgress = 0.0
        timeDateWidget.dateProgress = 0.0
        timeDateWidget.dayPctProgress = 0.0
        timeDateWidget.ticksProgress = 0.0
        orbitalBootProgress = 0.0
        leftSlidersBoot = 0.0
        leftTilesBoot = 0.0
        mediaBoot = 0.0
        pomodoroBoot = 0.0
        jarvisBootAnim.start()
    }

    ParallelAnimation {
        id: jarvisBootAnim

        // 1a. Clock Pill appears first (0ms)
        NumberAnimation {
            target: timeDateWidget
            property: "pillProgress"
            from: 0.0; to: 1.0
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
        }

        // 1b. Clock time inside the pill appears next (180ms)
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation {
                target: timeDateWidget
                property: "pillTextProgress"
                from: 0.0; to: 1.0
                duration: 280
                easing.type: Easing.OutQuint
            }
        }

        // 2a. Date fades in (350ms)
        SequentialAnimation {
            PauseAnimation { duration: 350 }
            NumberAnimation {
                target: timeDateWidget
                property: "dateProgress"
                from: 0.0; to: 1.0
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        // 2b. Percent of day fades in next (490ms)
        SequentialAnimation {
            PauseAnimation { duration: 490 }
            NumberAnimation {
                target: timeDateWidget
                property: "dayPctProgress"
                from: 0.0; to: 1.0
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        // 3. Clock second lines fade in clockwise one by one + orbital rings (620ms)
        SequentialAnimation {
            PauseAnimation { duration: 620 }
            ParallelAnimation {
                NumberAnimation {
                    target: timeDateWidget
                    property: "ticksProgress"
                    from: 0.0; to: 1.0
                    duration: 680
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: dashboardContent
                    property: "orbitalBootProgress"
                    from: 0.0; to: 1.0
                    duration: 720
                    easing.type: Easing.OutQuint
                }
            }
        }

        // 4. Left wing (sliders + pills/tiles) cascade in (1050ms, 1180ms)
        SequentialAnimation {
            PauseAnimation { duration: 1050 }
            NumberAnimation {
                target: dashboardContent
                property: "leftSlidersBoot"
                from: 0.0; to: 1.0
                duration: 460
                easing.type: Easing.OutQuint
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 1180 }
            NumberAnimation {
                target: dashboardContent
                property: "leftTilesBoot"
                from: 0.0; to: 1.0
                duration: 460
                easing.type: Easing.OutQuint
            }
        }

        // 5. Media player shoots down from the back of the dashboard (1380ms)
        SequentialAnimation {
            PauseAnimation { duration: 1380 }
            NumberAnimation {
                target: dashboardContent
                property: "mediaBoot"
                from: 0.0; to: 1.0
                duration: 480
                easing.type: Easing.OutQuint
            }
        }

        // 6. Pomodoro card appears last in the intro choreography (1620ms)
        SequentialAnimation {
            PauseAnimation { duration: 1620 }
            NumberAnimation {
                target: dashboardContent
                property: "pomodoroBoot"
                from: 0.0; to: 1.0
                duration: 480
                easing.type: Easing.OutQuint
            }
        }
    }

    SpringPress {}
    MouseArea {
        anchors.fill: parent
        // Click empty space on the cardless canvas to dismiss
        onClicked: {
            if (dashboardContent.editTilesMode) {
                dashboardContent.editTilesMode = false
            } else if (dashboardContent.activeDetailView !== "") {
                dashboardContent.activeDetailView = ""
            } else if (root) {
                root.dashboardExpanded = false
            }
        }
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
        { id: "wallpaper", span: 1 },
        { id: "settings", span: 1 }
    ]

    readonly property real gridCardPadding: 8
    readonly property real gridInnerWidth: leftWing.width - gridCardPadding * 2
    readonly property real tileUnitWidth: Math.floor((gridInnerWidth - 30) / 4)
    readonly property real tileDoubleWidth: tileUnitWidth * 2 + 10
    readonly property real pageStride: 122 + 12
    property int totalPageCount: 1
    property bool showPomodoroPopup: false
    property bool showNightLightPopup: false
    property real nightPopupTargetX: 0
    property real nightPopupTargetY: 0
    property int nightLightIntensity: 0
    property int nightLightSavedIntensity: 40

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

    function setTileShape(id, shape) {
        Helpers.setTileShape(dashboardContent, tilesModel, id, shape)
    }

    function cycleTileShape(id) {
        Helpers.cycleTileShape(dashboardContent, tilesModel, id)
    }

    function getTileShape(id) {
        return Helpers.getTileShape(tilesModel, id)
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

    readonly property var detailOrder: ["", "wifi", "bluetooth", "notifications", "screentime", "plugins", "updates", "notes", "battery", "calendar", "volume", "theme", "wallpaper", "settings"]

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
        jumpPrevCategory()
    }

    Keys.onPressed: (event) => {
        Helpers.handleKeyPressed(dashboardContent, event)
    }
    
    property int targetPageIndex: 0

    SpringAnimation {
        id: smoothScrollAnim
        target: tilesPager ? tilesPager : dummyScrollTarget
        property: "contentY"
        spring: Motion.spatialSpring
        damping: Motion.spatialDamping
        epsilon: 0.5
        onRunningChanged: {
            if (!running && tilesPager) {
                tilesPager.contentY = targetPageIndex * pageStride
            }
        }
    }

    QtObject {
        id: dummyScrollTarget
        property real contentY: 0
    }
    
    function pageUp() {
        if (!tilesPager) return
        let cur = smoothScrollAnim.running ? targetPageIndex : Math.round(tilesPager.contentY / pageStride)
        if (cur > 0) {
            goToPage(cur - 1)
        } else {
            goToPage(0)
        }
    }
    
    function pageDown() {
        if (!tilesPager) return
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
    readonly property var calDetailSection: detailOverlay.calDetailSection
    readonly property var notifDetailSection: detailOverlay.notifDetailSection
    readonly property var updatesDetailSection: detailOverlay.updatesDetailSection
    readonly property var notesDetailSection: detailOverlay.notesDetailSection
    readonly property var pluginsDetailSection: detailOverlay.pluginsDetailSection
    readonly property var themeDetailSection: detailOverlay.themeDetailSection
    readonly property var settingsDetailSection: detailOverlay.settingsDetailSection

    Connections {
        target: dashboardContent.root
        ignoreUnknownSignals: true
        function onDashboardDetailChanged() {
            if (dashboardContent.root && dashboardContent.activeDetailView !== dashboardContent.root.dashboardDetail) {
                dashboardContent.activeDetailView = dashboardContent.root.dashboardDetail || ""
            }
        }
        function onDashboardExpandedChanged() {
            if (dashboardContent.root && dashboardContent.root.dashboardExpanded) {
                dashboardContent.startJarvisBoot()
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

    function openNightLightPopup(targetX, targetY) {
        nightPopupTargetX = targetX
        nightPopupTargetY = targetY
        showNightLightPopup = true
    }

    function toggleNightLightPopup(targetX, targetY) {
        if (showNightLightPopup) {
            showNightLightPopup = false
        } else {
            openNightLightPopup(targetX, targetY)
        }
    }

    Connections {
        target: dashboardContent.root ? dashboardContent.root : null
        ignoreUnknownSignals: true
        function onRequestNightLightPopup() {
            dashboardContent.openNightLightPopup(230, 80)
        }
    }

    function applyNightTemperature(pct) {
        lastNightChange = Date.now()
        pct = Math.max(0, Math.min(100, Math.round(pct)))
        nightLightIntensity = pct
        if (pct === 0) {
            nightMode = 0
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset"])
        } else {
            nightLightSavedIntensity = pct
            nightMode = pct >= 60 ? 2 : 1
            let temp = Math.max(2000, Math.min(5800, Math.round(6000 - (pct / 100) * 3800)))
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.01; done; exec hyprsunset -t " + temp])
        }
    }

    function setNightIntensity(pct) {
        applyNightTemperature(pct)
    }

    function cycleNightMode() {
        let nextMode = (nightMode + 1) % 3
        setNightMode(nextMode)
    }

    function setNightMode(mode) {
        lastNightChange = Date.now()
        nightMode = mode
        if (mode === 0) {
            nightLightIntensity = 0
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset"])
        } else if (mode === 1) {
            let pct = (nightLightSavedIntensity > 0 && nightLightSavedIntensity < 60) ? nightLightSavedIntensity : 40
            nightLightIntensity = pct
            let temp = Math.max(2000, Math.min(5800, Math.round(6000 - (pct / 100) * 3800)))
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.01; done; exec hyprsunset -t " + temp])
        } else if (mode === 2) {
            let pct = nightLightSavedIntensity >= 60 ? nightLightSavedIntensity : 80
            nightLightIntensity = pct
            let temp = Math.max(2000, Math.min(5800, Math.round(6000 - (pct / 100) * 3800)))
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.01; done; exec hyprsunset -t " + temp])
        }
    }

    Process {
        id: nightUpdater
        running: true
        command: ["bash", "-c", "out=$(pgrep -a hyprsunset); if [ -z \"$out\" ]; then echo 'off 0'; else t=$(echo \"$out\" | grep -oP '(?<=-t )\\d+' | head -n1); echo \"on ${t:-4500}\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - dashboardContent.lastNightChange < 1500) return
                let parts = this.text.trim().split(" ")
                if (parts[0] === "off") {
                    dashboardContent.nightMode = 0
                    dashboardContent.nightLightIntensity = 0
                } else {
                    let temp = parseInt(parts[1]) || 4500
                    let pct = Math.max(5, Math.min(100, Math.round(((6000 - temp) / 3800) * 100)))
                    dashboardContent.nightLightIntensity = pct
                    dashboardContent.nightLightSavedIntensity = pct
                    dashboardContent.nightMode = pct >= 60 ? 2 : 1
                }
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

    // Media Display Mode: Keep Media Player visible whenever an active MPRIS player exists (playing or paused)
    property bool showMediaManually: false
    readonly property bool isMediaPlaying: mprisSel.playing && curTitle !== ""
    readonly property bool showMediaPlayer: Boolean(mprisSel && mprisSel.player !== null)
    readonly property bool isMediaExpanded: Boolean(mediaWithLyricsGroup && mediaWithLyricsGroup.isExpanded)
    readonly property bool showPomodoroDock: Boolean(pomodoroDockCard && pomodoroDockCard.isPomodoroVisible)
    readonly property bool isPomodoroExpanded: Boolean(pomodoroDockCard && pomodoroDockCard.isExpanded)

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

    // ── MAIN CONTROLS (Compact Two-Zone Layout: Controls Left + Chronometer Right) ──
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

        // ── UPPER STAGE (Left Controls Wing + Right Chronometer above Bottom Dock Cards) ──
        Item {
            id: upperStage
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            height: (mediaWithLyricsGroup.isMediaVisible || pomodoroDockCard.isPomodoroVisible) ? 304 : Math.max(0, parent.height - 12)
            z: 5

            // Ambient orbital rings radiating from the right-hand clock observatory
            Canvas {
                id: orbitalBackdropCanvas
                anchors.fill: parent
                enabled: false
                z: 0
                readonly property color inkC: (root && root.ink) ? root.ink : "#ffffff"
                readonly property color sealC: (root && root.seal) ? root.seal : "#22d3ee"
                readonly property real bootProg: dashboardContent.orbitalBootProgress
                readonly property real clockCx: centerObservatory.x + centerObservatory.width / 2
                readonly property real clockCy: centerObservatory.y + centerObservatory.height / 2
                readonly property real baseRingR: Math.round(centerObservatory.width / 2) + 14
                onInkCChanged: requestPaint()
                onSealCChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onBootProgChanged: requestPaint()
                onClockCxChanged: requestPaint()
                onClockCyChanged: requestPaint()
                onBaseRingRChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    if (bootProg <= 0.005) return
                    var cx = clockCx
                    var cy = clockCy
                    if (baseRingR <= 16) return
                    var radii = [baseRingR, baseRingR + 54, baseRingR + 124, baseRingR + 196]
                    var startAng = -Math.PI / 2
                    for (var i = 0; i < radii.length; i++) {
                        if (radii[i] <= 0) continue
                        var ringT = Math.max(0.0, Math.min(1.0, (bootProg * 1.30) - i * 0.10))
                        if (ringT <= 0.01) continue
                        ctx.beginPath()
                        ctx.arc(cx, cy, radii[i], startAng, startAng + Math.PI * 2 * ringT)
                        ctx.strokeStyle = i === 0
                            ? Qt.rgba(sealC.r, sealC.g, sealC.b, 0.16 * ringT)
                            : Qt.rgba(inkC.r, inkC.g, inkC.b, (0.055 - i * 0.01) * ringT)
                        ctx.lineWidth = i === 0 ? 1.5 : 1
                        ctx.setLineDash(i % 2 === 1 ? [4, 8] : [])
                        ctx.stroke()
                    }
                    ctx.setLineDash([])
                }
            }

            // ── LEFT WING CARD: Sliders + HUD Telemetry & Controls ──
            Rectangle {
                id: leftWingCard
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(440, Math.max(350, Math.round(parent.width * 0.54)))
                height: leftWing.implicitHeight + 32
                radius: 22
                border.width: 0
                antialiasing: true
                z: 2
                readonly property color inkC: (root && root.ink) ? root.ink : "#ffffff"
                color: Qt.rgba(inkC.r, inkC.g, inkC.b, 0.05)
                opacity: dashboardContent.leftSlidersBoot
                scale: 0.94 + 0.06 * dashboardContent.leftSlidersBoot
                transform: Translate {
                    x: -20 * (1.0 - dashboardContent.leftSlidersBoot)
                }

                Column {
                    id: leftWing
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    spacing: 14

                    HomescreenTopControls {
                        id: topControlArea
                        width: parent.width
                        height: 82
                        opacity: dashboardContent.leftSlidersBoot
                        scale: 0.90 + 0.10 * dashboardContent.leftSlidersBoot
                        transform: Translate {
                            x: -28 * (1.0 - dashboardContent.leftSlidersBoot)
                            y: -6 * (1.0 - dashboardContent.leftSlidersBoot)
                        }
                        dashboardContent: dashboardContent
                        root: dashboardContent.root
                        audioData: audioData
                    }

                    HomescreenCommandDeck {
                        id: commandDeckArea
                        width: parent.width
                        height: 106
                        opacity: dashboardContent.leftTilesBoot
                        scale: 0.92 + 0.08 * dashboardContent.leftTilesBoot
                        transform: Translate {
                            x: -20 * (1.0 - dashboardContent.leftTilesBoot)
                            y: 14 * (1.0 - dashboardContent.leftTilesBoot)
                        }
                        dashboardContent: dashboardContent
                        root: dashboardContent.root
                    }

                    // Keep tilesPagerContainer alias target alive invisibly so existing helper refs remain safe
                    Item {
                        id: tilesPagerContainer
                        visible: false
                        width: 0
                        height: 0
                        property var tilesPager: null
                    }
                }
            }

            // ── RIGHT OBSERVATORY: Circular Watch Chronometer ──
            Item {
                id: centerObservatory
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, Math.min(224, parent.height - 56))
                height: width
                z: 3

                HomescreenClockWidget {
                    id: timeDateWidget
                    anchors.fill: parent
                    dashboardContent: dashboardContent
                    root: dashboardContent.root
                    mprisSel: mprisSel
                    biggerFont: biggerFont
                }
            }
        } // end upperStage

        // ── DETACHED BOTTOM-LEFT POMODORO CARD (Appears last in intro, expands downward on hover) ──
        HomescreenPomodoroCard {
            id: pomodoroDockCard
            anchors.top: upperStage.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.leftMargin: -24
            width: isExpanded ? 310 : 230
            height: isExpanded ? 124 : 72
            z: 1
            bootProgress: dashboardContent.pomodoroBoot
            transform: Translate { y: -76 * (1.0 - dashboardContent.pomodoroBoot) }
            Behavior on width { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.25 } }
            Behavior on height { SpringAnimation { spring: Motion.spatialSpring; damping: Motion.spatialDamping; epsilon: 0.25 } }
            dashboardContent: dashboardContent
            root: dashboardContent.root
        }

        // ── COMPACT BOTTOM-RIGHT MEDIA LISTTILE (Expands downward on hover to reveal controls) ──
        HomescreenMediaLyricsCard {
            id: mediaWithLyricsGroup
            anchors.top: upperStage.bottom
            anchors.topMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: -24
            readonly property real baseCollapsedWidth: Math.min(280, Math.round(parent.width * 0.42))
            readonly property real maxCollapsedWidth: Math.min(480, Math.round(parent.width * 0.70))
            width: isExpanded
                ? Math.min(520, Math.round(parent.width * 0.72))
                : Math.min(maxCollapsedWidth, Math.max(baseCollapsedWidth, preferredCollapsedWidth))
            height: isExpanded ? 124 : 72
            z: 1
            transform: Translate { y: -76 * (1.0 - dashboardContent.mediaBoot) }
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            dashboardContent: dashboardContent
            root: dashboardContent.root
            panel: dashboardContent.panel
            mprisSel: mprisSel
            mprisArt: mprisArt
            audioData: audioData
        }

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
        root: (dashboardContent && dashboardContent.root) ? dashboardContent.root : null
        panel: (dashboardContent && dashboardContent.panel) ? dashboardContent.panel : null
    }

    // ── NIGHT LIGHT INTENSITY POPUP ──
    HomescreenNightLightPopup {
        id: nightLightPopupBackdrop
        anchors.fill: parent
        dashboardContent: dashboardContent
        root: dashboardContent.root
    }
}

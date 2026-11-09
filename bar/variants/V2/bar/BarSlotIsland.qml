import QtQuick
import ".."
import Quickshell.Hyprland
import "../modules"
import "../panels"

Item {
    id: island
    required property var barSlot

    property alias centerRowItem: collapsedContent.centerRowItem
    property alias islandCollapsedItem: collapsedContent.islandCollapsedItem
    property alias islandCollapsedRightSlot: collapsedContent.islandCollapsedRightSlot
    property alias islandTimerItem: collapsedContent.islandTimerItem
    property alias islandOsdItem: islandOverlays.islandOsdItem
    property alias islandNotifPeekItem: islandOverlays.islandNotifPeekItem
    property alias islandDictationItem: islandOverlays.islandDictationItem
    property alias islandChargingItem: islandOverlays.islandChargingItem

    opacity: (island.barSlot.isDashboardActive || island.barSlot.isDashboardClosing) ? 0.0 : 1.0
    visible: opacity > 0.001
    enabled: !island.barSlot.isDashboardActive && !island.barSlot.isDashboardClosing
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    focus: island.barSlot.root.barUnlocked && !island.barSlot.isDashboardActive
    Keys.onEscapePressed: {
        if (island.barSlot.root.barUnlocked) {
            island.barSlot.root.barUnlocked = false
        }
    }

    clip: true

    property bool rawHovered: islandHover.hovered || (island.barSlot.root && island.barSlot.root.hoverForce)
    property bool isHovered: false

    Timer {
        id: unhoverDebounceTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (!island.rawHovered) {
                island.isHovered = false
            }
        }
    }

    onRawHoveredChanged: {
        if (rawHovered) {
            unhoverDebounceTimer.stop()
            island.isHovered = true
        } else {
            unhoverDebounceTimer.restart()
        }
    }

    HoverHandler {
        id: islandHover
        acceptedDevices: PointerDevice.AllDevices
    }

    property int prevNotifCount: 0
    property real blackHoleStrength: 0

    Connections {
        target: island.barSlot.root
        function onNotifCountChanged() {
            if (island.barSlot.root.notifCount > island.prevNotifCount) blackHoleAnim.restart()
            island.prevNotifCount = island.barSlot.root.notifCount
        }
    }
    SequentialAnimation {
        id: blackHoleAnim
        NumberAnimation { target: island; property: "blackHoleStrength"; from: 0; to: 1; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: island; property: "blackHoleStrength"; from: 1; to: 0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 3.0 }
    }
    transform: Scale {
        origin.x: island.barSlot.root.notifBarX > 0 ? (island.barSlot.root.notifBarX - island.x) : island.width / 2
        origin.y: island.height / 2
        xScale: 1.0 - (island.blackHoleStrength * 0.06)
        yScale: 1.0 - (island.blackHoleStrength * 0.08)
    }

    readonly property int fitPadding: Math.floor((island.barSlot.root.v2BarHeight - 24) / 2.0)
    readonly property int fitRegionGap: 12
    readonly property int fitRegionCount: 3

    // The base shell draws a black hole around the island when hovered.
    property bool isIslandHidden: (!island.isHovered || island.osdActive || island.notifPeekActive) && !island.barSlot.root.anyPopupVisible
    property real islandShrinkProgress: island.barSlot.isHoverExpanded ? 0.0 : 1.0
    Behavior on islandShrinkProgress {
        NumberAnimation { duration: island.barSlot.isHoverExpanded ? 240 : 200; easing.type: Easing.OutCubic }
    }
    property real islandElementsOpacity: island.barSlot.isHoverExpanded ? 1.0 : 0.0
    Behavior on islandElementsOpacity {
        NumberAnimation { duration: island.barSlot.isHoverExpanded ? 200 : 120; easing.type: Easing.OutCubic }
    }
    property real islandCollapsedOpacity: island.barSlot.isHoverExpanded ? 0.0 : 1.0
    Behavior on islandCollapsedOpacity {
        NumberAnimation { duration: island.barSlot.isHoverExpanded ? 100 : 180; easing.type: Easing.OutCubic }
    }

    property bool osdActive: false
    property real osdProgress: 0.0
    property string osdKind: ""
    property int osdValue: 0

    Behavior on osdProgress {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    Timer {
        id: islandOsdTimer
        interval: 1500
        onTriggered: {
            island.osdActive = false
            island.osdProgress = 0.0
        }
    }

    Connections {
        target: island.barSlot.root
        function onIslandOsdTickChanged() {
            island.osdKind = island.barSlot.root.islandOsdKind
            island.osdValue = island.barSlot.root.islandOsdValue
            island.osdActive = true
            island.osdProgress = 1.0
            islandOsdTimer.restart()
        }
    }

    property bool notifPeekActive: false
    property real notifPeekProgress: 0.0
    property string notifPeekApp: ""
    property string notifPeekSummary: ""
    property string notifPeekBody: ""
    property string notifPeekIcon: ""
    property int notifPeekId: 0

    Behavior on notifPeekProgress {
        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
    }

    readonly property bool dictationActive: island.barSlot.root.dictationActive
    property real dictationProgress: dictationActive ? 1.0 : 0.0
    Behavior on dictationProgress {
        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
    }

    readonly property bool chargingActive: island.barSlot.root.chargingPopupActive
    property real chargingProgress: chargingActive ? 1.0 : 0.0
    Behavior on chargingProgress {
        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
    }

    Timer {
        id: notifPeekTimer
        interval: 5800
        onTriggered: {
            island.notifPeekActive = false
            island.notifPeekProgress = 0.0
        }
    }

    function getNotifIcon(appName, iconHint) {
        if (iconHint && typeof iconHint === "string" && iconHint.length > 0) {
            if (!iconHint.startsWith("/") && !iconHint.startsWith("file://")) {
                if (iconHint.indexOf(" ") === -1 && iconHint.length < 30) {
                    return iconHint
                }
            }
        }
        var a = (appName || "").toLowerCase()
        if (a.indexOf("spotify") !== -1 || a.indexOf("music") !== -1) return "music_note"
        if (a.indexOf("screenshot") !== -1 || a.indexOf("capture") !== -1 || a.indexOf("action") !== -1 || a.indexOf("grim") !== -1) return "screenshot_monitor"
        if (a.indexOf("bluetooth") !== -1) return "bluetooth"
        if (a.indexOf("wifi") !== -1 || a.indexOf("network") !== -1) return "wifi"
        if (a.indexOf("battery") !== -1 || a.indexOf("power") !== -1) return "battery_charging_full"
        if (a.indexOf("volume") !== -1 || a.indexOf("audio") !== -1) return "volume_up"
        if (a.indexOf("terminal") !== -1 || a.indexOf("bash") !== -1 || a.indexOf("shell") !== -1) return "terminal"
        if (a.indexOf("browser") !== -1 || a.indexOf("zen") !== -1 || a.indexOf("firefox") !== -1 || a.indexOf("chrome") !== -1) return "language"
        if (a.indexOf("discord") !== -1 || a.indexOf("slack") !== -1 || a.indexOf("chat") !== -1 || a.indexOf("message") !== -1) return "chat"
        if (a.indexOf("mail") !== -1) return "mail"
        if (a.indexOf("timer") !== -1 || a.indexOf("clock") !== -1) return "schedule"
        if (a.indexOf("update") !== -1 || a.indexOf("arch") !== -1 || a.indexOf("pacman") !== -1) return "system_update"
        return "notifications"
    }

    Connections {
        target: island.barSlot.root
        function onNotifPeekTickChanged() {
            island.notifPeekApp = island.barSlot.root.notifPeekApp
            island.notifPeekSummary = island.barSlot.root.notifPeekSummary
            island.notifPeekBody = island.barSlot.root.notifPeekBody
            island.notifPeekIcon = island.barSlot.root.notifPeekIcon
            island.notifPeekId = island.barSlot.root.notifPeekId
            island.notifPeekActive = true
            island.notifPeekProgress = 1.0
            notifPeekTimer.restart()
        }
        function onNotifPeekDismissTickChanged() {
            notifPeekTimer.stop()
            island.notifPeekActive = false
            island.notifPeekProgress = 0.0
        }
    }

    onIsIslandHiddenChanged: {
        if (!isIslandHidden) {
            island.syncExpandedModels()
        }
    }

    property real leftVisibleWidth: 0
    property real rightVisibleWidth: 0
    readonly property real collapsedItemsWidth: centerRowItem.implicitWidth + 4
        + islandCollapsedItem.visibleWidth
        + (islandCollapsedRightSlot.implicitWidth > 0 ? (islandCollapsedRightSlot.implicitWidth + 4) : 0)
        + (islandTimerItem.active ? (islandTimerItem.targetWidth + 4) : 0)
    readonly property real defaultCollapsedCenterWidth: Math.max(60, collapsedItemsWidth)
    readonly property real overlayProgress: Math.max(island.osdProgress, island.notifPeekProgress, island.dictationProgress, island.chargingProgress)
    readonly property real overlayTargetWidth: {
        if (island.dictationProgress > 0) return islandDictationItem.width
        if (island.chargingProgress > 0) return islandChargingItem.targetWidth
        if (island.notifPeekProgress > 0) return islandNotifPeekItem.width
        return islandOsdItem.width
    }
    readonly property real collapsedIslandWidth: (island.chargingProgress > 0)
        ? (islandChargingItem.targetWidth)
        : (2 * fitPadding + ((1.0 - overlayProgress) * defaultCollapsedCenterWidth + overlayProgress * overlayTargetWidth))

    readonly property real leftCardWidth: 112
    readonly property real rightCardWidth: 156
    readonly property real middleGap: 8
    readonly property real middleWidth: (hoverQuickPanel && hoverQuickPanel.omarchyMenuOpen) ? 580 : 380
    readonly property real expandedContainerWidth: Math.min(
        island.barSlot.width - 24,
        leftCardWidth + middleGap + middleWidth + middleGap + rightCardWidth + 16
    )

    readonly property real fitNaturalWidth: island.barSlot.isHoverExpanded
        ? expandedContainerWidth
        : collapsedIslandWidth

    // edit-mode frame around the bar while unlocked (gentle pulse)
    Rectangle {
        anchors.fill: parent
        radius: island.barSlot.shellRadius
        color: "transparent"
        border.color: island.barSlot.accent
        border.width: island.barSlot.root.barUnlocked ? 1 : 0    // width 0 hides it when locked
        z: 40
        SequentialAnimation on opacity {
            running: island.barSlot.root.barUnlocked
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    // DOUBLE-click EMPTY bar area → unlock (sits below widgets and edit slots).
    // double-click so a stray single click while aiming for Control/Volume can't
    // accidentally trigger unlock. (lock again via dim backdrop click / ESC.)
    MouseArea {
        anchors.fill: parent
        z: -1
        onDoubleClicked: island.barSlot.root.barUnlocked = true
    }

    // ── Center-region metrics (clean bounds) ──
    readonly property int centerGap: 12
    readonly property int rowMargin: 5
    readonly property real centerAvail: Math.max(0, island.barSlot.width - 2 * island.barSlot.shellOuterMargin - 2 * fitPadding - 2 * fitRegionGap)
    readonly property real centerOtherBudgetWidth: 0
    readonly property real g8AvailableWidth: centerAvail
    readonly property real idealCenterX: Math.round((width - centerRowItem.width) / 2)
    readonly property real minCenterX: 8
    readonly property real maxCenterX: Math.max(8, width - centerRowItem.width - 8)
    readonly property real centerTargetX: idealCenterX

    // ── side-row auto-compact (portrait/narrow) ──
    // Presentation-only stages that hide low-priority side groups when the bar
    // would otherwise overflow. Never touches root.mod* toggles, models, order
    // or slot persistence. Budgets are summed from stage-independent budgetSlotWidth
    // values — never from the collapsed row widths — so hiding a group cannot
    // feed back into its own decision (same anti-flutter rule as the G8 stage).
    property int narrowStage: 0            // 0 normal · 1 compact · 2 portrait · 3 emergency
    property real g8FloorWidth: 80         // published by G8: its clock-only minimal width
    function groupVisibleAtStage(gid, stage) {
        if (gid === "G8") return true                                        // clock has its own stages
        if (stage <= 0) return true
        if (stage === 1) return ["G9"].indexOf(gid) < 0
        if (stage === 2) return ["G9", "G19", "G20"].indexOf(gid) < 0
        return ["G1", "G2", "G3", "G8", "G12"].indexOf(gid) >= 0
    }
    function sideNaturalWidth(row, stage) {
        var sum = 0, n = 0
        for (var k = 0; k < row.rep.count; k++) {
            var it = row.rep.itemAt(k)
            if (!it || !it.hasContent) continue
            if (!groupVisibleAtStage(it.gid, stage)) continue
            sum += it.budgetSlotWidth; n++
        }
        return sum + Math.max(0, n - 1) * row.spacing
    }
    function centerFloorWidth(stage) {
        var sum = 0, n = 0
        for (var k = 0; k < centerRowItem.rep.count; k++) {
            var it = centerRowItem.rep.itemAt(k)
            if (!it || !it.hasContent) continue
            if (!groupVisibleAtStage(it.gid, stage)) continue
            sum += it.gid === "G8" ? g8FloorWidth : it.budgetSlotWidth
            n++
        }
        return sum + Math.max(0, n - 1) * centerRowItem.spacing
    }
    function narrowCandidateWidth(stage) {
        return (typeof row2SecondaryItem !== "undefined" && row2SecondaryItem) ? sideNaturalWidth(row2SecondaryItem, stage) : 0
    }
    function updateNarrowStage() {
        if (typeof maxMiddleWidth === "undefined") return
        var s = narrowStage
        var W = maxMiddleWidth
        if (W < 1) return                              // no layout yet
        if (s === 0 && narrowCandidateWidth(0) + 16 > W) s = 1
        if (s === 1 && narrowCandidateWidth(1) + 16 > W) s = 2
        if (s === 2 && narrowCandidateWidth(2) + 16 > W) s = 3
        if (s === 3 && narrowCandidateWidth(2) + 32 <= W) s = 2
        if (s === 2 && narrowCandidateWidth(1) + 32 <= W) s = 1
        if (s === 1 && narrowCandidateWidth(0) + 32 <= W) s = 0
        if (s !== narrowStage) narrowStage = s
    }
    function scheduleNarrowUpdate() { narrowTimer.restart() }
    Timer { id: narrowTimer; interval: 80; repeat: false; onTriggered: island.updateNarrowStage() }
    onWidthChanged: scheduleNarrowUpdate()
    onG8FloorWidthChanged: scheduleNarrowUpdate()
    Connections {
        target: island.barSlot.root
        function onBarShellStyleChanged() {
            island.scheduleNarrowUpdate()
        }
        function onBarUnlockedChanged() { syncModelsTimer.restart() }
        function onV2WidgetSpacingChanged() { syncModelsTimer.restart() }
    }

    ListModel { id: row1PriorityModel }
    ListModel { id: row2SecondaryModel }
    property real estimatedMiddleWidth: 240

    function estimateWidgetWidth(gid) {
        if (!gid || gid === "") return 0
        if (gid === "G1") return 30
        if (gid === "G2") {
            var wsCount = (Hyprland && Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values.length : 5
            return Math.max(60, wsCount * 18 + 24)
        }
        if (gid === "G3") return 30
        var supportsFull = ["G12", "G21"].indexOf(gid) >= 0
        var isFull = supportsFull && island.barSlot.root && !island.barSlot.root.iconOnly(gid)
        if (isFull) {
            if (gid === "G21") return 64
            return 60
        }
        return 30
    }

    function isGidActive(gid) {
        if (!gid || gid === "") return false
        var r = island.barSlot.root
        if (!r) return true
        if (gid === "G1") return true
        if (gid === "G2") return true
        if (gid === "G3") return r.modStatus !== false
        if (gid === "G8") return true
        if (gid === "G9") return r.modMpris !== false
        if (gid === "G12") return r.modBattery !== false
        if (gid === "G19") return r.modGithubHeatmap !== false
        if (gid === "G20") return r.modNotes !== false
        if (gid === "G21") return r.modScreentime !== false
        if (gid === "G22") return r.modNotif !== false
        return false
    }

    function syncExpandedModels() {
        row1PriorityModel.clear()
        row2SecondaryModel.clear()

        var r1Gids = ["G1", "G2", "G3", "G22"]
        var r2Gids = ["G19", "G20", "G12", "G21"]

        var w1 = 0, n1 = 0
        for (var i = 0; i < r1Gids.length; i++) {
            var g1 = r1Gids[i]
            if (isGidActive(g1)) {
                row1PriorityModel.append({ gid: g1, extra: false })
                w1 += estimateWidgetWidth(g1)
                n1++
            }
        }
        var spacing = (island.barSlot.root && island.barSlot.root.v2WidgetSpacing) ? island.barSlot.root.v2WidgetSpacing : 5
        w1 += Math.max(0, n1 - 1) * spacing

        var w2 = 0, n2 = 0
        for (var j = 0; j < r2Gids.length; j++) {
            var g2 = r2Gids[j]
            if (isGidActive(g2)) {
                row2SecondaryModel.append({ gid: g2, extra: false })
                w2 += estimateWidgetWidth(g2)
                n2++
            }
        }
        w2 += Math.max(0, n2 - 1) * spacing

        island.estimatedMiddleWidth = Math.max(w1, w2, 200)
    }

    Timer {
        id: syncModelsTimer
        interval: 50
        repeat: false
        onTriggered: island.syncExpandedModels()
    }

    BarSlotCollapsedContent {
        id: collapsedContent
        barSlot: island.barSlot
        island: island
    }

    BarSlotIslandOverlays {
        id: islandOverlays
        barSlot: island.barSlot
        island: island
        notifPeekTimer: notifPeekTimer
    }

    ClockWidget {
        id: barClockShared
        root: island.barSlot.root
        visible: false
    }

    WeatherWidget {
        id: barWeatherShared
        root: island.barSlot.root
        visible: false
    }

    MprisArtwork {
        id: mediaCardArt
        player: (island.barSlot.mprisPanel && island.barSlot.mprisPanel.player) ? island.barSlot.mprisPanel.player : null
        root: island.barSlot.root
    }

    AudioData {
        id: barAudioShared
    }

    // ── Extracted Modular Hover Quick Settings Panel ──
    HoverQuickSettingsPanel {
        id: hoverQuickPanel
        barSlot: island.barSlot
        island: island
        anchors.horizontalCenter: parent.horizontalCenter
        y: (island.barSlot.root.barPosition === "bottom") ? (island.height - height) : 0
        opacity: island.islandElementsOpacity
        scale: island.barSlot.isHoverExpanded ? 1.0 : 0.96
        transform: Translate {
            y: island.barSlot.isHoverExpanded ? 0 : (island.barSlot.root.barPosition === "bottom" ? 12 : -12)
            Behavior on y { NumberAnimation { duration: island.barSlot.isHoverExpanded ? 240 : 160; easing.type: Easing.OutCubic } }
        }
        visible: opacity > 0.001
        enabled: island.barSlot.isHoverExpanded
        Behavior on scale { NumberAnimation { duration: island.barSlot.isHoverExpanded ? 240 : 160; easing.type: Easing.OutCubic } }
    }

    // ── slot-aware panel X positions: publish per-screen anchors ──
    // find a group's slot and map its (frac·width) to window/screen X.
    function groupX(gid, frac) {
        if (gid === "G8" && island.islandShrinkProgress < 0.5) {
            return island.x + 8 + island.leftCardWidth * frac
        }
        if (gid === "G9" && island.islandShrinkProgress < 0.5) {
            return island.x + (island.width - island.rightCardWidth - 8) + island.rightCardWidth * frac
        }
        var row = centerRowItem
        if (row && row.rep) {
            for (var k = 0; k < row.rep.count; k++) {
                var it = row.rep.itemAt(k)
                if (it && it.gid === gid) {
                    return island.x + row.x + it.x + it.width * frac
                }
            }
        }
        return 0
    }

    // Some composite groups contain several independent panel triggers.
    // Read their exact local center instead of pointing every panel at the
    // center of the entire group.
    function groupContentX(gid, propertyName, fallbackFrac) {
        if (gid === "G8" && island.islandShrinkProgress < 0.5) {
            return island.x + 8 + island.leftCardWidth * 0.5
        }
        if (gid === "G9" && island.islandShrinkProgress < 0.5) {
            return island.x + (island.width - island.rightCardWidth - 8) + island.rightCardWidth * 0.5
        }
        var row = centerRowItem
        if (row && row.rep) {
            for (var k = 0; k < row.rep.count; k++) {
                var it = row.rep.itemAt(k)
                if (it && it.gid === gid && it.contentItem
                        && it.contentItem[propertyName] !== undefined) {
                    return island.x + row.x + it.x + it.pad
                        + Number(it.contentItem[propertyName])
                }
            }
        }
        return groupX(gid, fallbackFrac)
    }

    readonly property string panelScreenName: island.barSlot.screen ? island.barSlot.screen.name : ""
    readonly property var panelAnchors: {
        void(island.width)
        void(island.x)
        void(centerRowItem.x); void(centerRowItem.width)
        return {
            tray:         island.groupX("G3",  0.0),
            trayCaret:    island.groupContentX("G3", "trayCaretX", 0.5),
            notif:        island.groupX("G22",  0.0),
            notifCaret:   island.groupContentX("G22", "notifCaretX", 0.5),
            quickActions: island.groupX("G10", 0.5),
            volume:       island.groupX("G6",  0.5),
            network:      island.groupX("G11", 0.5),
            battery:      island.groupX("G12", 0.5),
            memory:       island.groupX("G4",  0.5),
            cpu:          island.groupX("G5",  0.5),
            screentime:   island.groupX("G21", 0.5),
            gpu:          island.groupX("G17", 0.5),
            thermal:      island.groupX("G16", 0.5),
            storage:      island.groupX("G18", 0.5),
            githubHeatmap:island.groupX("G19", 0.5),
            ai:           island.groupX("G7",  0.5),
            workspace:    island.groupX("G2",  0.5),
            arch:         island.groupX("G3",  0.5),
            archCaret:    island.groupContentX("G3", "archCaretX", 0.5),
            bluetooth:    island.groupX("G15", 0.5),
            brightness:   island.groupX("G13", 0.5),
            power:        island.groupX("G14", 0.5),
            mpris:        island.groupX("G9",  0.5),
            weather:      island.groupContentX("G8", "weatherCaretX", 0.5),
            calendar:     island.groupContentX("G8", "calendarCaretX", 0.5),
            launcher:     island.groupX("G1",  0.5)
        }
    }
    onPanelAnchorsChanged: island.barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
    Component.onCompleted: {
        island.syncExpandedModels()
        island.barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
    }
}

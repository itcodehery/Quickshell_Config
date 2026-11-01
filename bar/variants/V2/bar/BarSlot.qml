// ─────────────────────────────────────────────────────────────────────────────
// V2 BarSlot — V1's complete widget/panel behavior on one selectable bar shell.
// The surface spans the full output width at a compact 33px visible height;
// a single screen-facing border and shadow replace the rounded section islands.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import ".."
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../modules"
import "../panels"
import "../motion"
import "../utils/IconMap.js" as IconMap

PanelWindow {
    id: barSlot
    required property var root
    required property var mprisPanel
    readonly property string screenName: barSlot.screen ? barSlot.screen.name : ""
    readonly property int shellOuterMargin: 5

    readonly property bool isDashboardTargetScreen: !barSlot.root.activePopupScreenName || barSlot.root.isActivePopupScreenName(barSlot.screenName)
    readonly property bool isDashboardActive: barSlot.root.dashboardExpanded && isDashboardTargetScreen
    property bool isDashboardClosing: false
    property bool dashboardEverActivated: false

    readonly property bool isPickerDetail: barSlot.root.dashboardDetail === "theme" || barSlot.root.dashboardDetail === "wallpaper"
    readonly property bool isSubPageOpen: barSlot.root.dashboardDetail !== ""
    readonly property real dashboardExpandedWidth: Math.min((isPickerDetail ? 960 : 840) + (isSubPageOpen ? 52 : 0), barSlot.width - 32)
    readonly property real dashboardExpandedHeight: Math.min(barSlot.height - 40, isPickerDetail ? 430 : 292)

    readonly property real dashboardTopRadius: 24
    readonly property real dashboardBottomRadius: 24

    readonly property var islandNotifPeekItem: island ? island.islandNotifPeekItem : null
    readonly property int notifTargetHeight: (island && island.notifPeekActive && typeof islandNotifPeekItem !== "undefined" && islandNotifPeekItem)
        ? (island.notifPeekBody !== "" ? Math.min(94, Math.max(70, islandNotifPeekItem.desiredCardHeight)) : 46)
        : barSlot.root.v2BarHeight
    readonly property int chargingTargetHeight: barSlot.root.v2BarHeight
    readonly property int barExpandedHeight: 156
    readonly property bool isHoverExpanded: !isDashboardActive && (typeof island !== "undefined" && island) && !island.isIslandHidden
    readonly property real hoverMaskHeight: Math.max(continuousBarSurface.height, barExpandedHeight)
    readonly property real hoverMaskWidth: (typeof island !== "undefined" && island) ? Math.max(continuousBarSurface.width, island.expandedContainerWidth) : continuousBarSurface.width
    readonly property int shellVisibleHeight: isDashboardActive
        ? Math.round(dashboardExpandedHeight)
        : (isHoverExpanded
            ? barExpandedHeight
            : (island && island.chargingProgress > 0
                ? Math.round(barSlot.root.v2BarHeight + (chargingTargetHeight - barSlot.root.v2BarHeight) * island.chargingProgress)
                : (island && island.notifPeekActive
                    ? Math.round(barSlot.root.v2BarHeight + (notifTargetHeight - barSlot.root.v2BarHeight) * island.notifPeekProgress)
                    : barSlot.root.v2BarHeight)))
    readonly property int shellRadius: isDashboardActive
        ? 24
        : ((island && island.notifPeekActive && island.notifPeekBody !== "")
            ? 20
            : (isHoverExpanded ? 24 : Math.round(shellVisibleHeight / 2)))
    readonly property real shellTargetWidth: isDashboardActive
        ? dashboardExpandedWidth
        : Math.max(80,
            Math.min(barSlot.width - 2 * shellOuterMargin,
                isHoverExpanded ? island.expandedContainerWidth : island.collapsedIslandWidth))

    visible: !barSlot.root.barHidden
    color: "transparent"
    // ALWAYS screen-tall → window never resizes → NO compositor resize animation.
    // Reserve the visible bar strip; the mask limits the INPUT region to the bar
    // strip when locked (clicks below pass through), full screen when unlocked (drag).
    // anchored to left+right always; top OR bottom by barPosition (exclusiveZone
    // reserves space on whichever edge is anchored → no extra logic needed)
    anchors {
        left: true; right: true
        top:    barSlot.root.barPosition === "top"
        bottom: barSlot.root.barPosition === "bottom"
    }
    implicitHeight: barSlot.screen ? barSlot.screen.height : 1440
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: effectivelyHidden ? 1 : barSlot.root.v2BarHeight + 8

    // Auto-hide was removed; the bar is always shown.
    readonly property bool effectivelyHidden: false

    mask: Region {
        x: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? 0
           : (barSlot.isHoverExpanded
               ? Math.round((barSlot.width - barSlot.hoverMaskWidth) / 2)
               : Math.round(continuousBarSurface.x))
        y: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? 0
           : barSlot.effectivelyHidden
               ? (barSlot.root.barPosition === "bottom" ? barSlot.height - 1 : 0)
               : (barSlot.root.barPosition === "bottom"
                   ? (barSlot.isHoverExpanded
                       ? barSlot.height - Math.round(barSlot.hoverMaskHeight) - 4
                       : barSlot.height - Math.round(continuousBarSurface.height) - 4)
                   : 4)
        width: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? barSlot.width
           : (barSlot.isHoverExpanded ? Math.round(barSlot.hoverMaskWidth) : Math.round(continuousBarSurface.width))
        height: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? barSlot.height
           : barSlot.effectivelyHidden ? 1
           : (barSlot.isHoverExpanded ? Math.round(barSlot.hoverMaskHeight) : Math.round(continuousBarSurface.height))
    }
    // grab keyboard while unlocked or dashboard is expanded so ESC / typing can work
    WlrLayershell.keyboardFocus: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HoverHandler {
        id: slotHover
        onHoveredChanged: if (hovered && !barSlot.root.anyPopupVisible) barSlot.root.activatePopupScreen(barSlot.screen)
    }

    // keep Hyprland awake while the idle-inhibitor toggle is on (carried over
    // from the legacy single-bar implementation)
    IdleInhibitor { window: barSlot; enabled: barSlot.root.idleInhibited }

    // if unlock ends mid-drag (ESC / ipc lock / click backdrop), kill the drag so the
    // ghost doesn't stay frozen + the source widget doesn't stay dimmed
    Connections {
        target: barSlot.root
        function onBarUnlockedChanged() {
            if (!barSlot.root.barUnlocked && barSlot.dragging) barSlot.cancelDrag()
        }
    }

    readonly property color accent: barSlot.root.seal

    function formatTitleCase(str) {
        if (!str || typeof str !== "string") return ""
        return str.replace(/\w\S*/g, function(txt) {
            return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
        })
    }

    function formatSentenceCase(str) {
        if (!str || typeof str !== "string") return ""
        var s = str.trim()
        if (s.length === 0) return ""
        if (s.length > 1 && s === s.toUpperCase()) {
            s = s.toLowerCase()
        }
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function formatNotificationBody(str) {
        if (!str || typeof str !== "string") return ""
        var s = str.replace(/<a\b[^>]*>(.*?)<\/a>/gi, "$1")
                   .replace(/<br\s*\/?>/gi, " ")
                   .replace(/<[^>]*>/g, "")
                   .trim()
        if (s.length === 0) return ""
        if (s.length > 1 && s === s.toUpperCase()) {
            s = s.toLowerCase()
        }
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    // One uninterrupted surface across the output. On the default top edge the
    // border is literally the bottom border requested for V2; the optional V1
    // bottom placement mirrors it so the shadow still opens toward the desktop.
    Rectangle {
        id: continuousBarSurface
        x: Math.round((barSlot.width - width) / 2)
        readonly property int islandMargin: 4
        property string lastBarPos: barSlot.root.barPosition
        property bool barPosTransitioning: false
        Timer {
            id: barPosTimer
            interval: 420
            onTriggered: continuousBarSurface.barPosTransitioning = false
        }
        onYChanged: {
            if (barSlot.root.barPosition !== lastBarPos) {
                lastBarPos = barSlot.root.barPosition
                barPosTransitioning = true
                barPosTimer.restart()
            }
        }
        y: barSlot.root.barPosition === "bottom"
            ? (barSlot.effectivelyHidden ? barSlot.height : barSlot.height - height - islandMargin)
            : (barSlot.effectivelyHidden ? -height : islandMargin)
        Behavior on y {
            enabled: barSlot.effectivelyHidden || continuousBarSurface.barPosTransitioning
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }
        }
        width: barSlot.shellTargetWidth
        Behavior on width {
            NumberAnimation {
                duration: (barSlot.isDashboardActive || barSlot.isHoverExpanded) ? 240 : 200
                easing.type: (barSlot.isDashboardActive || barSlot.isHoverExpanded) ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.08
            }
        }
        height: barSlot.shellVisibleHeight
        Behavior on height {
            NumberAnimation {
                duration: (barSlot.isDashboardActive || barSlot.isHoverExpanded) ? 240 : 200
                easing.type: (barSlot.isDashboardActive || barSlot.isHoverExpanded) ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.08
            }
        }
        radius: barSlot.shellRadius
        Behavior on radius { NumberAnimation { duration: barSlot.isDashboardActive ? 220 : 160; easing.type: Easing.OutCubic } }
        color: "transparent"
        z: (barSlot.isDashboardActive || barSlot.isDashboardClosing) ? 20 : 0

        readonly property real targetTopCornerRadius: barSlot.isDashboardActive ? barSlot.dashboardTopRadius : radius
        readonly property real targetBottomCornerRadius: barSlot.isDashboardActive ? barSlot.dashboardBottomRadius : radius

        property real topCornerRadius: targetTopCornerRadius
        Behavior on topCornerRadius { NumberAnimation { duration: barSlot.isDashboardActive ? 220 : 160; easing.type: Easing.OutCubic } }

        property real bottomCornerRadius: targetBottomCornerRadius
        Behavior on bottomCornerRadius { NumberAnimation { duration: barSlot.isDashboardActive ? 220 : 160; easing.type: Easing.OutCubic } }

        Shape {
            id: islandSurfaceBorder
            anchors.fill: parent
            visible: (!barSlot.isDashboardActive) && barSlot.root.barBorderEnabled
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            z: 15

            readonly property real topR: continuousBarSurface.topCornerRadius
            readonly property real botR: continuousBarSurface.bottomCornerRadius
            readonly property real w: width
            readonly property real h: height

            ShapePath {
                strokeColor: barSlot.root.islandBorder
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                startX: islandSurfaceBorder.topR
                startY: 0.5
                PathLine { x: islandSurfaceBorder.w - islandSurfaceBorder.topR; y: 0.5 }
                PathQuad {
                    x: islandSurfaceBorder.w - 0.5; y: islandSurfaceBorder.topR
                    controlX: islandSurfaceBorder.w - 0.5; controlY: 0.5
                }
                PathLine {
                    x: islandSurfaceBorder.w - 0.5
                    y: islandSurfaceBorder.h - islandSurfaceBorder.botR
                }
                PathQuad {
                    x: islandSurfaceBorder.w - islandSurfaceBorder.botR
                    y: islandSurfaceBorder.h - 0.5
                    controlX: islandSurfaceBorder.w - 0.5; controlY: islandSurfaceBorder.h - 0.5
                }
                PathLine { x: islandSurfaceBorder.botR; y: islandSurfaceBorder.h - 0.5 }
                PathQuad {
                    x: 0.5; y: islandSurfaceBorder.h - islandSurfaceBorder.botR
                    controlX: 0.5; controlY: islandSurfaceBorder.h - 0.5
                }
                PathLine { x: 0.5; y: islandSurfaceBorder.topR }
                PathQuad {
                    x: islandSurfaceBorder.topR; y: 0.5
                    controlX: 0.5; controlY: 0.5
                }
            }
        }

        // The panel indentation is part of the filled silhouette, not merely a
        // border drawn over a rectangle. This keeps its interior genuinely cut
        // out and mirrors the same negative-space geometry at the bottom edge.
        Shape {
            id: surfaceFill
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: barSlot.isSubPageOpen ? Qt.darker(barSlot.root.barBg, 1.35) : barSlot.root.barBg
                startX: continuousBarSurface.topCornerRadius
                startY: 0
                PathLine { x: surfaceFill.width - continuousBarSurface.topCornerRadius; y: 0 }
                PathQuad {
                    x: surfaceFill.width; y: continuousBarSurface.topCornerRadius
                    controlX: surfaceFill.width; controlY: 0
                }
                PathLine {
                    x: surfaceFill.width
                    y: surfaceFill.height - continuousBarSurface.bottomCornerRadius
                }
                PathQuad {
                    x: surfaceFill.width - continuousBarSurface.bottomCornerRadius
                    y: surfaceFill.height
                    controlX: surfaceFill.width; controlY: surfaceFill.height
                }
                PathLine { x: continuousBarSurface.bottomCornerRadius; y: surfaceFill.height }
                PathQuad {
                    x: 0; y: surfaceFill.height - continuousBarSurface.bottomCornerRadius
                    controlX: 0; controlY: surfaceFill.height
                }
                PathLine { x: 0; y: continuousBarSurface.topCornerRadius }
                PathQuad {
                    x: continuousBarSurface.topCornerRadius; y: 0
                    controlX: 0; controlY: 0
                }
            }
        }
    }

    // ── dim backdrop while unlocked (edit mode) or dashboard expanded; click empty → dismiss ──
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: barSlot.root.barUnlocked ? 0.4 : (barSlot.isDashboardActive ? 0.65 : 0.0)
        visible: opacity > 0.001
        z: 10
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            enabled: barSlot.root.barUnlocked || barSlot.isDashboardActive
            onClicked: {
                if (barSlot.root.barUnlocked) {
                    barSlot.root.barUnlocked = false
                } else if (barSlot.isDashboardActive) {
                    barSlot.root.dashboardExpanded = false
                }
            }
        }
    }

    // ── unlock drag&drop: ghost + state ──
    property var row1PriorityItem: null
    property var row2SecondaryItem: null
    readonly property var centerRowItem: island ? island.centerRowItem : null

    property bool dragging: false          // ghost visible (incl. snap-back phase)
    property bool dragActive: false        // mouse currently down (follow cursor)
    property Item dragItem: null           // slot content mirrored by the ghost
    property var  srcModel: null           // source region model + index
    property int  srcIndex: -1
    property var  dropModel: null          // current drop-target model + index
    property int  dropIndex: -1
    property real ghostW: 0
    property real ghostH: 0
    property real ghostHomeX: 0
    property real ghostHomeY: 0
    property real ghostX: 0
    property real ghostY: 0
    function beginDrag(item, hx, hy, w, h, sm, si) {
        dragItem = item; ghostW = w; ghostH = h; ghostHomeX = hx; ghostHomeY = hy
        ghostX = hx; ghostY = hy; srcModel = sm; srcIndex = si
        dropModel = null; dropIndex = -1; dragActive = true; dragging = true
    }
    // which slot (model+index) is under a window-point?
    function slotAt(wx, wy) {
        var rows = [row1PriorityItem, row2SecondaryItem, centerRowItem]
        for (var r = 0; r < rows.length; r++) {
            if (!rows[r]) continue
            var rep = rows[r].rep
            for (var k = 0; k < rep.count; k++) {
                var it = rep.itemAt(k)
                if (!it || !it.visible || !it.autoShown) continue
                var p = it.mapToItem(null, 0, 0)
                if (wx >= p.x && wx <= p.x + it.width && wy >= p.y && wy <= p.y + it.height)
                    return { model: rows[r].rmodel, index: k }
            }
        }
        return null
    }
    function moveDrag(wx, wy) {
        ghostX = wx - ghostW / 2; ghostY = wy - ghostH / 2
        var hit = slotAt(wx, wy)
        dropModel = hit ? hit.model : null
        dropIndex = hit ? hit.index : -1
    }
    function endDrag() {
        dragActive = false
        var swapped = false
        if (dropModel && dropIndex >= 0 && !(dropModel === srcModel && dropIndex === srcIndex)) {
            var sg = srcModel.get(srcIndex).gid, tg = dropModel.get(dropIndex).gid
            srcModel.setProperty(srcIndex, "gid", tg)
            dropModel.setProperty(dropIndex, "gid", sg)
            swapped = true
        }
        dropModel = null; dropIndex = -1
        if (swapped) { if (_orderLoaded) saveOrder(); dragging = false }   // content swapped in place + persist
        else { ghostX = ghostHomeX; ghostY = ghostHomeY; snapTimer.restart() }   // snap back
    }
    Timer { id: snapTimer; interval: 240; onTriggered: barSlot.dragging = false }
    // abort a drag with no swap (ESC / ipc lock / backdrop-click while dragging, or a
    // compositor grab-cancel) → clear the ghost immediately so it can't freeze on screen
    function cancelDrag() {
        snapTimer.stop()
        dragActive = false; dragging = false; dragItem = null
        dropModel = null; dropIndex = -1
    }

    // ── region models (physical L→R order) ──
    property alias leftModel: leftModel
    property alias centerModel: centerModel
    property alias rightModel: rightModel

    ListModel {
        id: leftModel
        ListElement { gid: "G1"; extra: false }
        ListElement { gid: "G2"; extra: false }
        ListElement { gid: "G3"; extra: false }
        ListElement { gid: "G22"; extra: false }
    }
    ListModel {
        id: centerModel
        ListElement { gid: "G8"; extra: false }
    }
    ListModel {
        id: rightModel
        ListElement { gid: "G9"; extra: false }
        ListElement { gid: "G19"; extra: false }
        ListElement { gid: "G20"; extra: false }
        ListElement { gid: "G12"; extra: false }
        ListElement { gid: "G21"; extra: false }
    }

    // ── order persistence (survives restart) ──
    readonly property string orderCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barorder_v2"
    readonly property int leftBaseSlotCount: 4
    readonly property int centerBaseSlotCount: 1
    readonly property int rightBaseSlotCount: 5
    // Both side regions can reach the same total capacity. The right side has
    // fewer built-in groups, so it receives three more optional slots.
    readonly property int sideSlotCapacity: 12
    readonly property int leftExtraSlotLimit: sideSlotCapacity - leftBaseSlotCount
    readonly property int rightExtraSlotLimit: sideSlotCapacity - rightBaseSlotCount
    readonly property int centerExtraSlotLimit: 3
    property bool _orderLoaded: false
    function modelContains(m, gid) {
        for (var i = 0; i < m.count; i++) if (m.get(i).gid === gid) return true
        return false
    }
    function extraSlotCount(m, baseCount) { return Math.max(0, m.count - baseCount) }
    function serializeModel(m) {
        var slots = []
        for (var i = 0; i < m.count; i++) {
            var row = m.get(i)
            slots.push((row.extra ? "E:" : "B:") + (row.gid === "" ? "_" : row.gid))
        }
        return slots.join(",")
    }
    function serializeOrder() {
        return serializeModel(leftModel) + "|" + serializeModel(centerModel) + "|" + serializeModel(rightModel)
    }
    function parseRegion(raw, baseCount, maxExtraCount, legacy) {
        var tokens = raw === "" ? [] : raw.split(",")
        if (legacy && tokens.length !== baseCount) return null
        if (!legacy && (tokens.length < baseCount
                || tokens.length > baseCount + maxExtraCount)) return null

        var entries = []
        for (var i = 0; i < tokens.length; i++) {
            if (legacy) {
                entries.push({ gid: tokens[i], extra: false })
                continue
            }

            var token = tokens[i]
            if (token.length < 3 || token.charAt(1) !== ":") return null
            var kind = token.charAt(0)
            if ((i < baseCount && kind !== "B") || (i >= baseCount && kind !== "E")) return null
            var gid = token.substring(2)
            entries.push({ gid: gid === "_" ? "" : gid, extra: kind === "E" })
        }
        return entries
    }
    function applyEntries(m, entries) {
        m.clear()
        for (var i = 0; i < entries.length; i++) m.append(entries[i])
    }
    function applyOrder(str) {
        var parts = str.split("|")
        if (parts.length !== 3) return false

        // Accept the initial fixed-width V2 cache once, then write the slot-aware
        // B:/E: format on the next edit. Every new cache must keep the immutable
        // base slots first and stay within its region-specific extra-slot limit.
        var legacy = parts[0].indexOf(":") < 0
        var l = parseRegion(parts[0], leftBaseSlotCount, leftExtraSlotLimit, legacy)
        var c = parseRegion(parts[1], centerBaseSlotCount, centerExtraSlotLimit, legacy)
        var r = parseRegion(parts[2], rightBaseSlotCount, rightExtraSlotLimit, legacy)

        // Migrate older V2 slot schemas by ensuring all base slots are preserved.
        if (!l || !c || !r) {
            var previousLeft10 = parseRegion(parts[0], 10, leftExtraSlotLimit + 1, legacy)
            var previousCenter = parseRegion(parts[1], centerBaseSlotCount,
                centerExtraSlotLimit, legacy)
            var previousRight = parseRegion(parts[2], rightBaseSlotCount, rightExtraSlotLimit, legacy)
            if (previousLeft10 && previousCenter && previousRight) {
                var oldBase10 = previousLeft10.slice(0, 10)
                var oldExtras10 = previousLeft10.slice(10)
                var hasG22 = false
                for (var pi = 0; pi < previousLeft10.length; pi++) {
                    if (previousLeft10[pi].gid === "G22") { hasG22 = true; break; }
                }
                if (!hasG22) {
                    l = oldBase10.slice(0, 3).concat([{ gid: "G22", extra: false }], oldBase10.slice(3), oldExtras10)
                } else {
                    l = oldBase10.concat([{ gid: "", extra: false }], oldExtras10)
                }
                c = previousCenter
                r = previousRight
            } else {
                var previousLeft = parseRegion(parts[0], 7, 3, legacy)
                var previousRight7 = parseRegion(parts[2], rightBaseSlotCount, 3, legacy)
                if (!previousLeft || !previousCenter || (!previousRight && !previousRight7)) return false

                var oldBase = previousLeft.slice(0, 7)
                var oldExtras = previousLeft.slice(7)
                l = oldBase.slice(0, 5).concat([
                    { gid: "G16", extra: false },
                    { gid: "G17", extra: false },
                    { gid: "G18", extra: false }
                ], oldBase.slice(5), oldExtras)
                c = previousCenter
                r = previousRight || previousRight7
            }
        }

        // Empty slots are legal, but each registered widget must occur at most once.
        var all = l.concat(c, r), seen = {}
        for (var i = 0; i < all.length; i++) {
            var gid = all[i].gid
            if (gid === "") continue
            if (!registry[gid]) { all[i].gid = ""; continue }
            if (seen[gid]) return false
            seen[gid] = true
        }
        // Auto-inject any missing registered widgets
        for (var regGid in registry) {
            if (!seen[regGid]) {
                r.push({ gid: regGid, extra: true })
                seen[regGid] = true
            }
        }

        applyEntries(leftModel, l)
        applyEntries(centerModel, c)
        applyEntries(rightModel, r)
        return true
    }
    function saveOrder() {
        var serialized = serializeOrder()
        orderSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + orderCachePath + "')\" && printf '%s' '" + serialized + "' > '" + orderCachePath + "'"]
        orderSaveProc.running = false; orderSaveProc.running = true
        if (!barSlot.root._barLayoutSyncing) barSlot.root.syncBarOrder(barSlot.screenName, serialized)
    }
    Process { id: orderSaveProc }
    Process {
        id: orderLoadProc
        command: ["cat", barSlot.orderCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t.length > 0) barSlot.applyOrder(t)
                barSlot._orderLoaded = true
            }
        }
    }
    function addExtraSlot(m, baseCount, maxExtraCount) {
        if (!m || extraSlotCount(m, baseCount) >= maxExtraCount) return
        m.append({ gid: "", extra: true })
        if (_orderLoaded) saveOrder()
    }
    function removeExtraSlot(m, index, baseCount) {
        if (!m || index < baseCount || index >= m.count) return
        var row = m.get(index)
        if (!row.extra || row.gid !== "") return
        m.remove(index, 1)
        if (_orderLoaded) saveOrder()
    }
    function resetModel(m, gids, baseCount) {
        m.clear()
        for (var i = 0; i < gids.length; i++)
            m.append({ gid: gids[i], extra: i >= baseCount })
    }
    // Restore the confirmed V2 default snapshot, including its intentional
    // empty base cells and the six optional cells on the right.
    function resetOrder() {
        var dL = ["G1","G2","G3","G22"]
        var dR = ["G9","G19","G20","G12","G21"]
        resetModel(leftModel, dL, leftBaseSlotCount)
        resetModel(centerModel, ["G8"], centerBaseSlotCount)
        resetModel(rightModel, dR, rightBaseSlotCount)
        if (_orderLoaded) saveOrder()
    }

    property var layoutController: ({
        ready: function () {
            return barSlot._orderLoaded && barSlot.backingWindowVisible
        },
        defaultLayout: function () { barSlot.resetOrder() },
        applyOrder: function (serialized) { barSlot.applyOrder(serialized) }
    })

    Component.onCompleted: {
        if (!barSlot.root.activePopupScreenName) barSlot.root.activatePopupScreen(barSlot.screen)
        barSlot.root.registerBarLayoutController(barSlot.screenName, barSlot.layoutController)
    }

    Component.onDestruction: {
        if (barSlot.root
                && barSlot.root.isActivePopupScreenName(barSlot.screenName)
                && barSlot.root.anyPopupVisible) {
            barSlot.root.closePopups()
        }
        barSlot.root.unregisterBarLayoutController(barSlot.screenName, barSlot.layoutController)
    }

    ShaderEffectSource {
        id: ghost
        sourceItem: barSlot.dragItem
        width: barSlot.ghostW; height: barSlot.ghostH
        x: barSlot.ghostX; y: barSlot.ghostY
        visible: barSlot.dragging
        z: 100
        // dim while dragging over empty space (no valid drop → snap-back)
        opacity: barSlot.dragActive ? (barSlot.dropModel ? 0.95 : 0.45) : 0.92
        scale: barSlot.dragActive ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on x { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on y { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on scale { NumberAnimation { duration: 120 } }
    }

    // ─────────────────────────── group registry ───────────────────────────
    BarSlotRegistry {
        id: slotRegistry
        barSlot: barSlot
        island: island
    }
    readonly property var registry: slotRegistry.map

    BarSlotIsland {
        id: island
        barSlot: barSlot
        // The backing layer-window remains full-screen, but the visible/content
        // island follows the selected shell surface. This preserves stable
        // layer-shell resources while the island resizes with its visible rows.
        x: continuousBarSurface.x
        width: continuousBarSurface.width
        height: continuousBarSurface.height
        y: continuousBarSurface.y
        z: 22
    }

    // ── In-place expanded Island Dock dashboard ──
    BarSlotDashboard {
        id: expandedDashboardContainer
        barSlot: barSlot
        x: continuousBarSurface.x
        y: continuousBarSurface.y
        width: continuousBarSurface.width
        height: continuousBarSurface.height
        z: 25
    }
}

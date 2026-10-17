// ─────────────────────────────────────────────────────────────────────────────
// V2 BarSlot — V1's complete widget/panel behavior on one selectable bar shell.
// The surface spans the full output width at a compact 33px visible height;
// a single screen-facing border and shadow replace the rounded section islands.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "modules"
import "IconMap.js" as IconMap

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

    readonly property real dashboardExpandedWidth: Math.min(800, barSlot.width - 32)
    readonly property real dashboardExpandedHeight: Math.min(barSlot.height - 40, (barSlot.root.dashboardDetail !== "" && barSlot.root.dashboardDetail !== "system") ? 520 : 292)

    readonly property real dashboardTopRadius: barSlot.root.barPosition === "bottom" ? 24 : 10
    readonly property real dashboardBottomRadius: barSlot.root.barPosition === "bottom" ? 10 : 24

    readonly property int shellRadius: isDashboardActive
        ? 24
        : (shellVisibleHeight / 2)
    readonly property int shellVisibleHeight: isDashboardActive
        ? Math.round(dashboardExpandedHeight)
        : barSlot.root.v2BarHeight
    readonly property real shellTargetWidth: isDashboardActive
        ? dashboardExpandedWidth
        : Math.max(80,
            Math.min(barSlot.width - 2 * shellOuterMargin,
                island.fitNaturalWidth))

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
        x: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? 0 : Math.round(continuousBarSurface.x)
        y: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? 0
           : barSlot.effectivelyHidden
               ? (barSlot.root.barPosition === "bottom" ? barSlot.height - 1 : 0)
               : (barSlot.root.barPosition === "bottom" ? barSlot.height - Math.round(continuousBarSurface.height) - 4 : 4)
        width: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? barSlot.width : Math.round(continuousBarSurface.width)
        height: (barSlot.root.barUnlocked || barSlot.isDashboardActive) ? barSlot.height
           : barSlot.effectivelyHidden ? 1 : Math.round(continuousBarSurface.height)
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

    // One uninterrupted surface across the output. On the default top edge the
    // border is literally the bottom border requested for V2; the optional V1
    // bottom placement mirrors it so the shadow still opens toward the desktop.
    Rectangle {
        id: continuousBarSurface
        x: Math.round((barSlot.width - width) / 2)
        readonly property int islandMargin: 4
        readonly property bool lockRetracted: !barSlot.isDashboardActive && barSlot.root.barLockRetracted
        y: lockRetracted
            ? (barSlot.root.barPosition === "bottom" ? barSlot.height + 24 : -height - islandMargin - 24)
            : barSlot.root.barPosition === "bottom"
            ? (barSlot.effectivelyHidden ? barSlot.height : barSlot.height - height - islandMargin)
            : (barSlot.effectivelyHidden ? -height : islandMargin)
        Behavior on y {
            NumberAnimation {
                duration: continuousBarSurface.lockRetracted ? 320 : 400
                easing.type: continuousBarSurface.lockRetracted ? Easing.InBack : Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        width: barSlot.shellTargetWidth
        Behavior on width {
            enabled: barSlot.isDashboardActive || barSlot.isDashboardClosing
            NumberAnimation {
                duration: barSlot.isDashboardActive ? 420 : 300
                easing.type: barSlot.isDashboardActive ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.15
            }
        }
        height: barSlot.shellVisibleHeight
        Behavior on height {
            NumberAnimation {
                duration: barSlot.isDashboardActive ? 420 : 300
                easing.type: barSlot.isDashboardActive ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.15
            }
        }
        radius: barSlot.shellRadius
        Behavior on radius { NumberAnimation { duration: barSlot.isDashboardActive ? 350 : 280; easing.type: Easing.OutCubic } }
        color: "transparent"
        z: (barSlot.isDashboardActive || barSlot.isDashboardClosing) ? 20 : 0

        readonly property real targetTopCornerRadius: barSlot.isDashboardActive ? barSlot.dashboardTopRadius : radius
        readonly property real targetBottomCornerRadius: barSlot.isDashboardActive ? barSlot.dashboardBottomRadius : radius

        property real topCornerRadius: targetTopCornerRadius
        Behavior on topCornerRadius { NumberAnimation { duration: barSlot.isDashboardActive ? 350 : 280; easing.type: Easing.OutCubic } }

        property real bottomCornerRadius: targetBottomCornerRadius
        Behavior on bottomCornerRadius { NumberAnimation { duration: barSlot.isDashboardActive ? 350 : 280; easing.type: Easing.OutCubic } }

        RectangularShadow {
            anchors.fill: parent
            visible: true
            radius: continuousBarSurface.bottomCornerRadius
            blur: barSlot.isDashboardActive ? 24 : 9
            Behavior on blur { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            spread: 0
            offset: Qt.vector2d(0, barSlot.root.barPosition === "bottom" ? -2 : 2)
            color: barSlot.root.v2BarShadow
            z: -1
        }

        Shape {
            id: islandSurfaceBorder
            anchors.fill: parent
            visible: barSlot.isDashboardActive || barSlot.root.barBorderEnabled
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
                fillColor: barSlot.root.barBg
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
        var rows = [leftRowItem, centerRowItem, rightRowItem]
        for (var r = 0; r < rows.length; r++) {
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

    // ── order persistence (survives restart) ──
    readonly property string orderCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barorder_v2"
    readonly property int leftBaseSlotCount: 11
    readonly property int centerBaseSlotCount: 1
    readonly property int rightBaseSlotCount: 7
    // Both side regions can reach the same total capacity. The right side has
    // fewer built-in groups, so it receives three more optional slots.
    readonly property int sideSlotCapacity: 16
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
        var dL = ["G1","G2","G3","G22","","G5","G6","","G7","",""]
        var dR = ["G9","G10","","G14","G12","G13","G16",
                  "G18","G17","G19","G21","","G20","",""]
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
    Component {
        id: compLauncher
        LauncherWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: logoPadding / 2
            readonly property real barContentRightInset: logoPadding / 2
        }
    }
    Component {
        id: compWorkspace
        WorkspaceWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 0
            readonly property real barContentRightInset: 0
        }
    }
    Component {
        id: compStatus                                   // G3: arch · tray · notif
        Item {
            id: statusGroup
            readonly property real barContentLeftInset: barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: barSlot.root.v2IconGroupPadding
            readonly property real archCaretX: statusRow.x + archWidget.x + archWidget.width / 2
            readonly property real trayCaretX: statusRow.x + statusTrayRow.x + trayWidget.x + trayWidget.width / 2
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modStatus
                ? Math.round(statusRow.implicitWidth) + 2 * barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: barSlot.root.modStatus ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: barSlot.root.v2InlineSpacing
                ArchUpdaterWidget  { id: archWidget; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    id: statusTrayRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barSlot.root.v2IconClusterSpacing
                    TrayWidget         { id: trayWidget; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Component {
        id: compNotification                                   // G22: notif
        Item {
            id: notifGroup
            readonly property real barContentLeftInset: barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: barSlot.root.v2IconGroupPadding
            readonly property real notifCaretX: notifRow.x + notifWidget.x + notifWidget.width / 2
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modNotif
                ? Math.round(notifRow.implicitWidth) + 2 * barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: barSlot.root.modNotif ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Row {
                id: notifRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: barSlot.root.v2InlineSpacing
                NotificationWidget { id: notifWidget; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Component {
        id: compMem
        MemoryWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 8
            readonly property real barContentRightInset: 10
        }
    }
    Component {
        id: compCpu
        CpuWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compCpuTemperature
        CpuTemperatureWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compGpu
        GpuWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compStorage
        StorageWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compVol
        AudioWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compClaude
        ClaudeWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compShellFallbackUpdater
        Item {
            width: 26
            height: 28
            ArchUpdaterWidget {
                root: barSlot.root
                colorGid: "G8"
                preferShell: true
                anchors.centerIn: parent
            }
        }
    }

    Component {
        id: compCenter                                   // G8: weather·clock·date·indicators
        Item {
            id: g8
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
            readonly property color contentColor:
                barSlot.root.widgetContentColor("G8", barSlot.root.ink)
            readonly property real weatherCaretX:
                centerRow.x + weatherSlot.x + weatherSlot.width / 2
            readonly property real calendarCaretX:
                centerRow.x + dateSlot.x + dateSlot.width / 2
            implicitWidth: Math.round(centerRow.implicitWidth) + 18
            implicitHeight: 28

            // ── responsive stage (narrow-monitor overlap fix) ──
            // Presentation-only inside G8 — never touches root.mod* user toggles.
            // Mutable state with hysteresis, NOT a computed property: downshift when
            // the CURRENT stage no longer fits (24px slack), upshift only when the
            // LARGER stage would fit with 48px slack — measured against that stage's
            // own needed width, else minimal⇄compact oscillates.
            property int stage: 0                        // 0 normal · 1 compact · 2 minimal
            readonly property bool showWeather: stage <= 1
            readonly property bool showDate:    stage === 0
            readonly property bool showIcons:   iconsRow.hasActive
            // needed widths per stage: reactive bindings over the UNCOLLAPSED content
            // (the stage-gated wrapper widths shrink and would mislead the upshift
            // decision). 18 = pill padding, 8 = row spacing per visible neighbour.
            readonly property real needMinimal: 18 + clock.implicitWidth
                + (showIcons && iconsRow.implicitWidth > 0.5 ? 8 + iconsRow.implicitWidth : 0)
            readonly property real needCompact: needMinimal
                + (weather.implicitWidth > 0.5 ? 8 + weather.implicitWidth : 0)
            readonly property real needNormal: needCompact
                + (dateLabel.implicitWidth > 0.5 ? 8 + dateLabel.implicitWidth : 0)
            function updateStage() {
                // compact only while G8 actually occupies the center slot: after a
                // drag swap G8 can sit in a SIDE row — its own width then feeds the
                // very side-row width that centerAvail is measured from, and the
                // stage delta (~weather+date) exceeds the 24/48px hysteresis window
                // → boundary-width flutter. As a side widget G8 stays at normal.
                if (!barSlot.modelContains(centerModel, "G8")) {
                    if (stage !== 0) stage = 0
                    return
                }
                var avail = island.g8AvailableWidth
                var s = stage
                if (s === 0 && needNormal  + 24 > avail) s = 1
                if (s === 1 && needCompact + 24 > avail) s = 2
                if (s === 2 && needCompact + 48 <= avail) s = 1
                if (s === 1 && needNormal  + 48 <= avail) s = 0
                if (s !== stage) stage = s
            }
            // publish the clock + status-icon floor width for the side-row budget
            Binding { target: island; property: "g8FloorWidth"; value: g8.needMinimal }
            // 80ms one-shot coalesces width flutter (track changes, tray churn)
            Timer { id: restageTimer; interval: 80; repeat: false; onTriggered: g8.updateStage() }
            onNeedNormalChanged:  restageTimer.restart()
            onNeedCompactChanged: restageTimer.restart()
            Connections { target: island; function onG8AvailableWidthChanged() { restageTimer.restart() } }
            Component.onCompleted: restageTimer.restart()

            Row {
                id: centerRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)   // integer center → sharp text
                spacing: barSlot.root.v2SectionSpacing
                Item {                                   // weather wrapper (stage-gated)
                    id: weatherSlot
                    visible: width > 0.5
                    width: g8.showWeather ? weather.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showWeather ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    WeatherWidget {
                        id: weather
                        anchors.fill: parent
                        root: barSlot.root
                    }
                }
                ClockWidget   { id: clock;   root: barSlot.root }
                Item {                                   // date (stage-gated)
                    id: dateSlot
                    visible: width > 0.5
                    width: g8.showDate ? dateLabel.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showDate ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    UiText {
                        id: dateLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            clock.now;
                            var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                            var d = new Date();
                            return days[d.getDay()] + " " + d.getDate();
                        }
                        color: Qt.rgba(g8.contentColor.r, g8.contentColor.g, g8.contentColor.b, 0.5)
                        font.family: barSlot.root.barFont
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barSlot.root.activatePopupScreen(barSlot.screen)
                            barSlot.root.calendarTick++;
                            barSlot.root.calendarVisible = !barSlot.root.calendarVisible
                        }
                    }
                }
                Item {                                   // indicator icons wrapper (stage-gated)
                    visible: g8.showIcons || width > 0.5
                    width: g8.showIcons ? iconsRow.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showIcons ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Row {
                        id: iconsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: barSlot.root.v2InlineSpacing
                        readonly property bool shellFallbackActive: !barSlot.root.modStatus
                            && (barSlot.root.shellUpdateBehind > 0 || barSlot.root.shellUpdateProgressVisible)
                        readonly property bool hasActive: idleInd.awake
                            || dndInd.silenced
                            || screenRecInd.recording
                            || voxInd.state === "recording"
                            || voxInd.state === "transcribing"
                            || omarchyUpdateInd.updateAvailable
                            || shellFallbackActive
                        IdleWidget               { id: idleInd;          root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        NotificationSilenceWidget{ id: dndInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        ScreenRecordWidget       { id: screenRecInd;     root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        VoxtypeWidget            { id: voxInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        UpdateWidget             { id: omarchyUpdateInd; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        Loader {
                            visible: iconsRow.shellFallbackActive || width > 0.5
                            active: iconsRow.shellFallbackActive
                            width: iconsRow.shellFallbackActive ? 26 : 0
                            height: 28
                            sourceComponent: compShellFallbackUpdater
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: compMpris
        MprisWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: active ? 9 : 8
            readonly property real barContentRightInset: active ? 9 : 8
        }
    }
    Component {
        id: compQuick                                    // G10: idle-inhib · media · theme
        Item {
            readonly property real barContentLeftInset: barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: barSlot.root.v2IconGroupPadding
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modQuick
                ? Math.round(qcRow.implicitWidth) + 2 * barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: barSlot.root.modQuick ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Row {
                id: qcRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: barSlot.root.v2IconClusterSpacing
                IdleInhibitorWidget { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                MediaBrowserWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
                ThemeDisplayWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Component {
        id: compNetwork
        NetworkWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compGithubHeatmap
        GithubHeatmapWidget {
            root: barSlot.root
        }
    }
    Component {
        id: compPower
        PowerProfileWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compBattery
        BatteryWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compBrightness
        BrightnessWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compBluetooth
        BluetoothWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compNotes
        NotesWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }

    Component {
        id: compScreentime
        ScreentimeWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    readonly property var registry: ({
        "G1": compLauncher, "G2": compWorkspace, "G3": compStatus,
        "G5": compCpu, "G6": compVol, "G7": compClaude,
        "G8": compCenter,
        "G9": compMpris, "G10": compQuick,
        "G12": compBattery, "G13": compBrightness, "G14": compPower,
        "G16": compCpuTemperature, "G17": compGpu, "G18": compStorage,
        "G21": compScreentime, "G19": compGithubHeatmap, "G20": compNotes, "G22": compNotification
    })

    // ───────────────────── reusable region row of slots ─────────────────────
    component SlotRow: Row {
        id: slotRow
        property var rmodel
        property int baseCount
        property int maxExtraCount: 3
        property alias rep: repeater
        readonly property int extraCount: rmodel ? barSlot.extraSlotCount(rmodel, baseCount) : 0
        spacing: barSlot.root.v2WidgetSpacing
        height: 32
        // index of the LAST currently shown slot (skips disabled and auto-hidden
        // narrow-stage widgets) — a separator only makes sense BEFORE this gap.
        readonly property int lastVisibleIndex: {
            void(width)
            var last = -1
            for (var k = 0; k < repeater.count; k++) {
                var it = repeater.itemAt(k)
                if (it && it.hasContent && it.autoShown) last = k
            }
            return last
        }
        function nextVisibleSlot(afterIndex) {
            void(width)
            for (var i = afterIndex + 1; i < repeater.count; i++) {
                var candidate = repeater.itemAt(i)
                if (candidate && candidate.hasContent && candidate.autoShown) return candidate
            }
            return null
        }

        Repeater {
            id: repeater
            model: rmodel
            delegate: Item {
                id: slot
                required property string gid
                required property bool extra
                required property int index
                readonly property bool occupied: gid !== "" && barSlot.registry[gid] !== undefined
                // workspace draws a pill 4px wider than its implicitWidth on each
                // side; pad its slot symmetrically so inter-group gaps stay uniform.
                readonly property int pad: slot.gid === "G2" ? barSlot.root.wsPillPad : 0
                readonly property var contentItem: ldr.item
                readonly property bool hasContent: occupied && Math.round(ldr.implicitWidth) > 0.5
                readonly property real contentLeftInset: contentItem
                    ? contentItem.barContentLeftInset : 0
                readonly property real contentRightInset: contentItem
                    ? contentItem.barContentRightInset : 0
                readonly property bool hasVisualSurface:
                    barSlot.root.widgetHasFill(gid) || barSlot.root.widgetHasBorder(gid)
                readonly property real visualLeftEdge: pad
                    + (hasVisualSurface ? 0 : contentLeftInset)
                readonly property real visualRightEdge: pad
                    + Math.round(ldr.implicitWidth)
                    - (hasVisualSurface ? 0 : contentRightInset)
                readonly property var nextVisualSlot: slotRow.nextVisibleSlot(index)
                readonly property real nextVisualLeftEdge: nextVisualSlot
                    ? nextVisualSlot.x - slot.x + nextVisualSlot.visualLeftEdge
                    : visualRightEdge + slotRow.spacing
                readonly property real unsetSeparatorCenterX:
                    (visualRightEdge + nextVisualLeftEdge) / 2
                readonly property bool placeholderShown: !occupied && barSlot.root.barUnlocked
                // user-set separator after this widget: extra width is part of BOTH
                // width recipes so the narrow-stage budget stays stage-independent.
                readonly property bool sepOn: occupied && barSlot.root.sepAfter(gid)
                readonly property int sepW: 15
                readonly property real naturalSlotWidth: placeholderShown
                    ? 28
                    : Math.round(ldr.implicitWidth) + 2 * pad + (sepOn && hasContent ? sepW : 0)
                // Empty edit slots do not influence the locked narrow-layout budget.
                readonly property real budgetSlotWidth: hasContent
                    ? Math.round(ldr.implicitWidth) + 2 * pad + (sepOn ? sepW : 0)
                    : 0
                readonly property bool autoShown: placeholderShown
                    || (occupied && island.groupVisibleAtStage(slot.gid, island.narrowStage))
                onBudgetSlotWidthChanged: island.scheduleNarrowUpdate()
                width: autoShown ? naturalSlotWidth : 0
                height: 32
                visible: placeholderShown || (hasContent && (autoShown || width > 0.5))
                opacity: autoShown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Rectangle {
                    id: widgetColorSurface
                    x: slot.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(ldr.implicitWidth)
                    height: 24
                    radius: height / 2
                    clip: true
                    visible: slot.occupied && slot.hasContent && slot.autoShown
                        && (barSlot.root.widgetHasFill(slot.gid)
                            || barSlot.root.widgetHasBorder(slot.gid))
                    color: barSlot.root.widgetFillColor(slot.gid)
                    border.color: barSlot.root.widgetBorderColor(slot.gid)
                    border.width: barSlot.root.widgetHasBorder(slot.gid)
                        ? barSlot.root.panelBorderW
                        : 0
                    Behavior on color {
                        ColorAnimation { duration: 140 }
                    }






                }

                Loader {
                    id: ldr
                    x: slot.pad
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: slot.occupied ? barSlot.registry[slot.gid] : null
                    // dim the original while its ghost is being dragged
                    opacity: (barSlot.dragItem === ldr && barSlot.dragActive) ? 0.25 : 1.0
                }

                // thin vertical divider, centered in the widened right gap
                Rectangle {
                    visible: slot.sepOn && slot.hasContent && slot.autoShown
                    x: slot.width - slot.pad - 5
                    width: 1
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: sepMa.containsMouse ? barSlot.root.seal : barSlot.root.sep
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Quiet drop slot in edit mode. Added empty slots can be removed;
                // an empty base slot remains as the return target for its widget.
                Rectangle {
                    id: emptySlot
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: barSlot.root.tileRadius
                    visible: slot.placeholderShown
                    color: removeMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle
                    border.color: removeMa.containsMouse ? barSlot.root.seal : barSlot.root.sep
                    border.width: 0
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: slot.extra ? "×" : "·"
                        color: removeMa.containsMouse ? barSlot.root.seal : barSlot.root.sumi
                        font.family: barSlot.root.barFont
                        font.pixelSize: slot.extra ? 12 : 14
                    }

                    MouseArea {
                        id: removeMa
                        anchors.fill: parent
                        enabled: slot.extra && !barSlot.dragging
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: barSlot.removeExtraSlot(rmodel, slot.index, slotRow.baseCount)
                    }
                }

                // ── drag-catcher: only in unlock mode, overlays the widget ──
                MouseArea {
                    anchors.fill: parent
                    enabled: barSlot.root.barUnlocked && slot.occupied && slot.hasContent && slot.autoShown
                    visible: enabled
                    z: 25
                    preventStealing: true
                    cursorShape: Qt.OpenHandCursor
                    onPressed: {
                        var p = ldr.mapToItem(null, 0, 0)
                        barSlot.beginDrag(ldr, p.x, p.y, Math.round(ldr.implicitWidth), slot.height, rmodel, slot.index)
                    }
                    onPositionChanged: (e) => {
                        if (!barSlot.dragging) return
                        var w = mapToItem(null, e.x, e.y)
                        barSlot.moveDrag(w.x, w.y)
                    }
                    onReleased: barSlot.endDrag()
                    onCanceled: barSlot.cancelDrag()
                }
                // drop-target highlight (the group under the cursor, not the source)
                Rectangle {
                    anchors.fill: parent
                    radius: barSlot.root.pillRadius
                    color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.30)
                    border.color: barSlot.accent
                    border.width: 0
                    z: 26
                    visible: barSlot.dragging
                        && barSlot.dropModel === rmodel && barSlot.dropIndex === slot.index
                        && !(barSlot.srcModel === rmodel && barSlot.srcIndex === slot.index)
                }

                // ── separator toggle for the gap AFTER this slot (hover-revealed,
                //    V1 split-point pattern — click sets/clears the thin divider) ──
                Item {
                    visible: slot.autoShown && slot.hasContent && slot.index < slotRow.lastVisibleIndex
                    width: 14
                    height: slot.height
                    // The active handle sits exactly over the rendered divider.
                    // For a filled widget, the unset point follows the fill's real
                    // right edge instead of an independently reconstructed width.
                    x: slot.sepOn
                        ? Math.round(slot.width - slot.pad - 4.5 - width / 2)
                        : slot.unsetSeparatorCenterX - width / 2
                    z: 30
                    Text {
                        anchors.centerIn: parent
                        visible: !slot.sepOn
                        text: "•"
                        color: barSlot.root.sumi
                        font.pixelSize: 10; font.family: barSlot.root.barFont
                        opacity: sepMa.containsMouse ? 0.9 : 0.0          // hover-revealed
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: sepMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barSlot.root.toggleSep(slot.gid)
                    }
                }
            }
        }

        Rectangle {
            id: addSlot
            width: visible ? 28 : 0
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: barSlot.root.tileRadius
            visible: barSlot.root.barUnlocked
                && slotRow.extraCount < slotRow.maxExtraCount
            color: addMa.containsMouse ? barSlot.root.fillActive : barSlot.root.fillIdle
            border.color: addMa.containsMouse ? barSlot.root.seal : barSlot.root.sep
            border.width: 0
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: addMa.containsMouse ? barSlot.root.seal : barSlot.root.ink
                font.family: barSlot.root.barFont
                font.pixelSize: 14
            }

            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: barSlot.addExtraSlot(rmodel, slotRow.baseCount,
                    slotRow.maxExtraCount)
            }
        }
    }

    Item {
        id: island
        // The backing layer-window remains full-screen, but the visible/content
        // island follows the selected shell surface. This preserves stable
        // layer-shell resources while the island resizes with its visible rows.
        x: continuousBarSurface.x
        width: continuousBarSurface.width
        height: barSlot.root.v2BarHeight
        y: continuousBarSurface.y
        z: 22
        opacity: (barSlot.isDashboardActive || barSlot.isDashboardClosing) ? 0.0 : 1.0
        visible: opacity > 0.001
        enabled: !barSlot.isDashboardActive && !barSlot.isDashboardClosing
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        focus: barSlot.root.barUnlocked || barSlot.isDashboardActive
        Keys.onEscapePressed: {
            if (barSlot.isDashboardActive) {
                barSlot.root.dashboardExpanded = false
            } else {
                barSlot.root.barUnlocked = false
            }
        }

        property bool isHovered: islandHover.hovered
        HoverHandler {
            id: islandHover
            acceptedDevices: PointerDevice.AllDevices
        }

        property int prevNotifCount: 0
        property real blackHoleStrength: 0

        Connections {
            target: barSlot.root
            function onNotifCountChanged() {
                if (barSlot.root.notifCount > island.prevNotifCount) blackHoleAnim.restart()
                island.prevNotifCount = barSlot.root.notifCount
            }
        }
        SequentialAnimation {
            id: blackHoleAnim
            NumberAnimation { target: island; property: "blackHoleStrength"; from: 0; to: 1; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: island; property: "blackHoleStrength"; from: 1; to: 0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 3.0 }
        }
        transform: Scale {
            origin.x: barSlot.root.notifBarX > 0 ? (barSlot.root.notifBarX - island.x) : island.width / 2
            origin.y: island.height / 2
            xScale: 1.0 - (island.blackHoleStrength * 0.06)
            yScale: 1.0 - (island.blackHoleStrength * 0.08)
        }

        readonly property int fitPadding: Math.floor((barSlot.root.v2BarHeight - 24) / 2.0)
        readonly property int fitRegionGap: 12
        readonly property int fitRegionCount:
            (leftRowItem.implicitWidth > 0.5 ? 1 : 0)
            + (centerRowItem.implicitWidth > 0.5 ? 1 : 0)
            + (rightRowItem.implicitWidth > 0.5 ? 1 : 0)

        // The base shell draws a black hole around the island when hovered.
        property bool isIslandHidden: (!island.isHovered || island.osdActive) && !barSlot.root.anyPopupVisible
        property real islandShrinkProgress: 1.0
        property real islandElementsOpacity: 0.0
        property real islandCollapsedOpacity: 1.0

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
            target: barSlot.root
            function onIslandOsdTickChanged() {
                island.osdKind = barSlot.root.islandOsdKind
                island.osdValue = barSlot.root.islandOsdValue
                island.osdActive = true
                island.osdProgress = 1.0
                islandOsdTimer.restart()
            }
        }

        onIsIslandHiddenChanged: {
            if (!isIslandHidden) {
                collapseAnim.stop()
                expandAnim.restart()
            } else {
                expandAnim.stop()
                collapseAnim.restart()
            }
        }

        SequentialAnimation {
            id: expandAnim
            // Step 1: Fade out collapsed items quickly and bounce expand the bar!
            ParallelAnimation {
                NumberAnimation {
                    target: island
                    property: "islandCollapsedOpacity"
                    to: 0.0
                    duration: 100
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: island
                    property: "islandShrinkProgress"
                    to: 0.0
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.25
                }
            }
            // Step 2: Once the bar has bounced open, fade and settle in all elements!
            NumberAnimation {
                target: island
                property: "islandElementsOpacity"
                to: 1.0
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        SequentialAnimation {
            id: collapseAnim
            ParallelAnimation {
                // Step 1: Quickly fade out the expanded elements
                NumberAnimation {
                    target: island
                    property: "islandElementsOpacity"
                    to: 0.0
                    duration: 110
                    easing.type: Easing.OutQuad
                }
                // Step 2: Bounce the bar closed to collapsed width and fade in collapsed items
                SequentialAnimation {
                    PauseAnimation { duration: 20 }
                    ParallelAnimation {
                        NumberAnimation {
                            target: island
                            property: "islandShrinkProgress"
                            to: 1.0
                            duration: 360
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                        SequentialAnimation {
                            PauseAnimation { duration: 150 }
                            NumberAnimation {
                                target: island
                                property: "islandCollapsedOpacity"
                                to: 1.0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        property real leftVisibleWidth: (1.0 - islandShrinkProgress) * (leftRowItem.implicitWidth + (leftRowItem.implicitWidth > 0.5 ? fitRegionGap : 0))
        property real rightVisibleWidth: (1.0 - islandShrinkProgress) * (rightRowItem.implicitWidth + (rightRowItem.implicitWidth > 0.5 ? fitRegionGap : 0))

        readonly property real defaultCollapsedCenterWidth: islandCollapsedItem.width + centerRowItem.implicitWidth + 8 + islandCollapsedRightSlot.width
        readonly property real collapsedCenterTotalWidth: (1.0 - osdProgress) * defaultCollapsedCenterWidth + osdProgress * islandOsdItem.width
        readonly property real centerVisibleWidth: (1.0 - islandShrinkProgress) * centerRowItem.implicitWidth + islandShrinkProgress * collapsedCenterTotalWidth
        readonly property real fitNaturalWidth: Math.ceil(
            2 * fitPadding
            + centerVisibleWidth
            + leftVisibleWidth
            + rightVisibleWidth
        )

        // edit-mode frame around the bar while unlocked (gentle pulse)
        Rectangle {
            anchors.fill: parent
            radius: barSlot.shellRadius
            color: "transparent"
            border.color: barSlot.accent
            border.width: barSlot.root.barUnlocked ? 1 : 0    // width 0 hides it when locked
            z: 40
            SequentialAnimation on opacity {
                running: barSlot.root.barUnlocked
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
            onDoubleClicked: barSlot.root.barUnlocked = true
        }

        // ── Center-region collision handling (narrow-monitor overlap fix) ──
        // free span between the side rows; the only stage-decision input — reads
        // ONLY left/right geometry (never the center row), so stage changes that
        // resize G8 cannot feed back into this value (no binding loop).
        readonly property int centerGap: 12
        // Pull the first and last groups 2px closer to the physical screen edge.
        readonly property int rowMargin: 5
        readonly property real centerAvail: Math.max(0, barSlot.width - 2 * barSlot.shellOuterMargin
            - 2 * fitPadding - leftRowItem.implicitWidth - rightRowItem.implicitWidth
            - 2 * fitRegionGap)
        readonly property real centerOtherBudgetWidth: {
            var sum = 0, visibleCount = 0
            for (var i = 0; i < centerRowItem.rep.count; i++) {
                var item = centerRowItem.rep.itemAt(i)
                if (!item || !item.hasContent) continue
                if (!groupVisibleAtStage(item.gid, narrowStage)) continue
                visibleCount++
                if (item.gid !== "G8") sum += item.budgetSlotWidth
            }
            return sum + Math.max(0, visibleCount - 1) * centerRowItem.spacing
        }
        // G8 may occupy any center slot after drag & drop. Reserve the other
        // center widgets first so its internal responsive stage sees real space.
        readonly property real g8AvailableWidth: Math.max(0, centerAvail - centerOtherBudgetWidth)
        // centered while space allows; clamped between the rows when squeezed.
        // If even the current G8 width cannot fit (max < min), fall back to the
        // screen-clamped ideal — the documented extreme case may overlap.
        readonly property real idealCenterX: Math.round((width - centerRowItem.width) / 2)
        readonly property real minCenterX: Math.round(leftRowItem.x + leftRowItem.width + centerGap)
        readonly property real maxCenterX: Math.round(rightRowItem.x - centerGap - centerRowItem.width)
        readonly property real centerTargetX: maxCenterX < minCenterX
            ? Math.max(4, Math.min(idealCenterX, width - centerRowItem.width - 4))
            : Math.max(minCenterX, Math.min(idealCenterX, maxCenterX))

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
            if (stage === 1) return ["G7", "G9", "G10"].indexOf(gid) < 0         // drop AI · MPRIS · Quick
            if (stage === 2) return ["G4", "G7", "G9", "G10", "G17", "G18", "G19"].indexOf(gid) < 0   // also MEM · GPU · HDD · Heatmap
            return ["G1", "G2", "G6", "G8", "G11", "G14"].indexOf(gid) >= 0      // emergency whitelist
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
            // side rows + minimal viable center row + margins + center gaps
            return sideNaturalWidth(leftRowItem, stage) + sideNaturalWidth(rightRowItem, stage)
                 + centerFloorWidth(stage)
                 + 2 * fitRegionGap + 2 * fitPadding
        }
        function updateNarrowStage() {
            // Compare against the available SCREEN width, never the
            // content-driven width. Otherwise hiding a group would shrink
            // the measurement that decided to hide it and create a feedback loop.
            var s = narrowStage
            var W = barSlot.width - 2 * barSlot.shellOuterMargin
            if (W < 1) return                              // no layout yet
            // downshift while the CURRENT stage no longer fits (24px slack)…
            if (s === 0 && narrowCandidateWidth(0) + 24 > W) s = 1
            if (s === 1 && narrowCandidateWidth(1) + 24 > W) s = 2
            if (s === 2 && narrowCandidateWidth(2) + 24 > W) s = 3
            // …upshift only when the NEXT-LARGER stage fits with 48px slack,
            // measured against that stage's own candidate width.
            if (s === 3 && narrowCandidateWidth(2) + 48 <= W) s = 2
            if (s === 2 && narrowCandidateWidth(1) + 48 <= W) s = 1
            if (s === 1 && narrowCandidateWidth(0) + 48 <= W) s = 0
            if (s !== narrowStage) narrowStage = s
        }
        function scheduleNarrowUpdate() { narrowTimer.restart() }
        Timer { id: narrowTimer; interval: 80; repeat: false; onTriggered: island.updateNarrowStage() }
        onWidthChanged: scheduleNarrowUpdate()
        onG8FloorWidthChanged: scheduleNarrowUpdate()
        Connections {
            target: barSlot.root
            function onBarShellStyleChanged() {
                island.scheduleNarrowUpdate()
                expandAnim.stop()
                collapseAnim.stop()
                island.islandShrinkProgress = island.isIslandHidden ? 1.0 : 0.0
                island.islandElementsOpacity = island.isIslandHidden ? 0.0 : 1.0
                island.islandCollapsedOpacity = island.isIslandHidden ? 1.0 : 0.0
            }
        }

        // ── region models (physical L→R order) ──
        ListModel {
            id: leftModel
            ListElement { gid: "G1"; extra: false } ListElement { gid: "G2"; extra: false } ListElement { gid: "G3"; extra: false } ListElement { gid: "G22"; extra: false }
            ListElement { gid: ""; extra: false }   ListElement { gid: "G5"; extra: false } ListElement { gid: "G6"; extra: false }
            ListElement { gid: ""; extra: false } ListElement { gid: "G7"; extra: false } ListElement { gid: ""; extra: false }
            ListElement { gid: ""; extra: false }
        }
        ListModel {
            id: centerModel
            ListElement { gid: "G8"; extra: false }
        }
        ListModel {
            id: rightModel
            ListElement { gid: "G9"; extra: false }  ListElement { gid: "G10"; extra: false } ListElement { gid: ""; extra: false }
            ListElement { gid: "G14"; extra: false } ListElement { gid: "G12"; extra: false } ListElement { gid: "G13"; extra: false }
            ListElement { gid: "G16"; extra: false }  ListElement { gid: "G17"; extra: true }
            ListElement { gid: "G19"; extra: true }  ListElement { gid: ""; extra: true }  ListElement { gid: "G20"; extra: true }
            ListElement { gid: "G21"; extra: true }
            ListElement { gid: ""; extra: true }
            ListElement { gid: ""; extra: true }
        }

        SlotRow {
            id: leftRowItem
            anchors.verticalCenter: parent.verticalCenter
            x: island.fitPadding - (island.islandShrinkProgress * implicitWidth)
            rmodel: leftModel
            baseCount: barSlot.leftBaseSlotCount
            maxExtraCount: barSlot.leftExtraSlotLimit
            opacity: island.islandElementsOpacity
            visible: opacity > 0.001
            transform: Translate {
                y: (1.0 - island.islandElementsOpacity) * (barSlot.root.barPosition === "bottom" ? 4 : -4)
            }
        }
        SlotRow {
            id: centerRowItem
            // no centerIn: x is clamped between the side rows on narrow monitors
            anchors.verticalCenter: parent.verticalCenter
            x: island.fitPadding + island.leftVisibleWidth
            rmodel: centerModel
            baseCount: barSlot.centerBaseSlotCount
            maxExtraCount: barSlot.centerExtraSlotLimit
            visible: opacity > 0.001
            opacity: 1.0 * (1.0 - island.osdProgress)
            transform: Translate {
                y: 0
            }
        }
        
        Rectangle {
            id: islandCollapsedItem
            anchors.verticalCenter: parent.verticalCenter
            x: island.fitPadding + island.leftVisibleWidth + centerRowItem.implicitWidth + 4
            
            readonly property bool mediaActive: barSlot.mprisPanel && barSlot.mprisPanel.active
            readonly property bool hasLyrics: mediaActive && barSlot.mprisPanel.lyricsTrackId !== "" && barSlot.mprisPanel.lyricsTrackId === barSlot.mprisPanel.currentTrackId && barSlot.mprisPanel.lyricsList && barSlot.mprisPanel.lyricsList.length > 0 && barSlot.mprisPanel.currentLyricIndex >= 0
            readonly property string lyricText: hasLyrics ? barSlot.mprisPanel.lyricsList[barSlot.mprisPanel.currentLyricIndex].text : ""
            
            readonly property string windowTitle: Hyprland && Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
            
            readonly property string displayText: hasLyrics ? lyricText : (windowTitle !== "" ? windowTitle : "Desktop")
            readonly property real maxTextWidth: hasLyrics ? (barSlot.width - 120) : 350
            
            property string activeSlot: "A"
            readonly property real targetTextWidth: activeSlot === "A" ? textA.implicitWidth : textB.implicitWidth
            readonly property real visibleWidth: Math.min(Math.max(targetTextWidth + 24, 60), maxTextWidth + 24)
            width: visibleWidth
            Behavior on width {
                NumberAnimation { duration: 480; easing.type: Easing.OutCubic }
            }
            height: 24
            radius: height / 2
            color: "transparent"
            clip: true
            opacity: island.islandCollapsedOpacity * (1.0 - island.osdProgress)
            visible: opacity > 0.001

            property int prevLyricIndex: -1
            property bool initialized: false

            function switchText(newText, forced) {
                if (!forced && newText === (activeSlot === "A" ? textA.text : textB.text)) return

                var curIdx = (hasLyrics && barSlot.mprisPanel) ? barSlot.mprisPanel.currentLyricIndex : -1
                var movingBackwards = hasLyrics && (curIdx >= 0) && (prevLyricIndex >= 0) && (curIdx < prevLyricIndex)
                if (hasLyrics && curIdx >= 0) {
                    prevLyricIndex = curIdx
                } else {
                    prevLyricIndex = -1
                }

                var dir = movingBackwards ? -1 : 1
                var outY = -14 * dir
                var inStartY = 14 * dir

                animToB.stop()
                animToA.stop()

                if (activeSlot === "A") {
                    textB.text = newText
                    transB.y = inStartY
                    textB.opacity = 0.0
                    animTransAY.to = outY
                    activeSlot = "B"
                    animToB.restart()
                } else {
                    textA.text = newText
                    transA.y = inStartY
                    textA.opacity = 0.0
                    animTransBY.to = outY
                    activeSlot = "A"
                    animToA.restart()
                }
            }

            onDisplayTextChanged: {
                if (!islandCollapsedItem.initialized) return
                if (islandCollapsedItem.displayText === (islandCollapsedItem.activeSlot === "A" ? textA.text : textB.text)) return
                islandCollapsedItem.switchText(islandCollapsedItem.displayText, false)
            }

            Connections {
                target: barSlot.mprisPanel ? barSlot.mprisPanel : null
                function onCurrentLyricIndexChanged() {
                    if (!islandCollapsedItem.initialized || !islandCollapsedItem.hasLyrics) return
                    if (islandCollapsedItem.displayText === (islandCollapsedItem.activeSlot === "A" ? textA.text : textB.text)) {
                        islandCollapsedItem.switchText(islandCollapsedItem.displayText, true)
                    }
                }
            }

            Component.onCompleted: {
                textA.text = displayText
                textA.opacity = 1.0
                transA.y = 0
                textB.text = ""
                textB.opacity = 0.0
                transB.y = 14
                activeSlot = "A"
                if (hasLyrics && barSlot.mprisPanel) {
                    prevLyricIndex = barSlot.mprisPanel.currentLyricIndex
                }
                initialized = true
            }

            ParallelAnimation {
                id: animToB
                NumberAnimation {
                    id: animTransAY
                    target: transA
                    property: "y"
                    to: -14
                    duration: 480
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textA
                    property: "opacity"
                    to: 0.0
                    duration: 380
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: transB
                    property: "y"
                    to: 0
                    duration: 480
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textB
                    property: "opacity"
                    to: 1.0
                    duration: 440
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: animToA
                NumberAnimation {
                    id: animTransBY
                    target: transB
                    property: "y"
                    to: -14
                    duration: 480
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textB
                    property: "opacity"
                    to: 0.0
                    duration: 380
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: transA
                    property: "y"
                    to: 0
                    duration: 480
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textA
                    property: "opacity"
                    to: 1.0
                    duration: 440
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: textA
                anchors.centerIn: parent
                text: islandCollapsedItem.displayText
                color: barSlot.root.ink
                font.family: "DM Sans"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: islandCollapsedItem.hasLyrics ? Text.ElideNone : Text.ElideRight
                width: Math.min(implicitWidth, islandCollapsedItem.maxTextWidth)
                transform: Translate { id: transA; y: 0 }
            }

            Text {
                id: textB
                anchors.centerIn: parent
                text: ""
                color: barSlot.root.ink
                font.family: "DM Sans"
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: islandCollapsedItem.hasLyrics ? Text.ElideNone : Text.ElideRight
                width: Math.min(implicitWidth, islandCollapsedItem.maxTextWidth)
                opacity: 0.0
                transform: Translate { id: transB; y: 14 }
            }
        }
        ListModel {
            id: islandMediaModel
            ListElement { gid: "G9"; type: "widget"; extra: false }
        }

        ListModel {
            id: islandBatteryModel
            ListElement { gid: "G12"; type: "widget"; extra: false }
        }

        SlotRow {
            id: islandCollapsedRightSlot
            anchors.verticalCenter: parent.verticalCenter
            
            x: island.fitPadding + island.leftVisibleWidth + centerRowItem.implicitWidth + 4 + islandCollapsedItem.width + 4
                
            visible: opacity > 0.001
            opacity: island.islandCollapsedOpacity * (1.0 - island.osdProgress)
            
            rmodel: islandCollapsedItem.mediaActive ? islandMediaModel : islandBatteryModel
            baseCount: 1
            maxExtraCount: 0
        }

        Rectangle {
            id: islandOsdItem
            anchors.centerIn: parent

            width: 220
            height: 24
            radius: height / 2
            color: "transparent"
            clip: true
            opacity: island.islandCollapsedOpacity * island.osdProgress
            visible: opacity > 0.001

            readonly property color sliderColor: island.osdKind === "audio-muted" 
                ? Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.45)
                : barSlot.root.seal

            transform: Translate {
                y: (1.0 - island.osdProgress) * (barSlot.root.barPosition === "bottom" ? 6 : -6)
            }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Item {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        font.pixelSize: 18
                        color: islandOsdItem.sliderColor
                        text: {
                            if (island.osdKind === "brightness") {
                                return IconMap.icon("light_mode")
                            } else if (island.osdKind === "audio-muted") {
                                return IconMap.icon("volume_off")
                            } else {
                                if (island.osdValue <= 0) return IconMap.icon("volume_mute")
                                if (island.osdValue <= 50) return IconMap.icon("volume_down")
                                return IconMap.icon("volume_up")
                            }
                        }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }

                Rectangle {
                    id: osdTrack
                    width: 130
                    height: 18
                    radius: height / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.22)
                    clip: true

                    Item {
                        id: osdFillItem
                        readonly property real val: Math.max(0, Math.min(100, island.osdKind === "audio-muted" ? 0 : island.osdValue))
                        readonly property real maxGap: 14
                        readonly property real gap: val > 85 ? maxGap * (100 - val) / 15.0 : maxGap
                        readonly property real barOpacity: val > 85 ? (100 - val) / 15.0 : 1.0

                        width: val > 0 ? Math.max(parent.height + maxGap, parent.width * (val / 100.0)) : 0
                        height: parent.height
                        visible: val > 0

                        Behavior on width {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        // The actual fill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(parent.height, parent.width - osdFillItem.gap)
                            radius: (height / 4) + ((height / 4) * (1.0 - osdFillItem.barOpacity))
                            color: islandOsdItem.sliderColor

                            // fully rounded on the left
                            Rectangle {
                                width: parent.height
                                height: parent.height
                                radius: height / 2
                                color: parent.color
                                anchors.left: parent.left
                            }

                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        // The vertical bar with "padding"
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: osdFillItem.maxGap
                            height: parent.height
                            color: "transparent"
                            opacity: osdFillItem.barOpacity

                            Rectangle {
                                anchors.centerIn: parent
                                width: 2.5
                                height: parent.height - 6
                                radius: 1.25
                                color: islandOsdItem.sliderColor

                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }
                    }
                }

                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    horizontalAlignment: Text.AlignLeft
                    text: (island.osdKind === "audio-muted" ? "0" : String(island.osdValue)) + "%"
                    color: island.osdKind === "audio-muted"
                        ? Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.45)
                        : barSlot.root.ink
                    font.family: barSlot.root.barFont
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        SlotRow {
            id: rightRowItem
            anchors.verticalCenter: parent.verticalCenter
            x: island.fitPadding + island.leftVisibleWidth + island.centerVisibleWidth + (island.centerVisibleWidth > 0.5 ? island.fitRegionGap : 0)
            rmodel: rightModel
            baseCount: barSlot.rightBaseSlotCount
            maxExtraCount: barSlot.rightExtraSlotLimit
            opacity: island.islandElementsOpacity
            visible: opacity > 0.001
            transform: Translate {
                y: (1.0 - island.islandElementsOpacity) * (barSlot.root.barPosition === "bottom" ? 4 : -4)
            }
        }

        // ── slot-aware panel X positions: publish per-screen anchors ──
        // find a group's slot and map its (frac·width) to window/screen X.
        function groupX(gid, frac) {
            var rows = [leftRowItem, centerRowItem, rightRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
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
            var rows = [leftRowItem, centerRowItem, rightRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid && it.contentItem
                            && it.contentItem[propertyName] !== undefined) {
                        return island.x + row.x + it.x + it.pad
                            + Number(it.contentItem[propertyName])
                    }
                }
            }
            return groupX(gid, fallbackFrac)
        }

        readonly property string panelScreenName: barSlot.screen ? barSlot.screen.name : ""
        readonly property var panelAnchors: {
            void(island.width)
            void(island.x)
            void(leftRowItem.x); void(centerRowItem.x); void(rightRowItem.x)
            void(leftRowItem.width); void(centerRowItem.width); void(rightRowItem.width)
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
        onPanelAnchorsChanged: barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
        Component.onCompleted: barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)

    }



    // ── In-place expanded Island Dock dashboard ──
    Item {
        id: expandedDashboardContainer
        x: continuousBarSurface.x
        y: continuousBarSurface.y
        width: continuousBarSurface.width
        height: continuousBarSurface.height
        z: 25
        clip: true
        opacity: barSlot.isDashboardActive ? 1.0 : 0.0
        visible: opacity > 0.001
        enabled: barSlot.isDashboardActive
        Behavior on opacity {
            NumberAnimation {
                duration: barSlot.isDashboardActive ? 250 : 160
                easing.type: Easing.OutCubic
            }
        }

        property date now: new Date()
        Timer {
            interval: 1000
            running: barSlot.isDashboardActive
            repeat: true
            onTriggered: expandedDashboardContainer.now = new Date()
        }

        function pad(n) { return n < 10 ? "0" + n : String(n) }

        readonly property string hourStr: {
            var h = barSlot.root.clock12h ? now.getHours() % 12 : now.getHours()
            if (barSlot.root.clock12h && h === 0) h = 12
            return pad(h)
        }
        readonly property string minStr: pad(now.getMinutes())
        readonly property string amPmStr: barSlot.root.clock12h ? (now.getHours() < 12 ? "AM" : "PM") : ""

        readonly property var months: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        readonly property var days: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        readonly property var shortDays: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        readonly property string dateStr: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()]
        readonly property string dateShortStr: shortDays[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()

        QtObject {
            id: dashboardAdapter
            property bool expanded: barSlot.root.dashboardExpanded
            onExpandedChanged: {
                if (barSlot.root.dashboardExpanded !== expanded) {
                    barSlot.root.dashboardExpanded = expanded
                }
            }
            property bool searchOpen: false
            function toggleSearch() {
                searchOpen = !searchOpen
                if (searchOpen) {
                    petSearch.open()
                } else {
                    petSearch.close()
                }
            }
            function toggleSearchEngine() {
                if (petSearch) petSearch.toggleEngine()
            }
        }

        Timer {
            id: dashboardCloseTimer
            interval: 220
            repeat: false
            onTriggered: {
                barSlot.isDashboardClosing = false
                if (dashboardLoader.item) {
                    dashboardLoader.item.activeDetailView = ""
                    dashboardLoader.item.selectCategoryByIndex(0)
                }
                barSlot.root.dashboardDetail = ""
            }
        }

        Connections {
            target: barSlot
            function onIsDashboardActiveChanged() {
                if (barSlot.isDashboardActive) {
                    dashboardCloseTimer.stop()
                    barSlot.isDashboardClosing = false
                    barSlot.dashboardEverActivated = true
                    if (dashboardLoader.item) {
                        if (!barSlot.root.dashboardDetail) {
                            dashboardLoader.item.activeDetailView = ""
                            dashboardLoader.item.selectCategoryByIndex(0)
                        } else {
                            dashboardLoader.item.activeDetailView = barSlot.root.dashboardDetail
                        }
                        dashboardLoader.item.forceActiveFocus()
                    }
                } else {
                    dashboardAdapter.searchOpen = false
                    if (petSearch) petSearch.close()
                    barSlot.isDashboardClosing = true
                    dashboardCloseTimer.restart()
                }
            }
        }

        // Unified Top Header Bar
        Item {
            id: topHeaderBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: barSlot.dashboardExpandedWidth - 28
            anchors.topMargin: 14
            height: 32
            z: 10

            // Left Side: System Pet + Cute Search Bar + Clock Pill + Battery Pill
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                SystemPet {
                    id: systemPet
                    root: barSlot.root
                    curious: dashboardAdapter.searchOpen
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: dashboardAdapter.toggleSearch()
                }

                PetSearchBar {
                    id: petSearch
                    root: barSlot.root
                    isOpen: dashboardAdapter.searchOpen
                    maxContentWidth: Math.max(160, Math.min(260, topHeaderBar.width - systemPet.width - topHeaderRightRow.width - 24))
                    anchors.verticalCenter: parent.verticalCenter
                    onFocusLostOrClosed: {
                        dashboardAdapter.searchOpen = false
                        if (dashboardLoader.item) dashboardLoader.item.forceActiveFocus()
                    }
                    onSearchSubmitted: {
                        barSlot.root.dashboardExpanded = false
                    }
                }

                // Battery Pill
                Rectangle {
                    id: batteryPill
                    height: 28
                    readonly property bool shouldShow: !dashboardAdapter.searchOpen && battLoader.item && battLoader.item.shown
                    width: shouldShow ? battLoader.item.implicitWidth : 0
                    opacity: shouldShow ? 1.0 : 0.0
                    radius: 14
                    color: barSlot.root.dashboardDetail === "battery"
                        ? Qt.rgba(barSlot.root.seal.r, barSlot.root.seal.g, barSlot.root.seal.b, 0.22)
                        : (batteryPillMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle)
                    border.width: barSlot.root.dashboardDetail === "battery" ? 1.5 : 0
                    border.color: barSlot.root.seal
                    clip: true
                    visible: width > 0.1 || opacity > 0.01
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Loader {
                        id: battLoader
                        anchors.centerIn: parent
                        active: barSlot.dashboardEverActivated
                        sourceComponent: BatteryWidget { root: barSlot.root }
                    }

                    MouseArea {
                        id: batteryPillMa
                        anchors.fill: parent
                        z: 10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (barSlot.root.dashboardDetail === "battery") {
                                barSlot.root.dashboardDetail = ""
                            } else {
                                barSlot.root.dashboardDetail = "battery"
                            }
                        }
                    }
                }

                // DateTime Pill
                Rectangle {
                    id: dateTimePill
                    height: 28
                    readonly property bool shouldShow: !dashboardAdapter.searchOpen
                    width: shouldShow ? dateTimeRow.implicitWidth + 20 : 0
                    opacity: shouldShow ? 1.0 : 0.0
                    radius: 14
                    color: dateTimeMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle
                    clip: true
                    visible: width > 0.1 || opacity > 0.01
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: dateTimeRow
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            text: "schedule"
                            color: barSlot.root.ink
                            font.pixelSize: 13
                            opacity: 0.75
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: dateTimeTxt
                            text: expandedDashboardContainer.dateShortStr + "  •  " + expandedDashboardContainer.hourStr + ":" + expandedDashboardContainer.minStr + (expandedDashboardContainer.amPmStr !== "" ? " " + expandedDashboardContainer.amPmStr : "")
                            color: barSlot.root.ink
                            opacity: 0.85
                            font.family: barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dateTimeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barSlot.root.calendarVisible = !barSlot.root.calendarVisible
                        }
                    }
                }
            }

            // Right Side: Screentime/Uptime Pill + Restart Button + Power Off Button
            Row {
                id: topHeaderRightRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Process {
                    id: uptimeProc
                    command: ["bash", "-c", "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime"]
                    running: barSlot.isDashboardActive
                    stdout: StdioCollector {
                        onStreamFinished: {
                            uptimeTxt.text = this.text.trim()
                        }
                    }
                }
                Timer {
                    interval: 60000; repeat: true; running: barSlot.isDashboardActive
                    onTriggered: { uptimeProc.running = false; uptimeProc.running = true }
                }

                // Screentime / Uptime Pill
                Rectangle {
                    height: 28
                    width: uptimeRow.implicitWidth + 20
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: barSlot.root.dashboardDetail === "screentime"
                        ? Qt.rgba(barSlot.root.seal.r, barSlot.root.seal.g, barSlot.root.seal.b, 0.22)
                        : (uptimeMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle)
                    border.width: barSlot.root.dashboardDetail === "screentime" ? 1.5 : 0
                    border.color: barSlot.root.seal
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: uptimeRow
                        anchors.centerIn: parent
                        spacing: 5

                        IconText {
                            text: "timelapse"
                            color: barSlot.root.ink
                            font.pixelSize: 13
                            opacity: 0.75
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: uptimeTxt
                            text: "--"
                            color: barSlot.root.ink
                            opacity: 0.85
                            font.family: barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: uptimeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (barSlot.root.dashboardDetail === "screentime") {
                                barSlot.root.dashboardDetail = ""
                            } else {
                                barSlot.root.dashboardDetail = "screentime"
                            }
                        }
                    }
                }

                // System / Power Settings Button
                Rectangle {
                    id: systemBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: barSlot.root.dashboardDetail === "system"
                        ? Qt.rgba(barSlot.root.seal.r, barSlot.root.seal.g, barSlot.root.seal.b, 0.22)
                        : (systemBtnMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle)
                    border.width: barSlot.root.dashboardDetail === "system" ? 1.5 : 0
                    border.color: barSlot.root.seal
                    scale: systemBtnMa.pressed ? 0.92 : (systemBtnMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        color: barSlot.root.dashboardDetail === "system" ? barSlot.root.seal : barSlot.root.ink
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: systemBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (barSlot.root.dashboardDetail === "system") {
                                barSlot.root.dashboardDetail = ""
                            } else {
                                barSlot.root.dashboardDetail = "system"
                            }
                        }
                    }
                }
            }
        }

        // Expanded Dashboard Content
        Loader {
            id: dashboardLoader
            anchors.top: topHeaderBar.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: barSlot.dashboardExpandedWidth - 28
            height: Math.round(barSlot.dashboardExpandedHeight - 32 - 12 - 14 - 14)
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            active: barSlot.dashboardEverActivated
            source: Qt.resolvedUrl("panels/HomescreenDashboardContent.qml")
            z: 5

            onLoaded: {
                item.root = barSlot.root
                item.panel = dashboardAdapter
                item.mprisPanel = barSlot.mprisPanel
                if (!barSlot.root.dashboardDetail) {
                    item.activeDetailView = ""
                    item.selectCategoryByIndex(0)
                } else {
                    item.activeDetailView = barSlot.root.dashboardDetail
                }
                if (barSlot.isDashboardActive) item.forceActiveFocus()
            }
        }
    }
}

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
import Quickshell.Services.Mpris
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
    readonly property real dashboardExpandedHeight: Math.min(barSlot.height - 40, 292)

    readonly property real dashboardTopRadius: barSlot.root.barPosition === "bottom" ? 24 : 10
    readonly property real dashboardBottomRadius: barSlot.root.barPosition === "bottom" ? 10 : 24

    readonly property int notifTargetHeight: (island && island.notifPeekActive && typeof islandNotifPeekItem !== "undefined")
        ? (island.notifPeekBody !== "" ? Math.min(88, Math.max(64, islandNotifPeekItem.desiredCardHeight)) : 44)
        : barSlot.root.v2BarHeight
    readonly property int chargingTargetHeight: 40
    readonly property int barExpandedHeight: Math.round(barSlot.root.v2BarHeight * 2.5)
    readonly property int shellVisibleHeight: isDashboardActive
        ? Math.round(dashboardExpandedHeight)
        : (island && island.chargingProgress > 0
            ? Math.round(barSlot.root.v2BarHeight + (chargingTargetHeight - barSlot.root.v2BarHeight) * island.chargingProgress)
            : (island && island.notifPeekActive
                ? Math.round(barSlot.root.v2BarHeight + (notifTargetHeight - barSlot.root.v2BarHeight) * island.notifPeekProgress)
                : Math.round(barSlot.root.v2BarHeight + (barExpandedHeight - barSlot.root.v2BarHeight) * (1.0 - island.islandShrinkProgress))))
    readonly property int shellRadius: isDashboardActive
        ? 24
        : ((island && island.notifPeekActive && island.notifPeekBody !== "")
            ? 18
            : (island && island.islandShrinkProgress < 0.5 ? 20 : Math.round(shellVisibleHeight / 2)))
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

    function formatTitleCase(str) {
        if (!str || typeof str !== "string") return ""
        return str.replace(/\b[a-zA-Z]/g, function(c) { return c.toUpperCase() })
    }

    function formatSentenceCase(str) {
        if (!str || typeof str !== "string") return ""
        var s = str.trim()
        if (s.length === 0) return ""
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    // One uninterrupted surface across the output. On the default top edge the
    // border is literally the bottom border requested for V2; the optional V1
    // bottom placement mirrors it so the shadow still opens toward the desktop.
    Rectangle {
        id: continuousBarSurface
        x: Math.round((barSlot.width - width) / 2)
        readonly property int islandMargin: 4
        y: barSlot.root.barPosition === "bottom"
            ? (barSlot.effectivelyHidden ? barSlot.height : barSlot.height - height - islandMargin)
            : (barSlot.effectivelyHidden ? -height : islandMargin)
        Behavior on y {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }
        width: barSlot.shellTargetWidth
        Behavior on width {
            enabled: barSlot.isDashboardActive || barSlot.isDashboardClosing
            NumberAnimation {
                duration: barSlot.isDashboardActive ? 240 : 180
                easing.type: barSlot.isDashboardActive ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.10
            }
        }
        height: barSlot.shellVisibleHeight
        Behavior on height {
            NumberAnimation {
                duration: barSlot.isDashboardActive ? 240 : 180
                easing.type: barSlot.isDashboardActive ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.10
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

        readonly property var activePrivacyColors: {
            var list = []
            if (barSlot.root.privacyMic) list.push("#F59E0B")
            if (barSlot.root.privacyCam) list.push("#10B981")
            if (barSlot.root.privacyScreen) list.push(barSlot.root.screenRecording ? "#EF4444" : "#3B82F6")
            return list
        }

        readonly property color privacyColorStart: {
            var cols = activePrivacyColors
            if (!cols || cols.length === 0) return "transparent"
            return cols[0]
        }

        readonly property color privacyColorMid: {
            var cols = activePrivacyColors
            if (!cols || cols.length === 0) return "transparent"
            if (cols.length === 1) return cols[0]
            if (cols.length === 2) return cols[1]
            return cols[1] // Emerald in tricolor
        }

        readonly property color privacyColorEnd: {
            var cols = activePrivacyColors
            if (!cols || cols.length === 0) return "transparent"
            if (cols.length === 1) return cols[0]
            if (cols.length === 2) return cols[1]
            return cols[2] // Blue/Red in tricolor
        }

        // Hardware Privacy Subtle Gradient Glow (Tricolor horizontal gradient under bottom border)
        Item {
            id: privacyGlowUnderlay
            visible: barSlot.root.privacyAnyActive
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(40, parent.width - Math.round(continuousBarSurface.bottomCornerRadius * 0.9))
            y: barSlot.root.barPosition === "bottom" ? -4 : (parent.height - 2.5)
            height: 6.5
            z: -1

            property real glowPulse: 1.0
            opacity: (barSlot.root.privacyAnyActive ? glowPulse : 0.0) * 0.82
            Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

            SequentialAnimation on glowPulse {
                running: barSlot.root.privacyAnyActive
                loops: Animation.Infinite
                NumberAnimation { to: 0.65; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.00; duration: 1100; easing.type: Easing.InOutSine }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 0.08; color: continuousBarSurface.privacyColorStart }
                    GradientStop { position: 0.50; color: continuousBarSurface.privacyColorMid }
                    GradientStop { position: 0.92; color: continuousBarSurface.privacyColorEnd }
                    GradientStop { position: 1.00; color: "transparent" }
                }
            }

            layer.enabled: barSlot.root.privacyAnyActive
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.45
                blurMax: 10
            }
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

        // Hardware Privacy & Screen-Share Laser Border Line
        Item {
            id: privacyGlowBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.max(12, continuousBarSurface.bottomCornerRadius * 0.85)
            anchors.rightMargin: Math.max(12, continuousBarSurface.bottomCornerRadius * 0.85)
            y: barSlot.root.barPosition === "bottom" ? 0 : (parent.height - height)
            height: 2.0
            z: 16
            visible: barSlot.root.privacyAnyActive
            opacity: privacyGlowUnderlay.opacity * 1.15

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 0.08; color: continuousBarSurface.privacyColorStart }
                    GradientStop { position: 0.50; color: continuousBarSurface.privacyColorMid }
                    GradientStop { position: 0.92; color: continuousBarSurface.privacyColorEnd }
                    GradientStop { position: 1.00; color: "transparent" }
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
        id: compShellFallbackUpdater
        Item {
            width: 26
            height: 24
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
            width: implicitWidth
            height: implicitHeight
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
            readonly property color contentColor:
                barSlot.root.widgetContentColor("G8", barSlot.root.ink)
            readonly property real weatherCaretX:
                centerRow.x + weatherSlot.x + weatherSlot.width / 2
            readonly property real calendarCaretX:
                centerRow.x + dateSlot.x + dateSlot.width / 2
            implicitWidth: Math.round(centerRow.implicitWidth) + 18
            implicitHeight: 24

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
                height: 24
                spacing: barSlot.root.v2SectionSpacing
                Item {                                   // weather wrapper (stage-gated)
                    id: weatherSlot
                    visible: width > 0.5
                    width: g8.showWeather ? weather.implicitWidth : 0
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
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
                ClockWidget {
                    id: clock
                    root: barSlot.root
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item {                                   // date (stage-gated)
                    id: dateSlot
                    visible: width > 0.5
                    width: g8.showDate ? dateLabel.implicitWidth : 0
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
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
                            if (barSlot.root.dashboardExpanded && barSlot.root.dashboardDetail === "calendar") {
                                barSlot.root.dashboardExpanded = false
                                barSlot.root.dashboardDetail = ""
                            } else {
                                barSlot.root.calendarVisible = false
                                barSlot.root.dashboardDetail = "calendar"
                                barSlot.root.dashboardExpanded = true
                            }
                        }
                    }
                }
                Item {                                   // indicator icons wrapper (stage-gated)
                    visible: g8.showIcons || width > 0.5
                    width: g8.showIcons ? iconsRow.implicitWidth : 0
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    opacity: g8.showIcons ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Row {
                        id: iconsRow
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
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
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
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
        id: compGithubHeatmap
        GithubHeatmapWidget {
            root: barSlot.root
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
        "G8": compCenter,
        "G9": compMpris,
        "G12": compBattery,
        "G19": compGithubHeatmap, "G20": compNotes, "G21": compScreentime, "G22": compNotification
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
        height: island.islandShrinkProgress < 0.5 ? 30 : 24
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
                readonly property bool isButton: slot.gid !== "G8" && slot.occupied && slot.hasContent && island.islandShrinkProgress < 0.5
                readonly property int squareSize: 30
                readonly property bool supportsFull: ["G12", "G21"].indexOf(slot.gid) >= 0
                readonly property bool isFullOption: supportsFull && !barSlot.root.iconOnly(slot.gid)
                readonly property bool isComposite: ["G2", "G3"].indexOf(slot.gid) >= 0
                readonly property bool isPriority: ["G1", "G2"].indexOf(slot.gid) >= 0
                readonly property real buttonContentWidth: Math.round(ldr.implicitWidth)
                readonly property real buttonWidth: {
                    if (!isButton) return buttonContentWidth
                    if (isFullOption) {
                        if (slot.gid === "G21") return Math.max(squareSize * 2, 64)
                        return squareSize * 2 // twice the width of the square = 60px
                    }
                    if (isComposite) return Math.max(squareSize, buttonContentWidth + 12)
                    return squareSize // rounded square = 30px
                }
                // workspace draws a pill 4px wider than its implicitWidth on each
                // side; pad its slot symmetrically so inter-group gaps stay uniform.
                readonly property int pad: (slot.gid === "G2" && !isButton) ? barSlot.root.wsPillPad : 0
                readonly property var contentItem: ldr.item
                readonly property bool hasContent: occupied && Math.round(ldr.implicitWidth) > 0.5
                readonly property real contentLeftInset: (contentItem && contentItem.barContentLeftInset !== undefined)
                    ? contentItem.barContentLeftInset : 0
                readonly property real contentRightInset: (contentItem && contentItem.barContentRightInset !== undefined)
                    ? contentItem.barContentRightInset : 0
                readonly property bool hasVisualSurface:
                    isButton || barSlot.root.widgetHasFill(gid) || barSlot.root.widgetHasBorder(gid)
                readonly property real visualLeftEdge: isButton ? 0 : (pad
                    + (hasVisualSurface ? 0 : contentLeftInset))
                readonly property real visualRightEdge: isButton ? buttonWidth : (pad
                    + Math.round(ldr.implicitWidth)
                    - (hasVisualSurface ? 0 : contentRightInset))
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
                    : ((isButton ? buttonWidth : buttonContentWidth) + 2 * pad + (sepOn && hasContent ? sepW : 0))
                // Empty edit slots do not influence the locked narrow-layout budget.
                readonly property real budgetSlotWidth: hasContent
                    ? ((isButton ? buttonWidth : buttonContentWidth) + 2 * pad + (sepOn ? sepW : 0))
                    : 0
                readonly property bool autoShown: placeholderShown
                    || (occupied && island.groupVisibleAtStage(slot.gid, island.narrowStage))
                onBudgetSlotWidthChanged: island.scheduleNarrowUpdate()
                width: autoShown ? naturalSlotWidth : 0
                height: island.islandShrinkProgress < 0.5 ? 30 : 24
                visible: placeholderShown || (hasContent && (autoShown || width > 0.5))
                opacity: autoShown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                Rectangle {
                    id: properButtonSurface
                    anchors.centerIn: parent
                    width: isButton ? buttonWidth : buttonContentWidth
                    height: isButton ? 30 : 24
                    radius: isButton ? 10 : (height / 2)
                    clip: true
                    visible: slot.occupied && slot.hasContent && slot.autoShown
                        && (isButton || barSlot.root.widgetHasFill(slot.gid) || barSlot.root.widgetHasBorder(slot.gid))

                    color: {
                        if (barSlot.root.widgetHasFill(slot.gid)) {
                            return barSlot.root.widgetFillColor(slot.gid)
                        }
                        if (isButton) {
                            if (isPriority) {
                                return btnHover.hovered
                                    ? Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.28)
                                    : Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.14)
                            }
                            return btnHover.hovered
                                ? Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.16)
                                : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.08)
                        }
                        return "transparent"
                    }

                    border.width: (isButton || barSlot.root.widgetHasBorder(slot.gid)) ? 1 : 0
                    border.color: {
                        if (isButton) {
                            if (isPriority) {
                                return btnHover.hovered
                                    ? Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.70)
                                    : Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.32)
                            }
                            return btnHover.hovered
                                ? Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.48)
                                : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.12)
                        }
                        if (barSlot.root.widgetHasBorder(slot.gid)) {
                            return barSlot.root.widgetBorderColor(slot.gid)
                        }
                        return "transparent"
                    }

                    scale: (isButton && btnHover.hovered && !barSlot.dragging) ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Behavior on border.color { ColorAnimation { duration: 140 } }

                    HoverHandler {
                        id: btnHover
                        enabled: isButton && !barSlot.root.barUnlocked
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Loader {
                    id: ldr
                    anchors.centerIn: parent
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
        height: continuousBarSurface.height
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
        readonly property int fitRegionCount: 3

        // The base shell draws a black hole around the island when hovered.
        property bool isIslandHidden: (!island.isHovered || island.osdActive || island.notifPeekActive) && !barSlot.root.anyPopupVisible
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

        readonly property bool dictationActive: barSlot.root.dictationActive
        property real dictationProgress: dictationActive ? 1.0 : 0.0
        Behavior on dictationProgress {
            NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }

        readonly property bool chargingActive: barSlot.root.chargingPopupActive
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
            target: barSlot.root
            function onNotifPeekTickChanged() {
                island.notifPeekApp = barSlot.root.notifPeekApp
                island.notifPeekSummary = barSlot.root.notifPeekSummary
                island.notifPeekBody = barSlot.root.notifPeekBody
                island.notifPeekIcon = barSlot.root.notifPeekIcon
                island.notifPeekId = barSlot.root.notifPeekId
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
                collapseAnim.stop()
                expandAnim.restart()
            } else {
                expandAnim.stop()
                collapseAnim.restart()
            }
        }

        ParallelAnimation {
            id: expandAnim
            // Step 1: Fade out collapsed items quickly and bounce expand the bar!
            NumberAnimation {
                target: island
                property: "islandCollapsedOpacity"
                to: 0.0
                duration: 80
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: island
                property: "islandShrinkProgress"
                to: 0.0
                duration: 210
                easing.type: Easing.OutBack
                easing.overshoot: 1.12
            }
            // Step 2: Quickly fade and settle in all elements in parallel with slight lead
            SequentialAnimation {
                PauseAnimation { duration: 40 }
                NumberAnimation {
                    target: island
                    property: "islandElementsOpacity"
                    to: 1.0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
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
                    duration: 80
                    easing.type: Easing.OutQuad
                }
                // Step 2: Bounce the bar closed to collapsed width and fade in collapsed items
                NumberAnimation {
                    target: island
                    property: "islandShrinkProgress"
                    to: 1.0
                    duration: 190
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.10
                }
                SequentialAnimation {
                    PauseAnimation { duration: 70 }
                    NumberAnimation {
                        target: island
                        property: "islandCollapsedOpacity"
                        to: 1.0
                        duration: 120
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        property real leftVisibleWidth: 0
        property real rightVisibleWidth: 0
        readonly property real collapsedItemsWidth: centerRowItem.implicitWidth + 4
            + islandCollapsedItem.visibleWidth
            + (islandTimerItem.active ? (islandTimerItem.targetWidth + 4) : 0)
            + (islandCollapsedRightSlot.implicitWidth > 0 ? (islandCollapsedRightSlot.implicitWidth + 4) : 0)
        readonly property real defaultCollapsedCenterWidth: Math.max(60, collapsedItemsWidth)
        readonly property real overlayProgress: Math.max(island.osdProgress, island.notifPeekProgress, island.dictationProgress, island.chargingProgress)
        readonly property real overlayTargetWidth: {
            if (island.dictationProgress > 0) return islandDictationItem.width
            if (island.chargingProgress > 0) return islandChargingItem.width
            if (island.notifPeekProgress > 0) return islandNotifPeekItem.width
            return islandOsdItem.width
        }
        readonly property real collapsedIslandWidth: 2 * fitPadding + ((1.0 - overlayProgress) * defaultCollapsedCenterWidth + overlayProgress * overlayTargetWidth)

        readonly property real leftCardWidth: 140
        readonly property real rightCardWidth: 205
        readonly property real middleGap: 12
        readonly property real middleButtonsWidth: (row1PriorityItem && row2SecondaryItem && Math.max(row1PriorityItem.implicitWidth, row2SecondaryItem.implicitWidth) > 10)
            ? Math.max(row1PriorityItem.implicitWidth, row2SecondaryItem.implicitWidth)
            : island.estimatedMiddleWidth
        readonly property real maxMiddleWidth: Math.max(100, barSlot.width - leftCardWidth - rightCardWidth - 2 * middleGap - 32)
        readonly property real middleWidth: Math.min(maxMiddleWidth, middleButtonsWidth)

        readonly property real expandedContainerWidth: Math.min(
            barSlot.width - 24,
            leftCardWidth + middleGap + middleWidth + middleGap + rightCardWidth + 24
        )

        readonly property real fitNaturalWidth: Math.ceil(
            (1.0 - islandShrinkProgress) * expandedContainerWidth
            + islandShrinkProgress * collapsedIslandWidth
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

        // ── Center-region metrics (clean bounds) ──
        readonly property int centerGap: 12
        readonly property int rowMargin: 5
        readonly property real centerAvail: Math.max(0, barSlot.width - 2 * barSlot.shellOuterMargin - 2 * fitPadding - 2 * fitRegionGap)
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
            return row2SecondaryItem ? sideNaturalWidth(row2SecondaryItem, stage) : 0
        }
        function updateNarrowStage() {
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
            target: barSlot.root
            function onBarShellStyleChanged() {
                island.scheduleNarrowUpdate()
                expandAnim.stop()
                collapseAnim.stop()
                island.islandShrinkProgress = island.isIslandHidden ? 1.0 : 0.0
                island.islandElementsOpacity = island.isIslandHidden ? 0.0 : 1.0
                island.islandCollapsedOpacity = island.isIslandHidden ? 1.0 : 0.0
            }
            function onBarUnlockedChanged() { syncModelsTimer.restart() }
            function onV2WidgetSpacingChanged() { syncModelsTimer.restart() }
        }

        // ── region models (physical L→R order) ──
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
            var isFull = supportsFull && barSlot.root && !barSlot.root.iconOnly(gid)
            if (isFull) {
                if (gid === "G21") return 64
                return 60
            }
            return 30
        }

        function isGidActive(gid) {
            if (!gid || gid === "") return false
            var r = barSlot.root
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
            var spacing = (barSlot.root && barSlot.root.v2WidgetSpacing) ? barSlot.root.v2WidgetSpacing : 5
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

        SlotRow {
            id: centerRowItem
            height: 24
            anchors.verticalCenter: parent.verticalCenter
            x: island.fitPadding
            rmodel: centerModel
            baseCount: barSlot.centerBaseSlotCount
            maxExtraCount: barSlot.centerExtraSlotLimit
            visible: opacity > 0.001
            opacity: island.islandCollapsedOpacity * (1.0 - island.overlayProgress)
        }

        Rectangle {
            id: islandCollapsedItem
            anchors.verticalCenter: parent.verticalCenter
            x: centerRowItem.x + centerRowItem.implicitWidth + 4
            
            readonly property bool mediaActive: barSlot.mprisPanel && barSlot.mprisPanel.active
            readonly property bool hasLyrics: mediaActive && barSlot.mprisPanel.lyricsTrackId !== "" && barSlot.mprisPanel.lyricsTrackId === barSlot.mprisPanel.currentTrackId && barSlot.mprisPanel.lyricsList && barSlot.mprisPanel.lyricsList.length > 0 && barSlot.mprisPanel.currentLyricIndex >= 0
            readonly property string lyricText: hasLyrics ? barSlot.mprisPanel.lyricsList[barSlot.mprisPanel.currentLyricIndex].text : ""
            
            readonly property string windowTitle: Hyprland && Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
            
            readonly property string displayText: hasLyrics ? lyricText : (windowTitle !== "" ? windowTitle : "Desktop")
            readonly property real maxTextWidth: hasLyrics ? (barSlot.width - 120) : 350
            
            property string activeSlot: "A"
            property string currentShownText: ""
            property int lastLyricIndex: -1
            readonly property real targetTextWidth: activeSlot === "A" ? textA.implicitWidth : textB.implicitWidth
            readonly property real visibleWidth: Math.min(Math.max(targetTextWidth + 24, 60), maxTextWidth + 24)
            width: visibleWidth
            Behavior on width {
                NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
            height: 24
            radius: height / 2
            color: "transparent"
            clip: true
            opacity: island.islandCollapsedOpacity * (1.0 - island.overlayProgress)
            visible: opacity > 0.001

            property bool initialized: false

            function switchText(newText, forced) {
                if (!forced && newText === currentShownText) return

                var curIdx = (hasLyrics && barSlot.mprisPanel) ? barSlot.mprisPanel.currentLyricIndex : -1
                var movingBackwards = hasLyrics && (curIdx >= 0) && (lastLyricIndex >= 0) && (curIdx < lastLyricIndex)
                if (hasLyrics && curIdx >= 0) {
                    lastLyricIndex = curIdx
                } else {
                    lastLyricIndex = -1
                }
                currentShownText = newText

                var dir = movingBackwards ? -1 : 1
                var outY = -20 * dir
                var inStartY = 20 * dir

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
                if (islandCollapsedItem.displayText !== islandCollapsedItem.currentShownText) {
                    islandCollapsedItem.switchText(islandCollapsedItem.displayText, false)
                }
            }

            Connections {
                target: barSlot.mprisPanel ? barSlot.mprisPanel : null
                function onCurrentLyricIndexChanged() {
                    if (!islandCollapsedItem.initialized || !islandCollapsedItem.hasLyrics) return
                    var idx = barSlot.mprisPanel.currentLyricIndex
                    if (idx === islandCollapsedItem.lastLyricIndex) return
                    if (islandCollapsedItem.displayText === islandCollapsedItem.currentShownText) {
                        islandCollapsedItem.switchText(islandCollapsedItem.displayText, true)
                    }
                }
            }

            Component.onCompleted: {
                currentShownText = displayText
                textA.text = displayText
                textA.opacity = 1.0
                transA.y = 0
                textB.text = ""
                textB.opacity = 0.0
                transB.y = 20
                activeSlot = "A"
                if (hasLyrics && barSlot.mprisPanel) {
                    lastLyricIndex = barSlot.mprisPanel.currentLyricIndex
                }
                initialized = true
            }

            ParallelAnimation {
                id: animToB
                NumberAnimation {
                    id: animTransAY
                    target: transA
                    property: "y"
                    to: -20
                    duration: 420
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textA
                    property: "opacity"
                    to: 0.0
                    duration: 320
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: transB
                    property: "y"
                    to: 0
                    duration: 420
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textB
                    property: "opacity"
                    to: 1.0
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: animToA
                NumberAnimation {
                    id: animTransBY
                    target: transB
                    property: "y"
                    to: -20
                    duration: 420
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textB
                    property: "opacity"
                    to: 0.0
                    duration: 320
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: transA
                    property: "y"
                    to: 0
                    duration: 420
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: textA
                    property: "opacity"
                    to: 1.0
                    duration: 380
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: textA
                anchors.centerIn: parent
                text: ""
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
                transform: Translate { id: transB; y: 20 }
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

        Rectangle {
            id: islandTimerItem
            anchors.verticalCenter: parent.verticalCenter
            x: islandCollapsedItem.x + islandCollapsedItem.width + (islandTimerItem.width > 0 ? 4 : 0)

            readonly property bool active: barSlot.root.timerActive
            readonly property real targetWidth: active ? (timerRow.implicitWidth + 14) : 0
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

            height: 24
            radius: height / 2
            color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.14)
            border.color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.32)
            border.width: 1
            clip: true
            opacity: (active ? 1.0 : 0.0) * island.islandCollapsedOpacity * (1.0 - island.overlayProgress)
            visible: opacity > 0.001

            Row {
                id: timerRow
                anchors.centerIn: parent
                spacing: 5

                Item {
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.22)
                        border.width: 1.5
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: barSlot.root.timerPaused ? Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.45) : barSlot.accent
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap

                            PathAngleArc {
                                centerX: 7
                                centerY: 7
                                radiusX: 5.75
                                radiusY: 5.75
                                startAngle: -90
                                sweepAngle: {
                                    if (barSlot.root.timerMode === "stopwatch") {
                                        return ((barSlot.root.timerRemaining % 60) / 60.0) * 360
                                    }
                                    var init = Math.max(1, barSlot.root.timerInitial)
                                    var rem = Math.max(0, barSlot.root.timerRemaining)
                                    return (1.0 - (rem / init)) * 360
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        var sec = barSlot.root.timerRemaining
                        var h = Math.floor(sec / 3600)
                        var m = Math.floor((sec % 3600) / 60)
                        var s = sec % 60
                        function pad(n) { return n < 10 ? "0" + n : String(n) }
                        return h > 0 ? (h + ":" + pad(m) + ":" + pad(s)) : (pad(m) + ":" + pad(s))
                    }
                    font.family: "DM Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: barSlot.root.timerPaused ? Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.6) : barSlot.accent
                }
            }

            TooltipMixin {
                id: timerTip
                root: barSlot.root
                owner: islandTimerItem
                text: barSlot.root.timerLabel + " · " + (barSlot.root.timerPaused ? "Paused" : "Running") + "\nLeft-click: Pause/Resume · Right-click: Reset"
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: timerTip.show()
                onExited: timerTip.hide()
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        barSlot.root.resetTimer()
                    } else {
                        barSlot.root.toggleTimer()
                    }
                }
            }
        }

        SlotRow {
            id: islandCollapsedRightSlot
            anchors.verticalCenter: parent.verticalCenter
            
            x: islandTimerItem.x + islandTimerItem.width + (islandCollapsedRightSlot.width > 0 ? 4 : 0)
                
            visible: opacity > 0.001
            opacity: island.islandCollapsedOpacity * (1.0 - island.overlayProgress)
            
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
            opacity: island.islandCollapsedOpacity * island.osdProgress * (1.0 - island.notifPeekProgress) * (1.0 - island.dictationProgress) * (1.0 - island.chargingProgress)
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

        Rectangle {
            id: islandNotifPeekItem
            anchors.centerIn: parent

            readonly property bool hasBody: island.notifPeekBody !== ""
            readonly property real maxContentWidth: Math.min(540, barSlot.width - 60)
            readonly property real desiredTextWidth: Math.max(summaryText.implicitWidth, Math.min(390, bodyText.implicitWidth))
            readonly property real contentTargetWidth: 16 + (hasBody ? 34 : 22) + 12 + Math.max(160, desiredTextWidth) + 12 + 22 + 16
            readonly property int desiredCardHeight: 20 + Math.max(hasBody ? 34 : 22, notifTextCol.implicitHeight)

            width: Math.min(maxContentWidth, Math.max(300, contentTargetWidth))
            height: island.height
            color: "transparent"
            clip: true
            opacity: island.islandCollapsedOpacity * island.notifPeekProgress * (1.0 - island.dictationProgress) * (1.0 - island.chargingProgress)
            visible: opacity > 0.001

            transform: Translate {
                y: (1.0 - island.notifPeekProgress) * (barSlot.root.barPosition === "bottom" ? 6 : -6)
            }

            HoverHandler {
                id: peekHov
                onHoveredChanged: {
                    if (hovered) {
                        notifPeekTimer.stop()
                    } else if (island.notifPeekActive) {
                        notifPeekTimer.interval = 2200
                        notifPeekTimer.restart()
                    }
                }
            }

            // Background click invokes notification action
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    island.notifPeekActive = false
                    island.notifPeekProgress = 0.0
                    barSlot.root.invokeNotification(island.notifPeekId, island.notifPeekApp)
                }
            }

            Row {
                id: notifPeekContentRow
                anchors.centerIn: parent
                width: parent.width - 28
                spacing: 12

                // App icon / badge
                Item {
                    width: islandNotifPeekItem.hasBody ? 34 : 22
                    height: width
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        visible: island.notifPeekIcon !== "" && (island.notifPeekIcon.startsWith("file://") || island.notifPeekIcon.startsWith("/"))
                        source: (island.notifPeekIcon !== "" && (island.notifPeekIcon.startsWith("file://") || island.notifPeekIcon.startsWith("/"))) ? island.notifPeekIcon : ""
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: islandNotifPeekItem.hasBody ? 9 : (height / 2)
                        visible: !island.notifPeekIcon || (!island.notifPeekIcon.startsWith("file://") && !island.notifPeekIcon.startsWith("/"))
                        color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.16)
                        border.color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.32)
                        border.width: 1

                        IconText {
                            anchors.centerIn: parent
                            font.pixelSize: islandNotifPeekItem.hasBody ? 16 : 13
                            color: barSlot.accent
                            text: island.getNotifIcon(island.notifPeekApp, island.notifPeekIcon)
                        }
                    }
                }

                // Title + multi-line body column
                Column {
                    id: notifTextCol
                    width: parent.width - (islandNotifPeekItem.hasBody ? 34 : 22) - 12 - 22 - 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // App / Category tiny subtitle if available and body is present (First Letter Capitalized / Title Case)
                    Text {
                        visible: islandNotifPeekItem.hasBody && island.notifPeekApp !== "" && island.notifPeekApp.toLowerCase() !== island.notifPeekSummary.toLowerCase()
                        text: barSlot.formatTitleCase(island.notifPeekApp.replace(/[-_]/g, " "))
                        font.family: "DM Sans"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.3
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.55)
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    // Summary / Title (First Letter Capitalized / Title Case, full text wrap)
                    Text {
                        id: summaryText
                        text: barSlot.formatTitleCase(island.notifPeekSummary !== "" ? island.notifPeekSummary : island.notifPeekApp)
                        font.family: "DM Sans"
                        font.pixelSize: islandNotifPeekItem.hasBody ? 13 : 12
                        font.weight: Font.Bold
                        color: barSlot.root.ink
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    // Body / Description (Sentence Case, multi-line wrap)
                    Text {
                        id: bodyText
                        visible: islandNotifPeekItem.hasBody
                        text: barSlot.formatSentenceCase(island.notifPeekBody)
                        font.family: "DM Sans"
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        lineHeight: 1.15
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.82)
                        elide: Text.ElideRight
                        maximumLineCount: 3
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }

                // Close button
                Rectangle {
                    id: closeBtn
                    width: 22
                    height: 22
                    radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeHov.hovered ? Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 13
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, closeHov.hovered ? 0.95 : 0.45)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    HoverHandler { id: closeHov }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            island.notifPeekActive = false
                            island.notifPeekProgress = 0.0
                        }
                    }
                }
            }
        }

        // ── Voice Dictation Dynamic Island Item ──
        Rectangle {
            id: islandDictationItem
            anchors.centerIn: parent
            readonly property bool isTranscribing: barSlot.root.dictationState === "transcribing"
            width: isTranscribing ? 146 : 84
            Behavior on width {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            height: 24
            radius: height / 2
            color: "transparent"
            clip: false
            opacity: island.islandCollapsedOpacity * island.dictationProgress
            visible: opacity > 0.001

            transform: Translate {
                y: (1.0 - island.dictationProgress) * (barSlot.root.barPosition === "bottom" ? 6 : -6)
            }

            // ── 1. Listening State: 3-Element Theme Waveform (No background, pure theme accent) ──
            Item {
                id: listeningWaveformContainer
                anchors.centerIn: parent
                width: listeningWaveformRow.implicitWidth
                height: parent.height
                visible: opacity > 0.001
                opacity: islandDictationItem.isTranscribing ? 0.0 : 1.0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Row {
                    id: listeningWaveformRow
                    anchors.centerIn: parent
                    spacing: 4

                    // Bar 1 (Left): Rounded capsule bar (Theme Accent)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4.5
                        radius: 2.25
                        color: barSlot.accent
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            running: island.dictationActive && !islandDictationItem.isTranscribing
                            NumberAnimation { to: 14; duration: 260; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 6; duration: 240; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 11; duration: 220; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 7; duration: 280; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Bar 2 (Middle): Tallest rounded capsule bar (Theme Accent)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4.5
                        radius: 2.25
                        color: barSlot.accent
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            running: island.dictationActive && !islandDictationItem.isTranscribing
                            NumberAnimation { to: 19; duration: 220; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 9; duration: 260; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 16; duration: 240; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 8; duration: 200; easing.type: Easing.InOutQuad }
                        }
                    }

                    // Dot 3 (Right): Circular dot (Theme Accent)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        radius: 2.5
                        color: barSlot.accent
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: island.dictationActive && !islandDictationItem.isTranscribing
                            NumberAnimation { to: 1.35; duration: 280; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.80; duration: 240; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.20; duration: 220; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.90; duration: 260; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }

            // ── 2. Transcribing State: 6-Dot Progressive Spinner + "Transcribing…" Text (Image 1) ──
            Item {
                id: transcribingRow
                anchors.centerIn: parent
                width: transcribingContentRow.implicitWidth
                height: parent.height
                visible: opacity > 0.001
                opacity: islandDictationItem.isTranscribing ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }

                Row {
                    id: transcribingContentRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Rotating Progressive Dot Spinner (6 circular dots)
                    Item {
                        id: transcribingSpinner
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 1050
                            loops: Animation.Infinite
                            running: island.dictationActive && islandDictationItem.isTranscribing
                        }

                        // Dot 0 (Top: 0°)
                        Rectangle {
                            x: 9.1; y: 2.3
                            width: 1.8; height: 1.8
                            radius: 0.9
                            color: barSlot.accent
                            opacity: 0.40
                        }

                        // Dot 1 (60°)
                        Rectangle {
                            x: 14.7; y: 5.4
                            width: 2.4; height: 2.4
                            radius: 1.2
                            color: barSlot.accent
                            opacity: 0.55
                        }

                        // Dot 2 (120°)
                        Rectangle {
                            x: 14.3; y: 11.8
                            width: 3.2; height: 3.2
                            radius: 1.6
                            color: barSlot.accent
                            opacity: 0.70
                        }

                        // Dot 3 (Bottom: 180°, Largest)
                        Rectangle {
                            x: 7.6; y: 14.4
                            width: 4.8; height: 4.8
                            radius: 2.4
                            color: barSlot.accent
                            opacity: 1.00
                        }

                        // Dot 4 (240°)
                        Rectangle {
                            x: 2.1; y: 11.4
                            width: 4.0; height: 4.0
                            radius: 2.0
                            color: barSlot.accent
                            opacity: 0.85
                        }

                        // Dot 5 (300°)
                        Rectangle {
                            x: 2.7; y: 5.2
                            width: 2.8; height: 2.8
                            radius: 1.4
                            color: barSlot.accent
                            opacity: 0.60
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Transcribing…"
                        font.family: barSlot.root.barFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: barSlot.root.ink
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: barSlot.root.toggleDictation()
            }
        }

        // ── Laptop Charging Dynamic Island Pill ──
        Rectangle {
            id: islandChargingItem
            anchors.centerIn: parent
            width: 380
            height: barSlot.chargingTargetHeight
            radius: height / 2
            color: "transparent"
            clip: false
            opacity: island.islandCollapsedOpacity * island.chargingProgress * (1.0 - island.dictationProgress)
            visible: opacity > 0.001

            transform: Translate {
                y: (1.0 - island.chargingProgress) * (barSlot.root.barPosition === "bottom" ? 6 : -6)
            }

            readonly property int pct: Math.max(1, Math.min(100, barSlot.root.chargingPopupPercent))

            property real animatedPct: 0
            Behavior on animatedPct {
                NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
            }

            Connections {
                target: island
                function onChargingActiveChanged() {
                    if (island.chargingActive) {
                        islandChargingItem.animatedPct = 0;
                        chargeAnimTimer.restart();
                    }
                }
            }

            Timer {
                id: chargeAnimTimer
                interval: 40
                onTriggered: islandChargingItem.animatedPct = islandChargingItem.pct
            }

            onPctChanged: {
                if (island.chargingActive && !chargeAnimTimer.running) {
                    animatedPct = pct;
                }
            }

            // Right: Charging Status Label
            Text {
                id: chargingLabel
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "Charging"
                font.family: barSlot.root.barFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: "#22c55e"
            }

            // Left / Center: Animated Gradient Progress Bar with Head Badge
            Item {
                id: barTrackArea
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.right: chargingLabel.left
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                height: 28

                // Subtle ambient glow behind progress fill
                Rectangle {
                    anchors.left: trackGroove.left
                    anchors.verticalCenter: trackGroove.verticalCenter
                    width: progressFillItem.width
                    height: 12
                    radius: 6
                    color: "#22c55e"
                    opacity: 0.22
                }

                // Background Track Groove
                Rectangle {
                    id: trackGroove
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.16)
                    border.color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.08)
                    border.width: 1
                }

                // Progress Fill Container
                Item {
                    id: progressFillItem
                    anchors.left: trackGroove.left
                    anchors.verticalCenter: trackGroove.verticalCenter
                    height: trackGroove.height
                    width: Math.max(height, trackGroove.width * (islandChargingItem.animatedPct / 100))
                    clip: true

                    // Multi-stop horizontal gradient
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: "#059669" }
                            GradientStop { position: 0.35; color: "#10b981" }
                            GradientStop { position: 0.70; color: "#22c55e" }
                            GradientStop { position: 1.00; color: "#4ade80" }
                        }
                    }

                    // Shimmer wave traveling through the filled bar
                    Rectangle {
                        id: chargeShimmer
                        width: Math.min(65, Math.max(25, progressFillItem.width * 0.55))
                        height: parent.height
                        radius: parent.height / 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }

                        SequentialAnimation on x {
                            loops: Animation.Infinite
                            running: island.chargingActive
                            NumberAnimation {
                                from: -chargeShimmer.width
                                to: progressFillItem.width
                                duration: 1250
                                easing.type: Easing.InOutQuad
                            }
                            PauseAnimation { duration: 350 }
                        }
                    }
                }

                // Floating Capsule Badge at the progress tip (matching reference image)
                Item {
                    id: chargeHeadBadge
                    x: Math.max(0, Math.min(barTrackArea.width - width, progressFillItem.width - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(36, pctNumText.implicitWidth + 14)
                    height: 22

                    // Soft glowing aura / halo
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 10
                        height: parent.height + 8
                        radius: height / 2
                        color: Qt.rgba(0.06, 0.73, 0.51, 0.35)

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: island.chargingActive
                            NumberAnimation { to: 1.14; duration: 850; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.00; duration: 850; easing.type: Easing.InOutSine }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: island.chargingActive
                            NumberAnimation { to: 0.55; duration: 850; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.25; duration: 850; easing.type: Easing.InOutSine }
                        }
                    }

                    // Solid capsule body
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.00; color: "#22c55e" }
                            GradientStop { position: 1.00; color: "#15803d" }
                        }
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        border.width: 1

                        Text {
                            id: pctNumText
                            anchors.centerIn: parent
                            text: islandChargingItem.pct
                            font.family: barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: barSlot.root.chargingPopupActive = false
            }
        }

        ClockWidget {
            id: barClockShared
            root: barSlot.root
            visible: false
        }

        WeatherWidget {
            id: barWeatherShared
            root: barSlot.root
            visible: false
        }

        MprisArtwork {
            id: mediaCardArt
            player: (barSlot.mprisPanel && barSlot.mprisPanel.player) ? barSlot.mprisPanel.player : null
            root: barSlot.root
        }

        // ── Full-Height Left Widget: Time / Date / Weather Card ──
        Rectangle {
            id: expandedLeftTimeCard
            visible: opacity > 0.001
            opacity: island.islandElementsOpacity
            width: island.leftCardWidth
            height: island.height - 12
            y: 6
            x: 8
            radius: 14
            color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.08)
            border.width: 1
            border.color: timeCardHover.hovered
                ? Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.5)
                : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.14)
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: barClockShared.timeStr !== "" ? barClockShared.timeStr : "--:--"
                    font.family: barSlot.root.barFont
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: barSlot.root.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var d = barClockShared.now || new Date();
                        var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                        var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
                        return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()];
                    }
                    font.family: barSlot.root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.6)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    topPadding: 1

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: barWeatherShared.weatherLoaded ? barWeatherShared.weatherIcon : "sunny"
                        font.pixelSize: 11
                        color: barSlot.accent
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: barWeatherShared.weatherLoaded
                            ? (barWeatherShared.weatherTempStr + (barWeatherShared.weatherDesc ? " · " + barSlot.formatTitleCase(barWeatherShared.weatherDesc) : ""))
                            : "Weather…"
                        font.family: barSlot.root.barFont
                        font.pixelSize: 10
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.75)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        width: Math.min(implicitWidth, 110)
                    }
                }
            }

            HoverHandler { id: timeCardHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    barSlot.root.activatePopupScreen(barSlot.screen)
                    barSlot.root.dashboardExpanded = true
                    barSlot.root.dashboardDetail = "calendar"
                }
            }
        }

        // ── Full-Height Right Widget: Media Player Card ──
        Rectangle {
            id: expandedRightMediaCard
            visible: opacity > 0.001
            opacity: island.islandElementsOpacity
            width: island.rightCardWidth
            height: island.height - 12
            y: 6
            x: island.width - width - 8
            radius: 14

            readonly property var player: (barSlot.mprisPanel && barSlot.mprisPanel.player) ? barSlot.mprisPanel.player : null
            readonly property bool hasMedia: barSlot.mprisPanel && barSlot.mprisPanel.active && player !== null
            readonly property string trackTitle: hasMedia ? (player.trackTitle || "No Track") : ""
            readonly property string trackArtist: hasMedia ? (player.trackArtist || "Unknown Artist") : ""
            readonly property bool isPlaying: hasMedia && ((barSlot.mprisPanel && barSlot.mprisPanel.playing) || (player && player.playbackState === MprisPlaybackState.Playing))
            readonly property bool canPrev: hasMedia && player.canGoPrevious
            readonly property bool canNext: hasMedia && player.canGoNext

            readonly property bool hasDominantColor: {
                var c = mediaCardArt.dominantColor
                if (c && String(c) !== "#00000000" && String(c) !== "transparent") return true
                var rc = barSlot.root ? barSlot.root.mprisDominantColor : null
                if (rc && String(rc) !== "#00000000" && String(rc) !== "transparent") return true
                return false
            }
            readonly property color artColor: {
                if (mediaCardArt.dominantColor && String(mediaCardArt.dominantColor) !== "#00000000" && String(mediaCardArt.dominantColor) !== "transparent") {
                    return mediaCardArt.dominantColor
                }
                if (barSlot.root && barSlot.root.mprisDominantColor && String(barSlot.root.mprisDominantColor) !== "#00000000" && String(barSlot.root.mprisDominantColor) !== "transparent") {
                    return barSlot.root.mprisDominantColor
                }
                return barSlot.accent
            }

            color: hasMedia
                ? Qt.rgba(artColor.r, artColor.g, artColor.b, mediaCardHover.hovered ? 0.32 : 0.24)
                : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.08)
            border.width: 1
            border.color: hasMedia
                ? Qt.rgba(artColor.r, artColor.g, artColor.b, mediaCardHover.hovered ? 0.70 : 0.45)
                : (mediaCardHover.hovered ? Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.5) : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.14))
            Behavior on color { ColorAnimation { duration: 250 } }
            Behavior on border.color { ColorAnimation { duration: 250 } }

            // Media Active Layout
            Row {
                anchors.fill: parent
                anchors.margins: 7
                spacing: 8
                visible: expandedRightMediaCard.hasMedia

                // Left: Album art thumbnail
                Rectangle {
                    id: mediaArtThumb
                    width: 48
                    height: 48
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 10
                    color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(expandedRightMediaCard.artColor.r, expandedRightMediaCard.artColor.g, expandedRightMediaCard.artColor.b, 0.50)
                    clip: true

                    Image {
                        id: mediaArtThumbImg
                        anchors.fill: parent
                        source: mediaCardArt.source
                        sourceSize: Qt.size(96, 96)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready && source != ""
                    }

                    IconText {
                        anchors.centerIn: parent
                        visible: !mediaArtThumbImg.visible
                        text: "music_note"
                        font.pixelSize: 22
                        color: expandedRightMediaCard.artColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barSlot.root.mprisVisible = !barSlot.root.mprisVisible
                    }
                }

                // Right: Track title, artist, and playback controls
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - mediaArtThumb.width - parent.spacing
                    spacing: 2

                    Text {
                        text: barSlot.formatTitleCase(expandedRightMediaCard.trackTitle)
                        font.family: barSlot.root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: barSlot.root.ink
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: barSlot.formatTitleCase(expandedRightMediaCard.trackArtist)
                        font.family: barSlot.root.barFont
                        font.pixelSize: 10
                        color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.65)
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 2

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "skip_previous"
                            font.pixelSize: 15
                            color: expandedRightMediaCard.canPrev ? (expandedRightMediaCard.hasMedia ? expandedRightMediaCard.artColor : barSlot.root.ink) : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.3)
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (expandedRightMediaCard.player) expandedRightMediaCard.player.previous()
                            }
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(expandedRightMediaCard.artColor.r, expandedRightMediaCard.artColor.g, expandedRightMediaCard.artColor.b, 0.85)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)

                            IconText {
                                anchors.centerIn: parent
                                text: expandedRightMediaCard.isPlaying ? "pause" : "play_arrow"
                                font.pixelSize: 14
                                color: "#ffffff"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (expandedRightMediaCard.player) expandedRightMediaCard.player.togglePlaying()
                            }
                        }

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "skip_next"
                            font.pixelSize: 15
                            color: expandedRightMediaCard.canNext ? (expandedRightMediaCard.hasMedia ? expandedRightMediaCard.artColor : barSlot.root.ink) : Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.3)
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (expandedRightMediaCard.player) expandedRightMediaCard.player.next()
                            }
                        }
                    }
                }
            }

            // Idle Layout (When no media is playing)
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: !expandedRightMediaCard.hasMedia

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "music_note"
                    font.pixelSize: 20
                    color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.4)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No Media Playing"
                    font.family: barSlot.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Qt.rgba(barSlot.root.ink.r, barSlot.root.ink.g, barSlot.root.ink.b, 0.5)
                }
            }

            HoverHandler { id: mediaCardHover }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: Qt.PointingHandCursor
                onClicked: barSlot.root.mprisVisible = !barSlot.root.mprisVisible
            }
        }

        // ── Middle Section: Two-Row Button Hierarchy ──
        Item {
            id: expandedMiddleArea
            visible: opacity > 0.001
            opacity: island.islandElementsOpacity
            x: expandedLeftTimeCard.x + expandedLeftTimeCard.width + Math.round((island.width - expandedLeftTimeCard.width - expandedRightMediaCard.width - 16 - width) / 2)
            y: 6
            width: island.middleWidth
            height: island.height - 12
            clip: false

            // Row 1: Priority system navigation (G1 launcher, G2 workspaces, G10 quick settings, G3)
            SlotRow {
                id: row1PriorityItem
                height: 30
                anchors.horizontalCenter: parent.horizontalCenter
                y: 3
                rmodel: row1PriorityModel
                baseCount: row1PriorityModel.count
                maxExtraCount: 0
            }

            // Row 2: Secondary quick toggles (Volume, Mic, Wifi, Bluetooth, Battery, Backlight, Power, etc.)
            SlotRow {
                id: row2SecondaryItem
                height: 30
                anchors.horizontalCenter: parent.horizontalCenter
                y: 37
                rmodel: row2SecondaryModel
                baseCount: row2SecondaryModel.count
                maxExtraCount: 0
            }
        }

        // ── slot-aware panel X positions: publish per-screen anchors ──
        // find a group's slot and map its (frac·width) to window/screen X.
        function groupX(gid, frac) {
            if (gid === "G8" && island.islandShrinkProgress < 0.5) {
                return island.x + expandedLeftTimeCard.x + expandedLeftTimeCard.width * frac
            }
            if (gid === "G9" && island.islandShrinkProgress < 0.5) {
                return island.x + expandedRightMediaCard.x + expandedRightMediaCard.width * frac
            }
            var rows = [row1PriorityItem, row2SecondaryItem, centerRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                if (!row) continue
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid) {
                        var rowGlobalX = row.parent ? (row.parent === island ? row.x : row.parent.x + row.x) : row.x
                        return island.x + rowGlobalX + it.x + it.width * frac
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
                return island.x + expandedLeftTimeCard.x + expandedLeftTimeCard.width * 0.5
            }
            if (gid === "G9" && island.islandShrinkProgress < 0.5) {
                return island.x + expandedRightMediaCard.x + expandedRightMediaCard.width * 0.5
            }
            var rows = [row1PriorityItem, row2SecondaryItem, centerRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                if (!row) continue
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid && it.contentItem
                            && it.contentItem[propertyName] !== undefined) {
                        var rowGlobalX = row.parent ? (row.parent === island ? row.x : row.parent.x + row.x) : row.x
                        return island.x + rowGlobalX + it.x + it.pad
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
            void(row1PriorityItem.x); void(centerRowItem.x); void(row2SecondaryItem.x)
            void(row1PriorityItem.width); void(centerRowItem.width); void(row2SecondaryItem.width)
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
        Component.onCompleted: {
            island.syncExpandedModels()
            barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
        }

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
                    color: barSlot.root.dashboardDetail === "calendar"
                        ? Qt.rgba(barSlot.root.seal.r, barSlot.root.seal.g, barSlot.root.seal.b, 0.22)
                        : (dateTimeMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle)
                    border.width: barSlot.root.dashboardDetail === "calendar" ? 1.5 : 0
                    border.color: barSlot.root.seal
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
                            color: barSlot.root.dashboardDetail === "calendar" ? barSlot.root.seal : barSlot.root.ink
                            font.pixelSize: 13
                            opacity: barSlot.root.dashboardDetail === "calendar" ? 1.0 : 0.75
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: dateTimeTxt
                            text: expandedDashboardContainer.dateShortStr + "  •  " + expandedDashboardContainer.hourStr + ":" + expandedDashboardContainer.minStr + (expandedDashboardContainer.amPmStr !== "" ? " " + expandedDashboardContainer.amPmStr : "")
                            color: barSlot.root.dashboardDetail === "calendar" ? barSlot.root.seal : barSlot.root.ink
                            opacity: barSlot.root.dashboardDetail === "calendar" ? 1.0 : 0.85
                            font.family: barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: barSlot.root.dashboardDetail === "calendar" ? Font.Bold : Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dateTimeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (barSlot.root.dashboardDetail === "calendar") {
                                barSlot.root.dashboardDetail = ""
                            } else {
                                barSlot.root.dashboardDetail = "calendar"
                            }
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

                // Voice Dictation Button (Top Header Bar)
                Rectangle {
                    id: dictationHeaderBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: barSlot.root.dictationActive
                        ? Qt.rgba(barSlot.root.seal.r, barSlot.root.seal.g, barSlot.root.seal.b, 0.28)
                        : (dictationHeaderMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle)
                    border.width: barSlot.root.dictationActive ? 1.5 : 0
                    border.color: barSlot.accent
                    scale: dictationHeaderMa.pressed ? 0.92 : (dictationHeaderMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: barSlot.root.dictationState === "transcribing" ? "auto_awesome" : "mic"
                        color: barSlot.root.dictationActive ? barSlot.accent : barSlot.root.ink
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: dictationHeaderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barSlot.root.dashboardExpanded = false
                            barSlot.root.toggleDictation()
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

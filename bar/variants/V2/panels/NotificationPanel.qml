import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: notifPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-notifications"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    // ── quickshell-owned notification history ────────────────────────────────
    // Mako's history is capped (default max-history 5), so polling it and
    // REPLACING our list each time loses everything older. Instead we MERGE each
    // poll into our own retained history (capped 50) and persist it, so entries
    // survive both mako dropping them and a quickshell restart.
    //
    // Identity: mako ids are a per-session counter that RESETS on a mako restart,
    // so a bare id is ambiguous across restarts. We derive a session token
    // (boot-id + mako pid + proc start-time) once per poll; when it changes we
    // bump `generation`, and every entry is keyed "generation:id". Old entries
    // (gen 0) and reused new ids (gen 1) therefore never collide. The bare id is
    // used ONLY for makoctl dismiss/invoke operations.

    property var recent: []             // [{key,id,gen,appName,summary,body,firstSeen,active}]
    property var dismissed: ({})         // composite-key -> true (persisted)
    property string sessionToken: ""
    property int generation: 0
    property int seq: 0                  // monotonic first-seen counter (ordering)
    property bool cacheLoaded: false
    property string lastSaved: ""

    // pending = not dismissed → drives both the list and the badge
    readonly property var pending: {
        var out = []
        for (var i = 0; i < recent.length; i++)
            if (!dismissed[recent[i].key]) out.push(recent[i])
        return out
    }
    readonly property int unreadCount: pending.length

    // grouped = pending collapsed by appName; each group has:
    //   {appName, count, latest (the first/newest entry), items, keys}
    property var expandedGroups: ({})   // appName -> true when expanded

    readonly property var grouped: {
        var order = []
        var map = {}
        for (var i = 0; i < pending.length; i++) {
            var n = pending[i]
            var app = n.appName || "Unknown"
            if (map[app] === undefined) {
                map[app] = { appName: app, count: 0, latest: n, items: [], keys: [] }
                order.push(app)
            }
            map[app].count++
            map[app].items.push(n)
            map[app].keys.push(n.key)
        }
        var out = []
        for (var j = 0; j < order.length; j++) out.push(map[order[j]])
        return out
    }

    // scrollable list height cap, clamped to the monitor
    readonly property int listCap: Math.max(120, Math.min(480, notifPanel.height - 180))

    Binding { target: root; property: "notifCount"; value: notifPanel.unreadCount }

    // ── persistent cache (quickshell is the sole writer; write only on change) ──
    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/qs-rise-notifications.json"
    FileView {
        id: cacheFile
        path: notifPanel.cachePath
        onLoaded: {
            try {
                var j = JSON.parse(cacheFile.text())
                notifPanel.sessionToken = j.token || ""
                notifPanel.generation   = j.generation || 0
                notifPanel.seq          = j.seq || 0
                notifPanel.recent       = Array.isArray(j.recent) ? j.recent : []
                notifPanel.dismissed    = (j.dismissed && typeof j.dismissed === "object") ? j.dismissed : ({})
                notifPanel.lastSaved    = cacheFile.text()
            } catch (e) {
                notifPanel.recent = []; notifPanel.dismissed = ({})
            }
            notifPanel.cacheLoaded = true
            notifPanel.poll()
        }
        onLoadFailed: {                  // first run: no cache yet
            notifPanel.cacheLoaded = true
            notifPanel.poll()
        }
    }
    // force the initial load (don't rely on implicit auto-load) — the whole panel
    // is gated on cacheLoaded, so a missed load would mean no notifications ever
    Component.onCompleted: cacheFile.reload()

    function saveCache() {
        if (!notifPanel.cacheLoaded) return
        var state = JSON.stringify({
            token: notifPanel.sessionToken,
            generation: notifPanel.generation,
            seq: notifPanel.seq,
            recent: notifPanel.recent,
            dismissed: notifPanel.dismissed
        })
        if (state === notifPanel.lastSaved) return   // no real change → no write
        notifPanel.lastSaved = state
        cacheFile.setText(state)
    }

    // pid-guarded: with an empty pid, /proc//stat collapses to /proc/stat (a
    property bool isDnd: false

    readonly property string pollScript: "dnd=$(quickshell -p /usr/share/omarchy/shell ipc call notifications isDnd 2>/dev/null || echo \"off\"); hist=$(jq -cs '[.[] | {id: .id, app_name: .app, summary: .summary, body: .body}]' ~/.local/state/omarchy/notifications/history/*.json 2>/dev/null); [ -z \"$hist\" ] && hist='[]'; printf '{\"token\":\"omarchy\",\"dnd\":\"%s\",\"list\":[],\"history\":%s}' \"$dnd\" \"$hist\""

    Process {
        id: pollProc
        command: ["bash", "-c", notifPanel.pollScript]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var d
                try { d = JSON.parse(this.text) } catch (e) { return }
                notifPanel.isDnd = (d.dnd === "on")
                notifPanel.merge(d.token || "", d.list || [], d.history || [])
            }
        }
    }
    function poll() {
        if (!notifPanel.cacheLoaded) return
        pollProc.running = false; pollProc.running = true
    }

    // merge this poll's active(list) + history into our retained history
    function merge(token, listArr, histArr) {
        // session / generation
        if (token !== "" && token !== notifPanel.sessionToken) {
            if (notifPanel.sessionToken !== "") notifPanel.generation += 1
            notifPanel.sessionToken = token
        }
        var gen = notifPanel.generation

        // incoming this poll (current generation), by bare id; active = in `list`
        var incoming = {}
        for (var i = 0; i < listArr.length; i++) {
            var n = listArr[i]
            incoming[n.id] = { appName: n.app_name || "", summary: n.summary || "", body: n.body || "", active: true }
        }
        for (var j = 0; j < histArr.length; j++) {
            var h = histArr[j]
            if (incoming[h.id] === undefined)
                incoming[h.id] = { appName: h.app_name || "", summary: h.summary || "", body: h.body || "", active: false }
        }

        // existing entries by composite key
        var byKey = {}
        for (var k = 0; k < notifPanel.recent.length; k++) byKey[notifPanel.recent[k].key] = notifPanel.recent[k]

        // update-or-create current-gen entries; oldest id first so newest gets the largest seq
        var ids = []
        for (var idk in incoming) ids.push(parseInt(idk))
        ids.sort(function(a, b) { return a - b })
        for (var m = 0; m < ids.length; m++) {
            var id = ids[m]
            var key = gen + ":" + id
            var src = incoming[id]
            if (byKey[key] !== undefined) {
                var e = byKey[key]
                e.appName = src.appName; e.summary = src.summary; e.body = src.body
            } else {
                byKey[key] = { key: key, id: id, gen: gen,
                    appName: src.appName, summary: src.summary, body: src.body,
                    firstSeen: (++notifPanel.seq) }
            }
        }

        // recompute the (transient) active flag for ALL entries, build a NEW array
        var out = []
        for (var ek in byKey) {
            var ee = byKey[ek]
            ee.active = (ee.gen === gen && incoming[ee.id] !== undefined && incoming[ee.id].active === true)
            out.push(ee)
        }
        out.sort(function(a, b) { return b.firstSeen - a.firstSeen })
        if (out.length > 50) out = out.slice(0, 50)

        // prune dismissed keys no longer present (bounds the set)
        var present = {}
        for (var o = 0; o < out.length; o++) present[out[o].key] = true
        var nd = {}, changed = false
        for (var dk in notifPanel.dismissed) {
            if (present[dk]) nd[dk] = true; else changed = true
        }

        notifPanel.recent = out                  // reassign → bindings fire
        if (changed) notifPanel.dismissed = nd
        notifPanel.saveCache()
    }

    // ── actions ──
    Process { id: actionProc; command: ["bash", "-c", "true"] }
    function runMako(cmd) {
        actionProc.command = ["bash", "-c", cmd + " 2>/dev/null || true"]
        actionProc.running = false; actionProc.running = true
    }

    function dismissOne(entry) {
        var nd = {}
        for (var k in notifPanel.dismissed) nd[k] = true
        nd[entry.key] = true
        notifPanel.dismissed = nd                // reassign → bindings update
        notifPanel.saveCache()
    }

    function dismissGroup(group) {
        var nd = {}
        for (var k in notifPanel.dismissed) nd[k] = true
        for (var i = 0; i < group.keys.length; i++) nd[group.keys[i]] = true
        notifPanel.dismissed = nd
        // collapse the group when dismissed
        var eg = {}
        for (var ek in notifPanel.expandedGroups) eg[ek] = notifPanel.expandedGroups[ek]
        delete eg[group.appName]
        notifPanel.expandedGroups = eg
        notifPanel.saveCache()
    }

    function dismissAll() {
        var nd = {}
        for (var k in notifPanel.dismissed) nd[k] = true
        for (var i = 0; i < notifPanel.recent.length; i++) nd[notifPanel.recent[i].key] = true
        notifPanel.dismissed = nd
        notifPanel.recent = []
        notifPanel.runMako("quickshell -p /usr/share/omarchy/shell ipc call notifications clear")
        notifPanel.saveCache()
    }

    function openNotification(entry) {
        root.notifVisible = false
    }

    // ── poll cadence: fast while open, much slower when closed.
    // Opening the panel still triggers an immediate refresh below; the closed
    // cadence only keeps the badge/history roughly warm without parsing mako
    // JSON every few seconds in idle.
    Timer {
        interval: notifPanel.visible ? 1500 : 10000
        running: notifPanel.cacheLoaded; repeat: true; triggeredOnStart: true
        onTriggered: notifPanel.poll()
    }

    property real reveal: root.notifVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.notifVisible ? 160 : 120
            easing.type: root.notifVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.notifVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: { if (visible) notifPanel.poll() }

    MouseArea {
        anchors.fill: parent
        onClicked: root.notifVisible = false
    }

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
            root: notifPanel.root
            ownerActive: notifPanel.root.notifVisible
            targetX: notifPanel.root.notifCaretBarX
            reveal: notifPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.notifBarX, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - notifPanel.reveal)
            : (barBottom + gap) - 2 * (1 - notifPanel.reveal)
        opacity: notifPanel.reveal
        focus: root.notifVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.notifVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: notifPanel.unreadCount > 0
                        ? "Notifications · " + notifPanel.grouped.length
                            + (notifPanel.grouped.length < notifPanel.unreadCount
                                ? " (" + notifPanel.unreadCount + ")"
                                : "")
                        : "Notifications"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notifVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── notification list (scrollable; each individually dismissable) ──
            Flickable {
                width: parent.width
                height: Math.min(listCol.implicitHeight, notifPanel.listCap)
                contentHeight: listCol.implicitHeight
                clip: true
                interactive: listCol.implicitHeight > notifPanel.listCap
                boundsBehavior: Flickable.StopAtBounds   // no overshoot/rebound at the top/bottom edge
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: listCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: notifPanel.grouped

                        delegate: Column {
                            required property var modelData
                            width: listCol.width
                            spacing: 4

                            // ── Group header row ──
                            Rectangle {
                                id: groupRow
                                width: parent.width
                                height: groupEntryCol.implicitHeight + 16
                                radius: root.panelButtonRadius
                                color: groupMa.containsMouse ? root.fillHover : root.fillIdle
                                border.color: groupMa.containsMouse ? root.seal : root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                readonly property bool expanded: notifPanel.expandedGroups[modelData.appName] === true

                                Column {
                                    id: groupEntryCol
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    anchors.margins: 8
                                    anchors.topMargin: 8
                                    anchors.rightMargin: 26
                                    spacing: 3

                                    // App name + count chip
                                    Row {
                                        spacing: 6
                                        width: parent.width

                                        UiText {
                                            text: modelData.appName || "App"
                                            color: root.sumiHi
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.letterSpacing: 0.5
                                            elide: Text.ElideRight
                                            width: modelData.count > 1 ? parent.width - countChip.width - 6 : parent.width
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        // Count badge – only visible when grouped (>1)
                                        Rectangle {
                                            id: countChip
                                            visible: modelData.count > 1
                                            width: countLbl.implicitWidth + 10
                                            height: 14
                                            radius: 7
                                            color: root.accent
                                            anchors.verticalCenter: parent.verticalCenter
                                            UiText {
                                                id: countLbl
                                                anchors.centerIn: parent
                                                text: modelData.count
                                                color: root.paper
                                                font.family: root.barFont
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }

                                    // Latest notification summary
                                    UiText {
                                        text: modelData.latest.summary || ""
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        width: parent.width
                                        elide: Text.ElideRight
                                        visible: text !== ""
                                    }
                                    UiText {
                                        text: modelData.count > 1 && !groupRow.expanded
                                            ? "+" + (modelData.count - 1) + " more  ▾"
                                            : (modelData.latest.body || "")
                                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b,
                                            modelData.count > 1 && !groupRow.expanded ? 0.45 : 0.6)
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        width: parent.width
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        visible: modelData.count === 1 || !groupRow.expanded || (modelData.latest.body || "") !== ""
                                    }
                                }

                                // Click row → expand/collapse if multi
                                MouseArea {
                                    id: groupMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData.count <= 1) return
                                        var eg = {}
                                        for (var k in notifPanel.expandedGroups) eg[k] = notifPanel.expandedGroups[k]
                                        if (eg[modelData.appName]) delete eg[modelData.appName]
                                        else eg[modelData.appName] = true
                                        notifPanel.expandedGroups = eg
                                    }
                                }

                                // per-group dismiss ✕
                                Rectangle {
                                    anchors.top: parent.top; anchors.right: parent.right
                                    anchors.topMargin: 4; anchors.rightMargin: 4
                                    width: 18; height: 18; radius: 9
                                    color: "transparent"
                                    UiText {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: gxMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                        font.pixelSize: 10
                                    }
                                    MouseArea {
                                        id: gxMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: notifPanel.dismissGroup(modelData)
                                    }
                                }
                            }

                            // ── Expanded individual items ──
                            Column {
                                visible: groupRow.expanded && modelData.count > 1
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: modelData.items

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: listCol.width - 12
                                        anchors.right: parent.right
                                        height: iEntryCol.implicitHeight + 14
                                        radius: root.panelButtonRadius
                                        color: iMa.containsMouse ? root.fillHover : Qt.rgba(root.fillIdle.r, root.fillIdle.g, root.fillIdle.b, 0.6)
                                        border.color: iMa.containsMouse ? root.seal : root.sep
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Column {
                                            id: iEntryCol
                                            anchors { left: parent.left; right: parent.right; top: parent.top }
                                            anchors.margins: 8
                                            anchors.topMargin: 7
                                            anchors.rightMargin: 26
                                            spacing: 2

                                            UiText {
                                                text: modelData.summary || ""
                                                color: root.ink
                                                font.family: root.barFont
                                                font.pixelSize: 11
                                                width: parent.width
                                                elide: Text.ElideRight
                                                visible: text !== ""
                                            }
                                            UiText {
                                                text: modelData.body || ""
                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                                font.family: root.barFont
                                                font.pixelSize: 10
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                visible: text !== ""
                                            }
                                        }

                                        MouseArea { id: iMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }

                                        Rectangle {
                                            anchors.top: parent.top; anchors.right: parent.right
                                            anchors.topMargin: 3; anchors.rightMargin: 4
                                            width: 18; height: 18; radius: 9
                                            color: "transparent"
                                            UiText {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: ixMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
                                                font.pixelSize: 10
                                            }
                                            MouseArea {
                                                id: ixMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: notifPanel.dismissOne(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiText {
                        visible: notifPanel.grouped.length === 0
                        width: listCol.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "No notifications"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                        font.family: root.barFont
                        font.pixelSize: 11
                    }
                }
            }

            Row {
                width: parent.width
                height: 28
                spacing: 6

                // ── DND toggle ──
                Rectangle {
                    width: clearRect.visible ? (parent.width - 6) / 2 : parent.width
                    height: 28; radius: root.panelButtonRadius
                    color: dndMa.containsMouse ? root.fillHover : root.fillIdle
                    border.color: notifPanel.isDnd ? root.accent : (dndMa.containsMouse ? root.seal : root.sep)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: notifPanel.isDnd ? "DnD: On" : "DnD: Off"
                        color: notifPanel.isDnd ? root.accent : (dndMa.containsMouse ? root.seal : root.sumi)
                        font.family: root.barFont; font.pixelSize: 11
                    }
                    MouseArea {
                        id: dndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifPanel.runMako("quickshell -p /usr/share/omarchy/shell ipc call notifications toggleDnd")
                    }
                }

                // ── clear all ──
                Rectangle {
                    id: clearRect
                    width: (parent.width - 6) / 2
                    height: 28; radius: root.panelButtonRadius
                    visible: notifPanel.pending.length > 0
                    readonly property bool hovered: clearMa.containsMouse
                    color: hovered ? root.fillHover : root.fillIdle
                    border.color: hovered ? root.seal : root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    UiText {
                        anchors.centerIn: parent
                        text: "Clear all"
                        color: clearMa.containsMouse ? root.seal : root.sumi
                        font.family: root.barFont; font.pixelSize: 11
                    }
                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifPanel.dismissAll()
                    }
                }
            }
        }
    }
}

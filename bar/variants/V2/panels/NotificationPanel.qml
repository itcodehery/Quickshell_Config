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
    property bool showingHistory: false

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
    property int expandSeq: 0

    readonly property var grouped: {
        var order = []
        var map = {}
        var activeList = showingHistory ? recent : pending
        for (var i = 0; i < activeList.length; i++) {
            var n = activeList[i]
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

    readonly property string pollScript: "dnd=$(quickshell -p /usr/share/omarchy/shell ipc call notifications isDnd 2>/dev/null || echo \"off\"); list=$(jq -cs '[.[] | {id: .timestamp, notifId: (.originalId // .id // 0), app_name: .app, summary: .summary, body: .body}]' ~/.local/state/omarchy/notifications/*.json 2>/dev/null); [ -z \"$list\" ] && list='[]'; hist=$(jq -cs '[.[] | {id: .timestamp, notifId: (.originalId // .id // 0), app_name: .app, summary: .summary, body: .body}]' ~/.local/state/omarchy/notifications/history/*.json 2>/dev/null); [ -z \"$hist\" ] && hist='[]'; printf '{\"token\":\"omarchy\",\"dnd\":\"%s\",\"list\":%s,\"history\":%s}' \"$dnd\" \"$list\" \"$hist\""

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
            incoming[n.id] = { notifId: n.notifId || 0, appName: n.app_name || "", summary: n.summary || "", body: n.body || "", active: true }
        }
        for (var j = 0; j < histArr.length; j++) {
            var h = histArr[j]
            if (incoming[h.id] === undefined)
                incoming[h.id] = { notifId: h.notifId || 0, appName: h.app_name || "", summary: h.summary || "", body: h.body || "", active: false }
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
                e.notifId = src.notifId || 0; e.appName = src.appName; e.summary = src.summary; e.body = src.body
            } else {
                byKey[key] = { key: key, id: id, notifId: src.notifId || 0, gen: gen,
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

    function invokeNotification(entry) {
        if (!entry) return
        var notifId = entry.notifId || 0
        var app = entry.appName || ""
        var cmd = ""
        var nid = Number(notifId || 0)
        if (nid > 0 && nid < 100000000000) {
            cmd = "quickshell -p /usr/share/omarchy/shell ipc call notifications invoke " + nid
        } else if (app !== "") {
            cmd = "quickshell -p /usr/share/omarchy/shell ipc call notifications invokeApp \"" + app + "\""
        } else {
            cmd = "quickshell -p /usr/share/omarchy/shell ipc call notifications invoke 0"
        }
        notifPanel.runMako(cmd)
        notifPanel.dismissOne(entry)
        if (root) root.notifVisible = false
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
        notifPanel.expandSeq += 1
        notifPanel.saveCache()
    }

    function toggleGroup(appName) {
        var eg = {}
        for (var k in notifPanel.expandedGroups) eg[k] = notifPanel.expandedGroups[k]
        eg[appName] = !eg[appName]
        notifPanel.expandedGroups = eg
        notifPanel.expandSeq += 1
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
    visible: false
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
        radius: 32
        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.95)
        border.color: root.panelBorder
        border.width: 1

        x: Math.round(Math.max(6, Math.min(root.notifBarX - width/2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - notifPanel.reveal)
            : (barBottom + gap) + 6 - 2 * (1 - notifPanel.reveal)
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
            width: parent.width - 24
            x: 12
            y: 12
            spacing: 8

            Flickable {
                width: parent.width
                height: Math.min(listCol.implicitHeight, 400)
                contentWidth: width
                contentHeight: listCol.implicitHeight
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: listCol
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: notifPanel.grouped

                        delegate: Item {
                            id: delegateContainer
                            required property var modelData
                            required property int index
                            width: listCol.width
                            height: groupRow.height

                            readonly property bool isExpanded: notifPanel.expandSeq >= 0 && !!notifPanel.expandedGroups[delegateContainer.modelData.appName]

                            onModelDataChanged: {
                                groupRow.x = 0
                                groupRow.opacity = 1
                            }

                            Rectangle {
                                id: groupRow
                                width: delegateContainer.width
                                height: groupMainCol.implicitHeight + 20
                                radius: 20
                                x: 0

                                Behavior on x {
                                    enabled: !swipeMa.drag.active
                                    NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 200 }
                                }
                                Behavior on height {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                }

                                property bool isFirst: delegateContainer.index === 0
                                color: isFirst ? root.fillActive : root.fillIdle
                                border.width: 1
                                border.color: delegateContainer.isExpanded ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                Behavior on border.color { ColorAnimation { duration: 180 } }

                                MouseArea {
                                    id: swipeMa
                                    anchors.fill: parent
                                    drag.target: groupRow
                                    drag.axis: Drag.XAxis
                                    drag.minimumX: -parent.width
                                    drag.maximumX: parent.width
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        if (delegateContainer.modelData.count > 1) {
                                            notifPanel.toggleGroup(delegateContainer.modelData.appName)
                                        } else {
                                            notifPanel.invokeNotification(delegateContainer.modelData.latest)
                                        }
                                    }

                                    onReleased: {
                                        if (Math.abs(groupRow.x) > parent.width * 0.35) {
                                            groupRow.x = groupRow.x > 0 ? parent.width : -parent.width
                                            groupRow.opacity = 0
                                            dismissTimer.start()
                                        } else {
                                            groupRow.x = 0
                                        }
                                    }
                                }

                                Timer {
                                    id: dismissTimer
                                    interval: 200
                                    onTriggered: {
                                        if (notifPanel.showingHistory) {
                                            var d = {}
                                            for (var k in notifPanel.dismissed) {
                                                if (k !== delegateContainer.modelData.latest.key) d[k] = true
                                            }
                                            notifPanel.dismissed = d
                                            notifPanel.saveCache()
                                        } else {
                                            notifPanel.dismissOne(delegateContainer.modelData.latest)
                                        }
                                    }
                                }

                                Column {
                                    id: groupMainCol
                                    width: parent.width - 20
                                    anchors.centerIn: parent
                                    spacing: 8

                                    // Top Main Row
                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        // Left Icon Circle
                                        Rectangle {
                                            width: 34; height: 34; radius: 17
                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                            anchors.verticalCenter: parent.verticalCenter
                                            IconText {
                                                anchors.centerIn: parent
                                                text: delegateContainer.modelData.appName.toLowerCase().indexOf("record") !== -1 ? "radio_button_checked" : "notifications"
                                                color: root.ink
                                                font.pixelSize: 17
                                            }
                                        }

                                        // Center Text Content
                                        Column {
                                            id: groupEntryCol
                                            width: parent.width - 34 - 10 - actionRow.width - 10
                                            spacing: 2
                                            anchors.verticalCenter: parent.verticalCenter

                                            Row {
                                                spacing: 6
                                                UiText {
                                                    text: delegateContainer.modelData.appName || "Notification"
                                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.75)
                                                    font.family: root.barFont
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                // Group Count Badge (Visible when count > 1)
                                                Rectangle {
                                                    visible: delegateContainer.modelData.count > 1
                                                    height: 18
                                                    radius: 9
                                                    width: groupCountRow.implicitWidth + 12
                                                    color: delegateContainer.isExpanded ? root.seal : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                                    border.width: 1
                                                    border.color: root.seal
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    Row {
                                                        id: groupCountRow
                                                        anchors.centerIn: parent
                                                        spacing: 3

                                                        IconText {
                                                            text: "layers"
                                                            font.pixelSize: 11
                                                            color: delegateContainer.isExpanded ? "#FFFFFF" : root.seal
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }

                                                        Text {
                                                            text: delegateContainer.modelData.count
                                                            font.family: root.barFont
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                            color: delegateContainer.isExpanded ? "#FFFFFF" : root.seal
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                }

                                                UiText {
                                                    text: "• " + (delegateContainer.modelData.latest.firstSeen ? (new Date(delegateContainer.modelData.latest.firstSeen)).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : "now")
                                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                                                    font.family: root.barFont
                                                    font.pixelSize: 9
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            // Marquee Title
                                            Item {
                                                id: marqueeContainer
                                                width: parent.width
                                                height: 16
                                                clip: true

                                                UiText {
                                                    id: titleText
                                                    text: delegateContainer.modelData.latest.summary || ""
                                                    color: root.ink
                                                    font.family: root.barFont
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold

                                                    SequentialAnimation on x {
                                                        loops: Animation.Infinite
                                                        running: titleText.implicitWidth > marqueeContainer.width
                                                        PauseAnimation { duration: 1500 }
                                                        NumberAnimation {
                                                            from: 0
                                                            to: -(titleText.implicitWidth - marqueeContainer.width + 10)
                                                            duration: Math.max(1000, (titleText.implicitWidth - marqueeContainer.width) * 20)
                                                        }
                                                        PauseAnimation { duration: 1500 }
                                                        NumberAnimation {
                                                            to: 0
                                                            duration: 0
                                                        }
                                                    }
                                                }
                                            }

                                            UiText {
                                                text: delegateContainer.modelData.latest.body || ""
                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                                font.family: root.barFont
                                                font.pixelSize: 11
                                                width: parent.width
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.WordWrap
                                                visible: text !== ""
                                            }
                                        }

                                        // Action Buttons (Expand Chevron when count > 1)
                                        Row {
                                            id: actionRow
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: delegateContainer.modelData.count > 1

                                            // Expand / Collapse Chevron Button (for grouped notifications)
                                            Rectangle {
                                                width: 28; height: 28; radius: 14
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: expandMa.containsMouse
                                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.28)
                                                    : (delegateContainer.isExpanded ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08))
                                                border.width: 1
                                                border.color: delegateContainer.isExpanded ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16)
                                                Behavior on color { ColorAnimation { duration: 120 } }

                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: delegateContainer.isExpanded ? "expand_less" : "expand_more"
                                                    color: delegateContainer.isExpanded ? root.seal : root.ink
                                                    font.pixelSize: 18
                                                }

                                                MouseArea {
                                                    id: expandMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: notifPanel.toggleGroup(delegateContainer.modelData.appName)
                                                }
                                            }
                                        }
                                    }

                                    // Expanded Sub-items List (for remaining notifications in this group)
                                    Column {
                                        id: subItemsCol
                                        visible: delegateContainer.isExpanded && delegateContainer.modelData.count > 1
                                        width: parent.width
                                        spacing: 6

                                        // Divider
                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                                        }

                                        Repeater {
                                            model: (delegateContainer.isExpanded && delegateContainer.modelData.items) ? delegateContainer.modelData.items.slice(1) : []

                                            delegate: Rectangle {
                                                id: subItemBox
                                                required property var modelData
                                                required property int index
                                                width: subItemsCol.width
                                                height: subItemRow.implicitHeight + 12
                                                radius: 12
                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                                                border.width: 1
                                                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                                x: 0

                                                Behavior on x {
                                                    enabled: !subSwipeMa.drag.active
                                                    NumberAnimation { duration: 220; easing.type: Easing.OutQuart }
                                                }
                                                Behavior on opacity { NumberAnimation { duration: 180 } }

                                                MouseArea {
                                                    id: subSwipeMa
                                                    anchors.fill: parent
                                                    drag.target: subItemBox
                                                    drag.axis: Drag.XAxis
                                                    drag.minimumX: -parent.width
                                                    drag.maximumX: parent.width
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onClicked: {
                                                        notifPanel.invokeNotification(subItemBox.modelData)
                                                    }

                                                    onReleased: {
                                                        if (Math.abs(subItemBox.x) > parent.width * 0.35) {
                                                            subItemBox.x = subItemBox.x > 0 ? parent.width : -parent.width
                                                            subItemBox.opacity = 0
                                                            subDismissTimer.start()
                                                        } else {
                                                            subItemBox.x = 0
                                                        }
                                                    }
                                                }

                                                Timer {
                                                    id: subDismissTimer
                                                    interval: 180
                                                    onTriggered: {
                                                        if (notifPanel.showingHistory) {
                                                            var d = {}
                                                            for (var k in notifPanel.dismissed) {
                                                                if (k !== subItemBox.modelData.key) d[k] = true
                                                            }
                                                            notifPanel.dismissed = d
                                                            notifPanel.saveCache()
                                                        } else {
                                                            notifPanel.dismissOne(subItemBox.modelData)
                                                        }
                                                    }
                                                }

                                                Row {
                                                    id: subItemRow
                                                    width: parent.width - 16
                                                    anchors.centerIn: parent

                                                    Column {
                                                        width: parent.width
                                                        spacing: 2
                                                        anchors.verticalCenter: parent.verticalCenter

                                                        Row {
                                                            spacing: 6
                                                            UiText {
                                                                text: subItemBox.modelData.summary || ""
                                                                color: root.ink
                                                                font.family: root.barFont
                                                                font.pixelSize: 11
                                                                font.weight: Font.DemiBold
                                                                elide: Text.ElideRight
                                                                width: Math.min(implicitWidth, parent.parent.width - 60)
                                                            }
                                                            UiText {
                                                                text: subItemBox.modelData.firstSeen ? (new Date(subItemBox.modelData.firstSeen)).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : ""
                                                                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                                                                font.family: root.barFont
                                                                font.pixelSize: 9
                                                                anchors.verticalCenter: parent.verticalCenter
                                                            }
                                                        }

                                                        UiText {
                                                            text: subItemBox.modelData.body || ""
                                                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                                            font.family: root.barFont
                                                            font.pixelSize: 10
                                                            width: parent.width
                                                            elide: Text.ElideRight
                                                            maximumLineCount: 2
                                                            wrapMode: Text.WordWrap
                                                            visible: text !== ""
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Dismiss Group Button
                                        Rectangle {
                                            width: parent.width
                                            height: 26
                                            radius: 13
                                            color: groupClearMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
                                            border.width: 1
                                            border.color: groupClearMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)

                                            Row {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                IconText {
                                                    text: "clear_all"
                                                    font.pixelSize: 13
                                                    color: groupClearMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                                }
                                                Text {
                                                    text: "Dismiss group (" + delegateContainer.modelData.count + ")"
                                                    font.family: root.barFont
                                                    font.pixelSize: 10
                                                    font.weight: Font.Medium
                                                    color: groupClearMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.7)
                                                }
                                            }

                                            MouseArea {
                                                id: groupClearMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: notifPanel.dismissGroup(delegateContainer.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiText {
                        visible: notifPanel.grouped.length === 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: notifPanel.showingHistory ? "No history" : "No notifications"
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
                        font.family: root.barFont
                        font.pixelSize: 12
                        height: 40
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // ── bottom buttons (History, Clear all, DND pills) ──
            Item {
                width: parent.width
                height: 40

                // History Pill (Left)
                Rectangle {
                    id: histPill
                    width: 52
                    height: 40
                    radius: 20
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: notifPanel.showingHistory
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                        : (histMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.09))
                    border.width: 1.5
                    border.color: notifPanel.showingHistory
                        ? root.seal
                        : (histMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18))
                    scale: histMa.pressed ? 0.94 : (histMa.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "history"
                        color: notifPanel.showingHistory ? root.seal : (histMa.containsMouse ? root.seal : root.ink)
                        font.pixelSize: 18
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: histMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifPanel.showingHistory = !notifPanel.showingHistory
                    }
                }

                // Clear all Pill (Center)
                Rectangle {
                    id: clearAllPill
                    anchors.left: histPill.right
                    anchors.right: dndPill.left
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 40
                    radius: 20
                    readonly property bool hasItems: notifPanel.pending.length > 0 || notifPanel.recent.length > 0
                    color: hasItems
                        ? (clearMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.09))
                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                    border.width: 1.5
                    border.color: hasItems
                        ? (clearMa.containsMouse ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18))
                        : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    scale: clearMa.pressed ? 0.95 : (clearMa.containsMouse && hasItems ? 1.02 : 1.0)
                    opacity: hasItems ? 1.0 : 0.45
                    enabled: hasItems
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            text: "delete_sweep"
                            font.pixelSize: 18
                            color: clearAllPill.hasItems
                                ? (clearMa.containsMouse ? root.seal : root.ink)
                                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            text: "Clear all"
                            color: clearAllPill.hasItems
                                ? (clearMa.containsMouse ? root.seal : root.ink)
                                : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: clearAllPill.hasItems ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: notifPanel.dismissAll()
                    }
                }

                // DND / Alert Pill (Right)
                Rectangle {
                    id: dndPill
                    width: 52
                    height: 40
                    radius: 20
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: notifPanel.isDnd
                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                        : (dndMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.09))
                    border.width: 1.5
                    border.color: notifPanel.isDnd
                        ? root.seal
                        : (dndMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18))
                    scale: dndMa.pressed ? 0.94 : (dndMa.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: notifPanel.isDnd ? "notifications_off" : "notifications_active"
                        color: notifPanel.isDnd ? root.seal : (dndMa.containsMouse ? root.seal : root.ink)
                        font.pixelSize: 18
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        id: dndMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            notifPanel.runMako("quickshell -p /usr/share/omarchy/shell ipc call notifications toggleDnd")
                            notifPanel.isDnd = !notifPanel.isDnd
                            if (root) root.notifSilenced = notifPanel.isDnd
                        }
                    }
                }
            }
        }
    }
}

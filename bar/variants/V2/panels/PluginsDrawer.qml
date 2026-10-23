import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../modules"

PanelWindow {
    id: pluginDrawer
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-plugins-drawer"

    readonly property int barHeight: root.v2BarHeight
    readonly property int topMargin: (root.barPosition === "top" ? (barHeight + (root.barShellStyle === "ios" ? 12 : 8)) : 8)
    readonly property int rightMargin: 12

    property real reveal: root.pluginsDrawerVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.pluginsDrawerVisible ? 220 : 160
            easing.type: root.pluginsDrawerVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.pluginsDrawerVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Click outside to dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (dragState.active) {
                dragState.cancelDrag()
            } else {
                root.pluginsDrawerVisible = false
            }
        }
    }

    // ── Drag & Drop state ──
    QtObject {
        id: dragState
        property bool active: false
        property int dragIndex: -1
        property var dragItemData: null
        property real mouseStartX: 0
        property real mouseStartY: 0
        property real currentX: 0
        property real currentY: 0

        function startDrag(index, itemData, startX, startY) {
            dragIndex = index
            dragItemData = itemData
            mouseStartX = startX
            mouseStartY = startY
            currentX = startX
            currentY = startY
            active = true
        }

        function updateDrag(curX, curY) {
            currentX = curX
            currentY = curY
        }

        function cancelDrag() {
            active = false
            dragIndex = -1
            dragItemData = null
        }
    }

    ListModel {
        id: pluginsModel
    }

    Process {
        id: queryPluginsProc
        command: ["python3", "-c", "import json, os, subprocess
cache_order_path = os.path.expanduser('~/.cache/quickshell_plugins_order.json')
cache_pinned_path = os.path.expanduser('~/.cache/quickshell_pinned_plugins.json')

order = []
pinned = []
try:
    with open(cache_order_path) as f:
        order = json.load(f)
except Exception:
    order = []

try:
    with open(cache_pinned_path) as f:
        pinned = json.load(f)
except Exception:
    pinned = []

exclude = {'omarchy.bar', 'omarchy.audio', 'omarchy.bluetooth', 'omarchy.clock', 'omarchy.network', 'omarchy.weather', 'omarchy.workspaces', 'omarchy.tray', 'omarchy.power', 'omarchy.indicators', 'omarchy.keyboard-layout', 'omarchy.osd'}
icon_map = {
    'omarchy.clipboard': 'content_paste',
    'omarchy.emojis': 'sentiment_satisfied',
    'omarchy.image-picker': 'image',
    'omarchy.reminders': 'notifications',
    'stappmus.activity-monitor': 'show_chart',
    'omarchy.agents': 'smart_toy',
    'omarchy.disk-speedtest': 'speed',
    'omarchy.speedtest': 'network_check',
    'omarchy.wifiqr': 'qr_code_2',
    'shavanced.notification-center': 'notifications_active',
    'io.github.twiking.omasettings': 'settings',
    'bobbynicholas.omaland': 'dashboard',
    'omarchy.menu': 'menu',
    'co.klair.wallarchy': 'wallpaper',
    'crmne.hyprmoncfg': 'monitor',
    'omarchy.monitor': 'tv',
    'omarchy.dev-gallery': 'developer_mode',
    'omarchy.tailscale': 'vpn_lock',
    'omarchy.system-update': 'system_update'
}
try:
    res = subprocess.check_output(['omarchy', 'plugin', 'list', '--json'])
    plugins = json.loads(res)
    result = []
    order_map = {pid: i for i, pid in enumerate(order)}
    for p in plugins:
        if not p.get('enabled'): continue
        if p.get('kinds') == ['service']: continue
        pid = p['id']
        if pid in exclude: continue
        name = p.get('name', pid)
        icon = icon_map.get(pid, 'extension')
        result.append({'id': pid, 'name': name, 'icon': icon, 'kinds': p.get('kinds', ['overlay'])})
    
    # Sort by custom saved order; unranked items go to the end
    result.sort(key=lambda item: order_map.get(item['id'], 9999))
    print(json.dumps(result))
except Exception:
    print('[]')
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text.trim() || "[]")
                    pluginsModel.clear()
                    for (var i = 0; i < list.length; i++) {
                        pluginsModel.append(list[i])
                    }
                } catch(e) {}
            }
        }
    }

    Connections {
        target: root
        function onPluginsDrawerVisibleChanged() {
            if (root.pluginsDrawerVisible) {
                queryPluginsProc.running = false
                queryPluginsProc.running = true
            }
        }
        function onPluginsSettingsChanged() {
            // Re-trigger layout/pinning update when pinned list changes
            queryPluginsProc.running = false
            queryPluginsProc.running = true
        }
    }

    Component.onCompleted: {
        queryPluginsProc.running = true
    }

    // Floating Drawer Box
    Rectangle {
        id: card
        width: 324
        height: Math.min(500, contentCol.implicitHeight + 28)
        radius: root.panelRadius
        color: root.paper
        border.color: root.panelBorder
        border.width: 1

        x: parent.width - width - rightMargin
        y: root.barPosition === "bottom"
            ? (parent.height - topMargin - height) + 12 * (1 - pluginDrawer.reveal)
            : topMargin - 12 * (1 - pluginDrawer.reveal)

        opacity: pluginDrawer.reveal
        focus: root.pluginsDrawerVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (dragState.active) {
                    dragState.cancelDrag()
                } else {
                    root.pluginsDrawerVisible = false
                }
                event.accepted = true
            }
        }

        PillShadow { theme: root }

        Column {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // Header Row
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "widgets"
                        color: root.seal
                        fill: 1
                        font.pixelSize: 17
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Omarchy Plugins"
                        color: root.ink
                        font.family: root.mono
                        font.pixelSize: 13
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: countText.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: String(pluginsModel.count) + " Active"
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.sep
            }

            // Grid / List of enabled plugins
            Flickable {
                id: flickArea
                width: parent.width
                height: Math.min(390, gridView.implicitHeight)
                contentHeight: gridView.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: !dragState.active

                Grid {
                    id: gridView
                    width: parent.width
                    columns: 2
                    spacing: 8

                    Repeater {
                        id: repeater
                        model: pluginsModel
                        delegate: Rectangle {
                            id: tile
                            required property var model
                            required property int index

                            readonly property bool isPinned: root.isPluginPinned(model.id)
                            readonly property bool isBeingDragged: dragState.active && dragState.dragIndex === index

                            width: Math.floor((gridView.width - 8) / 2)
                            height: 48
                            radius: root.panelButtonRadius
                            opacity: isBeingDragged ? 0.3 : 1.0
                            color: isPinned
                                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, tileHover.containsMouse ? 0.16 : 0.08)
                                : (tileHover.containsMouse
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, root.fillHoverAlpha)
                                    : root.fillIdle)
                            border.color: isPinned
                                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, tileHover.containsMouse ? 0.9 : 0.45)
                                : (tileHover.containsMouse ? root.seal : root.sep)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            // Drag target check
                            Item {
                                anchors.fill: parent
                                MouseArea {
                                    id: tileHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: dragState.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    drag.target: null

                                    property real pressX: 0
                                    property real pressY: 0
                                    property bool draggingStarted: false

                                    onPressed: function(mouse) {
                                        pressX = mouse.x
                                        pressY = mouse.y
                                        draggingStarted = false
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (pressed && !draggingStarted) {
                                            var dx = mouse.x - pressX
                                            var dy = mouse.y - pressY
                                            if (Math.sqrt(dx * dx + dy * dy) > 6) {
                                                draggingStarted = true
                                                var pt = tile.mapToItem(card, mouse.x, mouse.y)
                                                dragState.startDrag(index, model, pt.x, pt.y)
                                            }
                                        }
                                        if (dragState.active && dragState.dragIndex === index) {
                                            var cur = tile.mapToItem(card, mouse.x, mouse.y)
                                            dragState.updateDrag(cur.x, cur.y)

                                            // Determine target tile under current pointer
                                            var gridPt = tile.mapToItem(gridView, mouse.x, mouse.y)
                                            var targetIdx = calculateTargetIndex(gridPt.x, gridPt.y)
                                            if (targetIdx >= 0 && targetIdx < pluginsModel.count && targetIdx !== dragState.dragIndex) {
                                                pluginsModel.move(dragState.dragIndex, targetIdx, 1)
                                                dragState.dragIndex = targetIdx
                                            }
                                        }
                                    }

                                    onReleased: function(mouse) {
                                        if (draggingStarted && dragState.active) {
                                            saveCurrentModelOrder()
                                            dragState.cancelDrag()
                                        } else if (!draggingStarted) {
                                            root.pluginsDrawerVisible = false
                                            Quickshell.execDetached(["omarchy-shell", "shell", "summon", model.id])
                                        }
                                        draggingStarted = false
                                    }
                                }
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 6

                                // Drag indicator grip
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "drag_indicator"
                                    color: tileHover.containsMouse ? root.sumi : Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 0.4)
                                    font.pixelSize: 14
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                // Plugin icon
                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.icon
                                    color: (tileHover.containsMouse || isPinned) ? root.seal : root.ink
                                    fill: isPinned ? 1 : 0
                                    font.pixelSize: 16
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 66
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: model.name
                                        color: root.ink
                                        font.family: root.mono
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: model.id.replace(/^omarchy\./, "")
                                        color: root.sumi
                                        font.family: root.mono
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                // Pin toggle button
                                Rectangle {
                                    id: pinBtn
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: pinMa.containsMouse
                                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2)
                                        : "transparent"
                                    border.color: isPinned ? root.seal : "transparent"
                                    border.width: isPinned ? 1 : 0

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "push_pin"
                                        font.pixelSize: 12
                                        fill: isPinned ? 1 : 0
                                        color: isPinned ? root.seal : (pinMa.containsMouse ? root.seal : root.sumi)
                                    }

                                    MouseArea {
                                        id: pinMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.togglePinPlugin(model.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Dragged ghost item overlay
        Rectangle {
            id: ghostTile
            visible: dragState.active && dragState.dragItemData !== null
            width: Math.floor((gridView.width - 8) / 2)
            height: 48
            radius: root.panelButtonRadius
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
            border.color: root.seal
            border.width: 1.5
            x: dragState.currentX - width / 2
            y: dragState.currentY - height / 2
            z: 999
            opacity: 0.92

            Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 8

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dragState.dragItemData ? dragState.dragItemData.icon : "extension"
                    color: root.seal
                    font.pixelSize: 17
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: dragState.dragItemData ? dragState.dragItemData.name : ""
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }

    function calculateTargetIndex(localGridX, localGridY) {
        var tileW = Math.floor((gridView.width - 8) / 2)
        var tileH = 48
        var col = Math.floor(localGridX / (tileW + 8))
        var row = Math.floor(localGridY / (tileH + 8))
        col = Math.max(0, Math.min(1, col))
        row = Math.max(0, row)
        var idx = row * 2 + col
        return Math.min(pluginsModel.count - 1, Math.max(0, idx))
    }

    function saveCurrentModelOrder() {
        var list = []
        for (var i = 0; i < pluginsModel.count; i++) {
            list.push(pluginsModel.get(i).id)
        }
        root.setPluginsOrderList(list)
    }
}

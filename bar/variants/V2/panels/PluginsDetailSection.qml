import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: pluginsSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property int focusedIndex: 0
    property string filterText: ""
    readonly property int filteredCount: filteredPluginsModel.count

    property bool isRemoving: false
    property string confirmingPluginId: ""
    property string confirmingPluginName: ""

    function focusSearch() {
        filterTextInput.forceActiveFocus()
    }

    ListModel {
        id: allPluginsModel
    }

    ListModel {
        id: filteredPluginsModel
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
        kinds = p.get('kinds', ['overlay'])
        result.append({
            'id': pid,
            'name': name,
            'icon': icon,
            'kinds': ', '.join(kinds),
            'firstParty': bool(p.get('firstParty', False))
        })
    
    result.sort(key=lambda item: order_map.get(item['id'], 9999))
    print(json.dumps(result))
except Exception:
    print('[]')
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text.trim() || "[]")
                    allPluginsModel.clear()
                    for (var i = 0; i < list.length; i++) {
                        allPluginsModel.append(list[i])
                    }
                    pluginsSection.applyFilter()
                } catch(e) {}
            }
        }
    }

    Process {
        id: removePluginProc
        stdout: StdioCollector {
            onStreamFinished: {
                pluginsSection.isRemoving = false
                queryPluginsProc.running = false
                queryPluginsProc.running = true
            }
        }
    }

    function applyFilter() {
        filteredPluginsModel.clear()
        var q = filterText.trim().toLowerCase()
        for (var i = 0; i < allPluginsModel.count; i++) {
            var item = allPluginsModel.get(i)
            if (!q || item.name.toLowerCase().indexOf(q) !== -1 || item.id.toLowerCase().indexOf(q) !== -1) {
                filteredPluginsModel.append(item)
            }
        }
        if (focusedIndex >= filteredPluginsModel.count) {
            focusedIndex = Math.max(0, filteredPluginsModel.count - 1)
        }
    }

    onFilterTextChanged: applyFilter()

    onFocusedIndexChanged: {
        if (pluginsListView && pluginsListView.count > 0 && focusedIndex >= 0 && focusedIndex < pluginsListView.count) {
            pluginsListView.positionViewAtIndex(focusedIndex, ListView.Contain)
        }
    }

    Connections {
        target: root
        function onPluginsSettingsChanged() {
            queryPluginsProc.running = false
            queryPluginsProc.running = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            confirmingPluginId = ""
            confirmingPluginName = ""
            queryPluginsProc.running = false
            queryPluginsProc.running = true
            pluginsSection.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        queryPluginsProc.running = true
        pluginsSection.forceActiveFocus()
    }

    function triggerLaunch(index) {
        if (index < 0 || index >= filteredPluginsModel.count) return
        var item = filteredPluginsModel.get(index)
        if (!item) return
        if (root) root.dashboardExpanded = false
        closeRequested()
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", item.id])
    }

    function togglePinCurrent(index) {
        if (index < 0 || index >= filteredPluginsModel.count) return
        var item = filteredPluginsModel.get(index)
        if (item && root && root.togglePinPlugin) {
            root.togglePinPlugin(item.id)
        }
    }

    function requestRemovePlugin(id, name) {
        if (!id) return
        confirmingPluginId = id
        confirmingPluginName = name || id
    }

    function cancelRemove() {
        confirmingPluginId = ""
        confirmingPluginName = ""
        pluginsSection.forceActiveFocus()
    }

    function executeRemove() {
        if (!confirmingPluginId) return
        var targetId = confirmingPluginId
        confirmingPluginId = ""
        confirmingPluginName = ""
        isRemoving = true

        if (root && root.isPluginPinned && root.isPluginPinned(targetId) && root.togglePinPlugin) {
            root.togglePinPlugin(targetId)
        }

        removePluginProc.command = ["bash", "-c", "omarchy plugin remove \"$1\" --yes 2>/dev/null || omarchy plugin disable \"$1\"", "_", targetId]
        removePluginProc.running = false
        removePluginProc.running = true
        pluginsSection.forceActiveFocus()
    }

    focus: visible
    Keys.onPressed: (event) => {
        if (confirmingPluginId !== "") {
            if (event.key === Qt.Key_Escape) {
                cancelRemove()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                executeRemove()
                event.accepted = true
            }
            return
        }

        if (event.key === Qt.Key_Escape) {
            if (filterText.length > 0) {
                filterText = ""
            } else {
                closeRequested()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_H || event.key === Qt.Key_L) {
            // DO NOT intercept H and L!
            // Let them propagate to HomescreenDashboardContent to cycle categories!
            event.accepted = false
            return
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
            if (filteredPluginsModel.count > 0) {
                focusedIndex = (focusedIndex + 1) % filteredPluginsModel.count
            }
            event.accepted = true
        } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
            if (filteredPluginsModel.count > 0) {
                focusedIndex = (focusedIndex - 1 + filteredPluginsModel.count) % filteredPluginsModel.count
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            triggerLaunch(focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            togglePinCurrent(focusedIndex)
            event.accepted = true
        } else if (event.key === Qt.Key_Delete) {
            if (focusedIndex >= 0 && focusedIndex < filteredPluginsModel.count) {
                var cur = filteredPluginsModel.get(focusedIndex)
                if (cur) requestRemovePlugin(cur.id, cur.name)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Slash) {
            focusSearch()
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            if (filterText.length > 0) {
                filterText = filterText.slice(0, -1)
            }
            event.accepted = true
        }
    }

    // ── TWO-COLUMN DASHBOARD LAYOUT ──
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: PLUGIN SPOTLIGHT / WIDGET PREVIEW & ACTIONS ─────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) * 0.44)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            readonly property var curItem: (pluginsSection.focusedIndex >= 0 && pluginsSection.focusedIndex < filteredPluginsModel.count)
                ? filteredPluginsModel.get(pluginsSection.focusedIndex) : null

            // Left Top Bar
            Item {
                id: leftTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26

                // Top Left: Status pill
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    radius: 13
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                    width: leftStatusRow.implicitWidth + 18

                    Row {
                        id: leftStatusRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: pluginsSection.isRemoving ? "#ea6962" : (leftColContainer.curItem ? "#a9b665" : root.sumiHi)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        IconText {
                            text: "widgets"
                            font.pixelSize: 13
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: pluginsSection.isRemoving ? "Removing..." : "Plugin Spotlight"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Top Right: Refresh & Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: refreshLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        IconText {
                            anchors.centerIn: parent
                            text: "refresh"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        MouseArea {
                            id: refreshLeftMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                queryPluginsProc.running = false
                                queryPluginsProc.running = true
                            }
                        }
                    }

                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: closeLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        MouseArea {
                            id: closeLeftMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pluginsSection.closeRequested()
                        }
                    }
                }
            }

            // Left Column Body Content
            Item {
                id: leftBodyContainer
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.05)
                    clip: true

                    // 1. Selected Plugin Spotlight Widget (Compact, No Scrolling Needed)
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        spacing: 8
                        visible: leftColContainer.curItem !== null

                        // Top: Compact Plugin Info Row (Icon + Name + Badges)
                        Row {
                            width: parent.width
                            spacing: 10

                            // Icon Avatar
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 12
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                                border.color: root.seal
                                border.width: 1.5

                                IconText {
                                    anchors.centerIn: parent
                                    text: leftColContainer.curItem ? leftColContainer.curItem.icon : "extension"
                                    font.pixelSize: 20
                                    color: root.seal
                                }
                            }

                            // Title & Badges Column
                            Column {
                                width: parent.width - 40 - 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: leftColContainer.curItem ? leftColContainer.curItem.name : ""
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: root.ink
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Row {
                                    spacing: 5
                                    width: parent.width

                                    Rectangle {
                                        height: 18
                                        radius: 9
                                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.14)
                                        width: kindBadgeText.implicitWidth + 10

                                        Text {
                                            id: kindBadgeText
                                            anchors.centerIn: parent
                                            text: leftColContainer.curItem ? leftColContainer.curItem.kinds : ""
                                            font.family: root.mono
                                            font.pixelSize: 8
                                            font.bold: true
                                            color: root.seal
                                        }
                                    }

                                    Rectangle {
                                        height: 18
                                        radius: 9
                                        readonly property bool isPinned: (leftColContainer.curItem && root && root.isPluginPinned && root.isPluginPinned(leftColContainer.curItem.id))
                                        color: isPinned
                                            ? Qt.rgba(root.color03.r, root.color03.g, root.color03.b, 0.20)
                                            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                        width: pinSpotlightText.implicitWidth + 10

                                        Text {
                                            id: pinSpotlightText
                                            anchors.centerIn: parent
                                            text: parent.isPinned ? "Pinned" : "Unpinned"
                                            font.family: root.barFont
                                            font.pixelSize: 8
                                            font.weight: Font.Medium
                                            color: parent.isPinned ? root.color03 : root.sumi
                                        }
                                    }
                                }
                            }
                        }

                        // Primary Action: Launch Plugin Button
                        Rectangle {
                            width: parent.width
                            height: 32
                            radius: 16
                            color: launchMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal
                            scale: launchMa.pressed ? 0.97 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                IconText {
                                    text: "open_in_new"
                                    font.pixelSize: 13
                                    color: root.paper
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "Launch Plugin"
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: root.paper
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: launchMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pluginsSection.triggerLaunch(pluginsSection.focusedIndex)
                            }
                        }

                        // Secondary Action Row: Pin & Remove Buttons
                        Row {
                            width: parent.width
                            spacing: 6

                            // Pin Button
                            Rectangle {
                                id: pinSpotBtn
                                width: Math.floor((parent.width - 6) / 2)
                                height: 28
                                radius: 14
                                readonly property bool isPinned: (leftColContainer.curItem && root && root.isPluginPinned && root.isPluginPinned(leftColContainer.curItem.id))
                                color: pinSpotMa.containsMouse ? root.fillHover : root.fillIdle
                                border.color: isPinned ? root.seal : root.panelBorder
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "push_pin"
                                        font.pixelSize: 11
                                        fill: pinSpotBtn.isPinned ? 1 : 0
                                        color: pinSpotBtn.isPinned ? root.seal : root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: pinSpotBtn.isPinned ? "Unpin" : "Pin"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: root.ink
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                TooltipMixin {
                                    id: pinSpotTip
                                    root: pluginsSection.root
                                    owner: pinSpotBtn
                                    text: pinSpotBtn.isPinned ? "Unpin from top header" : "Pin icon to top header (left of Screentime)"
                                }

                                MouseArea {
                                    id: pinSpotMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: pinSpotTip.show()
                                    onExited: pinSpotTip.hide()
                                    onClicked: {
                                        pinSpotTip.hide()
                                        pluginsSection.togglePinCurrent(pluginsSection.focusedIndex)
                                    }
                                }
                            }

                            // Remove / Delete Plugin Button
                            Rectangle {
                                id: removeSpotBtn
                                width: parent.width - pinSpotBtn.width - 6
                                height: 28
                                radius: 14
                                color: removeSpotMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.22) : Qt.rgba(0.92, 0.41, 0.38, 0.08)
                                border.color: removeSpotMa.containsMouse ? "#ea6962" : Qt.rgba(0.92, 0.41, 0.38, 0.3)
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        text: "delete_outline"
                                        font.pixelSize: 12
                                        color: "#ea6962"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Remove"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: "#ea6962"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    id: removeSpotMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (leftColContainer.curItem) {
                                            pluginsSection.requestRemovePlugin(leftColContainer.curItem.id, leftColContainer.curItem.name)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. Empty / No Plugin Selected State
                    Column {
                        anchors.centerIn: parent
                        visible: leftColContainer.curItem === null
                        spacing: 8
                        width: parent.width - 32

                        Rectangle {
                            width: 48
                            height: 48
                            radius: 24
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)

                            IconText {
                                anchors.centerIn: parent
                                text: "extension_off"
                                font.pixelSize: 24
                                color: root.ink
                                opacity: 0.35
                            }
                        }

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            width: parent.width

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No Plugin Selected"
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: root.ink
                                opacity: 0.8
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Select a plugin on the right to view details"
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.ink
                                opacity: 0.4
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: PLUGINS LISTVIEW & SEARCH ──────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: columnsRow.width - leftColContainer.width - columnsRow.spacing
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Right Top Bar: Title Pill & Live Search Input
            Item {
                id: rightTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 28

                Row {
                    anchors.fill: parent
                    spacing: 8

                    // Title pill & count badge
                    Rectangle {
                        height: 28
                        radius: 14
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                        width: rightTitleRow.implicitWidth + 16
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            id: rightTitleRow
                            anchors.centerIn: parent
                            spacing: 6

                            IconText {
                                text: "extension"
                                font.pixelSize: 14
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "Plugins"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: rightCountBadgeText.implicitWidth + 8
                                height: 16
                                radius: 8
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    id: rightCountBadgeText
                                    anchors.centerIn: parent
                                    text: String(filteredPluginsModel.count)
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: root.seal
                                }
                            }
                        }
                    }

                    // Live Filter Input Box
                    Rectangle {
                        width: parent.width - rightTitleRow.parent.width - 8
                        height: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.6)
                        border.color: filterTextInput.activeFocus ? root.seal : root.panelBorder
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "search"
                                font.pixelSize: 13
                                color: root.sumi
                            }

                            TextInput {
                                id: filterTextInput
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 36
                                text: pluginsSection.filterText
                                onTextChanged: pluginsSection.filterText = text
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                selectByMouse: true

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Escape) {
                                        filterTextInput.focus = false
                                        pluginsSection.forceActiveFocus()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Down) {
                                        filterTextInput.focus = false
                                        pluginsSection.forceActiveFocus()
                                        event.accepted = true
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Filter plugins (press /)..."
                                    color: root.sumi
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    visible: !filterTextInput.text
                                    opacity: 0.7
                                }
                            }

                            Rectangle {
                                visible: pluginsSection.filterText.length > 0
                                width: 16
                                height: 16
                                radius: 8
                                color: clearFilterMa.containsMouse ? root.fillHover : "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.pixelSize: 11
                                    color: root.sumi
                                }

                                MouseArea {
                                    id: clearFilterMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pluginsSection.filterText = ""
                                }
                            }
                        }
                    }
                }
            }

            // Plugins ListView
            Item {
                id: listContainer
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: rightBottomHint.top
                anchors.bottomMargin: 6
                clip: true

                // Empty state when search produces no results
                Column {
                    anchors.centerIn: parent
                    visible: filteredPluginsModel.count === 0
                    spacing: 6

                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "search_off"
                        font.pixelSize: 28
                        color: root.ink
                        opacity: 0.3
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No matching plugins found"
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.ink
                        opacity: 0.5
                    }
                }

                ListView {
                    id: pluginsListView
                    anchors.fill: parent
                    clip: true
                    spacing: 5
                    boundsBehavior: Flickable.StopAtBounds
                    model: filteredPluginsModel
                    currentIndex: pluginsSection.focusedIndex

                    delegate: Rectangle {
                        id: pluginRowRect
                        required property var model
                        required property int index

                        readonly property bool isFocused: pluginsSection.focusedIndex === index
                        readonly property bool isPinned: root && root.isPluginPinned ? root.isPluginPinned(model.id) : false

                        width: pluginsListView.width
                        height: 44
                        radius: 12

                        color: isFocused
                            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                            : (rowMa.containsMouse
                                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.08)
                                : Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.45))

                        border.color: isFocused
                            ? root.seal
                            : (isPinned ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06))
                        border.width: isFocused ? 1.5 : 1

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Icon Avatar
                            Rectangle {
                                width: 30
                                height: 30
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: pluginRowRect.isFocused || pluginRowRect.isPinned
                                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                                IconText {
                                    anchors.centerIn: parent
                                    text: model.icon
                                    font.pixelSize: 16
                                    color: pluginRowRect.isFocused || pluginRowRect.isPinned ? root.seal : root.ink
                                }
                            }

                            // Plugin Name & ID
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30 - 64 - 16
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: model.name
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: pluginRowRect.isFocused ? Font.Bold : Font.DemiBold
                                    color: root.ink
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    width: parent.width
                                    text: model.id.replace(/^omarchy\./, "") + " • " + model.kinds
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    color: root.sumi
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }

                            // Right Action Icons Row (Pin & Remove)
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                // Pin Button
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: pinRowMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20) : "transparent"

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "push_pin"
                                        font.pixelSize: 13
                                        fill: pluginRowRect.isPinned ? 1 : 0
                                        color: pluginRowRect.isPinned ? root.seal : (pinRowMa.containsMouse ? root.seal : Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 0.45))
                                    }

                                    MouseArea {
                                        id: pinRowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root && root.togglePinPlugin) {
                                                root.togglePinPlugin(pluginRowRect.model.id)
                                            }
                                        }
                                    }
                                }

                                // Delete / Remove Button
                                Rectangle {
                                    width: 26
                                    height: 26
                                    radius: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: delRowMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.20) : "transparent"

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "delete_outline"
                                        font.pixelSize: 13
                                        color: delRowMa.containsMouse ? "#ea6962" : Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 0.4)
                                    }

                                    MouseArea {
                                        id: delRowMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            pluginsSection.requestRemovePlugin(pluginRowRect.model.id, pluginRowRect.model.name)
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: rowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pluginsSection.focusedIndex = pluginRowRect.index
                            onDoubleClicked: pluginsSection.triggerLaunch(pluginRowRect.index)
                        }
                    }
                }
            }

            // Right Bottom Navigation Hint Bar
            Rectangle {
                id: rightBottomHint
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 24
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        text: "swap_vert"
                        font.pixelSize: 12
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "[j]/[k] navigate • [Enter] Launch • [p] Pin • [Del] Remove • [Esc] Close"
                        font.family: root.barFont
                        font.pixelSize: 9
                        color: root.ink
                        opacity: 0.75
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════
    // ── REMOVE / DELETE CONFIRMATION MODAL OVERLAY ───────────────────────
    // ═════════════════════════════════════════════════════════════════════
    Rectangle {
        id: confirmOverlay
        anchors.fill: parent
        radius: 20
        color: Qt.rgba(0, 0, 0, 0.65)
        visible: pluginsSection.confirmingPluginId !== ""
        z: 100

        MouseArea {
            anchors.fill: parent
            // Prevent interaction behind the modal
            onClicked: {}
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 320)
            height: 154
            radius: 16
            color: root.fillIdle
            border.color: "#ea6962"
            border.width: 1.5

            Column {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                Row {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: Qt.rgba(0.92, 0.41, 0.38, 0.20)
                        anchors.verticalCenter: parent.verticalCenter

                        IconText {
                            anchors.centerIn: parent
                            text: "delete"
                            font.pixelSize: 16
                            color: "#ea6962"
                        }
                    }

                    Text {
                        text: "Remove Plugin?"
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Remove or disable \"" + pluginsSection.confirmingPluginName + "\" from your Omarchy setup?"
                    font.family: root.barFont
                    font.pixelSize: 10
                    color: root.sumi
                }

                Item { width: 1; height: 2 }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    // Cancel
                    Rectangle {
                        width: 90
                        height: 30
                        radius: 15
                        color: cancelMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: root.panelBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.ink
                        }

                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pluginsSection.cancelRemove()
                        }
                    }

                    // Confirm Remove
                    Rectangle {
                        width: 100
                        height: 30
                        radius: 15
                        color: confirmDeleteMa.containsMouse ? Qt.lighter("#ea6962", 1.1) : "#ea6962"

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "delete"
                                font.pixelSize: 12
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Remove"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: confirmDeleteMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pluginsSection.executeRemove()
                        }
                    }
                }
            }
        }
    }
}

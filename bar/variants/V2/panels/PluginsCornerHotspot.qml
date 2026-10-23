import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../modules"

PanelWindow {
    id: cornerHotspot
    required property var root
    required property var targetScreen

    screen: targetScreen

    color: "transparent"
    anchors {
        top: root.barPosition === "top"
        bottom: root.barPosition === "bottom"
        right: true
    }
    // Expand window width when pinned items exist
    implicitWidth: hotspotRow.width + 16
    implicitHeight: root.v2BarHeight + (root.barShellStyle === "ios" ? 8 : 2)

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-plugins-corner"

    ListModel {
        id: pinnedModel
    }

    Process {
        id: queryPinnedProc
        command: ["python3", "-c", "import json, os, subprocess
cache_path = os.path.expanduser('~/.cache/quickshell_pinned_plugins.json')
pinned = []
try:
    with open(cache_path) as f:
        pinned = json.load(f)
except Exception:
    pinned = []

if not pinned:
    print('[]')
    exit(0)

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
    p_map = {p['id']: p for p in plugins if p.get('enabled') and p.get('kinds') != ['service'] and p['id'] not in exclude}
    result = []
    for pid in pinned:
        if pid in p_map:
            p = p_map[pid]
            result.append({'id': pid, 'name': p.get('name', pid), 'icon': icon_map.get(pid, 'extension')})
    print(json.dumps(result))
except Exception:
    print('[]')
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text.trim() || "[]")
                    pinnedModel.clear()
                    for (var i = 0; i < list.length; i++) {
                        pinnedModel.append(list[i])
                    }
                } catch(e) {}
            }
        }
    }

    Connections {
        target: root
        function onPluginsSettingsChanged() {
            queryPinnedProc.running = false
            queryPinnedProc.running = true
        }
    }

    Component.onCompleted: {
        queryPinnedProc.running = true
    }

    Row {
        id: hotspotRow
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        // Pinned plugin icon buttons
        Repeater {
            model: pinnedModel
            delegate: Rectangle {
                id: pinnedBtn
                width: 28
                height: 28
                radius: 14
                color: pinnedMa.containsMouse
                    ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25)
                    : Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.6)
                border.color: pinnedMa.containsMouse ? root.seal : root.panelBorder
                border.width: 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                IconText {
                    anchors.centerIn: parent
                    text: model.icon
                    font.pixelSize: 15
                    color: pinnedMa.containsMouse ? root.seal : root.ink
                }

                TooltipMixin {
                    id: pinTip
                    root: cornerHotspot.root
                    owner: pinnedBtn
                    text: model.name
                }

                MouseArea {
                    id: pinnedMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: pinTip.show()
                    onExited: pinTip.hide()
                    onClicked: {
                        pinTip.hide()
                        Quickshell.execDetached(["omarchy-shell", "shell", "summon", model.id])
                    }
                }
            }
        }

        // Hotspot Drawer Toggle Pill (Rightmost)
        Rectangle {
            id: triggerBtn
            width: 28
            height: 28
            radius: 14
            color: ma.containsMouse || root.pluginsDrawerVisible
                ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)
                : Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.45)
            border.color: (ma.containsMouse || root.pluginsDrawerVisible) ? root.seal : root.panelBorder
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            // Rotates slightly on hover
            rotation: ma.containsMouse ? 15 : 0
            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

            IconText {
                anchors.centerIn: parent
                text: "widgets"
                font.pixelSize: 15
                fill: (ma.containsMouse || root.pluginsDrawerVisible) ? 1 : 0
                color: (ma.containsMouse || root.pluginsDrawerVisible) ? root.seal : root.ink
                Behavior on fill { NumberAnimation { duration: 150 } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            TooltipMixin {
                id: triggerTip
                root: cornerHotspot.root
                owner: triggerBtn
                text: "Omarchy Plugins"
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: triggerTip.show()
                onExited: triggerTip.hide()
                onClicked: {
                    triggerTip.hide()
                    hoverOpenTimer.stop()
                    root.togglePluginsDrawer()
                }
            }

            Timer {
                id: hoverOpenTimer
                interval: 220
                repeat: false
                onTriggered: {
                    if (ma.containsMouse && !root.pluginsDrawerVisible) {
                        triggerTip.hide()
                        root.togglePluginsDrawer()
                    }
                }
            }
        }
    }
}

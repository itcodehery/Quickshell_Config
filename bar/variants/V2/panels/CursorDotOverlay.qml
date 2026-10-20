import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: overlay
    required property var root

    property real cursorX: 0
    property real cursorY: 0
    readonly property int notifCount: root.notifCount
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/cursor-dot/tracker.py"

    visible: notifCount > 0 || rippleCenter.opacity > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "cursor-ripple"
    mask: Region {} // 100% click-through pass-through

    Process {
        id: trackerProc
        command: ["python3", overlay.scriptPath]
        running: overlay.visible
        stdout: SplitParser {
            onRead: function(data) {
                var line = String(data || "").trim()
                if (!line) return
                var parts = line.split(" ")
                if (parts.length >= 2) {
                    overlay.cursorX = parseFloat(parts[0]) || 0
                    overlay.cursorY = parseFloat(parts[1]) || 0
                }
            }
        }
    }

    Item {
        id: rippleCenter
        // Centered directly on cursor position
        x: overlay.cursorX
        y: overlay.cursorY

        visible: overlay.notifCount > 0 || opacity > 0.001

        opacity: overlay.notifCount > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        // Staggered concentric water ripples
        Repeater {
            model: 3

            Item {
                id: rippleWave
                anchors.centerIn: parent
                property int delay: index * 550
                property real animProgress: 0

                Rectangle {
                    anchors.centerIn: parent
                    width: 70
                    height: 70
                    radius: 35
                    color: "transparent"
                    border.color: "#7fbbb3"
                    border.width: 1.5

                    scale: 0.1 + (rippleWave.animProgress * 1.5)
                    opacity: Math.max(0, (1.0 - rippleWave.animProgress) * 0.75)
                }

                SequentialAnimation {
                    id: waveAnim
                    running: overlay.visible
                    loops: Animation.Infinite

                    PauseAnimation { duration: rippleWave.delay }

                    NumberAnimation {
                        target: rippleWave
                        property: "animProgress"
                        from: 0.0
                        to: 1.0
                        duration: 1650
                        easing.type: Easing.OutCubic
                    }

                    // Reset pause before looping
                    PauseAnimation { duration: Math.max(0, 1650 - rippleWave.delay) }
                }
            }
        }
    }
}

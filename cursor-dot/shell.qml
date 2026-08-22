import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

ShellRoot {
    id: root

    property real cursorX: 0
    property real cursorY: 0
    property int notifCount: 0
    property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/cursor-dot/tracker.py"

    Process {
        id: trackerProc
        command: ["python3", root.scriptPath]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var line = String(data || "").trim()
                if (!line) return
                var parts = line.split(" ")
                if (parts.length >= 3) {
                    var x = parseFloat(parts[0]) || 0
                    var y = parseFloat(parts[1]) || 0
                    var count = parseInt(parts[2]) || 0

                    root.cursorX = x
                    root.cursorY = y
                    root.notifCount = count
                }
            }
        }
    }

    PanelWindow {
        id: overlay
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "cursor-ripple"
        mask: Region {} // 100% click-through pass-through

        Item {
            id: rippleCenter
            // Centered directly on cursor position
            x: root.cursorX
            y: root.cursorY

            visible: root.notifCount > 0

            opacity: root.notifCount > 0 ? 1 : 0
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
                        running: root.notifCount > 0
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
}

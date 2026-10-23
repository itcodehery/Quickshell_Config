import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: overlay
    property var root: null

    property real cursorX: 0
    property real cursorY: 0
    readonly property int notifCount: root ? (root.notifCount || 0) : 0
    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/cursor-dot/tracker.py"
    readonly property string cursorIconPath: Quickshell.env("HOME") + "/.config/quickshell/cursor-dot/cursor.svg"

    // Shake to find state
    property bool isShaking: false
    property real targetScale: 1.0
    property real currentScale: 1.0
    property real cursorOpacity: (currentScale > 1.05 || isShaking) ? 1.0 : 0.0
    property real baseCursorSize: 32

    visible: notifCount > 0 || rippleCenter.opacity > 0.001 || isShaking || currentScale > 1.01 || cursorOpacity > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "cursor-ripple"
    mask: Region {} // 100% click-through pass-through

    Behavior on currentScale {
        NumberAnimation {
            duration: overlay.isShaking ? 140 : 320
            easing.type: overlay.isShaking ? Easing.OutBack : Easing.OutCubic
        }
    }

    Behavior on cursorOpacity {
        NumberAnimation {
            duration: overlay.isShaking ? 100 : 250
            easing.type: Easing.OutCubic
        }
    }

    Process {
        id: trackerProc
        command: ["python3", overlay.scriptPath]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                var line = String(data || "").trim()
                if (!line) return
                var parts = line.split(" ")
                if (parts.length >= 2) {
                    overlay.cursorX = parseFloat(parts[0]) || 0
                    overlay.cursorY = parseFloat(parts[1]) || 0
                }
                if (parts.length >= 4) {
                    overlay.isShaking = parts[3] === "1"
                }
                if (parts.length >= 5) {
                    overlay.targetScale = parseFloat(parts[4]) || 1.0
                } else if (!overlay.isShaking) {
                    overlay.targetScale = 1.0
                }
                overlay.currentScale = overlay.targetScale
            }
        }
        onExited: function(exitCode, exitStatus) {
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: trackerProc.running = true
    }

    // Shake to Find: macOS-style scaled up cursor anchored at the hotspot tip
    Item {
        id: cursorAnchor
        x: overlay.cursorX
        y: overlay.cursorY
        visible: overlay.currentScale > 1.01 || overlay.cursorOpacity > 0.001

        Item {
            id: cursorTransform
            transformOrigin: Item.TopLeft
            scale: overlay.currentScale
            opacity: overlay.cursorOpacity

            Image {
                id: cursorImg
                x: -overlay.baseCursorSize * 0.21
                y: -overlay.baseCursorSize * 0.07
                width: overlay.baseCursorSize
                height: overlay.baseCursorSize
                source: overlay.cursorIconPath
                sourceSize.width: 128
                sourceSize.height: 128
                smooth: true
                mipmap: true
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
                    running: overlay.visible && overlay.notifCount > 0
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

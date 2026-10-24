import QtQuick
import Quickshell
import Quickshell.Wayland

// Small pill in the top-right corner of the screen showing one dot per active
// hardware privacy source (microphone, camera, screen share / recording).
PanelWindow {
    id: privacyWin
    required property var root
    required property var targetScreen

    screen: targetScreen

    readonly property bool anyActive: root.privacyAnyActive
    readonly property var dots: {
        var list = []
        if (root.privacyMic) list.push({ key: "mic", color: "#F59E0B" })
        if (root.privacyCam) list.push({ key: "cam", color: "#10B981" })
        if (root.privacyScreen) list.push({ key: "screen", color: root.screenRecording ? "#EF4444" : "#3B82F6" })
        return list
    }

    readonly property real pillHeight: Math.max(14, Math.round(root.v2BarHeight * 0.6))

    color: "transparent"
    visible: anyActive || pill.opacity > 0.01
    anchors {
        top: true
        right: true
    }
    margins {
        top: Math.max(2, Math.round((root.v2BarHeight - pillHeight) / 2))
        right: 14
    }
    implicitWidth: pill.width
    implicitHeight: pillHeight

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-privacy-dots"

    // Purely informational: let every click fall through to whatever is below
    mask: Region {}

    Rectangle {
        id: pill
        height: privacyWin.pillHeight
        width: dotRow.implicitWidth + 18
        radius: height / 2
        color: privacyWin.root.barBg
        border.width: 1
        border.color: privacyWin.root.islandBorder
        opacity: privacyWin.anyActive ? 1 : 0
        scale: privacyWin.anyActive ? 1 : 0.8
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            id: dotRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: privacyWin.dots
                delegate: Rectangle {
                    id: dot
                    required property var modelData
                    width: 8
                    height: 8
                    radius: 4
                    color: modelData.color

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.5; duration: 1000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }
}

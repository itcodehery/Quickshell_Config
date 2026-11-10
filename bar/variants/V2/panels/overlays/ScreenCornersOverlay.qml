import QtQuick
import QtQuick.Shapes
import ".."
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    required property var root
    required property var targetScreen

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "screen-corners"
    mask: Region {}

    readonly property int cornerRadius: 16
    readonly property color cornerColor: "#000000"

    // Standard smooth corner rounding
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // Top-Left Corner
        ShapePath {
            fillColor: win.cornerColor
            strokeColor: "transparent"
            startX: 0; startY: 0
            PathLine { x: win.cornerRadius; y: 0 }
            PathArc {
                x: 0
                y: win.cornerRadius
                radiusX: win.cornerRadius
                radiusY: win.cornerRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }

        // Top-Right Corner
        ShapePath {
            fillColor: win.cornerColor
            strokeColor: "transparent"
            startX: win.width; startY: 0
            PathLine { x: win.width - win.cornerRadius; y: 0 }
            PathArc {
                x: win.width
                y: win.cornerRadius
                radiusX: win.cornerRadius
                radiusY: win.cornerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: win.width; y: 0 }
        }

        // Bottom-Left Corner
        ShapePath {
            fillColor: win.cornerColor
            strokeColor: "transparent"
            startX: 0; startY: win.height
            PathLine { x: 0; y: win.height - win.cornerRadius }
            PathArc {
                x: win.cornerRadius
                y: win.height
                radiusX: win.cornerRadius
                radiusY: win.cornerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: 0; y: win.height }
        }

        // Bottom-Right Corner
        ShapePath {
            fillColor: win.cornerColor
            strokeColor: "transparent"
            startX: win.width; startY: win.height
            PathLine { x: win.width - win.cornerRadius; y: win.height }
            PathArc {
                x: win.width
                y: win.height - win.cornerRadius
                radiusX: win.cornerRadius
                radiusY: win.cornerRadius
                direction: PathArc.Counterclockwise
            }
            PathLine { x: win.width; y: win.height }
        }
    }
}

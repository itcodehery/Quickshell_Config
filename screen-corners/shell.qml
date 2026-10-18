import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

ShellRoot {
    id: root

    property int cornerRadius: 10
    property color cornerColor: "#000000"

    Variants {
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: cornerWindow
                required property var modelData
                screen: modelData

                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "screen-corners"
                mask: Region {} // 100% click-through, all input events pass to windows beneath

                // ── Top-Left Corner ──
                Shape {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: root.cornerRadius
                    height: root.cornerRadius
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.cornerColor
                        strokeColor: "transparent"
                        strokeWidth: 0
                        startX: 0
                        startY: 0
                        PathLine { x: root.cornerRadius; y: 0 }
                        PathArc {
                            x: 0
                            y: root.cornerRadius
                            radiusX: root.cornerRadius
                            radiusY: root.cornerRadius
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: 0; y: 0 }
                    }
                }

                // ── Top-Right Corner ──
                Shape {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: root.cornerRadius
                    height: root.cornerRadius
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.cornerColor
                        strokeColor: "transparent"
                        strokeWidth: 0
                        startX: root.cornerRadius
                        startY: 0
                        PathLine { x: 0; y: 0 }
                        PathArc {
                            x: root.cornerRadius
                            y: root.cornerRadius
                            radiusX: root.cornerRadius
                            radiusY: root.cornerRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: root.cornerRadius; y: 0 }
                    }
                }

                // ── Bottom-Left Corner ──
                Shape {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: root.cornerRadius
                    height: root.cornerRadius
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.cornerColor
                        strokeColor: "transparent"
                        strokeWidth: 0
                        startX: 0
                        startY: root.cornerRadius
                        PathLine { x: root.cornerRadius; y: root.cornerRadius }
                        PathArc {
                            x: 0
                            y: 0
                            radiusX: root.cornerRadius
                            radiusY: root.cornerRadius
                            direction: PathArc.Clockwise
                        }
                        PathLine { x: 0; y: root.cornerRadius }
                    }
                }

                // ── Bottom-Right Corner ──
                Shape {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: root.cornerRadius
                    height: root.cornerRadius
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.cornerColor
                        strokeColor: "transparent"
                        strokeWidth: 0
                        startX: root.cornerRadius
                        startY: root.cornerRadius
                        PathLine { x: 0; y: root.cornerRadius }
                        PathArc {
                            x: root.cornerRadius
                            y: 0
                            radiusX: root.cornerRadius
                            radiusY: root.cornerRadius
                            direction: PathArc.Counterclockwise
                        }
                        PathLine { x: root.cornerRadius; y: root.cornerRadius }
                    }
                }
            }
        }
    }
}

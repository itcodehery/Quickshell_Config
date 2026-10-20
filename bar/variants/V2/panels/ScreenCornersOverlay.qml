import QtQuick
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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "screen-corners"
    mask: Region {}

    readonly property int cornerRadius: 16
    readonly property color cornerColor: root.paper

    // Top-Left Corner
    Canvas {
        id: tl
        width: win.cornerRadius
        height: win.cornerRadius
        anchors.top: parent.top
        anchors.left: parent.left
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = win.cornerColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.arc(width, height, width, -Math.PI / 2, Math.PI, true)
            ctx.closePath()
            ctx.fill()
        }
        Connections {
            target: win
            function onCornerColorChanged() { tl.requestPaint() }
        }
    }

    // Top-Right Corner
    Canvas {
        id: tr
        width: win.cornerRadius
        height: win.cornerRadius
        anchors.top: parent.top
        anchors.right: parent.right
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = win.cornerColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width, height)
            ctx.arc(0, height, width, 0, -Math.PI / 2, true)
            ctx.closePath()
            ctx.fill()
        }
        Connections {
            target: win
            function onCornerColorChanged() { tr.requestPaint() }
        }
    }

    // Bottom-Left Corner
    Canvas {
        id: bl
        width: win.cornerRadius
        height: win.cornerRadius
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = win.cornerColor
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(0, height)
            ctx.lineTo(width, height)
            ctx.arc(width, 0, width, Math.PI / 2, Math.PI, false)
            ctx.closePath()
            ctx.fill()
        }
        Connections {
            target: win
            function onCornerColorChanged() { bl.requestPaint() }
        }
    }

    // Bottom-Right Corner
    Canvas {
        id: br
        width: win.cornerRadius
        height: win.cornerRadius
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = win.cornerColor
            ctx.beginPath()
            ctx.moveTo(width, 0)
            ctx.lineTo(width, height)
            ctx.lineTo(0, height)
            ctx.arc(0, 0, width, Math.PI / 2, 0, true)
            ctx.closePath()
            ctx.fill()
        }
        Connections {
            target: win
            function onCornerColorChanged() { br.requestPaint() }
        }
    }
}

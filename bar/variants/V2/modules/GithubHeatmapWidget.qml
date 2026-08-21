import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    property string username: "itcodehery"

    implicitWidth: root.modGithubHeatmap ? ico.implicitWidth + 16 : 0
    implicitHeight: 28
    clip: true
    visible: root.modGithubHeatmap

    Text {
        id: ico
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF09B) // Github icon
        color: root.widgetContentColor("G19", root.ink)
        font.family: root.mono
        font.pixelSize: 14
    }

    TooltipMixin { 
        id: tip
        root: rootMod.root
        owner: rootMod
        text: "GitHub Contributions" 
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            root.githubHeatmapVisible = !root.githubHeatmapVisible
        }
    }
}

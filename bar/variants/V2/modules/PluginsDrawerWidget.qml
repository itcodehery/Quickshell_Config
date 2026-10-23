import QtQuick
import "../modules"

Item {
    id: rootMod
    required property var root

    implicitWidth: root.v2ActionIconCellWidth
    implicitHeight: 28

    readonly property bool active: root.pluginsDrawerVisible
    readonly property string tooltipText: "Omarchy Plugins"
    readonly property color contentColor: root.widgetContentColor("G10", root.widgetIconColor)

    HoverHandler {
        id: hoverH
        onHoveredChanged: {
            if (hovered && !root.pluginsDrawerVisible) {
                hoverTimer.restart()
            } else if (!hovered) {
                hoverTimer.stop()
            }
        }
    }

    Timer {
        id: hoverTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (hoverH.hovered && !root.pluginsDrawerVisible) {
                root.togglePluginsDrawer()
            }
        }
    }

    IconText {
        anchors.centerIn: parent
        text: "widgets"
        font.pixelSize: 15
        fill: (rootMod.active || hoverH.hovered) ? 1 : 0
        color: (rootMod.active || hoverH.hovered)
            ? (root.widgetHasFill("G10") ? rootMod.contentColor : root.seal)
            : rootMod.contentColor
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on fill { NumberAnimation { duration: 150 } }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: tip.hide()
        onClicked: {
            tip.hide()
            hoverTimer.stop()
            root.togglePluginsDrawer()
        }
    }
}

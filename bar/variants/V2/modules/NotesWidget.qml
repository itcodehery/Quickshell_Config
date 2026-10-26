import QtQuick
import Quickshell
import "../panels"
import ".."

Item {
    id: notesWidget
    required property var root

    implicitWidth: 32
    implicitHeight: root.v2BarHeight

    property bool isNotesOpen: root.dashboardExpanded && root.dashboardDetail === "notes"

    Rectangle {
        id: notesBtn
        width: 32
        height: root.v2BarHeight - 6
        anchors.centerIn: parent
        radius: root.panelButtonRadius
        
        color: notesMa.containsMouse || notesWidget.isNotesOpen ? root.fillHover : "transparent"
        border.color: notesMa.containsMouse || notesWidget.isNotesOpen ? root.sep : "transparent"
        border.width: 0

        IconText {
            anchors.centerIn: parent
            text: "\uE150" // Edit / Note icon in Material Symbols
            color: notesWidget.isNotesOpen ? root.accent : root.ink
            font.pixelSize: 15
        }

        MouseArea {
            id: notesMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.dashboardExpanded && root.dashboardDetail === "notes") {
                    root.dashboardExpanded = false
                } else {
                    root.dashboardDetail = "notes"
                    root.dashboardExpanded = true
                }
            }
        }
    }
}

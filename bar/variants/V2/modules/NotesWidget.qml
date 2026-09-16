import QtQuick
import Quickshell
import "../panels"
import ".."

Item {
    id: notesWidget
    required property var root

    implicitWidth: 32
    implicitHeight: root.v2BarHeight

    property bool isNotesPanelOpen: notesOverlay.reveal > 0.001

    Rectangle {
        id: notesBtn
        width: 32
        height: root.v2BarHeight - 6
        anchors.centerIn: parent
        radius: root.panelButtonRadius
        
        color: notesMa.containsMouse || notesWidget.isNotesPanelOpen ? root.fillHover : "transparent"
        border.color: notesMa.containsMouse || notesWidget.isNotesPanelOpen ? root.sep : "transparent"
        border.width: 1

        IconText {
            anchors.centerIn: parent
            text: "\uE150" // Edit / Note icon in Material Symbols
            color: notesWidget.isNotesPanelOpen ? root.accent : root.ink
            font.pixelSize: 15
        }

        MouseArea {
            id: notesMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (notesOverlay.notesOpen) {
                    notesOverlay.notesOpen = false
                } else {
                    notesOverlay.targetX = notesBtn.mapToItem(null, notesBtn.width / 2, 0).x
                    notesOverlay.notesOpen = true
                }
            }
        }
    }

    NotesPanel {
        id: notesOverlay
        root: notesWidget.root
        screen: notesWidget.root.activePopupScreen
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    color: "transparent"
    anchors { bottom: true; left: false; right: false }
    height: 100
    width: 200
    
    Rectangle {
        anchors.fill: parent
        color: "red"
    }
}

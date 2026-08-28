import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../modules"

PanelWindow {
    id: powerNotch
    required property var root
    required property var targetScreen

    screen: targetScreen
    color: "transparent"
    
    anchors { top: true; right: true; left: false; bottom: false }
    width: 220
    height: root.v2BarHeight
    
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "power-notch"
    
    property bool notchVisible: hoverTrigger.containsMouse || menuArea.containsMouse || shutDownMouse.containsMouse || restartMouse.containsMouse || lockMouse.containsMouse
    property real reveal: notchVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }

    Item {
        id: triggerArea
        width: 10
        height: 10
        anchors.top: parent.top
        anchors.right: parent.right
        
        MouseArea {
            id: hoverTrigger
            anchors.fill: parent
            hoverEnabled: true
        }
    }

    Item {
        id: notchWrapper
        width: 140
        height: root.v2BarHeight
        anchors.right: parent.right
        y: -height + (reveal * height)
        clip: true
        
        Rectangle {
            id: notchBody
            width: parent.width
            height: parent.height + radius
            y: -radius
            radius: 7
            color: root.paper
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1)
            border.width: 1
            
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                height: notchWrapper.height
                spacing: 5
                
                Rectangle {
                    width: 40
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6
                    color: shutDownMouse.containsMouse ? root.color01 : "transparent"
                    
                    IconText {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        color: shutDownMouse.containsMouse ? root.paper : root.ink
                        font.pixelSize: 16
                    }
                    
                    MouseArea {
                        id: shutDownMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { shutDownProc.running = false; shutDownProc.running = true }
                    }
                }
                
                Rectangle {
                    width: 40
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6
                    color: restartMouse.containsMouse ? root.color03 : "transparent"
                    
                    IconText {
                        anchors.centerIn: parent
                        text: "restart_alt"
                        color: restartMouse.containsMouse ? root.paper : root.ink
                        font.pixelSize: 16
                    }
                    
                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { restartProc.running = false; restartProc.running = true }
                    }
                }
                
                Rectangle {
                    width: 40
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 6
                    color: lockMouse.containsMouse ? root.color04 : "transparent"
                    
                    IconText {
                        anchors.centerIn: parent
                        text: "lock"
                        color: lockMouse.containsMouse ? root.paper : root.ink
                        font.pixelSize: 16
                    }
                    
                    MouseArea {
                        id: lockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { lockProc.running = false; lockProc.running = true }
                    }
                }
            }
            
            MouseArea {
                id: menuArea
                anchors.fill: parent
                hoverEnabled: true
                z: -1
            }
        }
    }
    
    Process {
        id: shutDownProc
        running: false
        command: ["bash", "-c", "systemctl poweroff"]
    }
    
    Process {
        id: restartProc
        running: false
        command: ["bash", "-c", "systemctl reboot"]
    }
    
    Process {
        id: lockProc
        running: false
        command: ["bash", "-c", "loginctl lock-session || hyprlock"]
    }
}

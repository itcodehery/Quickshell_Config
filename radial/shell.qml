import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Shapes

ShellRoot {
    id: root

    property var clientsData: []
    property int activeWsId: 1
    property int numWorkspaces: 5 
    property real globalCursorX: 1920 / 2
    property real globalCursorY: 1080 / 2
    
    Process {
        id: switchProc
        property int targetWs: 1
        command: ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + targetWs + " })"]
        onExited: Qt.quit()
    }

    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let json = JSON.parse(this.text);
                    clientsData = json;
                    
                    let m = 5;
                    for(let i = 0; i < json.length; i++) {
                        if (json[i].workspace.id > m) m = json[i].workspace.id;
                    }
                    numWorkspaces = m;
                } catch (e) {}
            }
        }
    }

    Process {
        id: activeWsProc
        command: ["hyprctl", "activeworkspace", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let json = JSON.parse(this.text);
                    activeWsId = json.id;
                } catch (e) {}
            }
        }
    }

    Process {
        id: cursorProc
        command: ["hyprctl", "cursorpos", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let json = JSON.parse(this.text);
                    globalCursorX = json.x;
                    globalCursorY = json.y;
                } catch(e) {}
            }
        }
    }

    PanelWindow {
        id: radialWindow
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "radial-switcher"
        WlrLayershell.focusable: true
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        property real mx: globalCursorX
        property real my: globalCursorY
        
        Rectangle {
            id: dimBackground
            anchors.fill: parent
            color: "transparent" // NO DIMMING AT ALL
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                
                onPositionChanged: (mouse) => {
                    radialWindow.mx = mouse.x
                    radialWindow.my = mouse.y
                }
                
                onClicked: (mouse) => {
                    let dx = mouse.x - radialCenter.x
                    let dy = mouse.y - radialCenter.y
                    let dist = Math.sqrt(dx*dx + dy*dy)
                    
                    if (dist >= 50 && dist <= 180) {
                        let angle = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                        let wedgeSize = 360 / root.numWorkspaces
                        let shiftedAngle = (angle + 90) % 360
                        let clickedIndex = Math.floor(shiftedAngle / wedgeSize)
                        let wsId = clickedIndex + 1
                        
                        radialCenter.scale = 0.8
                        radialCenter.opacity = 0
                        switchProc.targetWs = wsId;
                        switchProc.running = true;
                        let t = Qt.createQmlObject('import QtQuick; Timer { interval: 300; running: true; onTriggered: Qt.quit() }', root, "timer")
                    } else {
                        Qt.quit()
                    }
                }
            }
            
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Qt.quit()
            }

            Item {
                id: radialCenter
                x: globalCursorX
                y: globalCursorY
                
                scale: 0.8
                opacity: 0
                NumberAnimation on scale { to: 1; duration: 200; easing.type: Easing.OutBack }
                NumberAnimation on opacity { to: 1; duration: 150; easing.type: Easing.OutCubic }
                
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                
                // Central circle
                Rectangle {
                    anchors.centerIn: parent
                    width: 90
                    height: 90
                    radius: 45
                    color: "#2d353b"
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.activeWsId
                        color: "#7fbbb3"
                        font.pixelSize: 28
                        font.bold: true
                    }
                }
                
                Repeater {
                    model: root.numWorkspaces
                    
                    Item {
                        id: wedgeItem
                        property int wsId: index + 1
                        
                        property real innerRadius: 50
                        property real outerRadius: 180
                        property real startAngleDeg: index * (360 / root.numWorkspaces) - 90
                        property real sweepAngleDeg: 360 / root.numWorkspaces
                        property real gapDeg: 5
                        
                        property real dx: radialWindow.mx - radialCenter.x
                        property real dy: radialWindow.my - radialCenter.y
                        property real dist: Math.sqrt(dx*dx + dy*dy)
                        property real mouseAngleDeg: (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                        
                        property real normStart: (startAngleDeg + 360) % 360
                        property real normEnd: (startAngleDeg + sweepAngleDeg + 360) % 360
                        
                        property bool isHovered: {
                            if (dist < innerRadius || dist > outerRadius) return false;
                            let a = mouseAngleDeg;
                            if (normStart < normEnd) {
                                return a >= normStart && a < normEnd;
                            } else {
                                return a >= normStart || a < normEnd;
                            }
                        }
                        
                        Shape {
                            id: wedgeShape
                            
                            scale: wedgeItem.isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            
                            ShapePath {
                                // No stroke at all, completely sharp clean slices
                                strokeColor: "transparent"
                                strokeWidth: 0
                                fillColor: wedgeItem.wsId === root.activeWsId ? "#343f44" : (wedgeItem.isHovered ? "#2d353b" : "#21272c")
                                
                                property real startRad: (wedgeItem.startAngleDeg + wedgeItem.gapDeg/2) * Math.PI / 180
                                property real endRad: (wedgeItem.startAngleDeg + wedgeItem.sweepAngleDeg - wedgeItem.gapDeg/2) * Math.PI / 180
                                
                                startX: wedgeItem.innerRadius * Math.cos(startRad)
                                startY: wedgeItem.innerRadius * Math.sin(startRad)
                                
                                PathLine {
                                    x: wedgeItem.outerRadius * Math.cos(startRad)
                                    y: wedgeItem.outerRadius * Math.sin(startRad)
                                }
                                PathAngleArc {
                                    centerX: 0; centerY: 0
                                    radiusX: wedgeItem.outerRadius; radiusY: wedgeItem.outerRadius
                                    startAngle: wedgeItem.startAngleDeg + wedgeItem.gapDeg/2
                                    sweepAngle: wedgeItem.sweepAngleDeg - wedgeItem.gapDeg
                                }
                                PathLine {
                                    x: wedgeItem.innerRadius * Math.cos(endRad)
                                    y: wedgeItem.innerRadius * Math.sin(endRad)
                                }
                                PathAngleArc {
                                    centerX: 0; centerY: 0
                                    radiusX: wedgeItem.innerRadius; radiusY: wedgeItem.innerRadius
                                    startAngle: wedgeItem.startAngleDeg + wedgeItem.sweepAngleDeg - wedgeItem.gapDeg/2
                                    sweepAngle: -(wedgeItem.sweepAngleDeg - wedgeItem.gapDeg)
                                }
                            }
                        }
                        
                        // Workspace text / abbreviation list
                        Column {
                            property real midRad: (wedgeItem.startAngleDeg + wedgeItem.sweepAngleDeg/2) * Math.PI / 180
                            property real textDist: wedgeItem.innerRadius + (wedgeItem.outerRadius - wedgeItem.innerRadius) / 2
                            x: textDist * Math.cos(midRad) - width/2
                            y: textDist * Math.sin(midRad) - height/2
                            
                            spacing: 4
                            
                            Text {
                                text: wedgeItem.wsId
                                color: wedgeItem.wsId === root.activeWsId ? "#7fbbb3" : "#d3c6aa"
                                font.pixelSize: 18
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            
                            Row {
                                spacing: 6
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Repeater {
                                    model: {
                                        let all = root.clientsData.filter(c => c.workspace.id === wedgeItem.wsId);
                                        return all;
                                    }
                                    
                                    Rectangle {
                                        width: 28
                                        height: 16
                                        color: "#21272c"
                                        radius: 4
                                        border.color: "#2d353b"
                                        border.width: 1
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.class ? modelData.class.substring(0, 3).toUpperCase() : ""
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#d3c6aa"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

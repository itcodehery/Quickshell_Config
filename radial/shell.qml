import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Shapes

ShellRoot {
    id: root

    property var clientsData: []
    property var activeWorkspaces: []
    property var displayWorkspaces: [1]
    property int activeWsId: 1
    property int numWorkspaces: 1 
    property real globalCursorX: 1920 / 2
    property real globalCursorY: 1080 / 2

    // Dynamic Theme Properties
    property color themeBackground: "#2d353b"
    property color themeForeground: "#d3c6aa"
    property color themeAccent: "#7fbbb3"
    property color themeLighterBg: "#343f44"
    property color themeDarkBg: "#21272c"
    property color themeSelection: "#3d484d"
    property color themeMuted: "#475258"

    FileView {
        path: "/home/hery/.local/state/omarchy/current/theme/colors.toml"
        watchChanges: true
        onLoaded: {
            let lines = text().split('\n');
            let colors = {};
            for (let i = 0; i < lines.length; i++) {
                let m = lines[i].match(/([a-z0-9_]+)\s*=\s*"([^"]+)"/);
                if (m) {
                    colors[m[1]] = m[2];
                }
            }
            
            let bg = colors["background"] || colors["color0"] || "#2d353b";
            themeBackground = bg;
            themeForeground = colors["foreground"] || colors["color7"] || "#d3c6aa";
            themeAccent = colors["accent"] || colors["color4"] || "#7fbbb3";
            
            themeSelection = colors["selection"] || colors["color8"] || themeAccent;
            themeMuted = colors["muted"] || colors["color8"] || themeForeground;
            
            themeDarkBg = colors["dark_background"] || bg;
            themeLighterBg = colors["lighter_background"] || colors["selection"] || colors["color8"] || bg;
        }
    }
    
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
                    
                    let wsSet = new Set();
                    for(let i = 0; i < json.length; i++) {
                        if (json[i].workspace.id > 0) {
                            wsSet.add(json[i].workspace.id);
                        }
                    }
                    let arr = Array.from(wsSet).sort((a,b) => a - b);
                    activeWorkspaces = arr;
                    
                    let empty = 1;
                    while (arr.includes(empty)) empty++;
                    
                    displayWorkspaces = arr.concat([empty]);
                    numWorkspaces = displayWorkspaces.length;
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

    function closeMenu() {
        radialCenter.scale = 0.8
        radialCenter.opacity = 0
        let t = Qt.createQmlObject('import QtQuick; Timer { interval: 200; running: true; onTriggered: Qt.quit() }', root, "timer")
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
            color: "transparent" 
            
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
                    
                    if (dist >= 80 && dist <= 200) {
                        let angle = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                        let wedgeSize = 360 / root.numWorkspaces
                        let shiftedAngle = (angle + 90 + wedgeSize/2) % 360
                        let clickedIndex = Math.floor(shiftedAngle / wedgeSize)
                        if (clickedIndex < 0 || clickedIndex >= root.displayWorkspaces.length) return;
                        
                        let wsId = root.displayWorkspaces[clickedIndex]
                        
                        switchProc.targetWs = wsId;
                        switchProc.running = true;
                        closeMenu()
                    } else {
                        closeMenu()
                    }
                }
            }
            
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: closeMenu()
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
                    id: centerCircle
                    anchors.centerIn: parent
                    width: 70
                    height: 70
                    radius: 35
                    
                    color: centerArea.containsMouse ? root.themeDarkBg : root.themeBackground
                    border.color: centerArea.containsMouse ? root.themeAccent : root.themeMuted
                    border.width: centerArea.containsMouse ? 2 : 1
                    
                    scale: centerArea.containsMouse ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    
                    MouseArea {
                        id: centerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: closeMenu()
                    }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        
                        Text {
                            text: "✕"
                            color: root.themeForeground
                            font.pixelSize: 22
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Text {
                            text: root.activeWorkspaces.length
                            color: root.themeMuted
                            font.pixelSize: 12
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
                
                Repeater {
                    model: root.numWorkspaces
                    
                    Item {
                        id: wedgeItem
                        property int wsId: root.displayWorkspaces[index]
                        property bool isEmpty: index === root.displayWorkspaces.length - 1
                        
                        property real centerAngleDeg: index * (360 / root.numWorkspaces) - 90
                        property real startAngleDeg: centerAngleDeg - (180 / root.numWorkspaces)
                        property real sweepAngleDeg: 360 / root.numWorkspaces
                        
                        property real dx: radialWindow.mx - radialCenter.x
                        property real dy: radialWindow.my - radialCenter.y
                        property real dist: Math.sqrt(dx*dx + dy*dy)
                        property real mouseAngleDeg: (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                        
                        property real normStart: (startAngleDeg + 360) % 360
                        property real normEnd: (startAngleDeg + sweepAngleDeg + 360) % 360
                        
                        property bool isHovered: {
                            if (dist < 80 || dist > 200) return false;
                            let a = mouseAngleDeg;
                            if (normStart < normEnd) {
                                return a >= normStart && a < normEnd;
                            } else {
                                return a >= normStart || a < normEnd;
                            }
                        }
                        
                        Rectangle {
                            id: wsRect
                            width: 120
                            height: 75
                            
                            property real centerAngleRad: wedgeItem.centerAngleDeg * Math.PI / 180
                            property real distFromCenter: 140
                            
                            x: distFromCenter * Math.cos(centerAngleRad) - width/2
                            y: distFromCenter * Math.sin(centerAngleRad) - height/2
                            
                            color: wedgeItem.wsId === root.activeWsId ? root.themeLighterBg : (wedgeItem.isHovered ? root.themeBackground : root.themeDarkBg)
                            border.color: wedgeItem.isHovered ? root.themeAccent : (wedgeItem.isEmpty ? root.themeMuted : root.themeSelection)
                            border.width: wedgeItem.isHovered ? 1 : 0
                            radius: 8
                            
                            scale: wedgeItem.isHovered ? 1.1 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            
                            Text {
                                visible: wedgeItem.isEmpty
                                text: "+"
                                anchors.centerIn: parent
                                color: root.themeMuted
                                font.pixelSize: 36
                                font.bold: true
                            }
                            
                            Item {
                                visible: !wedgeItem.isEmpty
                                anchors.top: parent.top
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                height: 14
                                
                                Text {
                                    text: {
                                        if (wedgeItem.isEmpty) return "";
                                        let clients = root.clientsData.filter(c => c.workspace.id === wedgeItem.wsId);
                                        if (clients.length === 0) return "Empty";
                                        let first = clients[0].class || clients[0].title || "Unknown";
                                        first = first.charAt(0).toUpperCase() + first.slice(1);
                                        if (clients.length === 1) return first;
                                        return first + " & " + (clients.length - 1) + " other" + (clients.length > 2 ? "s" : "");
                                    }
                                    anchors.left: parent.left
                                    anchors.right: iconImg.left
                                    anchors.rightMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: wedgeItem.wsId === root.activeWsId ? root.themeAccent : root.themeForeground
                                    font.pixelSize: 10
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                
                                Image {
                                    id: iconImg
                                    property string iconName: {
                                        if (wedgeItem.isEmpty) return "";
                                        let clients = root.clientsData.filter(c => c.workspace.id === wedgeItem.wsId);
                                        if (clients.length === 0) return "";
                                        return clients[0].class || clients[0].initialClass || "";
                                    }
                                    visible: iconName !== ""
                                    source: iconName !== "" ? Quickshell.iconPath(iconName.toLowerCase(), "application-x-executable") : ""
                                    width: 12
                                    height: 12
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: 12
                                    sourceSize.height: 12
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            Item {
                                visible: !wedgeItem.isEmpty
                                anchors.top: parent.top
                                anchors.topMargin: 26
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                
                                property real logicalWidth: 1536
                                property real logicalHeight: 864
                                
                                Repeater {
                                    model: {
                                        if (wedgeItem.isEmpty) return [];
                                        return root.clientsData.filter(c => c.workspace.id === wedgeItem.wsId);
                                    }
                                    
                                    Rectangle {
                                        x: (modelData.at[0] / parent.logicalWidth) * parent.width
                                        y: (modelData.at[1] / parent.logicalHeight) * parent.height
                                        width: (modelData.size[0] / parent.logicalWidth) * parent.width
                                        height: (modelData.size[1] / parent.logicalHeight) * parent.height
                                        
                                        color: root.themeDarkBg
                                        border.color: root.themeMuted
                                        border.width: 1
                                        radius: 2
                                        
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.class ? modelData.class.substring(0, 3).toUpperCase() : ""
                                            font.pixelSize: 7
                                            font.bold: true
                                            color: root.themeForeground
                                            visible: parent.width > 20 && parent.height > 10
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

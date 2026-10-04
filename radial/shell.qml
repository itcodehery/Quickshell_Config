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
    property real localCursorX: 1920 / 2
    property real localCursorY: 1080 / 2
    property bool isClosing: false
    property bool isOpen: false

    Component.onCompleted: { root.isOpen = true }

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
                    root.clientsData = json;
                    
                    let wsSet = new Set();
                    for(let i = 0; i < json.length; i++) {
                        if (json[i].workspace.id > 0) {
                            wsSet.add(json[i].workspace.id);
                        }
                    }
                    let arr = Array.from(wsSet).sort((a,b) => a - b);
                    root.activeWorkspaces = arr;
                    
                    let empty = 1;
                    while (arr.includes(empty)) empty++;
                    
                    root.displayWorkspaces = arr.concat([empty]);
                    root.numWorkspaces = root.displayWorkspaces.length;
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
                    root.activeWsId = json.id;
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
                    root.globalCursorX = json.x;
                    root.globalCursorY = json.y;
                    monitorsProc.running = true;
                } catch(e) {}
            }
        }
    }

    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let monitors = JSON.parse(this.text);
                    let gx = root.globalCursorX;
                    let gy = root.globalCursorY;
                    let localX = gx;
                    let localY = gy;
                    let mw = 1920;
                    let mh = 1080;
                    let scale = 1;
                    
                    for (let m of monitors) {
                        let scale = m.scale || 1;
                        let mx = m.x;
                        let my = m.y;
                        let logicalW = m.width / scale;
                        let logicalH = m.height / scale;
                        if (gx >= mx && gx <= mx + logicalW && gy >= my && gy <= my + logicalH) {
                            localX = gx - mx;
                            localY = gy - my;
                            mw = logicalW;
                            mh = logicalH;
                            break;
                        }
                    }
                    let padding = Theme.cardDist + Theme.cardWidth/2 + 20;
                    if (localX < padding) localX = padding;
                    if (localX > mw - padding) localX = mw - padding;
                    if (localY < padding) localY = padding;
                    if (localY > mh - padding) localY = mh - padding;
                    
                    root.localCursorX = localX;
                    root.localCursorY = localY;
                } catch(e) {}
            }
        }
    }

    function closeMenu() {
        if (root.isClosing) return;
        root.isClosing = true;
        root.isOpen = false;
        radialCenter.scale = 0.5
        radialCenter.opacity = 0
        dimBackground.opacity = 0
        let t = Qt.createQmlObject('import QtQuick; Timer { interval: Theme.animDurationClose; running: true; onTriggered: Qt.quit() }', root, "timer")
    }

    function selectWorkspace(index) {
        if (index < 0 || index >= root.displayWorkspaces.length) return;
        let wsId = root.displayWorkspaces[index];
        switchProc.targetWs = wsId;
        switchProc.running = true;
        closeMenu();
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

        property real mx: root.localCursorX
        property real my: root.localCursorY
        
        Rectangle {
            id: dimBackground
            anchors.fill: parent
            color: Theme.scrim
            opacity: 0
            
            NumberAnimation on opacity {
                to: 1; duration: Theme.animDurationOpen; easing.type: Easing.OutCubic
            }
            Behavior on opacity { NumberAnimation { duration: Theme.animDurationClose; easing.type: Easing.OutCubic } }
            
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                
                onPositionChanged: (mouse) => {
                    radialWindow.mx = mouse.x
                    radialWindow.my = mouse.y
                }
                
                function handleAction(mx, my) {
                    let dx = mx - radialCenter.x
                    let dy = my - radialCenter.y
                    let dist = Math.sqrt(dx*dx + dy*dy)
                    
                    if (dist >= 80 && dist <= Theme.cardDist + 100) {
                        let angle = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
                        let wedgeSize = 360 / root.numWorkspaces
                        let shiftedAngle = (angle + 90 + wedgeSize/2) % 360
                        let clickedIndex = Math.floor(shiftedAngle / wedgeSize)
                        
                        selectWorkspace(clickedIndex)
                    } else {
                        closeMenu()
                    }
                }

                onClicked: (mouse) => handleAction(mouse.x, mouse.y)
            }
            
            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: closeMenu()
            }

            Item {
                id: radialCenter
                x: root.localCursorX
                y: root.localCursorY
                
                scale: 0.5
                opacity: 0
                NumberAnimation on scale { to: 1; duration: Theme.animDurationOpen; easing.type: Easing.OutBack }
                NumberAnimation on opacity { to: 1; duration: Theme.animDurationOpen; easing.type: Easing.OutCubic }
                
                Behavior on scale { NumberAnimation { duration: Theme.animDurationClose; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.animDurationClose; easing.type: Easing.OutCubic } }
                
                // Ring spokes/connections
                Repeater {
                    model: root.numWorkspaces
                    Item {
                        property real centerAngleDeg: index * (360 / root.numWorkspaces) - 90
                        property real centerAngleRad: centerAngleDeg * Math.PI / 180
                        
                        Rectangle {
                            x: 35 * Math.cos(parent.centerAngleRad)
                            y: 35 * Math.sin(parent.centerAngleRad) - height/2
                            width: Theme.cardDist - 35 - Theme.cardWidth/2 + 10
                            height: 2
                            color: root.activeWorkspaces[index] === root.activeWsId ? Theme.accent : Theme.muted
                            opacity: 0.3
                            transformOrigin: Item.Left
                            rotation: parent.centerAngleDeg
                        }
                    }
                }
                
                // Central circle
                Rectangle {
                    id: centerCircle
                    anchors.centerIn: parent
                    width: 70
                    height: 70
                    radius: 35
                    
                    color: centerArea.containsMouse ? Theme.darkBg : Theme.background
                    border.color: centerArea.containsMouse ? Theme.accent : Theme.muted
                    border.width: centerArea.containsMouse ? 2 : 1
                    
                    scale: centerArea.containsMouse ? 1.05 : 1.0
                    Behavior on scale { NumberAnimation { duration: Theme.animDurationHover; easing.type: Easing.OutCubic } }
                    
                    // Central Drop Shadow
                    Rectangle {
                        z: -1
                        anchors.fill: parent
                        anchors.margins: -1
                        anchors.verticalCenterOffset: 2
                        radius: 36
                        color: Theme.withAlpha("#000000", 0.4)
                    }
                    
                    MouseArea {
                        id: centerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: closeMenu()
                    }
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: -2
                        
                        Text {
                            text: root.activeWsId
                            color: Theme.accent
                            font.pixelSize: 28
                            font.family: "DM Sans"
                            font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: root.activeWorkspaces.length
                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: root.activeWorkspaces[index] === root.activeWsId ? Theme.accent : Theme.muted
                                }
                            }
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
                            if (dist < 80 || dist > Theme.cardDist + 100) return false;
                            let a = mouseAngleDeg;
                            if (normStart < normEnd) {
                                return a >= normStart && a < normEnd;
                            } else {
                                return a >= normStart || a < normEnd;
                            }
                        }
                        
                        WorkspaceCard {
                            index: index
                            isOpen: root.isOpen
                            wsId: wedgeItem.wsId
                            isEmpty: wedgeItem.isEmpty
                            clientsData: {
                                if (wedgeItem.isEmpty) return [];
                                return root.clientsData.filter(c => c.workspace.id === wedgeItem.wsId);
                            }
                            isActive: wedgeItem.wsId === root.activeWsId
                            isHovered: wedgeItem.isHovered
                            centerAngleDeg: wedgeItem.centerAngleDeg
                        }
                    }
                }
            }
        }
    }
}

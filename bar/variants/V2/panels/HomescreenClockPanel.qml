import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../modules"

PanelWindow {
    id: hsClock
    required property var root
    required property var targetScreen

    screen: targetScreen
    color: "transparent"

    // Fill the screen to allow dimming the entire screen (including the bar)
    anchors { bottom: true; left: true; right: true; top: true }
    
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: (expanded || isClosing) ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "homescreen-clock"
    WlrLayershell.keyboardFocus: (expanded || isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool expanded: root.dashboardExpanded
    property bool isClosing: false

    Rectangle {
        id: dimmer
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        opacity: (expanded && !isClosing) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
        visible: opacity > 0
        MouseArea {
            anchors.fill: parent
            onClicked: root.dashboardExpanded = false
        }
    }

    mask: Region { item: (expanded || isClosing || dimmer.opacity > 0) ? dimmer : bgRect }

    Timer {
        id: closeTimer
        interval: 420
        repeat: false
        onTriggered: hsClock.isClosing = false
    }

    onExpandedChanged: {
        if (expanded) {
            closeTimer.stop()
            isClosing = false
            if (dashboardLoader.item) dashboardLoader.item.forceActiveFocus()
        } else {
            isClosing = true
            closeTimer.restart()
        }
        if (root.dashboardExpanded !== expanded) {
            root.dashboardExpanded = expanded
        }
    }
    
    Connections {
        target: root
        function onDashboardExpandedChanged() {
            if (hsClock.expanded !== root.dashboardExpanded) {
                hsClock.expanded = root.dashboardExpanded
            }
        }
    }
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: hsClock.now = new Date()
    }
    
    function pad(n) { return n < 10 ? "0" + n : String(n) }
    
    readonly property string hourStr: {
        var h = root.clock12h ? now.getHours() % 12 : now.getHours()
        if (root.clock12h && h === 0) h = 12
        return pad(h)
    }
    readonly property string minStr: pad(now.getMinutes())
    readonly property string amPmStr: root.clock12h ? (now.getHours() < 12 ? "AM" : "PM") : ""
    
    readonly property var months: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    readonly property var days: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property string dateStr: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()]

    Timer {
        id: autoCollapseTimer
        interval: 6500
        running: expanded && !bgHover.hovered
        repeat: false
        onTriggered: expanded = false
    }

    readonly property real pillHeight: clockLayout.height > 0 ? clockLayout.height + 24 : 80
    readonly property real pillWidth: clockLayout.width > 0 ? clockLayout.width + 48 : 220

    Rectangle {
        id: bgRect
        clip: true
        visible: expanded || isClosing || opacity > 0
        opacity: expanded ? 1.0 : 0.0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: expanded ? 20 : 20 + Math.max(0, (110 - pillHeight) / 2)
        width: expanded ? parent.width * 0.7 : pillWidth
        height: expanded ? targetScreen.height * 0.55 : pillHeight
        radius: expanded ? 24 : height / 2
        color: root.bg
        border.color: root.islandBorder
        border.width: 1
        
        Behavior on opacity {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }
        }
        
        Behavior on width {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
        }
        Behavior on radius { NumberAnimation { duration: 400 } }

        HoverHandler {
            id: bgHover
        }
        
        // Header / Compact Clock
        Row {
            id: clockLayout
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: expanded ? 20 : (bgRect.height - height) / 2
            spacing: 12
            
            Behavior on anchors.topMargin { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

            // Hours
            Text {
                text: hsClock.hourStr
                color: root.ink
                font.family: root.barFont
                font.pixelSize: 56
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
            
            // Separator
            Rectangle {
                width: 3
                height: 44
                color: root.ink
                opacity: 0.5
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
            }

            // Minutes and Date Column
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                
                Row {
                    spacing: 6
                    anchors.left: parent.left
                    Text {
                        text: hsClock.minStr
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 36
                        font.weight: Font.Medium
                    }
                    
                    Text {
                        text: hsClock.amPmStr
                        visible: root.clock12h
                        color: root.ink
                        opacity: 0.8
                        font.family: root.barFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 5
                    }
                }
                
                Text {
                    text: hsClock.dateStr.toUpperCase()
                    color: root.ink
                    opacity: 0.7
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }
        }
        
        // Expanded Content Loader
        Loader {
            id: dashboardLoader
            anchors.top: clockLayout.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            active: expanded || isClosing
            source: "HomescreenDashboardContent.qml"
            opacity: expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
            
            onLoaded: {
                item.root = hsClock.root
                item.panel = hsClock
                if (expanded) item.forceActiveFocus()
            }
        }
        
        // Top-left: System Pet + Battery
        Row {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20
            spacing: 12
            visible: opacity > 0
            opacity: expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            // System Pet
            SystemPet {
                root: hsClock.root
                anchors.verticalCenter: parent.verticalCenter
            }

            // Battery pill
            Rectangle {
                height: 32
                width: battLoader.item ? battLoader.item.implicitWidth : 0
                radius: 16
                color: root.fillIdle
                visible: battLoader.item && battLoader.item.shown
                anchors.verticalCenter: parent.verticalCenter

                Loader {
                    id: battLoader
                    anchors.centerIn: parent
                    active: expanded || isClosing
                    sourceComponent: BatteryWidget { root: hsClock.root }
                }
            }
        }
        
        // Top Right Controls (Uptime, Restart, Power Off)
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 12
            visible: opacity > 0
            opacity: expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
            
            Process {
                id: uptimeProc
                command: ["bash", "-c", "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime"]
                running: expanded
                stdout: StdioCollector {
                    onStreamFinished: {
                        uptimeTxt.text = "UP " + this.text.trim().toUpperCase()
                    }
                }
            }
            Timer {
                interval: 60000; repeat: true; running: expanded
                onTriggered: { uptimeProc.running = false; uptimeProc.running = true }
            }

            Rectangle {
                height: 32
                width: uptimeTxt.implicitWidth + 24
                radius: 16
                color: uptimeMa.containsMouse ? root.fillHover : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    id: uptimeTxt
                    anchors.centerIn: parent
                    text: "UP --"
                    color: root.ink
                    opacity: uptimeMa.containsMouse ? 1.0 : 0.7
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                MouseArea {
                    id: uptimeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        
                        root.screentimeVisible = !root.screentimeVisible // Toggle screentime
                    }
                }
            }

            Rectangle {
                width: 32; height: 32; radius: 16
                color: restartMa.containsMouse ? root.fillHover : root.fillIdle
                IconText {
                    anchors.centerIn: parent
                    text: "restart_alt"
                    color: root.ink
                    font.pixelSize: 16
                }
                MouseArea {
                    id: restartMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                }
            }

            Rectangle {
                width: 32; height: 32; radius: 16
                color: powerMa.containsMouse ? "#ff4444" : root.fillIdle
                IconText {
                    anchors.centerIn: parent
                    text: "power_settings_new"
                    color: powerMa.containsMouse ? "white" : root.ink
                    font.pixelSize: 16
                }
                MouseArea {
                    id: powerMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                }
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import "../modules"

PanelWindow {
    id: stPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-screentime"

    property real reveal: root.screentimeVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.screentimeVisible ? 160 : 120
            easing.type: root.screentimeVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.screentimeVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var stData: ({})
    property var todayApps: []
    property var pastDays: []
    property int maxPastTotal: 0
    property string todayDate: ""

    Process {
        id: loadProc
        running: root.screentimeVisible
        command: ["cat", "/home/hery/.cache/screentime.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text)
                    stPanel.stData = d
                    
                    let ds = new Date()
                    let yy = ds.getFullYear()
                    let mm = String(ds.getMonth() + 1).padStart(2, '0')
                    let dd = String(ds.getDate()).padStart(2, '0')
                    let td = yy + "-" + mm + "-" + dd
                    stPanel.todayDate = td
                    
                    if (d[td] && d[td].apps) {
                        let arr = []
                        for (let app in d[td].apps) {
                            arr.push({ name: app, time: d[td].apps[app] })
                        }
                        arr.sort((a, b) => b.time - a.time)
                        stPanel.todayApps = arr
                    } else {
                        stPanel.todayApps = []
                    }
                    
                    let days = Object.keys(d).sort()
                    let hist = []
                    let mt = 0
                    let recent = days.slice(-7)
                    for (let i = 0; i < recent.length; i++) {
                        let t = d[recent[i]].total || 0
                        if (t > mt) mt = t
                        hist.push({ date: recent[i].substring(5), total: t })
                    }
                    stPanel.maxPastTotal = mt
                    stPanel.pastDays = hist
                    
                    graphCanvas.requestPaint()
                } catch(e) {}
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.screentimeVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: 400
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.bg
        border.color: root.panelBorder
        border.width: root.panelBorderW
        clip: true

        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: stPanel.root
            ownerActive: stPanel.root.screentimeVisible
            targetX: parent.width / 2
            reveal: stPanel.reveal
        }

        x: (parent.width - width) / 2
        y: root.barPosition === "bottom"
            ? (parent.height - root.v2BarHeight - 6 - height) + 2 * (1 - stPanel.reveal)
            : (root.v2BarHeight + 6) - 2 * (1 - stPanel.reveal)
        opacity: stPanel.reveal
        focus: root.screentimeVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.screentimeVisible = false
                event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SCREENTIME"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    id: closeText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: root.screentimeVisible = false
                    }
                }
            }

            Text {
                text: "Past 7 Days"
                color: root.sumiHi
                font.family: root.barFont
                font.pixelSize: 12
            }

            Item {
                width: parent.width
                height: 100
                
                Text {
                    text: {
                        if (stPanel.maxPastTotal === 0) return ""
                        let h = Math.floor(stPanel.maxPastTotal / 3600)
                        let m = Math.floor((stPanel.maxPastTotal % 3600) / 60)
                        let s = stPanel.maxPastTotal % 60
                        if (h > 0) return h + "h " + m + "m"
                        if (m > 0) return m + "m"
                        return s + "s"
                    }
                    anchors.right: parent.right
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 2
                    color: root.sumiHi
                    font.family: root.barFont
                    font.pixelSize: 10
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    y: 0
                    color: root.sumiHi
                    opacity: 0.2
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    y: 80
                    color: root.sumiHi
                    opacity: 0.4
                }
                
                Repeater {
                    model: stPanel.pastDays
                    Rectangle {
                        width: 24
                        property real h: stPanel.maxPastTotal > 0 ? (modelData.total / stPanel.maxPastTotal) * 80 : 0
                        height: Math.max(4, h)
                        y: 80 - height
                        
                        property real spacingW: (parent.width - (stPanel.pastDays.length * 24)) / (stPanel.pastDays.length + 1)
                        x: spacingW + index * (24 + spacingW)
                        
                        color: modelData.date === stPanel.todayDate.substring(5) ? root.seal : root.sumi
                        radius: 4
                        
                        Text {
                            text: modelData.date
                            y: parent.height + 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Text {
                text: "Today's Apps"
                color: root.sumiHi
                font.family: root.barFont
                font.pixelSize: 12
            }

            ListView {
                width: parent.width
                height: 160
                clip: true
                spacing: 8
                model: stPanel.todayApps
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 32
                    radius: 8
                    color: root.fillIdle
                    
                    Row {
                        anchors.fill: parent
                        anchors.margins: 8
                        
                        Text {
                            text: modelData.name
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width - 80
                        }
                        
                        Text {
                            text: {
                                let h = Math.floor(modelData.time / 3600)
                                let m = Math.floor((modelData.time % 3600) / 60)
                                let s = modelData.time % 60
                                if (h > 0) return h + "h " + m + "m"
                                if (m > 0) return m + "m"
                                return s + "s"
                            }
                            color: root.ink
                            opacity: 0.7
                            font.family: root.barFont
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                            width: 80
                        }
                    }
                }
            }
        }
    }
}

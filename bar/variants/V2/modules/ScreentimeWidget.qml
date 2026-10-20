import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: root.modScreentime ? row.implicitWidth + 12 : 0
    implicitHeight: 28
    opacity: root.modScreentime ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    readonly property color contentColor: root.widgetContentColor("G21", root.widgetIconColor)
    property string sessionTimeStr: "00:00"

    Process {
        id: stProc
        running: root.modScreentime
        command: ["cat", "/home/hery/.cache/screentime_session.txt"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = parseInt(this.text.trim())
                if (!isNaN(s)) {
                    let h = Math.floor(s / 3600)
                    let m = Math.floor((s % 3600) / 60)
                    let sec = s % 60
                    if (h > 0) {
                        rootMod.sessionTimeStr = h + "h " + m + "m"
                    } else if (m > 0) {
                        rootMod.sessionTimeStr = m + "m"
                    } else {
                        rootMod.sessionTimeStr = sec + "s"
                    }
                }
            }
        }
    }
    
    Timer {
        interval: 2000; repeat: true; running: root.modScreentime
        onTriggered: { stProc.running = false; stProc.running = true }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        IconText {
            anchors.verticalCenter: parent.verticalCenter
            text: "hourglass_empty"
            color: rootMod.contentColor
            font.pixelSize: 13
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            visible: !root.iconOnly("G21")
            anchors.verticalCenter: parent.verticalCenter
            text: rootMod.sessionTimeStr
            color: rootMod.contentColor
            font.family: root.barFont
            font.pixelSize: 10
            font.weight: Font.Medium
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: "Screentime: " + rootMod.sessionTimeStr }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onClicked: {
            tip.hide()
            if (root.dashboardExpanded && root.dashboardDetail === "screentime") {
                root.dashboardExpanded = false
                root.dashboardDetail = ""
            } else {
                root.dashboardDetail = "screentime"
                root.dashboardExpanded = true
            }
        }
    }
}

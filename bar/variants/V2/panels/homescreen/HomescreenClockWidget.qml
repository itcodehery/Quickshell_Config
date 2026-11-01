import QtQuick
import ".."
import Quickshell
import Quickshell.Widgets
import "../../modules"
import "../../motion"

// --- COOL AESTHETIC TIME & DATE WIDGET (Zero borders, unified canvas) ---
Item {
    id: timeDateWidget
    required property var dashboardContent
    required property var root
    required property var mprisSel
    required property var biggerFont

    visible: opacity > 0.001
    opacity: !dashboardContent.showMediaPlayer ? 1.0 : 0.0
    scale: !dashboardContent.showMediaPlayer ? 1.0 : 0.96
    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    // Seamless smoked glass foundation (Zero borders)
    Rectangle {
        id: timeCanvasBg
        anchors.fill: parent
        radius: 22
        color: Qt.rgba(root.paper.r * 0.20 + 0.03, root.paper.g * 0.20 + 0.03, root.paper.b * 0.20 + 0.03, 0.72)

        // Clipping container for smooth ambient gradient and edge lighting
        ClippingRectangle {
            anchors.fill: parent
            radius: 22
            color: "transparent"

            // Top-right ambient aurora glow
            Rectangle {
                width: 240
                height: 240
                radius: 120
                anchors.top: parent.top
                anchors.topMargin: -60
                anchors.right: parent.right
                anchors.rightMargin: -40
                opacity: 0.16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.seal }
                    GradientStop { position: 0.7; color: Qt.rgba(root.color06.r, root.color06.g, root.color06.b, 0.3) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Bottom-left subtle warm secondary ambient tint
            Rectangle {
                width: 180
                height: 180
                radius: 90
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -60
                anchors.left: parent.left
                anchors.leftMargin: -40
                opacity: 0.09
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.color03 }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // Breathing pulse item for colon
    Item {
        id: colonPulse
        property real pulse: 0.9
        SequentialAnimation {
            running: timeDateWidget.visible
            loops: Animation.Infinite
            NumberAnimation { target: colonPulse; property: "pulse"; to: 0.35; duration: 1000; easing.type: Easing.InOutSine }
            NumberAnimation { target: colonPulse; property: "pulse"; to: 0.95; duration: 1000; easing.type: Easing.InOutSine }
        }
    }

    // Main Widget Layout Container
    Item {
        anchors.fill: parent
        anchors.margins: 18

        // ── TOP ROW: Date & Editorial Status Pill ──
        Item {
            id: topTimeRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24

            Item {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                width: calRow.implicitWidth

                Row {
                    id: calRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        text: "calendar_today"
                        font.pixelSize: 14
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: Qt.formatDate(dashboardContent.now, "dddd, MMMM d")
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardContent.activeDetailView = "calendar"
                        if (root) root.dashboardDetail = "calendar"
                    }
                }
            }

            // Right Pill: Live Greeting Tag
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 22
                radius: 11
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                width: greetingRow.implicitWidth + 16

                Row {
                    id: greetingRow
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: dashboardContent.timeGreeting
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.4
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // ── BOTTOM ROW: Day Progress or Resume Track ──
        Item {
            id: bottomTimeRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 26

            // State A: Resume Track Chip (if a song was paused)
            Rectangle {
                anchors.fill: parent
                radius: 13
                visible: dashboardContent.curTitle !== ""
                color: resumeMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.09)
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        text: "play_arrow"
                        font.pixelSize: 16
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Resume: " + dashboardContent.curTitle
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.ink
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, timeDateWidget.width - 80)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: resumeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardContent.showMediaManually = true
                        if (mprisSel.player) mprisSel.player.play()
                    }
                }
            }

            // State B: Day Completion Bar (when no media is paused/loaded)
            Item {
                anchors.fill: parent
                visible: dashboardContent.curTitle === ""

                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 4

                    IconText {
                        text: "bedtime"
                        font.pixelSize: 12
                        color: root.sumiHi
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: dashboardContent.dayProgressPercent + "% of day completed"
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: root.sumiHi
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    text: dashboardContent.remainingHoursToday
                    font.family: root.barFont
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: root.seal
                    opacity: 0.85
                }

                // Sleek continuous micro-bar (borderless)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.max(height, parent.width * (dashboardContent.dayProgressPercent / 100))
                        radius: 1.5
                        color: root.seal
                    }
                }
            }
        }
    }

    // ── CENTER HERO: Massive Display Clock (Dead Center of the Whole Pill) ──
    Item {
        id: heroClockContainer
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 5
        width: heroClockRow.implicitWidth
        height: heroClockRow.implicitHeight
        scale: clockMa.pressed ? 0.96 : (clockMa.containsMouse ? 1.02 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Row {
            id: heroClockRow
            anchors.centerIn: parent
            spacing: 3

            // Hour Digits
            Text {
                text: dashboardContent.clockHours
                font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                font.pixelSize: 76
                font.weight: Font.Bold
                font.letterSpacing: 0.0
                color: root.ink
                anchors.verticalCenter: parent.verticalCenter
            }

            // Soft Breathing Colon
            Text {
                text: ":"
                font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                font.pixelSize: 64
                font.weight: Font.Light
                color: root.seal
                opacity: colonPulse.pulse
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -4
            }

            // Minute Digits
            Text {
                text: dashboardContent.clockMinutes
                font.family: biggerFont.name.length > 0 ? biggerFont.name : root.barFont
                font.pixelSize: 76
                font.weight: Font.Bold
                font.letterSpacing: 0.0
                color: root.seal
                anchors.verticalCenter: parent.verticalCenter
            }

            // Right Metadata: AM/PM + Week Number
            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 2
                spacing: 3
                leftPadding: 8

                Text {
                    text: dashboardContent.clockAmPm
                    font.family: root.barFont
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: root.ink
                    opacity: 0.75
                    visible: text !== ""
                }

                Text {
                    text: "W" + dashboardContent.getWeekNumber()
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.5
                    color: root.color03
                    opacity: 0.85
                }
            }
        }

        MouseArea {
            id: clockMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                dashboardContent.activeDetailView = "calendar"
                if (root) root.dashboardDetail = "calendar"
            }
        }

        TooltipMixin {
            root: dashboardContent.root
            owner: heroClockContainer
            text: "Open Calendar"
        }
    }
}

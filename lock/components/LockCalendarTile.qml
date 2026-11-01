import QtQuick
import QtQuick.Shapes

// ── TILE 4: CURVED WEEK CALENDAR WIDGET (2 Cols) ─
// Direction: Bottom-Left
Item {
    id: tile4Wrapper
    required property var root
    property alias tile4InAnim: tile4InAnim
    property alias t4Trans: t4Trans

    width: 468
    height: parent.height
    opacity: 0.0
    scale: 0.94
    transform: Translate { id: t4Trans; x: 0; y: 24 }

    SequentialAnimation {
        id: tile4InAnim
        running: true
        PauseAnimation { duration: 280 }
        ParallelAnimation {
            NumberAnimation { target: tile4Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: tile4Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            NumberAnimation { target: t4Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
        }
    }

    Rectangle {
        id: calTile
        anchors.fill: parent
        radius: 26
        color: root.cardBg
        border.color: root.cardBorder
        border.width: 1
        clip: true

        Item {
            anchors.fill: parent
            anchors.margins: 14

            // 1. Top Bar: Calendar Badge & Today Button
            Item {
                id: calTopBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 24

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Text {
                        text: "calendar_month"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 13
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: root.months[root.selMonth] + " " + root.selDay
                        font.family: "Genova"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Jump to Today Pill Button
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 22
                    radius: 11
                    color: todayBtnMa.containsMouse ? root.fillIdle : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                    width: todayPillRow.implicitWidth + 14

                    Row {
                        id: todayPillRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 5; height: 5; radius: 2.5
                            color: root.isSelectedToday ? root.color02 : root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Today"
                            font.family: "Genova"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.seal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: todayBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.jumpToToday()
                    }
                }
            }

            // 2. Curved Days Band
            Item {
                id: curvedWeekView
                anchors.top: calTopBar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.right: parent.right
                height: 90
                clip: true

                readonly property real archHeight: 12.0
                readonly property real ribbonBaseY: 44.0
                readonly property real ribbonThickness: 34.0
                readonly property real sidePad: 8.0
                readonly property real trackWidth: width - (sidePad * 2)

                function archOffsetY(t) {
                    return 4.0 * archHeight * t * (1.0 - t)
                }

                property real scrollOffset: 0.0
                property real targetOffset: 0.0

                function stopScrollAnim() {
                    if (scrollAnim.running) scrollAnim.stop()
                    scrollOffset = 0
                    targetOffset = 0
                }

                NumberAnimation {
                    id: scrollAnim
                    target: curvedWeekView
                    property: "scrollOffset"
                    duration: 200
                    easing.type: Easing.OutCubic
                    onFinished: {
                        var delta = Math.round(curvedWeekView.scrollOffset)
                        if (delta !== 0) {
                            root.stepDay(delta)
                            curvedWeekView.scrollOffset = 0
                            curvedWeekView.targetOffset = 0
                        }
                    }
                }

                function scrollBy(delta) {
                    targetOffset = Math.round(targetOffset) + delta
                    targetOffset = Math.max(-4, Math.min(4, targetOffset))
                    scrollAnim.stop()
                    scrollAnim.from = scrollOffset
                    scrollAnim.to = targetOffset
                    scrollAnim.duration = Math.max(180, Math.min(280, 150 + Math.abs(targetOffset - scrollOffset) * 40))
                    scrollAnim.start()
                }

                // Upward Curved Background Ribbon Shape
                Shape {
                    id: curveShape
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                        strokeWidth: 1
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        fillColor: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.08)

                        startX: curvedWeekView.sidePad
                        startY: curvedWeekView.ribbonBaseY

                        PathQuad {
                            x: curvedWeekView.sidePad + curvedWeekView.trackWidth
                            y: curvedWeekView.ribbonBaseY
                            controlX: curvedWeekView.sidePad + (curvedWeekView.trackWidth / 2)
                            controlY: curvedWeekView.ribbonBaseY - (curvedWeekView.archHeight * 2)
                        }

                        PathLine {
                            x: curvedWeekView.sidePad + curvedWeekView.trackWidth
                            y: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness
                        }

                        PathQuad {
                            x: curvedWeekView.sidePad
                            y: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness
                            controlX: curvedWeekView.sidePad + (curvedWeekView.trackWidth / 2)
                            controlY: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness - (curvedWeekView.archHeight * 2)
                        }

                        PathLine {
                            x: curvedWeekView.sidePad
                            y: curvedWeekView.ribbonBaseY
                        }
                    }
                }

                // Fixed Summit Center Circular Badge at peak of the curve
                Rectangle {
                    id: summitCenterBadge
                    width: 28
                    height: 28
                    radius: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(curvedWeekView.ribbonBaseY - curvedWeekView.archHeight + (curvedWeekView.ribbonThickness / 2) - 14)
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.32)
                    border.width: 1.5
                    border.color: root.seal
                    z: 1
                }

                // Global Wheel Handler over the curved week view
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            curvedWeekView.scrollBy(1)
                        } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            curvedWeekView.scrollBy(-1)
                        }
                    }
                }

                // Dynamic sliding day items along the custom curve (-5 to +5)
                Repeater {
                    model: [-5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5]
                    delegate: Item {
                        id: dayDelegate
                        required property int modelData
                        required property int index

                        readonly property var itemData: root.getWeekDayItem(modelData)
                        readonly property real u: modelData - curvedWeekView.scrollOffset
                        readonly property real t: (u + 3.5) / 7.0
                        readonly property real posX: curvedWeekView.sidePad + (t * curvedWeekView.trackWidth)
                        readonly property real clampedT: Math.max(0.0, Math.min(1.0, t))
                        readonly property real curveH: curvedWeekView.archOffsetY(clampedT)
                        readonly property real posY: curvedWeekView.ribbonBaseY - curveH + (curvedWeekView.ribbonThickness / 2)

                        readonly property real dist: Math.abs(u)
                        readonly property bool isCenter: dist < 0.4
                        readonly property real itemOpacity: {
                            if (dist <= 0.4) return 1.0
                            if (dist >= 3.5) return 0.0
                            return Math.max(0.0, 1.0 - (dist / 3.5) * 0.75)
                        }

                        visible: itemOpacity > 0.01
                        z: 2

                        x: Math.round(posX - (width / 2))
                        y: 0
                        width: Math.round(curvedWeekView.trackWidth / 7.2)
                        height: curvedWeekView.height

                        // Day Name sitting ABOVE the circular badge & ribbon
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(posY - (isCenter ? 30 : 28))
                            text: dayDelegate.itemData.dayName
                            font.family: "Genova"
                            font.pixelSize: 10
                            font.weight: isCenter ? Font.Bold : Font.Normal
                            color: isCenter ? root.ink : root.sumi
                            opacity: dayDelegate.itemOpacity
                        }

                        // Day Number sitting INSIDE the ribbon / summit badge
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(posY - (height / 2))
                            text: dayDelegate.itemData.day
                            font.family: "Genova"
                            font.pixelSize: isCenter ? 12 : 11
                            font.weight: isCenter ? Font.Bold : Font.Medium
                            color: root.ink
                            opacity: dayDelegate.itemOpacity
                        }

                        // Center / Today Marker Dot
                        Rectangle {
                            visible: dayDelegate.itemData.isToday && dayDelegate.itemOpacity > 0.1
                            width: 4
                            height: 4
                            radius: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(posY + (isCenter ? 15 : 13))
                            color: root.seal
                            opacity: dayDelegate.itemOpacity
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var targetDelta = Math.round(u)
                                if (targetDelta !== 0) curvedWeekView.scrollBy(targetDelta)
                            }
                        }
                    }
                }
            }

            // 3. Bottom Strip: Date Summary & Navigation
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: prevDayMa.containsMouse ? root.fillIdle : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: root.ink
                    }
                    MouseArea {
                        id: prevDayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: curvedWeekView.scrollBy(-1)
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        var selDate = new Date(root.selYear, root.selMonth, root.selDay)
                        var label = Qt.formatDate(selDate, "ddd, MMM d")
                        return root.isSelectedToday ? ("Today · " + label) : label
                    }
                    font.family: "Genova"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: root.ink
                }

                Rectangle {
                    width: 20; height: 20; radius: 10
                    color: nextDayMa.containsMouse ? root.fillIdle : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 14
                        color: root.ink
                    }
                    MouseArea {
                        id: nextDayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: curvedWeekView.scrollBy(1)
                    }
                }
            }
        }
    }
}

import QtQuick

Row {
    id: clockWeatherRow
    required property var root
    required property var biggerFont

    property alias tile1Wrapper: tile1Wrapper
    property alias tile1InAnim: tile1InAnim
    property alias t1Trans: t1Trans
    property alias tile2Wrapper: tile2Wrapper
    property alias tile2InAnim: tile2InAnim
    property alias t2Trans: t2Trans

    height: parent.height
    spacing: 16

    // ── TILE 1: CLOCK (Stacked or Inline) ─────────
    // Direction: Top-Left
    Item {
        id: tile1Wrapper
        width: 230
        height: parent.height
        opacity: 0.0
        scale: 0.94
        transform: Translate { id: t1Trans; x: 0; y: 24 }

        SequentialAnimation {
            id: tile1InAnim
            running: true
            PauseAnimation { duration: 160 }
            ParallelAnimation {
                NumberAnimation { target: tile1Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { target: tile1Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                NumberAnimation { target: t1Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }
        }

        Rectangle {
            id: clockTile
            anchors.fill: parent
            radius: 26
            color: root.cardBg
            border.color: root.cardBorder
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.margins: 16

                // Top Pill Header
                Row {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    spacing: 5
                    Text {
                        text: "schedule"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 13
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Clock"
                        font.family: "Genova"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Stacked Clock View
                Column {
                    visible: root.clockStyle === "stacked"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    spacing: -10

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var h = root.now.getHours()
                            return h < 10 ? "0" + h : String(h)
                        }
                        font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                        font.pixelSize: 48
                        font.weight: Font.Bold
                        color: root.ink
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var m = root.now.getMinutes()
                            return m < 10 ? "0" + m : String(m)
                        }
                        font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                        font.pixelSize: 48
                        font.weight: Font.Bold
                        color: root.ink
                        opacity: 0.45
                    }
                }

                // Inline Clock View
                Column {
                    visible: root.clockStyle !== "stacked"
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    spacing: 4

                    Text {
                        text: Qt.formatTime(root.now, "HH:mm")
                        font.family: "Genova"
                        font.pixelSize: 42
                        font.weight: Font.Bold
                        color: root.ink
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: ":" + Qt.formatTime(root.now, "ss")
                        font.family: "Genova"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: root.seal
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                // Bottom Row
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Text {
                        text: root.now.getHours() < 12 ? "AM" : "PM"
                        font.family: "Genova"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: root.seal
                    }
                    Text {
                        text: "·"
                        color: root.sumi
                        font.pixelSize: 10
                    }
                    Text {
                        text: Qt.formatDate(root.now, "ddd, d MMM")
                        font.family: "Genova"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: root.ink
                        opacity: 0.70
                    }
                }
            }
        }
    }

    // ── TILE 2: WEATHER CARD (Editorial Conversational Style) ──
    // Direction: Top-Center
    Item {
        id: tile2Wrapper
        width: 230
        height: parent.height
        opacity: 0.0
        scale: 0.94
        transform: Translate { id: t2Trans; x: 0; y: 24 }

        SequentialAnimation {
            id: tile2InAnim
            running: true
            PauseAnimation { duration: 200 }
            ParallelAnimation {
                NumberAnimation { target: tile2Wrapper; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { target: tile2Wrapper; property: "scale"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                NumberAnimation { target: t2Trans; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }
        }

        Rectangle {
            id: weatherTile
            anchors.fill: parent
            radius: 26
            color: root.cardBg
            border.color: root.cardBorder
            border.width: 1

            Item {
                anchors.fill: parent
                anchors.margins: 20

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    textFormat: Text.RichText
                    text: "<span style='color:" + root.toHex(root.color07) + "'>It’s </span>" +
                          "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherTemp + "°</span>" +
                          "<span style='color:" + root.color07 + "'> now</span><br>" +
                          "<span style='color:" + root.toHex(root.color07) + "'>in </span>" +
                          "<span style='color:" + root.toHex(root.seal) + "; font-weight:700'>" + root.weatherCity + ".</span><br>" +
                          "<span style='color:" + root.toHex(root.color07) + "'>Will be </span>" +
                          "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherPhrase.cond1 + "</span><br>" +
                          "<span style='color:" + root.toHex(root.ink) + "; font-weight:700'>" + root.weatherPhrase.cond2 + ".</span>"
                    font.family: "Genova"
                    font.pixelSize: 20
                    font.weight: Font.Normal
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}

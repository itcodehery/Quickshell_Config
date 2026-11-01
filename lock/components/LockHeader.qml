import QtQuick

// ── 4. TOP HEADER: GREETING (TOP-LEFT) & LIVE LYRICS (TOP-RIGHT) ─
Item {
    id: greetingContainer
    required property var root
    property alias greetingInAnim: greetingInAnim
    property alias greetingTranslate: greetingTranslate

    height: 20

    opacity: 0.0
    transform: Translate { id: greetingTranslate; y: -12 }

    SequentialAnimation {
        id: greetingInAnim
        running: true
        PauseAnimation { duration: 120 }
        ParallelAnimation {
            NumberAnimation { target: greetingContainer; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: greetingTranslate; property: "y"; to: 0; duration: 420; easing.type: Easing.OutCubic }
        }
    }

    Text {
        id: greetingTxt
        text: root.greeting
        font.family: "Genova"
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 0.5
        color: root.ink
        opacity: 0.70
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignLeft
    }

    // Live Lyrics Line (Top-Right corner above Bento Tiles, Right-Aligned)
    Item {
        id: lyricContainer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 20
        width: Math.min(680, Math.max(0, parent.width - greetingTxt.implicitWidth - 24))
        clip: true
        visible: root.hasMedia && root.currentLyricText !== ""
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Row {
            id: lyricRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: "music_note"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 13
                color: root.seal
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                id: lyricSwitcher
                height: 20
                width: Math.min(640, Math.max(10, lyricSwitcher.useB ? textB.implicitWidth : textA.implicitWidth))
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                property bool useB: false
                property string currentShownText: ""
                property bool initialized: false

                function transitionTo(newText) {
                    if (!newText || newText === currentShownText) return
                    currentShownText = newText
                    animSwitch.stop()

                    if (!useB) {
                        textB.text = newText
                        transB.y = 5
                        textB.opacity = 0.0

                        animExitTrans.target = transA
                        animExitTrans.to = -5
                        animExitOpacity.target = textA

                        animEnterTrans.target = transB
                        animEnterTrans.to = 0
                        animEnterOpacity.target = textB

                        useB = true
                    } else {
                        textA.text = newText
                        transA.y = 5
                        textA.opacity = 0.0

                        animExitTrans.target = transB
                        animExitTrans.to = -5
                        animExitOpacity.target = textB

                        animEnterTrans.target = transA
                        animEnterTrans.to = 0
                        animEnterOpacity.target = textA

                        useB = false
                    }

                    animSwitch.restart()
                }

                ParallelAnimation {
                    id: animSwitch

                    NumberAnimation {
                        id: animExitTrans
                        property: "y"
                        duration: 160
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        id: animExitOpacity
                        property: "opacity"
                        to: 0.0
                        duration: 140
                        easing.type: Easing.OutQuad
                    }

                    NumberAnimation {
                        id: animEnterTrans
                        property: "y"
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        id: animEnterOpacity
                        property: "opacity"
                        to: 1.0
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    id: textA
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: "Genova"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                    color: root.seal
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 640)
                    transform: Translate { id: transA }
                }

                Text {
                    id: textB
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: "Genova"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5
                    color: root.seal
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 640)
                    transform: Translate { id: transB }
                }

                Connections {
                    target: root
                    function onCurrentLyricTextChanged() {
                        if (!lyricSwitcher.initialized) {
                            lyricSwitcher.init(root.currentLyricText)
                            return
                        }
                        lyricSwitcher.transitionTo(root.currentLyricText)
                    }
                }

                function init(txt) {
                    currentShownText = txt
                    textA.text = txt
                    textA.opacity = 1.0
                    transA.y = 0
                    textB.text = ""
                    textB.opacity = 0.0
                    transB.y = 5
                    useB = false
                    initialized = true
                }

                Component.onCompleted: {
                    if (root.currentLyricText !== "") {
                        init(root.currentLyricText)
                    }
                }
            }
        }
    }
}

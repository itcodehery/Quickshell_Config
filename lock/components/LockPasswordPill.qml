import QtQuick

// ── 6. SLEEK FROSTED PASSWORD PILL (Bottom Row) ───────────────
Item {
    id: passwordArea
    required property var root
    property alias pwdInAnim: pwdInAnim

    readonly property bool isTyping: root.enteredPassword.length > 0 && !root.failureMessage && !root.authenticating
    readonly property bool isIdle: root.enteredPassword.length === 0 && !root.failureMessage && !root.authenticating

    width: Math.max(220, isTyping ? (dotsRow.implicitWidth + 36) : (isIdle ? (idleRow.implicitWidth + 36) : (root.authenticating ? 160 : errorText.implicitWidth + 36)))
    height: 38
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    opacity: 0.0
    transform: Translate { id: pwdShake; x: 0; y: 16 }

    SequentialAnimation {
        id: pwdInAnim
        running: true
        PauseAnimation { duration: 320 }
        ParallelAnimation {
            NumberAnimation { target: passwordArea; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: pwdShake; property: "y"; to: 0; duration: 420; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: pwdShake; property: "x"; to: -14; duration: 40 }
        NumberAnimation { target: pwdShake; property: "x"; to: 14; duration: 80 }
        NumberAnimation { target: pwdShake; property: "x"; to: -8; duration: 60 }
        NumberAnimation { target: pwdShake; property: "x"; to: 8; duration: 60 }
        NumberAnimation { target: pwdShake; property: "x"; to: 0; duration: 40 }
    }

    Connections {
        target: root
        function onFailedAttemptsChanged() {
            if (root.failedAttempts > 0) {
                shakeAnim.restart()
            }
        }
    }

    // Glass Capsule Background
    Rectangle {
        id: pillBg
        anchors.fill: parent
        radius: height / 2
        color: Qt.rgba(root.paper.r * 0.25 + 0.04, root.paper.g * 0.25 + 0.04, root.paper.b * 0.25 + 0.04, 0.72)
        border.color: root.failureMessage.length > 0 ? Qt.rgba(root.color01.r, root.color01.g, root.color01.b, 0.50) :
                      (passwordArea.isTyping ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.40) :
                       Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12))
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // 1. Idle State: Breathing Lock Icon + "Type Password to Unlock"
    Row {
        id: idleRow
        anchors.centerIn: parent
        spacing: 8
        visible: passwordArea.isIdle
        opacity: idleBreathing.pulseOpacity

        Text {
            text: "lock"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 14
            color: root.seal
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "Type Password to Unlock"
            font.family: "Genova"
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 0.2
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: idleBreathing
        property real pulseOpacity: 0.85
        SequentialAnimation {
            running: passwordArea.isIdle
            loops: Animation.Infinite
            NumberAnimation { target: idleBreathing; property: "pulseOpacity"; to: 0.55; duration: 1500; easing.type: Easing.InOutSine }
            NumberAnimation { target: idleBreathing; property: "pulseOpacity"; to: 0.95; duration: 1500; easing.type: Easing.InOutSine }
        }
    }

    // 2. Typing State: Glowing Dots
    Row {
        id: dotsRow
        anchors.centerIn: parent
        spacing: 10
        visible: passwordArea.isTyping

        Repeater {
            model: root.enteredPassword.length
            delegate: Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.seal

                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: 8
                    color: root.seal
                    opacity: 0.35
                    z: -1
                }
            }
        }
    }

    // 3. Authenticating State: Spinner + Verifying
    Row {
        anchors.centerIn: parent
        spacing: 8
        visible: root.authenticating

        Text {
            text: "sync"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 16
            color: root.seal
            anchors.verticalCenter: parent.verticalCenter

            NumberAnimation on rotation {
                running: root.authenticating
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 900
            }
        }

        Text {
            text: "Verifying..."
            font.family: "Genova"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: root.seal
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // 4. Error Message
    Text {
        id: errorText
        anchors.centerIn: parent
        text: root.failureMessage
        font.family: "Genova"
        font.pixelSize: 12
        font.weight: Font.DemiBold
        color: root.color01
        visible: root.failureMessage.length > 0 && !root.authenticating
    }
}

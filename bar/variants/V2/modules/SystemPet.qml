import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: pet
    required property var root

    width: 36
    height: 36

    // ── State detection ─────────────────────────────────────────────
    MprisSelect { id: mprisSel }

    readonly property int cpu: root.systemCpuPercent
    readonly property bool musicPlaying: mprisSel.playing
    property int idleSeconds: 0

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            if (pet.cpu < 10) pet.idleSeconds += 5
            else pet.idleSeconds = 0
        }
    }

    // Priority: annoyed (override) > stressed > vibing > sleeping > daydreaming > bored > happy
    readonly property string mood: {
        if (cpu > 70) return "stressed"
        if (musicPlaying) return "vibing"
        if (idleSeconds > 120) return "sleeping"
        if (idleSeconds > 60) return "daydreaming"
        if (idleSeconds > 30) return "bored"
        return "happy"
    }

    // ── Poke / annoyed state ────────────────────────────────────────
    property int pokeCount: 0
    property bool annoyed: false

    function poke() {
        pokeCount = Math.min(pokeCount + 1, 5)
        annoyed = true
        pokeRevertTimer.restart()
        idleSeconds = 0
    }

    Timer {
        id: pokeRevertTimer
        interval: 3000
        onTriggered: {
            pet.annoyed = false
            pet.pokeCount = 0
        }
    }

    property string displayMood: "happy"
    onMoodChanged: { if (!annoyed) moodTransition.restart() }
    onAnnoyedChanged: {
        if (annoyed) displayMood = "annoyed"
        else moodTransition.restart()
    }

    Timer {
        id: moodTransition
        interval: 300
        onTriggered: pet.displayMood = pet.mood
    }

    Component.onCompleted: displayMood = mood

    // ── Theme colors ────────────────────────────────────────────────
    readonly property color bodyColor: root.seal
    readonly property color bodyLight: Qt.lighter(root.seal, 1.3)
    readonly property color eyeColor: root.paper
    readonly property color pupilColor: root.ink
    readonly property color cheekColor: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.5)
    readonly property color accessoryColor: root.ink

    // ── Idle bounce animation ───────────────────────────────────────
    property real bounceY: 0
    SequentialAnimation on bounceY {
        loops: Animation.Infinite
        NumberAnimation { to: -2.5; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0;    duration: 800; easing.type: Easing.InOutSine }
    }
    
    // Daydream float
    property real floatY: 0
    SequentialAnimation on floatY {
        loops: Animation.Infinite
        running: displayMood === "daydreaming"
        NumberAnimation { to: -4; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0;  duration: 1500; easing.type: Easing.InOutSine }
    }

    // ── Wobble for stressed state ───────────────────────────────────
    property real wobbleAngle: 0
    SequentialAnimation {
        id: wobbleAnim
        loops: Animation.Infinite
        running: displayMood === "stressed" || displayMood === "annoyed"
        NumberAnimation { target: pet; property: "wobbleAngle"; to: 3;  duration: 80;  easing.type: Easing.InOutSine }
        NumberAnimation { target: pet; property: "wobbleAngle"; to: -3; duration: 80;  easing.type: Easing.InOutSine }
        NumberAnimation { target: pet; property: "wobbleAngle"; to: 2;  duration: 70;  easing.type: Easing.InOutSine }
        NumberAnimation { target: pet; property: "wobbleAngle"; to: 0;  duration: 100; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 200 }
    }

    // ── Breathing for sleeping state ────────────────────────────────
    property real breathScale: 1.0
    SequentialAnimation {
        id: breathAnim
        loops: Animation.Infinite
        running: displayMood === "sleeping"
        NumberAnimation { target: pet; property: "breathScale"; to: 1.06; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { target: pet; property: "breathScale"; to: 1.0;  duration: 1500; easing.type: Easing.InOutSine }
    }

    // ── Main body container ─────────────────────────────────────────
    Item {
        id: bodyContainer
        anchors.centerIn: parent
        width: 44
        height: 44
        scale: 36 / 52
        transform: [
            Translate { y: displayMood === "sleeping" ? 0 : (displayMood === "daydreaming" ? pet.floatY : pet.bounceY) },
            Rotation {
                angle: pet.wobbleAngle
                origin.x: bodyContainer.width / 2
                origin.y: bodyContainer.height / 2
            },
            Scale {
                xScale: displayMood === "sleeping" ? pet.breathScale : 1.0
                yScale: displayMood === "sleeping" ? pet.breathScale : 1.0
                origin.x: bodyContainer.width / 2
                origin.y: bodyContainer.height / 2
            }
        ]

        // Body blob
        Rectangle {
            id: body
            anchors.fill: parent
            radius: width / 2
            color: pet.bodyColor

            // Highlight / shine spot
            Rectangle {
                x: 8; y: 6
                width: 8; height: 6
                radius: 4
                color: pet.bodyLight
                opacity: 0.6
            }
        }

        // ── Eyes ────────────────────────────────────────────────────
        // Left eye
        Rectangle {
            id: leftEye
            x: 11; y: (displayMood === "vibing" || displayMood === "bored" || displayMood === "annoyed") ? 17 : (displayMood === "daydreaming" ? 13 : 15)
            width: displayMood === "sleeping" ? 8 : (displayMood === "daydreaming" ? 10 : 8)
            height: displayMood === "sleeping" ? 2 : (displayMood === "stressed" || displayMood === "daydreaming" ? 10 : (displayMood === "annoyed" ? 4 : 8))
            radius: displayMood === "sleeping" ? 1 : width / 2
            color: pet.eyeColor

            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

            // Pupil
            Rectangle {
                y: (displayMood === "daydreaming") ? 1 : (parent.height - height) / 2
                x: (displayMood === "bored") ? 1 : (parent.width - width) / 2
                width: 4; height: displayMood === "sleeping" ? 0 : 4
                radius: 2
                color: pet.pupilColor
                visible: displayMood !== "sleeping"
                Behavior on x { NumberAnimation { duration: 200 } }
                Behavior on y { NumberAnimation { duration: 200 } }
            }

            // Half-closed lids
            Rectangle {
                visible: displayMood === "vibing" || displayMood === "bored"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.4
                radius: parent.radius
                color: pet.bodyColor
            }
            
            // Angry brow
            Rectangle {
                visible: displayMood === "annoyed"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: -2
                width: parent.width + 4
                height: 3
                rotation: 20
                color: pet.bodyColor
            }
        }

        // Right eye
        Rectangle {
            id: rightEye
            x: 25; y: (displayMood === "vibing" || displayMood === "bored" || displayMood === "annoyed") ? 17 : (displayMood === "daydreaming" ? 13 : 15)
            width: displayMood === "sleeping" ? 8 : (displayMood === "daydreaming" ? 10 : 8)
            height: displayMood === "sleeping" ? 2 : (displayMood === "stressed" || displayMood === "daydreaming" ? 10 : (displayMood === "annoyed" ? 4 : 8))
            radius: displayMood === "sleeping" ? 1 : width / 2
            color: pet.eyeColor

            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

            Rectangle {
                y: (displayMood === "daydreaming") ? 1 : (parent.height - height) / 2
                x: (displayMood === "bored") ? 1 : (parent.width - width) / 2
                width: 4; height: displayMood === "sleeping" ? 0 : 4
                radius: 2
                color: pet.pupilColor
                visible: displayMood !== "sleeping"
                Behavior on x { NumberAnimation { duration: 200 } }
                Behavior on y { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                visible: displayMood === "vibing" || displayMood === "bored"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.4
                radius: parent.radius
                color: pet.bodyColor
            }
            
            // Angry brow
            Rectangle {
                visible: displayMood === "annoyed"
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.rightMargin: -2
                width: parent.width + 4
                height: 3
                rotation: -20
                color: pet.bodyColor
            }
        }

        // ── Mouth ───────────────────────────────────────────────────
        // Happy smile / daydreaming
        Canvas {
            id: mouthCanvas
            x: 14; y: 26
            width: 16; height: 10
            visible: displayMood === "happy" || displayMood === "vibing" || displayMood === "daydreaming"
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Qt.rgba(pet.eyeColor.r, pet.eyeColor.g, pet.eyeColor.b, 0.9)
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(2, 2)
                ctx.quadraticCurveTo(8, (pet.displayMood === "daydreaming" ? 12 : 9), 14, 2)
                ctx.stroke()
            }
            onVisibleChanged: requestPaint()
        }
        
        // Bored / Annoyed mouth (straight line or slight frown)
        Rectangle {
            x: 17; y: 27
            width: 10; height: 2
            radius: 1
            color: pet.eyeColor
            opacity: 0.8
            visible: displayMood === "bored" || displayMood === "annoyed"
        }

        // Stressed mouth (small "o")
        Rectangle {
            x: 19; y: 27
            width: 6; height: 5
            radius: 3
            color: pet.eyeColor
            visible: displayMood === "stressed"
            opacity: 0.8

            Behavior on height { NumberAnimation { duration: 200 } }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2; height: parent.height - 2
                radius: width / 2
                color: pet.bodyColor
            }
        }

        // Sleeping mouth (tiny line)
        Rectangle {
            x: 18; y: 27
            width: 8; height: 2
            radius: 1
            color: pet.eyeColor
            opacity: 0.5
            visible: displayMood === "sleeping"
        }
        
        // Blush (daydreaming)
        Rectangle {
            x: 6; y: 23
            width: 6; height: 4
            radius: 2
            color: root.color01
            opacity: displayMood === "daydreaming" ? 0.4 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        Rectangle {
            x: 32; y: 23
            width: 6; height: 4
            radius: 2
            color: root.color01
            opacity: displayMood === "daydreaming" ? 0.4 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }
    
    // Hitbox for poke
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pet.poke()
    }

    // ── Floating accessories ────────────────────────────────────────

    // Sweat drops (stressed)
    Repeater {
        model: displayMood === "stressed" ? 2 : 0
        delegate: Rectangle {
            id: sweatDrop
            property real baseX: index === 0 ? 38 : 42
            x: baseX
            width: 4; height: 6
            radius: 2
            color: root.color04
            opacity: 0.8

            SequentialAnimation on y {
                loops: Animation.Infinite
                PropertyAnimation { to: 6 + index * 3; duration: 0 }
                PropertyAnimation { to: 20 + index * 5; duration: 600 + index * 200; easing.type: Easing.InQuad }
                PropertyAnimation { to: 6 + index * 3; duration: 0 }
                PauseAnimation { duration: 300 + index * 200 }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PropertyAnimation { to: 0.8; duration: 0 }
                PropertyAnimation { to: 0.8; duration: 400 + index * 200 }
                PropertyAnimation { to: 0; duration: 200 }
                PropertyAnimation { to: 0; duration: 300 + index * 200 }
            }
        }
    }
    
    // Sparkles / Stars (daydreaming)
    Repeater {
        model: displayMood === "daydreaming" ? 2 : 0
        delegate: Text {
            text: "✦"
            color: root.color03
            font.pixelSize: index === 0 ? 12 : 8
            x: index === 0 ? 34 : 2
            y: index === 0 ? 4 : 8
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PropertyAnimation { to: 0.1; duration: 0 }
                PropertyAnimation { to: 0.8; duration: 800 + index * 200 }
                PropertyAnimation { to: 0.1; duration: 800 + index * 200 }
            }
        }
    }

    // Zzz (sleeping)
    Repeater {
        model: displayMood === "sleeping" ? 3 : 0
        delegate: Text {
            id: zzzText
            text: "z"
            color: pet.accessoryColor
            opacity: 0
            font.family: root.barFont
            font.pixelSize: 9 + index * 2
            font.weight: Font.Bold
            font.italic: true
            x: 36 + index * 5

            SequentialAnimation on y {
                loops: Animation.Infinite
                PropertyAnimation { to: 18 - index * 2; duration: 0 }
                PropertyAnimation { to: 4 - index * 6; duration: 1200 + index * 400; easing.type: Easing.OutSine }
                PauseAnimation { duration: 400 }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: index * 500 }
                PropertyAnimation { to: 0.6; duration: 400 }
                PropertyAnimation { to: 0.6; duration: 600 + index * 200 }
                PropertyAnimation { to: 0; duration: 400 }
                PauseAnimation { duration: (2 - index) * 300 }
            }
        }
    }

    // Music notes (vibing)
    Repeater {
        model: displayMood === "vibing" ? 2 : 0
        delegate: Text {
            id: noteText
            text: index === 0 ? "♪" : "♫"
            color: pet.accessoryColor
            opacity: 0
            font.pixelSize: 11
            x: index === 0 ? 2 : 40

            SequentialAnimation on y {
                loops: Animation.Infinite
                PropertyAnimation { to: 14; duration: 0 }
                PropertyAnimation { to: -2; duration: 1400 + index * 300; easing.type: Easing.OutSine }
                PauseAnimation { duration: 300 }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PauseAnimation { duration: index * 600 }
                PropertyAnimation { to: 0.7; duration: 400 }
                PropertyAnimation { to: 0.7; duration: 600 }
                PropertyAnimation { to: 0; duration: 400 }
                PauseAnimation { duration: (1 - index) * 400 }
            }

            SequentialAnimation on x {
                loops: Animation.Infinite
                PropertyAnimation { to: index === 0 ? 2 : 40; duration: 0 }
                PropertyAnimation { to: index === 0 ? -4 : 46; duration: 1400 + index * 300; easing.type: Easing.OutSine }
                PauseAnimation { duration: 300 }
            }
        }
    }
}

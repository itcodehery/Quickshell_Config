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
    readonly property int temp: root.barTemperatureC
    readonly property bool musicPlaying: mprisSel.playing
    property int idleSeconds: 0

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            if (pet.cpu < 10) pet.idleSeconds += 5
            else pet.idleSeconds = 0
        }
    }

    // Priority: annoyed (override) > overheating > stressed > vibing > sleeping > happy
    readonly property string mood: {
        if (temp > 80) return "overheating"
        if (cpu > 70) return "stressed"
        if (musicPlaying) return "vibing"
        if (idleSeconds > 120) return "sleeping"
        return "happy"
    }

    // ── Poke / annoyed state ────────────────────────────────────────
    property int pokeCount: 0
    property bool annoyed: false

    function poke() {
        pokeCount = Math.min(pokeCount + 1, 5)
        annoyed = true
        pokeRevertTimer.restart()
        // Reset idle counter — you just interacted!
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

    // annoyed overrides system mood when active
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

    // ── Wobble for stressed state ───────────────────────────────────
    property real wobbleAngle: 0
    SequentialAnimation {
        id: wobbleAnim
        loops: Animation.Infinite
        running: displayMood === "stressed" || displayMood === "overheating"
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
            Translate { y: displayMood === "sleeping" ? 0 : pet.bounceY },
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
            x: 11; y: displayMood === "vibing" ? 17 : 15
            width: displayMood === "sleeping" ? 8 : 8
            height: displayMood === "sleeping" ? 2 : (displayMood === "stressed" || displayMood === "overheating" ? 10 : 8)
            radius: displayMood === "sleeping" ? 1 : width / 2
            color: pet.eyeColor

            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

            // Pupil
            Rectangle {
                anchors.centerIn: parent
                width: 4; height: displayMood === "sleeping" ? 0 : 4
                radius: 2
                color: pet.pupilColor
                visible: displayMood !== "sleeping"
            }

            // Half-closed vibing lid (top)
            Rectangle {
                visible: displayMood === "vibing"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.4
                radius: parent.radius
                color: pet.bodyColor
            }
        }

        // Right eye
        Rectangle {
            id: rightEye
            x: 25; y: displayMood === "vibing" ? 17 : 15
            width: displayMood === "sleeping" ? 8 : 8
            height: displayMood === "sleeping" ? 2 : (displayMood === "stressed" || displayMood === "overheating" ? 10 : 8)
            radius: displayMood === "sleeping" ? 1 : width / 2
            color: pet.eyeColor

            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

            Rectangle {
                anchors.centerIn: parent
                width: 4; height: displayMood === "sleeping" ? 0 : 4
                radius: 2
                color: pet.pupilColor
                visible: displayMood !== "sleeping"
            }

            Rectangle {
                visible: displayMood === "vibing"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.4
                radius: parent.radius
                color: pet.bodyColor
            }
        }

        // ── Mouth ───────────────────────────────────────────────────
        // Happy smile
        Canvas {
            id: mouthCanvas
            x: 14; y: 26
            width: 16; height: 10
            visible: displayMood === "happy" || displayMood === "vibing"
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Qt.rgba(pet.eyeColor.r, pet.eyeColor.g, pet.eyeColor.b, 0.9)
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.moveTo(2, 2)
                ctx.quadraticCurveTo(8, 9, 14, 2)
                ctx.stroke()
            }
            onVisibleChanged: requestPaint()
        }

        // Stressed / overheating mouth (small "o")
        Rectangle {
            x: 19; y: 27
            width: 6; height: displayMood === "overheating" ? 7 : 5
            radius: 3
            color: pet.eyeColor
            visible: displayMood === "stressed" || displayMood === "overheating"
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

        // ── Cheeks (overheating) ────────────────────────────────────
        Rectangle {
            x: 4; y: 22
            width: 8; height: 5
            radius: 3
            color: root.color01
            opacity: displayMood === "overheating" ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        Rectangle {
            x: 32; y: 22
            width: 8; height: 5
            radius: 3
            color: root.color01
            opacity: displayMood === "overheating" ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }

    // ── Floating accessories ────────────────────────────────────────

    // Sweat drops (stressed)
    Repeater {
        model: displayMood === "stressed" || displayMood === "overheating" ? 2 : 0
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

    // Heat waves (overheating)
    Repeater {
        model: displayMood === "overheating" ? 3 : 0
        delegate: Text {
            id: heatWave
            text: "~"
            color: root.color01
            font.pixelSize: 10
            font.weight: Font.Bold
            x: 10 + index * 12

            SequentialAnimation on y {
                loops: Animation.Infinite
                PropertyAnimation { to: 4; duration: 0 }
                PropertyAnimation { to: -6; duration: 800 + index * 100; easing.type: Easing.OutSine }
                PropertyAnimation { to: 4; duration: 0 }
                PauseAnimation { duration: index * 150 }
            }

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                PropertyAnimation { to: 0; duration: 0 }
                PropertyAnimation { to: 0.7; duration: 300 }
                PropertyAnimation { to: 0; duration: 500 + index * 100 }
                PauseAnimation { duration: index * 150 }
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

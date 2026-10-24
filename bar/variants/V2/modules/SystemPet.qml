import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: pet
    required property var root
    signal clicked()

    height: 32
    readonly property real baseWidth: height
    property bool isHovered: petMa.containsMouse
    property bool showCuteWord: Math.random() < 0.5
    readonly property real cuteWordWidth: (showCuteWord && currentCuteWord !== "") ? (cuteWordLabel.implicitWidth + 4) : 0
    readonly property real pillTargetWidth: isHovered ? (6 + moodPill.implicitWidth) : 0
    readonly property real cuteWordTargetWidth: (showCuteWord && currentCuteWord !== "") ? (6 + cuteWordWidth) : 0
    width: baseWidth + pillTargetWidth + cuteWordTargetWidth
    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

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

    // Priority: curious (search bar open) > vibing > sleeping > daydreaming > bored > happy
    property bool curious: false
    readonly property string mood: {
        if (curious) return "curious"
        if (musicPlaying) return "vibing"
        if (idleSeconds > 120) return "sleeping"
        if (idleSeconds > 60) return "daydreaming"
        if (idleSeconds > 30) return "bored"
        return "happy"
    }

    readonly property string stateTitle: {
        switch (displayMood) {
            case "curious": return "Curious"
            case "vibing": return "Vibing"
            case "sleeping": return "Sleeping"
            case "daydreaming": return "Daydreaming"
            case "bored": return "Bored"
            case "happy":
            default: return "Happy"
        }
    }

    readonly property string stateDescription: {
        switch (displayMood) {
            case "curious": return "Search bar is open"
            case "vibing": return "Purring along to the music"
            case "sleeping": return "System idle for " + Math.round(idleSeconds / 60) + "m"
            case "daydreaming": return "System idle for over 1 minute"
            case "bored": return "System idle for over 30 seconds"
            case "happy":
            default: return "Content and purring (CPU " + cpu + "%)"
        }
    }

    readonly property string stateIcon: {
        switch (displayMood) {
            case "curious": return "search"
            case "vibing": return "music_note"
            case "sleeping": return "bedtime"
            case "daydreaming": return "cloud"
            case "bored": return "hourglass_empty"
            case "happy":
            default: return "pets"
        }
    }

    property string currentCuteWord: "bouncing"

    readonly property var allCuteWords: [
        "beaming", "booping", "bouncing", "brewing", "bubbling",
        "chasing", "churning", "conjuring", "cooking", "crafting",
        "cuddling", "dancing", "dazzling", "discovering", "doodling",
        "dreaming", "drifting", "exploring", "floating", "fluttering",
        "frolicking", "giggling", "gliding", "hopping", "hugging",
        "humming", "imagining", "jingling", "napping", "nibbling",
        "orbiting", "purring", "prancing", "roaming", "shimmying",
        "singing", "skipping", "snuggling", "soaring", "sparking",
        "spinning", "stargazing", "twirling", "waddling", "wiggling",
        "wobbling", "yawning", "zooming"
    ]

    function pickCuteWord() {
        var pool = allCuteWords
        switch (displayMood) {
            case "vibing":
                pool = ["dancing", "humming", "singing", "shimmying", "twirling", "bouncing", "jingling", "spinning"]
                break
            case "sleeping":
                pool = ["napping", "dreaming", "drifting", "snuggling", "cuddling", "yawning", "floating"]
                break
            case "daydreaming":
                pool = ["stargazing", "dreaming", "floating", "drifting", "imagining", "doodling", "wandering", "wishing"]
                break
            case "curious":
                pool = ["exploring", "discovering", "finding", "roaming", "chasing", "mapping"]
                break
            case "bored":
                pool = ["wobbling", "wibbling", "waddling", "nibbling", "yawning", "doodling"]
                break
            case "happy":
            default:
                pool = ["beaming", "booping", "bouncing", "bubbling", "giggling", "frolicking", "hopping", "purring", "sparking", "wiggling", "kneading", "pouncing"]
                break
        }
        var filtered = pool.filter(function(w) { return w !== currentCuteWord; })
        var choices = filtered.length > 0 ? filtered : pool
        currentCuteWord = choices[Math.floor(Math.random() * choices.length)]
    }

    function rollCuteWord() {
        if (celebrating || shrugging) return
        showCuteWord = (Math.random() < 0.5)
        if (showCuteWord) {
            pickCuteWord()
        }
    }

    Timer {
        id: wordCycleTimer
        interval: 35000
        repeat: true
        running: true
        onTriggered: {
            if (!pet.isHovered) {
                pet.rollCuteWord()
            }
        }
    }

    // ── Poke hop animation ──────────────────────────────────────────
    property real pokeScale: 1.0
    SequentialAnimation {
        id: pokeHopAnim
        NumberAnimation { target: pet; property: "pokeScale"; to: 1.18; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: pet; property: "pokeScale"; to: 0.94; duration: 110; easing.type: Easing.InOutQuad }
        NumberAnimation { target: pet; property: "pokeScale"; to: 1.0; duration: 100; easing.type: Easing.OutBack }
    }

    // ── Search-submit celebration: a hop, a happy word and a floating heart ──
    property bool celebrating: false

    Timer {
        id: celebrateTimer
        interval: 2200
        onTriggered: pet.celebrating = false
    }

    function celebrate() {
        var words = ["purring", "booping", "beaming", "pouncing", "kneading", "giggling", "bouncing"]
        pokeHopAnim.restart()
        idleSeconds = 0
        currentCuteWord = words[Math.floor(Math.random() * words.length)]
        showCuteWord = true
        celebrating = true
        celebrateTimer.restart()
    }

    // ── Shrug animation ─────────────────────────────────────────────
    property bool shrugging: false
    property real shrugPaws: 0.0
    property real shrugTilt: 0.0

    SequentialAnimation {
        id: shrugAnim
        onStarted: pet.shrugging = true
        onFinished: {
            pet.shrugging = false
            pet.shrugPaws = 0.0
            pet.shrugTilt = 0.0
        }

        // 1. Lift paws & tilt head quizzically
        ParallelAnimation {
            NumberAnimation { target: pet; property: "shrugPaws"; to: 1.0; duration: 180; easing.type: Easing.OutBack }
            NumberAnimation { target: pet; property: "shrugTilt"; to: 8.5; duration: 180; easing.type: Easing.OutBack }
            NumberAnimation { target: pet; property: "pokeScale"; to: 1.06; duration: 180; easing.type: Easing.OutQuad }
        }

        // 2. Playful little wiggle while holding paws up
        SequentialAnimation {
            loops: 2
            NumberAnimation { target: pet; property: "shrugTilt"; to: 5.5; duration: 160; easing.type: Easing.InOutSine }
            NumberAnimation { target: pet; property: "shrugTilt"; to: 9.5; duration: 160; easing.type: Easing.InOutSine }
        }

        // 3. Hold the cute pose
        PauseAnimation { duration: 650 }

        // 4. Settle back down smoothly
        ParallelAnimation {
            NumberAnimation { target: pet; property: "shrugPaws"; to: 0.0; duration: 220; easing.type: Easing.InOutQuad }
            NumberAnimation { target: pet; property: "shrugTilt"; to: 0.0; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: pet; property: "pokeScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
        }
    }

    function shrug() {
        var words = ["shrug", "dunno", "meh", "who knows?", "hehe", "idk", "puzzled"]
        currentCuteWord = words[Math.floor(Math.random() * words.length)]
        showCuteWord = true
        idleSeconds = 0
        shrugAnim.restart()
    }

    function poke() {
        pokeHopAnim.restart()
        idleSeconds = 0
        rollCuteWord()
    }

    property string displayMood: "happy"
    onMoodChanged: moodTransition.restart()
    onCuriousChanged: {
        if (curious) displayMood = "curious"
        else moodTransition.restart()
    }
    onDisplayMoodChanged: rollCuteWord()

    Timer {
        id: moodTransition
        interval: 300
        onTriggered: pet.displayMood = pet.mood
    }

    Component.onCompleted: {
        displayMood = mood
        rollCuteWord()
    }

    // ── Theme colors ────────────────────────────────────────────────
    readonly property color bodyColor: root.seal
    readonly property color bodyLight: Qt.lighter(root.seal, 1.3)
    // Eyes, mouth and whiskers contrast against the face colour instead of the theme paper.
    readonly property real bodyLuma: 0.299 * bodyColor.r + 0.587 * bodyColor.g + 0.114 * bodyColor.b
    readonly property color faceInk: bodyLuma > 0.55 ? "#2B2026" : "#FFFFFF"
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

    // ── Blinking ────────────────────────────────────────────────────
    property real blink: 1.0
    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: pet; property: "blink"; to: 0.1; duration: 90; easing.type: Easing.InQuad }
        NumberAnimation { target: pet; property: "blink"; to: 1.0; duration: 130; easing.type: Easing.OutQuad }
    }
    Timer {
        interval: 3200
        running: true
        repeat: true
        onTriggered: {
            blinkAnim.restart()
            interval = 2500 + Math.random() * 3500
        }
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
        anchors.left: parent.left
        anchors.leftMargin: (pet.baseWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        scale: (36 / 52) * pet.pokeScale
        transform: [
            Translate { y: displayMood === "sleeping" ? 0 : (displayMood === "daydreaming" ? pet.floatY : pet.bounceY) },
            Rotation {
                angle: pet.shrugging ? pet.shrugTilt : (displayMood === "curious" ? 7 : 0)
                origin.x: bodyContainer.width / 2
                origin.y: bodyContainer.height / 2
                Behavior on angle { enabled: !pet.shrugging; NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            },
            Scale {
                xScale: displayMood === "sleeping" ? pet.breathScale : 1.0
                yScale: displayMood === "sleeping" ? pet.breathScale : 1.0
                origin.x: bodyContainer.width / 2
                origin.y: bodyContainer.height / 2
            }
        ]

        // Cat ears (rounded, with soft pink inner ear)
        Canvas {
            id: earsCanvas
            anchors.fill: parent
            property color c: pet.bodyColor
            onCChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                function ear(mx) {
                    function X(x) { return mx ? 44 - x : x }
                    ctx.fillStyle = c; ctx.strokeStyle = c; ctx.lineWidth = 5
                    ctx.beginPath(); ctx.moveTo(X(6), 22); ctx.lineTo(X(7), 4); ctx.lineTo(X(21), 11); ctx.closePath()
                    ctx.fill(); ctx.stroke()
                    ctx.fillStyle = "rgba(255,179,193,0.85)"; ctx.strokeStyle = "rgba(255,179,193,0.85)"; ctx.lineWidth = 2
                    ctx.beginPath(); ctx.moveTo(X(9), 17); ctx.lineTo(X(9.5), 8); ctx.lineTo(X(16), 12); ctx.closePath()
                    ctx.fill(); ctx.stroke()
                }
                ear(false); ear(true)
            }
        }

        // Left shrug paw (\)
        Rectangle {
            id: leftPaw
            x: -2 - (pet.shrugPaws * 5)
            y: 28 - (pet.shrugPaws * 10)
            width: 10
            height: 7
            radius: 3.5
            color: pet.bodyColor
            rotation: -28
            opacity: pet.shrugPaws
            visible: opacity > 0.01

            // Paw pad (pink bean)
            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 3
                radius: 1.5
                color: "#ffb3c1"
            }
        }

        // Right shrug paw (/)
        Rectangle {
            id: rightPaw
            x: 36 + (pet.shrugPaws * 5)
            y: 28 - (pet.shrugPaws * 10)
            width: 10
            height: 7
            radius: 3.5
            color: pet.bodyColor
            rotation: 28
            opacity: pet.shrugPaws
            visible: opacity > 0.01

            // Paw pad (pink bean)
            Rectangle {
                anchors.centerIn: parent
                width: 4
                height: 3
                radius: 1.5
                color: "#ffb3c1"
            }
        }

        // Face (wide, squishy chibi head)
        Rectangle {
            id: body
            x: 0; y: 5
            width: 44; height: 37
            radius: 18.5
            color: pet.bodyColor

            // Highlight / shine spot
            Rectangle {
                x: 9; y: 4
                width: 8; height: 5
                radius: 2.5
                color: pet.bodyLight
                opacity: 0.55
            }

            // Tabby forehead stripes
            Repeater {
                model: 3
                delegate: Rectangle {
                    x: 20 + (index - 1) * 4 + (index === 1 ? 0 : 0)
                    y: 2
                    width: 2
                    height: index === 1 ? 7 : 5
                    radius: 1
                    color: Qt.darker(pet.bodyColor, 1.35)
                    opacity: 0.45
                }
            }
        }

        // ── Eyes (big, glossy, with sparkle highlights) ─────────────
        Repeater {
            model: 2
            delegate: Item {
                id: eyeSlot
                readonly property bool isLeft: index === 0
                readonly property bool big: displayMood === "daydreaming" || displayMood === "curious"
                readonly property bool closed: displayMood === "sleeping"
                x: isLeft ? 8 : 26
                y: (displayMood === "vibing" || displayMood === "bored") ? 20 : 18
                width: 10; height: 11
                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                // Open eye
                Rectangle {
                    id: eyeball
                    anchors.centerIn: parent
                    width: eyeSlot.big ? 11 : 10
                    height: eyeSlot.big ? 12 : 11
                    radius: width / 2
                    color: pet.faceInk
                    visible: !eyeSlot.closed
                    transform: Scale { yScale: pet.blink; origin.y: eyeball.height / 2 }
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    // Pupil
                    Rectangle {
                        id: pupil
                        width: 7; height: 8
                        radius: 3.5
                        color: "transparent"
                        x: (parent.width - width) / 2 + (displayMood === "bored" ? -1.5 : (displayMood === "curious" ? 1.5 : 0))
                        y: (parent.height - height) / 2 + (displayMood === "daydreaming" ? -1.5 : (displayMood === "curious" ? -1 : 0.5))
                        Behavior on x { NumberAnimation { duration: 200 } }
                        Behavior on y { NumberAnimation { duration: 200 } }

                        // Sparkles
                        Rectangle { x: 3.8; y: 1; width: 2.6; height: 2.6; radius: 1.3; color: pet.bodyColor; opacity: 0.95 }
                        Rectangle { x: 1; y: 4.8; width: 1.5; height: 1.5; radius: 0.75; color: pet.bodyColor; opacity: 0.7 }
                    }

                    // Sleepy lids
                    Rectangle {
                        visible: displayMood === "vibing" || displayMood === "bored"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height * 0.42
                        radius: parent.radius
                        color: pet.bodyColor
                    }
                }

                // Closed eye (happy "u" arc) while sleeping
                Canvas {
                    anchors.centerIn: parent
                    width: 10; height: 6
                    visible: eyeSlot.closed
                    property color ink: pet.faceInk
                    onInkChanged: requestPaint()
                    onVisibleChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = Qt.rgba(pet.faceInk.r, pet.faceInk.g, pet.faceInk.b, 0.95)
                        ctx.lineWidth = 1.8
                        ctx.lineCap = "round"
                        ctx.beginPath(); ctx.moveTo(1, 1.5); ctx.quadraticCurveTo(5, 7, 9, 1.5); ctx.stroke()
                    }
                }
            }
        }

        // ── Blush cheeks ────────────────────────────────────────────
        Rectangle {
            x: 2.5; y: 27
            width: 8; height: 5; radius: 2.5
            color: "#ffb3c1"
            opacity: displayMood === "daydreaming" ? 0.75 : 0.42
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
        Rectangle {
            x: 33.5; y: 27
            width: 8; height: 5; radius: 2.5
            color: "#ffb3c1"
            opacity: displayMood === "daydreaming" ? 0.75 : 0.42
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        // ── Nose & mouth ────────────────────────────────────────────
        // Tiny heart-ish nose
        Rectangle {
            x: 20; y: 28
            width: 4; height: 3
            radius: 1.5
            color: "#ffb3c1"
        }

        // "ω" cat mouth
        Canvas {
            id: mouthCanvas
            x: 17; y: 30
            width: 10; height: 7
            property string m: pet.displayMood
            onMChanged: requestPaint()
            property color ink: pet.faceInk
            onInkChanged: requestPaint()
            visible: displayMood !== "bored"
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Qt.rgba(pet.faceInk.r, pet.faceInk.g, pet.faceInk.b, 0.9)
                ctx.lineWidth = 1.4
                ctx.lineCap = "round"
                var k = pet.displayMood === "curious" ? 3 : (pet.displayMood === "sleeping" ? 2.5 : (pet.displayMood === "daydreaming" || pet.displayMood === "vibing" ? 5.5 : 4.5))
                ctx.beginPath()
                ctx.moveTo(5, 0.5); ctx.quadraticCurveTo(3.8, k, 0.8, 2)
                ctx.moveTo(5, 0.5); ctx.quadraticCurveTo(6.2, k, 9.2, 2)
                ctx.stroke()
            }
            onVisibleChanged: requestPaint()
        }

        // Whiskers
        Repeater {
            model: 4
            delegate: Rectangle {
                property bool onLeft: index < 2
                property int row: index % 2
                x: onLeft ? 0 : 38
                y: 31 + row * 3
                width: 6; height: 1
                radius: 0.5
                color: pet.faceInk
                opacity: 0.5
                rotation: (onLeft ? 1 : -1) * (row === 0 ? 10 : -10)
            }
        }

        // Bored mouth (flat little line)
        Rectangle {
            x: 19.5; y: 32.5
            width: 5; height: 1.6
            radius: 0.8
            color: pet.faceInk
            opacity: 0.8
            visible: displayMood === "bored"
        }
    }
    
    // Hitbox for poke & hover detection
    MouseArea {
        id: petMa
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: isHovered ? parent.width : pet.baseWidth
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                pet.shrug()
            } else {
                pet.poke()
                pet.clicked()
            }
        }
    }

    // ── Cute Mood Pill to the Right (Opens on hover showing State only) ──
    Rectangle {
        id: moodPill
        z: 25
        anchors.left: parent.left
        anchors.leftMargin: pet.baseWidth + 6
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        radius: 12
        clip: true

        implicitWidth: pillRow.implicitWidth + 18
        width: isHovered ? implicitWidth : 0
        opacity: isHovered ? 1.0 : 0.0
        scale: isHovered ? 1.0 : 0.85

        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
        border.width: 1
        border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35)

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 5

            IconText {
                anchors.verticalCenter: parent.verticalCenter
                text: pet.stateIcon
                color: root.seal
                font.pixelSize: 13
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pet.stateTitle
                color: root.seal
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }

    // ── Static Cute Mood Word outside the pill (~50% probability) ───
    Item {
        id: cuteWordItem
        z: 20
        anchors.left: moodPill.right
        anchors.leftMargin: pet.isHovered ? 6 : 0
        anchors.verticalCenter: parent.verticalCenter
        height: 24
        width: (pet.showCuteWord && pet.currentCuteWord !== "") ? cuteWordLabel.implicitWidth : 0
        opacity: (pet.showCuteWord && pet.currentCuteWord !== "") ? 0.75 : 0.0
        visible: opacity > 0.01

        Behavior on anchors.leftMargin { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 250 } }
        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Text {
            id: cuteWordLabel
            anchors.verticalCenter: parent.verticalCenter
            text: pet.currentCuteWord
            color: root.ink
            font.family: root.barFont
            font.pixelSize: 11
            font.italic: true
            font.weight: Font.Medium
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    pet.shrug()
                } else {
                    pet.poke()
                    pet.clicked()
                }
            }
        }
    }

    // ── Floating accessories ────────────────────────────────────────

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

    // ── Shrug mark indicator ─────────────────────────────────────────
    Text {
        text: "~?"
        color: root.seal
        font.family: root.barFont
        font.pixelSize: 12
        font.weight: Font.Bold
        x: 34
        y: pet.shrugging ? -4 : 6
        opacity: pet.shrugging ? 0.95 : 0
        scale: pet.shrugging ? 1.0 : 0.4
        visible: opacity > 0.01
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    }

    // ── Celebration heart (search submitted) ────────────────────────
    Text {
        text: "♥"
        color: "#ff7a93"
        font.pixelSize: 11
        x: 33
        y: pet.celebrating ? -4 : 6
        opacity: pet.celebrating ? 0.95 : 0
        scale: pet.celebrating ? 1.0 : 0.4
        visible: opacity > 0.01
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    }

    // ── Curious indicator (search bar open) ─────────────────────────
    Text {
        text: "?"
        color: root.seal
        font.family: root.barFont
        font.pixelSize: 12
        font.weight: Font.Bold
        x: 35; y: -3
        opacity: displayMood === "curious" ? 0.95 : 0
        scale: displayMood === "curious" ? 1.0 : 0.4
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
    }
}

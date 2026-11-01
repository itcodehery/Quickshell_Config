import QtQuick
import QtQuick.Effects
import Quickshell

Item {
    id: bgRoot
    anchors.fill: parent

    // ── Dynamic Frosted Workspace Depth Properties ──
    property real bgBlur: 0.0
    property real bgBrightness: 0.0
    property real bgScale: 1.00
    property real bgDim: 0.0
    property bool transitionStarted: false

    function startEntranceTransition() {
        if (!transitionStarted && bgRoot.width > 0 && bgRoot.height > 0) {
            transitionStarted = true
            transitionAnim.restart()
        }
    }

    onWidthChanged: if (desktopSnapshot.status === Image.Ready) startEntranceTransition()
    onHeightChanged: if (desktopSnapshot.status === Image.Ready) startEntranceTransition()

    Timer {
        id: fallbackTransitionTimer
        interval: 180
        running: !bgRoot.transitionStarted
        onTriggered: bgRoot.startEntranceTransition()
    }

    ParallelAnimation {
        id: transitionAnim

        NumberAnimation {
            target: bgRoot
            property: "bgBlur"
            from: 0.0
            to: 0.88
            duration: 520
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bgRoot
            property: "bgBrightness"
            from: 0.0
            to: -0.20
            duration: 520
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bgRoot
            property: "bgScale"
            from: 1.00
            to: 0.97
            duration: 560
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: bgRoot
            property: "bgDim"
            from: 0.0
            to: 0.38
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    // ── 0. DEEP BASE RECTANGLE ──────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#0a0c0e"
    }

    // ── 1. DESKTOP SNAPSHOT (With dynamic wallpaper fallback) ───
    Image {
        id: desktopSnapshot
        anchors.fill: parent
        source: "file://" + (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-lock-bg.png"
        fillMode: Image.PreserveAspectCrop
        cache: false
        asynchronous: false
        visible: false
        onStatusChanged: {
            if (status === Image.Error) {
                source = "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
            } else if (status === Image.Ready) {
                bgRoot.startEntranceTransition()
            }
        }
    }

    // ── 2. FROSTED WORKSPACE DEPTH LAYER ────────────────────────
    Item {
        id: bgContainer
        anchors.fill: parent
        scale: bgRoot.bgScale
        transformOrigin: Item.Center

        MultiEffect {
            id: bgEffect
            source: desktopSnapshot
            anchors.fill: parent
            blurEnabled: true
            blurMax: 48
            blur: bgRoot.bgBlur
            brightness: bgRoot.bgBrightness
            saturation: -0.08
        }
    }

    // Darkening overlay & edge vignette
    Rectangle {
        id: dimOverlay
        anchors.fill: parent
        color: "#000000"
        opacity: bgRoot.bgDim
    }

    Rectangle {
        anchors.fill: parent
        opacity: bgRoot.bgDim * 0.75
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.40) }
            GradientStop { position: 0.15; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.85; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.55) }
        }
    }
}

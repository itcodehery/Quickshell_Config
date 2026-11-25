import QtQuick
import ".."

Item {
    id: trackRoot

    required property var root
    property real value: 0              // 0..100
    property bool sliding: false
    property color accentColor: (root && root.seal) ? root.seal : "#22d3ee"
    property color unfilledColor: {
        if (!root) return Qt.rgba(1, 1, 1, 0.2)
        if (root.isLightMode) return Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
        return Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
    }
    property string style: (root && root.sliderStyle) ? root.sliderStyle : "android17"

    readonly property real clampedVal: Math.max(0, Math.min(100, value))
    readonly property real progress: clampedVal / 100.0
    readonly property real trackW: width
    readonly property real handleX: Math.round(progress * Math.max(1, trackW - 4))

    // ═════════════════════════════════════════════════════════════════════════
    // ── 1. ANDROID 17 STYLE: Thinner split bar with taller vertical handle ───
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: a17Style
        anchors.fill: parent
        visible: trackRoot.style === "android17"

        readonly property real barHeight: 14
        readonly property real gap: 4

        // Filled Track (Left of drag line)
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, trackRoot.handleX - a17Style.gap)
            height: a17Style.barHeight
            radius: a17Style.barHeight / 2
            color: trackRoot.accentColor
            Behavior on width { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
        }

        // Unfilled Track (Right of drag line)
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Math.min(trackRoot.trackW, trackRoot.handleX + 4 + a17Style.gap)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: a17Style.barHeight
            radius: a17Style.barHeight / 2
            color: trackRoot.unfilledColor
            Behavior on anchors.leftMargin { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
        }

        // Vertical Drag Line (Taller than the bar)
        Rectangle {
            x: trackRoot.handleX
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: trackRoot.sliding ? 28 : 26
            radius: 2
            color: trackRoot.accentColor
            scale: trackRoot.sliding ? 1.08 : 1.0
            Behavior on height { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on x { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 2. iOS STYLE: Full capsule fluid fill with expanding pill ────────────
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: iosStyle
        anchors.fill: parent
        visible: trackRoot.style === "ios"

        property real capsuleH: trackRoot.sliding ? 26 : 22
        Behavior on capsuleH { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

        // Background Capsule
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: iosStyle.capsuleH + 8
            radius: height / 3
            color: trackRoot.unfilledColor
            border.width: (root && root.isLightMode) ? 1 : 0
            border.color: (root && root.cardBorderColor) ? root.cardBorderColor : "transparent"
            clip: true

            // Filled Fluid Progress
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, parent.width * trackRoot.progress))
                radius: parent.radius
                color: trackRoot.accentColor
                Behavior on width { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 3. ANDROID 12 STYLE: Material You thick track with inset thumb ───────
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: a12Style
        anchors.fill: parent
        visible: trackRoot.style === "android12"

        property real barH: trackRoot.sliding ? 26 : 22
        Behavior on barH { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

        // Track Capsule
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: a12Style.barH
            radius: height / 2
            color: trackRoot.unfilledColor
            border.width: (root && root.isLightMode) ? 1 : 0
            border.color: (root && root.cardBorderColor) ? root.cardBorderColor : "transparent"
            clip: true

            // Filled progress
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, parent.width * trackRoot.progress))
                radius: parent.radius
                color: trackRoot.accentColor
                Behavior on width { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
            }
        }

        // Inset Thumb Indicator
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            readonly property real targetX: Math.max(4, Math.min(trackRoot.trackW - width - 4, (trackRoot.trackW * trackRoot.progress) - width - 4))
            x: targetX
            width: trackRoot.sliding ? 18 : 14
            height: 14
            radius: 7
            color: root.isLightMode ? root.paper : "#ffffff"
            opacity: trackRoot.progress > 0.05 ? 0.95 : 0.0
            scale: trackRoot.sliding ? 1.08 : 1.0
            Behavior on x { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 4. COMET PULSE STYLE: Sweeping energy shimmer & morphing pill orb ──
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: pulseStyle
        anchors.fill: parent
        visible: trackRoot.style === "minimal"

        property real sweepFrac: 0.0
        NumberAnimation on sweepFrac {
            from: -0.25
            to: 1.25
            duration: 1800
            loops: Animation.Infinite
            running: pulseStyle.visible
        }

        // Unfilled recessed track
        Rectangle {
            id: pulseTrackBg
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: trackRoot.sliding ? 10 : 7
            radius: height / 2
            color: trackRoot.unfilledColor
            clip: true
            Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Filled accent bar
            Rectangle {
                id: pulseFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, trackRoot.handleX))
                radius: height / 2
                color: trackRoot.accentColor
                clip: true
                Behavior on width { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }

                // Sweeping light shimmer inside the filled bar
                Rectangle {
                    width: Math.max(18, pulseFill.width * 0.35)
                    height: parent.height
                    x: pulseStyle.sweepFrac * Math.max(1, pulseFill.width) - width / 2
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.45) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        // Morphing Orb + Halo Handle
        Item {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(trackRoot.trackW - width, trackRoot.handleX - width / 2))
            width: 24
            height: 24
            Behavior on x { enabled: !trackRoot.sliding; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            // Breathing outer aura
            Rectangle {
                anchors.centerIn: parent
                width: trackRoot.sliding ? 24 : 18
                height: width
                radius: width / 2
                color: Qt.rgba(trackRoot.accentColor.r, trackRoot.accentColor.g, trackRoot.accentColor.b, trackRoot.sliding ? 0.30 : 0.16)
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }

            // Inner contrasting pill thumb
            Rectangle {
                anchors.centerIn: parent
                width: trackRoot.sliding ? 14 : 10
                height: trackRoot.sliding ? 22 : 16
                radius: width / 2
                color: (root && root.paper) ? root.paper : "#181715"
                border.width: 2.5
                border.color: trackRoot.accentColor
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 5. KINETIC EQUALIZER STYLE: Magnetic spring-scaled capsule bars ───────
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: eqStyle
        anchors.fill: parent
        visible: trackRoot.style === "blocky"

        readonly property real safeW: Math.max(40, trackRoot.trackW)
        readonly property int barCount: Math.max(8, Math.min(26, Math.floor(safeW / 8)))
        property real pulsePhase: 0

        NumberAnimation on pulsePhase {
            from: 0
            to: Math.PI * 2
            duration: 1400
            loops: Animation.Infinite
            running: eqStyle.visible
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: Math.max(2, Math.floor((eqStyle.safeW - eqStyle.barCount * 4) / Math.max(1, eqStyle.barCount - 1)))

            Repeater {
                model: eqStyle.barCount

                Rectangle {
                    id: eqBar
                    required property int index
                    readonly property real frac: (index + 0.5) / Math.max(1, eqStyle.barCount)
                    readonly property bool isLit: frac <= trackRoot.progress + 0.02
                    readonly property real dist: Math.abs(frac - trackRoot.progress)
                    readonly property real prox: Math.max(0.0, 1.0 - dist * 5.0)
                    readonly property bool isFocus: dist < (0.65 / Math.max(1, eqStyle.barCount))
                    readonly property real ripple: isLit ? (Math.sin(eqStyle.pulsePhase - index * 0.45) * 1.5 + 1.5) : 0

                    y: Math.round((parent.height - height) / 2)
                    width: isFocus ? (trackRoot.sliding ? 6 : 5) : 4
                    height: Math.min(parent.height, Math.round(
                        (isLit ? 9 : 6)
                        + prox * (trackRoot.sliding ? 14 : 9)
                        + ripple
                    ))
                    radius: width / 2
                    color: isFocus
                        ? ((root && root.isLightMode) ? "#1c1a18" : "#f5f2ed")
                        : (isLit ? trackRoot.accentColor : trackRoot.unfilledColor)
                    border.width: isFocus ? 1.5 : 0
                    border.color: trackRoot.accentColor

                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 140 } }
                }
            }
        }
    }
}

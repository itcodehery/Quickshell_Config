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
            height: iosStyle.capsuleH
            radius: height / 2
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
    // ── 4. MINIMAL STYLE: Hairline track with floating circular knob ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: minStyle
        anchors.fill: parent
        visible: trackRoot.style === "minimal"

        readonly property real lineH: 4
        readonly property real knobDiam: trackRoot.sliding ? 20 : 16

        // Background Hairline
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: minStyle.lineH
            radius: minStyle.lineH / 2
            color: trackRoot.unfilledColor
        }

        // Filled Hairline
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(parent.width, trackRoot.handleX))
            height: minStyle.lineH
            radius: minStyle.lineH / 2
            color: trackRoot.accentColor
            Behavior on width { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
        }

        // Floating Circular Knob with Shadow
        Rectangle {
            id: minKnob
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(trackRoot.trackW - width, trackRoot.handleX - width / 2))
            width: minStyle.knobDiam
            height: minStyle.knobDiam
            radius: width / 2
            color: trackRoot.accentColor
            border.width: 2
            border.color: (root && root.paper) ? root.paper : "#181715"

            Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Behavior on x { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }

            // Drop shadow for floating effect
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 4
                height: parent.height + 4
                radius: width / 2
                color: Qt.rgba(0, 0, 0, (root && root.isLightMode) ? 0.12 : 0.35)
                z: -1
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 5. CYBER BLOCK STYLE: Industrial chamfered rail with block thumb ────
    // ═════════════════════════════════════════════════════════════════════════
    Item {
        id: blockStyle
        anchors.fill: parent
        visible: trackRoot.style === "blocky"

        readonly property real railH: 16

        // Background Rail
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: blockStyle.railH
            radius: 3
            color: trackRoot.unfilledColor
            border.width: (root && root.isLightMode) ? 1 : 0
            border.color: (root && root.cardBorderColor) ? root.cardBorderColor : "transparent"
            clip: true

            // Filled Segment
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(0, Math.min(parent.width, trackRoot.handleX))
                radius: 3
                color: trackRoot.accentColor
                Behavior on width { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
            }
        }

        // Cyber Thumb Block
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(trackRoot.trackW - width, trackRoot.handleX - width / 2))
            width: trackRoot.sliding ? 10 : 8
            height: trackRoot.sliding ? 26 : 22
            radius: 2
            color: (root && root.isLightMode) ? "#2a2826" : "#f2efea"
            border.width: 1
            border.color: trackRoot.accentColor

            Behavior on x { enabled: !trackRoot.sliding; NumberAnimation { duration: 120 } }
            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on height { NumberAnimation { duration: 120 } }

            // Center neon groove
            Rectangle {
                anchors.centerIn: parent
                width: 2
                height: parent.height - 10
                radius: 1
                color: trackRoot.accentColor
            }
        }
    }
}

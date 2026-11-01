import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell.Services.UPower
import "../modules"
import "../utils/IconMap.js" as IconMap

Item {
    id: overlaysRoot
    required property var barSlot
    required property var island
    required property var notifPeekTimer
    anchors.fill: parent

    property alias islandOsdItem: islandOsdItem
    property alias islandNotifPeekItem: islandNotifPeekItem
    property alias islandDictationItem: islandDictationItem
    property alias islandChargingItem: islandChargingItem

    // Volume / brightness OSD: one wide slider pill with the icon and percentage
    // drawn inside it (same look as the dashboard sliders).
    Rectangle {
        id: islandOsdItem
        anchors.centerIn: parent

        width: 290
        height: 27
        radius: height / 2
        color: "transparent"
        clip: true
        opacity: overlaysRoot.island.islandCollapsedOpacity * overlaysRoot.island.osdProgress * (1.0 - overlaysRoot.island.notifPeekProgress) * (1.0 - overlaysRoot.island.dictationProgress) * (1.0 - overlaysRoot.island.chargingProgress)
        visible: opacity > 0.001

        readonly property bool muted: overlaysRoot.island.osdKind === "audio-muted"
        readonly property color sliderColor: muted
            ? Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.45)
            : overlaysRoot.barSlot.root.seal
        readonly property real val: Math.max(0, Math.min(100, muted ? 0 : overlaysRoot.island.osdValue))
        readonly property color textColorOnFill: {
            var c = islandOsdItem.sliderColor
            var luma = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
            return luma > 0.5 ? "#1e1b18" : "#ffffff"
        }

        transform: Translate {
            y: (1.0 - overlaysRoot.island.osdProgress) * (overlaysRoot.barSlot.root.barPosition === "bottom" ? 6 : -6)
        }

        // Fill: inset from the track edges, every corner fully rounded,
        // followed by the signature vertical marker
        Item {
            id: osdFillItem
            readonly property real inset: 2
            readonly property real val: islandOsdItem.val
            readonly property real maxGap: 10
            readonly property real gap: val > 85 ? maxGap * (100 - val) / 15.0 : maxGap
            readonly property real barOpacity: val > 85 ? (100 - val) / 15.0 : 1.0
            readonly property real minPillW: Math.max(parent.height - 2 * inset, osdTextRow.implicitWidth + 24)

            x: inset
            y: inset
            height: parent.height - 2 * inset
            width: val > 0 ? Math.max(minPillW + maxGap, (parent.width - 2 * inset) * (val / 100.0)) : 0
            visible: val > 0

            Behavior on width {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }

            // The actual fill
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(parent.height, parent.width - osdFillItem.gap)
                radius: height / 2
                color: islandOsdItem.sliderColor
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            // The vertical line marker
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: osdFillItem.maxGap
                height: parent.height
                color: "transparent"
                opacity: osdFillItem.barOpacity

                Rectangle {
                    anchors.centerIn: parent
                    width: 3.5
                    height: parent.height - 6
                    radius: 1.75
                    color: islandOsdItem.sliderColor
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }
        }

        // Icon + percentage sit inside the slider
        Row {
            id: osdTextRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            spacing: 8
            z: 5

            IconText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 15
                color: islandOsdItem.textColorOnFill
                text: {
                    if (overlaysRoot.island.osdKind === "brightness") {
                        return IconMap.icon("light_mode")
                    } else if (overlaysRoot.island.osdKind === "audio-muted") {
                        return IconMap.icon("volume_off")
                    } else {
                        if (overlaysRoot.island.osdValue <= 0) return IconMap.icon("volume_mute")
                        if (overlaysRoot.island.osdValue <= 50) return IconMap.icon("volume_down")
                        return IconMap.icon("volume_up")
                    }
                }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: (islandOsdItem.muted ? "0" : String(overlaysRoot.island.osdValue)) + "%"
                color: islandOsdItem.textColorOnFill
                font.family: overlaysRoot.barSlot.root.barFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }

    Rectangle {
        id: islandNotifPeekItem
        anchors.centerIn: parent

        readonly property bool hasBody: overlaysRoot.island.notifPeekBody !== ""
        readonly property real maxContentWidth: Math.min(540, overlaysRoot.barSlot.width - 60)
        readonly property real desiredTextWidth: Math.max(headerRow.implicitWidth, Math.max(summaryText.implicitWidth, Math.min(380, bodyText.implicitWidth)))
        readonly property real contentTargetWidth: 16 + (hasBody ? 38 : 24) + 12 + Math.max(160, desiredTextWidth) + 12 + 24 + 16
        readonly property int desiredCardHeight: hasBody ? Math.max(70, notifContentCol.implicitHeight + 22) : 46

        width: Math.min(maxContentWidth, Math.max(300, contentTargetWidth))
        height: overlaysRoot.island.height
        color: "transparent"
        border.width: 0
        clip: true
        opacity: overlaysRoot.island.islandCollapsedOpacity * overlaysRoot.island.notifPeekProgress * (1.0 - overlaysRoot.island.dictationProgress) * (1.0 - overlaysRoot.island.chargingProgress)
        visible: opacity > 0.001

        transform: Translate {
            y: (1.0 - overlaysRoot.island.notifPeekProgress) * (overlaysRoot.barSlot.root.barPosition === "bottom" ? 6 : -6)
        }

        HoverHandler {
            id: peekHov
            onHoveredChanged: {
                if (hovered) {
                    overlaysRoot.notifPeekTimer.stop()
                } else if (overlaysRoot.island.notifPeekActive) {
                    overlaysRoot.notifPeekTimer.interval = 2200
                    overlaysRoot.notifPeekTimer.restart()
                }
            }
        }

        // Background click invokes notification action
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                overlaysRoot.island.notifPeekActive = false
                overlaysRoot.island.notifPeekProgress = 0.0
                overlaysRoot.barSlot.root.invokeNotification(overlaysRoot.island.notifPeekId, overlaysRoot.island.notifPeekApp)
            }
        }

        Row {
            id: notifPeekContentRow
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 12

            // App icon / badge
            Rectangle {
                id: notifIconBadge
                width: islandNotifPeekItem.hasBody ? 38 : 24
                height: width
                radius: islandNotifPeekItem.hasBody ? 11 : (height / 2)
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.08)
                border.width: 0

                Image {
                    id: notifImg
                    anchors.fill: parent
                    anchors.margins: islandNotifPeekItem.hasBody ? 4 : 2
                    visible: overlaysRoot.island.notifPeekIcon !== "" && (overlaysRoot.island.notifPeekIcon.startsWith("file://") || overlaysRoot.island.notifPeekIcon.startsWith("/"))
                    source: visible ? overlaysRoot.island.notifPeekIcon : ""
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    smooth: true
                }

                IconText {
                    anchors.centerIn: parent
                    visible: !notifImg.visible
                    font.pixelSize: islandNotifPeekItem.hasBody ? 18 : 13
                    color: overlaysRoot.barSlot.accent
                    text: overlaysRoot.island.getNotifIcon(overlaysRoot.island.notifPeekApp, overlaysRoot.island.notifPeekIcon)
                }
            }

            // Title + multi-line body column
            Column {
                id: notifContentCol
                width: parent.width - notifIconBadge.width - notifCloseBtn.width - notifPeekContentRow.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2.5

                // App / Category header row (when body is present)
                Row {
                    id: headerRow
                    visible: islandNotifPeekItem.hasBody && overlaysRoot.island.notifPeekApp !== "" && overlaysRoot.island.notifPeekApp.toLowerCase() !== overlaysRoot.island.notifPeekSummary.toLowerCase()
                    spacing: 6
                    width: parent.width

                    Text {
                        text: overlaysRoot.barSlot.formatTitleCase(overlaysRoot.island.notifPeekApp.replace(/[-_]/g, " "))
                        font.family: overlaysRoot.barSlot.root.barFont || "Genova"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: overlaysRoot.barSlot.accent
                        elide: Text.ElideRight
                    }

                    Text {
                        text: "·"
                        font.family: overlaysRoot.barSlot.root.barFont || "Genova"
                        font.pixelSize: 10
                        color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.4)
                    }

                    Text {
                        text: "Just now"
                        font.family: overlaysRoot.barSlot.root.barFont || "Genova"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.5)
                    }
                }

                // Summary / Title
                Text {
                    id: summaryText
                    text: overlaysRoot.barSlot.formatTitleCase(overlaysRoot.island.notifPeekSummary !== "" ? overlaysRoot.island.notifPeekSummary : overlaysRoot.island.notifPeekApp)
                    font.family: overlaysRoot.barSlot.root.barFont || "Genova"
                    font.pixelSize: islandNotifPeekItem.hasBody ? 13 : 12
                    font.weight: Font.Bold
                    color: overlaysRoot.barSlot.root.ink
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                // Body / Description
                Text {
                    id: bodyText
                    visible: islandNotifPeekItem.hasBody
                    text: overlaysRoot.barSlot.formatNotificationBody(overlaysRoot.island.notifPeekBody)
                    font.family: overlaysRoot.barSlot.root.barFont || "Genova"
                    font.pixelSize: 11
                    font.weight: Font.Normal
                    lineHeight: 1.2
                    color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.78)
                    linkColor: overlaysRoot.barSlot.accent
                    textFormat: Text.StyledText
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
            }

            // Close button
            Rectangle {
                id: notifCloseBtn
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: closeHov.hovered ? Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.12) : "transparent"
                border.width: 0
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 13
                    color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, closeHov.hovered ? 0.95 : 0.45)
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                HoverHandler { id: closeHov }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        overlaysRoot.island.notifPeekActive = false
                        overlaysRoot.island.notifPeekProgress = 0.0
                    }
                }
            }
        }
    }

    // ── Voice Dictation Dynamic Island Item ──
    Rectangle {
        id: islandDictationItem
        anchors.centerIn: parent
        readonly property bool isTranscribing: overlaysRoot.barSlot.root.dictationState === "transcribing"
        width: isTranscribing ? 146 : 84
        Behavior on width {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        height: 24
        radius: height / 2
        color: "transparent"
        clip: false
        opacity: overlaysRoot.island.islandCollapsedOpacity * overlaysRoot.island.dictationProgress
        visible: opacity > 0.001

        transform: Translate {
            y: (1.0 - overlaysRoot.island.dictationProgress) * (overlaysRoot.barSlot.root.barPosition === "bottom" ? 6 : -6)
        }

        // ── 1. Listening State: 3-Element Theme Waveform (No background, pure theme accent) ──
        Item {
            id: listeningWaveformContainer
            anchors.centerIn: parent
            width: listeningWaveformRow.implicitWidth
            height: parent.height
            visible: opacity > 0.001
            opacity: islandDictationItem.isTranscribing ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
                id: listeningWaveformRow
                anchors.centerIn: parent
                spacing: 4

                // Bar 1 (Left): Rounded capsule bar (Theme Accent)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4.5
                    radius: 2.25
                    color: overlaysRoot.barSlot.accent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SequentialAnimation on height {
                        loops: Animation.Infinite
                        running: overlaysRoot.island.dictationActive && !islandDictationItem.isTranscribing
                        NumberAnimation { to: 14; duration: 260; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 6; duration: 240; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 11; duration: 220; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 7; duration: 280; easing.type: Easing.InOutQuad }
                    }
                }

                // Bar 2 (Middle): Tallest rounded capsule bar (Theme Accent)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4.5
                    radius: 2.25
                    color: overlaysRoot.barSlot.accent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SequentialAnimation on height {
                        loops: Animation.Infinite
                        running: overlaysRoot.island.dictationActive && !islandDictationItem.isTranscribing
                        NumberAnimation { to: 19; duration: 220; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 9; duration: 260; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 16; duration: 240; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 8; duration: 200; easing.type: Easing.InOutQuad }
                    }
                }

                // Dot 3 (Right): Circular dot (Theme Accent)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 5
                    radius: 2.5
                    color: overlaysRoot.barSlot.accent
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: overlaysRoot.island.dictationActive && !islandDictationItem.isTranscribing
                        NumberAnimation { to: 1.35; duration: 280; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.80; duration: 240; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.20; duration: 220; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.90; duration: 260; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // ── 2. Transcribing State: 6-Dot Progressive Spinner + "Transcribing…" Text (Image 1) ──
        Item {
            id: transcribingRow
            anchors.centerIn: parent
            width: transcribingContentRow.implicitWidth
            height: parent.height
            visible: opacity > 0.001
            opacity: islandDictationItem.isTranscribing ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
                id: transcribingContentRow
                anchors.centerIn: parent
                spacing: 8

                // Rotating Progressive Dot Spinner (6 circular dots)
                Item {
                    id: transcribingSpinner
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 1050
                        loops: Animation.Infinite
                        running: overlaysRoot.island.dictationActive && islandDictationItem.isTranscribing
                    }

                    // Dot 0 (Top: 0°)
                    Rectangle {
                        x: 9.1; y: 2.3
                        width: 1.8; height: 1.8
                        radius: 0.9
                        color: overlaysRoot.barSlot.accent
                        opacity: 0.40
                    }

                    // Dot 1 (60°)
                    Rectangle {
                        x: 14.7; y: 5.4
                        width: 2.4; height: 2.4
                        radius: 1.2
                        color: overlaysRoot.barSlot.accent
                        opacity: 0.55
                    }

                    // Dot 2 (120°)
                    Rectangle {
                        x: 14.3; y: 11.8
                        width: 3.2; height: 3.2
                        radius: 1.6
                        color: overlaysRoot.barSlot.accent
                        opacity: 0.70
                    }

                    // Dot 3 (Bottom: 180°, Largest)
                    Rectangle {
                        x: 7.6; y: 14.4
                        width: 4.8; height: 4.8
                        radius: 2.4
                        color: overlaysRoot.barSlot.accent
                        opacity: 1.00
                    }

                    // Dot 4 (240°)
                    Rectangle {
                        x: 2.1; y: 11.4
                        width: 4.0; height: 4.0
                        radius: 2.0
                        color: overlaysRoot.barSlot.accent
                        opacity: 0.85
                    }

                    // Dot 5 (300°)
                    Rectangle {
                        x: 2.7; y: 5.2
                        width: 2.8; height: 2.8
                        radius: 1.4
                        color: overlaysRoot.barSlot.accent
                        opacity: 0.60
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Transcribing…"
                    font.family: overlaysRoot.barSlot.root.barFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: overlaysRoot.barSlot.root.ink
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: overlaysRoot.barSlot.root.toggleDictation()
        }
    }

    // ── Laptop Charging Dynamic Island Pill (In-Bar Sleek Horizontal Design) ──
    Rectangle {
        id: islandChargingItem
        anchors.centerIn: parent
        readonly property int targetWidth: Math.max(200, Math.round(chargingContentRow.implicitWidth + 28))
        width: targetWidth
        height: overlaysRoot.barSlot.root.v2BarHeight
        radius: height / 2
        clip: true
        color: "transparent"
        border.width: 0
        opacity: overlaysRoot.island.islandCollapsedOpacity * overlaysRoot.island.chargingProgress * (1.0 - overlaysRoot.island.dictationProgress)
        visible: opacity > 0.001

        readonly property int pct: Math.max(1, Math.min(100, overlaysRoot.barSlot.root.chargingPopupPercent))

        // Percentage-driven dynamic foreground accent color
        readonly property color batteryPercentColor: {
            if (pct < 20) return "#ef4444"      // Red (< 20%)
            if (pct < 50) return "#f97316"      // Orange (20-49%)
            if (pct < 80) return "#3b82f6"      // Royal Blue (50-79%)
            return "#10b981"                    // Emerald Green (80-100%)
        }

        readonly property string timeLeftStr: {
            var dev = UPower.displayDevice
            if (!dev) return ""
            var s = dev.timeToFull
            if (!s || s <= 0) return ""
            var h = Math.floor(s / 3600)
            var m = Math.floor((s % 3600) / 60)
            if (h > 0) return h + "h " + (m > 0 ? m + "m left" : "left")
            return m + " min left"
        }

        property real animatedPct: 0
        Behavior on animatedPct {
            NumberAnimation { duration: 850; easing.type: Easing.OutCubic }
        }

        Connections {
            target: overlaysRoot.island
            function onChargingActiveChanged() {
                if (overlaysRoot.island.chargingActive) {
                    islandChargingItem.animatedPct = 0;
                    chargeAnimTimer.restart();
                }
            }
        }

        Timer {
            id: chargeAnimTimer
            interval: 50
            onTriggered: islandChargingItem.animatedPct = islandChargingItem.pct
        }

        onPctChanged: {
            if (overlaysRoot.island.chargingActive && !chargeAnimTimer.running) {
                animatedPct = pct;
            }
        }

        // Horizontal content layout fitting within the bar height
        Row {
            id: chargingContentRow
            anchors.centerIn: parent
            spacing: 10

            // Left: Bolt icon + "Charging"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "bolt"
                    font.pixelSize: 14
                    color: islandChargingItem.batteryPercentColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Charging"
                    font.family: overlaysRoot.barSlot.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: overlaysRoot.barSlot.root.ink
                    opacity: 0.90
                }
            }

            // Center: Sleek Progress Bar Track with smoothly curved corners
            Rectangle {
                id: chargeTrack
                anchors.verticalCenter: parent.verticalCenter
                width: 130
                height: 18
                radius: 9
                color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.14)
                border.color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.20)
                border.width: 1
                clip: true

                // Animated Fill Bar
                Rectangle {
                    id: chargeFill
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: Math.max(0, Math.min(parent.width - 2, (parent.width - 2) * (islandChargingItem.animatedPct / 100)))
                    radius: 8
                    color: islandChargingItem.batteryPercentColor
                    Behavior on color { ColorAnimation { duration: 200 } }

                    // Percentage text inside pill if sufficiently wide
                    Text {
                        id: pillPctLabel
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: islandChargingItem.pct + "%"
                        font.family: overlaysRoot.barSlot.root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#ffffff"
                        visible: islandChargingItem.pct >= 25
                        opacity: Math.max(0, Math.min(1.0, (chargeFill.width - 24) / 16))
                    }
                }

                // Soft luminous glow around fill
                Rectangle {
                    anchors.fill: chargeFill
                    radius: chargeFill.radius
                    color: islandChargingItem.batteryPercentColor
                    opacity: 0.25
                    z: -1
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // Right: Percentage (if battery low) and Time remaining
            Row {
                id: chargingRightRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                visible: (islandChargingItem.pct < 25) || (islandChargingItem.timeLeftStr !== "")

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: islandChargingItem.pct < 25
                    text: islandChargingItem.pct + "%"
                    font.family: overlaysRoot.barSlot.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: islandChargingItem.batteryPercentColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: islandChargingItem.timeLeftStr
                    visible: text !== ""
                    font.family: overlaysRoot.barSlot.root.barFont
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Qt.rgba(overlaysRoot.barSlot.root.ink.r, overlaysRoot.barSlot.root.ink.g, overlaysRoot.barSlot.root.ink.b, 0.75)
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: overlaysRoot.barSlot.root.chargingPopupActive = false
        }
    }
}

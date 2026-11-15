import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.UPower
import "../modules"
import "../motion"
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
    property alias islandPowerPeekItem: islandPowerPeekItem

    // Volume / brightness OSD: horizontal capsule slider inspired by the vertical
    // quick-slider design (accent left chip, light right chip with dots, recessed
    // center groove, and sliding accent capsule with icon and percentage).
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
        readonly property color lightChipColor: {
            var c = islandOsdItem.sliderColor
            return Qt.rgba(
                c.r * 0.45 + 0.55,
                c.g * 0.45 + 0.55,
                c.b * 0.45 + 0.55,
                0.95
            )
        }
        readonly property color lightChipTextColor: "#1e1b18"

        transform: Translate {
            y: (1.0 - overlaysRoot.island.osdProgress) * (overlaysRoot.barSlot.root.barPosition === "bottom" ? 6 : -6)
        }

        // Left circular chip (icon reflecting state: volume / mute / brightness)
        Rectangle {
            id: osdLeftChip
            anchors.left: parent.left
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 4
            height: width
            radius: width / 2
            color: islandOsdItem.sliderColor
            Behavior on color { ColorAnimation { duration: 160 } }

            IconText {
                anchors.centerIn: parent
                font.pixelSize: 13
                color: islandOsdItem.textColorOnFill
                text: {
                    if (overlaysRoot.island.osdKind === "brightness") {
                        return IconMap.icon("light_mode")
                    } else if (overlaysRoot.island.osdKind === "audio-muted") {
                        return IconMap.icon("volume_off")
                    } else {
                        if (islandOsdItem.val <= 0) return IconMap.icon("volume_mute")
                        if (islandOsdItem.val <= 50) return IconMap.icon("volume_down")
                        return IconMap.icon("volume_up")
                    }
                }
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        // Right circular chip (three dots 'more_horiz' on pastel chip)
        Rectangle {
            id: osdRightChip
            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 4
            height: width
            radius: width / 2
            color: islandOsdItem.lightChipColor
            Behavior on color { ColorAnimation { duration: 160 } }

            IconText {
                anchors.centerIn: parent
                font.pixelSize: 13
                color: islandOsdItem.lightChipTextColor
                text: IconMap.icon("more_horiz")
            }
        }

        // Center track area: recessed groove with sliding fill capsule
        Item {
            id: osdTrackArea
            anchors.left: osdLeftChip.right
            anchors.leftMargin: 6
            anchors.right: osdRightChip.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 4

            // Recessed groove line
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Qt.rgba(0, 0, 0, 0.45)
            }

            // Fallback text when muted or 0%
            UiText {
                anchors.centerIn: parent
                text: islandOsdItem.muted ? "Muted" : "0%"
                color: overlaysRoot.barSlot.root.ink
                font.family: overlaysRoot.barSlot.root.barFont
                font.pixelSize: 11
                font.weight: Font.Medium
                opacity: 0.65
                visible: islandOsdItem.val === 0
            }

            // Sliding active fill capsule
            Rectangle {
                id: osdFillPill
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: parent.height
                radius: height / 2
                color: islandOsdItem.sliderColor
                clip: true

                readonly property real maxW: parent.width
                readonly property real valW: (islandOsdItem.val / 100.0) * maxW
                width: islandOsdItem.val > 0 ? Math.max(height, Math.min(maxW, valW)) : 0
                visible: width > 0

                Behavior on width {
                    NumberAnimation { duration: 130; easing.type: Easing.OutQuad }
                }
                Behavior on color { ColorAnimation { duration: 160 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                        color: islandOsdItem.textColorOnFill
                        text: overlaysRoot.island.osdKind === "brightness"
                            ? IconMap.icon("light_mode")
                            : IconMap.icon("music_note")
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(overlaysRoot.island.osdValue) + "%"
                        color: islandOsdItem.textColorOnFill
                        font.family: overlaysRoot.barSlot.root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        visible: osdFillPill.width >= 52
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }
                }
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
                clip: true
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
        readonly property bool isDischarging: overlaysRoot.barSlot.root.chargingPopupState === "discharging"

        // Percentage-driven dynamic foreground accent color
        readonly property color batteryPercentColor: {
            if (pct < 20) return "#ef4444"      // Red (< 20%)
            if (pct < 50) return "#f97316"      // Orange (20-49%)
            if (pct < 80) return isDischarging ? (overlaysRoot.barSlot.root.seal || "#22d3ee") : "#3b82f6"      // Royal Blue (50-79%)
            return isDischarging ? (overlaysRoot.barSlot.root.seal || "#10b981") : "#10b981"                    // Emerald Green (80-100%)
        }

        readonly property string timeLeftStr: {
            var dev = UPower.displayDevice
            if (!dev) return ""
            var s = isDischarging ? dev.timeToEmpty : dev.timeToFull
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

            // Left: Icon + Status text
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: islandChargingItem.isDischarging ? "power_off" : "bolt"
                    font.pixelSize: 14
                    color: islandChargingItem.batteryPercentColor
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: islandChargingItem.isDischarging ? "Disconnected" : "Charging"
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

    // ── Expanded Bar Power Peek (4 Material 3 Geometric Options) ──
    Item {
        id: islandPowerPeekItem
        anchors.centerIn: parent
        width: 440
        height: 132
        opacity: overlaysRoot.island.islandCollapsedOpacity * overlaysRoot.island.powerPeekProgress
        visible: opacity > 0.001

        property int focusedIndex: 0

        readonly property string pathFlower: "M 62.5 32.0 L 62.1 35.0 L 61.1 37.8 L 59.4 40.3 L 57.1 42.4 L 54.4 44.0 L 51.3 44.9 L 48.1 45.2 L 44.7 44.7 L 45.2 48.1 L 44.9 51.3 L 44.0 54.4 L 42.4 57.1 L 40.3 59.4 L 37.8 61.1 L 35.0 62.1 L 32.0 62.5 L 29.0 62.1 L 26.2 61.1 L 23.7 59.4 L 21.6 57.1 L 20.0 54.4 L 19.1 51.3 L 18.8 48.1 L 19.3 44.7 L 15.9 45.2 L 12.7 44.9 L 9.6 44.0 L 6.9 42.4 L 4.6 40.3 L 2.9 37.8 L 1.9 35.0 L 1.5 32.0 L 1.9 29.0 L 2.9 26.2 L 4.6 23.7 L 6.9 21.6 L 9.6 20.0 L 12.7 19.1 L 15.9 18.8 L 19.3 19.3 L 18.8 15.9 L 19.1 12.7 L 20.0 9.6 L 21.6 6.9 L 23.7 4.6 L 26.2 2.9 L 29.0 1.9 L 32.0 1.5 L 35.0 1.9 L 37.8 2.9 L 40.3 4.6 L 42.4 6.9 L 44.0 9.6 L 44.9 12.7 L 45.2 15.9 L 44.7 19.3 L 48.1 18.8 L 51.3 19.1 L 54.4 20.0 L 57.1 21.6 L 59.4 23.7 L 61.1 26.2 L 62.1 29.0 Z"
        readonly property string pathArch: "M 2 32 A 30 30 0 0 1 62 32 L 62 46 A 16 16 0 0 1 46 62 L 18 62 A 16 16 0 0 1 2 46 Z"
        readonly property string pathScallop: "M 62.5 32.0 L 61.9 34.9 L 60.0 37.6 L 57.3 39.7 L 54.2 41.2 L 55.4 44.5 L 55.8 47.9 L 55.2 51.0 L 53.6 53.6 L 51.0 55.2 L 47.9 55.8 L 44.5 55.4 L 41.2 54.2 L 39.7 57.3 L 37.6 60.0 L 34.9 61.9 L 32.0 62.5 L 29.1 61.9 L 26.4 60.0 L 24.3 57.3 L 22.8 54.2 L 19.5 55.4 L 16.1 55.8 L 13.0 55.2 L 10.4 53.6 L 8.8 51.0 L 8.2 47.9 L 8.6 44.5 L 9.8 41.2 L 6.7 39.7 L 4.0 37.6 L 2.1 34.9 L 1.5 32.0 L 2.1 29.1 L 4.0 26.4 L 6.7 24.3 L 9.8 22.8 L 8.6 19.5 L 8.2 16.1 L 8.8 13.0 L 10.4 10.4 L 13.0 8.8 L 16.1 8.2 L 19.5 8.6 L 22.8 9.8 L 24.3 6.7 L 26.4 4.0 L 29.1 2.1 L 32.0 1.5 L 34.9 2.1 L 37.6 4.0 L 39.7 6.7 L 41.2 9.8 L 44.5 8.6 L 47.9 8.2 L 51.0 8.8 L 53.6 10.4 L 55.2 13.0 L 55.8 16.1 L 55.4 19.5 L 54.2 22.8 L 57.3 24.3 L 60.0 26.4 L 61.9 29.1 Z"
        readonly property string pathStar: "M 48.0 32.0 L 48.5 33.6 L 49.8 35.5 L 51.7 38.0 L 53.7 41.0 L 55.3 44.4 L 55.9 48.0 L 55.5 51.3 L 53.9 53.9 L 51.3 55.5 L 48.0 55.9 L 44.4 55.3 L 41.0 53.7 L 38.0 51.7 L 35.5 49.8 L 33.6 48.5 L 32.0 48.0 L 30.4 48.5 L 28.5 49.8 L 26.0 51.7 L 23.0 53.7 L 19.6 55.3 L 16.0 55.9 L 12.7 55.5 L 10.1 53.9 L 8.5 51.3 L 8.1 48.0 L 8.7 44.4 L 10.3 41.0 L 12.3 38.0 L 14.2 35.5 L 15.5 33.6 L 16.0 32.0 L 15.5 30.4 L 14.2 28.5 L 12.3 26.0 L 10.3 23.0 L 8.7 19.6 L 8.1 16.0 L 8.5 12.7 L 10.1 10.1 L 12.7 8.5 L 16.0 8.1 L 19.6 8.7 L 23.0 10.3 L 26.0 12.3 L 28.5 14.2 L 30.4 15.5 L 32.0 16.0 L 33.6 15.5 L 35.5 14.2 L 38.0 12.3 L 41.0 10.3 L 44.4 8.7 L 48.0 8.1 L 51.3 8.5 L 53.9 10.1 L 55.5 12.7 L 55.9 16.0 L 55.3 19.6 L 53.7 23.0 L 51.7 26.0 L 49.8 28.5 L 48.5 30.4 Z"

        readonly property var options: [
            { name: "Screensaver", icon: "wallpaper", accent: (overlaysRoot.barSlot.root && overlaysRoot.barSlot.root.color06) ? overlaysRoot.barSlot.root.color06 : "#7aa89f", path: pathFlower },
            { name: "Lock", icon: "lock", accent: (overlaysRoot.barSlot.root && overlaysRoot.barSlot.root.color04) ? overlaysRoot.barSlot.root.color04 : "#658594", path: pathArch },
            { name: "Shutdown", icon: "power_settings_new", accent: (overlaysRoot.barSlot.root && overlaysRoot.barSlot.root.color01) ? overlaysRoot.barSlot.root.color01 : "#c4746e", path: pathScallop },
            { name: "Reboot", icon: "restart_alt", accent: (overlaysRoot.barSlot.root && overlaysRoot.barSlot.root.color03) ? overlaysRoot.barSlot.root.color03 : "#c8b36a", path: pathStar }
        ]

        function triggerOption(idx) {
            if (overlaysRoot.barSlot.root) overlaysRoot.barSlot.root.powerPeekActive = false
            switch (idx) {
                case 0:
                    Quickshell.execDetached(["bash", "-c", "omarchy-launch-screensaver 2>/dev/null || omarchy-screensaver 2>/dev/null"])
                    break
                case 1:
                    Quickshell.execDetached(["bash", "-c", "$HOME/.config/quickshell/bin/qs-lock 2>/dev/null || $HOME/.config/hypr/scripts/custom-lock.sh 2>/dev/null || loginctl lock-session"])
                    break
                case 2:
                    Quickshell.execDetached(["systemctl", "poweroff"])
                    break
                case 3:
                    Quickshell.execDetached(["systemctl", "reboot"])
                    break
            }
        }

        focus: overlaysRoot.island.powerPeekActive
        onVisibleChanged: if (visible) forceActiveFocus()

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_X) {
                if (overlaysRoot.barSlot.root) overlaysRoot.barSlot.root.powerPeekActive = false
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                focusedIndex = (focusedIndex + 1) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                focusedIndex = (focusedIndex - 1 + 4) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                triggerOption(focusedIndex)
                event.accepted = true
            }
        }

        transform: Translate {
            y: (1.0 - overlaysRoot.island.powerPeekProgress) * (overlaysRoot.barSlot.root.barPosition === "bottom" ? 10 : -10)
        }

        Row {
            anchors.centerIn: parent
            spacing: 12

            Repeater {
                model: islandPowerPeekItem.options

                Item {
                    id: pOptCard
                    required property var modelData
                    required property int index
                    readonly property bool isFocused: islandPowerPeekItem.focusedIndex === index
                    readonly property bool isHovered: pOptMa.containsMouse

                    width: 96
                    height: 112

                    Column {
                        anchors.centerIn: parent
                        spacing: 10

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 64
                            height: 64
                            scale: (pOptCard.isHovered || pOptCard.isFocused) ? 1.08 : 1.0
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    strokeWidth: 0
                                    strokeColor: "transparent"
                                    fillColor: (pOptCard.isHovered || pOptCard.isFocused)
                                        ? pOptCard.modelData.accent
                                        : Qt.rgba(pOptCard.modelData.accent.r, pOptCard.modelData.accent.g, pOptCard.modelData.accent.b, 0.22)
                                    Behavior on fillColor { ColorAnimation { duration: 160 } }

                                    PathSvg { path: pOptCard.modelData.path }
                                }
                            }

                            IconText {
                                anchors.centerIn: parent
                                text: pOptCard.modelData.icon
                                font.pixelSize: 26
                                color: (pOptCard.isHovered || pOptCard.isFocused)
                                    ? overlaysRoot.barSlot.root.paper
                                    : pOptCard.modelData.accent
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pOptCard.modelData.name
                            font.family: overlaysRoot.barSlot.root.barFont
                            font.pixelSize: 12
                            font.weight: pOptCard.isFocused ? Font.Bold : Font.DemiBold
                            color: overlaysRoot.barSlot.root.ink
                            opacity: (pOptCard.isHovered || pOptCard.isFocused) ? 1.0 : 0.75
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: pOptMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: islandPowerPeekItem.focusedIndex = pOptCard.index
                        onClicked: islandPowerPeekItem.triggerOption(pOptCard.index)
                    }
                }
            }
        }
    }
}

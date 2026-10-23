import QtQuick
import QtQuick.Effects
import Quickshell
import "../modules"
import "../motion"

Item {
    id: overlay
    anchors.fill: parent
    z: 9999
    clip: true

    required property var root
    required property var emotionsManager

    signal closed()
    signal submitted()

    property int activeLevelIndex: 5 // Default to "Pleasant"
    property string activeMode: "overall" // "current" or "overall"
    property var selectedTags: []
    property var selectedContext: ["Work"]

    readonly property var activeLevel: emotionsManager ? emotionsManager.getLevel(activeLevelIndex) : null

    onActiveLevelIndexChanged: {
        if (activeLevel) {
            selectedTags = activeLevel.defaultTags.slice(0, 2)
        }
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            if (activeLevel && selectedTags.length === 0) {
                selectedTags = activeLevel.defaultTags.slice(0, 2)
            }
        }
    }

    Component.onCompleted: {
        if (activeLevel && selectedTags.length === 0) {
            selectedTags = activeLevel.defaultTags.slice(0, 2)
        }
        forceActiveFocus()
    }

    // Keyboard navigation
    focus: true
    Keys.onLeftPressed: (event) => {
        if (activeLevelIndex > 0) activeLevelIndex--
        event.accepted = true
    }
    Keys.onRightPressed: (event) => {
        if (emotionsManager && activeLevelIndex < emotionsManager.levels.length - 1) activeLevelIndex++
        event.accepted = true
    }
    Keys.onEscapePressed: (event) => {
        overlay.dismiss()
        event.accepted = true
    }
    Keys.onReturnPressed: (event) => {
        overlay.confirmLog()
        event.accepted = true
    }

    function toggleTag(tag) {
        var arr = selectedTags.slice()
        var idx = arr.indexOf(tag)
        if (idx !== -1) {
            if (arr.length > 1) arr.splice(idx, 1)
        } else {
            arr.push(tag)
        }
        selectedTags = arr
    }

    function toggleContext(ctx) {
        var arr = selectedContext.slice()
        var idx = arr.indexOf(ctx)
        if (idx !== -1) {
            if (arr.length > 1) arr.splice(idx, 1)
        } else {
            arr.push(ctx)
        }
        selectedContext = arr
    }

    function confirmLog() {
        if (emotionsManager) {
            emotionsManager.logToday(activeLevelIndex, activeMode, selectedTags, selectedContext, "")
        }
        submitted()
        closed()
    }

    function dismiss() {
        if (emotionsManager) {
            emotionsManager.markPromptedToday()
        }
        closed()
    }

    // ── Main Shell Container (Matches Dashboard Glass Theme) ─────────────────
    Rectangle {
        anchors.fill: parent
        radius: 20
        color: root.paper
        border.width: 1
        border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
        clip: true

        // Catch clicks to prevent backdrop click-through
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // ── 1. Top Header Bar ────────────────────────────────────────────────
        Item {
            id: topHeader
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            height: 28

            // Left: Header Title & Icon
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: overlay.activeLevel ? Qt.rgba(overlay.activeLevel.color.r, overlay.activeLevel.color.g, overlay.activeLevel.color.b, 0.20) : "transparent"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 200 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "spa"
                        font.pixelSize: 14
                        color: overlay.activeLevel ? overlay.activeLevel.color : root.seal
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }

                Text {
                    text: "State of Mind"
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "· Daily Check-In"
                    color: root.ink
                    opacity: 0.5
                    font.family: root.barFont
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Center: 7 Level Pill Track
            Row {
                anchors.centerIn: parent
                spacing: 5

                Repeater {
                    model: overlay.emotionsManager ? overlay.emotionsManager.levels : []
                    delegate: Rectangle {
                        id: dotRect
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: overlay.activeLevelIndex === index
                        width: isSelected ? 26 : 14
                        height: 5
                        radius: 2.5
                        color: isSelected
                            ? modelData.color
                            : (dotMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.28) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12))

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 160 } }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: overlay.activeLevelIndex = dotRect.index
                        }
                    }
                }
            }

            // Right: Mode Switcher & Close Button
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                PillTabs {
                    anchors.verticalCenter: parent.verticalCenter
                    theme: overlay.root
                    variant: "tonal"
                    current: overlay.activeMode
                    model: [
                        { id: "overall", label: "Overall today" },
                        { id: "current", label: "Current mood" }
                    ]
                    onActivated: (id) => overlay.activeMode = id
                }

                // Close / Skip Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    anchors.verticalCenter: parent.verticalCenter
                    color: closeMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 14
                        color: root.ink
                    }

                    SpringPress {}
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: overlay.dismiss()
                    }
                }
            }
        }

        // ── 2. Two-Column Landscape Content ──────────────────────────────────
        Row {
            anchors.top: topHeader.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 14
            spacing: 12

            // ═════════════════════════════════════════════════════════════════
            // ── LEFT COLUMN: MOOD SELECTOR HERO ──────────────────────────────
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                id: leftCard
                width: Math.round(parent.width * 0.40)
                height: parent.height
                radius: 16
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
                clip: true

                // Subtle Aura Radial Glow behind icon
                Rectangle {
                    anchors.centerIn: parent
                    width: 140
                    height: 140
                    radius: 70
                    color: overlay.activeLevel ? overlay.activeLevel.color : "transparent"
                    opacity: 0.14
                    Behavior on color { ColorAnimation { duration: 250 } }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 32
                        blur: 1.0
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 24

                    // Stepper Row: Prev Button, Mood Avatar, Next Button
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 14

                        // Prev Stepper Chevron
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            anchors.verticalCenter: parent.verticalCenter
                            color: prevMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            opacity: overlay.activeLevelIndex > 0 ? 1.0 : 0.25

                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.pixelSize: 18
                                color: root.ink
                            }

                            SpringPress {}
                            MouseArea {
                                id: prevMa
                                anchors.fill: parent
                                enabled: overlay.activeLevelIndex > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: if (overlay.activeLevelIndex > 0) overlay.activeLevelIndex--
                            }
                        }

                        // Central Expressive Mood Avatar
                        Rectangle {
                            width: 60
                            height: 60
                            radius: 30
                            anchors.verticalCenter: parent.verticalCenter
                            color: overlay.activeLevel ? Qt.rgba(overlay.activeLevel.color.r, overlay.activeLevel.color.g, overlay.activeLevel.color.b, 0.20) : "transparent"
                            border.width: 1.5
                            border.color: overlay.activeLevel ? overlay.activeLevel.color : "transparent"

                            Behavior on color { ColorAnimation { duration: 250 } }
                            Behavior on border.color { ColorAnimation { duration: 250 } }

                            IconText {
                                anchors.centerIn: parent
                                text: overlay.activeLevel ? overlay.activeLevel.icon : ""
                                font.pixelSize: 32
                                color: overlay.activeLevel ? overlay.activeLevel.color : root.ink
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                        }

                        // Next Stepper Chevron
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            anchors.verticalCenter: parent.verticalCenter
                            color: nextMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            opacity: (overlay.emotionsManager && overlay.activeLevelIndex < overlay.emotionsManager.levels.length - 1) ? 1.0 : 0.25

                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                font.pixelSize: 18
                                color: root.ink
                            }

                            SpringPress {}
                            MouseArea {
                                id: nextMa
                                anchors.fill: parent
                                enabled: overlay.emotionsManager && overlay.activeLevelIndex < overlay.emotionsManager.levels.length - 1
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (overlay.emotionsManager && overlay.activeLevelIndex < overlay.emotionsManager.levels.length - 1) {
                                        overlay.activeLevelIndex++
                                    }
                                }
                            }
                        }
                    }

                    // Mood Label & Description
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: overlay.activeLevel ? overlay.activeLevel.name : ""
                            font.family: root.barFont
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: root.ink
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: overlay.activeLevel ? ("Status: " + overlay.activeLevel.badge) : ""
                            font.family: root.barFont
                            font.pixelSize: 11
                            color: overlay.activeLevel ? overlay.activeLevel.color : root.seal
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // ── RIGHT COLUMN: FEELINGS, CONTEXT & CONFIRM BUTTON ─────────────
            // ═════════════════════════════════════════════════════════════════
            Rectangle {
                id: rightCard
                width: parent.width - leftCard.width - parent.spacing
                height: parent.height
                radius: 16
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                border.width: 1
                border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // 1. Feelings Tags Row
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "FEELINGS"
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: root.ink
                            opacity: 0.5
                            font.letterSpacing: 0.5
                        }

                        Row {
                            spacing: 6
                            Repeater {
                                model: overlay.activeLevel ? overlay.activeLevel.defaultTags : []
                                delegate: Rectangle {
                                    id: tagChip
                                    required property string modelData
                                    readonly property bool isSelected: overlay.selectedTags.indexOf(modelData) !== -1

                                    height: 24
                                    radius: 12
                                    width: tagText.implicitWidth + 16
                                    color: isSelected
                                        ? (overlay.activeLevel ? Qt.rgba(overlay.activeLevel.color.r, overlay.activeLevel.color.g, overlay.activeLevel.color.b, 0.22) : root.seal)
                                        : (tagMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05))
                                    border.width: isSelected ? 1 : 0
                                    border.color: overlay.activeLevel ? overlay.activeLevel.color : root.seal
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        id: tagText
                                        anchors.centerIn: parent
                                        text: tagChip.modelData
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: tagChip.isSelected ? Font.DemiBold : Font.Normal
                                        color: tagChip.isSelected
                                            ? (overlay.activeLevel ? overlay.activeLevel.color : root.ink)
                                            : root.ink
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: tagMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: overlay.toggleTag(tagChip.modelData)
                                    }
                                }
                            }
                        }
                    }

                    // 2. Context Tags Row
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "CONTEXT"
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: root.ink
                            opacity: 0.5
                            font.letterSpacing: 0.5
                        }

                        Row {
                            spacing: 6
                            Repeater {
                                model: overlay.emotionsManager ? overlay.emotionsManager.contextOptions.slice(0, 5) : []
                                delegate: Rectangle {
                                    id: ctxChip
                                    required property string modelData
                                    readonly property bool isSelected: overlay.selectedContext.indexOf(modelData) !== -1

                                    height: 24
                                    radius: 12
                                    width: ctxText.implicitWidth + 16
                                    color: isSelected
                                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                                        : (ctxMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05))
                                    border.width: isSelected ? 1 : 0
                                    border.color: root.seal
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    Text {
                                        id: ctxText
                                        anchors.centerIn: parent
                                        text: ctxChip.modelData
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: ctxChip.isSelected ? Font.DemiBold : Font.Normal
                                        color: ctxChip.isSelected ? root.seal : root.ink
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: ctxMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: overlay.toggleContext(ctxChip.modelData)
                                    }
                                }
                            }
                        }
                    }

                    // Spacer
                    Item {
                        width: parent.width
                        height: 2
                    }

                    // 3. Bottom Action Bar: Shortcut Hint & Confirm Log Button
                    Item {
                        width: parent.width
                        height: 32

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            opacity: 0.45

                            IconText {
                                text: "keyboard_return"
                                font.pixelSize: 13
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Press Enter to log"
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Submit Button
                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 30
                            radius: 15
                            width: submitRow.implicitWidth + 24
                            color: overlay.activeLevel ? overlay.activeLevel.color : root.seal
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Row {
                                id: submitRow
                                anchors.centerIn: parent
                                spacing: 6

                                IconText {
                                    text: "check"
                                    font.pixelSize: 14
                                    color: "#18181B"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Log State of Mind"
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#18181B"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            SpringPress {}
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: overlay.confirmLog()
                            }
                        }
                    }
                }
            }
        }
    }
}

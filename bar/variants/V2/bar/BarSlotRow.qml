import QtQuick
import ".."

// ───────────────────── reusable region row of slots ─────────────────────
Row {
    id: slotRow
    required property var barSlot
    required property var island
    property var rmodel
    property int baseCount
    property int maxExtraCount: 3
    property alias rep: repeater
    readonly property int extraCount: rmodel ? slotRow.barSlot.extraSlotCount(rmodel, baseCount) : 0
    spacing: slotRow.barSlot.root.v2WidgetSpacing
    height: slotRow.island.islandShrinkProgress < 0.5 ? 30 : 24
    // index of the LAST currently shown slot (skips disabled and auto-hidden
    // narrow-stage widgets) — a separator only makes sense BEFORE this gap.
    readonly property int lastVisibleIndex: {
        void(width)
        var last = -1
        for (var k = 0; k < repeater.count; k++) {
            var it = repeater.itemAt(k)
            if (it && it.hasContent && it.autoShown) last = k
        }
        return last
    }
    function nextVisibleSlot(afterIndex) {
        void(width)
        for (var i = afterIndex + 1; i < repeater.count; i++) {
            var candidate = repeater.itemAt(i)
            if (candidate && candidate.hasContent && candidate.autoShown) return candidate
        }
        return null
    }

    Repeater {
        id: repeater
        model: rmodel
        delegate: Item {
            id: slot
            required property string gid
            required property bool extra
            required property int index
            readonly property bool occupied: gid !== "" && slotRow.barSlot.registry[gid] !== undefined
            readonly property bool isButton: slot.gid !== "G8" && slot.occupied && slot.hasContent && slotRow.island.islandShrinkProgress < 0.5
            readonly property int squareSize: 30
            readonly property bool supportsFull: ["G12", "G21"].indexOf(slot.gid) >= 0
            readonly property bool isFullOption: supportsFull && !slotRow.barSlot.root.iconOnly(slot.gid)
            readonly property bool isComposite: ["G2", "G3"].indexOf(slot.gid) >= 0
            readonly property bool isPriority: ["G1", "G2"].indexOf(slot.gid) >= 0
            readonly property real buttonContentWidth: Math.round(ldr.implicitWidth)
            readonly property real buttonWidth: {
                if (!isButton) return buttonContentWidth
                if (isFullOption) {
                    if (slot.gid === "G21") return Math.max(squareSize * 2, 64)
                    if (slot.gid === "G12") return Math.max(squareSize * 2, buttonContentWidth)
                    return squareSize * 2 // twice the width of the square = 60px
                }
                if (isComposite) return Math.max(squareSize, buttonContentWidth + 12)
                return squareSize // rounded square = 30px
            }
            // workspace draws a pill 4px wider than its implicitWidth on each
            // side; pad its slot symmetrically so inter-group gaps stay uniform.
            readonly property int pad: (slot.gid === "G2" && !isButton) ? slotRow.barSlot.root.wsPillPad : 0
            readonly property var contentItem: ldr.item
            readonly property bool hasContent: occupied && Math.round(ldr.implicitWidth) > 0.5
            readonly property real contentLeftInset: (contentItem && contentItem.barContentLeftInset !== undefined)
                ? contentItem.barContentLeftInset : 0
            readonly property real contentRightInset: (contentItem && contentItem.barContentRightInset !== undefined)
                ? contentItem.barContentRightInset : 0
            readonly property bool hasVisualSurface:
                isButton || slotRow.barSlot.root.widgetHasFill(gid) || slotRow.barSlot.root.widgetHasBorder(gid)
            readonly property real visualLeftEdge: isButton ? 0 : (pad
                + (hasVisualSurface ? 0 : contentLeftInset))
            readonly property real visualRightEdge: isButton ? buttonWidth : (pad
                + Math.round(ldr.implicitWidth)
                - (hasVisualSurface ? 0 : contentRightInset))
            readonly property var nextVisualSlot: slotRow.nextVisibleSlot(index)
            readonly property real nextVisualLeftEdge: nextVisualSlot
                ? nextVisualSlot.x - slot.x + nextVisualSlot.visualLeftEdge
                : visualRightEdge + slotRow.spacing
            readonly property real unsetSeparatorCenterX:
                (visualRightEdge + nextVisualLeftEdge) / 2
            readonly property bool placeholderShown: !occupied && slotRow.barSlot.root.barUnlocked
            // user-set separator after this widget: extra width is part of BOTH
            // width recipes so the narrow-stage budget stays stage-independent.
            readonly property bool sepOn: occupied && slotRow.barSlot.root.sepAfter(gid)
            readonly property int sepW: 15
            readonly property real naturalSlotWidth: placeholderShown
                ? 28
                : ((isButton ? buttonWidth : buttonContentWidth) + 2 * pad + (sepOn && hasContent ? sepW : 0))
            // Empty edit slots do not influence the locked narrow-layout budget.
            readonly property real budgetSlotWidth: hasContent
                ? ((isButton ? buttonWidth : buttonContentWidth) + 2 * pad + (sepOn ? sepW : 0))
                : 0
            readonly property bool autoShown: placeholderShown
                || (occupied && slotRow.island.groupVisibleAtStage(slot.gid, slotRow.island.narrowStage))
            onBudgetSlotWidthChanged: slotRow.island.scheduleNarrowUpdate()
            width: autoShown ? naturalSlotWidth : 0
            height: slotRow.island.islandShrinkProgress < 0.5 ? 30 : 24
            visible: placeholderShown || (hasContent && (autoShown || width > 0.5))
            opacity: autoShown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            Rectangle {
                id: properButtonSurface
                anchors.centerIn: parent
                width: isButton ? buttonWidth : buttonContentWidth
                height: isButton ? 30 : 24
                radius: isButton ? 12 : (height / 2)
                clip: true
                visible: slot.occupied && slot.hasContent && slot.autoShown
                    && (isButton || slotRow.barSlot.root.widgetHasFill(slot.gid) || slotRow.barSlot.root.widgetHasBorder(slot.gid))

                color: {
                    if (slotRow.barSlot.root.widgetHasFill(slot.gid)) {
                        return slotRow.barSlot.root.widgetFillColor(slot.gid)
                    }
                    if (isButton) {
                        if (isPriority) {
                            return btnHover.hovered
                                ? Qt.rgba(slotRow.barSlot.accent.r, slotRow.barSlot.accent.g, slotRow.barSlot.accent.b, 0.32)
                                : Qt.rgba(slotRow.barSlot.accent.r, slotRow.barSlot.accent.g, slotRow.barSlot.accent.b, 0.16)
                        }
                        return btnHover.hovered
                            ? Qt.rgba(slotRow.barSlot.root.ink.r, slotRow.barSlot.root.ink.g, slotRow.barSlot.root.ink.b, 0.16)
                            : Qt.rgba(slotRow.barSlot.root.ink.r, slotRow.barSlot.root.ink.g, slotRow.barSlot.root.ink.b, 0.08)
                    }
                    return "transparent"
                }

                border.width: (isButton || slotRow.barSlot.root.widgetHasBorder(slot.gid)) ? 1 : 0
                border.color: {
                    if (isButton) {
                        if (isPriority) {
                            return btnHover.hovered
                                ? Qt.rgba(slotRow.barSlot.accent.r, slotRow.barSlot.accent.g, slotRow.barSlot.accent.b, 0.65)
                                : Qt.rgba(slotRow.barSlot.accent.r, slotRow.barSlot.accent.g, slotRow.barSlot.accent.b, 0.28)
                        }
                        return btnHover.hovered
                            ? Qt.rgba(slotRow.barSlot.accent.r, slotRow.barSlot.accent.g, slotRow.barSlot.accent.b, 0.35)
                            : Qt.rgba(255, 255, 255, 0.04)
                    }
                    if (slotRow.barSlot.root.widgetHasBorder(slot.gid)) {
                        return slotRow.barSlot.root.widgetBorderColor(slot.gid)
                    }
                    return "transparent"
                }

                scale: (isButton && btnHover.hovered && !slotRow.barSlot.dragging) ? 1.05 : 1.0
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                HoverHandler {
                    id: btnHover
                    enabled: isButton && !slotRow.barSlot.root.barUnlocked
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Loader {
                id: ldr
                anchors.centerIn: parent
                sourceComponent: slot.occupied ? slotRow.barSlot.registry[slot.gid] : null
                // dim the original while its ghost is being dragged
                opacity: (slotRow.barSlot.dragItem === ldr && slotRow.barSlot.dragActive) ? 0.25 : 1.0
            }

            // thin vertical divider, centered in the widened right gap
            Rectangle {
                visible: slot.sepOn && slot.hasContent && slot.autoShown
                x: slot.width - slot.pad - 5
                width: 1
                height: 14
                anchors.verticalCenter: parent.verticalCenter
                color: sepMa.containsMouse ? slotRow.barSlot.root.seal : slotRow.barSlot.root.sep
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // Quiet drop slot in edit mode. Added empty slots can be removed;
            // an empty base slot remains as the return target for its widget.
            Rectangle {
                id: emptySlot
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: slotRow.barSlot.root.tileRadius
                visible: slot.placeholderShown
                color: removeMa.containsMouse ? slotRow.barSlot.root.fillHover : slotRow.barSlot.root.fillIdle
                border.color: removeMa.containsMouse ? slotRow.barSlot.root.seal : slotRow.barSlot.root.sep
                border.width: 0
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: slot.extra ? "×" : "·"
                    color: removeMa.containsMouse ? slotRow.barSlot.root.seal : slotRow.barSlot.root.sumi
                    font.family: slotRow.barSlot.root.barFont
                    font.pixelSize: slot.extra ? 12 : 14
                }

                MouseArea {
                    id: removeMa
                    anchors.fill: parent
                    enabled: slot.extra && !slotRow.barSlot.dragging
                    hoverEnabled: enabled
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: slotRow.barSlot.removeExtraSlot(rmodel, slot.index, slotRow.baseCount)
                }
            }

            // ── drag-catcher: only in unlock mode, overlays the widget ──
            MouseArea {
                anchors.fill: parent
                enabled: slotRow.barSlot.root.barUnlocked && slot.occupied && slot.hasContent && slot.autoShown
                visible: enabled
                z: 25
                preventStealing: true
                cursorShape: Qt.OpenHandCursor
                onPressed: {
                    var p = ldr.mapToItem(null, 0, 0)
                    slotRow.barSlot.beginDrag(ldr, p.x, p.y, Math.round(ldr.implicitWidth), slot.height, rmodel, slot.index)
                }
                onPositionChanged: (e) => {
                    if (!slotRow.barSlot.dragging) return
                    var w = mapToItem(null, e.x, e.y)
                    slotRow.barSlot.moveDrag(w.x, w.y)
                }
                onReleased: slotRow.barSlot.endDrag()
                onCanceled: slotRow.barSlot.cancelDrag()
            }
            // drop-target highlight (the group under the cursor, not the source)
            Rectangle {
                anchors.fill: parent
                radius: slotRow.barSlot.root.pillRadius
                color: Qt.rgba(slotRow.barSlot.accent.r, slotRow.barSlot.accent.g, slotRow.barSlot.accent.b, 0.30)
                border.color: slotRow.barSlot.accent
                border.width: 0
                z: 26
                visible: slotRow.barSlot.dragging
                    && slotRow.barSlot.dropModel === rmodel && slotRow.barSlot.dropIndex === slot.index
                    && !(slotRow.barSlot.srcModel === rmodel && slotRow.barSlot.srcIndex === slot.index)
            }

            // ── separator toggle for the gap AFTER this slot (hover-revealed,
            //    V1 split-point pattern — click sets/clears the thin divider) ──
            Item {
                visible: slot.autoShown && slot.hasContent && slot.index < slotRow.lastVisibleIndex
                width: 14
                height: slot.height
                // The active handle sits exactly over the rendered divider.
                // For a filled widget, the unset point follows the fill's real
                // right edge instead of an independently reconstructed width.
                x: slot.sepOn
                    ? Math.round(slot.width - slot.pad - 4.5 - width / 2)
                    : slot.unsetSeparatorCenterX - width / 2
                z: 30
                Text {
                    anchors.centerIn: parent
                    visible: !slot.sepOn
                    text: "•"
                    color: slotRow.barSlot.root.sumi
                    font.pixelSize: 10; font.family: slotRow.barSlot.root.barFont
                    opacity: sepMa.containsMouse ? 0.9 : 0.0          // hover-revealed
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    id: sepMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slotRow.barSlot.root.toggleSep(slot.gid)
                }
            }
        }
    }

    Rectangle {
        id: addSlot
        width: visible ? 28 : 0
        height: 28
        anchors.verticalCenter: parent.verticalCenter
        radius: slotRow.barSlot.root.tileRadius
        visible: slotRow.barSlot.root.barUnlocked
            && slotRow.extraCount < slotRow.maxExtraCount
        color: addMa.containsMouse ? slotRow.barSlot.root.fillActive : slotRow.barSlot.root.fillIdle
        border.color: addMa.containsMouse ? slotRow.barSlot.root.seal : slotRow.barSlot.root.sep
        border.width: 0
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "+"
            color: addMa.containsMouse ? slotRow.barSlot.root.seal : slotRow.barSlot.root.ink
            font.family: slotRow.barSlot.root.barFont
            font.pixelSize: 14
        }

        MouseArea {
            id: addMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: slotRow.barSlot.addExtraSlot(rmodel, slotRow.baseCount,
                slotRow.maxExtraCount)
        }
    }
}

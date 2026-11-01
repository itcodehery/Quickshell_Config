import QtQuick
import ".."
import "../../modules"

// ══════════ THEMES TAB ══════════
Column {
    id: themesTab
    required property var archPanel
    readonly property var root: archPanel.root

    width: parent.width
    spacing: 8
    visible: root.activeUpdateTab === "themes"

    component ScrollThumb: ArchUpdaterScrollThumb {
        archPanel: themesTab.archPanel
    }

    // ── rounded section card ──
    component Card: Rectangle {
        id: _card
        default property alias content: _cardBody.data
        property string title: ""
        property string trailing: ""
        width: parent ? parent.width : 0
        implicitHeight: _cardHead.height + (_cardHead.visible ? 8 : 0) + _cardBody.implicitHeight + archPanel.cardPad * 2
        height: implicitHeight
        radius: archPanel.cardRadius
        color: archPanel.cardBg

        Item {
            id: _cardHead
            visible: _card.title !== ""
            x: archPanel.cardPad + 2
            y: archPanel.cardPad
            width: _card.width - archPanel.cardPad * 2 - 4
            height: visible ? 16 : 0
            UiText {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: _card.title
                color: root.sumiHi; font.family: root.barFont
                font.pixelSize: 11; font.weight: Font.Medium
            }
            UiText {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: _card.trailing
                visible: text !== ""
                color: root.sumi; font.family: root.barFont; font.pixelSize: 10
            }
        }
        Column {
            id: _cardBody
            x: archPanel.cardPad
            y: archPanel.cardPad + _cardHead.height + (_cardHead.visible ? 8 : 0)
            width: _card.width - archPanel.cardPad * 2
            spacing: 6
        }
    }

    // ── pill action button (Control Center style) ──
    component PillButton: Rectangle {
        id: _pb
        property string label
        property string icon: ""
        property bool primary: false
        property bool active: false
        property bool btnEnabled: true
        property color accent: root.seal
        signal clicked()
        height: 36
        radius: height / 2
        opacity: btnEnabled ? 1.0 : 0.45
        color: primary
            ? (_pbMa.containsMouse && btnEnabled ? root.fillPrimaryHover : accent)
            : active
                ? (_pbMa.containsMouse ? Qt.lighter(accent, 1.12) : accent)
                : (_pbMa.containsMouse && btnEnabled ? archPanel.chipHover : archPanel.chipBg)
        Behavior on color { ColorAnimation { duration: 120 } }
        readonly property color fgColor: (primary || active) ? root.paper : (_pbMa.containsMouse && btnEnabled ? root.seal : root.ink)
        Row {
            anchors.centerIn: parent
            spacing: 6
            IconText {
                visible: _pb.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: _pb.icon
                color: _pb.fgColor
                font.pixelSize: 16
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _pb.label
                color: _pb.fgColor
                font.family: root.barFont
                font.pixelSize: 12
                font.weight: (primary || active) ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: _pbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: _pb.btnEnabled
            cursorShape: _pb.btnEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: _pb.clicked()
        }
    }

    // ── status pill chip ──
    component StatusPill: Rectangle {
        id: _sp
        property string label
        property string icon: ""
        property color textColor: root.ink
        property color bgTint: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.14)
        property bool clickable: false
        signal clicked()
        height: 24
        radius: 12
        color: _spMa.containsMouse && clickable
            ? Qt.rgba(textColor.r, textColor.g, textColor.b, 0.25)
            : bgTint
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: 5
            leftPadding: 8
            rightPadding: 8
            UiText {
                visible: _sp.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: _sp.icon
                color: _sp.textColor
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _sp.label
                color: _sp.textColor
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: _spMa
            anchors.fill: parent
            hoverEnabled: _sp.clickable
            enabled: _sp.clickable
            cursorShape: _sp.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: _sp.clicked()
        }
    }

    // ── Status pills row ──
    Flow {
        width: parent.width
        spacing: 6

        StatusPill {
            visible: root.themeUpdChecked === ""
            icon: "info"
            label: "Never checked — run a scan"
            textColor: root.sumi
        }

        StatusPill {
            visible: root.themeUpdChecked !== ""
            icon: root.themeUpdOutdated > 0 ? "update" : "check"
            label: root.themeUpdOutdated + (root.themeUpdOutdated === 1 ? " update found" : " updates found")
            textColor: root.themeUpdOutdated > 0 ? root.ink : root.sumi
            bgTint: root.themeUpdOutdated > 0 ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15) : archPanel.chipBg
        }

        StatusPill {
            visible: root.themeUpdLocalEdits > 0
            icon: "edit"
            label: root.themeUpdLocalEdits + " with local edits"
            textColor: root.inkDeep
        }

        StatusPill {
            visible: root.themeUpdDegraded
            icon: "warning"
            label: "Check incomplete"
            textColor: root.sealRaw
        }

        StatusPill {
            visible: {
                if (root.themeUpdChecked === "") return false
                var d = new Date(root.themeUpdChecked)
                return !isNaN(d.getTime())
            }
            icon: "schedule"
            label: {
                var d = new Date(root.themeUpdChecked)
                return "Checked " + Qt.formatDateTime(d, "HH:mm")
            }
            textColor: root.sumiHi
            bgTint: archPanel.chipBg
        }
    }

    // Error banner
    Rectangle {
        visible: archPanel.removeError !== ""
        width: parent.width
        height: 32
        radius: 12
        color: Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.15)
        Row {
            anchors.centerIn: parent
            spacing: 6
            IconText { text: "error"; color: root.sealRaw; font.pixelSize: 16 }
            UiText {
                text: "Remove failed · " + archPanel.removeError
                color: root.sealRaw; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium
            }
        }
    }

    // Current theme stale banner
    Rectangle {
        visible: root.themeUpdCurrentStale
        width: parent.width
        height: 42
        radius: 14
        color: archPanel.chipBg
        Row {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            IconText { text: "sync_problem"; color: root.inkDeep; font.pixelSize: 18 }
            UiText {
                text: "Current theme updated — live copy is stale"
                color: root.ink; font.family: root.barFont; font.pixelSize: 12; font.weight: Font.Medium
            }
        }
        PillButton {
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 28; radius: 14
            label: "Re-apply"
            icon: "sync"
            onClicked: archPanel.reapplyCurrentTheme()
        }
    }

    // ── Theme List Card ──
    Card {
        title: "Themes"
        trailing: root.themeUpdList.length > 0
            ? (root.themeUpdList.length + (root.themeUpdList.length === 1 ? " theme" : " themes"))
            : ""

        // Column headers
        Item {
            width: parent.width
            height: 22
            Row {
                width: parent.width
                spacing: archPanel.themeGridGap
                leftPadding: 6
                rightPadding: 6
                UiText {
                    width: parent.width - archPanel.themeRightBlockWidth - archPanel.themeGridGap - 12
                    text: "THEME"
                    color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                }
                Item { width: archPanel.themeActionsWidth; height: 1 }
                UiText {
                    width: archPanel.themeBehindWidth
                    text: "BEHIND"
                    color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                }
                UiText {
                    width: archPanel.themeStateWidth
                    text: "STATE"
                    color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                }
            }
        }

        // Theme list
        Item {
        width: parent.width
        height: Math.min(themesCol.implicitHeight, 240)
        Flickable {
            id: themesFlick
            anchors.fill: parent
            contentHeight: themesCol.implicitHeight
            clip: true
            interactive: themesCol.implicitHeight > 240

        Column {
            id: themesCol
            width: parent.width
            spacing: 2

            Repeater {
                model: root.themeUpdList

                delegate: Item {
                    id: themeRow
                    required property var modelData
                    required property int index
                    readonly property bool isUnreach:   modelData.state === "unreachable"
                    readonly property bool isLocalEdits: modelData.state === "local-edits"
                    readonly property bool isClean:      modelData.state === "clean"
                    readonly property bool canViewChanges: modelData.behind > 0 && !isUnreach
                    readonly property var localFiles: modelData.files || []
                    readonly property string localReason: modelData.reason || ""
                    readonly property string localFileLabel: localFiles.length > 0
                        ? localFiles[0] + (localFiles.length > 1 ? " +" + (localFiles.length - 1) : "")
                        : localReason
                    readonly property string stateLabel: isUnreach ? "offline"
                        : isLocalEdits ? (localReason === "untracked conflict" ? "conflict"
                            : localReason === "tracked edits" ? "edits"
                            : localReason === "local commits" ? "commits"
                            : "changes")
                        : "clean"
                    readonly property string stateTooltip: {
                        if (!isLocalEdits) return ""
                        if (localReason === "local commits")
                            return "Blocked · local commits ahead of upstream"

                        var title = localReason === "untracked conflict"
                            ? "Blocked · untracked overwrite conflict"
                            : localReason === "tracked edits"
                                ? "Blocked · tracked edits (staged or unstaged)"
                                : "Blocked · local changes"
                        if (localFiles.length === 0) return title

                        var noun = localReason === "untracked conflict"
                            ? (localFiles.length === 1 ? "conflicting path shown" : "conflicting paths shown")
                            : (localFiles.length === 1 ? "changed file shown" : "changed files shown")
                        return title + "\n" + localFiles.length + " " + noun + " · " + localFileLabel
                    }
                    // A per-theme update is pinned to the commit saved by the last
                    // scan. Local-edits/unreachable/old-schema rows stay review-only.
                    readonly property bool canPull: archPanel.isPinnedThemeUpdate(modelData)
                    readonly property bool canReinstall: archPanel.canReinstallTheme(modelData)
                    readonly property bool canRemove: !root.themeUpdChecking
                        && /^[A-Za-z0-9._-]+$/.test(modelData.name || "")
                    readonly property bool confirmingRemove:
                        archPanel.pendingRemoveName === String(modelData.name || "")
                    readonly property bool removeFlowIdle:
                        archPanel.pendingRemoveName === ""

                    width: parent.width
                    height: 22

                    Row {
                        width: parent.width
                        height: 22
                        spacing: archPanel.themeGridGap
                        UiText {
                            width: parent.width - archPanel.themeRightBlockWidth - archPanel.themeGridGap
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: modelData.current ? root.seal : root.ink
                            font.family: root.barFont; font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                        Item {
                            width: archPanel.themeActionsWidth
                            height: 22

                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: themeRow.confirmingRemove ? 132 : 100
                                height: parent.height
                                spacing: 4

                                // Slot 1: normal update, or the explicit inline remove
                                // confirmation. The fixed outer action area keeps the
                                // following information columns aligned in every state.
                                Item {
                                    width: themeRow.confirmingRemove
                                        ? archPanel.removeBusy ? 108 : 52
                                        : 52
                                    height: 22
                                    Rectangle {
                                        id: primaryAction
                                        readonly property bool actionEnabled: themeRow.confirmingRemove
                                            ? !archPanel.removeBusy && !root.themeUpdChecking
                                            : themeRow.removeFlowIdle && themeRow.canPull
                                        visible: themeRow.confirmingRemove
                                            || (themeRow.removeFlowIdle && themeRow.canPull)
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.verticalCenterOffset: -2
                                        width: parent.width; height: 18; radius: root.panelButtonRadius
                                        color: (primaryMa.containsMouse && actionEnabled)
                                            ? root.fillPrimaryHover : root.seal
                                        opacity: archPanel.removeBusy && themeRow.confirmingRemove ? 0.65 : 1.0
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        TooltipMixin {
                                            id: primaryTip
                                            root: archPanel.root
                                            owner: primaryAction
                                            text: themeRow.confirmingRemove
                                                ? archPanel.removeBusy
                                                    ? "Removing theme · " + modelData.name
                                                    : archPanel.removeError !== ""
                                                        ? "Retry removal · " + archPanel.removeError
                                                        : "Confirm removal · " + modelData.name
                                                : "Update theme · " + modelData.name
                                        }
                                        UiText {
                                            anchors.centerIn: parent
                                            text: themeRow.confirmingRemove
                                                ? archPanel.removeBusy ? "removing…"
                                                    : archPanel.removeError !== "" ? "retry" : "remove"
                                                : "update"
                                            color: root.paper
                                            font.family: root.barFont
                                            font.pixelSize: 9
                                        }
                                        MouseArea {
                                            id: primaryMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: primaryAction.actionEnabled
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onEntered: primaryTip.show()
                                            onExited: primaryTip.hide()
                                            onClicked: {
                                                primaryTip.hide()
                                                if (themeRow.confirmingRemove)
                                                    archPanel.confirmRemoveTheme()
                                                else
                                                    archPanel.updateOneTheme(modelData.name)
                                            }
                                        }
                                    }
                                }

                                // Slot 2 becomes a text button matching Remove while
                                // armed. Once removal starts, the progress button uses
                                // both text slots until the command finishes.
                                Rectangle {
                                    id: secondaryAction
                                    readonly property bool actionEnabled: themeRow.confirmingRemove
                                        ? !archPanel.removeBusy
                                        : themeRow.removeFlowIdle && themeRow.canReinstall
                                    visible: !themeRow.confirmingRemove || !archPanel.removeBusy
                                    width: themeRow.confirmingRemove ? 52 : 20
                                    height: 18; radius: root.panelButtonRadius
                                    color: themeRow.confirmingRemove
                                        ? (secondaryMa.containsMouse && actionEnabled)
                                            ? root.fillPrimaryHover : root.seal
                                        : (secondaryMa.containsMouse && actionEnabled)
                                            ? root.fillHover : "transparent"
                                    opacity: actionEnabled ? 1.0 : 0.28
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    TooltipMixin {
                                        id: secondaryTip
                                        root: archPanel.root
                                        owner: secondaryAction
                                        text: themeRow.confirmingRemove
                                            ? "Cancel removal · " + modelData.name
                                            : "Reinstall theme · " + modelData.name
                                    }
                                    UiText {
                                        anchors.centerIn: parent
                                        visible: themeRow.confirmingRemove
                                        text: "cancel"
                                        color: root.paper
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                    }
                                    IconText {
                                        anchors.centerIn: parent
                                        visible: !themeRow.confirmingRemove
                                        text: "\uE5D5"
                                        color: secondaryMa.containsMouse && secondaryAction.actionEnabled
                                            ? root.seal : root.sumi
                                        font.pixelSize: 14
                                    }
                                    MouseArea {
                                        id: secondaryMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: secondaryAction.actionEnabled
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onEntered: secondaryTip.show()
                                        onExited: secondaryTip.hide()
                                        onClicked: {
                                            secondaryTip.hide()
                                            if (themeRow.confirmingRemove)
                                                archPanel.cancelRemoveTheme()
                                            else
                                                archPanel.reinstallTheme(modelData.name, modelData.remoteUrl)
                                        }
                                    }
                                }

                                // Slot 3 is trash normally; while armed it keeps the
                                // reinstall action to the right of Cancel.
                                Rectangle {
                                    id: tertiaryAction
                                    readonly property bool actionEnabled: themeRow.confirmingRemove
                                        ? !archPanel.removeBusy && themeRow.canReinstall
                                        : themeRow.removeFlowIdle && themeRow.canRemove
                                    width: 20; height: 18; radius: root.panelButtonRadius
                                    color: {
                                        if (!tertiaryMa.containsMouse || !actionEnabled) return "transparent"
                                        if (themeRow.confirmingRemove) return root.fillHover
                                        return Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, root.fillHoverAlpha)
                                    }
                                    opacity: actionEnabled ? 1.0 : 0.28
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    TooltipMixin {
                                        id: tertiaryTip
                                        root: archPanel.root
                                        owner: tertiaryAction
                                        text: themeRow.confirmingRemove
                                            ? "Reinstall theme · " + modelData.name
                                            : "Remove theme · " + modelData.name
                                    }
                                    IconText {
                                        anchors.centerIn: parent
                                        text: themeRow.confirmingRemove ? "\uE5D5" : "\uE872"
                                        color: tertiaryMa.containsMouse && tertiaryAction.actionEnabled
                                            ? themeRow.confirmingRemove ? root.seal : root.sealRaw
                                            : root.sumi
                                        font.pixelSize: themeRow.confirmingRemove ? 14 : 13
                                    }
                                    MouseArea {
                                        id: tertiaryMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: tertiaryAction.actionEnabled
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onEntered: tertiaryTip.show()
                                        onExited: tertiaryTip.hide()
                                        onClicked: {
                                            tertiaryTip.hide()
                                            if (themeRow.confirmingRemove) {
                                                archPanel.cancelRemoveTheme()
                                                archPanel.reinstallTheme(modelData.name, modelData.remoteUrl)
                                            } else {
                                                archPanel.removeTheme(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Item {
                            width: archPanel.themeBehindWidth
                            height: 22
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                text: isUnreach ? "—" : (modelData.behind + (modelData.behind === 1 ? " commit" : " commits"))
                                color: behindMa.containsMouse && themeRow.canViewChanges ? root.seal : Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.7)
                                font.family: root.barFont; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: behindMa
                                anchors.fill: parent
                                hoverEnabled: themeRow.canViewChanges
                                enabled: themeRow.canViewChanges
                                cursorShape: themeRow.canViewChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: archPanel.viewThemeChanges(modelData.name)
                            }
                        }
                        // right slot: status only; all per-theme actions live in the
                        // intentionally unlabelled column immediately before Behind.
                        Item {
                            id: stateSlot
                            width: archPanel.themeStateWidth
                            height: 22
                            TooltipMixin {
                                id: stateTip
                                root: archPanel.root
                                owner: stateSlot
                                text: themeRow.stateTooltip
                            }
                            UiText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: themeRow.stateLabel
                                color: stateMa.containsMouse && themeRow.stateTooltip !== ""
                                    ? root.seal
                                    : isLocalEdits ? root.inkDeep : root.sumi
                                font.family: root.barFont; font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                            MouseArea {
                                id: stateMa
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                hoverEnabled: true
                                cursorShape: themeRow.stateTooltip !== "" ? Qt.WhatsThisCursor : Qt.ArrowCursor
                                onEntered: { if (themeRow.stateTooltip !== "") stateTip.show() }
                                onExited: stateTip.hide()
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width - 16; height: 1
                        color: root.sep
                        visible: index < root.themeUpdList.length - 1
                    }
                }
            }

            UiText {
                width: parent.width
                visible: root.themeUpdList.length === 0
                text: root.themeUpdChecked === "" ? "Not checked yet" : "All themes up to date"
                color: Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.5)
                font.family: root.barFont; font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                topPadding: 20
            }
        }
        }
        ScrollThumb { flick: themesFlick }
    }
}

    // ── buttons ──
    Row {
        width: parent.width
        spacing: 8

        // Check themes — runs the read-only check script; disabled while scanning
        Rectangle {
            width: (parent.width - 8) / 2
            height: 28; radius: root.panelButtonRadius
            color: (checkMa.containsMouse && !root.themeUpdChecking) ? root.fillHover : root.fillIdle
            border.color: (checkMa.containsMouse && !root.themeUpdChecking) ? root.seal : root.sep
            border.width: 0
            opacity: root.themeUpdChecking ? 0.5 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            UiText {
                anchors.centerIn: parent
                text: root.themeUpdChecking ? "Checking…" : "Check themes"
                color: (checkMa.containsMouse && !root.themeUpdChecking) ? root.seal : root.ink
                font.family: root.barFont; font.pixelSize: 11
            }
            MouseArea {
                id: checkMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.themeUpdChecking
                cursorShape: root.themeUpdChecking ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: root.themeCheckTick++
            }
        }

        // Update clean — applies only clean themes with a saved target
        // commit; blocked/local-edits stay untouched for review.
        Rectangle {
            readonly property int cleanCount: archPanel.cleanThemeUpdateCount()
            readonly property bool canApply: cleanCount > 0 && !root.themeUpdChecking
            width: (parent.width - 8) / 2
            height: 28; radius: root.panelButtonRadius
            opacity: canApply ? 1.0 : 0.45
            color: (allMa.containsMouse && canApply) ? root.fillPrimaryHover : root.seal
            border.color: "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            UiText {
                anchors.centerIn: parent
                text: root.themeUpdChecking ? "Checking…"
                                      : parent.canApply ? (root.themeUpdLocalEdits > 0 ? "Update clean" : "Update all")
                                      : root.themeUpdOutdated > 0 ? "Review first" : "No updates"
                color: root.paper
                font.family: root.barFont; font.pixelSize: 11
            }
            MouseArea {
                id: allMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.canApply
                cursorShape: parent.canApply ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: archPanel.updateAllThemes()
            }
        }
    }

}
// ══════════ END THEMES TAB ══════════

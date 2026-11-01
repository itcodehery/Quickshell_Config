import QtQuick
import ".."
import Quickshell
import "../../modules"

// ══════════ PACKAGES TAB ══════════
Column {
    id: packagesTab
    required property var archPanel
    readonly property var root: archPanel.root
    readonly property var panelUpdateRunner: archPanel.panelUpdateRunner

    width: parent.width
    spacing: 8
    visible: root.activeUpdateTab === "packages"

    component ScrollThumb: ArchUpdaterScrollThumb {
        archPanel: packagesTab.archPanel
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

        // OK count
        StatusPill {
            visible: root.archUpdates.length > 0
            icon: "✓"
            label: root.archGateOk + " OK"
            textColor: root.green
        }

        // Review count
        StatusPill {
            visible: root.archGateWarn > 0
            icon: "⚠"
            label: root.archGateWarn + " review"
            textColor: root.inkDeep
        }

        // Blocked count
        StatusPill {
            visible: root.archGateFail > 0
            icon: "✗"
            label: root.archGateFail + " blocked"
            textColor: root.sealRaw
        }

        // Degraded
        StatusPill {
            visible: root.archGateDegraded
            icon: "⚠"
            label: "protection limited"
            textColor: root.sealRaw
        }

        // Stale
        StatusPill {
            visible: root.archGateStale
            icon: "⚠"
            label: "source stale"
            textColor: root.sealRaw
        }

        // Mirrors agree
        StatusPill {
            visible: root.archGateMirrorsAgree && !root.archGateDegraded
            icon: "✓"
            label: "mirrors synced"
            textColor: root.green
        }

        // Mirror mismatch
        StatusPill {
            visible: root.archGateMirrorMismatch
            icon: "⚠"
            label: "mirror mismatch"
            textColor: root.sealRaw
        }

        // Blacklist pill (clickable link)
        StatusPill {
            visible: root.archGateBlacklist > 0
            icon: "shield"
            label: "blacklist " + root.archGateBlacklist + (root.archGateListDate !== "" ? " · " + root.archGateListDate : "")
            textColor: root.ink
            bgTint: archPanel.chipBg
            clickable: true
            onClicked: Quickshell.execDetached(["bash", "-c",
                "omarchy-launch-floating-terminal-with-presentation 'less ~/.local/share/qs-aur-blacklist.txt'"])
        }
    }

    // Escalation warning banner
    Rectangle {
        visible: root.archGateFail > 0
        width: parent.width
        height: 32
        radius: 12
        color: Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.15)
        Row {
            anchors.centerIn: parent
            spacing: 6
            IconText { text: "warning"; color: root.sealRaw; font.pixelSize: 16 }
            UiText {
                text: "Installed copy may be compromised — run the infection checker"
                color: root.sealRaw; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium
            }
        }
    }

    // ── Package List Card ──
    Card {
        title: "Packages"
        trailing: root.archUpdates.length > 0
            ? (root.archUpdates.length + (root.archUpdates.length === 1 ? " package" : " packages"))
            : ""

        // Column headers
        Item {
            width: parent.width
            height: 22

            Row {
                width: parent.width
                spacing: 8
                leftPadding: 6
                rightPadding: 6

                UiText {
                    width: (parent.width - 12) * 0.44
                    text: "PACKAGE"
                    color: root.sumiHi
                    font.family: root.barFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
                UiText {
                    width: (parent.width - 12) * 0.28
                    text: "INSTALLED"
                    color: root.sumiHi
                    font.family: root.barFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
                UiText {
                    width: (parent.width - 12) * 0.28
                    text: "AVAILABLE"
                    color: root.sumiHi
                    font.family: root.barFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.8
                }
            }
        }

        // Update list
        Item {
            width: parent.width
            height: Math.min(updatesCol.implicitHeight, 260)

            Flickable {
                id: packagesFlick
                anchors.fill: parent
                contentHeight: updatesCol.implicitHeight
                clip: true
                interactive: updatesCol.implicitHeight > height

                Column {
                    id: updatesCol
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: root.archUpdates

                        delegate: Rectangle {
                            id: pkgItem
                            required property var modelData
                            required property int index

                            readonly property color srcColor: {
                                if (modelData.source === "system") return root.seal;
                                if (modelData.source === "aur") return root.indigo;
                                return root.sumi;
                            }

                            readonly property var gv: archPanel.gateMap[modelData.name]
                            readonly property bool vBlocked: gv !== undefined && gv.verdict === "FAIL"
                            readonly property bool vReview:  gv !== undefined && gv.verdict === "WARN"
                            readonly property bool vOk:      gv !== undefined && gv.verdict === "OK"
                            readonly property string vReason: (gv !== undefined && gv.reason) ? gv.reason : ""
                            readonly property bool showReason: vReason !== "" && (vBlocked || vReview)

                            width: parent.width
                            height: showReason ? 52 : 36
                            radius: 10
                            color: pkgRowMa.containsMouse
                                ? archPanel.chipHover
                                : (index % 2 === 1 ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.03) : "transparent")
                            opacity: vBlocked ? 0.55 : 1.0
                            Behavior on color { ColorAnimation { duration: 100 } }

                            MouseArea {
                                id: pkgRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 2

                                Row {
                                    width: parent.width
                                    height: 24
                                    spacing: 8

                                    // Package column: Squircle badge + Name
                                    Row {
                                        width: (parent.width - 16) * 0.44
                                        height: parent.height
                                        spacing: 6

                                        Rectangle {
                                            width: 22; height: 22; radius: 7
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: vBlocked
                                                ? Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.2)
                                                : vReview
                                                    ? Qt.rgba(root.inkDeep.r, root.inkDeep.g, root.inkDeep.b, 0.2)
                                                    : vOk
                                                        ? Qt.rgba(root.green.r, root.green.g, root.green.b, 0.2)
                                                        : Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 0.15)
                                            UiText {
                                                anchors.centerIn: parent
                                                text: vBlocked ? "✗" : vReview ? "⚠" : vOk ? "✓" : "·"
                                                color: vBlocked ? root.sealRaw : vReview ? root.inkDeep : vOk ? root.green : root.sumi
                                                font.family: root.barFont
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                            }
                                        }

                                        UiText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 28
                                            text: modelData.name
                                            color: vBlocked ? root.sealRaw : root.ink
                                            font.family: root.barFont
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Installed column
                                    UiText {
                                        width: (parent.width - 16) * 0.28
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.oldVer
                                        color: root.sumiHi
                                        font.family: root.mono
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    // Available column
                                    Row {
                                        width: (parent.width - 16) * 0.28
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        UiText {
                                            width: parent.width - (modelData.source === "aur" ? 34 : 0)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.newVer
                                            color: pkgItem.srcColor
                                            font.family: root.mono
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            visible: modelData.source === "aur"
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 28; height: 16; radius: 5
                                            color: Qt.rgba(root.indigo.r, root.indigo.g, root.indigo.b, 0.2)
                                            UiText {
                                                anchors.centerIn: parent
                                                text: "AUR"
                                                color: root.indigo
                                                font.family: root.barFont
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }

                                // Reason row
                                Row {
                                    visible: pkgItem.showReason
                                    width: parent.width
                                    spacing: 5
                                    leftPadding: 28

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "info"
                                        color: vBlocked ? root.sealRaw : root.sumiHi
                                        font.pixelSize: 12
                                    }

                                    UiText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 48
                                        text: pkgItem.vReason
                                        color: vBlocked ? root.sealRaw : root.sumiHi
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        width: parent.width
                        height: 100
                        visible: root.archUpdates.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "check_circle"
                                color: root.green
                                font.pixelSize: 32
                            }
                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "All packages up to date"
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No system or AUR updates pending"
                                color: root.sumi
                                font.family: root.barFont
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            ScrollThumb { flick: packagesFlick }
        }
    }

    // ── Buttons ──
    Row {
        width: parent.width
        spacing: 8

        // Refresh
        PillButton {
            width: root.evenW((parent.width - 8 * (archPanel.btnCount - 1)) / archPanel.btnCount)
            icon: "refresh"
            label: "Refresh"
            onClicked: root.archRefreshTick++
        }

        // Update (primary)
        PillButton {
            width: root.evenW((parent.width - 8 * (archPanel.btnCount - 1)) / archPanel.btnCount)
            primary: true
            icon: "upgrade"
            btnEnabled: archPanel.canUpdate
            label: archPanel.canUpdate
                ? archPanel.packageUpdateButtonText
                : archPanel.repoBlockButtonText
            onClicked: {
                var command = [archPanel.packageUpdateCommand]
                if (archPanel.usesOmarchyUpdater) {
                    if (archPanel.packageUpdateMode === "cli") command.push("update")
                } else {
                    command.push(
                        "--run",
                        root.archScanId,
                        root.archScanHash,
                        String(root.archScanSystemCount),
                        String(root.archScanCheckedEpoch),
                        String(archPanel.aurReviewPackages)
                    )
                }
                archPanel.launchPackageUpdate(command)
            }
        }

        // Review AUR
        PillButton {
            visible: archPanel.aurReviewPackages > 0
            width: root.evenW((parent.width - 8 * (archPanel.btnCount - 1)) / archPanel.btnCount)
            icon: "visibility"
            label: "Review " + archPanel.aurReviewPackages + " AUR"
            onClicked: {
                panelUpdateRunner.command = ["bash", "-c",
                    "omarchy-launch-floating-terminal-with-presentation 'echo \"AUR review — no packages are installed by this view.\"; echo; AUR=$(command -v paru || command -v yay || echo yay); \"$AUR\" -Qum; echo; echo \"Review each PKGBUILD before building these manually.\"'"];
                root.archVisible = false;
                panelUpdateRunner.running = false;
                panelUpdateRunner.running = true;
            }
        }
    }
}
// ══════════ END PACKAGES TAB ══════════

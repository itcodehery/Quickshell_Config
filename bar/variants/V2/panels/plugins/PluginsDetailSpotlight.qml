import QtQuick
import ".."
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── LEFT COLUMN: PLUGIN SPOTLIGHT / WIDGET PREVIEW & ACTIONS ─────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: leftColContainer
    required property var root
    required property var pluginsSection
    required property var filteredPluginsModel
    signal refreshRequested()

    radius: 20
    color: root.fillIdle
    border.width: 0
    clip: true

    readonly property var curItem: (pluginsSection.focusedIndex >= 0 && pluginsSection.focusedIndex < filteredPluginsModel.count)
        ? filteredPluginsModel.get(pluginsSection.focusedIndex) : null

    // Left Top Bar
    Item {
        id: leftTopBar
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        height: 36
        z: 5

        // Top Right: Refresh & Close Button
        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            spacing: 6

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: refreshLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                IconText {
                    anchors.centerIn: parent
                    text: "refresh"
                    font.pixelSize: 13
                    color: root.ink
                }

                SpringPress {}
                MouseArea {
                    id: refreshLeftMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: leftColContainer.refreshRequested()
                }
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: closeLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    font.pixelSize: 13
                    color: root.ink
                }

                SpringPress {}
                MouseArea {
                    id: closeLeftMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pluginsSection.closeRequested()
                }
            }
        }
    }

    // Left Column Body Content
    Item {
        id: leftBodyContainer
        anchors.top: leftTopBar.bottom
        anchors.topMargin: 0
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10

        ConnectedTabCard {
            root: pluginsSection.root
            anchors.fill: parent
            dotColor: pluginsSection.isRemoving ? "#ea6962" : (leftColContainer.curItem ? "#a9b665" : root.sumiHi)
            icon: "widgets"
            text: pluginsSection.isRemoving ? "Removing..." : "Plugin Spotlight"

            // 1. Selected Plugin Spotlight Widget (Compact, No Scrolling Needed)
            Column {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 8
                visible: leftColContainer.curItem !== null

                // Top: Compact Plugin Info Row (Icon + Name + Badges)
                Row {
                    width: parent.width
                    spacing: 10

                    // Icon Avatar
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)

                        IconText {
                            anchors.centerIn: parent
                            text: leftColContainer.curItem ? leftColContainer.curItem.icon : "extension"
                            font.pixelSize: 20
                            color: root.seal
                        }
                    }

                    // Title & Badges Column
                    Column {
                        width: parent.width - 40 - 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            width: parent.width
                            text: leftColContainer.curItem ? leftColContainer.curItem.name : ""
                            font.family: root.barFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: root.ink
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Row {
                            spacing: 5
                            width: parent.width

                            Rectangle {
                                height: 18
                                radius: 9
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.14)
                                width: kindBadgeText.implicitWidth + 10

                                Text {
                                    id: kindBadgeText
                                    anchors.centerIn: parent
                                    text: leftColContainer.curItem ? leftColContainer.curItem.kinds : ""
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: root.seal
                                }
                            }

                            Rectangle {
                                height: 18
                                radius: 9
                                readonly property bool isPinned: (leftColContainer.curItem && root && root.isPluginPinned && root.isPluginPinned(leftColContainer.curItem.id))
                                color: isPinned
                                    ? Qt.rgba(root.color03.r, root.color03.g, root.color03.b, 0.20)
                                    : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                width: pinSpotlightText.implicitWidth + 10

                                Text {
                                    id: pinSpotlightText
                                    anchors.centerIn: parent
                                    text: parent.isPinned ? "Pinned" : "Unpinned"
                                    font.family: root.barFont
                                    font.pixelSize: 8
                                    font.weight: Font.Medium
                                    color: parent.isPinned ? root.color03 : root.sumi
                                }
                            }
                        }
                    }
                }

                // Primary Action: Launch Plugin Button
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 16
                    color: launchMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal

                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            text: (leftColContainer.curItem && leftColContainer.curItem.enabled === false) ? "power_settings_new" : "open_in_new"
                            font.pixelSize: 13
                            color: root.paper
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: (leftColContainer.curItem && leftColContainer.curItem.enabled === false) ? "Enable Plugin" : "Launch Plugin"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.paper
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: launchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pluginsSection.triggerLaunch(pluginsSection.focusedIndex)
                    }
                }

                // Secondary Action Row: Pin, Disable & Remove Buttons
                Row {
                    width: parent.width
                    spacing: 6

                    // Pin Button
                    Rectangle {
                        id: pinSpotBtn
                        readonly property int btnCount: disableSpotBtn.visible ? 3 : 2
                        width: Math.floor((parent.width - 6 * (btnCount - 1)) / btnCount)
                        height: 28
                        radius: 14
                        readonly property bool isPinned: (leftColContainer.curItem && root && root.isPluginPinned && root.isPluginPinned(leftColContainer.curItem.id))
                        color: isPinned
                            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, pinSpotMa.containsMouse ? 0.34 : 0.24)
                            : (pinSpotMa.containsMouse ? root.fillHover : root.fillIdle)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "push_pin"
                                font.pixelSize: 11
                                fill: pinSpotBtn.isPinned ? 1 : 0
                                color: pinSpotBtn.isPinned ? root.seal : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: pinSpotBtn.isPinned ? "Unpin" : "Pin"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        TooltipMixin {
                            id: pinSpotTip
                            root: pluginsSection.root
                            owner: pinSpotBtn
                            text: pinSpotBtn.isPinned ? "Unpin from top header" : "Pin icon to top header (left of Screentime)"
                        }

                        SpringPress {}
                        MouseArea {
                            id: pinSpotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: pinSpotTip.show()
                            onExited: pinSpotTip.hide()
                            onClicked: {
                                pinSpotTip.hide()
                                pluginsSection.togglePinCurrent(pluginsSection.focusedIndex)
                            }
                        }
                    }

                    // Disable Plugin Button (only for enabled plugins)
                    Rectangle {
                        id: disableSpotBtn
                        visible: !!(leftColContainer.curItem && leftColContainer.curItem.enabled !== false)
                        width: pinSpotBtn.width
                        height: 28
                        radius: 14
                        color: disableSpotMa.containsMouse ? root.fillHover : root.fillIdle

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "toggle_off"
                                font.pixelSize: 13
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Disable"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: disableSpotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (leftColContainer.curItem) pluginsSection.disablePlugin(leftColContainer.curItem.id)
                            }
                        }
                    }

                    // Remove / Delete Plugin Button
                    Rectangle {
                        id: removeSpotBtn
                        width: parent.width - pinSpotBtn.width - (disableSpotBtn.visible ? disableSpotBtn.width + 6 : 0) - 6
                        height: 28
                        radius: 14
                        color: removeSpotMa.containsMouse ? Qt.rgba(0.92, 0.41, 0.38, 0.22) : Qt.rgba(0.92, 0.41, 0.38, 0.08)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "delete_outline"
                                font.pixelSize: 12
                                color: "#ea6962"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Remove"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: "#ea6962"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        SpringPress {}
                        MouseArea {
                            id: removeSpotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (leftColContainer.curItem) {
                                    pluginsSection.requestRemovePlugin(leftColContainer.curItem.id, leftColContainer.curItem.name)
                                }
                            }
                        }
                    }
                }
            }

            // 2. Empty / No Plugin Selected State
            Column {
                anchors.centerIn: parent
                visible: leftColContainer.curItem === null
                spacing: 8
                width: parent.width - 32

                Rectangle {
                    width: 48
                    height: 48
                    radius: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)

                    IconText {
                        anchors.centerIn: parent
                        text: "extension_off"
                        font.pixelSize: 24
                        color: root.ink
                        opacity: 0.35
                    }
                }

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 3
                    width: parent.width

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No Plugin Selected"
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: root.ink
                        opacity: 0.8
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Select a plugin on the right to view details"
                        font.family: root.barFont
                        font.pixelSize: 10
                        color: root.ink
                        opacity: 0.4
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }
        }
    }
}

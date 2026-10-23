import QtQuick
import "../modules"
import "../motion"

// Shared tab switcher: selected option is a fully rounded pill,
// the other options are squarer rounded tiles. No borders anywhere.
Row {
    id: tabs

    // Theme object (the panel's `root`) providing seal / paper / ink / barFont
    property var theme: null
    // [{ id, label, icon (optional), badge (optional) }]
    property var model: []
    property string current: ""
    property int tabHeight: 26
    property int fontSize: 11
    // "filled": selected = solid seal pill (primary switcher)
    // "tonal":  selected = soft seal-tinted pill with seal text (secondary switcher)
    property string variant: "filled"
    readonly property bool tonal: variant === "tonal"
    property bool fill: false   // stretch options to share the Row's width equally

    signal activated(string id)

    spacing: 4

    Repeater {
        model: tabs.model

        delegate: Rectangle {
            id: tab
            required property var modelData
            readonly property bool isCur: tabs.current === modelData.id
            readonly property color fg: isCur ? (tabs.tonal ? tabs.theme.seal : tabs.theme.paper) : tabs.theme.ink

            height: tabs.tabHeight
            width: tabs.fill
                ? Math.floor((tabs.width - tabs.spacing * (tabs.model.length - 1)) / tabs.model.length)
                : Math.max(tabs.tabHeight * 2, content.implicitWidth + 24)
            radius: isCur ? height / 2 : 8
            border.width: 0
            color: isCur
                ? (tabs.tonal
                    ? Qt.rgba(tabs.theme.seal.r, tabs.theme.seal.g, tabs.theme.seal.b, 0.22)
                    : tabs.theme.seal)
                : Qt.rgba(tabs.theme.ink.r, tabs.theme.ink.g, tabs.theme.ink.b,
                          tabs.tonal ? (tabHov.hovered ? 0.10 : 0.05) : (tabHov.hovered ? 0.14 : 0.08))

            Behavior on radius { SpringAnimation { spring: Motion.pressSpring; damping: Motion.pressDamping; epsilon: 0.05 } }
            Behavior on color { ColorAnimation { duration: 140 } }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 5

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !!tab.modelData.icon
                    text: tab.modelData.icon || ""
                    font.pixelSize: tabs.fontSize + 1
                    color: tab.fg
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.label
                    font.family: tabs.theme.barFont
                    font.pixelSize: tabs.fontSize
                    font.weight: tab.isCur ? Font.DemiBold : Font.Medium
                    color: tab.fg
                    opacity: tab.isCur ? 1.0 : 0.8
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: (tab.modelData.badge || 0) > 0
                    height: 16
                    width: Math.max(16, badgeNum.implicitWidth + 8)
                    radius: 8
                    color: tab.isCur
                        ? Qt.rgba(tabs.theme.paper.r, tabs.theme.paper.g, tabs.theme.paper.b, 0.28)
                        : Qt.rgba(tabs.theme.seal.r, tabs.theme.seal.g, tabs.theme.seal.b, 0.20)

                    Text {
                        id: badgeNum
                        anchors.centerIn: parent
                        text: String(tab.modelData.badge || 0)
                        font.family: tabs.theme.barFont
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: tab.isCur ? tabs.theme.paper : tabs.theme.seal
                    }
                }
            }

            HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
            SpringPress {}
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tabs.activated(tab.modelData.id)
            }
        }
    }
}

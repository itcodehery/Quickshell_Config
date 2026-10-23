import QtQuick
import QtQuick.Shapes
import Quickshell
import "../modules"

Item {
    id: tabCard

    required property var root

    // Tab content properties
    property color dotColor: root.sumiHi
    property bool dotVisible: true
    property string icon: ""
    property string text: ""
    property color cardBg: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.05)
    property color cardBorder: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

    // Geometry knobs
    property real tabHeight: 30
    property real tabWidth: Math.min(tabContentRow.implicitWidth + 24, Math.max(120, width - 80))
    property real tabX: 16
    property real filletRadius: 7
    property real tabRadius: 9
    property real cardRadius: 14

    default property alias contentData: cardBody.data

    // Unified Shape Background (Card Body + Protruding Browser Tab in ONE single path)
    Shape {
        id: bgShape
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        z: 0

        readonly property real w: tabCard.width
        readonly property real h: tabCard.height
        readonly property real th: tabCard.tabHeight
        readonly property real tw: tabCard.tabWidth
        readonly property real tx: tabCard.tabX
        readonly property real fr: tabCard.filletRadius
        readonly property real tr: tabCard.tabRadius
        readonly property real cr: tabCard.cardRadius

        ShapePath {
            strokeColor: tabCard.cardBorder
            strokeWidth: 1
            fillColor: tabCard.cardBg
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            // 1. Start on Card Left edge at cardRadius
            startX: 0
            startY: bgShape.cr

            // 2. Card top-left corner
            PathQuad {
                x: bgShape.tx - bgShape.fr
                y: 0
                controlX: 0
                controlY: 0
            }

            // 3. Left concave fillet curving UP into tab
            PathQuad {
                x: bgShape.tx
                y: -bgShape.fr
                controlX: bgShape.tx
                controlY: 0
            }

            // 4. Tab left vertical wall
            PathLine {
                x: bgShape.tx
                y: -bgShape.th + bgShape.tr
            }

            // 5. Tab top-left rounded corner
            PathQuad {
                x: bgShape.tx + bgShape.tr
                y: -bgShape.th
                controlX: bgShape.tx
                controlY: -bgShape.th
            }

            // 6. Tab top horizontal edge
            PathLine {
                x: bgShape.tx + bgShape.tw - bgShape.tr
                y: -bgShape.th
            }

            // 7. Tab top-right rounded corner
            PathQuad {
                x: bgShape.tx + bgShape.tw
                y: -bgShape.th + bgShape.tr
                controlX: bgShape.tx + bgShape.tw
                controlY: -bgShape.th
            }

            // 8. Tab right vertical wall
            PathLine {
                x: bgShape.tx + bgShape.tw
                y: -bgShape.fr
            }

            // 9. Right concave fillet curving DOWN into card top
            PathQuad {
                x: bgShape.tx + bgShape.tw + bgShape.fr
                y: 0
                controlX: bgShape.tx + bgShape.tw
                controlY: 0
            }

            // 10. Card top edge to right corner
            PathLine {
                x: bgShape.w - bgShape.cr
                y: 0
            }

            // 11. Card top-right corner
            PathQuad {
                x: bgShape.w
                y: bgShape.cr
                controlX: bgShape.w
                controlY: 0
            }

            // 12. Card right wall
            PathLine {
                x: bgShape.w
                y: bgShape.h - bgShape.cr
            }

            // 13. Card bottom-right corner
            PathQuad {
                x: bgShape.w - bgShape.cr
                y: bgShape.h
                controlX: bgShape.w
                controlY: bgShape.h
            }

            // 14. Card bottom edge
            PathLine {
                x: bgShape.cr
                y: bgShape.h
            }

            // 15. Card bottom-left corner
            PathQuad {
                x: 0
                y: bgShape.h - bgShape.cr
                controlX: 0
                controlY: bgShape.h
            }

            // 16. Close back to start
            PathLine {
                x: 0
                y: bgShape.cr
            }
        }
    }

    // ── Tab Content (Icon, dot, text inside the protruding tab) ──────────────
    Row {
        id: tabContentRow
        x: tabCard.tabX + (tabCard.tabWidth - implicitWidth) / 2
        y: -tabCard.tabHeight + (tabCard.tabHeight - implicitHeight) / 2
        spacing: 6
        z: 2

        Rectangle {
            visible: tabCard.dotVisible
            width: 6
            height: 6
            radius: 3
            color: tabCard.dotColor
            anchors.verticalCenter: parent.verticalCenter
        }

        IconText {
            visible: tabCard.icon !== ""
            text: tabCard.icon
            font.pixelSize: 13
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: tabCard.text
            font.family: root.barFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    // ── Card Body Item (Contains the child widgets/content of the card) ──────
    Item {
        id: cardBody
        anchors.fill: parent
        z: 1
    }
}

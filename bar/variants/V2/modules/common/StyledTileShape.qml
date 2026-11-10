import QtQuick
import QtQuick.Shapes

Item {
    id: shapeRoot
    anchors.fill: parent

    required property var root
    property var span: 1               // 1, 2, 4 or "1x1", "1x2", "2x2"
    property string shapeType: ""      // Custom override; if "", uses themeRoot settings
    property color fillColor: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0

    readonly property bool is1x1: span === 1 || span === "1x1"
    readonly property bool is1x2: span === 2 || span === "1x2"
    readonly property bool is2x2: span === 4 || span === "2x2"

    readonly property string resolvedShape: {
        if (shapeType !== "") return shapeType
        if (!root) return (is1x1 ? "circle" : (is1x2 ? "capsule" : "rounded"))
        if (is1x1) return root.tileShape1x1 || "circle"
        if (is1x2) return root.tileShape1x2 || "capsule"
        return root.tileShape2x2 || "rounded"
    }

    readonly property bool isSimpleRect: {
        switch (resolvedShape) {
            case "circle":
            case "capsule":
            case "rounded":
            case "squircle":
            case "leaf":
            case "tab":
            case "block":
                return true
            default:
                return false
        }
    }

    // ── Pre-calculated Corner Radii for Rectangle Shapes ──
    readonly property real calcTopLeftR: {
        switch (resolvedShape) {
            case "circle": return width / 2
            case "capsule": return height / 2
            case "rounded": return 28
            case "squircle": return is1x1 ? 18 : (is1x2 ? 18 : 24)
            case "leaf": return is2x2 ? 40 : 28
            case "tab": return is2x2 ? 26 : 22
            case "block": return is2x2 ? 8 : 6
            default: return 28
        }
    }

    readonly property real calcTopRightR: {
        switch (resolvedShape) {
            case "circle": return width / 2
            case "capsule": return height / 2
            case "rounded": return 28
            case "squircle": return is1x1 ? 18 : (is1x2 ? 18 : 24)
            case "leaf": return is2x2 ? 14 : 10
            case "tab": return is2x2 ? 26 : 22
            case "block": return is2x2 ? 8 : 6
            default: return 28
        }
    }

    readonly property real calcBottomLeftR: {
        switch (resolvedShape) {
            case "circle": return width / 2
            case "capsule": return height / 2
            case "rounded": return 28
            case "squircle": return is1x1 ? 18 : (is1x2 ? 18 : 24)
            case "leaf": return is2x2 ? 14 : 10
            case "tab": return 6
            case "block": return is2x2 ? 8 : 6
            default: return 28
        }
    }

    readonly property real calcBottomRightR: {
        switch (resolvedShape) {
            case "circle": return width / 2
            case "capsule": return height / 2
            case "rounded": return 28
            case "squircle": return is1x1 ? 18 : (is1x2 ? 18 : 24)
            case "leaf": return is2x2 ? 40 : 28
            case "tab": return 6
            case "block": return is2x2 ? 8 : 6
            default: return 28
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 1. FAST NATIVE RECTANGLE FOR HIGH-PERFORMANCE RADIUS STYLES ─────────
    // ═════════════════════════════════════════════════════════════════════════
    Rectangle {
        id: rectBg
        visible: shapeRoot.isSimpleRect
        anchors.fill: parent
        color: shapeRoot.fillColor
        border.color: shapeRoot.borderColor
        border.width: shapeRoot.borderWidth

        topLeftRadius: shapeRoot.calcTopLeftR
        topRightRadius: shapeRoot.calcTopRightR
        bottomLeftRadius: shapeRoot.calcBottomLeftR
        bottomRightRadius: shapeRoot.calcBottomRightR

        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        Behavior on topLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
        Behavior on topRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
        Behavior on bottomRightRadius { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 2. CYBER OCTAGON / CHAMFERED CUT CORNERS ─────────────────────────────
    // ═════════════════════════════════════════════════════════════════════════
    Shape {
        id: chamferShape
        visible: shapeRoot.resolvedShape === "chamfer"
        anchors.fill: parent
        asynchronous: true

        readonly property real w: width
        readonly property real h: height
        readonly property real c: shapeRoot.is2x2 ? 20 : (shapeRoot.is1x2 ? 14 : 12)

        ShapePath {
            strokeColor: shapeRoot.borderWidth > 0 ? shapeRoot.borderColor : "transparent"
            strokeWidth: shapeRoot.borderWidth
            fillColor: shapeRoot.fillColor
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap

            startX: chamferShape.c; startY: 0
            PathLine { x: chamferShape.w - chamferShape.c; y: 0 }
            PathLine { x: chamferShape.w; y: chamferShape.c }
            PathLine { x: chamferShape.w; y: chamferShape.h - chamferShape.c }
            PathLine { x: chamferShape.w - chamferShape.c; y: chamferShape.h }
            PathLine { x: chamferShape.c; y: chamferShape.h }
            PathLine { x: 0; y: chamferShape.h - chamferShape.c }
            PathLine { x: 0; y: chamferShape.c }
            PathLine { x: chamferShape.c; y: 0 }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 3. TICKET / SCALLOPED PASS SHAPE (1x2 Side Notches) ──────────────────
    // ═════════════════════════════════════════════════════════════════════════
    Shape {
        id: ticket1x2Shape
        visible: shapeRoot.resolvedShape === "ticket" && shapeRoot.is1x2
        anchors.fill: parent
        asynchronous: true

        readonly property real w: width
        readonly property real h: height
        readonly property real cr: 14 // corner radius
        readonly property real nr: 7  // notch radius
        readonly property real midY: height / 2

        ShapePath {
            strokeColor: shapeRoot.borderWidth > 0 ? shapeRoot.borderColor : "transparent"
            strokeWidth: shapeRoot.borderWidth
            fillColor: shapeRoot.fillColor
            joinStyle: ShapePath.RoundJoin

            startX: ticket1x2Shape.cr; startY: 0
            PathLine { x: ticket1x2Shape.w - ticket1x2Shape.cr; y: 0 }
            PathArc { x: ticket1x2Shape.w; y: ticket1x2Shape.cr; radiusX: ticket1x2Shape.cr; radiusY: ticket1x2Shape.cr }
            PathLine { x: ticket1x2Shape.w; y: ticket1x2Shape.midY - ticket1x2Shape.nr }
            PathArc { x: ticket1x2Shape.w; y: ticket1x2Shape.midY + ticket1x2Shape.nr; radiusX: ticket1x2Shape.nr; radiusY: ticket1x2Shape.nr; direction: PathArc.Counterclockwise }
            PathLine { x: ticket1x2Shape.w; y: ticket1x2Shape.h - ticket1x2Shape.cr }
            PathArc { x: ticket1x2Shape.w - ticket1x2Shape.cr; y: ticket1x2Shape.h; radiusX: ticket1x2Shape.cr; radiusY: ticket1x2Shape.cr }
            PathLine { x: ticket1x2Shape.cr; y: ticket1x2Shape.h }
            PathArc { x: 0; y: ticket1x2Shape.h - ticket1x2Shape.cr; radiusX: ticket1x2Shape.cr; radiusY: ticket1x2Shape.cr }
            PathLine { x: 0; y: ticket1x2Shape.midY + ticket1x2Shape.nr }
            PathArc { x: 0; y: ticket1x2Shape.midY - ticket1x2Shape.nr; radiusX: ticket1x2Shape.nr; radiusY: ticket1x2Shape.nr; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: ticket1x2Shape.cr }
            PathArc { x: ticket1x2Shape.cr; y: 0; radiusX: ticket1x2Shape.cr; radiusY: ticket1x2Shape.cr }
        }
    }

    // ── 3b. TICKET / SCALLOPED PASS SHAPE (1x1 & 2x2 Corner Scallops) ────────
    Shape {
        id: ticketCornersShape
        visible: shapeRoot.resolvedShape === "ticket" && !shapeRoot.is1x2
        anchors.fill: parent
        asynchronous: true

        readonly property real w: width
        readonly property real h: height
        readonly property real nr: shapeRoot.is2x2 ? 14 : 9

        ShapePath {
            strokeColor: shapeRoot.borderWidth > 0 ? shapeRoot.borderColor : "transparent"
            strokeWidth: shapeRoot.borderWidth
            fillColor: shapeRoot.fillColor
            joinStyle: ShapePath.RoundJoin

            startX: ticketCornersShape.nr; startY: 0
            PathLine { x: ticketCornersShape.w - ticketCornersShape.nr; y: 0 }
            PathArc { x: ticketCornersShape.w; y: ticketCornersShape.nr; radiusX: ticketCornersShape.nr; radiusY: ticketCornersShape.nr; direction: PathArc.Counterclockwise }
            PathLine { x: ticketCornersShape.w; y: ticketCornersShape.h - ticketCornersShape.nr }
            PathArc { x: ticketCornersShape.w - ticketCornersShape.nr; y: ticketCornersShape.h; radiusX: ticketCornersShape.nr; radiusY: ticketCornersShape.nr; direction: PathArc.Counterclockwise }
            PathLine { x: ticketCornersShape.nr; y: ticketCornersShape.h }
            PathArc { x: 0; y: ticketCornersShape.h - ticketCornersShape.nr; radiusX: ticketCornersShape.nr; radiusY: ticketCornersShape.nr; direction: PathArc.Counterclockwise }
            PathLine { x: 0; y: ticketCornersShape.nr }
            PathArc { x: ticketCornersShape.nr; y: 0; radiusX: ticketCornersShape.nr; radiusY: ticketCornersShape.nr; direction: PathArc.Counterclockwise }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 4. DIAMOND EMBLEM (1x1 Specialized Geometric Shape) ──────────────────
    // ═════════════════════════════════════════════════════════════════════════
    Shape {
        id: diamondShape
        visible: shapeRoot.resolvedShape === "diamond"
        anchors.fill: parent
        asynchronous: true

        readonly property real w: width
        readonly property real h: height
        readonly property real tr: 7 // tip radius

        ShapePath {
            strokeColor: shapeRoot.borderWidth > 0 ? shapeRoot.borderColor : "transparent"
            strokeWidth: shapeRoot.borderWidth
            fillColor: shapeRoot.fillColor
            joinStyle: ShapePath.RoundJoin

            startX: diamondShape.w / 2; startY: 2
            PathLine { x: diamondShape.w - diamondShape.tr; y: diamondShape.h / 2 - diamondShape.tr }
            PathArc { x: diamondShape.w - 2; y: diamondShape.h / 2 + 2; radiusX: diamondShape.tr; radiusY: diamondShape.tr }
            PathLine { x: diamondShape.w / 2 + diamondShape.tr; y: diamondShape.h - diamondShape.tr }
            PathArc { x: diamondShape.w / 2 - 2; y: diamondShape.h - 2; radiusX: diamondShape.tr; radiusY: diamondShape.tr }
            PathLine { x: diamondShape.tr; y: diamondShape.h / 2 + diamondShape.tr }
            PathArc { x: 2; y: diamondShape.h / 2 - 2; radiusX: diamondShape.tr; radiusY: diamondShape.tr }
            PathLine { x: diamondShape.w / 2 - diamondShape.tr; y: diamondShape.tr }
            PathArc { x: diamondShape.w / 2; y: 2; radiusX: diamondShape.tr; radiusY: diamondShape.tr }
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── 5. HERALDIC SHIELD / CREST (2x2 Specialized Shape) ───────────────────
    // ═════════════════════════════════════════════════════════════════════════
    Shape {
        id: shieldShape
        visible: shapeRoot.resolvedShape === "shield"
        anchors.fill: parent
        asynchronous: true

        readonly property real w: width
        readonly property real h: height
        readonly property real tr: 18

        ShapePath {
            strokeColor: shapeRoot.borderWidth > 0 ? shapeRoot.borderColor : "transparent"
            strokeWidth: shapeRoot.borderWidth
            fillColor: shapeRoot.fillColor
            joinStyle: ShapePath.RoundJoin

            startX: shieldShape.tr; startY: 0
            PathLine { x: shieldShape.w - shieldShape.tr; y: 0 }
            PathArc { x: shieldShape.w; y: shieldShape.tr; radiusX: shieldShape.tr; radiusY: shieldShape.tr }
            PathLine { x: shieldShape.w; y: shieldShape.h * 0.56 }
            PathQuad { x: shieldShape.w / 2; y: shieldShape.h; controlX: shieldShape.w * 0.88; controlY: shieldShape.h * 0.92 }
            PathQuad { x: 0; y: shieldShape.h * 0.56; controlX: shieldShape.w * 0.12; controlY: shieldShape.h * 0.92 }
            PathLine { x: 0; y: shieldShape.tr }
            PathArc { x: shieldShape.tr; y: 0; radiusX: shieldShape.tr; radiusY: shieldShape.tr }
        }
    }
}

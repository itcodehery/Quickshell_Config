import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell.Widgets

Item {
    id: stageRoot
    required property var root
    required property var switcher

    // ═════════════════════════════════════════════════════
    // STYLE 1: TANZAKU (3D Fan / Sumi-e Filmstrip)
    // ═════════════════════════════════════════════════════
    Item {
        id: tanzakuStage
        visible: switcher.currentPickerStyle === "tanzaku" || switcher.currentPickerStyle === ""
        anchors.fill: parent

        readonly property int focusedW: 390
        readonly property int focusedH: 220
        readonly property int peekW: 68
        readonly property int stripW: 22
        readonly property int gap: 8

        function stripWidthFor(d) {
            if (d <= 0) return focusedW
            if (d === 1) return peekW
            return stripW
        }

        readonly property real cx: width / 2
        readonly property real fLeft: cx - focusedW / 2
        readonly property real fRight: cx + focusedW / 2

        function xForRel(r) {
            if (r === 0) return fLeft
            var x
            if (r < 0) {
                x = fLeft
                for (var k = -1; k >= r; k--) x = x - gap - stripWidthFor(-k)
                return x
            }
            x = fRight + gap
            for (var j = 1; j < r; j++) x = x + stripWidthFor(j) + gap
            return x
        }

        Repeater {
            model: switcher.filtered.length

            delegate: Item {
                id: tCard
                required property int index
                readonly property var entry: switcher.filtered[index] || null
                readonly property int relIdx: index - switcher.selFilt
                readonly property bool focused: relIdx === 0
                readonly property bool near: Math.abs(relIdx) <= 8

                width: tanzakuStage.stripWidthFor(Math.abs(relIdx))
                height: tanzakuStage.focusedH
                anchors.verticalCenter: parent.verticalCenter
                x: tanzakuStage.xForRel(relIdx)
                z: focused ? 100 : 50 - Math.min(Math.abs(relIdx), 30)
                visible: near
                opacity: near ? 1 : 0

                Behavior on x     { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: "#16161c"
                    border.width: focused ? 2.5 : 1
                    border.color: focused ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)

                    // Strict rounded clipping masks images & overlays cleanly
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: focused ? 2.5 : 1
                        radius: 14
                        color: "#16161c"

                        Image {
                            anchors.fill: parent
                            source: (tCard.near && tCard.entry && tCard.entry.thumb) ? tCard.entry.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }

                        // Wash overlay for non-focused cards
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: tCard.focused ? 0 : (Math.abs(tCard.relIdx) === 1 ? 0.35 : 0.60)
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        // Gradient shadow on focused card
                        Rectangle {
                            visible: tCard.focused
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 56
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                            }
                        }

                        // Theme/Wallpaper title on focused card
                        Text {
                            visible: tCard.focused
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            text: tCard.entry ? tCard.entry.label : ""
                            color: "#ECECEE"
                            font.family: root.barFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // Label overlay on peek cards
                        Rectangle {
                            visible: Math.abs(tCard.relIdx) === 1
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 28
                            color: Qt.rgba(0, 0, 0, 0.72)
                            Text {
                                anchors.centerIn: parent
                                text: tCard.entry ? tCard.entry.label : ""
                                color: "#ECECEE"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                width: parent.width - 6
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }

                // Red seal stroke under focused card
                Rectangle {
                    visible: tCard.focused
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52; height: 3; radius: 1.5
                    color: root.seal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tCard.focused) switcher.applySelected()
                        else switcher.selFilt = index
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════
    // STYLE 2: HEARTHSTONE (Curved Arc Hand of Cards)
    // ═════════════════════════════════════════════════════
    Item {
        id: hsStage
        visible: switcher.currentPickerStyle === "hearthstone"
        anchors.fill: parent

        readonly property int cardW: 148
        readonly property int cardH: 210
        readonly property int stepX: 96
        readonly property real spreadDeg: 3.8
        readonly property int focusLift: 28
        readonly property real focusScale: 1.16

        Repeater {
            model: switcher.filtered.length

            delegate: Item {
                id: hCard
                required property int index
                readonly property var entry: switcher.filtered[index] || null
                readonly property int relIdx: index - switcher.selFilt
                readonly property bool focused: relIdx === 0
                readonly property bool nearby: Math.abs(relIdx) <= 7
                readonly property real dim: focused ? 0.0 : Math.min(0.60, 0.28 + Math.abs(relIdx) * 0.06)

                width: hsStage.cardW
                height: hsStage.cardH
                visible: nearby
                transformOrigin: Item.Bottom

                x: (hsStage.width - hsStage.cardW) / 2 + relIdx * hsStage.stepX
                y: (hsStage.height - hsStage.cardH) - (focused ? hsStage.focusLift : 0) - 8
                rotation: relIdx * hsStage.spreadDeg
                scale: focused ? hsStage.focusScale : 1.0
                z: focused ? 1000 : 500 - Math.min(Math.abs(relIdx), 40)

                Behavior on x        { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
                Behavior on y        { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
                Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
                Behavior on scale    { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }

                // Card contents strictly clipped to card outer radius (18px)
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "#141418"

                    Image {
                        id: thumbImage
                        anchors.fill: parent
                        anchors.margins: 6
                        source: (hCard.nearby && hCard.entry && hCard.entry.thumb) ? hCard.entry.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                    }

                    // Gradient shadow at bottom of card
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 64
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.80) }
                        }
                    }

                    // Theme/Wallpaper title on the card
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        text: hCard.entry ? hCard.entry.label : ""
                        color: "#ECECEE"
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    // Dim overlay on non-focused cards
                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                        opacity: hCard.dim
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }
                }

                // Passepartout Shape - CurveRenderer with OddEvenFill outer/inner cutouts
                Shape {
                    id: frameShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real w: hCard.width
                    readonly property real h: hCard.height
                    readonly property real ro: 18    // outer radius
                    readonly property real m: 7      // mat width
                    readonly property real ri: 11    // inner (photo) radius

                    ShapePath {
                        fillRule: ShapePath.OddEvenFill
                        fillColor: "#141418"
                        strokeColor: "transparent"
                        strokeWidth: 0

                        // outer rounded rect
                        startX: frameShape.ro; startY: 0
                        PathLine { x: frameShape.w - frameShape.ro; y: 0 }
                        PathArc  { x: frameShape.w; y: frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        PathLine { x: frameShape.w; y: frameShape.h - frameShape.ro }
                        PathArc  { x: frameShape.w - frameShape.ro; y: frameShape.h; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        PathLine { x: frameShape.ro; y: frameShape.h }
                        PathArc  { x: 0; y: frameShape.h - frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        PathLine { x: 0; y: frameShape.ro }
                        PathArc  { x: frameShape.ro; y: 0; radiusX: frameShape.ro; radiusY: frameShape.ro }

                        // inner rounded hole (photo cut-out)
                        PathMove { x: frameShape.m + frameShape.ri; y: frameShape.m }
                        PathLine { x: frameShape.w - frameShape.m - frameShape.ri; y: frameShape.m }
                        PathArc  { x: frameShape.w - frameShape.m; y: frameShape.m + frameShape.ri; radiusX: frameShape.ri; radiusY: frameShape.ri }
                        PathLine { x: frameShape.w - frameShape.m; y: frameShape.h - frameShape.m - frameShape.ri }
                        PathArc  { x: frameShape.w - frameShape.m - frameShape.ri; y: frameShape.h - frameShape.m; radiusX: frameShape.ri; radiusY: frameShape.ri }
                        PathLine { x: frameShape.m + frameShape.ri; y: frameShape.h - frameShape.m }
                        PathArc  { x: frameShape.m; y: frameShape.h - frameShape.m - frameShape.ri; radiusX: frameShape.ri; radiusY: frameShape.ri }
                        PathLine { x: frameShape.m; y: frameShape.m + frameShape.ri }
                        PathArc  { x: frameShape.m + frameShape.ri; y: frameShape.m; radiusX: frameShape.ri; radiusY: frameShape.ri }
                    }

                    // Focused accent border — glowing white border when focused
                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: hCard.focused ? "#ffffff" : Qt.rgba(1, 1, 1, 0.12)
                        strokeWidth: hCard.focused ? 2.5 : 1
                        Behavior on strokeColor { ColorAnimation { duration: 160 } }

                        startX: frameShape.ro; startY: 0
                        PathLine { x: frameShape.w - frameShape.ro; y: 0 }
                        PathArc  { x: frameShape.w; y: frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        PathLine { x: frameShape.w; y: frameShape.h - frameShape.ro }
                        PathArc  { x: frameShape.w - frameShape.ro; y: frameShape.h; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        PathLine { x: frameShape.ro; y: frameShape.h }
                        PathArc  { x: 0; y: frameShape.h - frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        PathLine { x: 0; y: frameShape.ro }
                        PathArc  { x: frameShape.ro; y: 0; radiusX: frameShape.ro; radiusY: frameShape.ro }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (hCard.focused) switcher.applySelected()
                        else switcher.selFilt = index
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════
    // STYLE 3: CAROUSEL (Coverflow with Dead-Center Hero Card)
    // ═════════════════════════════════════════════════════
    Item {
        id: cfStage
        visible: switcher.currentPickerStyle === "carousel"
        anchors.fill: parent

        readonly property int expandedW: 380
        readonly property int expandedH: 214
        readonly property int sliceW: 84
        readonly property int sliceH: 184
        readonly property real itemStep: 68

        readonly property real centerX: (width - expandedW) / 2

        Repeater {
            model: switcher.filtered.length

            delegate: Item {
                id: cfSlice
                required property int index
                readonly property var entry: switcher.filtered[index] || null
                readonly property int relIdx: index - switcher.selFilt
                readonly property bool selected: relIdx === 0
                readonly property bool nearby: Math.abs(relIdx) <= 7

                visible: nearby
                width: selected ? cfStage.expandedW : cfStage.sliceW
                height: selected ? cfStage.expandedH : cfStage.sliceH

                // Dead-center vertically:
                y: (cfStage.height - height) / 2

                // Dead-center horizontally for selected card, cascading out for side cards:
                x: selected
                    ? cfStage.centerX
                    : (relIdx < 0
                        ? (cfStage.centerX - 20 - cfStage.sliceW - (Math.abs(relIdx) - 1) * cfStage.itemStep)
                        : (cfStage.centerX + cfStage.expandedW + 20 + (relIdx - 1) * cfStage.itemStep))
                z: selected ? 100 : 50 - Math.min(Math.abs(relIdx), 30)

                Behavior on x      { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                Behavior on y      { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                Rectangle {
                    anchors.fill: parent
                    radius: selected ? 16 : 10
                    color: "#16161c"
                    border.width: selected ? 2.5 : 1
                    border.color: selected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)

                    // Strict rounded clipping masks image and overlays cleanly
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: selected ? 2.5 : 1
                        radius: selected ? 14 : 9
                        color: "#16161c"

                        Image {
                            anchors.fill: parent
                            source: (cfSlice.nearby && cfSlice.entry && cfSlice.entry.thumb) ? cfSlice.entry.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }

                        // Dim overlay on side slices
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: cfSlice.selected ? 0 : 0.50
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        // Gradient shadow on selected card
                        Rectangle {
                            visible: cfSlice.selected
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 56
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                            }
                        }

                        // Theme/Wallpaper title on selected card
                        Text {
                            visible: cfSlice.selected
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            text: cfSlice.entry ? cfSlice.entry.label : ""
                            color: "#ECECEE"
                            font.family: root.barFont
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Red seal stroke under selected card
                Rectangle {
                    visible: cfSlice.selected
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 52; height: 3; radius: 1.5
                    color: root.seal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (cfSlice.selected) switcher.applySelected()
                        else switcher.selFilt = index
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════
    // STYLE 4: GRAVEMIND (Spatial 3D Capsule Coverflow)
    // ═════════════════════════════════════════════════════
    Item {
        id: gravemindStage
        visible: switcher.currentPickerStyle === "gravemind"
        anchors.fill: parent

        readonly property int cardW: 200
        readonly property int cardH: 200
        readonly property int cardRadius: 22
        readonly property real itemStep: 46
        readonly property real centerGap: 92
        readonly property real centerX: (width - cardW) / 2
        readonly property real centerY: (height - cardH) / 2

        // Capsule black dock backdrop (matches reference image)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 24
            color: "#08080b"
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
        }

        Repeater {
            model: switcher.filtered.length

            delegate: Item {
                id: gmCard
                required property int index
                readonly property var entry: switcher.filtered[index] || null
                readonly property int relIdx: index - switcher.selFilt
                readonly property bool focused: relIdx === 0
                readonly property bool nearby: Math.abs(relIdx) <= 7

                visible: nearby
                width: gravemindStage.cardW
                height: gravemindStage.cardH

                // Vertical centering
                y: gravemindStage.centerY

                // Horizontal 3D placement:
                x: focused
                    ? gravemindStage.centerX
                    : (relIdx < 0
                        ? (gravemindStage.centerX - gravemindStage.centerGap - (Math.abs(relIdx) - 1) * gravemindStage.itemStep)
                        : (gravemindStage.centerX + gravemindStage.centerGap + (relIdx - 1) * gravemindStage.itemStep))

                // Center card on top, outer cards stacked behind
                z: focused ? 100 : 50 - Math.min(Math.abs(relIdx), 30)

                // 3D Perspective Rotation around Y axis
                // Left cards angle inward facing right (-44 deg)
                // Right cards angle inward facing left (44 deg)
                property real targetRotY: focused ? 0 : (relIdx < 0 ? -44 : 44)
                property real targetScale: focused ? 1.0 : Math.max(0.82, 0.96 - Math.abs(relIdx) * 0.035)

                Behavior on x           { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                Behavior on targetRotY  { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                Behavior on targetScale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                transform: [
                    Rotation {
                        origin.x: gmCard.width / 2
                        origin.y: gmCard.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: gmCard.targetRotY
                    },
                    Scale {
                        origin.x: gmCard.width / 2
                        origin.y: gmCard.height / 2
                        xScale: gmCard.targetScale
                        yScale: gmCard.targetScale
                    }
                ]

                // Smooth card frame with rounded corners
                Rectangle {
                    anchors.fill: parent
                    radius: gravemindStage.cardRadius
                    color: "#121216"
                    border.width: gmCard.focused ? 2 : 1
                    border.color: gmCard.focused ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.12)
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: gmCard.focused ? 2 : 1
                        radius: gravemindStage.cardRadius - 1
                        color: "#121216"

                        Image {
                            anchors.fill: parent
                            source: (gmCard.nearby && gmCard.entry && gmCard.entry.thumb) ? gmCard.entry.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }

                        // Progressive depth shading on receding side cards
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: gmCard.focused ? 0.0 : Math.min(0.82, 0.28 + Math.abs(gmCard.relIdx) * 0.16)
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        // Bottom gradient shadow for typography on center card
                        Rectangle {
                            visible: gmCard.focused
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 74
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
                            }
                        }

                        // Typography: Title and Subtitle matching the reference image layout
                        Column {
                            visible: gmCard.focused
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            spacing: 2

                            Text {
                                width: parent.width
                                text: gmCard.entry ? gmCard.entry.label : ""
                                color: "#FFFFFF"
                                font.family: root.barFont
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: {
                                    if (!gmCard.entry) return ""
                                    if (switcher.isThemeMode) {
                                        let meta = (gmCard.entry.dir && switcher.metaCache[gmCard.entry.dir]) ? switcher.metaCache[gmCard.entry.dir] : null
                                        return meta && meta.author ? ("@" + meta.author) : "Theme"
                                    }
                                    return "Wallpaper"
                                }
                                color: Qt.rgba(1, 1, 1, 0.75)
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Theme accent line indicator under focused card
                Rectangle {
                    visible: gmCard.focused
                    anchors.top: parent.bottom
                    anchors.topMargin: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48
                    height: 3
                    radius: 1.5
                    color: root.seal
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (gmCard.focused) switcher.applySelected()
                        else switcher.selFilt = index
                    }
                }
            }
        }
    }
}

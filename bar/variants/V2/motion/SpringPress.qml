import QtQuick

// Drop-in M3E physics for any tile / button / tab.
// Place as a child of the item you want to animate (it attaches to its parent):
//   Rectangle { ...; SpringPress {} ; MouseArea { ... } }
//
//  - the item squishes when pressed (click only, never hover), on a bouncy spring
//  - every other SpringPress nearby is pushed away from the touched item (from all
//    directions) and springs back with overshoot on release
// It only observes pointer events (passive handlers), so existing MouseAreas keep working.
Item {
    id: sp

    property Item target: parent
    property real pressScale: 0.88
    property real pushReach: 170       // px - how far a touch is felt
    property real pushDistance: 14     // px - max shove on a press
    property bool interactive: true

    visible: false
    width: 0
    height: 0

    // Large containers (list areas, whole panels) are not "tiles"
    readonly property bool eligible: interactive && target && target.width > 0
        && target.width <= 460 && target.height <= 130

    readonly property bool pressed: eligible && pointHandler.active
    readonly property real area: target ? target.width * target.height : 0

    property real sc: 1
    property real tx: 0
    property real ty: 0

    Behavior on sc { SpringAnimation { spring: Motion.pressSpring; damping: Motion.pressDamping; epsilon: 0.0005 } }
    Behavior on tx { SpringAnimation { spring: Motion.pushSpring; damping: Motion.pushDamping; epsilon: 0.01 } }
    Behavior on ty { SpringAnimation { spring: Motion.pushSpring; damping: Motion.pushDamping; epsilon: 0.01 } }

    PointHandler {
        id: pointHandler
        parent: sp.target
        acceptedButtons: Qt.LeftButton
    }

    Scale {
        id: scaleT
        origin.x: sp.target ? sp.target.width / 2 : 0
        origin.y: sp.target ? sp.target.height / 2 : 0
        xScale: sp.sc
        yScale: sp.sc
    }
    Translate {
        id: moveT
        x: sp.tx
        y: sp.ty
    }

    Component.onCompleted: {
        if (target && target.transform.length === 0)
            target.transform = [scaleT, moveT]
    }

    function claim() {
        if (Motion.source && Motion.source !== sp && Motion.source.area < sp.area)
            return                                   // nested: the smaller (inner) button wins
        Motion.source = sp
        Motion.strength = 1
    }
    function release() {
        if (Motion.source !== sp) return
        Motion.source = null
        Motion.strength = 0
    }

    onPressedChanged: pressed ? claim() : release()

    // Own squish (click only - never on hover)
    sc: pressed ? pressScale : 1

    // Reaction to the touched neighbour
    function react() {
        var s = Motion.source
        if (!s || s === sp || !target || !s.target
                || target.Window.window !== s.target.Window.window) {
            tx = 0; ty = 0
            return
        }
        var a = target.mapToItem(null, target.width / 2, target.height / 2)
        var b = s.target.mapToItem(null, s.target.width / 2, s.target.height / 2)
        var dx = a.x - b.x
        var dy = a.y - b.y
        var d = Math.sqrt(dx * dx + dy * dy)
        if (d < 1 || d > pushReach) {
            tx = 0; ty = 0
            return
        }
        var f = 1 - d / pushReach
        f = f * f
        var m = pushDistance * Motion.strength * f
        tx = dx / d * m
        ty = dy / d * m
    }

    Connections {
        target: Motion
        function onSourceChanged() { sp.react() }
        function onStrengthChanged() { sp.react() }
    }
}

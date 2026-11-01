import QtQuick
import ".."

// Reusable scroll-position thumb for the update lists: appears ONLY when the
// list overflows, height is proportional to the visible fraction, tracks
// contentY, AND is draggable with the mouse (drag translates to contentY —
// we never bind-fight the y). One definition used by both tabs so they can
// never drift apart (the F2 "fixed one variant, missed the sibling" lesson).
Item {
    id: scrollTrack
    required property var flick
    required property var archPanel

    anchors.right: parent.right
    anchors.rightMargin: -6   // sit in the right gutter, clear of the full-width row separators
    width: 14
    height: flick.height
    visible: flick.contentHeight > flick.height + 1
    readonly property real thumbHeight: flick.contentHeight > 0
        ? Math.max(24, flick.height * flick.height / flick.contentHeight)
        : 0
    readonly property real thumbY: (flick.contentHeight > flick.height)
        ? (flick.height - thumbHeight) * (flick.contentY / (flick.contentHeight - flick.height))
        : 0

    Rectangle {
        id: thumb
        anchors.horizontalCenter: parent.horizontalCenter
        y: scrollTrack.thumbY
        width: (dragMa.containsMouse || dragMa.pressed) ? 6 : 3
        height: scrollTrack.thumbHeight
        radius: width / 2
        color: Qt.rgba(scrollTrack.archPanel.root.ink.r, scrollTrack.archPanel.root.ink.g, scrollTrack.archPanel.root.ink.b,
                       (dragMa.containsMouse || dragMa.pressed) ? 0.5 : 0.28)
        Behavior on width { NumberAnimation { duration: 100 } }
    }

    // A wider stationary grab target. The visible thumb moves, but this track
    // stays fixed, so drag math is stable while contentY changes.
    MouseArea {
        id: dragMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        property real startY: 0
        property real startContent: 0
        onPressed: (m) => {
            startY = m.y
            startContent = scrollTrack.flick.contentY
        }
        onPositionChanged: (m) => {
            if (!pressed) return
            var track = scrollTrack.flick.height - scrollTrack.thumbHeight
            if (track <= 0) return
            var scrollable = scrollTrack.flick.contentHeight - scrollTrack.flick.height
            var nc = startContent + (m.y - startY) * scrollable / track
            scrollTrack.flick.contentY = Math.max(0, Math.min(scrollable, nc))
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: lyricsPanel
    required property var root
    required property var mprisPanel

    screen: root.activePopupScreen
    color: "transparent"
    
    // Instead of full screen, just take enough space for the floating pill at the top
    anchors { top: true; left: true; right: true }
    height: 100
    
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-lyrics"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only allow clicks exactly on the pill, let the rest of the 100px-high bar pass through!
    mask: Region { item: lyricsCard }

    visible: mprisPanel.showingLyrics && mprisPanel.active

    Rectangle {
        id: lyricsCard
        width: Math.min(parent.width - 24, lyricsContentRow.implicitWidth + 60)
        height: 48
        x: (parent.width - width) / 2
        y: root.barPosition === "bottom" ? (parent.height - root.v2BarHeight - 6 - height) : (root.v2BarHeight + 6)

        radius: 24
        color: root.paper
        border.color: root.panelBorder
        border.width: 1
        opacity: (mprisPanel.showingLyrics && mprisPanel.active) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        PillShadow { theme: root }
        
        MouseArea {
            anchors.fill: parent
            drag.target: lyricsCard
            drag.axis: Drag.XAndYAxis
            cursorShape: Qt.OpenHandCursor
            onPressed: { cursorShape = Qt.ClosedHandCursor }
            onReleased: { cursorShape = Qt.OpenHandCursor }
        }

        Row {
            id: lyricsContentRow
            anchors.centerIn: parent
            spacing: 16

            IconText {
                text: "" // music icon
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
                color: root.sumiHi
            }

            UiText {
                id: lyricsText
                text: mprisPanel.currentLyricIndex >= 0 && mprisPanel.currentLyricIndex < mprisPanel.lyricsList.length ? mprisPanel.lyricsList[mprisPanel.currentLyricIndex].text : (mprisPanel.lyricsList.length > 0 ? "..." : "No lyrics found")
                color: root.ink
                font.family: root.mono
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                // constrain width if it's too long
                width: Math.min(implicitWidth, lyricsPanel.width - 120)
            }
            
            UiText {
                text: "✕"
                color: closeLyricsMa.containsMouse ? root.seal : root.sumi
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea { id: closeLyricsMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mprisPanel.showingLyrics = false }
            }
        }
    }
}

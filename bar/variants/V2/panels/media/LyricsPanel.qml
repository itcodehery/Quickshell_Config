import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland
import "../../modules"

// Top-left docked floating synced-lyrics pill matching PrivacyDots's top-right battery pill.
PanelWindow {
    id: lyricsPanel
    required property var root
    required property var mprisPanel

    screen: root ? root.activePopupScreen : null

    readonly property bool hasLyrics: mprisPanel
        && mprisPanel.lyricsTrackId !== ""
        && mprisPanel.lyricsTrackId === mprisPanel.currentTrackId
        && mprisPanel.lyricsList
        && mprisPanel.lyricsList.length > 0

    readonly property bool shouldShow: Boolean(
        mprisPanel && mprisPanel.active && mprisPanel.showingLyrics
        && !(root && (root.barHidden || root.dashboardExpanded))
    )

    visible: shouldShow || (pill && pill.opacity > 0.01)

    color: "transparent"
    anchors {
        top: root ? root.barPosition === "top" : true
        bottom: root ? root.barPosition === "bottom" : false
        left: true
    }
    margins {
        top: 4
        bottom: 4
        left: 14
    }

    readonly property real pillHeight: (root && root.pillH) ? root.pillH : 24
    readonly property real maxPillWidth: 380
    implicitWidth: maxPillWidth
    implicitHeight: root ? root.v2BarHeight : 32

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-lyrics-float"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: pill }

    readonly property string activeLine: {
        if (hasLyrics) {
            var idx = Math.max(0, mprisPanel.currentLyricIndex)
            if (idx < mprisPanel.lyricsList.length) {
                return mprisPanel.lyricsList[idx].text || "♪"
            }
        }
        if (mprisPanel && mprisPanel._isFetchingLyrics) return "Searching lyrics…"
        return "♪"
    }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        height: lyricsPanel.pillHeight
        radius: height / 2
        color: root ? root.barBg : "#111318"
        width: Math.min(lyricsPanel.maxPillWidth, Math.max(28, contentRow.implicitWidth + 20))

        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        opacity: lyricsPanel.shouldShow ? 1.0 : 0.0
        scale: lyricsPanel.shouldShow ? 1.0 : 0.92

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 6

            IconText {
                anchors.verticalCenter: parent.verticalCenter
                text: "music_note"
                font.pixelSize: 13
                color: root ? root.seal : "#ffffff"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: lyricsPanel.activeLine
                color: root ? root.ink : "#ffffff"
                font.family: root ? root.barFont : "Genova"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, lyricsPanel.maxPillWidth - 44)
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (lyricsPanel.mprisPanel) lyricsPanel.mprisPanel.showingLyrics = !lyricsPanel.mprisPanel.showingLyrics
            }
        }
    }
}

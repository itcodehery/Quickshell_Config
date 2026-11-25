import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../modules"

// Top-left docked workspace pill + separate floating synced-lyrics pill matching the bar theme.
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

    readonly property bool barVisible: !(root && (root.barHidden || root.dashboardExpanded))

    readonly property bool shouldShowLyrics: Boolean(
        mprisPanel && mprisPanel.active && mprisPanel.showingLyrics && barVisible
    )

    readonly property var wsGlyphs: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    readonly property string activeWsLabel: {
        var id = (Hyprland && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0)
            ? Hyprland.focusedWorkspace.id
            : 1
        return (id >= 1 && id <= wsGlyphs.length) ? wsGlyphs[id - 1] : String(id)
    }

    visible: barVisible || (wsPill && wsPill.opacity > 0.01) || (pill && pill.opacity > 0.01)

    color: "transparent"
    anchors {
        top: root ? root.barPosition === "top" : true
        bottom: root ? root.barPosition === "bottom" : false
        left: true
    }
    margins {
        top: (root && root.isBarNotch) ? 0 : 4
        bottom: (root && root.isBarNotch) ? 0 : 4
        left: 14
    }

    readonly property real pillHeight: (root && root.pillH) ? root.pillH : 24
    readonly property real maxLyricsWidth: 380
    implicitWidth: maxLyricsWidth + 60
    implicitHeight: root ? root.v2BarHeight : 32

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "omarchy-lyrics-float"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region { item: topLeftRow }

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

    Row {
        id: topLeftRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: 8
        height: lyricsPanel.pillHeight

        // 1. Distinct Workspace Number Pill
        Rectangle {
            id: wsPill
            anchors.verticalCenter: parent.verticalCenter
            height: lyricsPanel.pillHeight
            width: Math.max(lyricsPanel.pillHeight, wsTxt.implicitWidth + 16)
            radius: height / 2
            border.width: 0
            antialiasing: true
            color: (root && root.isBarVignette) ? "transparent" : (root ? root.barBg : "#111318")

            opacity: lyricsPanel.barVisible ? 1.0 : 0.0
            scale: lyricsPanel.barVisible ? 1.0 : 0.92
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            Text {
                id: wsTxt
                anchors.centerIn: parent
                text: lyricsPanel.activeWsLabel
                color: root ? root.seal : "#ffffff"
                font.family: root ? root.barFont : "Google Sans"
                font.pixelSize: 11
                font.weight: Font.Bold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (lyricsPanel.root) {
                        lyricsPanel.root.workspaceVisible = !lyricsPanel.root.workspaceVisible
                    }
                }
            }
        }

        // 2. Distinct Floating Synced-Lyrics Pill
        Rectangle {
            id: pill
            anchors.verticalCenter: parent.verticalCenter
            height: lyricsPanel.pillHeight
            radius: height / 2
            border.width: 0
            antialiasing: true
            color: (root && root.isBarVignette) ? "transparent" : (root ? root.barBg : "#111318")
            width: Math.min(lyricsPanel.maxLyricsWidth, Math.max(28, contentRow.implicitWidth + 20))

            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            visible: opacity > 0.01
            opacity: lyricsPanel.shouldShowLyrics ? 1.0 : 0.0
            scale: lyricsPanel.shouldShowLyrics ? 1.0 : 0.92

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
                    font.family: root ? root.barFont : "Google Sans"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, lyricsPanel.maxLyricsWidth - 44)
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
}

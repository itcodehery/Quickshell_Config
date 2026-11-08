import QtQuick
import ".."
import Quickshell
import Quickshell.Services.Mpris
import "../../modules"

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT CARD: Media Player with Everything Vertically Arranged
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: rightMediaCard
    required property var hoverPanel
    readonly property var mprisSel: hoverPanel.mprisSel
    readonly property var mediaCardArt: hoverPanel.mediaCardArt

    x: hoverPanel.width - width - 10
    y: 8
    width: 176
    height: 164
    radius: 20
    Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    readonly property var player: mprisSel.player || ((hoverPanel.mprisPanel && hoverPanel.mprisPanel.player) ? hoverPanel.mprisPanel.player : null)
    readonly property bool hasMedia: (mprisSel.active || (hoverPanel.mprisPanel && hoverPanel.mprisPanel.active)) && player !== null
    readonly property string trackTitle: hasMedia ? (player.trackTitle || "No Track") : ""
    readonly property string trackArtist: hasMedia ? (player.trackArtist || "Unknown Artist") : ""
    readonly property bool isPlaying: hasMedia && ((mprisSel.playing) || (hoverPanel.mprisPanel && hoverPanel.mprisPanel.playing) || (player && player.playbackState === MprisPlaybackState.Playing))
    readonly property bool canPrev: hasMedia && player.canGoPrevious
    readonly property bool canNext: hasMedia && player.canGoNext

    readonly property color artColor: {
        if (mediaCardArt.dominantColor && String(mediaCardArt.dominantColor) !== "#00000000" && String(mediaCardArt.dominantColor) !== "transparent") {
            return mediaCardArt.dominantColor
        }
        return hoverPanel.accent
    }

    color: hasMedia
        ? Qt.rgba(artColor.r, artColor.g, artColor.b, rightHov.hovered ? 0.22 : 0.14)
        : (rightHov.hovered ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09) : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06))
    border.width: 0
    Behavior on color { ColorAnimation { duration: 160 } }

    // Vertically Arranged Media Layout (Always displayed as Media Player)
    Column {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 5

        // Large Squircle Album Art
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64
            height: 64
            radius: 16
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12)
            border.width: 0
            clip: true

            Image {
                anchors.fill: parent
                source: mediaCardArt.source
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready && source != ""
            }

            IconText {
                anchors.centerIn: parent
                visible: mediaCardArt.source == ""
                text: "music_note"
                font.pixelSize: 28
                color: rightMediaCard.artColor
            }
        }

        // Track Title
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: rightMediaCard.hasMedia ? hoverPanel.barSlot.formatTitleCase(rightMediaCard.trackTitle) : "Media Player"
            font.family: hoverPanel.root.barFont
            font.pixelSize: 12
            font.weight: Font.Bold
            color: hoverPanel.root.ink
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            width: parent.width - 8
        }

        // Artist
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: rightMediaCard.hasMedia ? hoverPanel.barSlot.formatTitleCase(rightMediaCard.trackArtist) : "Not Playing"
            font.family: hoverPanel.root.barFont
            font.pixelSize: 11
            font.weight: Font.Medium
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.65)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            width: parent.width - 8
        }

        // Playback Controls Row
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            topPadding: 3

            IconText {
                id: prevIcon
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_previous"
                font.pixelSize: 16
                color: "#ffffff"
                opacity: rightMediaCard.canPrev ? (prevMa.containsMouse ? 1.0 : 0.72) : 0.25
                Behavior on opacity { NumberAnimation { duration: 120 } }
                MouseArea {
                    id: prevMa
                    hoverEnabled: true
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rightMediaCard.player) rightMediaCard.player.previous()
                        else Quickshell.execDetached(["playerctl", "previous"])
                    }
                }
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(rightMediaCard.artColor.r, rightMediaCard.artColor.g, rightMediaCard.artColor.b, 0.90)

                IconText {
                    anchors.centerIn: parent
                    text: rightMediaCard.isPlaying ? "pause" : "play_arrow"
                    font.pixelSize: 14
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rightMediaCard.player) rightMediaCard.player.togglePlaying()
                        else Quickshell.execDetached(["playerctl", "play-pause"])
                    }
                }
            }

            IconText {
                id: nextIcon
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_next"
                font.pixelSize: 16
                color: "#ffffff"
                opacity: rightMediaCard.canNext ? (nextMa.containsMouse ? 1.0 : 0.72) : 0.25
                Behavior on opacity { NumberAnimation { duration: 120 } }
                MouseArea {
                    id: nextMa
                    hoverEnabled: true
                    anchors.fill: parent; anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rightMediaCard.player) rightMediaCard.player.next()
                        else Quickshell.execDetached(["playerctl", "next"])
                    }
                }
            }
        }
    }

    HoverHandler { id: rightHov }
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: hoverPanel.root.mprisVisible = !hoverPanel.root.mprisVisible
    }
}

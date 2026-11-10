import QtQuick
import ".."
import Quickshell
import Quickshell.Services.Mpris
import "../../modules"

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT CARD: Compact Horizontal Media Player
// ─────────────────────────────────────────────────────────────────────────────
Rectangle {
    id: rightMediaCard
    required property var hoverPanel
    readonly property var mprisSel: hoverPanel.mprisSel
    readonly property var mediaCardArt: hoverPanel.mediaCardArt

    x: hoverPanel.width - width - 8
    y: Math.round((hoverPanel.height - height) / 2)
    width: 196
    height: hoverPanel.height - 8
    radius: 14
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
    border.width: 1
    border.color: hoverPanel.root.cardBorderColor
    Behavior on color { ColorAnimation { duration: 160 } }

    Row {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 6

        // Squircle Album Art
        Rectangle {
            width: parent.height
            height: parent.height
            radius: 10
            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12)
            clip: true
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                source: mediaCardArt.source
                sourceSize: Qt.size(68, 68)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready && source != ""
            }

            IconText {
                anchors.centerIn: parent
                visible: mediaCardArt.source == ""
                text: "music_note"
                font.pixelSize: 15
                color: rightMediaCard.artColor
            }
        }

        // Track Title & Artist
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - parent.height - controlsRow.width - 12
            spacing: 1
            clip: true

            Text {
                width: parent.width
                text: rightMediaCard.hasMedia ? hoverPanel.barSlot.formatTitleCase(rightMediaCard.trackTitle) : "Media"
                font.family: hoverPanel.root.barFont
                font.pixelSize: 10
                font.weight: Font.Bold
                color: hoverPanel.root.ink
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: rightMediaCard.hasMedia ? hoverPanel.barSlot.formatTitleCase(rightMediaCard.trackArtist) : "Not playing"
                font.family: hoverPanel.root.barFont
                font.pixelSize: 9
                font.weight: Font.Medium
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.65)
                elide: Text.ElideRight
            }
        }

        // Playback Controls Row
        Row {
            id: controlsRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            IconText {
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_previous"
                font.pixelSize: 14
                color: hoverPanel.root.ink
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
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(rightMediaCard.artColor.r, rightMediaCard.artColor.g, rightMediaCard.artColor.b, 0.90)

                IconText {
                    anchors.centerIn: parent
                    text: rightMediaCard.isPlaying ? "pause" : "play_arrow"
                    font.pixelSize: 12
                    color: {
                        var c = rightMediaCard.artColor
                        var l = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
                        return l > 0.55 ? "#121212" : "#ffffff"
                    }
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
                anchors.verticalCenter: parent.verticalCenter
                text: "skip_next"
                font.pixelSize: 14
                color: hoverPanel.root.ink
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

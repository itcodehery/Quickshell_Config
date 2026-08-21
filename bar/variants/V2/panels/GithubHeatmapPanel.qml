import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: ghPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-github-heatmap"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property real reveal: root.githubHeatmapVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.githubHeatmapVisible ? 160 : 120
            easing.type: root.githubHeatmapVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.githubHeatmapVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.githubHeatmapVisible = false }

    function toHex(c) {
        return "#" +
            Math.round(c.r * 255).toString(16).padStart(2, '0') +
            Math.round(c.g * 255).toString(16).padStart(2, '0') +
            Math.round(c.b * 255).toString(16).padStart(2, '0')
    }
    function blend(fg, bg, alpha) {
        return Qt.rgba(
            fg.r * alpha + bg.r * (1 - alpha),
            fg.g * alpha + bg.g * (1 - alpha),
            fg.b * alpha + bg.b * (1 - alpha),
            1.0
        )
    }

    property color accent: root.paletteColor(root.barColor)
    property string hexEmpty: toHex(blend(root.ink, root.paper, 0.1))
    property string hexLvl1:  toHex(blend(accent, root.paper, 0.35))
    property string hexLvl2:  toHex(blend(accent, root.paper, 0.55))
    property string hexLvl3:  toHex(blend(accent, root.paper, 0.75))
    property string hexLvl4:  toHex(accent)
    property string hexText:  toHex(root.sumiHi)

    property string svgSource: ""
    property bool refreshing: false

    Process {
        id: fetchHeatmap
        command: ["bash", "-c", 
            "cache_file=\"$HOME/.cache/quickshell_ghchart_raw.svg\"; " +
            "colored_file=\"$HOME/.cache/quickshell_ghchart_colored.svg\"; " +
            "fetch=false; " +
            "if [ ! -f \"$cache_file\" ]; then fetch=true; else " +
            "  cache_age=$(($(date +%s) - $(stat -c %Y \"$cache_file\"))); " +
            "  if [ $cache_age -ge 21600 ]; then fetch=true; fi; " +
            "fi; " +
            "if [ \"$fetch\" = true ]; then " +
            "  curl -s \"https://ghchart.rshah.org/itcodehery\" > \"$cache_file.tmp\"; " +
            "  if grep -q '<svg' \"$cache_file.tmp\"; then mv \"$cache_file.tmp\" \"$cache_file\"; else rm -f \"$cache_file.tmp\"; fi; " +
            "fi; " +
            "if [ -f \"$cache_file\" ]; then " +
            "  cp \"$cache_file\" \"$colored_file\"; " +
            "  sed -i 's/#eeeeee/" + ghPanel.hexEmpty + "/g' \"$colored_file\"; " +
            "  sed -i 's/#c6e48b/" + ghPanel.hexLvl1 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#7bc96f/" + ghPanel.hexLvl2 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#239a3b/" + ghPanel.hexLvl3 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#196127/" + ghPanel.hexLvl4 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#767676/" + ghPanel.hexText + "/g' \"$colored_file\"; " +
            "fi"
        ]
        onExited: {
            ghPanel.svgSource = "file://" + Quickshell.env("HOME") + "/.cache/quickshell_ghchart_colored.svg?t=" + new Date().getTime()
            ghPanel.refreshing = false
        }
    }

    onVisibleChanged: {
        if (visible) {
            refreshing = true
            fetchHeatmap.running = true
        }
    }

    Rectangle {
        id: card
        width: 740
        height: 147
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: root.bg
        border.color: root.panelBorder
        border.width: root.panelBorderW
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: ghPanel.root
            ownerActive: ghPanel.root.githubHeatmapVisible
            targetX: ghPanel.root.githubHeatmapBarX || ghPanel.root.weatherBarX || parent.width / 2
            reveal: ghPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min((ghPanel.root.githubHeatmapBarX || parent.width / 2) - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - ghPanel.reveal)
            : (barBottom + gap) - 2 * (1 - ghPanel.reveal)
        opacity: ghPanel.reveal
        focus: root.githubHeatmapVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.githubHeatmapVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            
            Item {
                width: parent.width
                height: 14
                
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GITHUB CONTRIBUTIONS (" + "itcodehery" + ")"
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 10
                    font.letterSpacing: 1
                }
                
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    
                    UiText {
                        text: "Refreshing..."
                        color: root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 10
                        visible: ghPanel.refreshing
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: String.fromCodePoint(0xF021)
                        color: refreshMa.containsMouse ? root.seal : root.sumiHi
                        font.family: root.mono
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                            running: ghPanel.refreshing
                        }
                        
                        MouseArea {
                            id: refreshMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !ghPanel.refreshing
                            onClicked: {
                                ghPanel.refreshing = true
                                Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.cache/quickshell_ghchart_raw.svg"])
                                fetchHeatmap.running = true
                            }
                        }
                    }
                }
            }

            Item {
                width: 716
                height: 110
                
                UiText {
                    anchors.centerIn: parent
                    text: "Fetching heatmap..."
                    color: root.sumiHi
                    font.family: root.mono
                    font.pixelSize: 12
                    visible: ghPanel.refreshing && !img.status
                }
                
                Image {
                    id: img
                    anchors.fill: parent
                    source: ghPanel.svgSource
                    fillMode: Image.Pad
                    cache: false
                    visible: ghPanel.svgSource !== ""
                }
            }
        }
    }
}

import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import "../../modules"
import "../../motion"

Item {
    id: githubSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#22d3ee"
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "Google Sans"
    readonly property string ghUser: "itcodehery"

    readonly property color onSealCol: {
        var l = 0.299 * sealCol.r + 0.587 * sealCol.g + 0.114 * sealCol.b
        return l > 0.55 ? "#121212" : "#ffffff"
    }

    // Theme-matched heatmap palette (5 levels)
    readonly property string hexEmpty: root && root.isLightMode ? "#e2e8f0" : "#1e232b"
    readonly property string hexLvl1: Qt.rgba(sealCol.r, sealCol.g, sealCol.b, 0.30).toString()
    readonly property string hexLvl2: Qt.rgba(sealCol.r, sealCol.g, sealCol.b, 0.52).toString()
    readonly property string hexLvl3: Qt.rgba(sealCol.r, sealCol.g, sealCol.b, 0.76).toString()
    readonly property string hexLvl4: sealCol.toString()
    readonly property string hexText: inkCol.toString()

    property string svgSource: "file://" + Quickshell.env("HOME") + "/.cache/quickshell_ghchart_colored.svg"
    property bool refreshing: false
    property string statusText: "Cached · 6h TTL"

    function colorHex(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        var g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        var b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    function refreshHeatmap(forceFetch) {
        if (fetchHeatmapProc.running) return
        refreshing = true
        statusText = forceFetch ? "Fetching from GitHub..." : "Updating chart..."
        if (forceFetch) {
            Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.cache/quickshell_ghchart_raw.svg"])
        }
        fetchHeatmapProc.running = true
    }

    Component.onCompleted: refreshHeatmap(false)

    Process {
        id: fetchHeatmapProc
        command: ["bash", "-c",
            "cache_file=\"$HOME/.cache/quickshell_ghchart_raw.svg\"; " +
            "colored_file=\"$HOME/.cache/quickshell_ghchart_colored.svg\"; " +
            "crop_script=\"$HOME/.config/quickshell/bin/qs-ghchart-crop.py\"; " +
            "fetch=false; " +
            "if [ ! -f \"$cache_file\" ]; then fetch=true; else " +
            "  cache_age=$(($(date +%s) - $(stat -c %Y \"$cache_file\"))); " +
            "  if [ $cache_age -ge 21600 ]; then fetch=true; fi; " +
            "fi; " +
            "if [ \"$fetch\" = true ]; then " +
            "  curl -fsSL \"https://ghchart.rshah.org/" + githubSection.ghUser + "\" > \"$cache_file.tmp\" 2>/dev/null; " +
            "  if grep -q '<svg' \"$cache_file.tmp\" 2>/dev/null; then mv \"$cache_file.tmp\" \"$cache_file\"; else rm -f \"$cache_file.tmp\"; fi; " +
            "fi; " +
            "if [ -f \"$cache_file\" ]; then " +
            "  if [ -x \"$crop_script\" ]; then " +
            "    \"$crop_script\" \"$cache_file\" \"$colored_file\" " +
            "      \"" + githubSection.colorHex(githubSection.root.isLightMode ? Qt.rgba(0.88, 0.90, 0.94, 1) : Qt.rgba(0.14, 0.16, 0.20, 1)) + "\" " +
            "      \"" + githubSection.colorHex(Qt.tint(githubSection.paperCol, Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.28))) + "\" " +
            "      \"" + githubSection.colorHex(Qt.tint(githubSection.paperCol, Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.50))) + "\" " +
            "      \"" + githubSection.colorHex(Qt.tint(githubSection.paperCol, Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.74))) + "\" " +
            "      \"" + githubSection.colorHex(githubSection.sealCol) + "\" " +
            "      \"" + githubSection.colorHex(githubSection.inkCol) + "\" 27; " +
            "  else " +
            "    cp \"$cache_file\" \"$colored_file\"; " +
            "  fi; " +
            "fi"
        ]
        onExited: function(exitCode) {
            githubSection.svgSource = "file://" + Quickshell.env("HOME") + "/.cache/quickshell_ghchart_colored.svg?t=" + Date.now()
            githubSection.refreshing = false
            githubSection.statusText = exitCode === 0 ? "Synced with @" + githubSection.ghUser : "Offline · Using cache"
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // ── Header Row ──
        Item {
            width: parent.width
            height: 44

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Rectangle {
                    width: 40
                    height: 40
                    radius: 14
                    border.width: 0
                    color: Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.16)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF09B)
                        font.family: githubSection.barFontFam
                        font.pixelSize: 20
                        color: githubSection.sealCol
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "GitHub Contributions"
                        font.family: githubSection.barFontFam
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: githubSection.inkCol
                    }

                    Text {
                        text: "@" + githubSection.ghUser + "  ·  " + githubSection.statusText
                        font.family: githubSection.barFontFam
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.58)
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Open GitHub Profile button
                Rectangle {
                    height: 34
                    width: openRow.implicitWidth + 24
                    radius: 17
                    border.width: 0
                    color: openMa.containsMouse
                        ? Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.14)
                        : Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SpringPress {}

                    Row {
                        id: openRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "open_in_new"
                            font.pixelSize: 15
                            color: githubSection.inkCol
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Profile"
                            font.family: githubSection.barFontFam
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: githubSection.inkCol
                        }
                    }

                    MouseArea {
                        id: openMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/" + githubSection.ghUser])
                    }
                }

                // Force Refresh button
                Rectangle {
                    height: 34
                    width: refreshRow.implicitWidth + 24
                    radius: 17
                    border.width: 0
                    color: refreshMa.containsMouse
                        ? Qt.lighter(githubSection.sealCol, 1.1)
                        : githubSection.sealCol
                    opacity: githubSection.refreshing ? 0.65 : 1.0
                    Behavior on color { ColorAnimation { duration: 150 } }
                    SpringPress {}

                    Row {
                        id: refreshRow
                        anchors.centerIn: parent
                        spacing: 6
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "refresh"
                            font.pixelSize: 15
                            color: githubSection.onSealCol
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 800
                                running: githubSection.refreshing
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: githubSection.refreshing ? "Syncing" : "Refresh"
                            font.family: githubSection.barFontFam
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: githubSection.onSealCol
                        }
                    }

                    MouseArea {
                        id: refreshMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !githubSection.refreshing
                        onClicked: githubSection.refreshHeatmap(true)
                    }
                }
            }
        }

        // ── Heatmap Canvas Card ──
        Rectangle {
            width: parent.width
            height: parent.height - 44 - 32 - 28
            radius: 20
            border.width: 0
            color: githubSection.root ? githubSection.root.fillIdle : Qt.rgba(1, 1, 1, 0.05)
            clip: true

            Image {
                id: heatmapImg
                anchors.fill: parent
                anchors.margins: 18
                source: githubSection.svgSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
                visible: githubSection.svgSource !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "Fetching contribution graph..."
                font.family: githubSection.barFontFam
                font.pixelSize: 13
                font.weight: Font.Medium
                color: Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.55)
                visible: githubSection.refreshing && heatmapImg.status !== Image.Ready
            }
        }

        // ── Footer Legend ──
        Item {
            width: parent.width
            height: 32

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Last year of public contributions"
                font.family: githubSection.barFontFam
                font.pixelSize: 11
                font.weight: Font.Medium
                color: Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.50)
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Less"
                    font.family: githubSection.barFontFam
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.50)
                }

                Repeater {
                    model: [
                        githubSection.root && githubSection.root.isLightMode ? Qt.rgba(0.88, 0.90, 0.94, 1) : Qt.rgba(0.14, 0.16, 0.20, 1),
                        Qt.tint(githubSection.paperCol, Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.28)),
                        Qt.tint(githubSection.paperCol, Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.50)),
                        Qt.tint(githubSection.paperCol, Qt.rgba(githubSection.sealCol.r, githubSection.sealCol.g, githubSection.sealCol.b, 0.74)),
                        githubSection.sealCol
                    ]
                    delegate: Rectangle {
                        required property color modelData
                        width: 12
                        height: 12
                        radius: 3
                        border.width: 0
                        color: modelData
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "More"
                    font.family: githubSection.barFontFam
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: Qt.rgba(githubSection.inkCol.r, githubSection.inkCol.g, githubSection.inkCol.b, 0.50)
                }
            }
        }
    }
}

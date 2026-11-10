import QtQuick
import ".."
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../modules"

Item {
    id: hoverPanel
    required property var barSlot
    required property var island

    readonly property var root: barSlot.root
    readonly property var mprisPanel: barSlot.mprisPanel
    readonly property color accent: barSlot.accent
    readonly property color wifiColor: {
        if (root && root.color04 && String(root.color04) !== "#00000000") return root.color04
        if (root && root.indigo && String(root.indigo) !== "#00000000") return root.indigo
        return "#5B8FB9"
    }

    property alias mprisSel: mprisSel
    property alias mediaCardArt: mediaCardArt
    property alias dndProc: dndProc
    property alias projectPrevProc: projectPrevProc
    property alias projectCycleProc: projectCycleProc
    property alias fetchHeatmapProc: fetchHeatmapProc

    width: island ? island.expandedContainerWidth : 676
    height: barSlot.barExpandedHeight
    clip: true

    // Shared services
    ClockWidget {
        id: barClockShared
        root: hoverPanel.root
        visible: false
    }

    WeatherWidget {
        id: barWeatherShared
        root: hoverPanel.root
        visible: false
    }

    AudioData {
        id: barAudioShared
    }

    MprisSelect {
        id: mprisSel
    }

    MprisArtwork {
        id: mediaCardArt
        player: mprisSel.player || ((hoverPanel.mprisPanel && hoverPanel.mprisPanel.player) ? hoverPanel.mprisPanel.player : null)
        root: hoverPanel.root
    }

    // Wi-Fi detection
    property string wifiSsid: ""
    property bool wifiConnected: false

    Process {
        id: wifiProc
        command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2 | head -n1"]
        running: hoverPanel.visible
        stdout: StdioCollector {
            onStreamFinished: {
                var s = this.text.trim()
                if (s.length > 0) {
                    hoverPanel.wifiSsid = s
                    hoverPanel.wifiConnected = true
                } else {
                    hoverPanel.wifiSsid = ""
                    hoverPanel.wifiConnected = false
                }
            }
        }
    }

    Timer {
        interval: 6000
        repeat: true
        running: hoverPanel.visible
        onTriggered: {
            if (!projectStatusProc.running) projectStatusProc.running = true
        }
    }
    Component.onCompleted: projectStatusProc.running = true

    // Omarchy update & version detection
    property bool omarchyUpdateAvailable: false
    property string omarchyVersion: ""

    Process {
        id: omarchyVerProc
        running: hoverPanel.visible
        command: ["bash", "-c", "omarchy-version 2>/dev/null || cat /etc/omarchy-version 2>/dev/null || echo ''"]
        stdout: StdioCollector {
            onStreamFinished: {
                hoverPanel.omarchyVersion = this.text.trim()
            }
        }
    }

    Process {
        id: omarchyUpdateProc
        running: hoverPanel.visible
        command: ["bash", "-c", "omarchy-update-available >/dev/null 2>&1 && echo YES || echo NO"]
        stdout: StdioCollector {
            onStreamFinished: {
                hoverPanel.omarchyUpdateAvailable = (this.text.trim() === "YES")
            }
        }
    }

    // Project / Display projection settings
    readonly property string projectctlPath: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-project-ctl"
    property string projectMode: "extend"
    property string projectLabel: "Extend"
    property string projectIcon: "splitscreen"
    property bool projectActive: false

    Process {
        id: projectStatusProc
        command: [hoverPanel.projectctlPath, "status"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    hoverPanel.projectMode = data.mode || "extend"
                    hoverPanel.projectLabel = data.label || "Extend"
                    hoverPanel.projectIcon = data.icon || "splitscreen"
                    hoverPanel.projectActive = (data.active === true)
                } catch(e) {}
            }
        }
    }

    Process {
        id: projectCycleProc
        command: [hoverPanel.projectctlPath, "cycle"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    hoverPanel.projectMode = data.mode || "extend"
                    hoverPanel.projectLabel = data.label || "Extend"
                    hoverPanel.projectIcon = data.icon || "splitscreen"
                    hoverPanel.projectActive = (data.active === true)
                } catch(e) {}
            }
        }
    }

    Process {
        id: projectPrevProc
        command: [hoverPanel.projectctlPath, "prev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    hoverPanel.projectMode = data.mode || "extend"
                    hoverPanel.projectLabel = data.label || "Extend"
                    hoverPanel.projectIcon = data.icon || "splitscreen"
                    hoverPanel.projectActive = (data.active === true)
                } catch(e) {}
            }
        }
    }

    // Omarchy menu & system spec states
    property bool omarchyMenuOpen: false
    property int omarchyTab: 0

    property string siHostname: ""
    property string siModel: ""
    property string siCpu: ""
    property string siRam: ""
    property string siGpu: ""
    property string siDisplay: ""
    property string siOs: ""
    property string siKernel: ""
    property bool siFetched: false

    Process {
        id: siFetchProc
        command: ["bash", "-c",
            "hostname=$(hostname); " +
            "model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo ''); " +
            "cpu=$(grep 'model name' /proc/cpuinfo | head -1 | sed 's/.*: //' | sed 's/ with.*//'); " +
            "ram=$(awk '/MemTotal/{printf \"%.0f GB\", $2/1024/1024}' /proc/meminfo); " +
            "gpu=$(glxinfo 2>/dev/null | grep 'OpenGL renderer' | sed 's/OpenGL renderer string: //' | sed 's/\\/PCIe.*//' || echo 'N/A'); " +
            "display=$(hyprctl monitors -j 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(', '.join(str(m['width']) + 'x' + str(m['height']) + ' @' + str(int(m['refreshRate'])) + 'Hz' for m in d))\"); " +
            "os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'); " +
            "kernel=$(uname -r); " +
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s' \"$hostname\" \"$model\" \"$cpu\" \"$ram\" \"$gpu\" \"$display\" \"$os\" \"$kernel\""
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                hoverPanel.siHostname = lines[0] || ""
                hoverPanel.siModel    = lines[1] || ""
                hoverPanel.siCpu      = lines[2] || ""
                hoverPanel.siRam      = lines[3] || ""
                hoverPanel.siGpu      = lines[4] || ""
                hoverPanel.siDisplay  = lines[5] || ""
                hoverPanel.siOs       = lines[6] || ""
                hoverPanel.siKernel   = lines[7] || ""
                hoverPanel.siFetched  = true
            }
        }
    }

    Process {
        id: dndProc
        command: ["bash", "-c", "if command -v omarchy-toggle-notification-silencing >/dev/null 2>&1; then exec omarchy-toggle-notification-silencing; fi; exec omarchy toggle notification silencing"]
        onExited: if (hoverPanel.root && hoverPanel.root.refreshStatusIndicators) hoverPanel.root.refreshStatusIndicators()
    }

    onOmarchyMenuOpenChanged: {
        if (omarchyMenuOpen && !siFetched && !siFetchProc.running) {
            siFetchProc.running = true
        }
    }

    function _vendorOf(str) {
        var m = /^(NVIDIA|AMD|Intel|Apple|Qualcomm)\b/i.exec(str || "")
        return m ? (m[1].toUpperCase() === "NVIDIA" ? "NVIDIA" : m[1].toUpperCase() === "AMD" ? "AMD"
                    : m[1].charAt(0).toUpperCase() + m[1].slice(1).toLowerCase()) : ""
    }
    function cpuModel(str) {
        return (str || "")
            .replace(/\((R|TM)\)/gi, "")
            .replace(/^(AMD|Intel)\s+/i, "")
            .replace(/\s+(\d+-Core\s+)?(Processor|CPU)\b.*$/i, "")
            .replace(/\s+@.*$/, "")
            .replace(/\s+/g, " ").trim()
    }
    function gpuModel(str) {
        return (str || "")
            .replace(/\s*\(.*\)\s*$/, "")
            .replace(/^(NVIDIA|AMD|Intel)\s+(Corporation\s+)?/i, "")
            .replace(/\b(GeForce|Radeon(?=\s+RX))\s+/i, "")
            .replace(/\s*(Laptop|Mobile|Max-Q)\b/gi, "")
            .replace(/\s*(GPU|Graphics)$/i, "")
            .replace(/\s+/g, " ").trim()
    }
    function gpuChip(str) {
        var v = _vendorOf(str)
        var mobile = /\b(Laptop|Mobile|Max-Q)\b/i.test(str || "")
        return mobile ? (v !== "" ? v + " · Laptop" : "Laptop") : v
    }
    function displayModel(str) {
        var first = (str || "").split(",")[0]
        return first.replace(/\s*@.*$/, "").replace("x", " × ").trim()
    }
    function displayChip(str) {
        var parts = (str || "").split(",")
        var m = /@\s*(\d+)\s*Hz/i.exec(parts[0] || "")
        var hz = m ? m[1] + " Hz" : ""
        return parts.length > 1 ? (hz !== "" ? hz + " · +" + (parts.length - 1) : "+" + (parts.length - 1)) : hz
    }

    // ── GitHub Heatmap Integration ────────────────────────────────────────────
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

    readonly property color ghAccent: hoverPanel.root.paletteColor(hoverPanel.root.barColor)
    readonly property string ghHexEmpty: toHex(blend(hoverPanel.root.ink, hoverPanel.root.paper, 0.1))
    readonly property string ghHexLvl1:  toHex(blend(ghAccent, hoverPanel.root.paper, 0.35))
    readonly property string ghHexLvl2:  toHex(blend(ghAccent, hoverPanel.root.paper, 0.55))
    readonly property string ghHexLvl3:  toHex(blend(ghAccent, hoverPanel.root.paper, 0.75))
    readonly property string ghHexLvl4:  toHex(ghAccent)
    readonly property string ghHexText:  toHex(hoverPanel.root.sumiHi)

    property string ghSvgSource: "file://" + Quickshell.env("HOME") + "/.cache/quickshell_ghchart_colored.svg"
    property bool ghRefreshing: false

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
            "  curl -s \"https://ghchart.rshah.org/itcodehery\" > \"$cache_file.tmp\"; " +
            "  if grep -q '<svg' \"$cache_file.tmp\"; then mv \"$cache_file.tmp\" \"$cache_file\"; else rm -f \"$cache_file.tmp\"; fi; " +
            "fi; " +
            "if [ -f \"$cache_file\" ]; then " +
            "  if [ -x \"$crop_script\" ]; then " +
            "    \"$crop_script\" \"$cache_file\" \"$colored_file\" " +
            "      \"" + hoverPanel.ghHexEmpty + "\" \"" + hoverPanel.ghHexLvl1 + "\" \"" + hoverPanel.ghHexLvl2 + "\" " +
            "      \"" + hoverPanel.ghHexLvl3 + "\" \"" + hoverPanel.ghHexLvl4 + "\" \"" + hoverPanel.ghHexText + "\" 327; " +
            "  else " +
            "    cp \"$cache_file\" \"$colored_file\"; " +
            "    sed -i 's/#eeeeee/" + hoverPanel.ghHexEmpty + "/g' \"$colored_file\"; " +
            "    sed -i 's/#c6e48b/" + hoverPanel.ghHexLvl1 + "/g' \"$colored_file\"; " +
            "    sed -i 's/#7bc96f/" + hoverPanel.ghHexLvl2 + "/g' \"$colored_file\"; " +
            "    sed -i 's/#239a3b/" + hoverPanel.ghHexLvl3 + "/g' \"$colored_file\"; " +
            "    sed -i 's/#196127/" + hoverPanel.ghHexLvl4 + "/g' \"$colored_file\"; " +
            "    sed -i 's/#767676/" + hoverPanel.ghHexText + "/g' \"$colored_file\"; " +
            "  fi; " +
            "fi"
        ]
        onExited: {
            hoverPanel.ghSvgSource = "file://" + Quickshell.env("HOME") + "/.cache/quickshell_ghchart_colored.svg?t=" + new Date().getTime()
            hoverPanel.ghRefreshing = false
        }
    }

    onOmarchyTabChanged: {
        if (omarchyTab === 1 && !fetchHeatmapProc.running) {
            ghRefreshing = true
            fetchHeatmapProc.running = true
        }
    }

    onVisibleChanged: {
        if (visible) {
            if (!omarchyUpdateProc.running) omarchyUpdateProc.running = true
            if (!omarchyVerProc.running && hoverPanel.omarchyVersion === "") omarchyVerProc.running = true
            projectStatusProc.running = false
            projectStatusProc.running = true
            if (hoverPanel.root && (!hoverPanel.root.archUpdates || hoverPanel.root.archUpdates.length === 0)) {
                hoverPanel.root.archRefreshTick++
            }
        } else {
            omarchyMenuOpen = false
            omarchyTab = 0
        }
    }

    // FontLoader for "Bigger" Font
    FontLoader {
        id: biggerFont
        source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Unknown Vendor/OpenType/Bigger/Bigger_Display.otf"
    }

    // Screentime of today
    property string screentimeStr: "0m"
    Process {
        id: stProc
        running: hoverPanel.visible
        command: ["cat", "/home/hery/.cache/screentime_session.txt"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = parseInt(this.text.trim())
                if (!isNaN(s)) {
                    let h = Math.floor(s / 3600)
                    let m = Math.floor((s % 3600) / 60)
                    if (h > 0) hoverPanel.screentimeStr = h + "h " + m + "m"
                    else if (m > 0) hoverPanel.screentimeStr = m + "m"
                    else hoverPanel.screentimeStr = s + "s"
                }
            }
        }
    }


    function toggleWifi() {
        Quickshell.execDetached(["bash", "-c", "nmcli radio wifi | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on"])
        wifiConnected = !wifiConnected
    }

    readonly property var workspaceList: {
        var ws = Hyprland.workspaces.values
        var focused = Hyprland.focusedWorkspace
        var maxWs = 5
        for (var i = 0; i < ws.length; i++) {
            if (ws[i].id > maxWs) maxWs = Math.min(ws[i].id, 10)
        }
        if (focused && focused.id > maxWs) maxWs = Math.min(focused.id, 10)
        var list = []
        for (var j = 1; j <= maxWs; j++) list.push(j)
        return list
    }

    function stepVolume(delta) {
        var cur = barAudioShared.volume
        var next = Math.max(0, Math.min(100, cur + delta))
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (next / 100).toFixed(2)])
    }

    function toggleMute() {
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // LEFT CARD: Compact Redesigned Clock & Calendar Card
    // ─────────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: leftClockCard
        x: 8
        y: Math.round((hoverPanel.height - height) / 2)
        width: 140
        height: hoverPanel.height - 8
        radius: 13
        color: leftHover.hovered
            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
        border.width: 1
        border.color: hoverPanel.root.cardBorderColor
        Behavior on color { ColorAnimation { duration: 160 } }

        Row {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 8

            // Left mini accent pill with calendar icon / day of week
            Rectangle {
                width: 34
                height: parent.height
                radius: 10
                color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, leftHover.hovered ? 0.22 : 0.15)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 160 } }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var d = barClockShared.now || new Date()
                            var days = ["SUN","MON","TUE","WED","THU","FRI","SAT"]
                            return days[d.getDay()]
                        }
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 8
                        font.weight: Font.Black
                        font.letterSpacing: 0.5
                        color: hoverPanel.accent
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            var d = barClockShared.now || new Date()
                            return String(d.getDate())
                        }
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: hoverPanel.root.ink
                    }
                }
            }

            // Right side: Bold Time + Weather & Month
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Row {
                    spacing: 3
                    Text {
                        id: mainTimeDigits
                        text: {
                            var d = barClockShared.now || new Date()
                            var h = d.getHours()
                            if (barClockShared.is12Hour !== false) {
                                h = h % 12
                                if (h === 0) h = 12
                            }
                            var m = d.getMinutes()
                            return (h < 10 ? "0" + h : String(h)) + ":" + (m < 10 ? "0" + m : String(m))
                        }
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 16
                        font.weight: Font.Black
                        color: hoverPanel.root.ink
                        renderType: Text.QtRendering
                    }

                    Text {
                        anchors.baseline: mainTimeDigits.baseline
                        text: {
                            var t = barClockShared.timeStr || ""
                            var m = t.match(/\b(AM|PM)\b/i)
                            return m ? m[1] : ""
                        }
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                    }
                }

                // Weather and month
                Row {
                    spacing: 4
                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: barWeatherShared.weatherLoaded ? barWeatherShared.weatherIcon : "sunny"
                        font.pixelSize: 11
                        color: hoverPanel.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: barWeatherShared.weatherLoaded ? barWeatherShared.weatherTempStr : "--°"
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.75)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "·"
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 8
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            var d = barClockShared.now || new Date()
                            var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                            return months[d.getMonth()]
                        }
                        font.family: hoverPanel.root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Medium
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.55)
                    }
                }
            }
        }

        HoverHandler { id: leftHover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                hoverPanel.root.dashboardExpanded = true
                hoverPanel.root.dashboardDetail = "calendar"
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // MIDDLE SECTION: Single Compact Row (Standard View + Workspaces Strip)
    // ─────────────────────────────────────────────────────────────────────────────
    Item {
        id: middleSection
        x: leftClockCard.x + leftClockCard.width + 8
        y: Math.round((hoverPanel.height - height) / 2)
        width: Math.max(100, hoverPanel.width - leftClockCard.width - rightMediaCard.width - 24)
        height: hoverPanel.height - 8
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Item {
            anchors.fill: parent

            // 1. Standard View + Workspaces Strip (Shown when omarchyMenuOpen is FALSE)
            Row {
                anchors.fill: parent
                spacing: 6
                visible: !hoverPanel.omarchyMenuOpen && hoverPanel.omarchyTab !== 1

                HoverQuickSettingsStandardView {
                    id: standardQuickView
                    hoverPanel: hoverPanel
                    width: parent.width - wsBlock.width - 6
                    height: parent.height
                }

                Row {
                    id: wsBlock
                    height: parent.height
                    spacing: 6

                    // Omarchy Control Center Button (toggles Omarchy Controls view)
                    Rectangle {
                        id: omarchyControlBtn
                        width: parent.height
                        height: parent.height
                        radius: 12
                        color: omarchyBtnHov.hovered
                            ? (hoverPanel.omarchyMenuOpen
                                ? hoverPanel.accent
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14))
                            : (hoverPanel.omarchyMenuOpen
                                ? hoverPanel.accent
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.07))
                        border.width: 1
                        border.color: hoverPanel.root.cardBorderColor

                        scale: omarchyBtnMa.pressed ? 0.92 : (omarchyBtnHov.hovered ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        HoverHandler { id: omarchyBtnHov }

                        Text {
                            anchors.centerIn: parent
                            text: hoverPanel.root.launcherLogoIconGlyph(hoverPanel.root.launcherLogoIcon)
                            font.family: hoverPanel.root.launcherLogoIconFont(hoverPanel.root.launcherLogoIcon)
                            font.pixelSize: 15
                            color: hoverPanel.omarchyMenuOpen
                                ? ((hoverPanel.accent.r * 0.299 + hoverPanel.accent.g * 0.587 + hoverPanel.accent.b * 0.114 > 0.55) ? "#121212" : "#ffffff")
                                : hoverPanel.root.ink
                            renderType: Text.QtRendering
                        }

                        MouseArea {
                            id: omarchyBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hoverPanel.omarchyMenuOpen = !hoverPanel.omarchyMenuOpen
                            }
                        }
                    }

                    // Workspace Indicator Strip
                    Rectangle {
                        height: parent.height
                        width: wsStripArea.width + 12
                        radius: 12
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.05)
                        border.width: 1
                        border.color: hoverPanel.root.cardBorderColor

                        Item {
                            id: wsStripArea
                            anchors.centerIn: parent
                            width: wsRow.width
                            height: 20

                            function wsHasWindows(id) {
                                var ws = Hyprland.workspaces.values
                                for (var i = 0; i < ws.length; i++) {
                                    if (ws[i].id === id) {
                                        var topCount = (ws[i].toplevels && ws[i].toplevels.values) ? ws[i].toplevels.values.length : 0
                                        return topCount > 0 || (ws[i].windows !== undefined && ws[i].windows > 0)
                                    }
                                }
                                return false
                            }

                            function getWsCellWidth(id, isFoc) {
                                if (isFoc) return 26
                                return wsHasWindows(id) ? 18 : 14
                            }

                            readonly property int focusedIndex: {
                                var f = Hyprland.focusedWorkspace
                                if (!f) return 0
                                var idx = hoverPanel.workspaceList.indexOf(f.id)
                                return idx >= 0 ? idx : 0
                            }

                            readonly property real targetX: {
                                var tx = 0
                                for (var i = 0; i < focusedIndex && i < hoverPanel.workspaceList.length; i++) {
                                    var id = hoverPanel.workspaceList[i]
                                    tx += getWsCellWidth(id, false) + wsRow.spacing
                                }
                                return tx
                            }

                            // Sliding Active Pill
                            Rectangle {
                                id: slidingPill
                                width: 26
                                height: 18
                                radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                color: hoverPanel.accent
                                x: wsStripArea.targetX

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 240
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.25
                                    }
                                }
                            }

                            Row {
                                id: wsRow
                                spacing: 3

                                Repeater {
                                    model: hoverPanel.workspaceList

                                    delegate: Item {
                                        id: wsCell
                                        required property int modelData
                                        readonly property int wsId: modelData
                                        readonly property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsId
                                        readonly property bool hasWindows: wsStripArea.wsHasWindows(wsId)

                                        width: wsStripArea.getWsCellWidth(wsId, isFocused)
                                        height: 20

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 240
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.25
                                            }
                                        }

                                        // Subtle hover indicator for unselected items
                                        Rectangle {
                                            visible: !isFocused && wsHov.hovered
                                            anchors.centerIn: parent
                                            width: parent.width
                                            height: 16
                                            radius: 8
                                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12)
                                        }

                                        // Dot ONLY for workspaces with NO windows
                                        Rectangle {
                                            visible: !isFocused && !hasWindows
                                            anchors.centerIn: parent
                                            width: 4
                                            height: 4
                                            radius: 2
                                            color: wsHov.hovered ? hoverPanel.root.ink : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.40)
                                        }

                                        // Number shown for focused AND for workspaces with windows
                                        Text {
                                            visible: isFocused || hasWindows
                                            anchors.centerIn: parent
                                            text: String(wsId)
                                            font.family: hoverPanel.root.barFont
                                            font.pixelSize: 9
                                            font.weight: isFocused ? Font.Bold : Font.Medium
                                            color: isFocused
                                                ? ((hoverPanel.accent.r * 0.299 + hoverPanel.accent.g * 0.587 + hoverPanel.accent.b * 0.114 > 0.55) ? "#121212" : "#ffffff")
                                                : hoverPanel.root.ink
                                        }

                                        HoverHandler { id: wsHov; cursorShape: Qt.PointingHandCursor }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hoverPanel.root.gotoWorkspace(wsId)
                                        }
                                    }
                                }
                            }
                        }

                        WheelHandler {
                            onWheel: (event) => {
                                if (event.angleDelta.y < 0) hoverPanel.root.nextWorkspace()
                                else if (event.angleDelta.y > 0) hoverPanel.root.prevWorkspace()
                            }
                        }
                    }
                }
            }

            // 2. Omarchy Settings View (Shown when omarchyMenuOpen is TRUE)
            HoverQuickSettingsOmarchyView {
                id: omarchyView
                hoverPanel: hoverPanel
                anchors.fill: parent
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // RIGHT CARD: Media Player with Everything Vertically Arranged
    // ─────────────────────────────────────────────────────────────────────────────
    HoverQuickSettingsMediaCard {
        id: rightMediaCard
        hoverPanel: hoverPanel
    }
}

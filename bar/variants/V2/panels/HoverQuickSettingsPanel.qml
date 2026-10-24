import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import "../modules"

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
            if (!wifiProc.running) wifiProc.running = true
            if (!stProc.running) stProc.running = true
            if (!omarchyUpdateProc.running) omarchyUpdateProc.running = true
            if (!omarchyVerProc.running && hoverPanel.omarchyVersion === "") omarchyVerProc.running = true
        }
    }

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
            "  sed -i 's/#eeeeee/" + hoverPanel.ghHexEmpty + "/g' \"$colored_file\"; " +
            "  sed -i 's/#c6e48b/" + hoverPanel.ghHexLvl1 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#7bc96f/" + hoverPanel.ghHexLvl2 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#239a3b/" + hoverPanel.ghHexLvl3 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#196127/" + hoverPanel.ghHexLvl4 + "/g' \"$colored_file\"; " +
            "  sed -i 's/#767676/" + hoverPanel.ghHexText + "/g' \"$colored_file\"; " +
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
    // LEFT CARD: Vertically Arranged Clock (Bigger Font) + AM/PM Below + Date & Weather
    // ─────────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: leftClockCard
        x: 8
        y: 6
        width: 112
        height: 144
        radius: 18
        color: leftHover.hovered
            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(255, 255, 255, 0.04)
        Behavior on color { ColorAnimation { duration: 160 } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            width: parent.width - 12

            // Vertically Arranged Clock: Big Hour on Top, Big Minute on Bottom (Bigger font)
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: -6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var d = barClockShared.now || new Date()
                        var h = d.getHours()
                        if (barClockShared.is12Hour !== false) {
                            h = h % 12
                            if (h === 0) h = 12
                        }
                        return h < 10 ? "0" + h : String(h)
                    }
                    font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: hoverPanel.root.ink
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        var d = barClockShared.now || new Date()
                        var m = d.getMinutes()
                        return m < 10 ? "0" + m : String(m)
                    }
                    font.family: biggerFont.name.length > 0 ? biggerFont.name : "Bigger"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: hoverPanel.root.ink
                    opacity: 0.45
                }
            }

            // AM/PM below the clock
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    var t = barClockShared.timeStr || ""
                    var m = t.match(/\b(AM|PM)\b/i)
                    return m ? m[1] : ""
                }
                font.family: hoverPanel.root.barFont
                font.pixelSize: 10
                font.weight: Font.Bold
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
            }

            // Date
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    var d = barClockShared.now || new Date()
                    var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                    var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                    return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()]
                }
                font.family: hoverPanel.root.barFont
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.55)
            }

            // Weather capsule
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 19
                width: Math.min(parent.width, weatherRow.implicitWidth + 12)
                radius: 9.5
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)

                Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 3

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
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.75)
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
    // MIDDLE SECTION: 2x2 Big Buttons, Brightness Card, Sound Card, Data Strip
    // ─────────────────────────────────────────────────────────────────────────────
    Item {
        id: middleSection
        x: leftClockCard.x + leftClockCard.width + 8
        y: 6
        width: hoverPanel.width - leftClockCard.width - rightMediaCard.width - 32
        height: 144
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Column {
            anchors.fill: parent
            spacing: 6

            // Top Row: Standard Quick Settings vs Omarchy Controls & System Info
            Item {
                id: topContainer
                width: parent.width
                height: parent.height - 34
                clip: true

                // ── Standard Quick Settings View ──
                Row {
                    id: standardQuickView
                    anchors.fill: parent
                    spacing: 8
                    visible: opacity > 0.001
                    opacity: hoverPanel.omarchyMenuOpen ? 0.0 : 1.0
                    scale: hoverPanel.omarchyMenuOpen ? 0.95 : 1.0
                    enabled: !hoverPanel.omarchyMenuOpen
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    // 2x2 Grid of Big Squircle Toggle Buttons
                    Grid {
                        id: toggleGrid
                        columns: 2
                        spacing: 6
                        width: 104
                        height: parent.height

                    // Button 1: GitHub Heatmap Toggle (replaces Night Light)
                    Rectangle {
                        id: btn1Heatmap
                        width: 49
                        height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
                        radius: 14
                        readonly property bool isActive: hoverPanel.omarchyMenuOpen && hoverPanel.omarchyTab === 1
                        color: isActive
                            ? (btn1Hov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                            : (btn1Hov.hovered
                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                        border.width: 1
                        border.color: isActive ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                        scale: btn1Hov.hovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(0xF09B) // GitHub icon
                            font.family: hoverPanel.root.barFont
                            font.pixelSize: 20
                            color: btn1Heatmap.isActive ? hoverPanel.root.paper : hoverPanel.root.ink
                        }

                        HoverHandler { id: btn1Hov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (hoverPanel.omarchyMenuOpen && hoverPanel.omarchyTab === 1) {
                                    hoverPanel.omarchyMenuOpen = false
                                    hoverPanel.omarchyTab = 0
                                } else {
                                    hoverPanel.omarchyMenuOpen = true
                                    hoverPanel.omarchyTab = 1
                                }
                            }
                        }
                    }

                    // Button 2: Lock / Screen lock
                    Rectangle {
                        width: 49
                        height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
                        radius: 14
                        color: btn2Hov.hovered
                            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.04)
                        scale: btn2Hov.hovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        IconText {
                            anchors.centerIn: parent
                            text: "lock"
                            font.pixelSize: 20
                            color: hoverPanel.root.ink
                        }

                        HoverHandler { id: btn2Hov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/bin/qs-lock"])
                        }
                    }

                    // Button 3: Wi-Fi Toggle
                    Rectangle {
                        width: 49
                        height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
                        radius: 14
                        color: hoverPanel.wifiConnected
                            ? (btn3Hov.hovered ? Qt.lighter(hoverPanel.wifiColor, 1.12) : hoverPanel.wifiColor)
                            : (btn3Hov.hovered
                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                        border.width: 1
                        border.color: hoverPanel.wifiConnected ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                        scale: btn3Hov.hovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 1

                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: hoverPanel.wifiConnected ? "signal_wifi_4_bar" : "signal_wifi_off"
                                font.pixelSize: 19
                                color: hoverPanel.root.ink
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Wi-Fi"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: hoverPanel.wifiConnected ? hoverPanel.root.ink : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.6)
                            }
                        }

                        HoverHandler { id: btn3Hov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: hoverPanel.toggleWifi()
                        }
                    }

                    // Button 4: Notification Bell / DND
                    Rectangle {
                        width: 49
                        height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
                        radius: 14
                        color: hoverPanel.root.notifSilenced
                            ? (btn4Hov.hovered ? Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.35) : Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.22))
                            : (btn4Hov.hovered
                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.04)
                        scale: btn4Hov.hovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Item {
                            anchors.fill: parent
                            IconText {
                                anchors.centerIn: parent
                                text: hoverPanel.root.notifSilenced ? "notifications_off" : "notifications"
                                font.pixelSize: 20
                                color: hoverPanel.root.notifSilenced ? hoverPanel.accent : hoverPanel.root.ink
                            }

                            // Unread Badge Dot
                            Rectangle {
                                visible: hoverPanel.root.notifCount > 0 && !hoverPanel.root.notifSilenced
                                width: 7
                                height: 7
                                radius: 3.5
                                color: hoverPanel.accent
                                x: parent.width - width - 6
                                y: 6
                            }
                        }

                        HoverHandler { id: btn4Hov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                                hoverPanel.root.dashboardExpanded = true
                                hoverPanel.root.dashboardDetail = "notifications"
                            }
                        }
                    }
                }

                // Screentime Card (matching reference UI with fully rounded floating pill)
                Rectangle {
                    id: screentimeCard
                    width: Math.floor((parent.width - toggleGrid.width - 16) / 2)
                    height: parent.height
                    radius: 18
                    color: briCardHov.hovered
                        ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
                        : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.04)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                            hoverPanel.root.dashboardExpanded = true
                            hoverPanel.root.dashboardDetail = "screentime"
                        }
                    }

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        spacing: 2

                        Text {
                            text: "Screentime"
                            font.family: hoverPanel.root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                        }

                        Text {
                            text: hoverPanel.screentimeStr || "0m"
                            font.family: hoverPanel.root.barFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: hoverPanel.root.ink
                            elide: Text.ElideRight
                        }
                    }

                    // Interactive bottom floating pill (fully rounded on all corners, matching reference image)
                    Rectangle {
                        id: stCapsule
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        height: 30
                        radius: height / 2
                        color: stMa.containsMouse
                            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14)
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "Today"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: hoverPanel.root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: "||"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            IconText {
                                text: "hourglass_top"
                                font.pixelSize: 13
                                color: hoverPanel.accent
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: stMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                                hoverPanel.root.dashboardExpanded = true
                                hoverPanel.root.dashboardDetail = "screentime"
                            }
                        }
                    }

                    HoverHandler { id: briCardHov }
                }

                // Packages Card (matching reference UI with fully rounded floating pill & version display)
                Rectangle {
                    id: packagesCard
                    width: Math.floor((parent.width - toggleGrid.width - 16) / 2)
                    height: parent.height
                    radius: 18
                    color: pkgCardHov.hovered
                        ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)
                        : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.04)

                    readonly property int updateCount: (hoverPanel.root && hoverPanel.root.archUpdates) ? hoverPanel.root.archUpdates.length : 0

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            hoverPanel.root.activatePopupScreen(hoverPanel.barSlot.screen)
                            hoverPanel.root.activeUpdateTab = "packages"
                            hoverPanel.root.dashboardExpanded = true
                            hoverPanel.root.dashboardDetail = "updates"
                        }
                    }

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        spacing: 2

                        Text {
                            text: "Packages"
                            font.family: hoverPanel.root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                        }

                        Row {
                            spacing: 4
                            width: parent.width

                            Text {
                                text: packagesCard.updateCount > 0
                                    ? (packagesCard.updateCount + (packagesCard.updateCount === 1 ? " update" : " updates"))
                                    : "Up to date"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: hoverPanel.root.ink
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width - 20)
                            }

                            IconText {
                                text: packagesCard.updateCount > 0 ? "upgrade" : "check"
                                font.pixelSize: 13
                                color: packagesCard.updateCount > 0 ? hoverPanel.accent : "#4ADE80"
                            }
                        }
                    }

                    // Interactive bottom floating pill (fully rounded on all corners, matching reference image)
                    Rectangle {
                        id: pkgCapsule
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 6
                        height: 30
                        radius: height / 2
                        color: pkgMa.containsMouse
                            ? (hoverPanel.omarchyUpdateAvailable
                                ? Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.28)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14))
                            : (hoverPanel.omarchyUpdateAvailable
                                ? Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.18)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            width: Math.min(implicitWidth, parent.width - 12)

                            Text {
                                text: "\uE900"
                                font.family: "omarchy"
                                font.pixelSize: 12
                                color: hoverPanel.omarchyUpdateAvailable ? hoverPanel.accent : hoverPanel.root.ink
                                opacity: hoverPanel.omarchyUpdateAvailable ? 1.0 : 0.65
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: hoverPanel.omarchyUpdateAvailable
                                    ? "Omarchy update!"
                                    : (hoverPanel.omarchyVersion !== ""
                                        ? (hoverPanel.omarchyVersion.startsWith("v") ? hoverPanel.omarchyVersion : ("v" + hoverPanel.omarchyVersion))
                                        : "Up to date")
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: hoverPanel.omarchyUpdateAvailable ? hoverPanel.accent : hoverPanel.root.ink
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.parent.width - 48)
                            }

                            IconText {
                                text: hoverPanel.omarchyUpdateAvailable ? "sync" : "check"
                                font.pixelSize: 12
                                color: hoverPanel.omarchyUpdateAvailable ? hoverPanel.accent : "#4ADE80"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: pkgMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (hoverPanel.omarchyUpdateAvailable) {
                                    Quickshell.execDetached(["bash", "-c", "omarchy-launch-floating-terminal-with-presentation omarchy-update"])
                                } else {
                                    omarchyUpdateProc.running = false
                                    omarchyUpdateProc.running = true
                                    if (hoverPanel.omarchyVersion === "") {
                                        omarchyVerProc.running = false
                                        omarchyVerProc.running = true
                                    }
                                    if (hoverPanel.root) hoverPanel.root.archRefreshTick++
                                }
                            }
                        }
                    }

                    HoverHandler { id: pkgCardHov }
                }
            } // end standardQuickView

            // ── Omarchy Controls & System Info View ──
            Item {
                id: omarchyView
                anchors.fill: parent
                visible: opacity > 0.001
                opacity: hoverPanel.omarchyMenuOpen ? 1.0 : 0.0
                scale: hoverPanel.omarchyMenuOpen ? 1.0 : 0.95
                enabled: hoverPanel.omarchyMenuOpen
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    spacing: 6
                    visible: hoverPanel.omarchyTab !== 1

                    // Header Row: Logo · Host · Tab Selector (Options / System Info) · Close Button
                    Item {
                        width: parent.width
                        height: 24

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 7
                                color: hoverPanel.accent
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    anchors.centerIn: parent
                                    text: "\uE900"
                                    color: hoverPanel.root.paper
                                    font.family: "omarchy"
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: hoverPanel.siHostname !== "" ? hoverPanel.siHostname : "Omarchy"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: hoverPanel.root.ink
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "·"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 11
                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: hoverPanel.siOs !== "" ? hoverPanel.siOs : "Control Center"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.55)
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            // Material 3 Expressive Segmented Tab Pill
                            Rectangle {
                                height: 24
                                width: tabRow.implicitWidth + 8
                                radius: 12
                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)

                                Rectangle {
                                    id: tabPill
                                    height: 20
                                    y: 2
                                    radius: 10
                                    color: hoverPanel.accent
                                    x: hoverPanel.omarchyTab === 0 ? 2 : (tabBtnSettings.width + 4)
                                    width: hoverPanel.omarchyTab === 0 ? tabBtnSettings.width : tabBtnSystem.width
                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                }

                                Row {
                                    id: tabRow
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Item {
                                        id: tabBtnSettings
                                        width: tabSetRow.implicitWidth + 12
                                        height: 20

                                        Row {
                                            id: tabSetRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "tune"
                                                font.pixelSize: 11
                                                color: hoverPanel.omarchyTab === 0 ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Options"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: hoverPanel.omarchyTab === 0 ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hoverPanel.omarchyTab = 0
                                        }
                                    }

                                    Item {
                                        id: tabBtnSystem
                                        width: tabSysRow.implicitWidth + 12
                                        height: 20

                                        Row {
                                            id: tabSysRow
                                            anchors.centerIn: parent
                                            spacing: 3
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "developer_board"
                                                font.pixelSize: 11
                                                color: hoverPanel.omarchyTab === 2 ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "System Info"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: hoverPanel.omarchyTab === 2 ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: hoverPanel.omarchyTab = 2
                                        }
                                    }
                                }
                            }

                            // Close X button
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: closeHov.hovered
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                                    : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                                IconText {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.pixelSize: 13
                                    color: hoverPanel.root.ink
                                }
                                HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: hoverPanel.omarchyMenuOpen = false
                                }
                            }
                        }
                    }

                    // Content Container (80px tall)
                    Item {
                        id: tabContentContainer
                        width: parent.width
                        height: 80
                        clip: true

                        WheelHandler {
                            onWheel: (event) => {
                                if (event.angleDelta.y < 0) hoverPanel.omarchyTab = Math.min(2, hoverPanel.omarchyTab + 1)
                                else if (event.angleDelta.y > 0) hoverPanel.omarchyTab = Math.max(0, hoverPanel.omarchyTab - 1)
                            }
                        }

                        // ── Tab 0: Options (5 Quick Action Chips + Bar Color + Picker Style) ──
                        Item {
                            id: optionsTabContent
                            anchors.fill: parent
                            visible: opacity > 0.001
                            opacity: hoverPanel.omarchyTab === 0 ? 1.0 : 0.0
                            x: hoverPanel.omarchyTab === 0 ? 0 : -20
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            enabled: hoverPanel.omarchyTab === 0

                            Column {
                                anchors.fill: parent
                                spacing: 5

                                // Row 1: 5 Material 3 Expressive Action Chips
                                Row {
                                    width: parent.width
                                    height: 36
                                    spacing: 6
                                    readonly property real chipW: Math.floor((width - 4 * 6) / 5)

                                    // 1. GitHub Heatmap (replaces Edit slots, opens directly in control panel)
                                    Rectangle {
                                        width: parent.chipW
                                        height: parent.height
                                        radius: 12
                                        color: hoverPanel.omarchyTab === 1
                                            ? (hmHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                            : (hmHov.hovered
                                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                                        border.width: 1
                                        border.color: hoverPanel.omarchyTab === 1 ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                                        scale: hmHov.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "data_object"
                                                font.pixelSize: 13
                                                color: hoverPanel.omarchyTab === 1 ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "GH Heatmap"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: hoverPanel.omarchyTab === 1 ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                        }
                                        HoverHandler { id: hmHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                hoverPanel.omarchyTab = 1
                                            }
                                        }
                                    }

                                    // 2. Position
                                    Rectangle {
                                        width: parent.chipW
                                        height: parent.height
                                        radius: 12
                                        color: posHov.hovered
                                            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.04)
                                        scale: posHov.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: hoverPanel.root.barPosition === "bottom" ? "vertical_align_bottom" : "vertical_align_top"
                                                font.pixelSize: 13
                                                color: hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: hoverPanel.root.barPosition === "bottom" ? "Bottom" : "Top"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: hoverPanel.root.ink
                                            }
                                        }
                                        HoverHandler { id: posHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: hoverPanel.root.barPosition = hoverPanel.root.barPosition === "bottom" ? "top" : "bottom"
                                        }
                                    }

                                    // 3. Do not disturb
                                    Rectangle {
                                        width: parent.chipW
                                        height: parent.height
                                        radius: 12
                                        color: hoverPanel.root.notifSilenced
                                            ? (dndHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                            : (dndHov.hovered
                                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                                        border.width: 1
                                        border.color: hoverPanel.root.notifSilenced ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                                        scale: dndHov.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: hoverPanel.root.notifSilenced ? "notifications_off" : "notifications"
                                                font.pixelSize: 13
                                                color: hoverPanel.root.notifSilenced ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "DND"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: hoverPanel.root.notifSilenced ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                        }
                                        HoverHandler { id: dndHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: { dndProc.running = false; dndProc.running = true }
                                        }
                                    }

                                    // 4. Bar Border
                                    Rectangle {
                                        width: parent.chipW
                                        height: parent.height
                                        radius: 12
                                        color: hoverPanel.root.barBorderEnabled
                                            ? (bbHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                            : (bbHov.hovered
                                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                                        border.width: 1
                                        border.color: hoverPanel.root.barBorderEnabled ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                                        scale: bbHov.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "border_outer"
                                                font.pixelSize: 13
                                                color: hoverPanel.root.barBorderEnabled ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Bar Border"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: hoverPanel.root.barBorderEnabled ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                        }
                                        HoverHandler { id: bbHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: hoverPanel.root.barBorderEnabled = !hoverPanel.root.barBorderEnabled
                                        }
                                    }

                                    // 5. Panel Border
                                    Rectangle {
                                        width: parent.chipW
                                        height: parent.height
                                        radius: 12
                                        color: hoverPanel.root.panelTooltipBorderEnabled
                                            ? (pbHov.hovered ? Qt.lighter(hoverPanel.accent, 1.1) : hoverPanel.accent)
                                            : (pbHov.hovered
                                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.15)
                                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                                        border.width: 1
                                        border.color: hoverPanel.root.panelTooltipBorderEnabled ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                                        scale: pbHov.hovered ? 1.03 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "select_window"
                                                font.pixelSize: 13
                                                color: hoverPanel.root.panelTooltipBorderEnabled ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Panel Border"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: hoverPanel.root.panelTooltipBorderEnabled ? hoverPanel.root.paper : hoverPanel.root.ink
                                            }
                                        }
                                        HoverHandler { id: pbHov; cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: hoverPanel.root.panelTooltipBorderEnabled = !hoverPanel.root.panelTooltipBorderEnabled
                                        }
                                    }
                                }

                                // Row 2: Bar Color Swatches Card + Picker Style Card
                                Row {
                                    width: parent.width
                                    height: 38
                                    spacing: 6

                                    // Bar Color Swatches Card
                                    Rectangle {
                                        width: Math.floor(parent.width * 0.53)
                                        height: parent.height
                                        radius: 13
                                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.04)

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "palette"
                                                font.pixelSize: 14
                                                color: hoverPanel.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Color"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.60)
                                            }

                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4

                                                Repeater {
                                                    model: hoverPanel.root.barColorOptions
                                                    delegate: Rectangle {
                                                        id: swatchItem
                                                        required property string modelData
                                                        width: 18
                                                        height: 18
                                                        radius: 9
                                                        color: hoverPanel.root.paletteColor(modelData)
                                                        scale: swatchHov.hovered ? 1.18 : (hoverPanel.root.barColor === modelData ? 1.05 : 0.92)
                                                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                                                        IconText {
                                                            anchors.centerIn: parent
                                                            visible: hoverPanel.root.barColor === swatchItem.modelData
                                                            text: "check"
                                                            color: hoverPanel.root.paletteContrastColor(swatchItem.modelData)
                                                            font.pixelSize: 10
                                                            font.weight: Font.Bold
                                                        }

                                                        HoverHandler { id: swatchHov; cursorShape: Qt.PointingHandCursor }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: hoverPanel.root.barColor = swatchItem.modelData
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Picker Style Card
                                    Rectangle {
                                        width: parent.width - Math.floor(parent.width * 0.53) - parent.spacing
                                        height: parent.height
                                        radius: 13
                                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                                        border.width: 1
                                        border.color: Qt.rgba(255, 255, 255, 0.04)

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            IconText {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "dashboard_customize"
                                                font.pixelSize: 14
                                                color: hoverPanel.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "Picker"
                                                font.family: hoverPanel.root.barFont
                                                font.pixelSize: 10
                                                font.weight: Font.Bold
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.60)
                                            }

                                            Row {
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3

                                                Repeater {
                                                    model: [
                                                        { label: "Tanzaku", val: "tanzaku" },
                                                        { label: "Hearthstone", val: "hearthstone" },
                                                        { label: "Carousel", val: "carousel" }
                                                    ]
                                                    delegate: Rectangle {
                                                        id: pickerBtn
                                                        required property var modelData
                                                        readonly property bool isCur: hoverPanel.root.pickerStyle === modelData.val
                                                        height: 24
                                                        width: Math.max(48, pTxt.implicitWidth + 12)
                                                        radius: 12
                                                        color: isCur
                                                            ? hoverPanel.accent
                                                            : (pHov.hovered ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12) : "transparent")
                                                        Behavior on color { ColorAnimation { duration: 120 } }

                                                        Text {
                                                            id: pTxt
                                                            anchors.centerIn: parent
                                                            text: pickerBtn.modelData.label
                                                            font.family: hoverPanel.root.barFont
                                                            font.pixelSize: 9
                                                            font.weight: pickerBtn.isCur ? Font.Bold : Font.Normal
                                                            color: pickerBtn.isCur ? hoverPanel.root.paper : hoverPanel.root.ink
                                                        }

                                                        HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: hoverPanel.root.pickerStyle = pickerBtn.modelData.val
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }


                        // ── Tab 2: System Info (Processor, Memory, Graphics, Display) ──
                        Item {
                            id: systemTabContent
                            anchors.fill: parent
                            visible: opacity > 0.001
                            opacity: hoverPanel.omarchyTab === 2 ? 1.0 : 0.0
                            x: hoverPanel.omarchyTab === 2 ? 0 : 20
                            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            enabled: hoverPanel.omarchyTab === 2

                            Row {
                                anchors.fill: parent
                                spacing: 6
                                readonly property real cardW: Math.floor((width - 3 * 6) / 4)

                                // 1. Processor
                                Rectangle {
                                    width: parent.cardW
                                    height: parent.height
                                    radius: 14
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.04)

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 8

                                        Item {
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: 24

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24; radius: 8
                                                color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "developer_board"
                                                    font.pixelSize: 14
                                                    color: hoverPanel.accent
                                                }
                                            }

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 18; radius: 9
                                                width: cpuChipText.implicitWidth + 10
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                                                Text {
                                                    id: cpuChipText
                                                    anchors.centerIn: parent
                                                    text: hoverPanel._vendorOf(hoverPanel.siCpu) !== "" ? hoverPanel._vendorOf(hoverPanel.siCpu) : "CPU"
                                                    font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                                                    color: hoverPanel.accent
                                                }
                                            }
                                        }

                                        Column {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: 1

                                            Text {
                                                text: "Processor"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                                            }
                                            Text {
                                                width: parent.width
                                                text: hoverPanel.siCpu !== "" ? hoverPanel.cpuModel(hoverPanel.siCpu) : "AMD Ryzen"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                                                color: hoverPanel.root.ink
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // 2. Memory
                                Rectangle {
                                    width: parent.cardW
                                    height: parent.height
                                    radius: 14
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.04)

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 8

                                        Item {
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: 24

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24; radius: 8
                                                color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "memory"
                                                    font.pixelSize: 14
                                                    color: hoverPanel.accent
                                                }
                                            }

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 18; radius: 9
                                                width: ramChipText.implicitWidth + 10
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                                                Text {
                                                    id: ramChipText
                                                    anchors.centerIn: parent
                                                    text: "RAM"
                                                    font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                                                    color: hoverPanel.accent
                                                }
                                            }
                                        }

                                        Column {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: 1

                                            Text {
                                                text: "Memory"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                                            }
                                            Text {
                                                width: parent.width
                                                text: hoverPanel.siRam !== "" ? hoverPanel.siRam : "16 GB"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                                                color: hoverPanel.root.ink
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // 3. Graphics
                                Rectangle {
                                    width: parent.cardW
                                    height: parent.height
                                    radius: 14
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.04)

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 8

                                        Item {
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: 24

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24; radius: 8
                                                color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "videogame_asset"
                                                    font.pixelSize: 14
                                                    color: hoverPanel.accent
                                                }
                                            }

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 18; radius: 9
                                                width: Math.min(60, gpuChipText.implicitWidth + 10)
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                                                Text {
                                                    id: gpuChipText
                                                    anchors.centerIn: parent
                                                    width: Math.min(implicitWidth, parent.width - 6)
                                                    elide: Text.ElideRight
                                                    text: hoverPanel.gpuChip(hoverPanel.siGpu) !== "" ? hoverPanel.gpuChip(hoverPanel.siGpu) : "GPU"
                                                    font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                                                    color: hoverPanel.accent
                                                }
                                            }
                                        }

                                        Column {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: 1

                                            Text {
                                                text: "Graphics"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                                            }
                                            Text {
                                                width: parent.width
                                                text: hoverPanel.siGpu !== "" ? hoverPanel.gpuModel(hoverPanel.siGpu) : "Graphics"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                                                color: hoverPanel.root.ink
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }

                                // 4. Display
                                Rectangle {
                                    width: parent.cardW
                                    height: parent.height
                                    radius: 14
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                                    border.width: 1
                                    border.color: Qt.rgba(255, 255, 255, 0.04)

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins: 8

                                        Item {
                                            anchors.top: parent.top
                                            width: parent.width
                                            height: 24

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 24; height: 24; radius: 8
                                                color: Qt.rgba(hoverPanel.accent.r, hoverPanel.accent.g, hoverPanel.accent.b, 0.20)
                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "desktop_windows"
                                                    font.pixelSize: 14
                                                    color: hoverPanel.accent
                                                }
                                            }

                                            Rectangle {
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                height: 18; radius: 9
                                                width: Math.min(64, dispChipText.implicitWidth + 10)
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08)
                                                Text {
                                                    id: dispChipText
                                                    anchors.centerIn: parent
                                                    width: Math.min(implicitWidth, parent.width - 6)
                                                    elide: Text.ElideRight
                                                    text: hoverPanel.displayChip(hoverPanel.siDisplay) !== "" ? hoverPanel.displayChip(hoverPanel.siDisplay) : "Display"
                                                    font.family: hoverPanel.root.barFont; font.pixelSize: 8; font.weight: Font.Bold
                                                    color: hoverPanel.accent
                                                }
                                            }
                                        }

                                        Column {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            spacing: 1

                                            Text {
                                                text: "Display"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 9; font.weight: Font.Medium
                                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                                            }
                                            Text {
                                                width: parent.width
                                                text: hoverPanel.siDisplay !== "" ? hoverPanel.displayModel(hoverPanel.siDisplay) : "1920 × 1080"
                                                font.family: hoverPanel.root.barFont; font.pixelSize: 11; font.weight: Font.Bold
                                                color: hoverPanel.root.ink
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Dedicated Full-Height Heatmap View (no headers, no tab switcher, floating close) ──
                Item {
                    id: heatmapFullView
                    anchors.fill: parent
                    visible: hoverPanel.omarchyTab === 1

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(255, 255, 255, 0.04)
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            text: "Fetching heatmap..."
                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                            font.family: hoverPanel.root.barFont
                            font.pixelSize: 11
                            visible: hoverPanel.ghRefreshing && ghImg.status !== Image.Ready
                        }

                        Image {
                            id: ghImg
                            anchors.fill: parent
                            anchors.margins: 4
                            source: hoverPanel.ghSvgSource
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            visible: hoverPanel.ghSvgSource !== ""
                        }

                        // Floating action buttons on top right
                        Row {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            spacing: 6
                            z: 10

                            // Refresh button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: hmRefMa.containsMouse
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.20)
                                    : Qt.rgba(hoverPanel.root.paper.r, hoverPanel.root.paper.g, hoverPanel.root.paper.b, 0.65)

                                IconText {
                                    anchors.centerIn: parent
                                    text: "refresh"
                                    color: hmRefMa.containsMouse ? hoverPanel.accent : hoverPanel.root.ink
                                    font.pixelSize: 13
                                    opacity: hoverPanel.ghRefreshing ? 0.6 : 1.0

                                    RotationAnimation on rotation {
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 800
                                        running: hoverPanel.ghRefreshing
                                    }
                                }

                                MouseArea {
                                    id: hmRefMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !hoverPanel.ghRefreshing
                                    onClicked: {
                                        hoverPanel.ghRefreshing = true
                                        Quickshell.execDetached(["rm", "-f", Quickshell.env("HOME") + "/.cache/quickshell_ghchart_raw.svg"])
                                        fetchHeatmapProc.running = true
                                    }
                                }
                            }

                            // Close button (returns back to Options)
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: hmCloseMa.containsMouse
                                    ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.20)
                                    : Qt.rgba(hoverPanel.root.paper.r, hoverPanel.root.paper.g, hoverPanel.root.paper.b, 0.65)

                                IconText {
                                    anchors.centerIn: parent
                                    text: "close"
                                    font.pixelSize: 13
                                    color: hoverPanel.root.ink
                                }

                                MouseArea {
                                    id: hmCloseMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: hoverPanel.omarchyTab = 0
                                }
                            }
                        }
                    }
                }
            } // end omarchyView
            } // end topContainer

            // Bottom Row: Omarchy Control Button + Workspace Indicator Strip
            Row {
                width: parent.width
                height: 28
                spacing: 6

                // Omarchy Control Center Button (toggles Omarchy Controls view)
                Rectangle {
                    id: omarchyControlBtn
                    width: 28
                    height: 28
                    radius: 14
                    color: omarchyBtnHov.hovered
                        ? (hoverPanel.omarchyMenuOpen
                            ? hoverPanel.accent
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14))
                        : (hoverPanel.omarchyMenuOpen
                            ? hoverPanel.accent
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.07))
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.04)

                    scale: omarchyBtnMa.pressed ? 0.92 : (omarchyBtnHov.hovered ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: omarchyBtnHov }

                    Text {
                        anchors.centerIn: parent
                        text: hoverPanel.root.launcherLogoIconGlyph(hoverPanel.root.launcherLogoIcon)
                        font.family: hoverPanel.root.launcherLogoIconFont(hoverPanel.root.launcherLogoIcon)
                        font.pixelSize: hoverPanel.root.launcherLogoIconSize(hoverPanel.root.launcherLogoIcon)
                        color: hoverPanel.omarchyMenuOpen ? hoverPanel.root.paper : hoverPanel.root.ink
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
                    width: parent.width - omarchyControlBtn.width - parent.spacing
                    height: 28
                    radius: 14
                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(255, 255, 255, 0.03)

                    // Workspace row with wider animated active pill
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
                        if (isFoc) return 34
                        return wsHasWindows(id) ? 22 : 16
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

                    // Sliding Active Pill (wider animated pill for the active workspace)
                    Rectangle {
                        id: slidingPill
                        width: 34
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
                        spacing: 4

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
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12)
                                }

                                // Dot ONLY for workspaces with NO windows (and not focused)
                                Rectangle {
                                    visible: !isFocused && !hasWindows
                                    anchors.centerIn: parent
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: wsHov.hovered ? hoverPanel.root.ink : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.40)
                                }

                                // Number shown for focused AND for workspaces with windows!
                                Text {
                                    visible: isFocused || hasWindows
                                    anchors.centerIn: parent
                                    text: String(wsId)
                                    font.family: hoverPanel.root.barFont
                                    font.pixelSize: 10
                                    font.weight: isFocused ? Font.Bold : Font.Medium
                                    color: isFocused ? hoverPanel.root.paper : hoverPanel.root.ink
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
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // RIGHT CARD: Media Player with Everything Vertically Arranged
    // ─────────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: rightMediaCard
        x: hoverPanel.width - width - 8
        y: 6
        width: 156
        height: 144
        radius: 18
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
            spacing: 4

            // Large Squircle Album Art
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 52
                height: 52
                radius: 14
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.12)
                border.width: 0
                clip: true

                Image {
                    anchors.fill: parent
                    source: mediaCardArt.source
                    sourceSize: Qt.size(104, 104)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready && source != ""
                }

                IconText {
                    anchors.centerIn: parent
                    visible: mediaCardArt.source == ""
                    text: "music_note"
                    font.pixelSize: 24
                    color: rightMediaCard.artColor
                }
            }

            // Track Title
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: rightMediaCard.hasMedia ? hoverPanel.barSlot.formatTitleCase(rightMediaCard.trackTitle) : "Media Player"
                font.family: hoverPanel.root.barFont
                font.pixelSize: 11
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
                font.pixelSize: 10
                font.weight: Font.Medium
                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.65)
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                width: parent.width - 8
            }

            // Playback Controls Row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                topPadding: 1

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
}

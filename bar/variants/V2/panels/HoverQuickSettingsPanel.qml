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

    anchors.fill: parent

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
            if (!nightProc.running) nightProc.running = true
            if (!stProc.running) stProc.running = true
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

    // Night Light detection & toggle
    property int nightMode: 0
    Process {
        id: nightProc
        running: hoverPanel.visible
        command: ["bash", "-c", "pgrep -x hyprsunset > /dev/null && echo 'on' || echo 'off'"]
        stdout: StdioCollector {
            onStreamFinished: {
                hoverPanel.nightMode = this.text.trim() === "on" ? 1 : 0
            }
        }
    }

    function toggleNightMode() {
        if (nightMode === 0) {
            nightMode = 1
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; exec hyprsunset -t 4500"])
        } else {
            nightMode = 0
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset"])
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
        height: hoverPanel.height - 12
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
        height: hoverPanel.height - 12

        Column {
            anchors.fill: parent
            spacing: 6

            // Top Row: 2x2 Big Squircle Buttons + Brightness Card + Sound Card
            Row {
                width: parent.width
                height: parent.height - 34
                spacing: 8

                // 2x2 Grid of Big Squircle Toggle Buttons
                Grid {
                    id: toggleGrid
                    columns: 2
                    spacing: 6
                    width: 104
                    height: parent.height

                    // Button 1: Night Light Toggle
                    Rectangle {
                        width: 49
                        height: Math.floor((toggleGrid.height - toggleGrid.spacing) / 2)
                        radius: 14
                        color: hoverPanel.nightMode > 0
                            ? (btn1Hov.hovered ? "#FFBE5C" : "#E6A740")
                            : (btn1Hov.hovered
                                ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.16)
                                : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.08))
                        border.width: 1
                        border.color: hoverPanel.nightMode > 0 ? "transparent" : Qt.rgba(255, 255, 255, 0.04)
                        scale: btn1Hov.hovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        IconText {
                            anchors.centerIn: parent
                            text: "nightlight_round"
                            font.pixelSize: 22
                            color: hoverPanel.nightMode > 0 ? "#142614" : hoverPanel.root.ink
                        }

                        HoverHandler { id: btn1Hov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: hoverPanel.toggleNightMode()
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
                            onClicked: Quickshell.execDetached(["hyprlock"])
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
                                text: hoverPanel.wifiConnected ? "wifi" : "wifi_off"
                                font.pixelSize: 19
                                color: hoverPanel.wifiConnected ? hoverPanel.root.paper : hoverPanel.root.ink
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Wi-Fi"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: hoverPanel.wifiConnected ? hoverPanel.root.paper : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.6)
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

                // Screentime Card (replacing Brightness, bottom-docked capsule)
                Rectangle {
                    id: screentimeCard
                    width: Math.floor((parent.width - toggleGrid.width - 16) / 2)
                    height: parent.height
                    radius: 16
                    clip: true
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
                        anchors.topMargin: 8
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

                    // Interactive bottom strip spanning the full width
                    Rectangle {
                        id: stCapsule
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 32
                        bottomLeftRadius: 16
                        bottomRightRadius: 16
                        color: stMa.containsMouse
                            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14)
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.04)
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: "Today"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: hoverPanel.root.ink
                            }

                            Text {
                                text: "||"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                            }

                            IconText {
                                text: "hourglass_top"
                                font.pixelSize: 13
                                color: hoverPanel.accent
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

                // Sound Card (bottom-docked capsule)
                Rectangle {
                    id: soundCard
                    width: Math.floor((parent.width - toggleGrid.width - 16) / 2)
                    height: parent.height
                    radius: 16
                    clip: true
                    color: sndCardHov.hovered
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
                            hoverPanel.root.dashboardDetail = "volume"
                        }
                    }

                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        spacing: 2

                        Text {
                            text: "Sound"
                            font.family: hoverPanel.root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.50)
                        }

                        Row {
                            spacing: 4
                            width: parent.width

                            Text {
                                text: barAudioShared.muted ? "Muted" : ((barAudioShared.sink && barAudioShared.sink.description) ? barAudioShared.sink.description : "Speakers")
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: hoverPanel.root.ink
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width - 20)
                            }

                            IconText {
                                text: "bluetooth"
                                font.pixelSize: 13
                                color: "#4ADE80"
                                visible: (barAudioShared.sink && barAudioShared.sink.description && barAudioShared.sink.description.toLowerCase().indexOf("blue") !== -1)
                            }
                        }
                    }

                    // Interactive bottom strip spanning the full width
                    Rectangle {
                        id: sndCapsule
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 32
                        bottomLeftRadius: 16
                        bottomRightRadius: 16
                        color: sndMa.containsMouse
                            ? Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.14)
                            : Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.09)

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Qt.rgba(255, 255, 255, 0.04)
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: barAudioShared.muted ? "0%" : (barAudioShared.volume + "%")
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: hoverPanel.root.ink
                            }

                            Text {
                                text: "||"
                                font.family: hoverPanel.root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: Qt.rgba(hoverPanel.root.ink.r, hoverPanel.root.ink.g, hoverPanel.root.ink.b, 0.35)
                            }

                            IconText {
                                text: barAudioShared.muted ? "volume_off" : (barAudioShared.volume > 50 ? "volume_up" : "volume_down")
                                font.pixelSize: 14
                                color: hoverPanel.accent
                            }
                        }

                        WheelHandler {
                            onWheel: (event) => {
                                if (event.angleDelta.y > 0) hoverPanel.stepVolume(5)
                                else if (event.angleDelta.y < 0) hoverPanel.stepVolume(-5)
                            }
                        }

                        MouseArea {
                            id: sndMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: hoverPanel.toggleMute()
                        }
                    }

                    HoverHandler { id: sndCardHov }
                }
            }

            // Bottom Row: Workspace Indicator Strip
            Rectangle {
                width: parent.width
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

    // ─────────────────────────────────────────────────────────────────────────────
    // RIGHT CARD: Media Player with Everything Vertically Arranged
    // ─────────────────────────────────────────────────────────────────────────────
    Rectangle {
        id: rightMediaCard
        x: hoverPanel.width - width - 8
        y: 6
        width: 156
        height: hoverPanel.height - 12
        radius: 18

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

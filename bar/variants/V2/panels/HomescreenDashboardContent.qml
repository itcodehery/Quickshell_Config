import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQml.Models
import "../modules"

Item {
    id: dashboardContent
    anchors.fill: parent
    focus: true
    onVisibleChanged: if (visible) forceActiveFocus()
    Component.onCompleted: forceActiveFocus()

    readonly property var detailOrder: ["", "wifi", "bluetooth", "cpu", "memory", "battery", "screentime"]

    function selectCategoryByIndex(idx) {
        if (idx < 0) idx = 0
        if (idx >= detailOrder.length) idx = detailOrder.length - 1
        let cat = detailOrder[idx]
        dashboardContent.activeDetailView = cat
        if (root) root.dashboardDetail = cat

        // Keep left-hand tilesPager in sync so active tile is visible
        if (cat === "battery" || cat === "screentime") {
            pageDown()
        } else if (cat === "wifi" || cat === "bluetooth" || cat === "cpu" || cat === "memory" || cat === "") {
            pageUp()
        }
    }

    function jumpNextCategory() {
        let curIdx = detailOrder.indexOf(dashboardContent.activeDetailView)
        let nextIdx = (curIdx + 1) % detailOrder.length
        selectCategoryByIndex(nextIdx)
    }

    function jumpPrevCategory() {
        let curIdx = detailOrder.indexOf(dashboardContent.activeDetailView)
        if (curIdx <= 0) curIdx = detailOrder.length
        let prevIdx = curIdx - 1
        selectCategoryByIndex(prevIdx)
    }

    function nextOption() {
        // 1. Check if current active detail section has an internal sub-option to step forward into
        if (dashboardContent.activeDetailView === "bluetooth" && btDetailSection && btDetailSection.nextSubOption && btDetailSection.nextSubOption()) {
            return
        }
        if (dashboardContent.activeDetailView === "battery" && batDetailSection && batDetailSection.nextSubOption && batDetailSection.nextSubOption()) {
            return
        }
        if (dashboardContent.activeDetailView === "screentime" && stDetailSection && stDetailSection.nextSubOption && stDetailSection.nextSubOption()) {
            return
        }
        // 2. Otherwise advance to next category
        jumpNextCategory()
    }

    function prevOption() {
        // 1. Check if current active detail section has an internal sub-option to step backward into
        if (dashboardContent.activeDetailView === "screentime" && stDetailSection && stDetailSection.prevSubOption && stDetailSection.prevSubOption()) {
            return
        }
        if (dashboardContent.activeDetailView === "battery" && batDetailSection && batDetailSection.prevSubOption && batDetailSection.prevSubOption()) {
            return
        }
        if (dashboardContent.activeDetailView === "bluetooth" && btDetailSection && btDetailSection.prevSubOption && btDetailSection.prevSubOption()) {
            return
        }
        if (dashboardContent.activeDetailView === "wifi" && wifiDetailSection && wifiDetailSection.speedTestActive) {
            wifiDetailSection.exitSpeedTest()
            return
        }
        // 2. Otherwise move to previous category
        jumpPrevCategory()
    }

    Keys.onUpPressed: pageUp()
    Keys.onDownPressed: pageDown()
    Keys.onLeftPressed: prevOption()
    Keys.onRightPressed: nextOption()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_K) {
            pageUp()
            event.accepted = true
        } else if (event.key === Qt.Key_J) {
            pageDown()
            event.accepted = true
        } else if (event.key === Qt.Key_H) {
            if (event.modifiers & Qt.ShiftModifier) {
                jumpPrevCategory()
            } else {
                prevOption()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            if (event.modifiers & Qt.ShiftModifier) {
                jumpNextCategory()
            } else {
                nextOption()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Tab) {
            if (panel && panel.searchOpen) {
                panel.toggleSearchEngine()
            } else if (event.modifiers & Qt.ShiftModifier) {
                jumpPrevCategory()
            } else {
                jumpNextCategory()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backtab) {
            jumpPrevCategory()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (dashboardContent.activeDetailView !== "") {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else if (panel) {
                panel.expanded = false
            }
            event.accepted = true
        } else if (event.key === Qt.Key_S) {
            if (panel) {
                panel.toggleSearch()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_Return) {
            if (dashboardContent.activeDetailView === "wifi" && wifiDetailSection) {
                wifiDetailSection.startSpeedTestWithSweep()
                event.accepted = true
            } else if (dashboardContent.activeDetailView === "bluetooth" && btDetailSection) {
                btDetailSection.doTogglePower()
                event.accepted = true
            }
        }
    }
    
    NumberAnimation {
        id: smoothScrollAnim
        target: tilesPager
        property: "contentY"
        duration: 250
        easing.type: Easing.OutCubic
    }
    
    function pageUp() {
        let h = tilesPager.height + tilesPager.spacing
        let idx = Math.round(tilesPager.contentY / h)
        if (idx > 0) {
            smoothScrollAnim.stop()
            smoothScrollAnim.to = (idx - 1) * h
            smoothScrollAnim.start()
        }
    }
    
    function pageDown() {
        let h = tilesPager.height + tilesPager.spacing
        let idx = Math.round(tilesPager.contentY / h)
        if (idx < tilesPager.count - 1) {
            smoothScrollAnim.stop()
            smoothScrollAnim.to = (idx + 1) * h
            smoothScrollAnim.start()
        }
    }

    function getAppIcon(cls) {
        if (!cls) return ""
        var lower = cls.toLowerCase()
        if (lower.indexOf("file://") === 0) return lower
        if (lower.indexOf("/") === 0) return "file://" + lower
        if (lower === "zen" || lower === "zen-alpha" || lower.indexOf("zen") >= 0) {
            return "file:///usr/share/icons/hicolor/128x128/apps/zen-browser.png"
        }
        if (lower === "kitty") {
            return "file:///usr/share/icons/hicolor/256x256/apps/kitty.png"
        }
        if (lower.indexOf("code") >= 0 || lower === "vscode") {
            var p = Quickshell.iconPath("code", "com.visualstudio.code")
            if (p) return p
        }
        if (lower.indexOf("whatsapp") >= 0) {
            var p = Quickshell.iconPath("whatsapp", "whatsapp-for-linux")
            if (p) return p
        }
        if (lower.indexOf("azahar") >= 0) {
            return "file:///usr/share/icons/hicolor/scalable/apps/org.azahar_emu.Azahar.svg"
        }
        if (lower.indexOf("chrome") >= 0 || lower.indexOf("chromium") >= 0) {
            var p = Quickshell.iconPath("google-chrome", "chrome")
            if (p) return p
        }
        if (lower.indexOf("firefox") >= 0) {
            var p = Quickshell.iconPath("firefox", "firefox-esr")
            if (p) return p
        }
        if (lower.indexOf("discord") >= 0) {
            var p = Quickshell.iconPath("discord", "discord")
            if (p) return p
        }
        if (lower.indexOf("spotify") >= 0) {
            var p = Quickshell.iconPath("spotify", "spotify-client")
            if (p) return p
        }
        if (lower.indexOf("steam") >= 0) {
            var p = Quickshell.iconPath("steam", "steam")
            if (p) return p
        }
        if (lower.indexOf("typora") >= 0) {
            var p = Quickshell.iconPath("typora", "accessories-text-editor")
            if (p) return p
        }
        if (lower.indexOf("thunar") >= 0 || lower.indexOf("nautilus") >= 0 || lower.indexOf("dolphin") >= 0) {
            var p = Quickshell.iconPath("system-file-manager", "folder")
            if (p) return p
        }
        var direct = Quickshell.iconPath(lower, "")
        if (direct) return direct
        var clean = lower.replace(".desktop", "").split("-")[0]
        var pClean = Quickshell.iconPath(clean, "")
        if (pClean) return pClean
        return Quickshell.iconPath("application-x-executable", "")
    }

    function getAppDisplayName(cls, title) {
        if (!cls) return title || "App"
        var lower = cls.toLowerCase()
        if (lower === "zen" || lower.indexOf("zen") >= 0) return "Zen Browser"
        if (lower === "kitty") return "Kitty"
        if (lower.indexOf("code") >= 0) return "VS Code"
        if (lower.indexOf("discord") >= 0) return "Discord"
        if (lower.indexOf("spotify") >= 0) return "Spotify"
        if (lower.indexOf("steam") >= 0) return "Steam"
        if (lower.indexOf("typora") >= 0) return "Typora"
        if (lower.indexOf("thunar") >= 0) return "Thunar"
        return cls.charAt(0).toUpperCase() + cls.slice(1)
    }

    property var root
    property var panel
    property string activeDetailView: root && root.dashboardDetail ? root.dashboardDetail : ""

    Connections {
        target: root || null
        function onDashboardDetailChanged() {
            if (root && dashboardContent.activeDetailView !== root.dashboardDetail) {
                dashboardContent.activeDetailView = root.dashboardDetail || ""
            }
        }
    }

    onActiveDetailViewChanged: {
        if (root && root.dashboardDetail !== activeDetailView) {
            root.dashboardDetail = activeDetailView
        }
    }

    AudioData { id: audioData }

    property int currentBrightness: 50
    Process {
        running: true
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }
    Timer {
        interval: 3000; repeat: true; running: panel.expanded
        onTriggered: { briUpdater.running = false; briUpdater.running = true }
    }
    Process {
        id: briUpdater
        command: ["bash", "-c", "brightnessctl -m | cut -d',' -f4 | tr -d '%'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(this.text)
                if (!isNaN(v)) dashboardContent.currentBrightness = v
            }
        }
    }

    property string currentWifiName: "Wi-Fi"
    property string currentBtName: "Bluetooth"

    Timer {
        id: statusTimer
        interval: 3000; repeat: true; running: panel.expanded; triggeredOnStart: true
        onTriggered: {
            wifiUpdater.running = false; wifiUpdater.running = true
            btUpdater.running = false; btUpdater.running = true
        }
    }
    
    Process {
        id: wifiUpdater
        command: ["bash", "-c", "nmcli -t -c no -f TYPE,NAME connection show --active | grep 802-11-wireless | cut -d':' -f2- | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = this.text.trim()
                if (s !== "" && dashboardContent.currentWifiName === "Searching...") {
                    statusTimer.interval = 3000 // reset back
                }
                dashboardContent.currentWifiName = s === "" ? "Wi-Fi" : s
            }
        }
    }
    
    Process {
        id: btUpdater
        command: ["bash", "-c", "bluetoothctl devices Connected | head -n1 | cut -d ' ' -f 3-"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = this.text.trim()
                if (s !== "" && dashboardContent.currentBtName === "Searching...") {
                    statusTimer.interval = 3000
                }
                dashboardContent.currentBtName = s === "" ? "Bluetooth" : s
            }
        }
    }

    MprisSelect { id: mprisSel }
    MprisArtwork { id: mprisArt; player: mprisSel.player; root: dashboardContent.root }
    
    property string curTitle: mprisSel.player ? (mprisSel.player.trackTitle || "") : ""
    property string curArtist: mprisSel.player ? (mprisSel.player.trackArtist || "") : ""
    property string curArtUrl: mprisArt.source
    
    property real curPos: 0
    property real curLen: 0
    property real _lastRead: -1
    
    function fmtTime(s) {
        if (!s || s <= 0 || isNaN(s)) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec)
    }

    function seekTo(ratio) {
        if (!mprisSel.player || curLen <= 0) return
        var target = Math.max(0, Math.min(1, ratio)) * curLen
        if (typeof mprisSel.player.setPosition === "function") {
            mprisSel.player.setPosition(target)
        } else {
            mprisSel.player.position = target
        }
        curPos = target
    }

    Timer {
        id: posTimer
        interval: 500; repeat: true
        running: mprisSel.active
        triggeredOnStart: true
        onTriggered: {
            if (!mprisSel.player) return
            var p = mprisSel.player.position || 0
            dashboardContent.curLen = mprisSel.player.length || 0
            if (Math.abs(p - dashboardContent._lastRead) > 0.05) {
                dashboardContent.curPos = p
                dashboardContent._lastRead = p
            } else if (mprisSel.playing) {
                dashboardContent.curPos = Math.min(dashboardContent.curLen, dashboardContent.curPos + 0.5)
            }
        }
    }

    Connections {
        target: mprisSel
        function onPlayerChanged() {
            dashboardContent.curPos = 0
            dashboardContent._lastRead = -1
            dashboardContent.curLen = mprisSel.player ? (mprisSel.player.length || 0) : 0
        }
    }
    
    onCurTitleChanged: { if (root && curTitle !== "") root.lastMediaTitle = curTitle }
    onCurArtistChanged: { if (root && curArtist !== "") root.lastMediaArtist = curArtist }
    onCurArtUrlChanged: { if (root && curArtUrl !== "") root.lastMediaArtUrl = curArtUrl }
    
    onRootChanged: {
        if (root) {
            if (mprisSel.player && mprisSel.player.trackTitle) {
                root.lastMediaTitle = mprisSel.player.trackTitle || ""
                root.lastMediaArtist = mprisSel.player.trackArtist || ""
            }
            if (mprisArt.source) root.lastMediaArtUrl = mprisArt.source
        }
    }

    Row {
        anchors.fill: parent
        spacing: 16

        // LEFT COLUMN (40%): Sliders, Tiles & Media Player
        Column {
            width: parent.width * 0.4 - 8
            height: parent.height
            spacing: 16

            // --- SLIDERS ---
            Column {
                width: parent.width
                spacing: 12
                
                // Brightness Container
                Row {
                    width: parent.width
                    spacing: 12
                    
                    // Brightness Slider
                    Rectangle {
                        id: briSlider
                        width: parent.width - 40 - 12
                        height: 40
                        radius: 20
                        color: root.fillIdle
                        
                        property bool sliding: false
                        property int localValue: dashboardContent.currentBrightness
                        
                        Item {
                            id: briFillItem
                            property real val: briSlider.sliding ? briSlider.localValue : dashboardContent.currentBrightness
                            property real gap: val > 85 ? 23 * (100 - val) / 15 : 23
                            property real barOpacity: val > 85 ? (100 - val) / 15 : 1
                            
                            width: Math.max(parent.height, parent.width * (val / 100))
                            height: parent.height
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            
                            // The actual fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width - briFillItem.gap)
                                radius: 10 + (10 * (1 - briFillItem.barOpacity))
                                color: root.seal
                                
                                // fully rounded on the left
                                Rectangle {
                                    width: parent.height
                                    height: parent.height
                                    radius: height / 2
                                    color: root.seal
                                    anchors.left: parent.left
                                }
                            }
                            
                            // The vertical bar with "padding"
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 23 // 10px gap + 3px line + 10px gap
                                height: parent.height
                                color: "transparent"
                                opacity: briFillItem.barOpacity
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: parent.height - 16
                                    radius: 1.5
                                    color: root.seal
                                }
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 12
                            IconText { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: "light_mode"
                                color: root.paper
                                font.pixelSize: 18 
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(briFillItem.val) + "%"
                                color: briFillItem.width > 70 ? root.paper : root.ink
                                font.pixelSize: 13
                                font.family: root.barFont
                                font.weight: Font.DemiBold
                                opacity: briSlider.sliding ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onPressed: { briSlider.sliding = true }
                            onPositionChanged: (mouse) => {
                                if (pressed) briSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                            }
                            onReleased: (mouse) => {
                                briSlider.sliding = false
                                let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                dashboardContent.currentBrightness = pct
                                Quickshell.execDetached(["bash", "-c", "brightnessctl set " + pct + "%"])
                            }
                        }
                    }
                    
                    // Night Light Toggle
                    Rectangle {
                        id: localNightToggle
                        width: 40
                        height: 40
                        radius: 20
                        property bool active: false
                        
                        Process {
                            running: true
                            command: ["bash", "-c", "pgrep -x hyprsunset > /dev/null && echo 'on' || echo 'off'"]
                            stdout: StdioCollector {
                                onStreamFinished: localNightToggle.active = (this.text.trim() === "on")
                            }
                        }
                        
                        color: active ? root.color01 : root.fillIdle
                        IconText { 
                            anchors.centerIn: parent
                            text: "nightlight_round"
                            color: localNightToggle.active ? root.paper : root.ink
                            font.pixelSize: 18
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (localNightToggle.active) {
                                    Quickshell.execDetached(["killall", "hyprsunset"])
                                    localNightToggle.active = false
                                } else {
                                    Quickshell.execDetached(["hyprsunset", "-t", "4000"])
                                    localNightToggle.active = true
                                }
                            }
                        }
                    }
                }

                // Audio Container
                Row {
                    width: parent.width
                    spacing: 12
                    
                    // Audio Slider
                    Rectangle {
                        id: audSlider
                        width: parent.width - 40 - 12
                        height: 40
                        radius: 20
                        color: root.fillIdle
                        
                        property bool sliding: false
                        property int localValue: audioData.volume
                        
                        Item {
                            id: audFillItem
                            property real val: audSlider.sliding ? audSlider.localValue : audioData.volume
                            property real gap: val > 85 ? 23 * (100 - val) / 15 : 23
                            property real barOpacity: val > 85 ? (100 - val) / 15 : 1
                            
                            width: Math.max(parent.height, parent.width * (val / 100))
                            height: parent.height
                            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            
                            // The actual fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Math.max(parent.height, parent.width - audFillItem.gap)
                                radius: 10 + (10 * (1 - audFillItem.barOpacity))
                                color: audioData.muted ? root.fillHover : root.seal
                                
                                // fully rounded on the left
                                Rectangle {
                                    width: parent.height
                                    height: parent.height
                                    radius: height / 2
                                    color: audioData.muted ? root.fillHover : root.seal
                                    anchors.left: parent.left
                                }
                            }
                            
                            // The vertical bar with "padding"
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 23 // 10px gap + 3px line + 10px gap
                                height: parent.height
                                color: "transparent"
                                opacity: audFillItem.barOpacity
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: parent.height - 16
                                    radius: 1.5
                                    color: audioData.muted ? root.fillHover : root.seal
                                }
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 12
                            IconText { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: audioData.muted ? "volume_off" : "volume_up"
                                color: audioData.muted ? root.ink : root.paper
                                font.pixelSize: 18 
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(audFillItem.val) + "%"
                                color: audioData.muted ? root.ink : (audFillItem.width > 70 ? root.paper : root.ink)
                                font.pixelSize: 13
                                font.family: root.barFont
                                font.weight: Font.DemiBold
                                opacity: audSlider.sliding ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onPressed: { audSlider.sliding = true }
                            onPositionChanged: (mouse) => {
                                if (pressed) audSlider.localValue = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                            }
                            onReleased: (mouse) => {
                                audSlider.sliding = false
                                let pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", pct + "%"])
                            }
                        }
                    }
                    
                    // Audio Menu Toggle
                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: root.volVisible ? root.color02 : root.fillIdle
                        
                        IconText { 
                            anchors.centerIn: parent
                            text: "tune"
                            color: root.volVisible ? root.paper : root.ink
                            font.pixelSize: 18
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.volVisible = !root.volVisible
                        }
                    }
                }
            }

            // --- MATERIAL YOU TILES ---
            ListView {
                id: tilesPager
                width: parent.width
                height: 132
                clip: true
                snapMode: ListView.SnapToItem
                orientation: ListView.Vertical
                boundsBehavior: Flickable.StopAtBounds
                spacing: 24
                
                WheelHandler {
                    onWheel: (event) => {
                        if (event.angleDelta.y > 0) {
                            tilesPager.flick(0, 2000)
                        } else if (event.angleDelta.y < 0) {
                            tilesPager.flick(0, -2000)
                        }
                    }
                }
                
                model: ObjectModel {
                    // --- PAGE 1 ---
                    Grid {
                        width: tilesPager.width
                        height: tilesPager.height
                        columns: 2
                        spacing: 12

                        // Wi-Fi Tile
                        Rectangle {
                            id: wifiTile
                            property bool connected: dashboardContent.currentWifiName !== "Wi-Fi"
                            readonly property color fg: connected ? root.paper : root.ink
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: connected
                                ? (wifiMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (wifiMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            scale: (wifiMa.pressed || wifiInnerMa.pressed) ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            
                            border.width: dashboardContent.activeDetailView === "wifi" ? 2 : 0
                            border.color: connected ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            MouseArea {
                                id: wifiMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dashboardContent.activeDetailView === "wifi") {
                                        dashboardContent.activeDetailView = ""
                                        if (root) root.dashboardDetail = ""
                                    } else {
                                        dashboardContent.activeDetailView = "wifi"
                                        if (root) root.dashboardDetail = "wifi"
                                    }
                                }
                            }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                spacing: 12
                                
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 14
                                    color: wifiTile.connected
                                        ? (wifiInnerMa.containsMouse ? Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.28) : Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.18))
                                        : (wifiInnerMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1))
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    
                                    IconText { 
                                        anchors.centerIn: parent
                                        text: "wifi"
                                        fill: wifiTile.connected ? 1 : 0
                                        color: wifiTile.fg
                                        font.pixelSize: 20
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    
                                    MouseArea {
                                        id: wifiInnerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (wifiTile.connected) {
                                                dashboardContent.currentWifiName = "Wi-Fi"
                                            } else {
                                                dashboardContent.currentWifiName = "Searching..."
                                            }
                                            Quickshell.execDetached(["bash", "-c", "nmcli radio wifi | grep -q 'enabled' && nmcli radio wifi off || nmcli radio wifi on"])
                                            statusTimer.interval = 500
                                            statusTimer.restart()
                                        }
                                    }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: "Wi-Fi"
                                        color: wifiTile.fg
                                        font.pixelSize: 13
                                        font.family: root.barFont
                                        font.weight: Font.DemiBold
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Text {
                                        text: dashboardContent.currentWifiName
                                        color: wifiTile.fg
                                        opacity: wifiTile.connected ? 0.75 : 0.6
                                        font.pixelSize: 11
                                        font.family: root.barFont
                                        elide: Text.ElideRight
                                        width: wifiTile.width - 44 - 8 - 12 - 16
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                        }

                        // Bluetooth Tile
                        Rectangle {
                            id: btTile
                            property bool connected: dashboardContent.currentBtName !== "Bluetooth"
                            readonly property color fg: connected ? root.paper : root.ink
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: connected
                                ? (btMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (btMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            scale: (btMa.pressed || btInnerMa.pressed) ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            
                            border.width: dashboardContent.activeDetailView === "bluetooth" ? 2 : 0
                            border.color: connected ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            MouseArea {
                                id: btMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dashboardContent.activeDetailView === "bluetooth") {
                                        dashboardContent.activeDetailView = ""
                                        if (root) root.dashboardDetail = ""
                                    } else {
                                        dashboardContent.activeDetailView = "bluetooth"
                                        if (root) root.dashboardDetail = "bluetooth"
                                    }
                                }
                            }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                spacing: 12
                                
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 14
                                    color: btTile.connected
                                        ? (btInnerMa.containsMouse ? Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.28) : Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.18))
                                        : (btInnerMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1))
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    
                                    IconText { 
                                        anchors.centerIn: parent
                                        text: "bluetooth"
                                        fill: btTile.connected ? 1 : 0
                                        color: btTile.fg
                                        font.pixelSize: 20
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    
                                    MouseArea {
                                        id: btInnerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (btTile.connected) {
                                                dashboardContent.currentBtName = "Bluetooth"
                                            } else {
                                                dashboardContent.currentBtName = "Searching..."
                                            }
                                            Quickshell.execDetached(["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && bluetoothctl power off || bluetoothctl power on"])
                                            statusTimer.interval = 500
                                            statusTimer.restart()
                                        }
                                    }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: "Bluetooth"
                                        color: btTile.fg
                                        font.pixelSize: 13
                                        font.family: root.barFont
                                        font.weight: Font.DemiBold
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Text {
                                        text: dashboardContent.currentBtName
                                        color: btTile.fg
                                        opacity: btTile.connected ? 0.75 : 0.6
                                        font.pixelSize: 11
                                        font.family: root.barFont
                                        elide: Text.ElideRight
                                        width: btTile.width - 44 - 8 - 12 - 16
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                        }

                        // CPU Tile
                        Rectangle {
                            id: cpuTile
                            property bool active: dashboardContent.activeDetailView === "cpu"
                            readonly property color fg: active ? root.paper : root.ink
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active
                                ? (cpuMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (cpuMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            scale: cpuMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            
                            border.width: active ? 2 : 0
                            border.color: active ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                
                                IconText {
                                    text: "memory"
                                    color: cpuTile.fg
                                    font.pixelSize: 20
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: "CPU"
                                        color: cpuTile.fg
                                        font.pixelSize: 13
                                        font.family: root.barFont
                                        font.weight: Font.DemiBold
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Text {
                                        text: root.systemCpuPercent + "%"
                                        color: cpuTile.fg
                                        opacity: cpuTile.active ? 0.8 : 0.6
                                        font.pixelSize: 11
                                        font.family: root.barFont
                                        elide: Text.ElideRight
                                        width: 60
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                            MouseArea {
                                id: cpuMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dashboardContent.activeDetailView === "cpu") {
                                        dashboardContent.activeDetailView = ""
                                        if (root) root.dashboardDetail = ""
                                    } else {
                                        dashboardContent.activeDetailView = "cpu"
                                        if (root) root.dashboardDetail = "cpu"
                                    }
                                }
                            }
                        }

                        // Memory Tile
                        Rectangle {
                            id: memTile
                            property bool active: dashboardContent.activeDetailView === "memory"
                            readonly property color fg: active ? root.paper : root.ink
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active
                                ? (memMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (memMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            scale: memMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            
                            border.width: active ? 2 : 0
                            border.color: active ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                
                                IconText {
                                    text: "dns"
                                    color: memTile.fg
                                    font.pixelSize: 20
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: "Memory"
                                        color: memTile.fg
                                        font.pixelSize: 13
                                        font.family: root.barFont
                                        font.weight: Font.DemiBold
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Text {
                                        text: root.systemMemUsedGiB.toFixed(1) + "/" + root.systemMemTotalGiB.toFixed(0) + "G"
                                        color: memTile.fg
                                        opacity: memTile.active ? 0.8 : 0.6
                                        font.pixelSize: 11
                                        font.family: root.barFont
                                        elide: Text.ElideRight
                                        width: 60
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                            MouseArea {
                                id: memMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dashboardContent.activeDetailView === "memory") {
                                        dashboardContent.activeDetailView = ""
                                        if (root) root.dashboardDetail = ""
                                    } else {
                                        dashboardContent.activeDetailView = "memory"
                                        if (root) root.dashboardDetail = "memory"
                                    }
                                }
                            }
                        }
                    }

                    // --- PAGE 2 ---
                    Grid {
                        width: tilesPager.width
                        height: tilesPager.height
                        columns: 2
                        spacing: 12

                        // DND Tile
                        Rectangle {
                            id: dndTile
                            property bool active: root.notifSilenced
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color04 : root.fillIdle
                            scale: dndMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: dndTile.active ? "notifications_off" : "notifications_active"; color: dndTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "DND"; color: dndTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: dndTile.active ? "Silenced" : "Alerts On"; color: dndTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: dndMa
                                anchors.fill: parent
                                onClicked: {
                                    Quickshell.execDetached(["quickshell", "-p", "/usr/share/omarchy/shell", "ipc", "call", "notifications", "toggleDnd"])
                                    root.notifSilenced = !root.notifSilenced
                                }
                            }
                        }

                        // Eye Comfort Tile
                        Rectangle {
                            id: nightTile
                            property bool active: false
                            
                            Process {
                                running: true
                                command: ["bash", "-c", "pgrep -x hyprsunset > /dev/null && echo 'on' || echo 'off'"]
                                stdout: StdioCollector {
                                    onStreamFinished: nightTile.active = (this.text.trim() === "on")
                                }
                            }

                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color01 : root.fillIdle
                            scale: nightMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: "nightlight_round"; color: nightTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Night Light"; color: nightTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: nightTile.active ? "Warm" : "Off"; color: nightTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: nightMa
                                anchors.fill: parent
                                onClicked: {
                                    if (nightTile.active) {
                                        Quickshell.execDetached(["killall", "hyprsunset"])
                                        nightTile.active = false
                                    } else {
                                        Quickshell.execDetached(["hyprsunset", "-t", "4000"])
                                        nightTile.active = true
                                    }
                                }
                            }
                        }

                        // Battery & Power Tile
                        Rectangle {
                            id: powerTile
                            property bool active: dashboardContent.activeDetailView === "battery"
                            readonly property color fg: active ? root.paper : root.ink
                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active
                                ? (powerMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (powerMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            scale: powerMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            border.width: active ? 2 : 0
                            border.color: active ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText {
                                    text: "bolt"
                                    color: powerTile.fg
                                    font.pixelSize: 20
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        text: "Battery"
                                        color: powerTile.fg
                                        font.pixelSize: 13
                                        font.family: root.barFont
                                        font.weight: Font.DemiBold
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Text {
                                        text: "Power & Health"
                                        color: powerTile.fg
                                        opacity: powerTile.active ? 0.8 : 0.6
                                        font.pixelSize: 11
                                        font.family: root.barFont
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                            MouseArea {
                                id: powerMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dashboardContent.activeDetailView === "battery") {
                                        dashboardContent.activeDetailView = ""
                                        if (root) root.dashboardDetail = ""
                                    } else {
                                        dashboardContent.activeDetailView = "battery"
                                        if (root) root.dashboardDetail = "battery"
                                    }
                                }
                            }
                        }

                        // Caffeine Tile
                        Rectangle {
                            id: coffeeTile
                            property bool active: false
                            
                            Process {
                                running: true
                                command: ["bash", "-c", "pgrep -f 'why=caffeine' > /dev/null && echo 'on' || echo 'off'"]
                                stdout: StdioCollector {
                                    onStreamFinished: coffeeTile.active = (this.text.trim() === "on")
                                }
                            }

                            width: (parent.width - 12) / 2
                            height: 60
                            radius: 30
                            color: active ? root.color03 : root.fillIdle
                            scale: coffeeMa.pressed ? 0.92 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                spacing: 12
                                IconText { text: "local_cafe"; color: coffeeTile.active ? root.paper : root.ink; font.pixelSize: 20; Behavior on color { ColorAnimation { duration: 200 } } }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: "Caffeine"; color: coffeeTile.active ? root.paper : root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: 200 } } }
                                    Text { text: coffeeTile.active ? "Awake" : "Sleepy"; color: coffeeTile.active ? root.paper : root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                            MouseArea {
                                id: coffeeMa
                                anchors.fill: parent
                                onClicked: {
                                    if (coffeeTile.active) {
                                        Quickshell.execDetached(["pkill", "-f", "why=caffeine"])
                                        coffeeTile.active = false
                                    } else {
                                        Quickshell.execDetached(["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=caffeine", "sleep", "infinity"])
                                        coffeeTile.active = true
                                    }
                                }
                            }
                        }
                    }

                    // --- PAGE 3 ---
                    Item {
                        width: tilesPager.width
                        height: tilesPager.height
                        
                        // Big Pill (Temp)
                        Rectangle {
                            id: tempTile
                            x: 0
                            y: 0
                            width: (tilesPager.width - 12) / 2
                            height: 132
                            radius: 26
                            clip: true
                            
                            property int currentTemp: 45

                            readonly property color tempColor: {
                                if (currentTemp < 52) return "#22d3ee" // Cyan
                                if (currentTemp < 72) return "#fbbf24" // Amber
                                return "#f87171" // Coral red
                            }
                            
                            color: root.fillIdle
                            scale: tempMa.pressed ? 0.94 : (tempMa.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                            // Subtle background thermal tint
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: Qt.rgba(tempTile.tempColor.r, tempTile.tempColor.g, tempTile.tempColor.b, 0.10)
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }
                            
                            Process {
                                running: true
                                command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let t = parseInt(this.text.trim())
                                        if (!isNaN(t)) {
                                            tempTile.currentTemp = Math.round(t / 1000)
                                        }
                                    }
                                }
                            }
                            
                            Process {
                                id: tempUpdater
                                command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let t = parseInt(this.text.trim())
                                        if (!isNaN(t)) {
                                            tempTile.currentTemp = Math.round(t / 1000)
                                        }
                                    }
                                }
                            }
                            
                            Timer {
                                interval: 2500; repeat: true; running: panel.expanded
                                onTriggered: { tempUpdater.running = false; tempUpdater.running = true }
                            }
                            
                            Item {
                                anchors.fill: parent
                                anchors.margins: 14

                                // Top row: Icon Badge + Category Label
                                Row {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 32
                                    spacing: 8

                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        color: Qt.rgba(tempTile.tempColor.r, tempTile.tempColor.g, tempTile.tempColor.b, 0.22)
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on color { ColorAnimation { duration: 300 } }

                                        IconText {
                                            anchors.centerIn: parent
                                            text: "thermostat"
                                            color: tempTile.tempColor
                                            font.pixelSize: 18
                                            Behavior on color { ColorAnimation { duration: 300 } }
                                        }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text {
                                            text: "CPU TEMP"
                                            color: root.ink
                                            opacity: 0.6
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.6
                                        }

                                        Text {
                                            text: tempTile.currentTemp < 52 ? "Optimal" : (tempTile.currentTemp < 72 ? "Normal" : "High")
                                            color: tempTile.tempColor
                                            font.family: root.barFont
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }

                                // Bottom readout
                                Item {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 36

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tempTile.currentTemp + "°C"
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 28
                                        font.weight: Font.Bold
                                    }

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 20
                                        radius: 10
                                        color: Qt.rgba(tempTile.tempColor.r, tempTile.tempColor.g, tempTile.tempColor.b, 0.20)
                                        border.color: Qt.rgba(tempTile.tempColor.r, tempTile.tempColor.g, tempTile.tempColor.b, 0.40)
                                        border.width: 1
                                        width: statusText.implicitWidth + 16

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Rectangle {
                                                width: 5; height: 5; radius: 2.5
                                                color: tempTile.tempColor
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                id: statusText
                                                text: tempTile.currentTemp < 52 ? "COOL" : (tempTile.currentTemp < 72 ? "WARM" : "HOT")
                                                color: tempTile.tempColor
                                                font.family: root.barFont
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: tempMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Quickshell.execDetached(["btop"])
                            }
                        }
                        
                        // Two small pills
                        Column {
                            x: (tilesPager.width + 12) / 2
                            y: 0
                            width: (tilesPager.width - 12) / 2
                            height: 132
                            spacing: 12
                            
                            // Screentime Tile
                            Rectangle {
                                id: screentimeTile
                                property bool active: dashboardContent.activeDetailView === "screentime"
                                readonly property color fg: active ? root.paper : root.ink
                                width: parent.width
                                height: 60
                                radius: 30
                                color: active
                                    ? (stMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (stMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }
                                scale: stMa.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12
                                    
                                    IconText {
                                        text: "hourglass_empty"
                                        color: screentimeTile.fg
                                        font.pixelSize: 20
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text {
                                            text: "Screen Time"
                                            color: screentimeTile.fg
                                            font.pixelSize: 13
                                            font.family: root.barFont
                                            font.weight: Font.DemiBold
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                        Text {
                                            text: "Usage & Trends"
                                            color: screentimeTile.fg
                                            opacity: screentimeTile.active ? 0.8 : 0.6
                                            font.pixelSize: 11
                                            font.family: root.barFont
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: stMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (dashboardContent.activeDetailView === "screentime") {
                                            dashboardContent.activeDetailView = ""
                                            if (root) root.dashboardDetail = ""
                                        } else {
                                            dashboardContent.activeDetailView = "screentime"
                                            if (root) root.dashboardDetail = "screentime"
                                        }
                                    }
                                }
                            }
                            
                            // Extra 2
                            Rectangle {
                                id: storageTile
                                width: parent.width
                                height: 60
                                radius: 30
                                color: root.fillIdle
                                scale: storageMa.pressed ? 0.92 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                
                                Process {
                                    running: true
                                    command: ["bash", "-c", "df -h / | awk 'NR==2{print $4}'"]
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            storageVal.text = this.text.trim() + " Free"
                                        }
                                    }
                                }
                                
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    spacing: 12
                                    
                                    IconText { text: "storage"; color: root.ink; font.pixelSize: 20 }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "Disk Space"; color: root.ink; font.pixelSize: 13; font.family: root.barFont; font.weight: Font.DemiBold }
                                        Text { id: storageVal; text: "Loading..."; color: root.ink; opacity: 0.6; font.pixelSize: 11; font.family: root.barFont; elide: Text.ElideRight; width: 60 }
                                    }
                                }
                                
                                MouseArea {
                                    id: storageMa
                                    anchors.fill: parent
                                    onClicked: {
                                        Quickshell.execDetached(["xdg-open", "/"])
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // --- MATERIAL YOU MEDIA PLAYER ---
            Rectangle {
                id: mediaCard
                width: parent.width
                height: Math.max(140, parent.height - 256)
                radius: 24
                color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r * 0.45, mediaCard.domCol.g * 0.45, mediaCard.domCol.b * 0.45, 0.5) : root.fillIdle
                border.color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.4) : root.islandBorder
                border.width: 1

                readonly property bool hasDominant: mprisArt.dominantColor && String(mprisArt.dominantColor) !== "#00000000" && String(mprisArt.dominantColor) !== "transparent"
                readonly property color domCol: hasDominant ? mprisArt.dominantColor : root.seal
                // Clean pastel / paper color for the pill play button matching Android Material You
                readonly property color pillBg: {
                    if (!hasDominant) return root.paper
                    var maxC = Math.max(domCol.r, domCol.g, domCol.b)
                    var minC = Math.min(domCol.r, domCol.g, domCol.b)
                    var sat = maxC > 0 ? (maxC - minC) / maxC : 0
                    // If dominant color is murky/dark/grey, fall back to clean, bright root.paper
                    if (sat < 0.25 || maxC < 0.35) {
                        return root.paper
                    }
                    // Soft pastel tint of root.paper
                    return Qt.tint(root.paper, Qt.rgba(domCol.r, domCol.g, domCol.b, 0.35))
                }

                Behavior on color { ColorAnimation { duration: 300 } }
                Behavior on border.color { ColorAnimation { duration: 300 } }

                // Inner clipping container ensures artwork and overlays are clipped to the 24px rounded corners
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 24
                    color: "transparent"

                    // Full-bleed album art background
                    Image {
                        id: cardBgArt
                        anchors.fill: parent
                        source: root.lastMediaArtUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // Smooth darkening and tint overlays so text/buttons pop
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.35) }
                            GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.50) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.70) }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.28) : "transparent"
                    }
                }

                // TOP ROW: App Icon + Status Tag (Left) + Output Pill (Right)
                Item {
                    id: topRow
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 14
                    height: 24

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // App icon (Spotify logo if available, or music icon)
                        Item {
                            width: 20; height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                id: spotLogo
                                anchors.fill: parent
                                source: (mprisSel.player && /spotify/i.test(mprisSel.player.identity || ""))
                                    ? "file:///home/hery/.config/quickshell/bar/spotify.svg"
                                    : ""
                                visible: source !== "" && status === Image.Ready
                            }

                            IconText {
                                anchors.centerIn: parent
                                text: "music_note"
                                color: "#ffffff"
                                font.pixelSize: 20
                                visible: !spotLogo.visible
                            }
                        }

                        // Last Played / Now Playing Tag
                        Rectangle {
                            id: statusTag
                            height: 20
                            radius: 6
                            color: (dashboardContent.curTitle === "" && root.lastMediaTitle !== "")
                                ? Qt.rgba(1, 1, 1, 0.30)
                                : (mprisSel.playing ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.30))
                            border.color: Qt.rgba(1, 1, 1, 0.2)
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: statusTxt.implicitWidth + 12

                            Text {
                                id: statusTxt
                                anchors.centerIn: parent
                                text: {
                                    if (dashboardContent.curTitle === "" && root.lastMediaTitle !== "") return "LAST PLAYED"
                                    if (mprisSel.playing) return "NOW PLAYING"
                                    return "PAUSED"
                                }
                                color: "#ffffff"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.8
                            }
                        }
                    }

                    // Output Pill (e.g. "This device" / Audio Sink)
                    Rectangle {
                        id: outputPill
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.22)
                        border.color: Qt.rgba(1, 1, 1, 0.15)
                        border.width: 1
                        width: outRow.implicitWidth + 14

                        Row {
                            id: outRow
                            anchors.centerIn: parent
                            spacing: 5

                            IconText {
                                text: "speaker"
                                font.pixelSize: 13
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: {
                                    var desc = (audioData.sink && audioData.sink.description) ? audioData.sink.description : "This device"
                                    return desc.length > 18 ? desc.substring(0, 16) + "…" : desc
                                }
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: "#ffffff"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // MIDDLE ROW: Title & Artist (Left) + Pill Play/Pause Button (Right)
                Item {
                    id: midRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    height: 48

                    // Track Title & Artist
                    Column {
                        id: textCol
                        anchors.left: parent.left
                        anchors.right: playPill.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.lastMediaTitle || "No media"
                            color: "#ffffff"
                            font.family: root.barFont
                            font.pixelSize: 17
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: root.lastMediaArtist || "Nothing in queue"
                            color: Qt.rgba(1, 1, 1, 0.80)
                            font.family: root.barFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Large Squircle / Pill Play/Pause Button (Material You style)
                    Rectangle {
                        id: playPill
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 48
                        height: 48
                        radius: 16
                        color: playMa.pressed ? Qt.rgba(1, 1, 1, 0.12) : (playMa.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.18))
                        border.color: Qt.rgba(1, 1, 1, 0.20)
                        border.width: 1
                        scale: playMa.pressed ? 0.90 : (playMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Geometric pause bars (100% mathematically centered)
                        Row {
                            anchors.centerIn: parent
                            spacing: 4.5
                            visible: mprisSel.playing

                            Rectangle {
                                width: 4.5
                                height: 16
                                radius: 2.25
                                color: "#ffffff"
                            }
                            Rectangle {
                                width: 4.5
                                height: 16
                                radius: 2.25
                                color: "#ffffff"
                            }
                        }

                        // Play arrow icon (when paused)
                        IconText {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 1.5
                            text: "play_arrow"
                            font.pixelSize: 28
                            color: "#ffffff"
                            visible: !mprisSel.playing
                        }

                        MouseArea {
                            id: playMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (mprisSel.player) mprisSel.player.togglePlaying()
                        }
                    }
                }

                // BOTTOM ROW: Prev + Wavy Progress Bar + Next + Song Length
                Row {
                    id: bottomRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 14
                    height: 26
                    spacing: 10

                    // Previous Button
                    Item {
                        width: 24; height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        IconText {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            font.pixelSize: 22
                            color: "#ffffff"
                            opacity: (mprisSel.player && mprisSel.player.canGoPrevious) ? 0.95 : 0.4
                        }

                        MouseArea {
                            id: prevMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            scale: pressed ? 0.88 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            onClicked: if (mprisSel.player) mprisSel.player.previous()
                        }
                    }

                    // Wavy Seekable Progress Bar
                    Item {
                        id: wavyBarContainer
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(80, parent.width - 24 - 24 - (positionTxt ? positionTxt.implicitWidth : 36) - (10 * 3))
                        height: 24

                        property real progress: dashboardContent.curLen > 0 
                            ? Math.max(0, Math.min(1, dashboardContent.curPos / dashboardContent.curLen)) 
                            : 0

                        Canvas {
                            id: waveCanvas
                            anchors.fill: parent
                            property real wavePhase: 0
                            property real waveAmp: mprisSel.playing ? 3.5 : 0

                            Behavior on waveAmp {
                                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                            }
                            onWaveAmpChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                var cy = height / 2
                                var p = wavyBarContainer.progress
                                var progressX = Math.max(0, Math.min(width, width * p))
                                var scrubberW = 4
                                var scrubberH = (seekArea.pressed || seekArea.containsMouse) ? 14 : 10
                                var baseAmp = waveCanvas.waveAmp

                                // 1. Unplayed straight horizontal line (from progressX to width)
                                if (progressX < width) {
                                    ctx.beginPath()
                                    ctx.moveTo(progressX, cy)
                                    ctx.lineTo(width, cy)
                                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.32)
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }

                                // 2. Played portion: wavy sine line when playing, flat straight line when paused
                                if (progressX > 0) {
                                    var wavelength = 34 // Slightly increased frequency
                                    ctx.beginPath()
                                    ctx.moveTo(0, cy)
                                    if (baseAmp > 0.05) {
                                        for (var x = 0; x <= progressX; x += 1.5) {
                                            var distToEnd = progressX - x
                                            var taper = distToEnd < 14 ? (distToEnd / 14) : 1.0
                                            var y = cy + baseAmp * taper * Math.sin((x / wavelength) * 2 * Math.PI - wavePhase)
                                            ctx.lineTo(x, y)
                                        }
                                    } else {
                                        ctx.lineTo(progressX, cy)
                                    }
                                    ctx.strokeStyle = "#ffffff"
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }

                                // 3. Vertical pill scrubber head (fixed vertically in center: stationary at cy)
                                ctx.beginPath()
                                ctx.moveTo(progressX, cy - scrubberH / 2)
                                ctx.lineTo(progressX, cy + scrubberH / 2)
                                ctx.strokeStyle = "#ffffff"
                                ctx.lineWidth = scrubberW
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }

                        Timer {
                            interval: 33
                            running: mprisSel.playing && panel.expanded
                            repeat: true
                            onTriggered: {
                                waveCanvas.wavePhase += 0.08
                                waveCanvas.requestPaint()
                            }
                        }

                        Connections {
                            target: dashboardContent
                            function onCurPosChanged() { waveCanvas.requestPaint() }
                            function onCurLenChanged() { waveCanvas.requestPaint() }
                        }

                        Connections {
                            target: mprisSel
                            function onPlayingChanged() { waveCanvas.requestPaint() }
                        }

                        // Floating Timestamp Tooltip during scrub / hover
                        Rectangle {
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 4
                            x: Math.max(0, Math.min(parent.width - width, wavyBarContainer.width * wavyBarContainer.progress - width / 2))
                            width: timeTxt.implicitWidth + 12
                            height: 18
                            radius: 9
                            color: Qt.rgba(0, 0, 0, 0.85)
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                            border.width: 1
                            visible: (seekArea.containsMouse || seekArea.pressed) && dashboardContent.curLen > 0

                            Text {
                                id: timeTxt
                                anchors.centerIn: parent
                                text: dashboardContent.fmtTime(dashboardContent.curPos) + " / " + dashboardContent.fmtTime(dashboardContent.curLen)
                                color: "#ffffff"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: seekArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                dashboardContent.seekTo(mouse.x / width)
                                waveCanvas.requestPaint()
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    dashboardContent.seekTo(mouse.x / width)
                                    waveCanvas.requestPaint()
                                }
                            }
                        }
                    }

                    // Next Button
                    Item {
                        width: 24; height: 24
                        anchors.verticalCenter: parent.verticalCenter

                        IconText {
                            anchors.centerIn: parent
                            text: "skip_next"
                            font.pixelSize: 22
                            color: "#ffffff"
                            opacity: (mprisSel.player && mprisSel.player.canGoNext) ? 0.95 : 0.4
                        }

                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            scale: pressed ? 0.88 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            onClicked: if (mprisSel.player) mprisSel.player.next()
                        }
                    }

                    // Current Song Position Display
                    Text {
                        id: positionTxt
                        text: dashboardContent.fmtTime(dashboardContent.curPos)
                        color: Qt.rgba(1, 1, 1, 0.85)
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // RIGHT COLUMN (60%): Dock (Recent Apps) + Process Monitor OR Detail Section
        Item {
            id: rightColumnArea
            width: parent.width * 0.6 - 8
            height: parent.height

            // Overview Mode: Dock + Process Monitor
            Column {
                id: overviewCol
                anchors.fill: parent
                spacing: 12
                visible: dashboardContent.activeDetailView === ""
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

            // SECTION 1: Dock (Recently Opened Apps)
            Rectangle {
                id: dockSection
                width: parent.width
                height: 96
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "RECENT APPS"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: recentModel.count > 0 ? (recentModel.count + " active") : "None"
                            color: root.ink
                            opacity: 0.4
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }

                    // Dock apps row
                    Item {
                        width: parent.width
                        height: 48

                        Text {
                            anchors.centerIn: parent
                            text: "No recent apps open"
                            color: root.ink
                            opacity: 0.4
                            font.family: root.barFont
                            font.pixelSize: 12
                            visible: recentModel.count === 0
                        }

                        ListView {
                            id: dockList
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 8
                            model: recentModel
                            clip: false
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                width: 48
                                height: 48

                                Rectangle {
                                    id: dockTile
                                    anchors.fill: parent
                                    radius: 14
                                    color: dockMa.containsMouse ? root.fillHover : (model.isFocused ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16) : Qt.rgba(1, 1, 1, 0.04))
                                    border.color: dockMa.containsMouse 
                                        ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.45) 
                                        : (model.isFocused ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.28) : Qt.rgba(1, 1, 1, 0.06))
                                    border.width: 1
                                    scale: dockMa.pressed ? 0.90 : (dockMa.containsMouse ? 1.08 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Image {
                                        id: appImg
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        width: 28
                                        height: 28
                                        source: (model.icon && (model.icon.indexOf("file://") === 0 || model.icon.indexOf("/") === 0)) ? (model.icon.indexOf("file://") === 0 ? model.icon : ("file://" + model.icon)) : dashboardContent.getAppIcon(model.icon || model.desktop)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }

                                    IconText {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        visible: appImg.status !== Image.Ready
                                        text: "apps"
                                        font.pixelSize: 22
                                        color: root.ink
                                    }

                                    // Active / focus dot
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 3.5
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: model.isFocused ? 12 : (model.isOpen ? 5 : 0)
                                        height: 3
                                        radius: 1.5
                                        color: model.isFocused ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
                                        visible: model.isOpen
                                        Behavior on width { NumberAnimation { duration: 180 } }
                                    }
                                }

                                // Tooltip on hover
                                Rectangle {
                                    anchors.bottom: parent.top
                                    anchors.bottomMargin: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: tipTxt.implicitWidth + 14
                                    height: 20
                                    radius: 10
                                    color: Qt.rgba(0.08, 0.08, 0.09, 0.95)
                                    border.color: Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                    visible: dockMa.containsMouse
                                    z: 100

                                    Text {
                                        id: tipTxt
                                        anchors.centerIn: parent
                                        text: (model.name || model.desktop) + (model.isOpen ? " (Running)" : "")
                                        color: "#ffffff"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }

                                MouseArea {
                                    id: dockMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        panel.expanded = false
                                        Quickshell.execDetached([
                                            "python3",
                                            "/home/hery/.config/quickshell/bar/scripts/recent_apps.py",
                                            "activate",
                                            model.address || "",
                                            model.desktop || "",
                                            model.exec || ""
                                        ])
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // SECTION 2: Process Monitor
            Rectangle {
                id: procSection
                width: parent.width
                height: parent.height - dockSection.height - parent.spacing
                radius: 20
                color: root.fillIdle
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "PROCESS MONITOR"
                        color: root.ink
                        opacity: 0.5
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    ListView {
                        width: parent.width
                        height: parent.height - 28
                        model: procModel
                        clip: true
                        spacing: 8
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 48
                            radius: 12
                            color: killHover.containsMouse ? Qt.rgba(1, 0, 0, 0.1) : root.fillHover
                            clip: true

                            // Bar chart background
                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                width: parent.width * (Math.min(100, parseInt(model.cpu)) / 100)
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.4)
                                radius: 12
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            }

                            // The close button
                            Rectangle {
                                id: killBtn
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: killRow.width + 16
                                height: 32; radius: 16
                                color: killHover.containsMouse ? "#ff4444" : "transparent"

                                Row {
                                    id: killRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "close"
                                        color: killHover.containsMouse ? "white" : root.ink
                                        font.pixelSize: 16
                                        opacity: killHover.containsMouse ? 1.0 : 0.6
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Stop"
                                        color: killHover.containsMouse ? "white" : root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        opacity: killHover.containsMouse ? 1.0 : 0.6
                                    }
                                }
                                Process {
                                    id: killProc
                                    command: ["kill", "-9", model.pid]
                                    running: false
                                }
                                MouseArea {
                                    id: killHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: { killProc.running = false; killProc.running = true }
                                }
                            }

                            // Text info
                            Column {
                                anchors.left: parent.left
                                anchors.right: killBtn.left
                                anchors.leftMargin: 16
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter

                                Row {
                                    width: parent.width
                                    spacing: 6
                                    Text {
                                        text: model.name
                                        color: root.ink
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, parent.width - 55)
                                    }
                                    Text {
                                        text: "•"
                                        color: root.ink
                                        opacity: 0.6
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                    }
                                    Text {
                                        text: model.cpu
                                        color: root.ink
                                        opacity: 0.8
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }
                                }
                                Text {
                                    text: "PID: " + model.pid
                                    color: root.ink
                                    opacity: 0.6
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
            } // end overviewCol

            // Detailed Wi-Fi Section
            WifiDetailSection {
                id: wifiDetailSection
                anchors.fill: parent
                root: dashboardContent.root
                panel: dashboardContent.panel
                visible: dashboardContent.activeDetailView === "wifi"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }

            // Detailed Bluetooth Section
            BluetoothDetailSection {
                id: btDetailSection
                anchors.fill: parent
                root: dashboardContent.root
                panel: dashboardContent.panel
                visible: dashboardContent.activeDetailView === "bluetooth"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }

            // Detailed CPU Section
            CpuDetailSection {
                id: cpuDetailSection
                anchors.fill: parent
                root: dashboardContent.root
                panel: dashboardContent.panel
                visible: dashboardContent.activeDetailView === "cpu"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }

            // Detailed Memory Section
            MemoryDetailSection {
                id: memDetailSection
                anchors.fill: parent
                root: dashboardContent.root
                panel: dashboardContent.panel
                visible: dashboardContent.activeDetailView === "memory"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }

            // Detailed Battery Section
            BatteryDetailSection {
                id: batDetailSection
                anchors.fill: parent
                root: dashboardContent.root
                panel: dashboardContent.panel
                visible: dashboardContent.activeDetailView === "battery"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }

            // Detailed Screentime Section
            ScreentimeDetailSection {
                id: stDetailSection
                anchors.fill: parent
                root: dashboardContent.root
                panel: dashboardContent.panel
                visible: dashboardContent.activeDetailView === "screentime"
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                onCloseRequested: {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
            }

            ListModel { id: recentModel }
            ListModel { id: procModel }

            Process {
                id: recentUpdater
                running: panel.expanded
                command: ["python3", "/home/hery/.config/quickshell/bar/scripts/recent_apps.py"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            var list = JSON.parse(this.text.trim())
                            recentModel.clear()
                            for (var i = 0; i < list.length; i++) {
                                recentModel.append(list[i])
                            }
                        } catch(e) {}
                    }
                }
            }

            Timer {
                interval: 3000; repeat: true; running: panel.expanded; triggeredOnStart: true
                onTriggered: { recentUpdater.running = false; recentUpdater.running = true }
            }

            Process {
                id: procUpdater
                running: panel.expanded && dashboardContent.activeDetailView === ""
                command: ["bash", "-c", "ps -eo pid,pcpu,comm --sort=-pcpu | head -n 10 | tail -n 9"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        var lines = this.text.split("\n")
                        procModel.clear()
                        for (var i = 0; i < lines.length; i++) {
                            var line = lines[i].trim()
                            if (line === "") continue
                            var parts = line.split(/\s+/)
                            if (parts.length >= 3) {
                                procModel.append({
                                    pid: parts[0],
                                    cpu: Math.round(parseFloat(parts[1])) + "%",
                                    name: parts.slice(2).join(" ")
                                })
                            }
                        }
                    }
                }
            }

            Timer {
                interval: 3000; repeat: true; running: panel.expanded && dashboardContent.activeDetailView === ""
                onTriggered: { procUpdater.running = false; procUpdater.running = true }
            }
        }
    }
}

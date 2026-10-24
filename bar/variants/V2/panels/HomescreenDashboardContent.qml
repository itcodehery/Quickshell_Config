import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQml.Models
import "../modules"
import "../motion"

Item {
    id: dashboardContent
    anchors.fill: parent
    implicitHeight: 220
    focus: true

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus()
            if (!root || !root.dashboardDetail) {
                activeDetailView = ""
                selectCategoryByIndex(0)
            }
        }
    }
    Component.onCompleted: {
        forceActiveFocus()
        if (!root || !root.dashboardDetail) {
            activeDetailView = ""
            selectCategoryByIndex(0)
        }
    }

    SpringPress {}
    MouseArea {
        anchors.fill: parent
        // Prevent clicks anywhere on the dashboard background from closing the dashboard
        onClicked: {}
    }

    readonly property var detailOrder: ["", "wifi", "bluetooth", "cpu", "memory", "notifications", "screentime", "plugins", "updates", "battery", "calendar", "volume", "system", "theme", "wallpaper", "lockscreen"]

    function selectCategoryByIndex(idx) {
        if (idx < 0) idx = 0
        if (idx >= detailOrder.length) idx = detailOrder.length - 1
        let cat = detailOrder[idx]
        dashboardContent.activeDetailView = cat
        if (root) root.dashboardDetail = cat

        // Keep left-hand tilesPager in sync so active tile is visible
        if (cat === "wifi" || cat === "bluetooth" || cat === "cpu" || cat === "memory" || cat === "") {
            goToPage(0)
        } else if (cat === "notifications" || cat === "screentime" || cat === "battery") {
            goToPage(1)
        } else if (cat === "plugins" || cat === "updates" || cat === "theme" || cat === "wallpaper") {
            goToPage(2)
        }

        dashboardContent.forceActiveFocus()
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
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(1)
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex + 1) % 4
            return
        }
        jumpNextCategory()
    }

    function prevOption() {
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(-1)
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex - 1 + 4) % 4
            return
        }
        jumpPrevCategory()
    }

    Keys.onUpPressed: {
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.setMode) {
                themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
            }
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex - 1 + 4) % 4
            return
        }
        if (dashboardContent.activeDetailView === "plugins") {
            if (pluginsDetailLoader.item) pluginsDetailLoader.item.focusedIndex = Math.max(0, pluginsDetailLoader.item.focusedIndex - 1)
            return
        }
        pageUp()
    }
    Keys.onDownPressed: {
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (themeLoader.item && themeLoader.item.setMode) {
                themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
            }
            return
        }
        if (dashboardContent.activeDetailView === "system") {
            if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex + 1) % 4
            return
        }
        if (dashboardContent.activeDetailView === "plugins") {
            if (pluginsDetailLoader.item) pluginsDetailLoader.item.focusedIndex = pluginsDetailLoader.item.focusedIndex + 1
            return
        }
        pageDown()
    }
    Keys.onLeftPressed: prevOption()
    Keys.onRightPressed: nextOption()
    Keys.onPressed: (event) => {
        if (dashboardContent.activeDetailView === "system") {
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_X) {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
                event.accepted = true
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
                if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex + 1) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
                if (sysDetailLoader.item) sysDetailLoader.item.focusedIndex = (sysDetailLoader.item.focusedIndex - 1 + 4) % 4
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (sysDetailLoader.item) sysDetailLoader.item.triggerOption(sysDetailLoader.item.focusedIndex)
                event.accepted = true
            }
            return
        }
        if (dashboardContent.activeDetailView === "plugins") {
            if (event.key === Qt.Key_Escape) {
                if (pluginsDetailLoader.item && pluginsDetailLoader.item.filterText.length > 0) {
                    pluginsDetailLoader.item.filterText = ""
                } else {
                    dashboardContent.activeDetailView = ""
                    if (root) root.dashboardDetail = ""
                }
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
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                if (pluginsDetailLoader.item) {
                    var count = pluginsDetailLoader.item.filteredCount || 1
                    pluginsDetailLoader.item.focusedIndex = (pluginsDetailLoader.item.focusedIndex + 1) % count
                }
                event.accepted = true
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                if (pluginsDetailLoader.item) {
                    var count = pluginsDetailLoader.item.filteredCount || 1
                    pluginsDetailLoader.item.focusedIndex = (pluginsDetailLoader.item.focusedIndex - 1 + count) % count
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (pluginsDetailLoader.item) pluginsDetailLoader.item.triggerLaunch(pluginsDetailLoader.item.focusedIndex)
                event.accepted = true
            } else if (event.key === Qt.Key_P) {
                if (pluginsDetailLoader.item) pluginsDetailLoader.item.togglePinCurrent(pluginsDetailLoader.item.focusedIndex)
                event.accepted = true
            } else if (event.key === Qt.Key_Slash) {
                if (pluginsDetailLoader.item && pluginsDetailLoader.item.focusSearch) {
                    pluginsDetailLoader.item.focusSearch()
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (pluginsDetailLoader.item && pluginsDetailLoader.item.filterText.length > 0) {
                    pluginsDetailLoader.item.filterText = pluginsDetailLoader.item.filterText.slice(0, -1)
                }
                event.accepted = true
            }
            return
        }
        if (dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper") {
            if (event.key === Qt.Key_Escape) {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (themeLoader.item && themeLoader.item.applySelected) themeLoader.item.applySelected()
                event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                if (themeLoader.item && themeLoader.item.setMode) {
                    themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Left) {
                if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Right) {
                if (themeLoader.item && themeLoader.item.moveSel) themeLoader.item.moveSel(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                if (themeLoader.item && themeLoader.item.setMode) {
                    themeLoader.item.setMode(themeLoader.item.activeMode === "theme" ? "wallpaper" : "theme")
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Backspace) {
                if (themeLoader.item && themeLoader.item.filterText.length > 0) {
                    themeLoader.item.filterText = themeLoader.item.filterText.slice(0, -1)
                }
                event.accepted = true
            } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                       && event.text.charCodeAt(0) !== 127
                       && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
                if (themeLoader.item) {
                    themeLoader.item.filterText += event.text
                }
                event.accepted = true
            }
            return
        }
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
        } else if (event.key === Qt.Key_N) {
            if (mprisSel.player) mprisSel.player.next()
            event.accepted = true
        } else if (event.key === Qt.Key_P) {
            if (mprisSel.player) mprisSel.player.previous()
            event.accepted = true
        } else if (event.key === Qt.Key_Space) {
            if (mprisSel.player) {
                mprisSel.player.togglePlaying()
                event.accepted = true
            } else if (dashboardContent.activeDetailView === "wifi" && wifiDetailSection) {
                wifiDetailSection.startSpeedTestWithSweep()
                event.accepted = true
            } else if (dashboardContent.activeDetailView === "bluetooth" && btDetailSection) {
                btDetailSection.doTogglePower()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_C) {
            if (calDetailSection && calDetailSection.isInputFocused) {
                return;
            }
            if (dashboardContent.activeDetailView === "calendar") {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else {
                dashboardContent.activeDetailView = "calendar"
                if (root) root.dashboardDetail = "calendar"
            }
            event.accepted = true
        } else if (event.key === Qt.Key_X) {
            if (calDetailSection && calDetailSection.isInputFocused) {
                return;
            }
            if (panel && panel.searchOpen) {
                return;
            }
            if (dashboardContent.activeDetailView === "system") {
                dashboardContent.activeDetailView = ""
                if (root) root.dashboardDetail = ""
            } else {
                dashboardContent.activeDetailView = "system"
                if (root) root.dashboardDetail = "system"
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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

    function goToPage(idx) {
        if (!tilesPager) return
        if (idx < 0) idx = 0
        if (idx >= tilesPager.count) idx = tilesPager.count - 1
        let h = tilesPager.height + tilesPager.spacing
        smoothScrollAnim.stop()
        smoothScrollAnim.to = idx * h
        smoothScrollAnim.start()
    }

    property var root
    property var panel
    property string activeDetailView: root && root.dashboardDetail ? root.dashboardDetail : ""

    readonly property var wifiDetailSection: wifiDetailLoader.item
    readonly property var btDetailSection: btDetailLoader.item
    readonly property var cpuDetailSection: cpuDetailLoader.item
    readonly property var memDetailSection: memDetailLoader.item
    readonly property var batDetailSection: batDetailLoader.item
    readonly property var stDetailSection: stDetailLoader.item
    readonly property var volDetailSection: volDetailLoader.item
    readonly property var sysDetailSection: sysDetailLoader.item
    readonly property var calDetailSection: calDetailLoader.item
    readonly property var notifDetailSection: notifDetailLoader.item
    readonly property var updatesDetailSection: updatesDetailLoader.item
    readonly property var pluginsDetailSection: pluginsDetailLoader.item

    Connections {
        target: dashboardContent.root
        ignoreUnknownSignals: true
        function onDashboardDetailChanged() {
            if (dashboardContent.root && dashboardContent.activeDetailView !== dashboardContent.root.dashboardDetail) {
                dashboardContent.activeDetailView = dashboardContent.root.dashboardDetail || ""
            }
        }
    }

    onActiveDetailViewChanged: {
        if (root && root.dashboardDetail !== activeDetailView) {
            root.dashboardDetail = activeDetailView
        }
        if (activeDetailView === "") {
            pageUp()
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
    property bool btPowered: false

    property int nightMode: 0 // 0: Off, 1: Soft (4500K), 2: Intense (3000K)
    property real lastNightChange: 0

    function cycleNightMode() {
        let nextMode = (nightMode + 1) % 3
        setNightMode(nextMode)
    }

    function setNightMode(mode) {
        lastNightChange = Date.now()
        nightMode = mode
        if (mode === 0) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset"])
        } else if (mode === 1) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.02; done; exec hyprsunset -t 4500"])
        } else if (mode === 2) {
            Quickshell.execDetached(["bash", "-c", "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.02; done; exec hyprsunset -t 3000"])
        }
    }

    Process {
        id: nightUpdater
        running: true
        command: ["bash", "-c", "out=$(pgrep -a hyprsunset); if [ -z \"$out\" ]; then echo 'off'; elif echo \"$out\" | grep -q '3000'; then echo 'intense'; else echo 'soft'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (Date.now() - dashboardContent.lastNightChange < 1500) return
                let s = this.text.trim()
                if (s === "intense") dashboardContent.nightMode = 2
                else if (s === "soft") dashboardContent.nightMode = 1
                else dashboardContent.nightMode = 0
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 3000; repeat: true; running: panel.expanded; triggeredOnStart: true
        onTriggered: {
            wifiUpdater.running = false; wifiUpdater.running = true
            btUpdater.running = false; btUpdater.running = true
            nightUpdater.running = false; nightUpdater.running = true
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
        command: ["bash", "-c", "if bluetoothctl show | grep -q 'Powered: yes'; then echo on; else echo off; fi; bluetoothctl devices Connected | head -n1 | cut -d ' ' -f 3-"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.split("\n")
                let powered = (lines[0] || "").trim() === "on"
                let s = (lines[1] || "").trim()
                if (powered && dashboardContent.currentBtName === "Searching...") {
                    statusTimer.interval = 3000
                }
                dashboardContent.btPowered = powered
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
        interval: 250; repeat: true
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
                dashboardContent.curPos = Math.min(dashboardContent.curLen, dashboardContent.curPos + 0.25)
            }
        }
    }

    Connections {
        target: mprisSel
        function onPlayerChanged() {
            dashboardContent.curPos = 0
            dashboardContent._lastRead = -1
            dashboardContent.curLen = mprisSel.player ? (mprisSel.player.length || 0) : 0
            dashboardContent.fetchLocalLyrics()
        }
    }

    readonly property string currentTrackId: {
        var t = curTitle ? curTitle.trim() : ""
        var a = curArtist ? curArtist.trim() : ""
        return (t || a) ? (t + "||" + a) : ""
    }

    property var mprisPanel: null
    property var localLyricsList: []
    property int localLyricIndex: -1
    property string localLyricsTrackId: ""
    property int _localLyricsFetchSeq: 0

    readonly property bool mprisHasTrackLyrics: mprisPanel !== null && mprisPanel !== undefined && mprisPanel.lyricsTrackId !== "" && mprisPanel.lyricsTrackId === currentTrackId && mprisPanel.lyricsList && mprisPanel.lyricsList.length > 0
    readonly property bool localHasTrackLyrics: localLyricsTrackId !== "" && localLyricsTrackId === currentTrackId && localLyricsList && localLyricsList.length > 0

    readonly property var activeLyricsList: mprisHasTrackLyrics ? mprisPanel.lyricsList : (localHasTrackLyrics ? localLyricsList : [])
    readonly property int activeLyricIndex: mprisHasTrackLyrics ? mprisPanel.currentLyricIndex : (localHasTrackLyrics ? localLyricIndex : -1)
    readonly property bool hasSyncedLyrics: mprisSel.active && activeLyricsList && activeLyricsList.length > 0 && activeLyricIndex >= 0 && activeLyricIndex < activeLyricsList.length
    readonly property string activeLyricText: hasSyncedLyrics ? activeLyricsList[activeLyricIndex].text : ""
    readonly property string nextLyricText: (hasSyncedLyrics && (activeLyricIndex + 1) < activeLyricsList.length) ? activeLyricsList[activeLyricIndex + 1].text : ""

    function syncLocalLyricIndex() {
        if (!localLyricsList || localLyricsList.length === 0) {
            if (localLyricIndex !== -1) localLyricIndex = -1
            return
        }
        var pos = dashboardContent.curPos
        var idx = -1
        for (var i = 0; i < localLyricsList.length; i++) {
            if (pos >= localLyricsList[i].time) {
                idx = i
            } else {
                break
            }
        }
        if (idx !== localLyricIndex) localLyricIndex = idx
    }

    function cleanTrackTitle(str) {
        if (!str) return ""
        return str.replace(/\s*[\(\[](feat\.|ft\.|remaster|live|official|deluxe|bonus|version|radio|edit|mono|stereo|anniversary).*?[\)\]]/gi, "")
                  .replace(/\s*-\s*(remaster|live|radio|deluxe|bonus|anniversary).*$/gi, "")
                  .trim()
    }

    function parseLocalLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return []
        var parsed = []
        var offsetSec = 0
        var offsetMatch = /\[offset:\s*([+-]?\d+)\]/i.exec(lrcText)
        if (offsetMatch) {
            offsetSec = (parseFloat(offsetMatch[1]) || 0) / 1000.0
        }

        var lines = lrcText.split('\n')
        var tagRegex = /\[(\d{1,2}):(\d{2}(?:\.\d+)?)\]/g
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || /^\[[a-zA-Z]+:/.test(line)) continue
            var timestamps = []
            var match
            tagRegex.lastIndex = 0
            while ((match = tagRegex.exec(line)) !== null) {
                var m = parseFloat(match[1])
                var s = parseFloat(match[2])
                timestamps.push((m * 60) + s)
            }
            if (timestamps.length > 0) {
                var txt = line.replace(/\[\d{1,2}:\d{2}(?:\.\d+)?\]/g, "").trim()
                if (txt.length > 0) {
                    for (var t = 0; t < timestamps.length; t++) {
                        var adjustedTime = Math.max(0, timestamps[t] + offsetSec)
                        parsed.push({ time: adjustedTime, text: txt })
                    }
                }
            }
        }
        parsed.sort(function(a, b) { return a.time - b.time })
        return parsed
    }

    function fetchLocalLyrics() {
        var title = curTitle ? curTitle.trim() : ""
        var artist = curArtist ? curArtist.trim() : ""
        var album = mprisSel.player ? (mprisSel.player.trackAlbum || "").trim() : ""
        var dur = Math.round(mprisSel.player ? (mprisSel.player.length || dashboardContent.curLen || 0) : (dashboardContent.curLen || 0))
        var trackId = (title || artist) ? (title + "||" + artist) : ""

        var seq = ++_localLyricsFetchSeq

        if (!title || !mprisSel.active) {
            localLyricsList = []
            localLyricIndex = -1
            localLyricsTrackId = ""
            return
        }

        // If mprisPanel is provided and actively managing lyrics for this track, let it handle it
        if (mprisPanel && mprisPanel.currentTrackId === trackId) {
            return
        }

        localLyricsList = []
        localLyricIndex = -1
        localLyricsTrackId = ""

        var cleaned = cleanTrackTitle(title)
        var targetTitle = cleaned !== "" ? cleaned : title

        function pickBestResult(resp) {
            if (!resp) return null
            if (!Array.isArray(resp) && resp.syncedLyrics) {
                return parseLocalLrc(resp.syncedLyrics)
            }
            if (Array.isArray(resp) && resp.length > 0) {
                var candidates = []
                for (var i = 0; i < resp.length; i++) {
                    var item = resp[i]
                    if (item && item.syncedLyrics && typeof item.syncedLyrics === "string" && item.syncedLyrics.trim().length > 0) {
                        var diff = dur > 0 && item.duration ? Math.abs(item.duration - dur) : 9999
                        candidates.push({ item: item, diff: diff })
                    }
                }
                if (candidates.length === 0) return null
                candidates.sort(function(a, b) { return a.diff - b.diff })
                return parseLocalLrc(candidates[0].item.syncedLyrics)
            }
            return null
        }

        function queryUrl(url, fallback) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, true)
            xhr.setRequestHeader("User-Agent", "Quickshell-Lyrics/2.0 (Linux)")
            xhr.timeout = 5000
            xhr.ontimeout = function() { if (fallback) fallback(); }
            xhr.onerror = function() { if (fallback) fallback(); }
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (seq !== dashboardContent._localLyricsFetchSeq || dashboardContent.currentTrackId !== trackId) {
                        return
                    }
                    if (xhr.status === 200) {
                        try {
                            var resp = JSON.parse(xhr.responseText)
                            var parsed = pickBestResult(resp)
                            if (parsed && parsed.length > 0) {
                                dashboardContent.localLyricsTrackId = trackId
                                dashboardContent.localLyricsList = parsed
                                dashboardContent.syncLocalLyricIndex()
                                return
                            }
                        } catch(e) {}
                    }
                    if (fallback) fallback()
                }
            }
            xhr.send()
        }

        var getUrl = dur > 0
            ? ("https://lrclib.net/api/get?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist) + (album ? "&album_name=" + encodeURIComponent(album) : "") + "&duration=" + dur)
            : ""
        var url1 = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist)
        var url2 = "https://lrclib.net/api/search?q=" + encodeURIComponent(targetTitle + " " + artist)

        if (getUrl !== "") {
            queryUrl(getUrl, function() {
                queryUrl(url1, function() {
                    queryUrl(url2, null)
                })
            })
        } else {
            queryUrl(url1, function() {
                queryUrl(url2, null)
            })
        }
    }

    onCurTitleChanged: {
        if (root && curTitle !== "") root.lastMediaTitle = curTitle
        fetchLocalLyrics()
    }
    onCurArtistChanged: {
        if (root && curArtist !== "") root.lastMediaArtist = curArtist
        fetchLocalLyrics()
    }
    onCurArtUrlChanged: { if (root && curArtUrl !== "") root.lastMediaArtUrl = curArtUrl }

    Connections {
        target: mprisSel.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { dashboardContent.fetchLocalLyrics() }
        function onTrackArtistChanged() { dashboardContent.fetchLocalLyrics() }
    }

    onCurPosChanged: {
        if (localLyricsList && localLyricsList.length > 0) {
            syncLocalLyricIndex()
        }
    }

    onRootChanged: {
        if (root) {
            if (mprisSel.player && mprisSel.player.trackTitle) {
                root.lastMediaTitle = mprisSel.player.trackTitle || ""
                root.lastMediaArtist = mprisSel.player.trackArtist || ""
            }
            if (mprisArt.source) root.lastMediaArtUrl = mprisArt.source
        }
    }

    // ── MAIN CONTROLS (Two Columns: Controls on Left, Media Player on Right) ──
    Item {
        id: mainControls
        anchors.fill: parent
        visible: (opacity > 0.001)
        opacity: dashboardContent.activeDetailView === "" ? 1.0 : 0.0
        scale: dashboardContent.activeDetailView === "" ? 1.0 : 0.98
        transform: Translate {
            y: dashboardContent.activeDetailView === "" ? 0 : (root && root.barPosition === "bottom" ? -10 : 10)
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 14

            // ── LEFT COLUMN: Sliders & Quick Settings Tiles ──
            Column {
                id: leftCol
                width: Math.round((parent.width - parent.spacing) / 2)
                spacing: 12

            // --- SLIDERS (Full Material You size) ---
            Column {
                id: slidersCol
                width: parent.width
                spacing: 10
                
                // Brightness Container
                Row {
                    width: parent.width
                    spacing: 10
                    
                    // Brightness Slider
                    Rectangle {
                        id: briSlider
                        width: parent.width - 38 - 8
                        height: 38
                        radius: 19
                        color: root.fillIdle
                        
                        property bool sliding: false
                        property int localValue: dashboardContent.currentBrightness
                        
                        Item {
                            id: briFillItem
                            property real val: briSlider.sliding ? briSlider.localValue : dashboardContent.currentBrightness
                            property real gap: val > 85 ? 19 * (100 - val) / 15 : 19
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
                                radius: 9.5 + (9.5 * (1 - briFillItem.barOpacity))
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
                                width: 20
                                height: parent.height
                                color: "transparent"
                                opacity: briFillItem.barOpacity
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: parent.height - 14
                                    radius: 1.5
                                    color: root.seal
                                }
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10
                            IconText { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: "light_mode"
                                color: root.paper
                                font.pixelSize: 18 
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(briFillItem.val) + "%"
                                color: briFillItem.width > 64 ? root.paper : root.ink
                                font.pixelSize: 12
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
                    
                    // Night Light Toggle (44x44, dual-mode: Soft / Intense)
                    Rectangle {
                        id: localNightToggle
                        width: 38
                        height: 38
                        radius: 19
                        
                        readonly property int mode: dashboardContent.nightMode
                        
                        color: mode === 2 ? root.color01 : (mode === 1 ? root.color03 : root.fillIdle)
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        HoverHandler {
                            id: localNightHov
                        }
                        
                        IconText { 
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -2
                            text: "nightlight_round"
                            color: localNightToggle.mode > 0 ? root.paper : root.ink
                            opacity: localNightToggle.mode > 0 ? 1.0 : 0.6
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        // Dual toggle indicator dashes
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3

                            Rectangle {
                                width: 5
                                height: 3
                                radius: 1.5
                                color: localNightToggle.mode > 0 ? root.paper : root.ink
                                opacity: localNightToggle.mode >= 1 ? 0.95 : 0.25
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            Rectangle {
                                width: 5
                                height: 3
                                radius: 1.5
                                color: localNightToggle.mode > 0 ? root.paper : root.ink
                                opacity: localNightToggle.mode === 2 ? 0.95 : 0.25
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }
                        }
                        
                        MouseArea {
                            id: localNightMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    dashboardContent.setNightMode(0)
                                } else {
                                    dashboardContent.cycleNightMode()
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    if (dashboardContent.nightMode < 2) dashboardContent.setNightMode(dashboardContent.nightMode + 1)
                                } else if (wheel.angleDelta.y < 0) {
                                    if (dashboardContent.nightMode > 0) dashboardContent.setNightMode(dashboardContent.nightMode - 1)
                                }
                            }
                        }
                    }
                }

                // Audio Container
                Row {
                    width: parent.width
                    spacing: 10
                    
                    // Audio Slider
                    Rectangle {
                        id: audSlider
                        width: parent.width - 38 - 8
                        height: 38
                        radius: 19
                        color: root.fillIdle
                        
                        property bool sliding: false
                        property int localValue: audioData.volume
                        
                        Item {
                            id: audFillItem
                            property real val: audSlider.sliding ? audSlider.localValue : audioData.volume
                            property real gap: val > 85 ? 19 * (100 - val) / 15 : 19
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
                                radius: 9.5 + (9.5 * (1 - audFillItem.barOpacity))
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
                                width: 20
                                height: parent.height
                                color: "transparent"
                                opacity: audFillItem.barOpacity
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 3
                                    height: parent.height - 14
                                    radius: 1.5
                                    color: audioData.muted ? root.fillHover : root.seal
                                }
                            }
                        }
                        
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            spacing: 10
                            IconText { 
                                anchors.verticalCenter: parent.verticalCenter
                                text: audioData.muted ? "volume_off" : "volume_up"
                                color: audioData.muted ? root.ink : root.paper
                                font.pixelSize: 18 
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(audFillItem.val) + "%"
                                color: audioData.muted ? root.ink : (audFillItem.width > 64 ? root.paper : root.ink)
                                font.pixelSize: 12
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
                    
                    // Audio Settings / Detail Toggle (38x38)
                    Rectangle {
                        id: audSettingsToggle
                        width: 38
                        height: 38
                        radius: 19
                        color: dashboardContent.activeDetailView === "volume" ? root.seal : root.fillIdle
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                        HoverHandler {
                            id: audTuneHov
                        }
                        
                        IconText { 
                            anchors.centerIn: parent
                            text: "tune"
                            color: dashboardContent.activeDetailView === "volume" ? root.paper : root.ink
                            font.pixelSize: 16
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        SpringPress {}
                        MouseArea {
                            id: audTuneMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (dashboardContent.activeDetailView === "volume") {
                                    dashboardContent.activeDetailView = ""
                                    if (root) root.dashboardDetail = ""
                                } else {
                                    dashboardContent.activeDetailView = "volume"
                                    if (root) root.dashboardDetail = "volume"
                                }
                            }
                        }
                    }
                }
            }

            // --- MATERIAL YOU TILES (Full Material You size) ---
            ListView {
                id: tilesPager
                width: parent.width
                height: 122
                clip: true
                snapMode: ListView.SnapToItem
                orientation: ListView.Vertical
                boundsBehavior: Flickable.StopAtBounds
                spacing: 12
                
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
                        spacing: 10

                        // Wi-Fi Tile
                        Rectangle {
                            id: wifiTile
                            property bool connected: dashboardContent.currentWifiName !== "Wi-Fi"
                            property bool active: dashboardContent.activeDetailView === "wifi"
                            readonly property bool isLit: connected
                            readonly property color fg: root.ink
                            width: (parent.width - 10) / 2
                            height: 56
                            radius: 28
                            color: wifiMa.containsMouse ? root.fillHover : root.fillIdle
                            Behavior on color { ColorAnimation { duration: 160 } }
                            
                            border.width: active ? 2 : 0
                            border.color: root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            SpringPress {}
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
                                spacing: 10
                                
                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 14
                                    color: wifiTile.isLit
                                        ? (wifiInnerMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                        : (wifiInnerMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1))
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    
                                    IconText { 
                                        anchors.centerIn: parent
                                        text: "wifi"
                                        fill: (wifiTile.connected || wifiTile.active) ? 1 : 0
                                        color: wifiTile.isLit ? root.paper : root.ink
                                        font.pixelSize: 20
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    
                                    SpringPress {}
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
                                    spacing: 2
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
                                        width: wifiTile.width - 40 - 8 - 10 - 12
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                        }

                        // Bluetooth Tile
                        Rectangle {
                            id: btTile
                            property bool connected: dashboardContent.btPowered
                            property bool active: dashboardContent.activeDetailView === "bluetooth"
                            readonly property bool isLit: connected
                            readonly property color fg: root.ink
                            width: (parent.width - 10) / 2
                            height: 56
                            radius: 28
                            color: btMa.containsMouse ? root.fillHover : root.fillIdle
                            Behavior on color { ColorAnimation { duration: 160 } }
                            
                            border.width: active ? 2 : 0
                            border.color: root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            SpringPress {}
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
                                spacing: 10
                                
                                Rectangle {
                                    width: 40
                                    height: 40
                                    radius: 14
                                    color: btTile.isLit
                                        ? (btInnerMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                        : (btInnerMa.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.1))
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                    
                                    IconText { 
                                        anchors.centerIn: parent
                                        text: "bluetooth"
                                        fill: (btTile.connected || btTile.active) ? 1 : 0
                                        color: btTile.isLit ? root.paper : root.ink
                                        font.pixelSize: 20
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    
                                    SpringPress {}
                                    MouseArea {
                                        id: btInnerMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (btTile.connected) {
                                                dashboardContent.btPowered = false
                                                dashboardContent.currentBtName = "Bluetooth"
                                            } else {
                                                dashboardContent.btPowered = true
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
                                    spacing: 2
                                    Text {
                                        text: "Bluetooth"
                                        color: btTile.fg
                                        font.pixelSize: 13
                                        font.family: root.barFont
                                        font.weight: Font.DemiBold
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    Text {
                                        text: dashboardContent.currentBtName === "Bluetooth"
                                            ? (dashboardContent.btPowered ? "On" : "Off")
                                            : dashboardContent.currentBtName
                                        color: btTile.fg
                                        opacity: btTile.connected ? 0.75 : 0.6
                                        font.pixelSize: 11
                                        font.family: root.barFont
                                        elide: Text.ElideRight
                                        width: btTile.width - 40 - 8 - 10 - 12
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
                            width: (parent.width - 10) / 2
                            height: 56
                            radius: 28
                            color: active
                                ? (cpuMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (cpuMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            
                            border.width: active ? 2 : 0
                            border.color: active ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                spacing: 10
                                
                                IconText {
                                    text: "memory"
                                    color: cpuTile.fg
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
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
                                        width: 70
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                            SpringPress {}
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
                            width: (parent.width - 10) / 2
                            height: 56
                            radius: 28
                            color: active
                                ? (memMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                : (memMa.containsMouse ? root.fillHover : root.fillIdle)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            
                            border.width: active ? 2 : 0
                            border.color: active ? root.paper : root.seal
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                spacing: 10
                                
                                IconText {
                                    text: "dns"
                                    color: memTile.fg
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }
                                
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
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
                                        width: 70
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                }
                            }
                            SpringPress {}
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

                    // --- PAGE 2 (Row 1: Notifications & Screen Time; Row 2: 1x4 Compact Toggles: Night Light, Caffeine, Power, Temp) ---
                    Column {
                        width: tilesPager.width
                        height: tilesPager.height
                        spacing: 10

                        // Row 1: Notifications + Screen Time
                        Row {
                            width: parent.width
                            spacing: 10

// Notifications Tile
                            Rectangle {
                                id: notifTile
                                property bool active: dashboardContent.activeDetailView === "notifications"
                                readonly property color fg: active ? root.paper : root.ink
                                readonly property int count: (root && root.notifCount) ? root.notifCount : 0
                                width: (parent.width - 10) / 2
                                height: 56
                                radius: 28
                                color: active
                                    ? (notifMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (notifMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    spacing: 10

                                    IconText {
                                        text: notifTile.count > 0 ? "notifications_active" : "notifications"
                                        color: notifTile.fg
                                        font.pixelSize: 22
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: "Notifications"
                                            color: notifTile.fg
                                            font.pixelSize: 13
                                            font.family: root.barFont
                                            font.weight: Font.DemiBold
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                        Text {
                                            text: notifTile.count > 0 ? (notifTile.count + " new") : "All caught up"
                                            color: notifTile.fg
                                            opacity: notifTile.active ? 0.8 : 0.6
                                            font.pixelSize: 11
                                            font.family: root.barFont
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                    }
                                }
                                SpringPress {}
                                MouseArea {
                                    id: notifMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (dashboardContent.activeDetailView === "notifications") {
                                            dashboardContent.activeDetailView = ""
                                            if (root) root.dashboardDetail = ""
                                        } else {
                                            dashboardContent.activeDetailView = "notifications"
                                            if (root) root.dashboardDetail = "notifications"
                                        }
                                    }
                                }
                            }

                            // Screentime Tile
                            Rectangle {
                                id: screentimeTile
                                property bool active: dashboardContent.activeDetailView === "screentime"
                                readonly property color fg: active ? root.paper : root.ink
                                width: (parent.width - 10) / 2
                                height: 56
                                radius: 28
                                color: active
                                    ? (stMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (stMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    spacing: 10
                                    
                                    IconText {
                                        text: "hourglass_empty"
                                        color: screentimeTile.fg
                                        font.pixelSize: 22
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }
                                    
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
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
                                SpringPress {}
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
                        }

                        // Row 2: 1x4 Compact Tiles (Night Light, Caffeine, Battery/Power, CPU Temp)
                        Row {
                            width: parent.width
                            spacing: 10

                            // 1. Night Light Tile (Compact 1x4)
                            Rectangle {
                                id: nightTile
                                readonly property int mode: dashboardContent.nightMode
                                property bool active: mode > 0

                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                color: mode === 2 ? root.color01 : (mode === 1 ? root.color03 : (nightTileMa.containsMouse ? root.fillHover : root.fillIdle))
                                Behavior on color { ColorAnimation { duration: 200 } }

                                IconText {
                                    anchors.centerIn: parent
                                    text: "nightlight_round"
                                    color: nightTile.active ? root.paper : (nightTileMa.containsMouse ? root.seal : root.ink)
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                TooltipMixin {
                                    id: nightTip
                                    root: dashboardContent.root
                                    owner: nightTile
                                    text: "Night Light: " + (nightTile.mode === 2 ? "Intense" : (nightTile.mode === 1 ? "Soft" : "Off")) + " (Right-click off)"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: nightTileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onEntered: nightTip.show()
                                    onExited: nightTip.hide()
                                    onClicked: (mouse) => {
                                        nightTip.hide()
                                        if (mouse.button === Qt.RightButton) {
                                            dashboardContent.setNightMode(0)
                                        } else {
                                            dashboardContent.cycleNightMode()
                                        }
                                    }
                                }
                            }

                            // 2. Caffeine Tile (Compact 1x4)
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

                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                color: active ? root.color03 : (coffeeMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                IconText {
                                    anchors.centerIn: parent
                                    text: "local_cafe"
                                    color: coffeeTile.active ? root.paper : (coffeeMa.containsMouse ? root.seal : root.ink)
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                TooltipMixin {
                                    id: coffeeTip
                                    root: dashboardContent.root
                                    owner: coffeeTile
                                    text: "Caffeine: " + (coffeeTile.active ? "Active (Keep Awake)" : "Sleepy")
                                }

                                SpringPress {}
                                MouseArea {
                                    id: coffeeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: coffeeTip.show()
                                    onExited: coffeeTip.hide()
                                    onClicked: {
                                        coffeeTip.hide()
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

                            // 3. Battery & Power Tile (Compact 1x4)
                            Rectangle {
                                id: powerTile
                                property bool active: dashboardContent.activeDetailView === "battery"
                                readonly property color fg: active ? root.paper : (powerMa.containsMouse ? root.seal : root.ink)
                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                color: active
                                    ? (powerMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (powerMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal

                                IconText {
                                    anchors.centerIn: parent
                                    text: "bolt"
                                    color: powerTile.fg
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                TooltipMixin {
                                    id: powerTip
                                    root: dashboardContent.root
                                    owner: powerTile
                                    text: "Battery & Power Health"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: powerMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: powerTip.show()
                                    onExited: powerTip.hide()
                                    onClicked: {
                                        powerTip.hide()
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

                            // 4. CPU Temperature Tile (Compact 1x4)
                            Rectangle {
                                id: tempTile
                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                clip: true
                                color: tempMa.containsMouse ? root.fillHover : root.fillIdle

                                property int currentTemp: 45
                                readonly property color tempColor: {
                                    if (currentTemp < 52) return "#22d3ee" // Cyan
                                    if (currentTemp < 72) return "#fbbf24" // Amber
                                    return "#f87171" // Coral red
                                }

                                Behavior on color { ColorAnimation { duration: 180 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: Qt.rgba(tempTile.tempColor.r, tempTile.tempColor.g, tempTile.tempColor.b, 0.14)
                                    Behavior on color { ColorAnimation { duration: 400 } }
                                }

                                Process {
                                    running: true
                                    command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            let t = parseInt(this.text.trim())
                                            if (!isNaN(t)) tempTile.currentTemp = Math.round(t / 1000)
                                        }
                                    }
                                }

                                Process {
                                    id: tempUpdater
                                    command: ["bash", "-c", "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 45000"]
                                    stdout: StdioCollector {
                                        onStreamFinished: {
                                            let t = parseInt(this.text.trim())
                                            if (!isNaN(t)) tempTile.currentTemp = Math.round(t / 1000)
                                        }
                                    }
                                }

                                Timer {
                                    interval: 2500; repeat: true; running: panel.expanded
                                    onTriggered: { tempUpdater.running = false; tempUpdater.running = true }
                                }

                                IconText {
                                    anchors.centerIn: parent
                                    text: "thermostat"
                                    color: tempTile.tempColor
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                TooltipMixin {
                                    id: tempTip
                                    root: dashboardContent.root
                                    owner: tempTile
                                    text: "CPU Temp: " + tempTile.currentTemp + "°C (" + (tempTile.currentTemp < 52 ? "Cool" : (tempTile.currentTemp < 72 ? "Warm" : "Hot")) + ")"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: tempMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: tempTip.show()
                                    onExited: tempTip.hide()
                                    onClicked: {
                                        tempTip.hide()
                                        tempUpdater.running = false
                                        tempUpdater.running = true
                                    }
                                }
                            }
                        }
                    }

                    // --- PAGE 3 (Row 1: Omarchy Plugins & Updates; Row 2: 1x4 Compact Toggles: Pomodoro, Quick Share, Themes, Wallpapers) ---
                    Column {
                        width: tilesPager.width
                        height: tilesPager.height
                        spacing: 10

                        // Row 1: Omarchy Plugins + Updates
                        Row {
                            width: parent.width
                            spacing: 10

                            // Omarchy Plugins Tile
                            Rectangle {
                                id: pluginsTile
                                property bool active: dashboardContent.activeDetailView === "plugins"
                                readonly property color fg: active ? root.paper : root.ink
                                width: (parent.width - 10) / 2
                                height: 56
                                radius: 28
                                color: active
                                    ? (pluginsMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (pluginsMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal
                                Behavior on border.width { NumberAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 14
                                    spacing: 10

                                    IconText {
                                        text: "widgets"
                                        color: pluginsTile.fg
                                        font.pixelSize: 22
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2
                                        Text {
                                            text: "Omarchy Plugins"
                                            color: pluginsTile.fg
                                            font.pixelSize: 13
                                            font.family: root.barFont
                                            font.weight: Font.DemiBold
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                        Text {
                                            text: "Extensions & Tools"
                                            color: pluginsTile.fg
                                            opacity: pluginsTile.active ? 0.8 : 0.6
                                            font.pixelSize: 11
                                            font.family: root.barFont
                                            Behavior on color { ColorAnimation { duration: 160 } }
                                        }
                                    }
                                }

                                SpringPress {}
                                MouseArea {
                                    id: pluginsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (dashboardContent.activeDetailView === "plugins") {
                                            dashboardContent.activeDetailView = ""
                                            if (root) root.dashboardDetail = ""
                                        } else {
                                            dashboardContent.activeDetailView = "plugins"
                                            if (root) root.dashboardDetail = "plugins"
                                        }
                                    }
                                }
                            }

                            // Right Half: Updates Pill + Lock Screen Settings Pill
                            Row {
                                width: (parent.width - 10) / 2
                                height: 56
                                spacing: 8

                                // 1. Software Updates Tile (Compact Icon Pill)
                                Rectangle {
                                    id: updatesTile
                                    property bool active: dashboardContent.activeDetailView === "updates" || dashboardContent.activeDetailView === "packages"
                                    readonly property color fg: active ? root.paper : root.ink
                                    width: Math.floor((parent.width - parent.spacing) / 2)
                                    height: 56
                                    radius: 28
                                    color: active
                                        ? (updatesMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                        : (updatesMa.containsMouse ? root.fillHover : root.fillIdle)
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    border.width: active ? 2 : 0
                                    border.color: active ? root.paper : root.seal
                                    Behavior on border.width { NumberAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "system_update"
                                        color: updatesTile.fg
                                        font.pixelSize: 24
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }

                                    TooltipMixin {
                                        id: updatesTip
                                        root: dashboardContent.root
                                        owner: updatesTile
                                        text: "Software Updates: " + (root.systemUpdatesAvailable > 0 ? (root.systemUpdatesAvailable + " available") : "Up to date")
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: updatesMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: updatesTip.show()
                                        onExited: updatesTip.hide()
                                        onClicked: {
                                            updatesTip.hide()
                                            if (dashboardContent.activeDetailView === "updates" || dashboardContent.activeDetailView === "packages") {
                                                dashboardContent.activeDetailView = ""
                                                if (root) root.dashboardDetail = ""
                                            } else {
                                                dashboardContent.activeDetailView = "updates"
                                                if (root) root.dashboardDetail = "updates"
                                            }
                                        }
                                    }
                                }

                                // 2. Lockscreen Settings Tile (Compact Icon Pill)
                                Rectangle {
                                    id: lockscreenTile
                                    property bool active: dashboardContent.activeDetailView === "lockscreen"
                                    readonly property color fg: active ? root.paper : root.ink
                                    width: Math.ceil((parent.width - parent.spacing) / 2)
                                    height: 56
                                    radius: 28
                                    color: active
                                        ? (lockscreenMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                        : (lockscreenMa.containsMouse ? root.fillHover : root.fillIdle)
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    border.width: active ? 2 : 0
                                    border.color: active ? root.paper : root.seal
                                    Behavior on border.width { NumberAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "lock"
                                        color: lockscreenTile.fg
                                        font.pixelSize: 24
                                        Behavior on color { ColorAnimation { duration: 160 } }
                                    }

                                    TooltipMixin {
                                        id: lockscreenTip
                                        root: dashboardContent.root
                                        owner: lockscreenTile
                                        text: "Lock Screen Settings"
                                    }

                                    SpringPress {}
                                    MouseArea {
                                        id: lockscreenMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: lockscreenTip.show()
                                        onExited: lockscreenTip.hide()
                                        onClicked: {
                                            lockscreenTip.hide()
                                            if (dashboardContent.activeDetailView === "lockscreen") {
                                                dashboardContent.activeDetailView = ""
                                                if (root) root.dashboardDetail = ""
                                            } else {
                                                dashboardContent.activeDetailView = "lockscreen"
                                                if (root) root.dashboardDetail = "lockscreen"
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Row 2: 1x4 Compact Tiles (Pomodoro, Quick Share, Themes, Wallpapers)
                        Row {
                            width: parent.width
                            spacing: 10

                            // 5. Pomodoro Timer Tile (Compact 1x4)
                            Rectangle {
                                id: pomodoroTile
                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                clip: true
                                color: root.timerActive ? (root.color03 || root.seal) : (pomodoroMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                IconText {
                                    anchors.centerIn: parent
                                    text: root.timerActive ? "timer" : "hourglass_top"
                                    color: root.timerActive ? root.paper : (pomodoroMa.containsMouse ? root.seal : root.ink)
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                TooltipMixin {
                                    id: pomodoroTip
                                    root: dashboardContent.root
                                    owner: pomodoroTile
                                    text: {
                                        if (!root.timerActive) return "Pomodoro: 25m Focus (Click to start)"
                                        if (root.timerPaused) return "Pomodoro: Paused"
                                        var sec = root.timerRemaining
                                        var m = Math.floor(sec / 60)
                                        var s = sec % 60
                                        return "Pomodoro: " + (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s) + " left (Right-click reset)"
                                    }
                                }

                                SpringPress {}
                                MouseArea {
                                    id: pomodoroMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onEntered: pomodoroTip.show()
                                    onExited: pomodoroTip.hide()
                                    onClicked: (mouse) => {
                                        pomodoroTip.hide()
                                        if (mouse.button === Qt.RightButton) {
                                            root.resetTimer()
                                        } else {
                                            if (root.timerActive) {
                                                root.toggleTimer()
                                            } else {
                                                root.startTimer(25, "Focus")
                                            }
                                        }
                                    }
                                }
                            }

                            // 6. Quick Share Tile (Compact 1x4)
                            Rectangle {
                                id: quickShareTile
                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                color: quickShareMa.containsMouse ? root.fillHover : root.fillIdle
                                Behavior on color { ColorAnimation { duration: 160 } }

                                IconText {
                                    anchors.centerIn: parent
                                    text: "share"
                                    color: quickShareMa.containsMouse ? root.seal : root.ink
                                    font.pixelSize: 22
                                }

                                TooltipMixin {
                                    id: qsTip
                                    root: dashboardContent.root
                                    owner: quickShareTile
                                    text: "Quick Share (LocalSend)"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: quickShareMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: qsTip.show()
                                    onExited: qsTip.hide()
                                    onClicked: {
                                        qsTip.hide()
                                        Quickshell.execDetached(["localsend"])
                                    }
                                }
                            }

                            // 7. Themes Tile (Compact 1x4)
                            Rectangle {
                                id: themeTile
                                property bool active: dashboardContent.activeDetailView === "theme"
                                readonly property color fg: active ? root.paper : (themeMa.containsMouse ? root.seal : root.ink)
                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                color: active
                                    ? (themeMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (themeMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal

                                IconText {
                                    anchors.centerIn: parent
                                    text: "palette"
                                    color: themeTile.fg
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                TooltipMixin {
                                    id: themeTip
                                    root: dashboardContent.root
                                    owner: themeTile
                                    text: "Themes & Color Scheme"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: themeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: themeTip.show()
                                    onExited: themeTip.hide()
                                    onClicked: {
                                        themeTip.hide()
                                        if (dashboardContent.activeDetailView === "theme") {
                                            dashboardContent.activeDetailView = ""
                                            if (root) root.dashboardDetail = ""
                                        } else {
                                            dashboardContent.activeDetailView = "theme"
                                            if (root) root.dashboardDetail = "theme"
                                        }
                                    }
                                }
                            }

                            // 8. Wallpapers Tile (Compact 1x4)
                            Rectangle {
                                id: wallpaperTile
                                property bool active: dashboardContent.activeDetailView === "wallpaper"
                                readonly property color fg: active ? root.paper : (wallpaperMa.containsMouse ? root.seal : root.ink)
                                width: Math.floor((parent.width - 30) / 4)
                                height: 56
                                radius: 18
                                color: active
                                    ? (wallpaperMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                                    : (wallpaperMa.containsMouse ? root.fillHover : root.fillIdle)
                                Behavior on color { ColorAnimation { duration: 160 } }

                                border.width: active ? 2 : 0
                                border.color: active ? root.paper : root.seal

                                IconText {
                                    anchors.centerIn: parent
                                    text: "wallpaper"
                                    color: wallpaperTile.fg
                                    font.pixelSize: 22
                                    Behavior on color { ColorAnimation { duration: 160 } }
                                }

                                TooltipMixin {
                                    id: wallTip
                                    root: dashboardContent.root
                                    owner: wallpaperTile
                                    text: "Wallpapers (Gallery & Picker)"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: wallpaperMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: wallTip.show()
                                    onExited: wallTip.hide()
                                    onClicked: {
                                        wallTip.hide()
                                        if (dashboardContent.activeDetailView === "wallpaper") {
                                            dashboardContent.activeDetailView = ""
                                            if (root) root.dashboardDetail = ""
                                        } else {
                                            dashboardContent.activeDetailView = "wallpaper"
                                            if (root) root.dashboardDetail = "wallpaper"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } // end tilesPager
        } // end leftCol

        // ── RIGHT COLUMN: Media Player & Lyrics Drawer ──
        Item {
            id: rightCol
            width: parent.width - leftCol.width - parent.spacing
            height: leftCol.height

            // --- MATERIAL YOU MEDIA PLAYER WITH EXTENDED LYRICS SECTION ---
            Item {
                id: mediaWithLyricsGroup
                anchors.fill: parent
                readonly property real lyricsVisibleHeight: Math.max(60, height - mediaCard.height)

                // Extended Lyrics Drawer (Starts from the back of the media player and extends down)
                Rectangle {
                    id: lyricsExtender
                    z: 1
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: 22

                    readonly property bool hasBrightDom: mediaCard.hasDominant && (mediaCard.domCol.r * 0.299 + mediaCard.domCol.g * 0.587 + mediaCard.domCol.b * 0.114 > 0.15)
                    color: mediaCard.hasDominant
                        ? Qt.rgba(mediaCard.domCol.r * 0.32, mediaCard.domCol.g * 0.32, mediaCard.domCol.b * 0.32, lyricsMa.containsMouse ? 0.75 : 0.60)
                        : (lyricsMa.containsMouse ? root.fillHover : root.fillIdle)
                    border.color: mediaCard.hasDominant
                        ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, lyricsMa.containsMouse ? 0.50 : 0.32)
                        : (lyricsMa.containsMouse ? root.islandBorder : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.16))
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }

                    // Frosted acrylic glass styling with ambient dominant glow
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 22
                        color: "transparent"

                        // Specular glass gradient
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Qt.rgba(1, 1, 1, lyricsMa.containsMouse ? 0.08 : 0.04)
                                }
                                GradientStop {
                                    position: 0.40
                                    color: Qt.rgba(1, 1, 1, 0.01)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "transparent"
                                }
                            }
                        }

                        // Subtle dominant ambient glow
                        Rectangle {
                            anchors.fill: parent
                            visible: mediaCard.hasDominant
                            opacity: lyricsMa.containsMouse ? 0.30 : 0.18
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: mediaCard.domCol
                                }
                                GradientStop {
                                    position: 0.85
                                    color: "transparent"
                                }
                            }
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: lyricsMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (dashboardContent.mprisPanel) {
                                dashboardContent.mprisPanel.showingLyrics = !dashboardContent.mprisPanel.showingLyrics
                            }
                        }
                    }

                    // Visible extension area extending below mediaCard
                    Item {
                        id: lyricVisibleArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: mediaWithLyricsGroup.lyricsVisibleHeight

                        // Floating Pill Toggle Tag (Right aligned)
                        Rectangle {
                            id: lyricsPillTag
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            radius: 12
                            readonly property bool isShowing: (dashboardContent.mprisPanel && dashboardContent.mprisPanel.showingLyrics)
                            color: isShowing
                                ? (mediaCard.hasDominant ? mediaCard.domCol : root.seal)
                                : (lyricsMa.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.14))
                            border.color: isShowing
                                ? (mediaCard.hasDominant ? mediaCard.domCol : root.seal)
                                : Qt.rgba(1, 1, 1, 0.28)
                            border.width: 1
                            width: tagRow.implicitWidth + 14

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            Row {
                                id: tagRow
                                anchors.centerIn: parent
                                spacing: 5

                                IconText {
                                    text: lyricsPillTag.isShowing ? "visibility" : "subtitles"
                                    font.pixelSize: 12
                                    color: lyricsPillTag.isShowing ? (mediaCard.hasDominant ? "#000000" : root.paper) : "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: lyricsPillTag.isShowing ? "FLOAT ON" : "LYRICS"
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                    color: lyricsPillTag.isShowing ? (mediaCard.hasDominant ? "#000000" : root.paper) : "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Realtime Animated Multi-line Lyrics Viewport (Vertically centered)
                        Item {
                            id: lyricTextContainer
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: lyricsPillTag.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - 12
                            clip: true

                            // Fallback container when no synced lyrics available
                            Column {
                                id: fallbackLyricsCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                visible: !dashboardContent.hasSyncedLyrics

                                Text {
                                    text: mprisSel.active ? (curTitle !== "" ? curTitle : "No synced lyrics available") : "Play music to see lyrics"
                                    color: "#FFFFFF"
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                }

                                Text {
                                    text: mprisSel.active
                                        ? (curArtist !== "" ? curArtist + "  •  No synced lyrics" : "No synced lyrics available")
                                        : "Tap to open lyrics panel"
                                    color: Qt.rgba(1, 1, 1, 0.50)
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    visible: text !== ""
                                }
                            }

                            // Reel column when synced lyrics are available - max 2 lines visible at a time
                            Item {
                                id: syncedReelViewport
                                anchors.fill: parent
                                visible: dashboardContent.hasSyncedLyrics
                                clip: true

                                Column {
                                    id: lyricReelCol
                                    width: parent.width
                                    spacing: 4

                                    property real glideOffset: 0
                                    readonly property real baseRestingY: {
                                        var twoLinesH = line1Text.implicitHeight + (lyricReelCol.nextText !== "" ? (spacing + line2Text.implicitHeight) : 0)
                                        return Math.max(0, Math.round((syncedReelViewport.height - twoLinesH) / 2))
                                    }

                                    y: baseRestingY + glideOffset

                                    property int curIdx: -1
                                    property string activeText: ""
                                    property string nextText: ""
                                    property string thirdText: ""
                                    property string pendingActiveText: ""
                                    property string pendingNextText: ""

                                    function resetImmediate() {
                                        glideOffset = 0
                                        line1Text.opacity = 1.0
                                        line2Text.opacity = lyricReelCol.nextText !== "" ? 0.50 : 0.0
                                        line3Text.opacity = 0.0
                                        line3Text.text = ""
                                    }

                                    // Active lyric (Current line) - multi-line WordWrap with comfortable spacing
                                    Text {
                                        id: line1Text
                                        width: parent.width
                                        text: lyricReelCol.activeText
                                        color: "#FFFFFF"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        opacity: 1.0
                                    }

                                    // Upcoming preview lyric (Next line) - glides up to line 1 during reel animation
                                    Text {
                                        id: line2Text
                                        width: parent.width
                                        text: lyricReelCol.nextText
                                        color: "#FFFFFF"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        opacity: text !== "" ? 0.50 : 0.0
                                    }

                                    // Incoming preview lyric (Only fades in as next line during reel animation, invisible at rest)
                                    Text {
                                        id: line3Text
                                        width: parent.width
                                        text: lyricReelCol.thirdText
                                        color: "#FFFFFF"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.15
                                        opacity: 0.0
                                    }
                                }

                                // High-performance, silky smooth vertical glide animation
                                ParallelAnimation {
                                    id: lyricReelAnim
                                    property real shiftDistance: -(line1Text.implicitHeight + lyricReelCol.spacing)

                                    NumberAnimation {
                                        target: lyricReelCol
                                        property: "glideOffset"
                                        from: 0
                                        to: lyricReelAnim.shiftDistance
                                        duration: 340
                                        easing.type: Easing.OutCubic
                                    }
                                    NumberAnimation {
                                        target: line1Text
                                        property: "opacity"
                                        to: 0.0
                                        duration: 260
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        target: line2Text
                                        property: "opacity"
                                        to: 1.0
                                        duration: 320
                                        easing.type: Easing.OutQuad
                                    }
                                    NumberAnimation {
                                        target: line3Text
                                        property: "opacity"
                                        to: 0.50
                                        duration: 320
                                        easing.type: Easing.OutQuad
                                    }

                                    onFinished: {
                                        lyricReelCol.activeText = lyricReelCol.pendingActiveText
                                        lyricReelCol.nextText = lyricReelCol.pendingNextText
                                        lyricReelCol.thirdText = ""
                                        lyricReelCol.glideOffset = 0
                                        line1Text.opacity = 1.0
                                        line2Text.opacity = lyricReelCol.nextText !== "" ? 0.50 : 0.0
                                        line3Text.opacity = 0.0
                                    }
                                }

                                function updateFromIndex(idx) {
                                    if (!dashboardContent.hasSyncedLyrics || idx < 0) {
                                        if (lyricReelAnim.running) lyricReelAnim.stop()
                                        lyricReelCol.curIdx = -1
                                        lyricReelCol.activeText = ""
                                        lyricReelCol.nextText = ""
                                        lyricReelCol.thirdText = ""
                                        lyricReelCol.resetImmediate()
                                        return
                                    }

                                    var list = dashboardContent.activeLyricsList
                                    var newAct = (list && list[idx]) ? list[idx].text : ""
                                    var newNext = (list && idx + 1 < list.length) ? list[idx + 1].text : ""
                                    var newThird = (list && idx + 2 < list.length) ? list[idx + 2].text : ""

                                    if (lyricReelCol.curIdx >= 0 && idx === lyricReelCol.curIdx + 1 && !lyricReelAnim.running) {
                                        // Sequential advance: smoothly glide next lyric into current container
                                        lyricReelCol.pendingActiveText = newAct
                                        lyricReelCol.pendingNextText = newNext
                                        lyricReelCol.thirdText = newThird
                                        lyricReelCol.curIdx = idx
                                        lyricReelAnim.shiftDistance = -(line1Text.implicitHeight + lyricReelCol.spacing)
                                        lyricReelAnim.restart()
                                    } else {
                                        // Non-sequential change (seek, track skip, initial load): update directly
                                        if (lyricReelAnim.running) lyricReelAnim.stop()
                                        lyricReelCol.curIdx = idx
                                        lyricReelCol.activeText = newAct
                                        lyricReelCol.nextText = newNext
                                        lyricReelCol.thirdText = ""
                                        lyricReelCol.resetImmediate()
                                    }
                                }

                                Connections {
                                    target: dashboardContent
                                    function onCurrentTrackIdChanged() {
                                        syncedReelViewport.updateFromIndex(-1)
                                    }
                                    function onActiveLyricIndexChanged() {
                                        syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                                    }
                                    function onHasSyncedLyricsChanged() {
                                        syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                                    }
                                }

                                Component.onCompleted: {
                                    syncedReelViewport.updateFromIndex(dashboardContent.activeLyricIndex)
                                }
                            }
                        }
                    }
                }

                // --- MATERIAL YOU MEDIA PLAYER (Front Card) ---
                Rectangle {
                    id: mediaCard
                    z: 2
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 144
                    radius: 22
                    readonly property bool hasDominant: mprisArt.dominantColor && String(mprisArt.dominantColor) !== "#00000000" && String(mprisArt.dominantColor) !== "transparent"
                    readonly property color domCol: hasDominant ? mprisArt.dominantColor : root.seal
                    readonly property bool hasVibrantDom: hasDominant && (domCol.r * 0.299 + domCol.g * 0.587 + domCol.b * 0.114 > 0.18)
                    color: mediaCard.hasDominant ? Qt.rgba(mediaCard.domCol.r * 0.45, mediaCard.domCol.g * 0.45, mediaCard.domCol.b * 0.45, 0.5) : root.fillIdle
                    border.color: hasVibrantDom ? Qt.rgba(mediaCard.domCol.r, mediaCard.domCol.g, mediaCard.domCol.b, 0.45) : root.islandBorder
                    border.width: 1
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

                    // Inner clipping container ensures artwork and overlays are clipped to the rounded corners
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 22
                        color: "transparent"

                        // Full-bleed album art background
                        Image {
                            id: cardBgArt
                            anchors.fill: parent
                            source: root.lastMediaArtUrl
                            sourceSize: Qt.size(512, 512)
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
                        anchors.margins: 12
                        height: 22

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
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 0.8
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Reload Lyrics Button
                            Rectangle {
                                id: reloadLyricsBtn
                                width: 22
                                height: 22
                                radius: 11
                                anchors.verticalCenter: parent.verticalCenter
                                color: reloadLyricsMa.containsMouse ? root.fillHover : root.fillIdle
                                border.color: root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                IconText {
                                    id: reloadIcon
                                    anchors.centerIn: parent
                                    text: "refresh"
                                    font.pixelSize: 13
                                    color: (mprisPanel && mprisPanel._isFetchingLyrics) ? root.seal : (root ? root.ink : "#ffffff")

                                    RotationAnimation on rotation {
                                        running: mprisPanel ? mprisPanel._isFetchingLyrics : false
                                        loops: Animation.Infinite
                                        from: 0
                                        to: 360
                                        duration: 800
                                    }
                                }

                                TooltipMixin {
                                    id: reloadLyricsTip
                                    root: dashboardContent.root
                                    owner: reloadLyricsBtn
                                    text: "Reload lyrics"
                                }

                                SpringPress {}
                                MouseArea {
                                    id: reloadLyricsMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: reloadLyricsTip.show()
                                    onExited: reloadLyricsTip.hide()
                                    onClicked: {
                                        var trackId = dashboardContent.currentTrackId
                                        if (mprisPanel) {
                                            if (trackId && mprisPanel._lyricsCache) {
                                                delete mprisPanel._lyricsCache[trackId]
                                            }
                                            mprisPanel.lyricsTrackId = ""
                                            mprisPanel._lyricsRetryCount = 0
                                            mprisPanel._isFetchingLyrics = false
                                            mprisPanel.fetchLyrics()
                                        }
                                        dashboardContent.localLyricsTrackId = ""
                                        dashboardContent.fetchLocalLyrics()
                                    }
                                }
                            }

                            // Output Pill (e.g. "This device" / Audio Sink)
                            Rectangle {
                                id: outputPill
                                anchors.verticalCenter: parent.verticalCenter
                                height: 22
                                radius: 11
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
                    }

                    // MIDDLE ROW: Title & Artist (Left) + Pill Play/Pause Button (Right)
                    Item {
                        id: midRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -1
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        height: 44

                        // Track Title & Artist
                        Column {
                            id: textCol
                            anchors.left: parent.left
                            anchors.right: playPill.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            // Song Title with Marquee (only scrolls when title overflows container)
                            Item {
                                id: marqueeTitleContainer
                                width: parent.width
                                height: 22
                                clip: true

                                readonly property bool shouldMarquee: marqueeTitleContainer.width > 20 && marqueeTitleText.implicitWidth > (marqueeTitleContainer.width + 4)

                                function resetMarquee() {
                                    marqueeAnim.stop()
                                    marqueeTitleText.x = 0
                                    if (shouldMarquee) marqueeAnim.start()
                                }

                                onWidthChanged: resetMarquee()
                                onShouldMarqueeChanged: resetMarquee()

                                Text {
                                    id: marqueeTitleText
                                    text: root.lastMediaTitle || "No media"
                                    color: "#ffffff"
                                    font.family: root.barFont
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                    anchors.verticalCenter: parent.verticalCenter

                                    onTextChanged: marqueeTitleContainer.resetMarquee()

                                    SequentialAnimation on x {
                                        id: marqueeAnim
                                        loops: Animation.Infinite
                                        running: marqueeTitleContainer.shouldMarquee
                                        onRunningChanged: {
                                            if (!running) marqueeTitleText.x = 0
                                        }
                                        PauseAnimation { duration: 2000 }
                                        NumberAnimation {
                                            from: 0
                                            to: -(marqueeTitleText.implicitWidth - marqueeTitleContainer.width + 16)
                                            duration: Math.max(1200, (marqueeTitleText.implicitWidth - marqueeTitleContainer.width) * 25)
                                            easing.type: Easing.Linear
                                        }
                                        PauseAnimation { duration: 1800 }
                                        NumberAnimation {
                                            to: 0
                                            duration: 400
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
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
                            width: 44
                            height: 44
                            radius: 14
                            color: playMa.pressed ? Qt.rgba(1, 1, 1, 0.12) : (playMa.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.18))
                            border.color: Qt.rgba(1, 1, 1, 0.20)
                            border.width: 1
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

                            SpringPress {}
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
                        anchors.margins: 12
                        height: 24
                        spacing: 8

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

                            SpringPress {}
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
                            width: Math.max(80, parent.width - 24 - 24 - (positionTxt ? positionTxt.implicitWidth : 36) - (8 * 3))
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

                            SpringPress {}
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
            } // end mediaWithLyricsGroup
        } // end rightCol
    } // end Row
} // end mainControls

    // ── DETAIL OVERLAY (Phone-style sub-page sheet) ──
    Item {
        id: detailOverlay
        anchors.fill: parent
        visible: (opacity > 0.001)
        opacity: dashboardContent.activeDetailView !== "" ? 1.0 : 0.0
        scale: dashboardContent.activeDetailView !== "" ? 1.0 : 0.98
        transform: Translate {
            y: dashboardContent.activeDetailView !== "" ? 0 : (root && root.barPosition === "bottom" ? 14 : -14)
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        z: 10

        // Subpage Header Bar
        Item {
            id: detailHeaderBar
            width: parent.width
            height: 0
            visible: false
            anchors.top: parent.top

            // Back button pill
            Rectangle {
                id: detailBackBtn
                height: 32
                width: backContentRow.width + 16
                radius: 16
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: detailBackMa.containsMouse ? root.fillHover : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: backContentRow
                    anchors.centerIn: parent
                    spacing: 5
                    IconText {
                        text: "arrow_back"
                        color: root.ink
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Back"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                SpringPress {}
                MouseArea {
                    id: detailBackMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardContent.activeDetailView = ""
                        if (root) root.dashboardDetail = ""
                    }
                }
            }

            // Section Title
            Text {
                anchors.centerIn: parent
                text: {
                    switch (dashboardContent.activeDetailView) {
                        case "wifi": return "Wi-Fi & Network"
                        case "bluetooth": return "Bluetooth"
                        case "cpu": return "CPU Performance"
                        case "memory": return "Memory Usage"
                        case "battery": return "Battery & Power"
                        case "screentime": return "Screen Time"
                        case "volume": return "Sound & Volume"
                        case "system": return "System & Power"
                        case "calendar": return "Calendar & Notes"
                        case "notifications": return "Notifications"
                        case "updates": return "Software Updates"
                        case "packages": return "Software Updates"
                        case "theme": return "Themes"
                        case "wallpaper": return "Wallpapers"
                        case "plugins": return "Omarchy Plugins"
                        case "lockscreen": return "Lock Screen Settings"
                        default: return ""
                    }
                }
                color: root.ink
                font.family: root.barFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            // Close button
            Rectangle {
                width: 32
                height: 32
                radius: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: detailCloseMa.containsMouse ? root.fillHover : root.fillIdle
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: "close"
                    color: root.ink
                    font.pixelSize: 16
                }

                SpringPress {}
                MouseArea {
                    id: detailCloseMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        dashboardContent.activeDetailView = ""
                        if (root) root.dashboardDetail = ""
                    }
                }
            }
        }

        // Subpage Content Area
        Item {
            id: detailContentArea
            anchors.top: detailHeaderBar.bottom
            anchors.topMargin: 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            component DetailLoader: Loader {
                required property string viewName
                anchors.fill: parent
                active: dashboardContent.activeDetailView === viewName
                visible: active
                Connections {
                    target: item
                    ignoreUnknownSignals: true
                    function onCloseRequested() {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                    }
                }
            }

            DetailLoader { id: wifiDetailLoader;  viewName: "wifi";          sourceComponent: WifiDetailSection          { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: btDetailLoader;    viewName: "bluetooth";     sourceComponent: BluetoothDetailSection     { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: cpuDetailLoader;   viewName: "cpu";           sourceComponent: CpuDetailSection           { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: memDetailLoader;   viewName: "memory";        sourceComponent: MemoryDetailSection        { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: batDetailLoader;   viewName: "battery";       sourceComponent: BatteryDetailSection       { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: stDetailLoader;    viewName: "screentime";    sourceComponent: ScreentimeDetailSection    { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader { id: volDetailLoader;   viewName: "volume";        sourceComponent: VolumeDetailSection        { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader {
                id: sysDetailLoader
                viewName: "system"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: SystemDetailSection { root: dashboardContent.root; panel: dashboardContent.panel }
            }
            DetailLoader {
                id: pluginsDetailLoader
                viewName: "plugins"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: PluginsDetailSection { root: dashboardContent.root; panel: dashboardContent.panel }
            }
            DetailLoader { id: calDetailLoader;   viewName: "calendar";      sourceComponent: CalendarDetailSection      { root: dashboardContent.root; panel: dashboardContent.panel } }
            DetailLoader {
                id: notifDetailLoader
                viewName: "notifications"
                sourceComponent: NotificationDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                }
            }
            DetailLoader {
                id: updatesDetailLoader
                viewName: "updates"
                active: dashboardContent.activeDetailView === "updates" || dashboardContent.activeDetailView === "packages"
                sourceComponent: UpdatesDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                }
            }
            DetailLoader {
                id: lockscreenDetailLoader
                viewName: "lockscreen"
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: LockscreenDetailSection {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                    onCloseRequested: {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) dashboardContent.root.dashboardDetail = ""
                    }
                }
            }
            DetailLoader {
                id: themeLoader
                viewName: "theme"
                active: dashboardContent.activeDetailView === "theme" || dashboardContent.activeDetailView === "wallpaper"
                visible: active
                onLoaded: if (item) item.forceActiveFocus()
                sourceComponent: ThemeWallpaperSwitcher {
                    root: dashboardContent.root
                    panel: dashboardContent.panel
                    activeMode: dashboardContent.activeDetailView === "wallpaper" ? "wallpaper" : "theme"
                    onCloseRequested: {
                        dashboardContent.activeDetailView = ""
                        if (dashboardContent.root) {
                            dashboardContent.root.dashboardDetail = ""
                            dashboardContent.root.dashboardExpanded = false
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

Item {
    id: root
    required property var theme

    function showIslandOsd(kind, value) {
        root.theme.islandOsdKind = kind
        root.theme.islandOsdValue = Math.max(0, Math.min(100, value))
        root.theme.islandOsdTick++
        root.theme.islandOsdActive = true
    }

    // ── Dynamic Island Live Activities ──

    // 1. Notification Peek Banner
    function triggerNotifPeek(app, summary, body, icon, notifId) {
        if (!app && !summary && !body) return
        root.theme.notifPeekApp = app || "Notification"
        root.theme.notifPeekSummary = summary || ""
        root.theme.notifPeekBody = body || ""
        root.theme.notifPeekIcon = icon || ""
        root.theme.notifPeekId = Number(notifId || 0)
        root.theme.notifPeekActive = true
        root.theme.notifPeekTick++
    }

    function dismissNotifPeek(notifId) {
        var nid = Number(notifId || 0)
        if (nid === 0 || root.theme.notifPeekId === 0 || nid === root.theme.notifPeekId) {
            root.theme.notifPeekActive = false
            root.theme.notifPeekDismissTick++
        }
    }

    Process { id: notifInvokeProc; command: ["bash", "-c", "true"] }

    function invokeNotification(notifId, appName) {
        var cmd = ""
        var nid = Number(notifId || 0)
        if (nid > 0 && nid < 100000000000) {
            cmd = "quickshell -p /usr/share/omarchy/shell ipc call notifications invoke " + nid
        } else if (appName && appName !== "") {
            cmd = "quickshell -p /usr/share/omarchy/shell ipc call notifications invokeApp \"" + appName + "\""
        } else {
            cmd = "quickshell -p /usr/share/omarchy/shell ipc call notifications invoke 0"
        }
        notifInvokeProc.command = ["bash", "-c", cmd + " 2>/dev/null || true"]
        notifInvokeProc.running = false
        notifInvokeProc.running = true
    }

    // 2. Timer / Pomodoro / Stopwatch Pill
    function startTimer(minutes, label) {
        var m = (minutes && minutes > 0) ? minutes : 25
        root.theme.timerMode = "countdown"
        root.theme.timerInitial = m * 60
        root.theme.timerRemaining = m * 60
        root.theme.timerLabel = label || "Focus"
        root.theme.timerPaused = false
        root.theme.timerActive = true
    }

    function toggleTimer() {
        if (!root.theme.timerActive) {
            root.theme.startTimer(25, "Focus")
            return
        }
        root.theme.timerPaused = !root.theme.timerPaused
    }

    function resetTimer() {
        root.theme.timerActive = false
        root.theme.timerPaused = false
        root.theme.timerRemaining = 0
        root.theme.timerInitial = 0
    }

    function startStopwatch() {
        root.theme.timerMode = "stopwatch"
        root.theme.timerRemaining = 0
        root.theme.timerInitial = 0
        root.theme.timerLabel = "Stopwatch"
        root.theme.timerPaused = false
        root.theme.timerActive = true
    }

    Timer {
        id: liveActivityTicker
        interval: 1000
        repeat: true
        running: root.theme.timerActive && !root.theme.timerPaused
        onTriggered: {
            if (root.theme.timerMode === "countdown") {
                if (root.theme.timerRemaining > 1) {
                    root.theme.timerRemaining -= 1
                } else {
                    root.theme.timerRemaining = 0
                    root.theme.timerActive = false
                    root.theme.triggerNotifPeek("Timer", "Focus Session Finished!", "Great work! Time for a break.", "")
                }
            } else {
                root.theme.timerRemaining += 1
            }
        }
    }

    // 3. Hardware Privacy & Screen-Share Dots
    Process {
        id: privacyProbeProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/privacy_probe.sh"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim())
                    root.theme.privacyMic = d.mic === 1
                    root.theme.privacyCam = d.cam === 1
                    root.theme.privacyScreen = d.screen === 1
                } catch(e) {}
            }
        }
    }

    Timer {
        id: privacyProbeTimer
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            privacyProbeProc.running = false
            privacyProbeProc.running = true
        }
    }

    // Real-time Notification Stream
    Process {
        id: notifStreamProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/bar/scripts/notif_stream.sh"]
        running: true
        onExited: function(exitCode, exitStatus) {
            notifStreamRestartTimer.restart()
        }
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var d = JSON.parse(line.trim())
                    if (!d) return
                    if (typeof d.count === "number") {
                        root.theme.notifCount = d.count
                    }
                    if (d.event === "dismiss") {
                        root.theme.dismissNotifPeek(d.id || 0)
                    } else if (d.event === "new" || (!d.event && (d.summary || d.body || d.app))) {
                        root.theme.triggerNotifPeek(d.app || "Notification", d.summary || "", d.body || "", d.appIcon || "", d.id || 0)
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: notifStreamRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            notifStreamProc.running = true
        }
    }

    // ── 4. Voice Dictation (voxtype) ──────────────────────────────────
    function toggleDictation() {
        Quickshell.execDetached(["bash", "-c", "systemctl --user is-active --quiet voxtype || systemctl --user start voxtype; voxtype record toggle"]);
    }

    function testDictationState(st) {
        if (!st || st === "idle") {
            root.theme.dictationState = "idle";
        } else {
            root.theme.dictationState = st;
            dictationTestTimer.restart();
        }
    }

    Timer {
        id: dictationTestTimer
        interval: 4000
        onTriggered: root.theme.dictationState = "idle"
    }

    FileView {
        id: voxtypeStateFile
        path: "/run/user/1000/voxtype/state"
        watchChanges: true
        printErrors: false
        onFileChanged: voxtypeStateFile.reload()
        onLoaded: {
            var st = String(voxtypeStateFile.text() || "").trim()
            if (!dictationTestTimer.running) root.theme.dictationState = st || "idle"
        }
        onLoadFailed: {
            if (!dictationTestTimer.running) root.theme.dictationState = "idle"
        }
    }

    // ── 5. Laptop Charging Dynamic Island Popup ───────────────────────
    function triggerChargingPopup(pct, state) {
        root.theme.chargingPopupPercent = pct || root.theme.currentBatteryPercent;
        root.theme.chargingPopupState = state || "charging";
        root.theme.chargingPopupActive = true;
        chargingPopupTimer.restart();
    }

    Timer {
        id: chargingPopupTimer
        interval: 4500
        onTriggered: root.theme.chargingPopupActive = false
    }

    // Instant event-driven reaction via UPower
    readonly property var uPowerDev: UPower.displayDevice
    readonly property int uPowerDevState: uPowerDev ? uPowerDev.state : UPowerDeviceState.Unknown
    readonly property bool uPowerCharging: uPowerDevState === UPowerDeviceState.Charging
    property int lastUPowerCharging: -1

    onUPowerChargingChanged: {
        if (uPowerDev) {
            var p = uPowerDev.percentage
            var pct = Math.round(p <= 1.0 ? p * 100 : p)
            if (!isNaN(pct) && pct > 0) root.theme.currentBatteryPercent = pct
        }
        if (lastUPowerCharging === -1) {
            lastUPowerCharging = uPowerCharging ? 1 : 0
            return
        }
        if (uPowerCharging && lastUPowerCharging !== 1) {
            lastUPowerCharging = 1
            root.theme.triggerChargingPopup(root.theme.currentBatteryPercent, "charging")
        } else if (!uPowerCharging && lastUPowerCharging === 1) {
            lastUPowerCharging = 0
            root.theme.triggerChargingPopup(root.theme.currentBatteryPercent, "discharging")
        }
    }

    FileView {
        id: acOnlineFile
        path: "/sys/class/power_supply/ACAD/online"
        printErrors: false
        onLoaded: {
            var ac = parseInt(String(acOnlineFile.text() || "").trim())
            if (!isNaN(ac)) {
                if (root.theme.prevAcOnline === 0 && ac === 1) {
                    root.theme.triggerChargingPopup(root.theme.currentBatteryPercent, "charging")
                } else if (root.theme.prevAcOnline === 1 && ac === 0) {
                    root.theme.triggerChargingPopup(root.theme.currentBatteryPercent, "discharging")
                }
                root.theme.prevAcOnline = ac
            }
        }
    }

    FileView {
        id: batCapacityFile
        path: "/sys/class/power_supply/BAT1/capacity"
        printErrors: false
        onLoaded: {
            var pct = parseInt(String(batCapacityFile.text() || "").trim())
            if (!isNaN(pct)) root.theme.currentBatteryPercent = pct
        }
    }

    Timer {
        id: powerSupplyTimer
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            batCapacityFile.reload()
            acOnlineFile.reload()
        }
    }

    Process {
        id: initPowerProfile
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo balanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim()
                if (p) root.theme.powerProfileCurrent = p
            }
        }
    }

    Process {
        id: hyprDispatchProbe
        command: ["bash", "-c", "hyprctl dispatch 'hl.dsp' 2>&1 | grep -qi 'hl\\.dispatch' && echo lua || echo classic"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { root.theme.hyprUsesLua = (this.text.trim() === "lua") }
        }
    }

    function gotoWorkspace(id) {
        if (root.theme.hyprUsesLua) {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"])
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
        }
    }
}

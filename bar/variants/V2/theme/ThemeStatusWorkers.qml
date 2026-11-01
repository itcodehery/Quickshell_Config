import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Item {
    id: root
    required property var theme

    function togglePluginsDrawer() {
        if (!root.theme.pluginsDrawerVisible) {
            root.theme.activateFocusedPopupScreen()
            if (!root.theme.activePopupScreen && Quickshell.screens.length > 0) {
                root.theme.activatePopupScreen(Quickshell.screens[0])
            }
        }
        root.theme.pluginsDrawerVisible = !root.theme.pluginsDrawerVisible
    }

    function isPluginPinned(id) {
        if (!id || !root.theme.pinnedPlugins) return false
        return root.theme.pinnedPlugins.indexOf(id) !== -1
    }

    function togglePinPlugin(id) {
        if (!id) return
        var list = (root.theme.pinnedPlugins || []).slice()
        var idx = list.indexOf(id)
        if (idx >= 0) {
            list.splice(idx, 1)
        } else {
            list.push(id)
        }
        root.theme.pinnedPlugins = list
        root.theme.savePinnedPlugins()
        root.theme.pluginsSettingsChanged()
    }

    function setPinnedPluginsList(list) {
        root.theme.pinnedPlugins = list || []
        root.theme.savePinnedPlugins()
        root.theme.pluginsSettingsChanged()
    }

    function setPluginsOrderList(list) {
        root.theme.pluginsOrder = list || []
        root.theme.savePluginsOrder()
        root.theme.pluginsSettingsChanged()
    }

    function savePinnedPlugins() {
        var jsonStr = JSON.stringify(root.theme.pinnedPlugins || [])
        pinnedSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.theme.pinnedPluginsCachePath + "')\" && printf '%s' '" + jsonStr + "' > '" + root.theme.pinnedPluginsCachePath + "'"]
        pinnedSaveProc.running = false
        pinnedSaveProc.running = true
        pinnedPluginsDataProc.running = false
        pinnedPluginsDataProc.running = true
    }

    function savePluginsOrder() {
        var jsonStr = JSON.stringify(root.theme.pluginsOrder || [])
        orderPluginsSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root.theme.pluginsOrderCachePath + "')\" && printf '%s' '" + jsonStr + "' > '" + root.theme.pluginsOrderCachePath + "'"]
        orderPluginsSaveProc.running = false
        orderPluginsSaveProc.running = true
    }

    Process { id: pinnedSaveProc }
    Process { id: orderPluginsSaveProc }

    Process {
        id: pinnedPluginsDataProc
        running: true
        command: ["python3", "-c", "import json, os, subprocess
cache_path = os.path.expanduser('~/.cache/quickshell_pinned_plugins.json')
pinned = []
try:
    with open(cache_path) as f:
        pinned = json.load(f)
except Exception:
    pinned = []

if not pinned:
    print('[]')
    exit(0)

icon_map = {
    'omarchy.clipboard': 'content_paste',
    'omarchy.emojis': 'sentiment_satisfied',
    'omarchy.image-picker': 'image',
    'omarchy.reminders': 'notifications',
    'stappmus.activity-monitor': 'show_chart',
    'omarchy.agents': 'smart_toy',
    'omarchy.disk-speedtest': 'speed',
    'omarchy.speedtest': 'network_check',
    'omarchy.wifiqr': 'qr_code_2',
    'shavanced.notification-center': 'notifications_active',
    'io.github.twiking.omasettings': 'settings',
    'bobbynicholas.omaland': 'dashboard',
    'omarchy.menu': 'menu',
    'co.klair.wallarchy': 'wallpaper',
    'crmne.hyprmoncfg': 'monitor',
    'omarchy.monitor': 'tv',
    'omarchy.dev-gallery': 'developer_mode',
    'omarchy.tailscale': 'vpn_lock',
    'omarchy.system-update': 'system_update'
}
try:
    res = subprocess.check_output(['omarchy', 'plugin', 'list', '--json'])
    plugins = json.loads(res)
    p_map = {p['id']: p for p in plugins}
    result = []
    for pid in pinned:
        p = p_map.get(pid, {})
        name = p.get('name', pid.replace('omarchy.', '').replace('-', ' ').title())
        icon = icon_map.get(pid, 'extension')
        result.append({'id': pid, 'name': name, 'icon': icon})
    print(json.dumps(result))
except Exception:
    result = [{'id': pid, 'name': pid.replace('omarchy.', '').replace('-', ' ').title(), 'icon': icon_map.get(pid, 'extension')} for pid in pinned]
    print(json.dumps(result))
"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.theme.pinnedPluginsData = JSON.parse(this.text.trim() || '[]')
                } catch(e) {}
            }
        }
    }

    Process {
        id: pinnedLoadProc
        command: ["cat", root.theme.pinnedPluginsCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text.trim() || "[]")
                    if (Array.isArray(parsed)) {
                        root.theme.pinnedPlugins = parsed
                        pinnedPluginsDataProc.running = false
                        pinnedPluginsDataProc.running = true
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: orderPluginsLoadProc
        command: ["cat", root.theme.pluginsOrderCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text.trim() || "[]")
                    if (Array.isArray(parsed)) {
                        root.theme.pluginsOrder = parsed
                    }
                } catch(e) {}
            }
        }
    }

    function refreshIdleStatus() {
        if (!root.theme._idleBackendChecked) return
        if (root.theme._idleOmarchyShellSystem) {
            idleStateFile.reload()
            return
        }
        if (!idleProc.running) idleProc.running = true
    }

    function refreshStatusIndicators() {
        root.theme.refreshIdleStatus()
        root.theme.refreshNotificationStatus()
    }

    function reprobeOmarchyShellBackends() {
        if (idleBackendProc.running || notifBackendProc.running) {
            root.theme._omarchyBackendReprobePending = true
            return
        }
        root.theme._omarchyBackendReprobePending = false
        idleBackendProc.running = true
        notifBackendProc.running = true
    }

    function finishOmarchyBackendReprobe() {
        if (idleBackendProc.running || notifBackendProc.running) return
        if (root.theme._omarchyBackendReprobePending) {
            omarchyBackendProbeDebounce.restart()
            return
        }
        root.theme.scheduleOmarchyBackendRetry()
    }

    function omarchyBackendRetryNeeded() {
        return (root.theme._idleOmarchyShellSystem && !root.theme._idleOmarchyShellBackend)
            || (root.theme._notifOmarchyShellSystem && !root.theme._notifOmarchyShellBackend)
    }

    function scheduleOmarchyBackendRetry() {
        if (!root.theme.omarchyBackendRetryNeeded()) {
            omarchyBackendRetryTimer.stop()
            root.theme._omarchyBackendRetryIndex = 0
            return
        }
        if (omarchyBackendConfirmTimer.running || omarchyBackendRetryTimer.running
                || root.theme._omarchyBackendRetryIndex >= root.theme._omarchyBackendRetryDelays.length) return
        omarchyBackendRetryTimer.interval = root.theme._omarchyBackendRetryDelays[root.theme._omarchyBackendRetryIndex]
        root.theme._omarchyBackendRetryIndex++
        omarchyBackendRetryTimer.restart()
    }

    function resetOmarchyBackendProbes() {
        omarchyBackendRetryTimer.stop()
        root.theme._omarchyBackendRetryIndex = 0
        omarchyBackendProbeDebounce.restart()
        omarchyBackendConfirmTimer.restart()
    }

    function parseNotificationsState(text) {
        try {
            var parsed = JSON.parse(String(text || "{}"))
            root.theme.notifSilenced = parsed && parsed.dnd === true
        } catch (e) {
            root.theme.notifSilenced = false
        }
    }

    function refreshNotificationStatus() {
        if (!root.theme._notifBackendChecked) return
        if (root.theme._notifOmarchyShellSystem) {
            notificationsStateFile.reload()
            return
        }
        if (!dndProc.running) dndProc.running = true
    }

    function refreshRecordingStatus() {
        if (recordingPidProc.running) {
            root.theme._recordingRefreshPending = true
            return
        }
        recordingPidProc.running = true
    }

    function reconcileSlowStatusIndicators() {
        root.theme.refreshRecordingStatus()
    }

    function setScreenRecordingPid(pid) {
        pid = String(pid || "").trim()
        if (pid === root.theme._screenRecordingPid) return

        root.theme._screenRecordingPid = pid
        if (pid === "") {
            root.theme.screenRecording = false
            root.theme.screenRecordingElapsed = 0
            root.theme._screenRecordingBaseElapsed = 0
            root.theme._screenRecordingBaseMs = 0
            root.theme._screenRecordingElapsedProbePid = ""
            return
        }

        root.theme.screenRecording = true
        root.theme.screenRecordingElapsed = 0
        root.theme._screenRecordingBaseElapsed = 0
        root.theme._screenRecordingBaseMs = Date.now()
        root.theme._screenRecordingElapsedProbePid = pid
        recordingElapsedProc.command = ["ps", "-o", "etimes=", "-p", pid]
        recordingElapsedProc.running = false
        recordingElapsedProc.running = true
    }

    function updateScreenRecordingElapsed() {
        if (!root.theme.screenRecording || root.theme._screenRecordingBaseMs <= 0) return
        root.theme.screenRecordingElapsed = root.theme._screenRecordingBaseElapsed + Math.floor((Date.now() - root.theme._screenRecordingBaseMs) / 1000)
    }

    function refreshVoxtypeStatus() {
        if (!root.theme.voxAvailable && !root.theme.modStatus) return
        if (voxProc.running) return
        voxProc.running = true
    }

    Process {
        id: idleBackendProc
        command: ["bash", "-c", "root=${OMARCHY_PATH:-/usr/share/omarchy}; [[ -f $root/shell/plugins/services/idle/manifest.json ]] || exit 2; command -v omarchy-shell >/dev/null 2>&1 && OMARCHY_PATH=$root omarchy-shell idle status >/dev/null 2>&1"]
        running: true
        onExited: (exitCode) => {
            root.theme._idleOmarchyShellSystem = exitCode !== 2
            root.theme._idleOmarchyShellBackend = exitCode === 0
            root.theme._idleBackendChecked = true
            root.theme.refreshIdleStatus()
            root.theme.finishOmarchyBackendReprobe()
        }
    }

    FileView {
        id: idleStateFile
        path: root.theme.idleStatePath
        watchChanges: root.theme._idleOmarchyShellSystem
        printErrors: false
        onFileChanged: idleStateFile.reload()
        onLoaded: {
            if (root.theme._idleOmarchyShellSystem) root.theme.stayAwake = true
        }
        onLoadFailed: {
            if (root.theme._idleOmarchyShellSystem) root.theme.stayAwake = false
        }
    }

    Process {
        id: notifBackendProc
        command: ["bash", "-c", "root=${OMARCHY_PATH:-/usr/share/omarchy}; [[ -f $root/shell/plugins/notifications/manifest.json ]] || exit 2; command -v omarchy-shell >/dev/null 2>&1 && OMARCHY_PATH=$root omarchy-shell notifications ping 2>/dev/null | grep -Fxq ok"]
        running: true
        onExited: (exitCode) => {
            root.theme._notifOmarchyShellSystem = exitCode !== 2
            root.theme._notifOmarchyShellBackend = exitCode === 0
            root.theme._notifBackendChecked = true
            root.theme.refreshNotificationStatus()
            root.theme.finishOmarchyBackendReprobe()
        }
    }

    FileView {
        id: notificationsStateFile
        path: root.theme.notificationsStatePath
        watchChanges: root.theme._notifOmarchyShellSystem
        printErrors: false
        onFileChanged: notificationsStateFile.reload()
        onLoaded: {
            if (root.theme._notifOmarchyShellSystem) root.theme.parseNotificationsState(notificationsStateFile.text())
        }
        onLoadFailed: {
            if (root.theme._notifOmarchyShellSystem) root.theme.notifSilenced = false
        }
    }

    Timer {
        id: omarchyBackendProbeDebounce
        interval: 250
        repeat: false
        onTriggered: root.theme.reprobeOmarchyShellBackends()
    }

    Timer {
        id: omarchyBackendRetryTimer
        repeat: false
        onTriggered: root.theme.reprobeOmarchyShellBackends()
    }

    Timer {
        id: omarchyBackendConfirmTimer
        interval: 2000
        repeat: false
        onTriggered: {
            root.theme._omarchyBackendRetryIndex = Math.max(1, root.theme._omarchyBackendRetryIndex)
            root.theme.reprobeOmarchyShellBackends()
        }
    }

    FileView {
        id: omarchyShellConfigFile
        path: root.theme.omarchyShellConfigPath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            omarchyShellConfigFile.reload()
            root.theme.resetOmarchyBackendProbes()
        }
    }

    Process {
        id: idleProc
        command: ["pgrep", "-x", "hypridle"]
        running: false
        onExited: (exitCode) => {
            if (!root.theme._idleOmarchyShellSystem) root.theme.stayAwake = exitCode !== 0
        }
    }

    Process {
        id: dndProc
        command: ["makoctl", "mode"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0 && !root.theme._notifOmarchyShellSystem) root.theme.notifSilenced = false
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.theme._notifOmarchyShellSystem) root.theme.notifSilenced = this.text.indexOf("do-not-disturb") >= 0
            }
        }
    }

    Process {
        id: recordingPidProc
        command: ["pgrep", "-o", "-f", "^gpu-screen-recorder"]
        running: false
        onExited: (exitCode) => {
            if (exitCode !== 0) root.theme.setScreenRecordingPid("")
            if (root.theme._recordingRefreshPending) {
                root.theme._recordingRefreshPending = false
                root.theme.refreshRecordingStatus()
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/)
                root.theme.setScreenRecordingPid(parts[0] || "")
            }
        }
    }

    FileView {
        id: screenRecordingStateFile
        path: root.theme.screenRecordingStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            screenRecordingStateFile.reload()
            root.theme.refreshRecordingStatus()
        }
        onLoaded: root.theme.refreshRecordingStatus()
        onLoadFailed: root.theme.refreshRecordingStatus()
    }

    Process {
        id: recordingElapsedProc
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.theme._screenRecordingElapsedProbePid !== root.theme._screenRecordingPid) return
                var elapsed = parseInt(this.text.trim())
                if (isNaN(elapsed)) elapsed = 0
                root.theme._screenRecordingBaseElapsed = Math.max(0, elapsed)
                root.theme._screenRecordingBaseMs = Date.now()
                root.theme.updateScreenRecordingElapsed()
            }
        }
    }

    Timer {
        interval: 1500
        running: root.theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: root.theme.refreshStatusIndicators()
    }

    Timer {
        interval: 45000
        running: root.theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: root.theme.reconcileSlowStatusIndicators()
    }

    Timer {
        interval: 1000
        running: root.theme.screenRecording
        repeat: true
        triggeredOnStart: true
        onTriggered: root.theme.updateScreenRecordingElapsed()
    }

    Process {
        id: voxProc
        command: ["bash", "-c",
            "if command -v voxtype >/dev/null 2>&1; then " +
            "timeout 1 voxtype status --extended --format json 2>/dev/null | jq -r '[(.class // .alt // \"idle\"), ((.tooltip // \"\") | split(\"\\n\")[0])] | @tsv' 2>/dev/null; " +
            "else echo 'MISSING'; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                if (parts[0] === "MISSING") {
                    root.theme.voxAvailable = false
                    root.theme.voxState = "idle"
                    root.theme.voxHint = ""
                    return
                }
                root.theme.voxAvailable = true
                root.theme.voxState = parts[0] || "idle"
                root.theme.voxHint = parts[1] || ""
            }
        }
    }

    Timer {
        interval: root.theme._voxActive ? 1000 : (root.theme.voxAvailable ? 10000 : 60000)
        running: root.theme._statusPollingWanted
        repeat: true
        triggeredOnStart: true
        onTriggered: root.theme.refreshVoxtypeStatus()
    }

    Process {
        command: ["bash", "-c", "systemctl is-active --quiet NetworkManager && echo 1 || echo 0"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.theme.useNM = this.text.trim() === "1" }
    }
}

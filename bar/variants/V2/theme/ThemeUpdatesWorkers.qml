import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import "Palette.js" as Palette

Item {
    id: root
    required property var theme

    function saveWidgets() {
        var line = root.theme.buildSaveWidgetsLine()
        widgetSaveProc.command = ["bash", "-c",
            "echo '" + line + "' > '" + root.theme.widgetsCachePath + "'"]
        widgetSaveProc.running = false
        widgetSaveProc.running = true
    }

    function saveDesktopMenuMode() {
        if (root.theme._desktopMenuModeLoaded) {
            desktopMenuModeSaveProc.command = ["bash", "-c",
                "printf '%s' '" + (root.theme.desktopMenuListMode ? "1" : "0") + "' > '" + root.theme.desktopMenuModeCachePath + "'"]
            desktopMenuModeSaveProc.running = false
            desktopMenuModeSaveProc.running = true
        }
    }

    Process {
        id: widgetLoadProc
        command: ["cat", root.theme.widgetsCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.theme.parseLoadedWidgets(this.text)
            }
        }
    }

    Process { id: widgetSaveProc }

    Process {
        id: desktopMenuModeLoadProc
        command: ["cat", root.theme.desktopMenuModeCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t === "1" || t === "list") root.theme.desktopMenuListMode = true
                else if (t === "0" || t === "radial") root.theme.desktopMenuListMode = false
                root.theme._desktopMenuModeLoaded = true
            }
        }
    }
    Process { id: desktopMenuModeSaveProc }

    function archGateRescan() { archGate.rerun() }

    Process {
        id: archGate
        // Hang on the DATA, not the refresh trigger: archRefreshTick fires the
        // refresh, but archUpdates is only filled when the refresh finishes — so
        // watching the tick would scan the PREVIOUS list. Watch archUpdates.
        property var watched: root.theme.archUpdates
        onWatchedChanged: rerun()
        // A rerun restarts even a live scan (running=false→true). That kill makes
        // onExited see a nonzero (terminated) exit; flag it so onExited does NOT
        // mistake the deliberate kill for a crash and force degraded — that false
        // degraded could land AFTER a clean scan and stick ("protection limited" +
        // no "mirrors ✓" despite a healthy feed).
        property bool killing: false
        function rerun() {
            if (running) killing = true
            running = false   // restart even if a previous scan is still running
            root.theme.archGateResults = []
            root.theme.archGateOk = 0; root.theme.archGateWarn = 0; root.theme.archGateFail = 0
            root.theme.archGateBlacklist = 0; root.theme.archGateDegraded = false
            root.theme.archGateStale = false; root.theme.archGateMirrorsAgree = false; root.theme.archGateMirrorMismatch = false
            // Run the gate even with 0 updates — it still emits the meta line, so the
            // panel can always show the blacklist size / protection status.
            root.theme.archGateState = (root.theme.archUpdates && root.theme.archUpdates.length > 0)
                ? "scanning" : "clean"
            stdinEnabled = true   // re-arm stdin each run — onStarted sets it false to send EOF; without this the 2nd+ run reads disabled stdin and hangs in 'scanning'
            running = true
        }
        command: ["bash", Quickshell.env("HOME") + "/.local/bin/qs-arch-security-gate.sh"]
        stdinEnabled: true
        onStarted: {
            // Feed "pkg|repo|old|new" — exactly the gate's stdin format.
            var ups = root.theme.archUpdates || []
            for (var i = 0; i < ups.length; i++) {
                var u = ups[i]
                var repo = (u.source === "aur") ? "aur" : "system"
                write(u.name + "|" + repo + "|" + (u.oldVer || "") + "|" + (u.newVer || "") + "\n")
            }
            stdinEnabled = false   // EOF → gate finishes
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var results = [], ok = 0, warn = 0, fail = 0, sawMeta = false
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var s = lines[i].trim(); if (!s) continue
                    var o; try { o = JSON.parse(s) } catch (e) { continue }
                    if (o.meta === "gate") {
                        sawMeta = true
                        root.theme.archGateBlacklist = o.blacklist || 0
                        if (o.degraded) root.theme.archGateDegraded = true
                        if (o.list_date) root.theme.archGateListDate = o.list_date
                        if (o.stale) root.theme.archGateStale = true
                        root.theme.archGateMirrorsAgree = (o.mirrors_agree === true)
                        root.theme.archGateMirrorMismatch = (o.mirror_mismatch === true)
                        continue
                    }
                    results.push(o)
                    if (o.verdict === "FAIL") fail++
                    else if (o.verdict === "WARN") warn++
                    else ok++
                }
                root.theme.archGateResults = results
                root.theme.archGateOk = ok; root.theme.archGateWarn = warn; root.theme.archGateFail = fail
                // Fail-CLOSED: if the gate didn't fully respond (no meta line, or a
                // package has no verdict — gate missing/crashed/partial), do NOT
                // claim "clean". An empty/short answer means "unverified", not "safe".
                if (!sawMeta || results.length !== (root.theme.archUpdates || []).length)
                    root.theme.archGateDegraded = true
                root.theme.archGateState =
                    fail > 0 ? "blocked"
                    : root.theme.archGateDegraded ? "degraded"
                    : warn > 0 ? "warn" : "clean"
            }
        }
        onExited: (exitCode) => {
            if (killing) { killing = false; return }   // we restarted it on purpose, not a crash
            // Gate exited nonzero (missing script, crash) => force degraded so the
            // panel never shows a false all-clear.
            if (exitCode !== 0) {
                root.theme.archGateDegraded = true
                if (root.theme.archGateFail === 0 && root.theme.archGateWarn === 0)
                    root.theme.archGateState = "degraded"
            }
        }
    }

    function updateShellProgressClock() {
        root.theme.shellProgressNowEpoch = Math.floor(Date.now() / 1000)
    }

    function resetShellProgress() {
        root.theme.shellProgressRunId = ""
        root.theme.shellProgressState = "idle"
        root.theme.shellProgressPhase = ""
        root.theme.shellProgressStep = 0
        root.theme.shellProgressTotalSteps = 5
        root.theme.shellProgressTargetCommit = ""
        root.theme.shellProgressStartedEpoch = 0
        root.theme.shellProgressUpdatedEpoch = 0
        root.theme.shellProgressScreenName = ""
        root.theme.shellProgressError = ""
        root.theme.shellProgressAcknowledged = true
        root.theme.shellProgressPanelOpen = true
    }

    function openShellProgressPanel() {
        root.theme.activatePopupScreenByName(root.theme.shellProgressScreenName)
        root.theme.activeUpdateTab = "shell"
        root.theme.archVisible = true
    }

    function resetShellUpdateState() {
        root.theme.shellUpdateBehind = 0
        root.theme.shellUpdateSummary = []
        root.theme.shellUpdateVersion = ""
        root.theme.shellUpdateChecked = ""
        root.theme.shellUpdateBaseCommit = ""
        root.theme.shellUpdateTargetCommit = ""
        root.theme.shellUpdateRepository = ""
        root.theme.shellUpdateUpstreamRef = ""
    }

    function parseShellUpdateState(raw) {
        try {
            var j = JSON.parse(raw)
            if (j.schemaVersion !== 5) {
                root.theme.resetShellUpdateState()
                return
            }
            root.theme.shellUpdateBehind = j.behind || 0
            root.theme.shellUpdateSummary = j.summary || []
            root.theme.shellUpdateVersion = j.version || ""
            root.theme.shellUpdateChecked = j.checked || ""
            root.theme.shellUpdateBaseCommit = j.baseCommit || ""
            root.theme.shellUpdateTargetCommit = j.targetCommit || ""
            root.theme.shellUpdateRepository = j.repository || ""
            root.theme.shellUpdateUpstreamRef = j.upstreamRef || ""
        } catch (e) {
            root.theme.resetShellUpdateState()
        }
    }

    function parseShellInstalledCommit(raw) {
        root.theme.shellInstalledCommit = raw.trim()
    }

    function parseShellProgress(raw) {
        try {
            var j = JSON.parse(raw)
            if (j.schemaVersion !== 1) {
                root.theme.resetShellProgress()
                return
            }

            root.theme.shellProgressRunId = j.runId || ""
            root.theme.shellProgressState = j.state || "idle"
            root.theme.shellProgressPhase = j.phase || ""
            root.theme.shellProgressStep = j.step || 0
            root.theme.shellProgressTotalSteps = j.totalSteps || 5
            root.theme.shellProgressTargetCommit = j.targetCommit || ""
            root.theme.shellProgressStartedEpoch = j.startedEpoch || 0
            root.theme.shellProgressUpdatedEpoch = j.updatedEpoch || 0
            root.theme.shellProgressScreenName = j.screenName || ""
            root.theme.shellProgressError = j.error || ""
            root.theme.shellProgressAcknowledged = j.acknowledged === true
            root.theme.shellProgressPanelOpen = j.panelOpen !== false
            root.theme.updateShellProgressClock()

            if (root.theme.shellUpdateProgressVisible && root.theme.shellProgressPanelOpen) root.theme.openShellProgressPanel()
            if (root.theme.shellProgressRunning
                    && root.theme.shellProgressPhase === "restarting"
                    && root.theme.shellProgressRunId !== ""
                    && root.theme._shellProgressCompleteRunId !== root.theme.shellProgressRunId) {
                root.theme._shellProgressCompleteRunId = root.theme.shellProgressRunId
                shellProgressCompleteProc.command = [
                    "bash",
                    Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh",
                    "--complete-progress",
                    root.theme.shellProgressRunId
                ]
                shellProgressCompleteProc.running = false
                shellProgressCompleteProc.running = true
            }
        } catch (e) {
            root.theme.resetShellProgress()
        }
    }

    function ackShellProgress() {
        if (!root.theme.shellProgressRunId) return
        shellProgressAckProc.command = [
            "bash",
            Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh",
            "--ack-progress",
            root.theme.shellProgressRunId
        ]
        shellProgressAckProc.running = false
        shellProgressAckProc.running = true
    }

    function setShellProgressPanelOpen(open) {
        if (!root.theme.shellProgressRunId || !root.theme.shellUpdateProgressVisible) return
        root.theme.shellProgressPanelOpen = open
        shellProgressPanelProc.command = [
            "bash",
            Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh",
            "--progress-panel",
            root.theme.shellProgressRunId,
            open ? "open" : "closed"
        ]
        shellProgressPanelProc.running = false
        shellProgressPanelProc.running = true
    }

    function closeArchUpdatesPanel() {
        if (root.theme.shellUpdateProgressVisible) root.theme.setShellProgressPanelOpen(false)
        root.theme.archVisible = false
    }

    function showShellUpdateTabFromWidget() {
        if (root.theme.shellUpdateProgressVisible) root.theme.setShellProgressPanelOpen(true)
        root.theme.activeUpdateTab = "shell"
        root.theme.archVisible = true
    }

    function reloadShellUpdateState() {
        shellUpdateStateFile.reload()
        shellInstalledCommitFile.reload()
        shellProgressFile.reload()
    }

    Timer {
        interval: 15000
        running: root.theme.shellProgressState === "running"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.theme.updateShellProgressClock()
    }

    FileView {
        id: shellUpdateStateFile
        path: Quickshell.env("HOME") + "/.cache/qs-shell/update-available.json"
        watchChanges: true
        printErrors: false
        onFileChanged: shellUpdateStateFile.reload()
        onLoaded: root.theme.parseShellUpdateState(shellUpdateStateFile.text())
        onLoadFailed: root.theme.resetShellUpdateState()
    }

    FileView {
        id: shellInstalledCommitFile
        path: Quickshell.env("HOME") + "/.config/quickshell/bar/.qsrise-commit"
        watchChanges: true
        printErrors: false
        onFileChanged: shellInstalledCommitFile.reload()
        onLoaded: root.theme.parseShellInstalledCommit(shellInstalledCommitFile.text())
        onLoadFailed: root.theme.shellInstalledCommit = ""
    }

    FileView {
        id: shellProgressFile
        path: Quickshell.env("HOME") + "/.cache/qs-shell/apply-status.json"
        watchChanges: true
        printErrors: false
        onFileChanged: shellProgressFile.reload()
        onLoaded: root.theme.parseShellProgress(shellProgressFile.text())
        onLoadFailed: root.theme.resetShellProgress()
    }

    Process {
        id: shellProgressCompleteProc
        command: ["true"]
        onExited: shellProgressFile.reload()
    }

    Process {
        id: shellProgressAckProc
        command: ["true"]
        onExited: {
            shellProgressFile.reload()
            root.theme.archVisible = false
        }
    }

    Process {
        id: shellProgressPanelProc
        command: ["true"]
        onExited: shellProgressFile.reload()
    }

    function reloadCurrentThemeFiles() {
        if (!root.theme.omarchyCurrentRootResolved) return
        themeReloadDebounce.restart()
    }

    Process {
        id: omarchyCurrentRootProbe
        command: ["bash", "-c",
            "state=\"$HOME/.local/state/omarchy/current\"; legacy=\"$HOME/.config/omarchy/current\"; " +
            "if command -v omarchy-shell >/dev/null 2>&1 && [ -d \"$state\" ] && [ -d /usr/share/omarchy ]; then printf '%s\\t%s\\n' \"$state\" /usr/share/omarchy; " +
            "elif [ -d \"$legacy\" ]; then printf '%s\\t%s\\n' \"$legacy\" \"$HOME/.local/share/omarchy\"; " +
            "else printf '%s\\t%s\\n' \"$legacy\" \"$HOME/.local/share/omarchy\"; fi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("\t")
                var resolved = parts.length > 0 ? parts[0] : ""
                var installRoot = parts.length > 1 ? parts[1] : ""
                if (resolved) root.theme.omarchyCurrentRoot = resolved
                if (installRoot) root.theme.omarchyInstallRoot = installRoot
                root.theme.omarchyCurrentRootResolved = true
                currentThemeNameWatcher.reload()
                root.theme.reloadCurrentThemeFiles()
            }
        }
    }

    Timer {
        id: themeReloadDebounce
        interval: 40
        repeat: false
        onTriggered: {
            paletteReader.running = false
            paletteReader.running = true
        }
    }

    // Omarchy writes theme.name immediately after the complete theme directory
    // swap, before its slower application retint commands and final hooks.
    FileView {
        id: currentThemeNameWatcher
        path: root.theme.themeNamePath
        watchChanges: root.theme.omarchyCurrentRootResolved
        printErrors: false
        onLoaded: {
            root.theme.setCurrentThemeName(currentThemeNameWatcher.text())
            root.theme.reloadCurrentThemeFiles()
        }
        onLoadFailed: root.theme.setCurrentThemeName("")
        onFileChanged: {
            reload()
            root.theme.reloadCurrentThemeFiles()
        }
    }

    Process {
        id: paletteReader
        command: ["cat", root.theme.colorsPath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                Palette.apply(root.theme, Palette.parse(this.text));
            }
        }
    }

    function ipcApplyTheme(payload) {
        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.apply: bad payload —", e); return; }
        if (!p || !p.colors) return;
        Palette.apply(root.theme, Palette.mapKeys(p.colors));
        root.theme.lastAppliedName = p.name || "";
    }

    function ipcApplyLauncher(payload) {
        let p;
        try { p = JSON.parse(payload); }
        catch (e) { console.warn("theme.applyLauncher: bad payload —", e); return; }
        root.theme.applyLauncherConfig(p);
    }

    function ipcReloadTheme() {
        paletteReader.running = false;
        paletteReader.running = true;
    }

    function ipcOpenPicker(mode) {
        if (mode === "theme" || mode === "wallpaper") root.theme.openImagePicker(mode)
        else if (mode === "screenshots" || mode === "videos") root.theme.openMediaBrowser(mode)
    }

    // Standalone compatibility while the integrated bootstrap is being rolled
    // out. VariantRoot supplies variantHost, so only the common IPC router owns
    // these targets in integrated mode.
    LazyLoader {
        active: root.theme.variantHost === null
        IpcHandler {
            target: "theme"
            function apply(payload: string) { root.theme.ipcApplyTheme(payload) }
            function applyLauncher(payload: string) { root.theme.ipcApplyLauncher(payload) }
            function reload() { root.theme.ipcReloadTheme() }
        }
    }

    LazyLoader {
        active: root.theme.variantHost === null
        IpcHandler {
            target: "picker"
            function theme() { root.theme.ipcOpenPicker("theme") }
            function wallpaper() { root.theme.ipcOpenPicker("wallpaper") }
            function screenshots() { root.theme.ipcOpenPicker("screenshots") }
            function videos() { root.theme.ipcOpenPicker("videos") }
        }
    }

    LazyLoader {
        active: root.theme.variantHost === null
        IpcHandler {
            target: "charging"
            function test(pct: int, state: string) { root.theme.triggerChargingPopup(pct, state) }
        }
    }

    LazyLoader {
        active: root.theme.variantHost === null
        IpcHandler {
            target: "dictation"
            function toggle() { root.theme.toggleDictation() }
        }
    }
}

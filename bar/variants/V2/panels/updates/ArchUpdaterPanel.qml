import QtQuick
import ".."
import "../../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: archPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-arch-updater"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6
    // Shared theme-table grid. Keeping the header and delegate on these exact
    // tokens makes the five-part action/info block a stable right-aligned unit.
    readonly property int themeGridGap: 6
    readonly property int themeActionsWidth: 132
    readonly property int themeBehindWidth: 60
    readonly property int themeStateWidth: 60
    readonly property int themeRightBlockWidth: themeActionsWidth
        + themeBehindWidth + themeStateWidth + themeGridGap * 2

    readonly property url packageFrontendUrl: Qt.resolvedUrl("../../../../core/qs-system-update.sh")
    readonly property string packageFrontendScript: decodeURIComponent(
        String(packageFrontendUrl).replace(/^file:\/\//, ""))
    readonly property string packageApplyScript: Quickshell.env("HOME") + "/.local/bin/qs-arch-apply-update.sh"
    property string packageUpdateBackend: "detecting"
    property string packageUpdateMode: ""
    property string packageUpdateCommand: ""
    property string packageApplyProtocol: ""
    property bool packageBackendProbeResolved: false
    readonly property bool usesOmarchyUpdater: packageUpdateBackend === "omarchy"
    readonly property bool packageUpdateBackendAvailable: usesOmarchyUpdater
        ? packageUpdateCommand !== ""
        : packageUpdateBackend === "arch"
            && packageUpdateCommand !== ""
            && packageApplyProtocol === "2"

    property alias panelUpdateRunner: panelUpdateRunner

    function failPackageBackendProbe() {
        if (packageUpdateBackend !== "detecting") return
        packageUpdateBackend = "probe-failed"
        packageUpdateMode = ""
        packageUpdateCommand = ""
        packageApplyProtocol = ""
        packageBackendProbeResolved = false
    }

    function retryPackageBackendProbe() {
        // `running` stays true while SIGTERM is still being reaped. Waiting for
        // it to become false prevents an old onExited from landing in a new run.
        if (packageBackendProbe.running
                || packageUpdateBackend === "detecting"
                || packageUpdateBackendAvailable) return
        packageUpdateMode = ""
        packageUpdateCommand = ""
        packageApplyProtocol = ""
        packageBackendProbeResolved = false
        packageUpdateBackend = "detecting"
        packageBackendProbe.running = true
    }

    Process {
        id: packageBackendProbe
        // This side-effect-free adapter ships in the same atomic QML generation.
        // Never probe an older privileged apply helper with an unknown argument.
        command: [archPanel.packageFrontendScript, "--probe", archPanel.packageApplyScript]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var line = String(this.text || "").split("\n")[0].replace(/\r$/, "")
                var parts = line.split("\t")
                if (parts.length !== 4) return
                var backend = parts[0]
                var mode = parts[1]
                var commandPath = parts[2]
                var protocol = parts[3]
                var relationOk = (backend === "omarchy" && (mode === "update" || mode === "cli")
                        && commandPath.indexOf("/") === 0)
                     || (backend === "arch" && mode === "apply" && commandPath.indexOf("/") === 0)
                     || ((backend === "omarchy-broken" || backend === "unsupported")
                        && mode === "none" && commandPath === "")
                if (!relationOk || (protocol !== "2" && protocol !== "legacy" && protocol !== "missing"))
                    return
                archPanel.packageUpdateBackend = backend
                archPanel.packageUpdateMode = mode
                archPanel.packageUpdateCommand = commandPath
                archPanel.packageApplyProtocol = protocol
                archPanel.packageBackendProbeResolved = true
                packageBackendProbeTimeout.stop()
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && !archPanel.packageBackendProbeResolved)
                archPanel.failPackageBackendProbe()
        }
    }

    Timer {
        id: packageBackendProbeTimeout
        interval: 2000
        running: archPanel.packageUpdateBackend === "detecting"
        repeat: false
        onTriggered: {
            archPanel.failPackageBackendProbe()
            packageBackendProbe.running = false
        }
    }

    Process {
        id: panelUpdateRunner
        // No default command: package updates and theme-terminal launches build
        // the command only on click, so an accidental start cannot run anything.
        command: []
    }

    // Theme removal is deliberately panel-native: confirmation, progress and
    // errors stay in this window, and no presentation terminal is spawned.
    property string pendingRemoveName: ""
    property bool removeBusy: false
    property string removeError: ""
    property bool removeCommandFinished: false
    property int removeResultCode: -1
    property string removeResultDetail: ""

    Process {
        id: themeRemoveProc
        command: []
        running: false
        stdout: StdioCollector { id: themeRemoveStdout }
        stderr: StdioCollector { id: themeRemoveStderr }
        onExited: (exitCode) => {
            var detail = String(themeRemoveStderr.text || themeRemoveStdout.text || "").trim()
            if (detail !== "") detail = detail.split(/\r?\n/)[0]
            archPanel.removeResultCode = exitCode
            archPanel.removeResultDetail = detail
            archPanel.removeCommandFinished = true
            archPanel.finishThemeRemoveIfReady()
        }
    }

    // Keep the panel-native progress state visible long enough to be perceived.
    // The command starts immediately; only the row's final UI transition waits.
    Timer {
        id: themeRemoveMinimumTimer
        interval: 300
        repeat: false
        onTriggered: archPanel.finishThemeRemoveIfReady()
    }

    // ── Theme-updates backend (this panel is the single instance in shell.qml,
    //    so the check runs ONCE, not per-monitor like the bar widgets would). The
    //    FileView publishes the read-only cache into root.themeUpd*; the button
    //    (Themes tab) bumps root.themeCheckTick to run the check script. ──
    function publishThemeState() {
        try {
            var j = JSON.parse(themeState.text())
            root.themeUpdTotal        = j.total      || 0
            root.themeUpdReachable    = j.reachable  || 0
            root.themeUpdOutdated     = j.outdated   || 0
            root.themeUpdLocalEdits   = j.localEdits || 0
            root.themeUpdDegraded     = !!j.degraded
            root.themeUpdCurrentStale = !!j.currentStale
            root.themeUpdChecked      = j.checked   || ""
            root.themeUpdList         = j.themes    || []
        } catch (e) {
            // keep the last good values on a malformed read
        }
    }

    FileView {
        id: themeState
        path: Quickshell.env("HOME") + "/.cache/qs-theme-updates.json"
        watchChanges: true
        onFileChanged: themeState.reload()
        onLoaded: archPanel.publishThemeState()
        // no onLoadFailed reset: absence just means "never checked" (themeUpdChecked stays "")
    }

    Process {
        id: themeCheckProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/bin/qs-theme-update-check.sh"]
        running: false
        onExited: {
            root.themeUpdChecking = false
            themeCheckWatchdog.stop()
            themeState.reload()   // pick up the freshly written cache immediately
        }
    }

    // unstick the button if the check ever hangs past its own 180s budget
    Timer {
        id: themeCheckWatchdog
        interval: 190000
        onTriggered: { root.themeUpdChecking = false; themeCheckProc.running = false }
    }

    property int themeCheckTrigger: root.themeCheckTick
    onThemeCheckTriggerChanged: {
        if (root.themeUpdChecking) return
        root.themeUpdChecking = true
        themeCheckWatchdog.restart()
        themeCheckProc.running = false
        themeCheckProc.running = true
    }

    property real reveal: root.archVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.archVisible ? 160 : 120
            easing.type: root.archVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.archVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: archPanel.closeOrCancelRemove()
    }

    function refreshPackagesTabState() {
        archPanel.nowEpoch = Math.floor(Date.now() / 1000)
        archPanel.retryPackageBackendProbe()
        root.archGateRescan()
        if (root.archUpdates.length === 0) root.archRefreshTick++
    }

    // Packages tab only: show the blacklist/protection status instantly (the gate
    // only reads a local file — no need to wait for the slow package check), and
    // kick a package check if there is no data yet. Opening Themes/Shell must not
    // start package work as a side effect.
    Connections {
        target: root
        function onArchVisibleChanged() {
            if (!root.archVisible) {
                if (!archPanel.removeBusy) archPanel.cancelRemoveTheme()
                return
            }
            if (root.activeUpdateTab === "packages") archPanel.refreshPackagesTabState()
        }
        function onActiveUpdateTabChanged() {
            if (root.archVisible && root.activeUpdateTab === "packages") archPanel.refreshPackagesTabState()
        }
        function onArchScanCheckedEpochChanged() {
            archPanel.nowEpoch = Math.floor(Date.now() / 1000)
        }
    }

    // pkg -> gate verdict, rebuilt once per gate run (avoids O(n²) per-row scans)
    readonly property var gateMap: {
        var m = ({})
        var r = root.archGateResults || []
        for (var i = 0; i < r.length; i++) m[r[i].pkg] = r[i]
        return m
    }

    // ── Full-repo update policy ──
    // AUR packages are never part of a pacman transaction. For official repo
    // packages, the safe boundary is all-or-nothing: if any repo package is not
    // scanned and OK, block the entire system upgrade. Never filter packages out
    // of pacman's transaction from this UI, because that can create an unsupported
    // partial upgrade.
    readonly property int repoUpdatePackages: {
        var n = 0, u = root.archUpdates || []
        for (var i = 0; i < u.length; i++)
            if (u[i].source !== "aur") n++
        return n
    }
    readonly property int repoOkPackages: {
        var n = 0, r = root.archGateResults || []
        for (var i = 0; i < r.length; i++)
            if (r[i].repo !== "aur" && r[i].verdict === "OK") n++
        return n
    }
    readonly property int aurReviewPackages: {
        var n = 0, r = root.archGateResults || []
        for (var i = 0; i < r.length; i++)
            if (r[i].repo === "aur" && r[i].verdict === "WARN") n++
        return n
    }
    readonly property int btnCount: aurReviewPackages > 0 ? 3 : 2
    property int nowEpoch: Math.floor(Date.now() / 1000)
    Timer {
        interval: 30000
        running: root.archVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: archPanel.nowEpoch = Math.floor(Date.now() / 1000)
    }
    readonly property bool repoScanFresh: root.archScanCheckedEpoch > 0
        && (nowEpoch - root.archScanCheckedEpoch) >= 0
        && (nowEpoch - root.archScanCheckedEpoch) <= root.archScanMaxAge
    readonly property bool repoScanMatchesUpdates: root.archScanSystemCount === repoUpdatePackages
    readonly property bool repoGateComplete: (root.archGateResults || []).length === (root.archUpdates || []).length
    readonly property bool repoGateAllowsFullUpgrade: repoUpdatePackages > 0
        && repoScanFresh
        && repoScanMatchesUpdates
        && repoGateComplete
        && repoOkPackages === repoUpdatePackages
        && (root.archGateState === "clean" || root.archGateState === "warn")
        && !root.archGateDegraded
    // Omarchy owns a broader transaction (system, migrations, AUR, tooling).
    // Its launcher is intentionally independent from this advisory package gate.
    readonly property bool canUpdate: packageUpdateBackendAvailable
        && (usesOmarchyUpdater || repoGateAllowsFullUpgrade)
    readonly property string repoBlockReason: {
        if (repoUpdatePackages === 0) return "No pacman updates"
        if (!repoScanFresh) return "Repo upgrade blocked: refresh scan"
        if (!repoScanMatchesUpdates) return "Repo upgrade blocked: scan drift"
        if (root.archGateState === "scanning") return "Scanning packages"
        if (!repoGateComplete) return "Repo upgrade blocked: scan incomplete"
        if (root.archGateDegraded) return "Repo upgrade blocked: protection limited"
        if (root.archGateFail > 0 || root.archGateState === "blocked") return "Repo upgrade blocked: package blocked"
        if (repoOkPackages !== repoUpdatePackages) return "Repo upgrade blocked: unverified package"
        return ""
    }
    readonly property string repoBlockButtonText: {
        if (packageUpdateBackend === "detecting") return "Detecting updater"
        if (packageUpdateBackend === "probe-failed") return "Updater detection failed"
        if (packageUpdateBackend === "omarchy-broken") return "Omarchy updater missing"
        if (packageUpdateBackend === "unsupported") return "Updater unavailable"
        if (packageUpdateBackend === "arch" && packageApplyProtocol !== "2")
            return "Update shell helper"
        if (repoUpdatePackages === 0) return "No updates"
        if (!repoScanFresh) return "Refresh required"
        if (!repoScanMatchesUpdates) return "Scan drift"
        if (root.archGateState === "scanning") return "Scanning"
        if (!repoGateComplete) return "Scan incomplete"
        if (root.archGateDegraded) return "Protection limited"
        if (root.archGateFail > 0 || root.archGateState === "blocked") return "Package blocked"
        if (repoOkPackages !== repoUpdatePackages) return "Unverified package"
        return archPanel.repoBlockReason
    }
    readonly property string packageUpdateButtonText: usesOmarchyUpdater
        ? "Open Omarchy update"
        : "Full repo upgrade (" + repoUpdatePackages + ")"
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
    }
    function hexColor(c) {
        function h(v) {
            var x = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
            return x.length < 2 ? "0" + x : x
        }
        return "#" + h(c.r) + h(c.g) + h(c.b)
    }
    function themedGumConfirmEnv() {
        return "env -u NO_COLOR"
            + " GUM_CONFIRM_PROMPT_FOREGROUND=" + shellQuote(hexColor(root.ink))
            + " GUM_CONFIRM_PROMPT_BACKGROUND=" + shellQuote(hexColor(root.bg))
            + " GUM_CONFIRM_SELECTED_FOREGROUND=" + shellQuote(hexColor(root.paper))
            + " GUM_CONFIRM_SELECTED_BACKGROUND=" + shellQuote(hexColor(root.seal))
            + " GUM_CONFIRM_UNSELECTED_FOREGROUND=" + shellQuote(hexColor(root.ink))
            + " GUM_CONFIRM_UNSELECTED_BACKGROUND=" + shellQuote(hexColor(root.bg))
    }
    function themedGumEnvironment() {
        return [
            "GUM_CONFIRM_PROMPT_FOREGROUND=" + hexColor(root.ink),
            "GUM_CONFIRM_PROMPT_BACKGROUND=" + hexColor(root.bg),
            "GUM_CONFIRM_SELECTED_FOREGROUND=" + hexColor(root.paper),
            "GUM_CONFIRM_SELECTED_BACKGROUND=" + hexColor(root.seal),
            "GUM_CONFIRM_UNSELECTED_FOREGROUND=" + hexColor(root.ink),
            "GUM_CONFIRM_UNSELECTED_BACKGROUND=" + hexColor(root.bg)
        ]
    }
    function launchPackageUpdate(command) {
        panelUpdateRunner.command = ["env", "-u", "NO_COLOR"]
            .concat(themedGumEnvironment())
            .concat([packageFrontendScript, "--launch"])
            .concat(command)
        root.archVisible = false
        panelUpdateRunner.running = false
        panelUpdateRunner.running = true
    }

    // ── theme update = visible terminal, pinned to the checked commit ──
    // The check script records baseCommit/targetCommit. The apply script refuses
    // to move if the theme changed since the scan, if the upstream identity
    // changed, or if the saved target is no longer reachable.
    readonly property string themeCheckScript: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-theme-update-check.sh"
    readonly property string themeApplyScript: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-theme-apply-update.sh"

    function launchThemeTerminal(inner) {
        panelUpdateRunner.command = ["bash", "-c",
            "omarchy-launch-floating-terminal-with-presentation " + shellQuote(inner)]
        root.archVisible = false
        panelUpdateRunner.running = false
        panelUpdateRunner.running = true
    }

    function isPinnedThemeUpdate(t) {
        t = t || {}
        return !root.themeUpdChecking
            && t.state === "clean"
            && t.behind > 0
            && /^[A-Za-z0-9._-]+$/.test(t.name || "")
            && typeof t.baseCommit === "string" && t.baseCommit.length > 0
            && typeof t.targetCommit === "string" && t.targetCommit.length > 0
    }

    function cleanThemeNames() {
        var out = [], list = root.themeUpdList || []
        for (var i = 0; i < list.length; i++) {
            var t = list[i] || {}
            if (isPinnedThemeUpdate(t))
                out.push(t.name)
        }
        return out
    }
    function cleanThemeUpdateCount() {
        return cleanThemeNames().length
    }
    function updateAllThemes() {
        if (root.themeUpdChecking) return
        var names = cleanThemeNames()
        if (names.length <= 0) return
        launchThemeTerminal("set +e; "
            + shellQuote(themeApplyScript) + " --all; rc=$?; "
            + shellQuote(themeCheckScript) + "; exit $rc")
    }

    function updateOneTheme(name) {
        if (root.themeUpdChecking) return
        if (!/^[A-Za-z0-9._-]+$/.test(name)) return   // never build a command from a bad name
        launchThemeTerminal("set +e; "
            + shellQuote(themeApplyScript) + " " + shellQuote(name) + "; rc=$?; "
            + shellQuote(themeCheckScript) + "; exit $rc")
    }

    function themeNameFromRepoUrl(repoUrl) {
        var value = String(repoUrl || "").trim()
        if (value === "") return ""
        if (value.indexOf("://") < 0 && /^[^/:]+@[^:]+:.+/.test(value))
            value = value.substring(value.indexOf(":") + 1)
        value = value.replace(/[?#].*$/, "")
        var slash = value.lastIndexOf("/")
        var base = slash >= 0 ? value.substring(slash + 1) : value
        return base.replace(/\.git$/i, "")
                   .replace(/^omarchy-/i, "")
                   .replace(/-theme$/i, "")
                   .toLowerCase()
    }

    function isSupportedThemeRepoUrl(repoUrl) {
        var value = String(repoUrl || "").trim()
        return /^https:\/\/[^\s]+$/i.test(value)
            || /^ssh:\/\/[^\s]+$/i.test(value)
            || /^git@[^\s:]+:[^\s]+$/.test(value)
    }

    function canReinstallTheme(t) {
        t = t || {}
        var name = String(t.name || "")
        var repoUrl = String(t.remoteUrl || "")
        return !root.themeUpdChecking
            && /^[A-Za-z0-9._-]+$/.test(name)
            && isSupportedThemeRepoUrl(repoUrl)
            && themeNameFromRepoUrl(repoUrl) === name.toLowerCase()
    }

    // Reinstall the selected row from the exact origin URL recorded by the last
    // theme scan. shellQuote keeps the git URL an argument, never shell syntax.
    function reinstallTheme(name, repoUrl) {
        if (root.themeUpdChecking) return
        if (!/^[A-Za-z0-9._-]+$/.test(name || "")) return
        if (!isSupportedThemeRepoUrl(repoUrl)) return
        if (themeNameFromRepoUrl(repoUrl) !== String(name).toLowerCase()) return
        launchThemeTerminal("set +e; omarchy theme install " + shellQuote(repoUrl) + "; rc=$?; "
            + "if [ \"$rc\" -eq 0 ]; then " + shellQuote(themeCheckScript)
            + "; fi; exit \"$rc\"")
    }

    // A successful remove is already authoritative local information. Update the
    // published model/cache directly instead of blocking on 79+ network probes;
    // the explicit "Check themes" action remains the full remote refresh.
    function publishRemovedTheme(name) {
        var list = root.themeUpdList || []
        var next = []
        var removed = null
        for (var i = 0; i < list.length; i++) {
            var item = list[i] || {}
            if (String(item.name || "") === name) removed = item
            else next.push(item)
        }

        root.themeUpdList = next
        root.themeUpdTotal = Math.max(0, root.themeUpdTotal - 1)
        if (removed && removed.state !== "unreachable")
            root.themeUpdReachable = Math.max(0, root.themeUpdReachable - 1)
        if (removed && Number(removed.behind || 0) > 0)
            root.themeUpdOutdated = Math.max(0, root.themeUpdOutdated - 1)
        if (removed && removed.state === "local-edits" && Number(removed.behind || 0) > 0)
            root.themeUpdLocalEdits = Math.max(0, root.themeUpdLocalEdits - 1)
        if (removed && removed.current) root.themeUpdCurrentStale = false

        try {
            var state = JSON.parse(themeState.text())
            state.total = root.themeUpdTotal
            state.reachable = root.themeUpdReachable
            state.outdated = root.themeUpdOutdated
            state.localEdits = root.themeUpdLocalEdits
            state.currentStale = root.themeUpdCurrentStale
            state.themes = next
            themeState.setText(JSON.stringify(state))
        } catch (e) {
            // The live model is already correct. A later explicit scan repairs an
            // absent or malformed cache without delaying this local operation.
        }
    }

    // Removal is row-specific and gated by inline Remove/Cancel actions before
    // Omarchy receives the validated theme name.
    function removeTheme(name) {
        if (root.themeUpdChecking || removeBusy) return
        if (!/^[A-Za-z0-9._-]+$/.test(name || "")) return
        pendingRemoveName = String(name)
        removeError = ""
    }

    function cancelRemoveTheme() {
        if (removeBusy) return
        pendingRemoveName = ""
        removeError = ""
    }

    function confirmRemoveTheme() {
        if (removeBusy || root.themeUpdChecking) return
        var name = String(pendingRemoveName || "")
        if (!/^[A-Za-z0-9._-]+$/.test(name)) {
            removeError = "Invalid theme name"
            return
        }

        removeError = ""
        removeBusy = true
        removeCommandFinished = false
        removeResultCode = -1
        removeResultDetail = ""
        themeRemoveMinimumTimer.restart()
        themeRemoveProc.command = ["omarchy", "theme", "remove", name]
        themeRemoveProc.running = true
    }

    function finishThemeRemoveIfReady() {
        if (!removeBusy || !removeCommandFinished || themeRemoveMinimumTimer.running) return

        var removedName = pendingRemoveName
        removeBusy = false
        if (removeResultCode === 0) {
            publishRemovedTheme(removedName)
            pendingRemoveName = ""
            removeError = ""
            return
        }

        removeError = removeResultDetail !== ""
            ? removeResultDetail
            : "Remove failed (exit " + removeResultCode + ")"
    }

    function closeOrCancelRemove() {
        if (pendingRemoveName !== "") {
            cancelRemoveTheme()
            return
        }
        root.closeArchUpdatesPanel()
    }

    function viewThemeChanges(name) {
        if (!/^[A-Za-z0-9._-]+$/.test(name)) return
        var dir = Quickshell.env("HOME") + "/.config/omarchy/themes/" + name
        var git = "git -C " + shellQuote(dir)
                + " -c core.fsmonitor="
                + " -c core.hooksPath=/dev/null"
        var inner = "printf '%s\\n\\n' " + shellQuote("Theme changes: " + name) + "; "
                  + "up=$(" + git + " rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) "
                  + "|| { echo 'No upstream configured.'; exit 1; }; "
                  + "echo \"Upstream: $up\"; echo; "
                  + "echo 'Commits:'; "
                  + git + " --no-pager log --oneline --decorate HEAD..'@{upstream}' || true; "
                  + "echo; echo 'Changed files:'; "
                  + git + " --no-pager diff --no-ext-diff --no-textconv --stat HEAD..'@{upstream}' || true"
        launchThemeTerminal(inner)
    }

    // Re-apply the CURRENT theme (a separate, explicit action). A pinned update
    // only advances the theme's REPO; the live copy under current/theme is a
    // generated copy, so it stays stale until re-applied. Reads the name from
    // disk — no user-controlled string reaches the shell.
    function reapplyCurrentTheme() {
        var nameFile = root.themeNamePath
        var omarchyPath = root.omarchyInstallRoot || (Quickshell.env("HOME") + "/.local/share/omarchy")
        var inner = "n=$(tr -d '[:space:]' < " + shellQuote(nameFile) + "); "
                  + "[ -n \"$n\" ] || { echo 'no current theme'; exit 1; }; "
                  + themedGumConfirmEnv() + " gum confirm " + shellQuote("Re-apply the current theme to pick up its update?")
                  + " && OMARCHY_PATH=" + shellQuote(omarchyPath) + " omarchy-theme-set \"$n\""
        panelUpdateRunner.command = ["bash", "-c",
            "omarchy-launch-floating-terminal-with-presentation " + shellQuote(inner)]
        root.archVisible = false
        panelUpdateRunner.running = false
        panelUpdateRunner.running = true
    }

    // ── Android-shade surface tokens (in line with Control Center) ──
    readonly property int   cardRadius: 18
    readonly property int   cardPad: 12
    readonly property color cardBg:    root.fillIdle
    readonly property color chipBg:    Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
    readonly property color chipHover: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)

    Rectangle {
        id: card
        width: 560
        height: Math.min(col.implicitHeight + 28, 540)
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: archPanel.root
            ownerActive: archPanel.root.archVisible
            targetX: archPanel.root.archCaretBarX
            reveal: archPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.archBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - archPanel.reveal)
            : (barBottom + gap) - 2 * (1 - archPanel.reveal)
        opacity: archPanel.reveal
        focus: root.archVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                archPanel.closeOrCancelRemove();
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            ArchUpdaterHeader {
                archPanel: archPanel
            }

            ArchUpdaterPackagesTab {
                id: packagesTab
                archPanel: archPanel
            }

            ArchUpdaterThemesTab {
                id: themesTab
                archPanel: archPanel
            }

            ShellUpdateTab {
                width: parent.width
                root: archPanel.root
                visible: root.activeUpdateTab === "shell"
            }
        }

    }
}

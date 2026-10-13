import QtQuick
import "../modules"
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

    readonly property url packageFrontendUrl: Qt.resolvedUrl("../../../core/qs-system-update.sh")
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

    // Reusable scroll-position thumb for the update lists: appears ONLY when the
    // list overflows, height is proportional to the visible fraction, tracks
    // contentY, AND is draggable with the mouse (drag translates to contentY —
    // we never bind-fight the y). One definition used by both tabs so they can
    // never drift apart (the F2 "fixed one variant, missed the sibling" lesson).
    component ScrollThumb: Item {
        id: scrollTrack
        required property var flick
        anchors.right: parent.right
        anchors.rightMargin: -6   // sit in the right gutter, clear of the full-width row separators
        width: 14
        height: flick.height
        visible: flick.contentHeight > flick.height + 1
        readonly property real thumbHeight: flick.contentHeight > 0
            ? Math.max(24, flick.height * flick.height / flick.contentHeight)
            : 0
        readonly property real thumbY: (flick.contentHeight > flick.height)
            ? (flick.height - thumbHeight) * (flick.contentY / (flick.contentHeight - flick.height))
            : 0

        Rectangle {
            id: thumb
            anchors.horizontalCenter: parent.horizontalCenter
            y: scrollTrack.thumbY
            width: (dragMa.containsMouse || dragMa.pressed) ? 6 : 3
            height: scrollTrack.thumbHeight
            radius: width / 2
            color: Qt.rgba(archPanel.root.ink.r, archPanel.root.ink.g, archPanel.root.ink.b,
                           (dragMa.containsMouse || dragMa.pressed) ? 0.5 : 0.28)
            Behavior on width { NumberAnimation { duration: 100 } }
        }

        // A wider stationary grab target. The visible thumb moves, but this track
        // stays fixed, so drag math is stable while contentY changes.
        MouseArea {
            id: dragMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real startY: 0
            property real startContent: 0
            onPressed: (m) => {
                startY = m.y
                startContent = scrollTrack.flick.contentY
            }
            onPositionChanged: (m) => {
                if (!pressed) return
                var track = scrollTrack.flick.height - scrollTrack.thumbHeight
                if (track <= 0) return
                var scrollable = scrollTrack.flick.contentHeight - scrollTrack.flick.height
                var nc = startContent + (m.y - startY) * scrollable / track
                scrollTrack.flick.contentY = Math.max(0, Math.min(scrollable, nc))
            }
        }
    }

    // ── Android-shade surface tokens (in line with Control Center) ──
    readonly property int   cardRadius: 18
    readonly property int   cardPad: 12
    readonly property color cardBg:    root.fillIdle
    readonly property color chipBg:    Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
    readonly property color chipHover: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)

    // ── rounded section card ──
    component Card: Rectangle {
        id: _card
        default property alias content: _cardBody.data
        property string title: ""
        property string trailing: ""
        width: parent ? parent.width : 0
        implicitHeight: _cardHead.height + (_cardHead.visible ? 8 : 0) + _cardBody.implicitHeight + archPanel.cardPad * 2
        height: implicitHeight
        radius: archPanel.cardRadius
        color: archPanel.cardBg

        Item {
            id: _cardHead
            visible: _card.title !== ""
            x: archPanel.cardPad + 2
            y: archPanel.cardPad
            width: _card.width - archPanel.cardPad * 2 - 4
            height: visible ? 16 : 0
            UiText {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: _card.title
                color: root.sumiHi; font.family: root.barFont
                font.pixelSize: 11; font.weight: Font.Medium
            }
            UiText {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: _card.trailing
                visible: text !== ""
                color: root.sumi; font.family: root.barFont; font.pixelSize: 10
            }
        }
        Column {
            id: _cardBody
            x: archPanel.cardPad
            y: archPanel.cardPad + _cardHead.height + (_cardHead.visible ? 8 : 0)
            width: _card.width - archPanel.cardPad * 2
            spacing: 6
        }
    }

    // ── pill action button (Control Center style) ──
    component PillButton: Rectangle {
        id: _pb
        property string label
        property string icon: ""
        property bool primary: false
        property bool active: false
        property bool btnEnabled: true
        property color accent: root.seal
        signal clicked()
        height: 36
        radius: height / 2
        opacity: btnEnabled ? 1.0 : 0.45
        color: primary
            ? (_pbMa.containsMouse && btnEnabled ? root.fillPrimaryHover : accent)
            : active
                ? (_pbMa.containsMouse ? Qt.lighter(accent, 1.12) : accent)
                : (_pbMa.containsMouse && btnEnabled ? archPanel.chipHover : archPanel.chipBg)
        Behavior on color { ColorAnimation { duration: 120 } }
        readonly property color fgColor: (primary || active) ? root.paper : (_pbMa.containsMouse && btnEnabled ? root.seal : root.ink)
        Row {
            anchors.centerIn: parent
            spacing: 6
            IconText {
                visible: _pb.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: _pb.icon
                color: _pb.fgColor
                font.pixelSize: 16
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _pb.label
                color: _pb.fgColor
                font.family: root.barFont
                font.pixelSize: 12
                font.weight: (primary || active) ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: _pbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: _pb.btnEnabled
            cursorShape: _pb.btnEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: _pb.clicked()
        }
    }

    // ── badge toggle chip ──
    component BadgeChip: Rectangle {
        id: _bc
        property string label
        property bool active: false
        signal toggled()
        height: 26
        radius: height / 2
        color: active
            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, _bcMa.containsMouse ? 0.35 : 0.22)
            : (_bcMa.containsMouse ? archPanel.chipHover : archPanel.chipBg)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: 5
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: _bc.active ? root.seal : root.sumi
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _bc.label
                color: _bc.active ? root.ink : root.sumi
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: _bc.active ? Font.DemiBold : Font.Normal
            }
        }
        MouseArea {
            id: _bcMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: _bc.toggled()
        }
    }

    // ── status pill chip ──
    component StatusPill: Rectangle {
        id: _sp
        property string label
        property string icon: ""
        property color textColor: root.ink
        property color bgTint: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.14)
        property bool clickable: false
        signal clicked()
        height: 24
        radius: 12
        color: _spMa.containsMouse && clickable
            ? Qt.rgba(textColor.r, textColor.g, textColor.b, 0.25)
            : bgTint
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            anchors.centerIn: parent
            spacing: 5
            leftPadding: 8
            rightPadding: 8
            UiText {
                visible: _sp.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: _sp.icon
                color: _sp.textColor
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: Font.Bold
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                text: _sp.label
                color: _sp.textColor
                font.family: root.barFont
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: _spMa
            anchors.fill: parent
            hoverEnabled: _sp.clickable
            enabled: _sp.clickable
            cursorShape: _sp.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: _sp.clicked()
        }
    }

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

            // ── header ──
            Item {
                width: parent.width
                height: 40

                // Left: Squircle Icon + Title & Subtitle (Control Center style)
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Rectangle {
                        width: 38; height: 38; radius: 13
                        anchors.verticalCenter: parent.verticalCenter
                        color: archPanel.chipBg
                        IconText {
                            anchors.centerIn: parent
                            text: "system_update"
                            color: root.seal
                            font.pixelSize: 20
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        UiText {
                            text: "Updates"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        UiText {
                            text: "Software & system updates"
                            color: root.sumiHi
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }
                }

                // Right: Badge toggles + Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Badges:"
                        color: root.sumiHi
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        rightPadding: 2
                    }

                    BadgeChip {
                        width: 50
                        label: "PKG"
                        active: root.archBadgePackages
                        onToggled: root.archBadgePackages = !root.archBadgePackages
                    }
                    BadgeChip {
                        width: 68
                        label: "Themes"
                        active: root.archBadgeThemes
                        onToggled: root.archBadgeThemes = !root.archBadgeThemes
                    }
                    BadgeChip {
                        width: 56
                        label: "Shell"
                        active: root.archBadgeShell
                        onToggled: root.archBadgeShell = !root.archBadgeShell
                    }

                    Item { width: 4; height: 1 }

                    Rectangle {
                        id: closeBtn
                        width: 32; height: 32; radius: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: closeMa.containsMouse ? archPanel.chipHover : archPanel.chipBg
                        Behavior on color { ColorAnimation { duration: 120 } }
                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: closeMa.containsMouse ? root.seal : root.ink
                            font.pixelSize: 16
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: archPanel.closeOrCancelRemove()
                        }
                    }
                }
            }

            // ── Segmented Tab Switcher (Control Center style) ──
            Rectangle {
                width: parent.width
                height: 38
                radius: 19
                color: archPanel.cardBg

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "packages", label: "Packages", badge: root.archUpdates.length },
                            { id: "themes",   label: "Themes",   badge: root.themeUpdOutdated },
                            { id: "shell",    label: "Shell",    badge: root.shellUpdateBehind }
                        ]

                        Rectangle {
                            id: tabBtn
                            required property var modelData
                            width: root.evenW((parent.width - 8) / 3)
                            height: parent.height
                            radius: height / 2

                            readonly property bool active: root.activeUpdateTab === modelData.id
                            readonly property color fgColor: active ? root.paper : (tabMa.containsMouse ? root.seal : root.ink)

                            color: active
                                ? (tabMa.containsMouse ? Qt.lighter(root.seal, 1.08) : root.seal)
                                : (tabMa.containsMouse ? archPanel.chipHover : "transparent")
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                UiText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tabBtn.modelData.label
                                    color: tabBtn.fgColor
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: tabBtn.active ? Font.DemiBold : Font.Medium
                                }

                                Rectangle {
                                    visible: tabBtn.modelData.badge > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(18, badgeTxt.implicitWidth + 8)
                                    height: 18
                                    radius: 9
                                    color: tabBtn.active
                                        ? Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.22)
                                        : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2)
                                    UiText {
                                        id: badgeTxt
                                        anchors.centerIn: parent
                                        text: String(tabBtn.modelData.badge)
                                        color: tabBtn.fgColor
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeUpdateTab = tabBtn.modelData.id
                            }
                        }
                    }
                }
            }

            // ══════════ PACKAGES TAB ══════════
            Column {
                id: packagesTab
                width: parent.width
                spacing: 8
                visible: root.activeUpdateTab === "packages"

                // ── Status pills row ──
                Flow {
                    width: parent.width
                    spacing: 6

                    // OK count
                    StatusPill {
                        visible: root.archUpdates.length > 0
                        icon: "✓"
                        label: root.archGateOk + " OK"
                        textColor: root.green
                    }

                    // Review count
                    StatusPill {
                        visible: root.archGateWarn > 0
                        icon: "⚠"
                        label: root.archGateWarn + " review"
                        textColor: root.inkDeep
                    }

                    // Blocked count
                    StatusPill {
                        visible: root.archGateFail > 0
                        icon: "✗"
                        label: root.archGateFail + " blocked"
                        textColor: root.sealRaw
                    }

                    // Degraded
                    StatusPill {
                        visible: root.archGateDegraded
                        icon: "⚠"
                        label: "protection limited"
                        textColor: root.sealRaw
                    }

                    // Stale
                    StatusPill {
                        visible: root.archGateStale
                        icon: "⚠"
                        label: "source stale"
                        textColor: root.sealRaw
                    }

                    // Mirrors agree
                    StatusPill {
                        visible: root.archGateMirrorsAgree && !root.archGateDegraded
                        icon: "✓"
                        label: "mirrors synced"
                        textColor: root.green
                    }

                    // Mirror mismatch
                    StatusPill {
                        visible: root.archGateMirrorMismatch
                        icon: "⚠"
                        label: "mirror mismatch"
                        textColor: root.sealRaw
                    }

                    // Blacklist pill (clickable link)
                    StatusPill {
                        visible: root.archGateBlacklist > 0
                        icon: "shield"
                        label: "blacklist " + root.archGateBlacklist + (root.archGateListDate !== "" ? " · " + root.archGateListDate : "")
                        textColor: root.ink
                        bgTint: archPanel.chipBg
                        clickable: true
                        onClicked: Quickshell.execDetached(["bash", "-c",
                            "omarchy-launch-floating-terminal-with-presentation 'less ~/.local/share/qs-aur-blacklist.txt'"])
                    }
                }

                // Escalation warning banner
                Rectangle {
                    visible: root.archGateFail > 0
                    width: parent.width
                    height: 32
                    radius: 12
                    color: Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.15)
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        IconText { text: "warning"; color: root.sealRaw; font.pixelSize: 16 }
                        UiText {
                            text: "Installed copy may be compromised — run the infection checker"
                            color: root.sealRaw; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium
                        }
                    }
                }

                // ── Package List Card ──
                Card {
                    title: "Packages"
                    trailing: root.archUpdates.length > 0
                        ? (root.archUpdates.length + (root.archUpdates.length === 1 ? " package" : " packages"))
                        : ""

                    // Column headers
                    Item {
                        width: parent.width
                        height: 22

                        Row {
                            width: parent.width
                            spacing: 8
                            leftPadding: 6
                            rightPadding: 6

                            UiText {
                                width: (parent.width - 12) * 0.44
                                text: "PACKAGE"
                                color: root.sumiHi
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }
                            UiText {
                                width: (parent.width - 12) * 0.28
                                text: "INSTALLED"
                                color: root.sumiHi
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }
                            UiText {
                                width: (parent.width - 12) * 0.28
                                text: "AVAILABLE"
                                color: root.sumiHi
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.8
                            }
                        }
                    }

                    // Update list
                    Item {
                        width: parent.width
                        height: Math.min(updatesCol.implicitHeight, 260)

                        Flickable {
                            id: packagesFlick
                            anchors.fill: parent
                            contentHeight: updatesCol.implicitHeight
                            clip: true
                            interactive: updatesCol.implicitHeight > height

                            Column {
                                id: updatesCol
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.archUpdates

                                    delegate: Rectangle {
                                        id: pkgItem
                                        required property var modelData
                                        required property int index

                                        readonly property color srcColor: {
                                            if (modelData.source === "system") return root.seal;
                                            if (modelData.source === "aur") return root.indigo;
                                            return root.sumi;
                                        }

                                        readonly property var gv: archPanel.gateMap[modelData.name]
                                        readonly property bool vBlocked: gv !== undefined && gv.verdict === "FAIL"
                                        readonly property bool vReview:  gv !== undefined && gv.verdict === "WARN"
                                        readonly property bool vOk:      gv !== undefined && gv.verdict === "OK"
                                        readonly property string vReason: (gv !== undefined && gv.reason) ? gv.reason : ""
                                        readonly property bool showReason: vReason !== "" && (vBlocked || vReview)

                                        width: parent.width
                                        height: showReason ? 52 : 36
                                        radius: 10
                                        color: pkgRowMa.containsMouse
                                            ? archPanel.chipHover
                                            : (index % 2 === 1 ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.03) : "transparent")
                                        opacity: vBlocked ? 0.55 : 1.0
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        MouseArea {
                                            id: pkgRowMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                        }

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 2

                                            Row {
                                                width: parent.width
                                                height: 24
                                                spacing: 8

                                                // Package column: Squircle badge + Name
                                                Row {
                                                    width: (parent.width - 16) * 0.44
                                                    height: parent.height
                                                    spacing: 6

                                                    Rectangle {
                                                        width: 22; height: 22; radius: 7
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        color: vBlocked
                                                            ? Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.2)
                                                            : vReview
                                                                ? Qt.rgba(root.inkDeep.r, root.inkDeep.g, root.inkDeep.b, 0.2)
                                                                : vOk
                                                                    ? Qt.rgba(root.green.r, root.green.g, root.green.b, 0.2)
                                                                    : Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 0.15)
                                                        UiText {
                                                            anchors.centerIn: parent
                                                            text: vBlocked ? "✗" : vReview ? "⚠" : vOk ? "✓" : "·"
                                                            color: vBlocked ? root.sealRaw : vReview ? root.inkDeep : vOk ? root.green : root.sumi
                                                            font.family: root.barFont
                                                            font.pixelSize: 12
                                                            font.weight: Font.Bold
                                                        }
                                                    }

                                                    UiText {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 28
                                                        text: modelData.name
                                                        color: vBlocked ? root.sealRaw : root.ink
                                                        font.family: root.barFont
                                                        font.pixelSize: 13
                                                        font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                // Installed column
                                                UiText {
                                                    width: (parent.width - 16) * 0.28
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.oldVer
                                                    color: root.sumiHi
                                                    font.family: root.mono
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }

                                                // Available column
                                                Row {
                                                    width: (parent.width - 16) * 0.28
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 6

                                                    UiText {
                                                        width: parent.width - (modelData.source === "aur" ? 34 : 0)
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.newVer
                                                        color: pkgItem.srcColor
                                                        font.family: root.mono
                                                        font.pixelSize: 12
                                                        font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                    }

                                                    Rectangle {
                                                        visible: modelData.source === "aur"
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 28; height: 16; radius: 5
                                                        color: Qt.rgba(root.indigo.r, root.indigo.g, root.indigo.b, 0.2)
                                                        UiText {
                                                            anchors.centerIn: parent
                                                            text: "AUR"
                                                            color: root.indigo
                                                            font.family: root.barFont
                                                            font.pixelSize: 9
                                                            font.weight: Font.Bold
                                                        }
                                                    }
                                                }
                                            }

                                            // Reason row
                                            Row {
                                                visible: pkgItem.showReason
                                                width: parent.width
                                                spacing: 5
                                                leftPadding: 28

                                                IconText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "info"
                                                    color: vBlocked ? root.sealRaw : root.sumiHi
                                                    font.pixelSize: 12
                                                }

                                                UiText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 48
                                                    text: pkgItem.vReason
                                                    color: vBlocked ? root.sealRaw : root.sumiHi
                                                    font.family: root.barFont
                                                    font.pixelSize: 11
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }
                                }

                                // Empty state
                                Item {
                                    width: parent.width
                                    height: 100
                                    visible: root.archUpdates.length === 0

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        IconText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "check_circle"
                                            color: root.green
                                            font.pixelSize: 32
                                        }
                                        UiText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "All packages up to date"
                                            color: root.ink
                                            font.family: root.barFont
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                        }
                                        UiText {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: "No system or AUR updates pending"
                                            color: root.sumi
                                            font.family: root.barFont
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }

                        ScrollThumb { flick: packagesFlick }
                    }
                }

                // ── Buttons ──
                Row {
                    width: parent.width
                    spacing: 8

                    // Refresh
                    PillButton {
                        width: root.evenW((parent.width - 8 * (archPanel.btnCount - 1)) / archPanel.btnCount)
                        icon: "refresh"
                        label: "Refresh"
                        onClicked: root.archRefreshTick++
                    }

                    // Update (primary)
                    PillButton {
                        width: root.evenW((parent.width - 8 * (archPanel.btnCount - 1)) / archPanel.btnCount)
                        primary: true
                        icon: "upgrade"
                        btnEnabled: archPanel.canUpdate
                        label: archPanel.canUpdate
                            ? archPanel.packageUpdateButtonText
                            : archPanel.repoBlockButtonText
                        onClicked: {
                            var command = [archPanel.packageUpdateCommand]
                            if (archPanel.usesOmarchyUpdater) {
                                if (archPanel.packageUpdateMode === "cli") command.push("update")
                            } else {
                                command.push(
                                    "--run",
                                    root.archScanId,
                                    root.archScanHash,
                                    String(root.archScanSystemCount),
                                    String(root.archScanCheckedEpoch),
                                    String(archPanel.aurReviewPackages)
                                )
                            }
                            archPanel.launchPackageUpdate(command)
                        }
                    }

                    // Review AUR
                    PillButton {
                        visible: archPanel.aurReviewPackages > 0
                        width: root.evenW((parent.width - 8 * (archPanel.btnCount - 1)) / archPanel.btnCount)
                        icon: "visibility"
                        label: "Review " + archPanel.aurReviewPackages + " AUR"
                        onClicked: {
                            panelUpdateRunner.command = ["bash", "-c",
                                "omarchy-launch-floating-terminal-with-presentation 'echo \"AUR review — no packages are installed by this view.\"; echo; AUR=$(command -v paru || command -v yay || echo yay); \"$AUR\" -Qum; echo; echo \"Review each PKGBUILD before building these manually.\"'"];
                            root.archVisible = false;
                            panelUpdateRunner.running = false;
                            panelUpdateRunner.running = true;
                        }
                    }
                }
            }
            // ══════════ END PACKAGES TAB ══════════

            // ══════════ THEMES TAB ══════════
            Column {
                id: themesTab
                width: parent.width
                spacing: 8
                visible: root.activeUpdateTab === "themes"

                // ── Status pills row ──
                Flow {
                    width: parent.width
                    spacing: 6

                    StatusPill {
                        visible: root.themeUpdChecked === ""
                        icon: "info"
                        label: "Never checked — run a scan"
                        textColor: root.sumi
                    }

                    StatusPill {
                        visible: root.themeUpdChecked !== ""
                        icon: root.themeUpdOutdated > 0 ? "update" : "check"
                        label: root.themeUpdOutdated + (root.themeUpdOutdated === 1 ? " update found" : " updates found")
                        textColor: root.themeUpdOutdated > 0 ? root.ink : root.sumi
                        bgTint: root.themeUpdOutdated > 0 ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15) : archPanel.chipBg
                    }

                    StatusPill {
                        visible: root.themeUpdLocalEdits > 0
                        icon: "edit"
                        label: root.themeUpdLocalEdits + " with local edits"
                        textColor: root.inkDeep
                    }

                    StatusPill {
                        visible: root.themeUpdDegraded
                        icon: "warning"
                        label: "Check incomplete"
                        textColor: root.sealRaw
                    }

                    StatusPill {
                        visible: {
                            if (root.themeUpdChecked === "") return false
                            var d = new Date(root.themeUpdChecked)
                            return !isNaN(d.getTime())
                        }
                        icon: "schedule"
                        label: {
                            var d = new Date(root.themeUpdChecked)
                            return "Checked " + Qt.formatDateTime(d, "HH:mm")
                        }
                        textColor: root.sumiHi
                        bgTint: archPanel.chipBg
                    }
                }

                // Error banner
                Rectangle {
                    visible: archPanel.removeError !== ""
                    width: parent.width
                    height: 32
                    radius: 12
                    color: Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, 0.15)
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        IconText { text: "error"; color: root.sealRaw; font.pixelSize: 16 }
                        UiText {
                            text: "Remove failed · " + archPanel.removeError
                            color: root.sealRaw; font.family: root.barFont; font.pixelSize: 11; font.weight: Font.Medium
                        }
                    }
                }

                // Current theme stale banner
                Rectangle {
                    visible: root.themeUpdCurrentStale
                    width: parent.width
                    height: 42
                    radius: 14
                    color: archPanel.chipBg
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        IconText { text: "sync_problem"; color: root.inkDeep; font.pixelSize: 18 }
                        UiText {
                            text: "Current theme updated — live copy is stale"
                            color: root.ink; font.family: root.barFont; font.pixelSize: 12; font.weight: Font.Medium
                        }
                    }
                    PillButton {
                        anchors.right: parent.right; anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        height: 28; radius: 14
                        label: "Re-apply"
                        icon: "sync"
                        onClicked: archPanel.reapplyCurrentTheme()
                    }
                }

                // ── Theme List Card ──
                Card {
                    title: "Themes"
                    trailing: root.themeUpdList.length > 0
                        ? (root.themeUpdList.length + (root.themeUpdList.length === 1 ? " theme" : " themes"))
                        : ""

                    // Column headers
                    Item {
                        width: parent.width
                        height: 22
                        Row {
                            width: parent.width
                            spacing: archPanel.themeGridGap
                            leftPadding: 6
                            rightPadding: 6
                            UiText {
                                width: parent.width - archPanel.themeRightBlockWidth - archPanel.themeGridGap - 12
                                text: "THEME"
                                color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                            }
                            Item { width: archPanel.themeActionsWidth; height: 1 }
                            UiText {
                                width: archPanel.themeBehindWidth
                                text: "BEHIND"
                                color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                            }
                            UiText {
                                width: archPanel.themeStateWidth
                                text: "STATE"
                                color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 0.8
                            }
                        }
                    }

                    // Theme list
                    Item {
                    width: parent.width
                    height: Math.min(themesCol.implicitHeight, 240)
                    Flickable {
                        id: themesFlick
                        anchors.fill: parent
                        contentHeight: themesCol.implicitHeight
                        clip: true
                        interactive: themesCol.implicitHeight > 240

                    Column {
                        id: themesCol
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: root.themeUpdList

                            delegate: Item {
                                id: themeRow
                                required property var modelData
                                required property int index
                                readonly property bool isUnreach:   modelData.state === "unreachable"
                                readonly property bool isLocalEdits: modelData.state === "local-edits"
                                readonly property bool isClean:      modelData.state === "clean"
                                readonly property bool canViewChanges: modelData.behind > 0 && !isUnreach
                                readonly property var localFiles: modelData.files || []
                                readonly property string localReason: modelData.reason || ""
                                readonly property string localFileLabel: localFiles.length > 0
                                    ? localFiles[0] + (localFiles.length > 1 ? " +" + (localFiles.length - 1) : "")
                                    : localReason
                                readonly property string stateLabel: isUnreach ? "offline"
                                    : isLocalEdits ? (localReason === "untracked conflict" ? "conflict"
                                        : localReason === "tracked edits" ? "edits"
                                        : localReason === "local commits" ? "commits"
                                        : "changes")
                                    : "clean"
                                readonly property string stateTooltip: {
                                    if (!isLocalEdits) return ""
                                    if (localReason === "local commits")
                                        return "Blocked · local commits ahead of upstream"

                                    var title = localReason === "untracked conflict"
                                        ? "Blocked · untracked overwrite conflict"
                                        : localReason === "tracked edits"
                                            ? "Blocked · tracked edits (staged or unstaged)"
                                            : "Blocked · local changes"
                                    if (localFiles.length === 0) return title

                                    var noun = localReason === "untracked conflict"
                                        ? (localFiles.length === 1 ? "conflicting path shown" : "conflicting paths shown")
                                        : (localFiles.length === 1 ? "changed file shown" : "changed files shown")
                                    return title + "\n" + localFiles.length + " " + noun + " · " + localFileLabel
                                }
                                // A per-theme update is pinned to the commit saved by the last
                                // scan. Local-edits/unreachable/old-schema rows stay review-only.
                                readonly property bool canPull: archPanel.isPinnedThemeUpdate(modelData)
                                readonly property bool canReinstall: archPanel.canReinstallTheme(modelData)
                                readonly property bool canRemove: !root.themeUpdChecking
                                    && /^[A-Za-z0-9._-]+$/.test(modelData.name || "")
                                readonly property bool confirmingRemove:
                                    archPanel.pendingRemoveName === String(modelData.name || "")
                                readonly property bool removeFlowIdle:
                                    archPanel.pendingRemoveName === ""

                                width: parent.width
                                height: 22

                                Row {
                                    width: parent.width
                                    height: 22
                                    spacing: archPanel.themeGridGap
                                    UiText {
                                        width: parent.width - archPanel.themeRightBlockWidth - archPanel.themeGridGap
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: modelData.current ? root.seal : root.ink
                                        font.family: root.barFont; font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                    Item {
                                        width: archPanel.themeActionsWidth
                                        height: 22

                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: themeRow.confirmingRemove ? 132 : 100
                                            height: parent.height
                                            spacing: 4

                                            // Slot 1: normal update, or the explicit inline remove
                                            // confirmation. The fixed outer action area keeps the
                                            // following information columns aligned in every state.
                                            Item {
                                                width: themeRow.confirmingRemove
                                                    ? archPanel.removeBusy ? 108 : 52
                                                    : 52
                                                height: 22
                                                Rectangle {
                                                    id: primaryAction
                                                    readonly property bool actionEnabled: themeRow.confirmingRemove
                                                        ? !archPanel.removeBusy && !root.themeUpdChecking
                                                        : themeRow.removeFlowIdle && themeRow.canPull
                                                    visible: themeRow.confirmingRemove
                                                        || (themeRow.removeFlowIdle && themeRow.canPull)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.verticalCenterOffset: -2
                                                    width: parent.width; height: 18; radius: root.panelButtonRadius
                                                    color: (primaryMa.containsMouse && actionEnabled)
                                                        ? root.fillPrimaryHover : root.seal
                                                    opacity: archPanel.removeBusy && themeRow.confirmingRemove ? 0.65 : 1.0
                                                    Behavior on color { ColorAnimation { duration: 100 } }
                                                    TooltipMixin {
                                                        id: primaryTip
                                                        root: archPanel.root
                                                        owner: primaryAction
                                                        text: themeRow.confirmingRemove
                                                            ? archPanel.removeBusy
                                                                ? "Removing theme · " + modelData.name
                                                                : archPanel.removeError !== ""
                                                                    ? "Retry removal · " + archPanel.removeError
                                                                    : "Confirm removal · " + modelData.name
                                                            : "Update theme · " + modelData.name
                                                    }
                                                    UiText {
                                                        anchors.centerIn: parent
                                                        text: themeRow.confirmingRemove
                                                            ? archPanel.removeBusy ? "removing…"
                                                                : archPanel.removeError !== "" ? "retry" : "remove"
                                                            : "update"
                                                        color: root.paper
                                                        font.family: root.barFont
                                                        font.pixelSize: 9
                                                    }
                                                    MouseArea {
                                                        id: primaryMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        enabled: primaryAction.actionEnabled
                                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                        onEntered: primaryTip.show()
                                                        onExited: primaryTip.hide()
                                                        onClicked: {
                                                            primaryTip.hide()
                                                            if (themeRow.confirmingRemove)
                                                                archPanel.confirmRemoveTheme()
                                                            else
                                                                archPanel.updateOneTheme(modelData.name)
                                                        }
                                                    }
                                                }
                                            }

                                            // Slot 2 becomes a text button matching Remove while
                                            // armed. Once removal starts, the progress button uses
                                            // both text slots until the command finishes.
                                            Rectangle {
                                                id: secondaryAction
                                                readonly property bool actionEnabled: themeRow.confirmingRemove
                                                    ? !archPanel.removeBusy
                                                    : themeRow.removeFlowIdle && themeRow.canReinstall
                                                visible: !themeRow.confirmingRemove || !archPanel.removeBusy
                                                width: themeRow.confirmingRemove ? 52 : 20
                                                height: 18; radius: root.panelButtonRadius
                                                color: themeRow.confirmingRemove
                                                    ? (secondaryMa.containsMouse && actionEnabled)
                                                        ? root.fillPrimaryHover : root.seal
                                                    : (secondaryMa.containsMouse && actionEnabled)
                                                        ? root.fillHover : "transparent"
                                                opacity: actionEnabled ? 1.0 : 0.28
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                                TooltipMixin {
                                                    id: secondaryTip
                                                    root: archPanel.root
                                                    owner: secondaryAction
                                                    text: themeRow.confirmingRemove
                                                        ? "Cancel removal · " + modelData.name
                                                        : "Reinstall theme · " + modelData.name
                                                }
                                                UiText {
                                                    anchors.centerIn: parent
                                                    visible: themeRow.confirmingRemove
                                                    text: "cancel"
                                                    color: root.paper
                                                    font.family: root.barFont
                                                    font.pixelSize: 9
                                                }
                                                IconText {
                                                    anchors.centerIn: parent
                                                    visible: !themeRow.confirmingRemove
                                                    text: "\uE5D5"
                                                    color: secondaryMa.containsMouse && secondaryAction.actionEnabled
                                                        ? root.seal : root.sumi
                                                    font.pixelSize: 14
                                                }
                                                MouseArea {
                                                    id: secondaryMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: secondaryAction.actionEnabled
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onEntered: secondaryTip.show()
                                                    onExited: secondaryTip.hide()
                                                    onClicked: {
                                                        secondaryTip.hide()
                                                        if (themeRow.confirmingRemove)
                                                            archPanel.cancelRemoveTheme()
                                                        else
                                                            archPanel.reinstallTheme(modelData.name, modelData.remoteUrl)
                                                    }
                                                }
                                            }

                                            // Slot 3 is trash normally; while armed it keeps the
                                            // reinstall action to the right of Cancel.
                                            Rectangle {
                                                id: tertiaryAction
                                                readonly property bool actionEnabled: themeRow.confirmingRemove
                                                    ? !archPanel.removeBusy && themeRow.canReinstall
                                                    : themeRow.removeFlowIdle && themeRow.canRemove
                                                width: 20; height: 18; radius: root.panelButtonRadius
                                                color: {
                                                    if (!tertiaryMa.containsMouse || !actionEnabled) return "transparent"
                                                    if (themeRow.confirmingRemove) return root.fillHover
                                                    return Qt.rgba(root.sealRaw.r, root.sealRaw.g, root.sealRaw.b, root.fillHoverAlpha)
                                                }
                                                opacity: actionEnabled ? 1.0 : 0.28
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                                TooltipMixin {
                                                    id: tertiaryTip
                                                    root: archPanel.root
                                                    owner: tertiaryAction
                                                    text: themeRow.confirmingRemove
                                                        ? "Reinstall theme · " + modelData.name
                                                        : "Remove theme · " + modelData.name
                                                }
                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: themeRow.confirmingRemove ? "\uE5D5" : "\uE872"
                                                    color: tertiaryMa.containsMouse && tertiaryAction.actionEnabled
                                                        ? themeRow.confirmingRemove ? root.seal : root.sealRaw
                                                        : root.sumi
                                                    font.pixelSize: themeRow.confirmingRemove ? 14 : 13
                                                }
                                                MouseArea {
                                                    id: tertiaryMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    enabled: tertiaryAction.actionEnabled
                                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onEntered: tertiaryTip.show()
                                                    onExited: tertiaryTip.hide()
                                                    onClicked: {
                                                        tertiaryTip.hide()
                                                        if (themeRow.confirmingRemove) {
                                                            archPanel.cancelRemoveTheme()
                                                            archPanel.reinstallTheme(modelData.name, modelData.remoteUrl)
                                                        } else {
                                                            archPanel.removeTheme(modelData.name)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Item {
                                        width: archPanel.themeBehindWidth
                                        height: 22
                                        UiText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            text: isUnreach ? "—" : (modelData.behind + (modelData.behind === 1 ? " commit" : " commits"))
                                            color: behindMa.containsMouse && themeRow.canViewChanges ? root.seal : Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.7)
                                            font.family: root.barFont; font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                        MouseArea {
                                            id: behindMa
                                            anchors.fill: parent
                                            hoverEnabled: themeRow.canViewChanges
                                            enabled: themeRow.canViewChanges
                                            cursorShape: themeRow.canViewChanges ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: archPanel.viewThemeChanges(modelData.name)
                                        }
                                    }
                                    // right slot: status only; all per-theme actions live in the
                                    // intentionally unlabelled column immediately before Behind.
                                    Item {
                                        id: stateSlot
                                        width: archPanel.themeStateWidth
                                        height: 22
                                        TooltipMixin {
                                            id: stateTip
                                            root: archPanel.root
                                            owner: stateSlot
                                            text: themeRow.stateTooltip
                                        }
                                        UiText {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: themeRow.stateLabel
                                            color: stateMa.containsMouse && themeRow.stateTooltip !== ""
                                                ? root.seal
                                                : isLocalEdits ? root.inkDeep : root.sumi
                                            font.family: root.barFont; font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                        MouseArea {
                                            id: stateMa
                                            anchors.fill: parent
                                            acceptedButtons: Qt.NoButton
                                            hoverEnabled: true
                                            cursorShape: themeRow.stateTooltip !== "" ? Qt.WhatsThisCursor : Qt.ArrowCursor
                                            onEntered: { if (themeRow.stateTooltip !== "") stateTip.show() }
                                            onExited: stateTip.hide()
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width - 16; height: 1
                                    color: root.sep
                                    visible: index < root.themeUpdList.length - 1
                                }
                            }
                        }

                        UiText {
                            width: parent.width
                            visible: root.themeUpdList.length === 0
                            text: root.themeUpdChecked === "" ? "Not checked yet" : "All themes up to date"
                            color: Qt.rgba(root.ink.r,root.ink.g,root.ink.b,0.5)
                            font.family: root.barFont; font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: 20
                        }
                    }
                    }
                    ScrollThumb { flick: themesFlick }
                }
            }

                // ── buttons ──
                Row {
                    width: parent.width
                    spacing: 8

                    // Check themes — runs the read-only check script; disabled while scanning
                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28; radius: root.panelButtonRadius
                        color: (checkMa.containsMouse && !root.themeUpdChecking) ? root.fillHover : root.fillIdle
                        border.color: (checkMa.containsMouse && !root.themeUpdChecking) ? root.seal : root.sep
                        border.width: 0
                        opacity: root.themeUpdChecking ? 0.5 : 1.0
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: root.themeUpdChecking ? "Checking…" : "Check themes"
                            color: (checkMa.containsMouse && !root.themeUpdChecking) ? root.seal : root.ink
                            font.family: root.barFont; font.pixelSize: 11
                        }
                        MouseArea {
                            id: checkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !root.themeUpdChecking
                            cursorShape: root.themeUpdChecking ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: root.themeCheckTick++
                        }
                    }

                    // Update clean — applies only clean themes with a saved target
                    // commit; blocked/local-edits stay untouched for review.
                    Rectangle {
                        readonly property int cleanCount: archPanel.cleanThemeUpdateCount()
                        readonly property bool canApply: cleanCount > 0 && !root.themeUpdChecking
                        width: (parent.width - 8) / 2
                        height: 28; radius: root.panelButtonRadius
                        opacity: canApply ? 1.0 : 0.45
                        color: (allMa.containsMouse && canApply) ? root.fillPrimaryHover : root.seal
                        border.color: "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: root.themeUpdChecking ? "Checking…"
                                                  : parent.canApply ? (root.themeUpdLocalEdits > 0 ? "Update clean" : "Update all")
                                                  : root.themeUpdOutdated > 0 ? "Review first" : "No updates"
                            color: root.paper
                            font.family: root.barFont; font.pixelSize: 11
                        }
                        MouseArea {
                            id: allMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.canApply
                            cursorShape: parent.canApply ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: archPanel.updateAllThemes()
                        }
                    }
                }

            }
            // ══════════ END THEMES TAB ══════════

            ShellUpdateTab {
                width: parent.width
                root: archPanel.root
                visible: root.activeUpdateTab === "shell"
            }
        }

    }
}

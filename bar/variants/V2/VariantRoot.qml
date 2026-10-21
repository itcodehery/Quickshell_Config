// V2 variant adapter: bind one bar to each real Wayland output, skip
// transient nameless/0x0 placeholder screens, and recreate a BarSlot when that
// output disappears and returns. If a screen remains valid but the layer window
// loses resources or closes, recreate only that window instead of reloading the
// complete Quickshell configuration.

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "panels"

Item {
    id: root

    required property var variantHost
    readonly property string variantId: "v2"
    readonly property bool ready: lifecycleReady()

    width: 0
    height: 0

    Theme {
        id: theme
        variantHost: root.variantHost
    }

    function closePopups() { theme.closePopups() }
    function prepareDeactivate() {
        theme.barUnlocked = false
        theme.closePopups()
    }
    function deactivationReady() { return !theme.anyPopupVisible }
    function layoutLock() { theme.barUnlocked = false }
    function layoutUnlock() { theme.barUnlocked = true }
    function toggleBar() { theme.barHidden = !theme.barHidden }
    function toggleDashboard() {
        if (!theme.dashboardExpanded) {
            theme.dashboardDetail = ""
        }
        theme.dashboardExpanded = !theme.dashboardExpanded
    }
    function openDashboardDetail(detail) {
        theme.dashboardDetail = detail
        theme.dashboardExpanded = true
    }
    function lockRetract() {}
    function lockReveal() {}
    function currentShellStyle() { return theme.barShellStyle }
    function showIslandOsd(kind, value) { theme.showIslandOsd(kind, value) }
    function triggerNotifPeek(app, summary, body, icon) { theme.triggerNotifPeek(app, summary, body, icon) }
    function dismissNotifPeek(notifId) { theme.dismissNotifPeek(notifId) }
    function triggerChargingPopup(pct) { theme.triggerChargingPopup(pct) }
    function testDictationState(st) { theme.testDictationState(st) }
    function startTimer(minutes, label) { theme.startTimer(minutes, label) }
    function toggleTimer() { theme.toggleTimer() }
    function resetTimer() { theme.resetTimer() }
    function startStopwatch() { theme.startStopwatch() }
    function startSysTask(label, progress) {}
    function updateSysTask(progress) {}
    function finishSysTask() {}
    function systemUpdateRefresh() { theme.archRefreshTick++ }
    function runReactor(kind, arg) {
        // Reactor is a V1-only animation. Keep the shared IPC contract stable,
        // but deliberately do nothing while V2 is active.
    }
    function applyTheme(payload) { theme.ipcApplyTheme(payload) }
    function applyLauncher(payload) { theme.ipcApplyLauncher(payload) }
    function reloadTheme() { theme.ipcReloadTheme() }
    function openPicker(mode) { theme.ipcOpenPicker(mode) }
    function setPickerStyle(style) { theme.setPickerStyle(style) }

    // QtWayland creates a nameless 0x0 placeholder screen while no real output
    // exists; exclude it so no unusable layer surface is created. A new real
    // ShellScreen identity makes Variants destroy the old BarSlot and
    // instantiate a fresh one.
    readonly property var barScreens: {
        var valid = []

        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name !== "" && candidate.width > 0 && candidate.height > 0) {
                valid.push(candidate)
            }
        }

        return valid
    }

    function lifecycleReady() {
        if (!theme._widgetsLoaded || barScreens.length === 0) return false

        var controllers = theme.barLayoutControllerKeys()
        if (controllers.length !== barScreens.length) return false

        for (var i = 0; i < barScreens.length; i++) {
            var controller = theme.barLayoutControllers[barScreens[i].name]
            if (!controller || !controller.ready || !controller.ready()) return false
        }
        return true
    }

    function activeScreenStillValid() {
        if (!theme.activePopupScreenName) return false

        for (var i = 0; i < barScreens.length; i++) {
            if (barScreens[i].name === theme.activePopupScreenName) return true
        }

        return false
    }

    function ensureActivePopupScreen() {
        if (barScreens.length === 0) {
            theme.closePopups()
            theme.activePopupScreen = null
            theme.activePopupScreenName = ""
        } else if (!activeScreenStillValid()) {
            if (theme.anyPopupVisible) theme.closePopups()
            theme.activatePopupScreen(barScreens[0])
        }
    }

    onBarScreensChanged: ensureActivePopupScreen()
    Component.onCompleted: {
        ensureActivePopupScreen()
        Quickshell.execDetached(["/home/hery/.config/quickshell/bar/variants/V2/scripts/start_screentime.sh"])
    }

    // Secondary guard for failures that do not replace the ShellScreen object.
    // resourcesLost is followed by closed, so one pending flag handles the pair
    // once. A closed PanelWindow drops its backing layer-shell window; setting
    // visible=true creates a fresh one without resetting the rest of the shell.
    component BarWindowRecovery: Scope {
        id: recovery

        required property var targetWindow
        required property var targetScreen

        property bool pending: false
        property int attempt: 0
        property string reason: ""

        function screenReady() {
            return targetScreen !== null
                && targetScreen.name !== ""
                && targetScreen.width > 0
                && targetScreen.height > 0
        }

        function schedule(reason_) {
            if (pending) return

            pending = true
            attempt = 0
            reason = reason_
            console.warn("[BarWindowRecovery] window lost: " + reason)
            retryTimer.restart()
        }

        Connections {
            target: recovery.targetWindow

            function onResourcesLost() { recovery.schedule("resourcesLost") }
            function onClosed() { recovery.schedule("closed") }
        }

        Timer {
            id: retryTimer
            interval: 750
            repeat: false
            onTriggered: {
                // Screen replacement is owned by Variants. The delegate and this
                // timer will normally be destroyed before reaching this branch.
                if (!recovery.screenReady()) {
                    console.warn("[BarWindowRecovery] invalid screen; waiting for Variants")
                    recovery.pending = false
                    return
                }

                recovery.attempt++
                console.warn("[BarWindowRecovery] recreating bar window (attempt "
                             + recovery.attempt + "/3)")
                recovery.targetWindow.visible = true
                verifyTimer.restart()
            }
        }

        Timer {
            id: verifyTimer
            interval: 1200
            repeat: false
            onTriggered: {
                if (recovery.targetWindow.backingWindowVisible) {
                    console.log("[BarWindowRecovery] bar window recovered")
                    recovery.pending = false
                    recovery.attempt = 0
                } else if (recovery.attempt < 3 && recovery.screenReady()) {
                    retryTimer.restart()
                } else {
                    console.warn("[BarWindowRecovery] targeted recovery failed")
                    recovery.pending = false
                }
            }
        }
    }

    component PopupDismissLayer: PanelWindow {
        id: dismissLayer

        required property var root
        required property var targetScreen

        screen: targetScreen
        color: Qt.rgba(0, 0, 0, 0.001)
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.focusable: dismissLayer.visible
        WlrLayershell.keyboardFocus: dismissLayer.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-popup-dismiss"
        mask: Region { item: hitArea }

        Rectangle {
            id: hitArea
            x: 0
            y: 0
            width: dismissLayer.width
            height: dismissLayer.height
            color: Qt.rgba(0, 0, 0, 0.001)

            MouseArea {
                anchors.fill: parent
                enabled: dismissLayer.visible
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: dismissLayer.root.closePopups()
            }
        }
        visible: root.anyPopupVisible
            && !root.keyboardPopupVisible
            && targetScreen
            && targetScreen.name !== ""
            && !root.isActivePopupScreenName(targetScreen.name)
    }

    Variants {
        model: root.barScreens

        delegate: Component {
            BarSlot {
                id: barWindow
                required property var modelData

                root: theme
                screen: modelData
                mprisPanel: theMprisPanel

                BarWindowRecovery {
                    targetWindow: barWindow
                    targetScreen: barWindow.modelData
                }
            }
        }
    }

    Variants {
        model: root.barScreens

        delegate: Component {
            PopupDismissLayer {
                required property var modelData

                root: theme
                targetScreen: modelData
            }
        }
    }

    component OnDemandPanel: LazyLoader {
        property bool trigger: false
        active: false
        onTriggerChanged: if (trigger && !active) active = true
    }

    TooltipOverlay { root: theme }
    ArchUpdaterPanel { root: theme }
    MprisPanel { id: theMprisPanel; root: theme }
    OnDemandPanel { trigger: theMprisPanel.showingLyrics && theMprisPanel.active; LyricsPanel        { root: theme; mprisPanel: theMprisPanel } }
    OnDemandPanel { trigger: theme.trayVisible;                                    TrayPanel          { root: theme } }
    OnDemandPanel { trigger: theme.weatherVisible;                                 WeatherPanel       { root: theme } }
    OnDemandPanel { trigger: theme.githubHeatmapVisible;                           GithubHeatmapPanel { root: theme } }
    OnDemandPanel { trigger: theme.workspaceVisible;                               WorkspacePanel     { root: theme } }
    OnDemandPanel { trigger: theme.controlVisible;                                 ControlPanel       { root: theme } }
    OnDemandPanel { trigger: theme.trayMenuVisible;                                TrayMenu           { root: theme } }

    // Picker variants: only the selected pickerStyle is instantiated on demand.
    LazyLoader { active: theme.imagePickerVisible && (theme.pickerStyle === "tanzaku" || theme.pickerStyle === "");  ImageCarouselPanel       { root: theme } }
    LazyLoader { active: theme.imagePickerVisible && theme.pickerStyle === "hearthstone";                           ImageCarouselHearthstone { root: theme } }
    LazyLoader { active: theme.imagePickerVisible && theme.pickerStyle === "carousel";                              ImageCarouselCarousel    { root: theme } }
    LazyLoader { active: theme.mediaBrowserVisible && (theme.pickerStyle === "tanzaku" || theme.pickerStyle === "");  MediaBrowserPanel        { root: theme } }
    LazyLoader { active: theme.mediaBrowserVisible && theme.pickerStyle === "hearthstone";                             MediaBrowserHearthstone  { root: theme } }
    LazyLoader { active: theme.mediaBrowserVisible && theme.pickerStyle === "carousel";                                MediaBrowserCarousel     { root: theme } }

    CursorDotOverlay { root: theme }

    Variants {
        model: root.barScreens

        delegate: Component {
            ScreenCornersOverlay {
                required property var modelData

                root: theme
                targetScreen: modelData
            }
        }
    }

    Variants {
        model: root.barScreens

        delegate: Component {
            PowerNotchPanel {
                required property var modelData

                root: theme
                targetScreen: modelData
            }
        }
    }

    Variants {
        model: root.barScreens

        delegate: Component {
            DesktopContextMenu {
                required property var modelData

                root: theme
                targetScreen: modelData
            }
        }
    }
    // Note: Homescreen dashboard is now integrated into BarSlot.qml as an in-place expandable Island Dock.
}

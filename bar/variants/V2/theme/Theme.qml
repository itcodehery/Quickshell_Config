import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "Palette.js" as Palette
import "ThemePopupAndLayout.js" as PopupLayout
import "ThemeTelemetry.js" as Telemetry
import "ThemeWidgetsConfig.js" as WidgetsConfig

ThemeBase {
    id: theme

    function reloadCurrentThemeFiles() { updatesWorkers.reloadCurrentThemeFiles() }
    function refreshAiUsage(selectedOnly) { telemetryWorkers.refreshAiUsage(selectedOnly) }

    readonly property bool anyPopupVisible: calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible || githubHeatmapVisible
        || workspaceVisible || imagePickerVisible || mediaBrowserVisible || notifVisible
        || powerProfileVisible || storageVisible || archVisible || trayVisible || trayMenuVisible
        || pluginsDrawerVisible
    readonly property bool keyboardPopupVisible: imagePickerVisible || mediaBrowserVisible

    // ── Top-right Plugins Drawer & Pinning state ──
    property bool pluginsDrawerVisible: false
    property real pluginsDrawerReveal: pluginsDrawerVisible ? 1 : 0
    Behavior on pluginsDrawerReveal {
        NumberAnimation {
            duration: theme.pluginsDrawerVisible ? 220 : 160
            easing.type: theme.pluginsDrawerVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    onPluginsDrawerVisibleChanged: popupOpened("pluginsDrawerVisible")

    function togglePluginsDrawer() { statusWorkers.togglePluginsDrawer() }

    readonly property string pinnedPluginsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_pinned_plugins.json"
    property var pinnedPlugins: []
    property var pinnedPluginsData: []
    readonly property string pluginsOrderCachePath: Quickshell.env("HOME") + "/.cache/quickshell_plugins_order.json"
    property var pluginsOrder: []
    signal pluginsSettingsChanged()

    function isPluginPinned(id) { return statusWorkers.isPluginPinned(id) }
    function togglePinPlugin(id) { statusWorkers.togglePinPlugin(id) }
    function setPinnedPluginsList(list) { statusWorkers.setPinnedPluginsList(list) }
    function setPluginsOrderList(list) { statusWorkers.setPluginsOrderList(list) }
    function savePinnedPlugins() { statusWorkers.savePinnedPlugins() }
    function savePluginsOrder() { statusWorkers.savePluginsOrder() }

    // ── Memory panel state ──
    property bool memVisible: false
    onMemVisibleChanged: popupOpened("memVisible")

    // ── Volume panel state ──
    property bool volVisible: false
    property real volReveal: volVisible ? 1 : 0
    Behavior on volReveal {
        NumberAnimation {
            duration: theme.volVisible ? 160 : 120
            easing.type: theme.volVisible ? Easing.OutBack : Easing.InCubic
        }
    }
    onVolVisibleChanged: popupOpened("volVisible")

    // ── Control center state ──
    property bool controlVisible: false
    onControlVisibleChanged: {
        popupOpened("controlVisible")
        if (!controlVisible) wwSubVisible = false
    }

    // ── Bar layout / unlock (drag&drop reorder). barUnlocked is transient. ──
    property bool barUnlocked: false
    property bool hoverForce: false
    property bool barHidden: false
    // Lock-screen transition (Island only): true slides the bar up off-screen
    // before hyprlock starts; false drops it back in after unlock.
    property bool barLockRetracted: false
    property var  fnDefaultLayout: function () { theme.resetAllBarLayouts() }
    property bool wwSubVisible: false   // "Widgets & Workspaces" fly-out

    // ── module enable flags (controlled by ControlPanel) ──
    property bool modStatus:     true
    property bool modNotif:      true
    property bool modMemory:     false
    property bool modCpu:        true
    property bool modScreentime: true
    property bool screentimeVisible: false
    property bool modCpuTemperature: true
    property bool modGpu:        true
    property bool modStorage:    true
    property bool modGithubHeatmap: true
    property bool modNotes:         true
    property bool modVolume:     true
    property bool modWeather:    true
    property bool modNetwork:    false
    property bool modBattery:    true
    property bool dashboardExpanded: false
    property string dashboardDetail: ""
    property string networkMode: "none"   // mirrored from NetworkWidget: wifi/ethernet/none
    // Centralized status indicators. These live on Theme so BarSlot-per-monitor
    // widgets don't each spawn their own status poller.
    property bool stayAwake: false            // idle lock disabled / stay-awake indicator
    readonly property bool hypridleAwake: stayAwake // compatibility alias for older modules
    property bool _idleBackendChecked: false
    property bool _idleOmarchyShellBackend: false
    property bool _idleOmarchyShellSystem: false
    property bool _omarchyBackendReprobePending: false
    property int _omarchyBackendRetryIndex: 0
    readonly property var _omarchyBackendRetryDelays: [2000, 5000, 15000]
    readonly property string omarchyShellConfigPath: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    readonly property string idleStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/indicators/stay-awake"
    property bool notifSilenced: false        // notification do-not-disturb mode
    property bool _notifBackendChecked: false
    property bool _notifOmarchyShellBackend: false
    property bool _notifOmarchyShellSystem: false
    readonly property string notificationsStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    property bool screenRecording: false
    property int screenRecordingElapsed: 0
    property string _screenRecordingPid: ""
    property string _screenRecordingElapsedProbePid: ""
    property int _screenRecordingBaseElapsed: 0
    property real _screenRecordingBaseMs: 0
    readonly property string screenRecordingStatePath: "/tmp/omarchy-screenrecord-filename"
    property bool _recordingRefreshPending: false
    property string voxState: "idle"          // idle/recording/transcribing
    property string voxHint: ""
    property bool voxAvailable: true
    readonly property bool _statusPollingWanted: modStatus
    readonly property bool _voxActive: voxState === "recording" || voxState === "transcribing"

    function refreshIdleStatus() { statusWorkers.refreshIdleStatus() }
    function refreshStatusIndicators() { statusWorkers.refreshStatusIndicators() }
    function reprobeOmarchyShellBackends() { statusWorkers.reprobeOmarchyShellBackends() }
    function finishOmarchyBackendReprobe() { statusWorkers.finishOmarchyBackendReprobe() }
    function omarchyBackendRetryNeeded() { return statusWorkers.omarchyBackendRetryNeeded() }
    function scheduleOmarchyBackendRetry() { statusWorkers.scheduleOmarchyBackendRetry() }
    function resetOmarchyBackendProbes() { statusWorkers.resetOmarchyBackendProbes() }
    function parseNotificationsState(text) { statusWorkers.parseNotificationsState(text) }
    function refreshNotificationStatus() { statusWorkers.refreshNotificationStatus() }
    function refreshRecordingStatus() { statusWorkers.refreshRecordingStatus() }
    function reconcileSlowStatusIndicators() { statusWorkers.reconcileSlowStatusIndicators() }
    function setScreenRecordingPid(pid) { statusWorkers.setScreenRecordingPid(pid) }
    function updateScreenRecordingElapsed() { statusWorkers.updateScreenRecordingElapsed() }
    function refreshVoxtypeStatus() { statusWorkers.refreshVoxtypeStatus() }

    // battery presence (laptop) — drives the Battery indicator tile's visibility (shown only
    // where a battery exists, like Brightness uses hasBacklight). Direct UPower check, event-driven.
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    // NetworkManager active (Omarchy 4.0) → the panel's iwctl scan/connect won't work,
    // so it shows an "open nmtui" button instead of an empty list
    property bool useNM: false

    // ── wifi/bluetooth settings launchers (Omarchy way, via uwsm-app) ──
    // iwd (Omarchy 3.8.x) → impala/bluetui through omarchy-launch-*; if NetworkManager
    // is the active backend (Omarchy 4.0) → nmtui instead. Quattro removed the
    // dedicated Bluetooth launcher; prefer a retained bluetui, then bluetoothctl.
    readonly property string launchWifiCmd: "if systemctl is-active --quiet NetworkManager 2>/dev/null; then omarchy-launch-or-focus-tui nmtui; else omarchy-launch-wifi; fi"
    readonly property string launchBtCmd:   "if command -v omarchy-launch-bluetooth >/dev/null 2>&1; then exec omarchy-launch-bluetooth; elif command -v omarchy-launch-or-focus-tui >/dev/null 2>&1; then if command -v bluetui >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec omarchy-launch-or-focus-tui bluetui; elif command -v bluetoothctl >/dev/null 2>&1; then command -v rfkill >/dev/null 2>&1 && rfkill unblock bluetooth >/dev/null 2>&1 || true; exec omarchy-launch-or-focus-tui bluetoothctl; fi; fi; command -v notify-send >/dev/null 2>&1 && notify-send -a QS-Shell -u critical 'Bluetooth settings unavailable' 'No supported Bluetooth settings backend was found' || true; exit 0"
    property bool modPower:      false   // default off (toggle in ControlPanel)
    property bool modBluetooth:  false   // default off (toggle in ControlPanel)
    property bool modBrightness: true
    property bool modMedia:      true
    property bool modQuick:      true    // G10 group pill (idle-inhibitor · media · theme)
    property bool modMpris:      true    // G9 now-playing / mpris pill
    property string mprisBarStyle: "default" // "default" or "full"
    property bool modClaude:     false   // default off (toggle in ControlPanel)

    // backlight presence — set by BrightnessWidget once it probes /sys/class/backlight.
    // ControlPanel uses this to hide the Brightness toggle on desktops without one.
    property bool hasBacklight:  false

    // ── workspace display mode ──
    property string workspaceMode: "10"   // "10", "5", "active"
    // ── workspace display style (orthogonal to mode; persisted) ──
    // "rings" is the stable cache token for the user-facing Frame style.
    property string workspaceStyle: "default"   // default, numbers, magic, kanji, rings, aurora

    property bool islandOsdActive: false
    property string islandOsdKind: ""
    property int islandOsdValue: 0
    property int islandOsdTick: 0
    function showIslandOsd(kind, value) { liveActivities.showIslandOsd(kind, value) }

    // ── Dynamic Island Live Activities ──
    // 1. Notification Peek Banner
    property bool notifPeekActive: false
    property string notifPeekApp: ""
    property string notifPeekSummary: ""
    property string notifPeekBody: ""
    property string notifPeekIcon: ""
    property int notifPeekId: 0
    property int notifPeekTick: 0
    property int notifPeekDismissTick: 0
    function triggerNotifPeek(app, summary, body, icon, notifId) { liveActivities.triggerNotifPeek(app, summary, body, icon, notifId) }
    function dismissNotifPeek(notifId) { liveActivities.dismissNotifPeek(notifId) }
    function invokeNotification(notifId, appName) { liveActivities.invokeNotification(notifId, appName) }

    // 2. Timer / Pomodoro / Stopwatch Pill
    property bool timerActive: false
    property bool timerPaused: false
    property string timerMode: "countdown"   // "countdown" | "stopwatch"
    property int timerRemaining: 0          // in seconds
    property int timerInitial: 0            // in seconds
    property string timerLabel: "Focus"
    function startTimer(minutes, label) { liveActivities.startTimer(minutes, label) }
    function toggleTimer() { liveActivities.toggleTimer() }
    function resetTimer() { liveActivities.resetTimer() }
    function startStopwatch() { liveActivities.startStopwatch() }

    // 3. Hardware Privacy & Screen-Share Dots
    property bool privacyMic: false
    property bool privacyCam: false
    property bool privacyScreen: false
    readonly property bool privacyAnyActive: privacyMic || privacyCam || privacyScreen

    // ── 4. Voice Dictation (voxtype) ──────────────────────────────────
    property bool dictationActive: dictationState === "recording" || dictationState === "transcribing"
    property string dictationState: "idle"
    function toggleDictation() { liveActivities.toggleDictation() }
    function testDictationState(st) { liveActivities.testDictationState(st) }

    // ── 5. Laptop Charging Dynamic Island Popup ───────────────────────
    property bool chargingPopupActive: false
    property int chargingPopupPercent: 100
    property string chargingPopupState: "charging" // "charging" | "discharging"
    property int prevAcOnline: -1
    property int currentBatteryPercent: 100
    function triggerChargingPopup(pct, state) { liveActivities.triggerChargingPopup(pct, state) }

    // ── picker visual style (theme/wallpaper/screenshot/video pickers) ──
    property string pickerStyle: "tanzaku"   // "tanzaku", "hearthstone", "carousel", "gravemind"
    function setPickerStyle(style) { if (style) pickerStyle = style }
    property string launcherLogoMode: "text"     // "text" or "icon"
    property string launcherLogoText: "omarchy"  // "omarchy", "hyprland", "arch", or "omacom"
    property string launcherLogoIcon: "omarchy"  // see launcherLogoIconGlyph()
    property bool   weatherImperial: false   // false = °C / km·h, true = °F / mph
    property bool   clock12h:        false   // false = 24h, true = 12h (AM/PM)

    // ── widget/workspace state persistence ──
    property var barSeps: []
    property var iconOnlyGids: []
    function sepAfter(gid) { return WidgetsConfig.sepAfter(theme, gid) }
    function iconOnly(gid) { return WidgetsConfig.iconOnly(theme, gid) }
    function toggleSep(gid) { WidgetsConfig.toggleSep(theme, gid) }
    function toggleIconOnly(gid) { WidgetsConfig.toggleIconOnly(theme, gid) }
    function parseGidCsv(s) { return WidgetsConfig.parseGidCsv(s) }

    // ── per-widget palette styles ──
    // Stored by stable GID, so slot reordering and temporarily hidden widgets
    // never lose their visual assignment.
    property var widgetColorStyles: ({})
    function widgetGidValid(gid) { return WidgetsConfig.widgetGidValid(gid) }
    function widgetColorModeValid(mode) { return WidgetsConfig.widgetColorModeValid(mode) }
    function normalizedWidgetColorMode(mode, colorId) { return WidgetsConfig.normalizedWidgetColorMode(mode, colorId) }
    function widgetToneValid(tone) { return WidgetsConfig.widgetToneValid(tone) }
    function widgetColorStyle(gid) { return WidgetsConfig.widgetColorStyle(theme, gid) }
    function setWidgetColorStyle(gid, colorId, mode, tone) { WidgetsConfig.setWidgetColorStyle(theme, gid, colorId, mode, tone) }
    function setWidgetPaletteColor(gid, colorId) { WidgetsConfig.setWidgetPaletteColor(theme, gid, colorId) }
    function setWidgetColorMode(gid, mode) { WidgetsConfig.setWidgetColorMode(theme, gid, mode) }
    function setWidgetBorderEnabled(gid, enabled) { WidgetsConfig.setWidgetBorderEnabled(theme, gid, enabled) }
    function setWidgetTone(gid, tone) { WidgetsConfig.setWidgetTone(theme, gid, tone) }
    function resetWidgetColor(gid) { WidgetsConfig.resetWidgetColor(theme, gid) }
    function resetAllWidgetFillColors() { return WidgetsConfig.resetAllWidgetFillColors(theme) }
    function widgetPaletteId(gid) { return WidgetsConfig.widgetPaletteId(theme, gid) }
    function widgetColorMode(gid) { return WidgetsConfig.widgetColorMode(theme, gid) }
    function widgetTone(gid) { return WidgetsConfig.widgetTone(theme, gid) }
    function widgetHasFill(gid) { return WidgetsConfig.widgetHasFill(theme, gid) }
    function widgetHasBorder(gid) { return WidgetsConfig.widgetHasBorder(theme, gid) }
    function widgetAssignedColor(gid) { return WidgetsConfig.widgetAssignedColor(theme, gid) }
    function _linearColorChannel(v) { return WidgetsConfig._linearColorChannel(v) }
    function _relativeLuminance(c) { return WidgetsConfig._relativeLuminance(theme, c) }
    function _contrastRatio(a, b) { return WidgetsConfig._contrastRatio(theme, a, b) }
    function paletteContrastColor(id) { return WidgetsConfig.paletteContrastColor(theme, id) }
    function widgetContrastColor(gid) { return WidgetsConfig.widgetContrastColor(theme, gid) }
    function widgetContentColor(gid, fallback) { return WidgetsConfig.widgetContentColor(theme, gid, fallback) }
    function widgetFillColor(gid) { return WidgetsConfig.widgetFillColor(theme, gid) }
    function widgetBorderColor(gid) { return WidgetsConfig.widgetBorderColor(theme, gid) }
    function serializeWidgetColorStyles() { return WidgetsConfig.serializeWidgetColorStyles(theme) }
    function parseWidgetColorStyles(raw) { return WidgetsConfig.parseWidgetColorStyles(theme, raw) }
    function buildSaveWidgetsLine() { return WidgetsConfig.buildSaveWidgetsLine(theme) }
    function parseLoadedWidgets(rawText) { WidgetsConfig.parseLoadedWidgets(theme, rawText) }

    readonly property string widgetsCachePath: Quickshell.env("HOME") + "/.cache/quickshell_widgets_v2"
    readonly property string desktopMenuModeCachePath: Quickshell.env("HOME") + "/.cache/quickshell_desktop_menu_mode"
    property bool _desktopMenuModeLoaded: false
    property bool _widgetsLoaded: false

    onModMemoryChanged:     if (_widgetsLoaded) saveWidgets()
    onModCpuTemperatureChanged: if (_widgetsLoaded) saveWidgets()
    onModGpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModStorageChanged:    if (_widgetsLoaded) saveWidgets()
    onModBrightnessChanged: if (_widgetsLoaded) saveWidgets()
    onModClaudeChanged:     if (_widgetsLoaded) saveWidgets()
    onModPowerChanged:      if (_widgetsLoaded) saveWidgets()
    onModBluetoothChanged:  if (_widgetsLoaded) saveWidgets()
    onModNetworkChanged:    if (_widgetsLoaded) saveWidgets()
    onModStatusChanged:     if (_widgetsLoaded) saveWidgets()
    onModQuickChanged:      if (_widgetsLoaded) saveWidgets()
    onModCpuChanged:        if (_widgetsLoaded) saveWidgets()
    onModVolumeChanged:     if (_widgetsLoaded) saveWidgets()
    onModMprisChanged:      if (_widgetsLoaded) saveWidgets()
    onMprisBarStyleChanged: if (_widgetsLoaded) saveWidgets()
    onAiToolChanged:        if (_widgetsLoaded) saveWidgets()
    onWorkspaceModeChanged: if (_widgetsLoaded) saveWidgets()
    onPickerStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onLauncherLogoModeChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoTextChanged: if (_widgetsLoaded) saveWidgets()
    onLauncherLogoIconChanged: if (_widgetsLoaded) saveWidgets()
    onWeatherImperialChanged: if (_widgetsLoaded) saveWidgets()
    onClock12hChanged:        if (_widgetsLoaded) saveWidgets()
    onArchBadgePackagesChanged: if (_widgetsLoaded) saveWidgets()
    onArchBadgeThemesChanged:   if (_widgetsLoaded) saveWidgets()
    onArchBadgeShellChanged:    if (_widgetsLoaded) saveWidgets()
    onWorkspaceStyleChanged:   if (_widgetsLoaded) saveWidgets()
    onBarPositionChanged:      if (_widgetsLoaded) saveWidgets()
    onV2AutoHideChanged:       if (_widgetsLoaded) saveWidgets()
    onBarShellStyleChanged:    if (_widgetsLoaded) saveWidgets()
    onBarBorderEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onPanelTooltipBorderEnabledChanged: if (_widgetsLoaded) saveWidgets()
    onBarColorChanged:         if (_widgetsLoaded) saveWidgets()
    onWidgetIconsForegroundChanged: if (_widgetsLoaded) saveWidgets()
    onBarTemperatureSourceChanged: if (_widgetsLoaded) saveWidgets()
    onDesktopMenuListModeChanged: {
        if (_widgetsLoaded) saveWidgets()
        updatesWorkers.saveDesktopMenuMode()
    }
    onSliderStyleChanged: if (_widgetsLoaded) saveWidgets()
    onTileShape1x1Changed: if (_widgetsLoaded) saveWidgets()
    onTileShape1x2Changed: if (_widgetsLoaded) saveWidgets()
    onTileShape2x2Changed: if (_widgetsLoaded) saveWidgets()

    function saveWidgets() { updatesWorkers.saveWidgets() }

    readonly property var launcherLogoTextOptions: ["omarchy", "hyprland", "arch", "omacom"]
    readonly property var launcherLogoIconOptions: ["omarchy", "hyprland", "arch", "grid", "spark", "power", "dragon", "mark", "nix", "branch", "rebel"]

    function launcherLogoTextIndex(id) { return WidgetsConfig.launcherLogoTextIndex(theme, id) }
    function launcherLogoIconIndex(id) { return WidgetsConfig.launcherLogoIconIndex(theme, id) }
    function launcherLogoTextValid(id) { return WidgetsConfig.launcherLogoTextValid(theme, id) }
    function launcherLogoIconValid(id) { return WidgetsConfig.launcherLogoIconValid(theme, id) }
    function nextLauncherLogoText() { WidgetsConfig.nextLauncherLogoText(theme) }
    function nextLauncherLogoIcon() { WidgetsConfig.nextLauncherLogoIcon(theme) }
    function launcherConfigValue(config, a, b, c) { return WidgetsConfig.launcherConfigValue(config, a, b, c) }
    function applyLauncherConfig(config) { WidgetsConfig.applyLauncherConfig(theme, config) }
    function launcherLogoLabel(id) { return WidgetsConfig.launcherLogoLabel(id) }
    function launcherLogoIconGlyph(id) { return WidgetsConfig.launcherLogoIconGlyph(id) }
    function launcherLogoIconFont(id) { return WidgetsConfig.launcherLogoIconFont(theme, id) }
    function launcherLogoIconSize(id) { return WidgetsConfig.launcherLogoIconSize(id) }
    function launcherLogoIconXOffset(id) { return WidgetsConfig.launcherLogoIconXOffset(id) }
    function launcherLogoIconYOffset(id) { return WidgetsConfig.launcherLogoIconYOffset(id) }

    // ── New widget panel states ──
    property bool networkVisible:   false
    onNetworkVisibleChanged: popupOpened("networkVisible")
    property bool storageVisible:   false
    onStorageVisibleChanged: popupOpened("storageVisible")
    property bool bluetoothVisible: false
    onBluetoothVisibleChanged: popupOpened("bluetoothVisible")
    property bool batteryVisible:   false
    onBatteryVisibleChanged: popupOpened("batteryVisible")
    property bool brightnessVisible: false
    onBrightnessVisibleChanged: popupOpened("brightnessVisible")
    property bool mprisVisible:     false
    onMprisVisibleChanged: popupOpened("mprisVisible")
    property bool weatherVisible:   false
    onWeatherVisibleChanged: popupOpened("weatherVisible")
    property bool githubHeatmapVisible: false
    onGithubHeatmapVisibleChanged: popupOpened("githubHeatmapVisible")
    property bool workspaceVisible: false
    onWorkspaceVisibleChanged: popupOpened("workspaceVisible")

    // ── Image picker state (theme/wallpaper carousel) ──
    property bool   imagePickerVisible:  false
    onImagePickerVisibleChanged: popupOpened("imagePickerVisible")
    property string imagePickerMode:     "wallpaper"   // "theme" or "wallpaper"
    property real   quickActionsBarX:    0
    // ── Media browser state (screenshots/videos carousel) ──
    property bool   mediaBrowserVisible: false
    onMediaBrowserVisibleChanged: popupOpened("mediaBrowserVisible")
    property string mediaBrowserMode:    "screenshots"  // "screenshots" or "videos"
    // ── Idle inhibitor (Wayland idle-inhibit protocol) ──
    property bool   idleInhibited:       false
    // ── Notification state ──
    property bool notifVisible: false
    onNotifVisibleChanged: {
        if (notifVisible) {
            notifVisible = false
            if (dashboardExpanded && dashboardDetail === "notifications") {
                dashboardExpanded = false
                dashboardDetail = ""
            } else {
                dashboardDetail = "notifications"
                dashboardExpanded = true
            }
        }
    }
    property int  notifCount:   0
    property real notifBarX:    0

    // ── Power Profile state ──
    property bool powerProfileVisible: false
    onPowerProfileVisibleChanged: popupOpened("powerProfileVisible")
    property string powerProfileCurrent: ""

    // ── Hyprland workspace dispatch (config-mode-aware) ──
    // Hyprland 0.55 added Lua configs but still supports classic hyprlang, and
    // BOTH ship the same version number — so the dispatch form depends on which
    // config is ACTIVE, not the version: classic wants "workspace N", Lua wants
    // hl.dsp.focus({ workspace = N }). Probe the mode once with a harmless token:
    // "hl.dsp" alone yields the Lua error "hl.dispatch: expected a dispatcher"
    // under Lua, or "Invalid dispatcher" under classic — neither switches.
    property bool hyprUsesLua: false
    function gotoWorkspace(id) { liveActivities.gotoWorkspace(id) }

    // ── Workspace Switcher (Super + Tab) ──
    property bool workspaceSwitchingActive: false
    property int workspaceTargetId: -1
    property var clientsList: []

    Process {
        id: wsClientsQuery
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text)
                    if (Array.isArray(parsed)) theme.clientsList = parsed
                } catch(e) {}
            }
        }
    }

    function refreshClientsList() {
        if (!wsClientsQuery.running) wsClientsQuery.running = true
    }

    Timer {
        id: workspaceSwitchTimer
        interval: 15000
        repeat: false
        onTriggered: {
            theme.finishWorkspaceSwitch()
        }
    }

    function getSortedWorkspacesList() {
        var occupiedIds = {}
        for (var c = 0; c < clientsList.length; c++) {
            var cl = clientsList[c]
            if (cl.workspace && cl.workspace.id > 0) {
                occupiedIds[cl.workspace.id] = true
            }
        }

        var allIds = {}
        if (typeof Hyprland !== "undefined" && Hyprland.workspaces && Hyprland.workspaces.values) {
            var ws = Hyprland.workspaces.values
            for (var i = 0; i < ws.length; i++) {
                if (ws[i].id > 0) allIds[ws[i].id] = true
            }
        }
        if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id > 0) {
            allIds[Hyprland.focusedWorkspace.id] = true
        }

        var list = Object.keys(allIds).map(Number).sort(function(a, b) { return a - b })
        if (list.length === 0) list = [1]

        // Check if ANY workspace currently in `list` is already empty
        var hasEmptyAlready = false
        for (var j = 0; j < list.length; j++) {
            if (!occupiedIds[list[j]]) {
                hasEmptyAlready = true
                break
            }
        }

        // Only add a new empty workspace if there is NO empty workspace in the list!
        if (!hasEmptyAlready) {
            var nextEmpty = 1
            while (allIds[nextEmpty]) nextEmpty++
            list.push(nextEmpty)
            list.sort(function(a, b) { return a - b })
        }

        return list
    }

    function switchWorkspace(dir) {
        workspaceSwitchTimer.stop()
        workspaceSwitchingActive = true
        refreshClientsList()

        if (!dashboardExpanded || dashboardDetail !== "workspaces") {
            dashboardDetail = "workspaces"
            dashboardExpanded = true
        }

        var wsList = getSortedWorkspacesList()
        if (wsList.length === 0) return

        var curId = (workspaceTargetId > 0)
            ? workspaceTargetId
            : ((typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) ? Hyprland.focusedWorkspace.id : wsList[0])
        var curIdx = wsList.indexOf(curId)
        if (curIdx < 0) curIdx = 0

        var nextIdx = 0
        if (dir === "prev") {
            nextIdx = (curIdx - 1 + wsList.length) % wsList.length
        } else {
            nextIdx = (curIdx + 1) % wsList.length
        }

        var nextWsId = wsList[nextIdx]
        workspaceTargetId = nextWsId

        gotoWorkspace(nextWsId)

        workspaceSwitchTimer.restart()
    }

    function finishWorkspaceSwitch() {
        workspaceSwitchTimer.stop()
        if (workspaceSwitchingActive) {
            workspaceSwitchingActive = false
            workspaceTargetId = -1
            dashboardExpanded = false
            dashboardDetail = ""
        }
    }

    // ── Arch Updater state ──
    property bool archVisible: false
    onArchVisibleChanged: popupOpened("archVisible")
    property var archUpdates: []
    property int archRefreshTick: 0
    property string archScanId: ""
    property int archScanCheckedEpoch: 0
    property string archScanHash: ""
    property int archScanSystemCount: 0
    readonly property int archScanMaxAge: 900

    // ── Arch security gate (pre-install verdict per package) ──
    // idle | scanning | clean | warn | blocked | degraded
    property string archGateState: "idle"
    property var    archGateResults: []   // [{pkg,repo,old,new,verdict,reason}]
    property int    archGateOk: 0
    property int    archGateWarn: 0
    property int    archGateFail: 0
    property int    archGateBlacklist: 0
    property bool   archGateDegraded: false
    property string archGateListDate: ""   // freshest blacklist date (meta updated_at, else mtime)
    property bool   archGateStale: false          // protection list older than the gate's stale window
    property bool   archGateMirrorsAgree: false   // both feed mirrors produced an identical list
    property bool   archGateMirrorMismatch: false // feeds diverged → using their union, flagged

    // Manual retry, e.g. on panel open: a degraded verdict can be a transient
    // (blacklist file mid-update at scan time) and must not stick until the
    // next refresh.
    function archGateRescan() { updatesWorkers.archGateRescan() }

    // ── Shell Updater state (shared by ArchUpdaterWidget and ShellUpdateTab) ──
    property int  shellUpdateBehind: 0
    property var  shellUpdateSummary: []
    property string shellUpdateVersion: ""
    property string shellUpdateChecked: ""
    property string shellUpdateBaseCommit: ""
    property string shellUpdateTargetCommit: ""
    property string shellUpdateRepository: ""
    property string shellUpdateUpstreamRef: ""
    property string shellInstalledCommit: ""
    property bool shellUpdateChecking: false
    property string shellProgressRunId: ""
    property string shellProgressState: "idle"
    property string shellProgressPhase: ""
    property int shellProgressStep: 0
    property int shellProgressTotalSteps: 5
    property string shellProgressTargetCommit: ""
    property int shellProgressStartedEpoch: 0
    property int shellProgressUpdatedEpoch: 0
    property string shellProgressScreenName: ""
    property string shellProgressError: ""
    property bool shellProgressAcknowledged: true
    property bool shellProgressPanelOpen: true
    property int shellProgressNowEpoch: Math.floor(Date.now() / 1000)
    property string _shellProgressCompleteRunId: ""
    readonly property bool shellProgressInterrupted: shellProgressState === "running"
        && shellProgressUpdatedEpoch > 0
        && shellProgressNowEpoch - shellProgressUpdatedEpoch > 600
    readonly property bool shellProgressRunning: shellProgressState === "running" && !shellProgressInterrupted
    readonly property bool shellProgressFailed: shellProgressState === "failed"
    readonly property bool shellProgressCompleted: shellProgressState === "completed" && !shellProgressAcknowledged
    readonly property bool shellUpdateProgressVisible: shellProgressRunning
        || shellProgressFailed || shellProgressCompleted || shellProgressInterrupted

    function updateShellProgressClock() { updatesWorkers.updateShellProgressClock() }
    function resetShellProgress() { updatesWorkers.resetShellProgress() }
    function openShellProgressPanel() { updatesWorkers.openShellProgressPanel() }
    function resetShellUpdateState() { updatesWorkers.resetShellUpdateState() }
    function parseShellUpdateState(raw) { updatesWorkers.parseShellUpdateState(raw) }
    function parseShellInstalledCommit(raw) { updatesWorkers.parseShellInstalledCommit(raw) }
    function parseShellProgress(raw) { updatesWorkers.parseShellProgress(raw) }
    function ackShellProgress() { updatesWorkers.ackShellProgress() }
    function setShellProgressPanelOpen(open) { updatesWorkers.setShellProgressPanelOpen(open) }
    function closeArchUpdatesPanel() { updatesWorkers.closeArchUpdatesPanel() }
    function showShellUpdateTabFromWidget() { updatesWorkers.showShellUpdateTabFromWidget() }
    function reloadShellUpdateState() { updatesWorkers.reloadShellUpdateState() }

    // ── Theme Updater state (fed by ArchUpdaterPanel's FileView over
    //    ~/.cache/qs-theme-updates.json; the panel owns the check Process so it
    //    runs ONCE, not per-monitor). The bar/tooltip only read these counts;
    //    the panel renders themeUpdList. Theme updates run in a visible terminal
    //    through qs-theme-apply-update.sh and are pinned to the checked target
    //    commit. ──
    property int    themeUpdOutdated: 0
    property int    themeUpdLocalEdits: 0
    property int    themeUpdTotal: 0
    property int    themeUpdReachable: 0
    property bool   themeUpdDegraded: false
    property bool   themeUpdCurrentStale: false
    property string themeUpdChecked: ""      // ISO timestamp of the last check, "" = never
    property var    themeUpdList: []          // outdated/unreachable entries shown in the panel
    property bool   themeUpdChecking: false   // a check is in flight (button disabled)
    property int    themeCheckTick: 0         // ++ from the panel button to trigger a check
    property string activeUpdateTab: "packages"   // which ArchUpdaterPanel tab is shown
    property bool   archBadgePackages: true   // package count badge on the bar updater icon
    property bool   archBadgeThemes: true     // clean-theme count badge on the bar updater icon
    property bool   archBadgeShell: true      // shell-update badge on the bar updater icon

    // ── Tray state ──
    property bool trayVisible: false
    onTrayVisibleChanged: popupOpened("trayVisible")
    property var trayPinned: []
    property real trayBarX: 10
    property real trayCaretBarX: trayBarX

    // ── slot-aware panel X anchors (center-X of each group; set by BarSlot) ──
    property real volumeBarX:     0
    property real networkBarX:    0
    property real batteryBarX:    0
    property real memoryBarX:     0
    property real cpuBarX:        0
    property real screentimeBarX: 0
    property real gpuBarX:        0
    property real thermalBarX:    0
    property real storageBarX:    0
    property real aiBarX:         0
    property real workspaceBarX:  0
    property real archBarX:       0
    property real archCaretBarX:  archBarX
    property real notifCaretBarX: notifBarX
    property real bluetoothBarX:  0
    property real brightnessBarX: 0
    property real powerBarX:      0
    property real mprisBarX:      0
    property real weatherBarX:    0
    property real githubHeatmapBarX: 0
    property real calendarBarX:   weatherBarX
    property real launcherBarX:   6   // ControlPanel follows the Launcher/Control group

    // One connected popover at a time: the active panel publishes the exact
    // bar-widget center used by both the caret and the small border opening.
    readonly property bool anchoredPanelVisible: calendarVisible || cpuVisible || gpuVisible
        || thermalVisible || aiUsageVisible
        || memVisible || volVisible || controlVisible || networkVisible || bluetoothVisible
        || batteryVisible || brightnessVisible || mprisVisible || weatherVisible
        || workspaceVisible || notifVisible || powerProfileVisible || storageVisible
        || archVisible || trayVisible

    // Preserve the panel surface's actually rendered tip while it closes so
    // the matching bar notch retracts at the same point. Edge panels clamp the
    // tip away from their rounded corner, so the raw widget center is not
    // always the final rendered position.
    property real panelInsetX: 0
    property bool panelInsetReady: false
    function setPanelInsetX(x) { PopupLayout.setPanelInsetX(theme, x) }
    property real panelInsetReveal: anchoredPanelVisible ? 1 : 0
    onPanelInsetRevealChanged: {
        if (!anchoredPanelVisible && panelInsetReveal <= 0.001)
            panelInsetReady = false
    }
    Behavior on panelInsetReveal {
        NumberAnimation {
            duration: theme.anchoredPanelVisible ? 160 : 120
            easing.type: theme.anchoredPanelVisible ? Easing.OutBack : Easing.InCubic
        }
    }

    // ── Tray context-menu state (themed menu, rendered by TrayMenu.qml) ──
    property bool trayMenuVisible: false
    onTrayMenuVisibleChanged: popupOpened("trayMenuVisible")
    property var  trayMenuHandle: null   // the QsMenuHandle of the clicked item
    property real trayMenuX: 0           // global x to anchor the menu under the icon
    property string trayMenuTitle: ""
    property string trayMenuIcon: ""

    function trayDisplayName(item) { return PopupLayout.trayDisplayName(item) }
    function trayDescription(item, displayName) { return PopupLayout.trayDescription(item, displayName) }
    function openTrayMenu(handle, x, title, icon) { PopupLayout.openTrayMenu(theme, handle, x, title, icon) }
    function trayIsHidden(item) { return PopupLayout.trayIsHidden(theme, item) }
    // toggle: hidden items get pinned (shown in bar); pinned items get unpinned (back to panel)
    function trayToggleHide(item) { PopupLayout.trayToggleHide(theme, item) }

    function ipcApplyTheme(payload) { updatesWorkers.ipcApplyTheme(payload) }
    function ipcApplyLauncher(payload) { updatesWorkers.ipcApplyLauncher(payload) }
    function ipcReloadTheme() { updatesWorkers.ipcReloadTheme() }
    function ipcOpenPicker(mode) { updatesWorkers.ipcOpenPicker(mode) }

    ThemeTelemetryWorkers { id: telemetryWorkers; theme: theme }
    ThemeStatusWorkers { id: statusWorkers; theme: theme }
    ThemeLiveActivities { id: liveActivities; theme: theme }
    ThemeUpdatesWorkers { id: updatesWorkers; theme: theme }
}

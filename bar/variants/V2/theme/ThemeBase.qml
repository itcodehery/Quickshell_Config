import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "ThemePopupAndLayout.js" as PopupLayout
import "ThemeTelemetry.js" as Telemetry

Item {
    id: theme
    property var variantHost: null
    property string lastMediaTitle: ""
    property string lastMediaArtist: ""
    property string lastMediaArtUrl: ""

    property string omarchyCurrentRoot: Quickshell.env("HOME") + "/.config/omarchy/current"
    property string omarchyInstallRoot: Quickshell.env("HOME") + "/.local/share/omarchy"
    property bool omarchyCurrentRootResolved: false
    readonly property string themeNamePath: omarchyCurrentRoot + "/theme.name"
    readonly property string colorsPath: omarchyCurrentRoot + "/theme/colors.toml"
    readonly property string currentBackgroundPath: omarchyCurrentRoot + "/background"
    readonly property string currentBackgroundsPath: omarchyCurrentRoot + "/theme/backgrounds"
    property string currentThemeName: ""
    readonly property string userBackgroundsPath: currentThemeName === ""
        ? ""
        : Quickshell.env("HOME") + "/.config/omarchy/backgrounds/" + currentThemeName
    readonly property var wallpaperSourcePaths: userBackgroundsPath === ""
        ? [currentBackgroundsPath]
        : [currentBackgroundsPath, userBackgroundsPath]

    function setCurrentThemeName(rawName) { PopupLayout.setCurrentThemeName(theme, rawName) }

    property color paper:   "#181616"
    property color ink:     "#c5c9c5"
    property color sumi:    "#a6a69c"
    property color color01: "#c4746e"
    property color color02: "#8a9a73"
    property color color03: "#c8b36a"
    property color color04: "#658594"
    property color color05: "#957fb8"
    property color color06: "#7aa89f"
    property color color07: "#c8c093"
    readonly property color inkDeep: color07
    readonly property color indigo:  color04
    readonly property color sealRaw: color01
    readonly property color sumiHi:  Qt.rgba(sumi.r*0.45 + ink.r*0.55, sumi.g*0.45 + ink.g*0.55, sumi.b*0.45 + ink.b*0.55, 1.0)  // lifted section-header text
    property color green:   "#8a9a73"   // gate "OK" verdict
    property color accentHint: sealRaw    // filled by palette; default = same as red
    readonly property color foregroundSoft: Qt.rgba(
        ink.r * 0.88 + paper.r * 0.12,
        ink.g * 0.88 + paper.g * 0.12,
        ink.b * 0.88 + paper.b * 0.12,
        1.0)
    property string barColor: "color01"
    property bool widgetIconsForeground: false
    property color mprisDominantColor: "transparent"
    property string _mprisColorCachedSource: ""
    property string sharedWeatherIcon: "·"
    property string sharedWeatherPlace: ""
    property string sharedWeatherTemp: ""
    property string sharedWeatherDesc: ""
    property bool sharedWeatherLoaded: false
    property bool sharedWeatherUnavailable: false
    property double _weatherLastFetchMs: 0
    readonly property bool barColorIsAccent: barColor === "accent"
    // Compatibility alias for older local code/reviews that still use the
    // previous boolean name.
    readonly property bool useThemeAccent: barColorIsAccent

    function paletteColor(id) { return PopupLayout.paletteColor(theme, id) }
    function normalizedPaletteId(id) { return PopupLayout.normalizedPaletteId(theme, id) }
    readonly property color seal: paletteColor(barColor)
    // Legacy global foreground switch is retained only for cache compatibility.
    // Widget colors now inherit Bar Color or use a per-GID palette style.
    readonly property color widgetIconColor: seal
    readonly property var barColorOptions: [
        "color01", "color02", "color03", "color04",
        "color05", "color06", "color07", "foreground"
    ]
    function paletteColorValid(id) { return PopupLayout.paletteColorValid(id) }
    function barColorValid(id) { return PopupLayout.barColorValid(id) }
    function barColorLabel(id) { return PopupLayout.barColorLabel(id) }

    readonly property string mono:  "JetBrainsMono Nerd Font"
    readonly property string barFont: "Genova"

    // ── transparency knobs (0.0 = fully transparent, 1.0 = opaque) ──
    property real barOpacity:  1.0   // durchgehende V2-Leiste
    property real pillOpacity: 0.18   // einzelne Widget-Pillen (workspace, mem, cpu, …)

    readonly property real surfaceOpacity: barOpacity
    readonly property color bg:     Qt.rgba(paper.r, paper.g, paper.b, surfaceOpacity)
    readonly property color barBg:  Qt.rgba(paper.r, paper.g, paper.b, surfaceOpacity)
    readonly property color pill:   Qt.rgba(paper.r, paper.g, paper.b, pillOpacity)
    readonly property color fg:     ink
    readonly property color muted:  sumi
    readonly property color accent: seal
    readonly property color warn:   seal
    readonly property color sep:    Qt.rgba(ink.r, ink.g, ink.b, 0.18)

    // ── interactive fill tokens (button/tile backgrounds) ──
    // One source of truth so every panel uses the same hover/active/idle alpha
    // instead of ad-hoc rgba literals scattered across the panels.
    readonly property real  fillActiveAlpha: 0.28
    readonly property real  fillHoverAlpha:  0.16
    readonly property color fillActive:      Qt.rgba(seal.r, seal.g, seal.b, fillActiveAlpha) // selected/active OR ghost-action hover
    readonly property color fillHover:        Qt.rgba(seal.r, seal.g, seal.b, fillHoverAlpha)  // light-seal hover (idle chip → this → fillActive)
    readonly property color fillIdle:         Qt.rgba(0, 0, 0, 0.12)              // resting chip (slight darken)
    // faint, NEUTRAL backdrop behind picker thumbnails — NOT an interactive fill.
    // ink-tinted and much weaker than fillIdle so a thumbnail sits on a quiet frame,
    // not on a dark interactive-looking box.
    readonly property color frameWeak:        Qt.rgba(ink.r, ink.g, ink.b, 0.05)
    readonly property color fillPrimaryHover: Qt.lighter(seal, 1.15)                // solid-seal button hover
    function evenW(w) { return 2 * Math.round(w / 2) }  // even px width -> integer-centered native text (crisp)

    // ── Multi-monitor popup routing ─────────────────────────────
    // Bars exist per screen, but panels remain singletons. The bar under the
    // pointer publishes its screen + local anchor map before any widget opens a
    // popup, so the singleton panel can move to the correct output.
    property var activePopupScreen: null
    property string activePopupScreenName: ""
    property var barAnchorsByScreen: ({})
    property bool _closingPopups: false
    property var barLayoutControllers: ({})
    property bool _barLayoutSyncing: false

    function registerBarLayoutController(screenName, controller) { PopupLayout.registerBarLayoutController(theme, screenName, controller) }
    function unregisterBarLayoutController(screenName, controller) { PopupLayout.unregisterBarLayoutController(theme, screenName, controller) }
    function barLayoutControllerScreenValid(screenName) { return PopupLayout.barLayoutControllerScreenValid(screenName) }
    function barLayoutControllerKeys() { return PopupLayout.barLayoutControllerKeys(theme) }
    function applyToBarLayoutControllers(actionName) { PopupLayout.applyToBarLayoutControllers(theme, actionName) }
    function syncBarOrder(sourceScreenName, serialized) { PopupLayout.syncBarOrder(theme, sourceScreenName, serialized) }
    function resetAllBarLayouts() { PopupLayout.resetAllBarLayouts(theme) }
    function resetBarLayoutPresentation() { PopupLayout.resetBarLayoutPresentation(theme) }
    function activatePopupScreen(screen) { PopupLayout.activatePopupScreen(theme, screen) }
    function activateFocusedPopupScreen() { return PopupLayout.activateFocusedPopupScreen(theme) }
    function activatePopupScreenByName(screenName) { return PopupLayout.activatePopupScreenByName(theme, screenName) }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (!theme.keyboardPopupVisible || theme.activePopupScreenName === "") return
            var monitor = Hyprland.focusedMonitor
            var focusedName = monitor ? monitor.name : ""
            if (focusedName !== "" && focusedName !== theme.activePopupScreenName) {
                theme.closePopups()
            }
        }
    }

    function isActivePopupScreenName(screenName) { return PopupLayout.isActivePopupScreenName(theme, screenName) }
    function applyAnchor(name, x) { PopupLayout.applyAnchor(theme, name, x) }
    function applyActiveBarAnchors() { PopupLayout.applyActiveBarAnchors(theme) }
    function publishBarAnchors(screenName, anchors) { PopupLayout.publishBarAnchors(theme, screenName, anchors) }
    function setPanelAnchor(name, x, screenName) { PopupLayout.setPanelAnchor(theme, name, x, screenName) }
    function closePopups(except) { PopupLayout.closePopups(theme, except) }
    function popupUsesConnectedInset(prop) { return PopupLayout.popupUsesConnectedInset(prop) }
    function popupOpened(prop) { PopupLayout.popupOpened(theme, prop) }
    function applyTheme(name) { PopupLayout.applyTheme(theme, name) }
    function applyWallpaper(path) { PopupLayout.applyWallpaper(path) }
    function openImagePicker(mode, screen) { PopupLayout.openImagePicker(theme, mode, screen) }
    function toggleImagePicker(mode, screen) { PopupLayout.toggleImagePicker(theme, mode, screen) }
    function openMediaBrowser(mode) { PopupLayout.openMediaBrowser(theme, mode) }
    signal requestNightLightPopup()

    // ── bar screen position & outer bar shell (persisted) ──
    property string barPosition: "top"   // "top" or "bottom"
    // ── bar auto-hide (persisted) ──
    // Auto-hide removed. Kept only so the persisted widget-state field (+45)
    // stays position-stable; it is always written as "0" and never read back.
    readonly property bool v2AutoHide: false
    property string barShellStyle: "pill"
    onBarShellStyleChanged: {
        if (barShellStyle !== "notch" && barShellStyle !== "pill" && barShellStyle !== "island") {
            barShellStyle = "pill"
        }
    }
    readonly property bool isBarPill: barShellStyle === "pill" || barShellStyle === "island"
    readonly property bool isBarNotch: barShellStyle === "notch"
    property bool barBorderEnabled: true
    property bool panelTooltipBorderEnabled: true
    // ── desktop context menu presentation mode (radial vs list, persisted) ──
    property bool desktopMenuListMode: false
    function barShellStyleValid(value) {
        return value === "pill" || value === "island" || value === "notch"
    }

    // ── pill/card border (default, non-borderless mode) ──
    // A premium "inactive window border" look: the surface tone (paper) nudged a
    // tick toward the foreground (ink) → a quiet edge a touch brighter than the
    // background, theme-aware in BOTH dark and light palettes. Tune via pillBorderMix.
    property real pillBorderMix: 0.13
    readonly property color pillBorder: Qt.rgba(
        paper.r * (1 - pillBorderMix) + ink.r * pillBorderMix,
        paper.g * (1 - pillBorderMix) + ink.g * pillBorderMix,
        paper.b * (1 - pillBorderMix) + ink.b * pillBorderMix, 1.0)
    // outer frame (the island edge against the wallpaper): a tick brighter than
    // the inner pill border so the bar lifts off the background → two readable
    // borders (subtle inner pills + a defined outer frame).
    property real islandBorderMix: 0.16
    readonly property color islandBorder: Qt.rgba(
        paper.r * (1 - islandBorderMix) + ink.r * islandBorderMix,
        paper.g * (1 - islandBorderMix) + ink.g * islandBorderMix,
        paper.b * (1 - islandBorderMix) + ink.b * islandBorderMix, 1.0)

    // ── V2 continuous edge-bar tokens ──
    // The compact visible strip uses one full-width surface, one quiet
    // screen-facing edge and a shadow cast away from that edge. Keeping these
    // separate from the pill recipe lets widgets and panels retain their
    // established hierarchy.
    readonly property int v2BarHeight: 33
    // Horizontal rhythm for the bar. Closely related icon buttons use the
    // 2px cluster step; icon+text pairs use 4px; independent widgets use 6px;
    // distinct information sections use 8px. A compact action cell stays 22px
    // wide, yielding a calm 24px centre-to-centre pitch inside icon clusters.
    readonly property int v2IconClusterSpacing: 2
    readonly property int v2InlineSpacing: 4
    readonly property int v2WidgetSpacing: 6
    readonly property int v2SectionSpacing: 8
    readonly property int v2ActionIconCellWidth: 22
    readonly property int v2IconGroupPadding: 5
    property real v2BarBorderMix: 0.22
    readonly property color v2BarBorder: Qt.rgba(
        paper.r * (1 - v2BarBorderMix) + ink.r * v2BarBorderMix,
        paper.g * (1 - v2BarBorderMix) + ink.g * v2BarBorderMix,
        paper.b * (1 - v2BarBorderMix) + ink.b * v2BarBorderMix, 1.0)
    readonly property color v2BarShadow: Qt.rgba(0, 0, 0, 0.46)
    // Popovers, tooltips and their interactive tiles share the calmer V2 shape;
    // bar-widget pills remain independently configurable below.
    readonly property int panelRadius: 6
    readonly property int panelButtonRadius: 6
    readonly property color panelBorder: v2BarBorder
    readonly property int panelBorderW: 1
    readonly property color panelOuterBorderColor: panelTooltipBorderEnabled
        ? panelBorder : Qt.rgba(0, 0, 0, 0)
    readonly property int panelOuterBorderW: panelTooltipBorderEnabled ? panelBorderW : 0

    // Fixed V2 geometry. The former Style section was removed; keeping these
    // shared constants avoids duplicating the established dimensions.
    readonly property int   pillRadius:   12
    readonly property int   pillH:        24
    readonly property int   pillBorderW:  1
    readonly property int   islandRadius: 16
    readonly property int   tileRadius:   10
    readonly property int   wsPillPad:    0
    readonly property color pillShadow:   Qt.rgba(0, 0, 0, 0.55)   // dark, theme-independent

    property string lastAppliedName: ""

    // ── Tooltip state ──
    property string tooltipText: ""
    property real tooltipX: 0
    property real tooltipY: 0
    property real tooltipTopY: 0
    property real tooltipBottomY: 0
    property bool tooltipShown: false
    property var tooltipOwner: null   // the widget currently owning the tooltip

    function showTooltip(text, x, topY, bottomY, owner) { PopupLayout.showTooltip(text, x, topY, bottomY, owner) }
    // hide only if the caller owns the current tooltip (owner match is stable
    // even when the tooltip text changes, e.g. a live timer). A null/undefined
    // owner force-hides. Legacy string args fall back to a text match.
    function hideTooltip(owner) { PopupLayout.hideTooltip(theme, owner) }

    // safety net: if the owning widget disappears while its tooltip is shown
    // (e.g. ScreenRecord stops mid-hover, or a slot widget gets disabled), force-hide.
    // Via Connections — NOT a `_visible` property whose change-handler writes
    // tooltipOwner (that property read tooltipOwner → binding loop).
    Connections {
        target: theme.tooltipOwner
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (theme.tooltipOwner && !theme.tooltipOwner.visible) {
                theme.tooltipShown = false; theme.tooltipOwner = null;
            }
        }
    }

    // ── Calendar state ──
    property bool calendarVisible: false
    onCalendarVisibleChanged: popupOpened("calendarVisible")
    property int calendarMonthOffset: 0
    property int calendarTick: 0
    property int selectedDay: 0

    readonly property var calendarCells: Telemetry.computeCalendarCells(theme)
    readonly property string calendarMonthName: Telemetry.computeCalendarMonthName(theme)
    readonly property string calendarYear: Telemetry.computeCalendarYear(theme)
    function openCalendar() { Telemetry.openCalendar(theme) }

    // ── CPU panel state ──
    property bool cpuVisible: false
    onCpuVisibleChanged: popupOpened("cpuVisible")

    // ── GPU panel state ──
    property bool gpuVisible: false
    onGpuVisibleChanged: popupOpened("gpuVisible")

    // ── Thermal panel state ──
    property bool thermalVisible: false
    onThermalVisibleChanged: popupOpened("thermalVisible")

    // ── AI usage panel state + which tool the bar pill shows ──
    property bool   aiUsageVisible: false
    property real   aiUsageReveal: aiUsageVisible ? 1 : 0
    Behavior on aiUsageReveal {
        NumberAnimation {
            duration: theme.aiUsageVisible ? 160 : 120
            easing.type: theme.aiUsageVisible ? Easing.OutBack : Easing.InCubic
        }
    }
    onAiUsageVisibleChanged: {
        popupOpened("aiUsageVisible")
        if (aiUsageVisible) theme.refreshAiUsage()
    }
    property string aiTool: "agy"   // "claude", "codex", "opencode", or "agy" — icon shown in the bar

    // ── AI usage data (single source of truth) ───────────────────
    // The bar pill (ClaudeWidget) and the AiUsagePanel both render from these —
    // the cache parsing lives ONLY here so the two views can never drift apart.
    // Token strings are bare "X.XXM / Y.YM"; the pill tooltip appends " tokens".
    property bool   aiClHas: false
    property bool   aiClFresh: false
    property int    aiClPct5h: 0
    property int    aiClPct7d: 0
    property bool   aiClBlocked: false
    property string aiClTokens: ""
    property string aiClRate: ""
    property int    aiClReset5hTs: 0
    property int    aiClReset7dTs: 0
    property int    aiClToday: 0

    property bool   aiCxHas: false
    property bool   aiCxFresh: false
    property int    aiCxPct5h: 0
    property int    aiCxPct7d: 0
    property string aiCxPlan: ""
    property string aiCxTokens: ""
    property string aiCxRate: ""
    property int    aiCxReset5hTs: 0
    property int    aiCxReset7dTs: 0
    property int    aiCxToday: 0
    property var    aiCxBuckets: []
    property var    aiCxWindows: []
    property int    aiCxPrimaryPct: 0
    property string aiCxPrimaryLabel: ""
    property int    aiCxPrimaryResetTs: 0
    property int    aiCxQuotaPct: 0
    property string aiCxQuotaLabel: ""
    property string aiCxLimitStatus: ""
    property string aiCxLimitReachedType: ""

    property bool   aiOcHas: false
    property bool   aiOcFresh: false
    property int    aiOcPct5h: 0
    property int    aiOcPct7d: 0
    property string aiOcPlan: ""
    property string aiOcTokens: ""
    property string aiOcRate: ""
    property string aiOcModel: ""
    property int    aiOcToday: 0
    property var    aiOcModels: []

    property bool   aiAgyHas: false
    property string aiAgyTotalSessions: "0"
    property string aiAgyTotalSteps: "0"
    property string aiAgyTodaySessions: "0"
    property string aiAgyTodaySteps: "0"

    property int    aiClockTick: 0

    // F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
    // otherwise produce wrong text and negative/overwide usage bars)
    function aiPct(v) { return Telemetry.aiPct(v) }
    function aiWindowLabel(minutes) { return Telemetry.aiWindowLabel(minutes) }
    function aiResetCodexUsage() { Telemetry.aiResetCodexUsage(theme) }
    function aiCodexWindowFromCache(w) { return Telemetry.aiCodexWindowFromCache(theme, w) }
    function aiCodexWindowsFromArray(arr) { return Telemetry.aiCodexWindowsFromArray(theme, arr) }
    function aiCodexLegacyWindowsFromCache(d) { return Telemetry.aiCodexLegacyWindowsFromCache(theme, d) }
    function aiCodexBucketsFromCache(d) { return Telemetry.aiCodexBucketsFromCache(theme, d) }
    function aiCodexGeneralBucket(buckets) { return Telemetry.aiCodexGeneralBucket(buckets) }
    function aiPlanLabel(plan) { return Telemetry.aiPlanLabel(plan) }
    function aiApplyCodexCache(d, ageOk) { Telemetry.aiApplyCodexCache(theme, d, ageOk) }
    function aiCodexStatusLabel(status, reachedType) { return Telemetry.aiCodexStatusLabel(status, reachedType) }
    function aiFmtReset(ts) { return Telemetry.aiFmtReset(theme, ts) }
    function aiPad2(n) { return Telemetry.aiPad2(n) }
    function aiFmtResetClock(ts) { return Telemetry.aiFmtResetClock(theme, ts) }
    function aiFmtResetDetail(ts) { return Telemetry.aiFmtResetDetail(theme, ts) }

    // ── Central system telemetry ──
    // One ShellRoot-level sampler feeds all monitor BarSlots. This replaces
    // per-widget bash/awk polling for CPU and memory, so adding monitors does not
    // multiply these status process chains.
    property int systemCpuPercent: 0
    property int systemCpuUserPercent: 0
    property int systemCpuSystemPercent: 0
    property int systemCpuIoWaitPercent: 0
    property real _systemCpuPrevIdle: -1
    property real _systemCpuPrevTotal: -1
    property real _systemCpuPrevUser: -1
    property real _systemCpuPrevSystem: -1
    property real _systemCpuPrevIoWait: -1
    property string cpuModelName: ""
    property int cpuCoreCount: 0
    property int cpuThreadCount: 0
    property int cpuClockMHz: 0
    property int cpuMaxClockMHz: 0
    property string cpuEnergyPreference: ""
    property string cpuScalingGovernor: ""
    property int cpuThrottleCount: 0
    property real systemLoad1: 0
    property real systemLoad5: 0
    property real systemLoad15: 0
    property string kernelRelease: ""
    property var cpuTopProcesses: []

    property int systemMemTotalMiB: 0
    property int systemMemAvailMiB: 0
    property int systemMemFreeMiB: 0
    property int systemMemBuffersMiB: 0
    property int systemMemCachedMiB: 0
    property string memoryType: ""
    property int memorySpeedMTs: 0
    readonly property int systemMemUsedMiB: Math.max(0, systemMemTotalMiB - systemMemAvailMiB)
    readonly property int systemMemPercent: systemMemTotalMiB > 0
        ? Math.max(0, Math.min(100, Math.round(systemMemUsedMiB / systemMemTotalMiB * 100)))
        : 0
    readonly property real systemMemUsedGiB: systemMemUsedMiB / 1024
    readonly property real systemMemTotalGiB: systemMemTotalMiB / 1024

    // Compact V2 telemetry. These samplers live on the singleton Theme so a
    // second monitor adds another view, not another nvidia-smi/df/hwmon poller.
    property string gpuBackend: ""
    property string gpuName: ""
    property string gpuDriverVersion: ""
    property int gpuPercent: 0
    property int gpuTemperatureC: 0
    property int gpuMemoryUsedMiB: 0
    property int gpuMemoryTotalMiB: 0
    property int gpuClockMHz: 0
    property real gpuPowerW: 0
    property real gpuPowerLimitW: 0
    property string gpuPerformanceState: ""
    property int gpuFanPercent: 0
    readonly property bool gpuAvailable: gpuBackend !== ""

    property int cpuTemperatureC: 0
    property int cpuCoreMaxTemperatureC: 0
    property int cpuTemperatureMaxC: 0
    property int cpuTemperatureCriticalC: 0
    property int nvmeTemperatureC: 0
    property int nvmeTemperatureMaxC: 0
    property int nvmeTemperatureCriticalC: 0
    property int memoryTemperatureC: 0
    readonly property bool cpuTemperatureAvailable: cpuTemperatureC > 0

    property string barTemperatureSource: "cpu"
    readonly property int barTemperatureC: barTemperatureSource === "core" ? cpuCoreMaxTemperatureC
        : barTemperatureSource === "gpu" ? gpuTemperatureC
        : barTemperatureSource === "nvme" ? nvmeTemperatureC
        : barTemperatureSource === "memory" ? memoryTemperatureC
        : cpuTemperatureC
    readonly property bool barTemperatureAvailable: barTemperatureC > 0

    function barTemperatureSourceValid(source) { return Telemetry.barTemperatureSourceValid(source) }
    function barTemperatureSourceLabel(source) { return Telemetry.barTemperatureSourceLabel(source) }
    function barTemperatureSourceAvailable(source) { return Telemetry.barTemperatureSourceAvailable(theme, source) }

    property int storagePercent: 0
    property real storageUsedBytes: 0
    property real storageTotalBytes: 0
    property bool storageAvailable: false
    readonly property real storageUsedGiB: storageUsedBytes / 1073741824
    readonly property real storageTotalGiB: storageTotalBytes / 1073741824
    property var storageDrives: []
    property bool storageInventoryAvailable: false

    function parseSystemCpu(text) { Telemetry.parseSystemCpu(theme, text) }
    function parseCpuInfo(text) { Telemetry.parseCpuInfo(theme, text) }
    function parseSystemLoad(text) { Telemetry.parseSystemLoad(theme, text) }
    function parseCpuDetail(text) { Telemetry.parseCpuDetail(theme, text) }
    function parseCpuTopProcesses(text) { Telemetry.parseCpuTopProcesses(theme, text) }
    function parseSystemMem(text) { Telemetry.parseSystemMem(theme, text) }
    function parseMemoryHardware(text) { Telemetry.parseMemoryHardware(theme, text) }
    function parseGpuTelemetry(text) { Telemetry.parseGpuTelemetry(theme, text) }
    function parseThermalTelemetry(text) { Telemetry.parseThermalTelemetry(theme, text) }
    function parseStorageInventory(text) { Telemetry.parseStorageInventory(theme, text) }
    function parseStorageTelemetry(text) { Telemetry.parseStorageTelemetry(theme, text) }
}

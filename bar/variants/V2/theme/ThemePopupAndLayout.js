// Palette helpers, multi-monitor popup routing, BarLayoutControllers,
// Tooltip helpers, and Tray helpers for Theme.qml.

function setCurrentThemeName(theme, rawName) {
    var name = String(rawName || "").trim()
    if (name === "." || name === ".." || name.indexOf("/") >= 0 || name.indexOf("\\") >= 0)
        name = ""
    theme.currentThemeName = name
}

function paletteColor(theme, id) {
    if (id === "color02") return theme.color02
    if (id === "color03") return theme.color03
    if (id === "color04") return theme.color04
    if (id === "color05") return theme.color05
    if (id === "color06") return theme.color06
    if (id === "color07") return theme.color07
    if (id === "foreground") return theme.foregroundSoft
    if (id === "accent") return theme.accentHint
    return theme.color01
}

function normalizedPaletteId(theme, id) {
    if (id === "red" || id === "accent") return "color01"
    return theme.paletteColorValid(id) ? id : "color01"
}

function paletteColorValid(id) {
    return id === "color01" || id === "color02" || id === "color03"
        || id === "color04" || id === "color05" || id === "color06"
        || id === "color07" || id === "foreground"
}

function barColorValid(id) {
    return paletteColorValid(id) || id === "red" || id === "accent"
}

function barColorLabel(id) {
    if (id === "color01" || id === "red" || id === "accent") return "Color 01"
    if (id === "color02") return "Color 02"
    if (id === "color03") return "Color 03"
    if (id === "color04") return "Color 04"
    if (id === "color05") return "Color 05"
    if (id === "color06") return "Color 06"
    if (id === "color07") return "Color 07"
    if (id === "foreground") return "Foreground"
    return "Color 01"
}

function registerBarLayoutController(theme, screenName, controller) {
    if (!screenName || !controller) return

    var next = {}
    for (var screen in theme.barLayoutControllers) next[screen] = theme.barLayoutControllers[screen]
    next[screenName] = controller
    theme.barLayoutControllers = next
}

function unregisterBarLayoutController(theme, screenName, controller) {
    if (!screenName) return
    if (controller && theme.barLayoutControllers[screenName] !== controller) return

    var next = {}
    for (var screen in theme.barLayoutControllers) {
        if (screen !== screenName) next[screen] = theme.barLayoutControllers[screen]
    }
    theme.barLayoutControllers = next
}

function barLayoutControllerScreenValid(screenName) {
    if (!screenName) return false

    for (var i = 0; i < Quickshell.screens.length; i++) {
        var screen = Quickshell.screens[i]
        if (screen.name === screenName && screen.width > 0 && screen.height > 0) return true
    }
    return false
}

function barLayoutControllerKeys(theme) {
    var keys = []
    for (var screen in theme.barLayoutControllers) {
        if (theme.barLayoutControllerScreenValid(screen)) keys.push(screen)
    }
    keys.sort()
    return keys
}

function applyToBarLayoutControllers(theme, actionName) {
    var keys = theme.barLayoutControllerKeys()

    theme._barLayoutSyncing = true
    try {
        for (var i = 0; i < keys.length; i++) {
            var controller = theme.barLayoutControllers[keys[i]]
            if (controller && controller[actionName]) controller[actionName]()
        }
    } finally {
        theme._barLayoutSyncing = false
    }
}

function syncBarOrder(theme, sourceScreenName, serialized) {
    if (theme._barLayoutSyncing || !serialized) return

    theme._barLayoutSyncing = true
    try {
        var keys = theme.barLayoutControllerKeys()
        for (var i = 0; i < keys.length; i++) {
            if (keys[i] === sourceScreenName) continue
            var controller = theme.barLayoutControllers[keys[i]]
            if (controller && controller.applyOrder) controller.applyOrder(serialized)
        }
    } finally {
        theme._barLayoutSyncing = false
    }
}

function resetAllBarLayouts(theme) {
    theme.applyToBarLayoutControllers("defaultLayout")
    theme.resetBarLayoutPresentation()
}

function resetBarLayoutPresentation(theme) {
    var separatorsChanged = theme.barSeps.length > 0
    var densityChanged = theme.iconOnlyGids.length > 0
    var widgetFillsChanged = theme.resetAllWidgetFillColors()
    var mprisChanged = theme.mprisBarStyle !== "default"

    if (separatorsChanged) theme.barSeps = []
    if (densityChanged) theme.iconOnlyGids = []

    // mprisBarStyle has its own persistence handler. If it was already at
    // the default, persist the other layout-only resets explicitly.
    if (mprisChanged) theme.mprisBarStyle = "default"
    else if ((separatorsChanged || densityChanged || widgetFillsChanged)
            && theme._widgetsLoaded) theme.saveWidgets()
}

function activatePopupScreen(theme, screen) {
    if (!screen || screen.name === "") return

    theme.activePopupScreen = screen
    theme.activePopupScreenName = screen.name
    theme.applyActiveBarAnchors()
}

function activateFocusedPopupScreen(theme) {
    var monitor = Hyprland.focusedMonitor
    var targetName = monitor ? monitor.name : ""

    for (var i = 0; i < Quickshell.screens.length; i++) {
        var candidate = Quickshell.screens[i]
        if (candidate.name === targetName
                && candidate.width > 0
                && candidate.height > 0) {
            theme.activatePopupScreen(candidate)
            return true
        }
    }

    if (theme.activePopupScreenName !== "") return true

    for (var j = 0; j < Quickshell.screens.length; j++) {
        var fallback = Quickshell.screens[j]
        if (fallback.name !== ""
                && fallback.width > 0
                && fallback.height > 0) {
            theme.activatePopupScreen(fallback)
            return true
        }
    }

    return false
}

function activatePopupScreenByName(theme, screenName) {
    if (screenName) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
            var candidate = Quickshell.screens[i]
            if (candidate.name === screenName
                    && candidate.width > 0
                    && candidate.height > 0) {
                theme.activatePopupScreen(candidate)
                return true
            }
        }
    }

    return theme.activateFocusedPopupScreen()
}

function isActivePopupScreenName(theme, screenName) {
    return theme.activePopupScreenName !== "" && screenName === theme.activePopupScreenName
}

function applyAnchor(theme, name, x) {
    if (name === "tray") theme.trayBarX = x
    else if (name === "trayCaret") theme.trayCaretBarX = x
    else if (name === "notif") theme.notifBarX = x
    else if (name === "notifCaret") theme.notifCaretBarX = x
    else if (name === "quickActions") theme.quickActionsBarX = x
    else if (name === "volume") theme.volumeBarX = x
    else if (name === "network") theme.networkBarX = x
    else if (name === "battery") theme.batteryBarX = x
    else if (name === "memory") theme.memoryBarX = x
    else if (name === "cpu") theme.cpuBarX = x
    else if (name === "gpu") theme.gpuBarX = x
    else if (name === "thermal") theme.thermalBarX = x
    else if (name === "storage") theme.storageBarX = x
    else if (name === "githubHeatmap") theme.githubHeatmapBarX = x
    else if (name === "ai") theme.aiBarX = x
    else if (name === "workspace") theme.workspaceBarX = x
    else if (name === "arch") theme.archBarX = x
    else if (name === "archCaret") theme.archCaretBarX = x
    else if (name === "bluetooth") theme.bluetoothBarX = x
    else if (name === "brightness") theme.brightnessBarX = x
    else if (name === "power") theme.powerBarX = x
    else if (name === "mpris") theme.mprisBarX = x
    else if (name === "weather") theme.weatherBarX = x
    else if (name === "calendar") theme.calendarBarX = x
    else if (name === "screentime") theme.screentimeBarX = x
    else if (name === "launcher") theme.launcherBarX = x
    else if (name === "trayMenu") theme.trayMenuX = x
}

function applyActiveBarAnchors(theme) {
    var anchors = theme.activePopupScreenName ? theme.barAnchorsByScreen[theme.activePopupScreenName] : null
    if (!anchors) return

    for (var name in anchors) theme.applyAnchor(name, anchors[name])
}

function publishBarAnchors(theme, screenName, anchors) {
    if (!screenName || !anchors) return

    var next = {}
    for (var screen in theme.barAnchorsByScreen) next[screen] = theme.barAnchorsByScreen[screen]
    next[screenName] = anchors
    theme.barAnchorsByScreen = next

    if (screenName === theme.activePopupScreenName) theme.applyActiveBarAnchors()
}

function setPanelAnchor(theme, name, x, screenName) {
    var targetScreen = screenName || theme.activePopupScreenName
    if (targetScreen) {
        var next = {}
        for (var screen in theme.barAnchorsByScreen) next[screen] = theme.barAnchorsByScreen[screen]

        var current = next[targetScreen] || {}
        var anchors = {}
        for (var key in current) anchors[key] = current[key]
        anchors[name] = x
        next[targetScreen] = anchors
        theme.barAnchorsByScreen = next
    }

    if (!targetScreen || targetScreen === theme.activePopupScreenName) theme.applyAnchor(name, x)
}

function closePopups(theme, except) {
    theme._closingPopups = true
    if (except !== "calendarVisible") theme.calendarVisible = false
    if (except !== "cpuVisible") theme.cpuVisible = false
    if (except !== "screentimeVisible") theme.screentimeVisible = false
    if (except !== "gpuVisible") theme.gpuVisible = false
    if (except !== "thermalVisible") theme.thermalVisible = false
    if (except !== "aiUsageVisible") theme.aiUsageVisible = false
    if (except !== "memVisible") theme.memVisible = false
    if (except !== "volVisible") theme.volVisible = false
    if (except !== "controlVisible") theme.controlVisible = false
    if (except !== "networkVisible") theme.networkVisible = false
    if (except !== "bluetoothVisible") theme.bluetoothVisible = false
    if (except !== "batteryVisible") theme.batteryVisible = false
    if (except !== "brightnessVisible") theme.brightnessVisible = false
    if (except !== "mprisVisible") theme.mprisVisible = false
    if (except !== "weatherVisible") theme.weatherVisible = false
    if (except !== "githubHeatmapVisible") theme.githubHeatmapVisible = false
    if (except !== "workspaceVisible") theme.workspaceVisible = false
    if (except !== "imagePickerVisible") theme.imagePickerVisible = false
    if (except !== "mediaBrowserVisible") theme.mediaBrowserVisible = false
    if (except !== "notifVisible") theme.notifVisible = false
    if (except !== "powerProfileVisible") theme.powerProfileVisible = false
    if (except !== "storageVisible") theme.storageVisible = false
    if (except !== "archVisible") theme.archVisible = false
    if (except !== "trayVisible") theme.trayVisible = false
    if (except !== "trayMenuVisible") theme.trayMenuVisible = false
    if (except !== "pluginsDrawerVisible") theme.pluginsDrawerVisible = false
    theme.hideTooltip()
    theme._closingPopups = false
}

function popupUsesConnectedInset(prop) {
    return prop !== "imagePickerVisible"
        && prop !== "mediaBrowserVisible"
        && prop !== "trayMenuVisible"
        && prop !== "pluginsDrawerVisible"
}

function popupOpened(theme, prop) {
    if (!theme._closingPopups && theme[prop]) {
        // The new panel surface publishes its clamped caret position on the
        // first reveal tick. Invalidate the previous panel's cached position
        // now so the bar cannot render one frame at that stale anchor.
        if (theme.popupUsesConnectedInset(prop)) theme.panelInsetReady = false
        theme.closePopups(prop)
    }
}

function applyTheme(theme, name) {
    if (!name) return
    var installRoot = theme.omarchyInstallRoot || (Quickshell.env("HOME") + "/.local/share/omarchy")
    Quickshell.execDetached(["bash", "-c", "OMARCHY_PATH='" + installRoot + "' omarchy-theme-set '" + name.replace(/'/g, "'\\''") + "'"])
}

function applyWallpaper(path) {
    if (!path) return
    Quickshell.execDetached(["bash", "-c", "omarchy-theme-bg-set '" + path.replace(/'/g, "'\\''") + "'"])
}

function openImagePicker(theme, mode, screen) {
    if (screen && screen.name !== "") theme.activatePopupScreen(screen)
    else theme.activateFocusedPopupScreen()
    theme.closePopups()
    theme.mediaBrowserVisible = false
    theme.imagePickerMode = mode || "theme"
    theme.dashboardDetail = mode || "theme"
    theme.dashboardExpanded = true
}

function toggleImagePicker(theme, mode, screen) {
    if (theme.dashboardExpanded && (theme.dashboardDetail === "theme" || theme.dashboardDetail === "wallpaper") && (theme.imagePickerMode === mode || theme.dashboardDetail === mode)) {
        theme.dashboardExpanded = false
        theme.dashboardDetail = ""
        return
    }

    theme.openImagePicker(mode, screen)
}

function openMediaBrowser(theme, mode) {
    theme.activateFocusedPopupScreen()
    theme.imagePickerVisible = false
    theme.mediaBrowserMode = mode
    theme.mediaBrowserVisible = true
}

function showTooltip(text, x, topY, bottomY, owner) {
    // Disabled per user request: remove hover tips for all icons
    return;
}

// hide only if the caller owns the current tooltip (owner match is stable
// even when the tooltip text changes, e.g. a live timer). A null/undefined
// owner force-hides. Legacy string args fall back to a text match.
function hideTooltip(theme, owner) {
    if (owner === undefined || owner === null) {
        theme.tooltipShown = false; theme.tooltipOwner = null;
    } else if (typeof owner === "object") {
        if (theme.tooltipOwner === owner) { theme.tooltipShown = false; theme.tooltipOwner = null; }
    } else if (theme.tooltipText === owner) {
        theme.tooltipShown = false; theme.tooltipOwner = null;
    }
}

function setPanelInsetX(theme, x) {
    if (!theme.anchoredPanelVisible) return

    if (isFinite(x) && x > 0) {
        theme.panelInsetX = x
        theme.panelInsetReady = true
    }
}

function trayDisplayName(item) {
    if (!item) return "Tray App"

    var title = String(item.title || "").trim()
    if (title !== "") return title

    var tooltipTitle = String(item.tooltipTitle || "").trim()
    if (tooltipTitle !== "") return tooltipTitle

    var fallback = String(item.id || "").trim()
    var slash = fallback.lastIndexOf("/")
    if (slash >= 0 && slash < fallback.length - 1)
        fallback = fallback.substring(slash + 1)
    fallback = fallback.replace(/^org\.(kde|ayatana|freedesktop)\./i, "")
                       .replace(/[_-]+/g, " ")
    return fallback !== "" ? fallback : "Tray App"
}

function trayDescription(item, displayName) {
    if (!item) return ""

    var description = String(item.tooltipDescription || "").trim()
    var tooltipTitle = String(item.tooltipTitle || "").trim()
    var name = String(displayName || "").trim().toLowerCase()
    if (description !== "" && description.toLowerCase() !== name)
        return description
    if (tooltipTitle !== "" && tooltipTitle.toLowerCase() !== name)
        return tooltipTitle
    return ""
}

function openTrayMenu(theme, handle, x, title, icon) {
    if (!handle) return
    theme.trayMenuHandle = handle
    theme.trayMenuTitle = String(title || "App Menu")
    theme.trayMenuIcon = String(icon || "")
    theme.setPanelAnchor("trayMenu", x)
    theme.trayMenuVisible = true
}

function trayIsHidden(theme, item) {
    return theme.trayPinned.indexOf(item.id) < 0
}

// toggle: hidden items get pinned (shown in bar); pinned items get unpinned (back to panel)
function trayToggleHide(theme, item) {
    var key = item.id
    if (!key) return
    var i = theme.trayPinned.indexOf(key)
    if (i >= 0) {
        var a = theme.trayPinned.slice(0, i)
        var b = theme.trayPinned.slice(i + 1)
        theme.trayPinned = a.concat(b)
        theme.trayVisible = false
    } else {
        theme.trayPinned = theme.trayPinned.concat([key])
    }
}

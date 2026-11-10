// Widget/workspace state persistence, per-widget palette styles, and launcher
// logo helpers for Theme.qml.

function sepAfter(theme, gid) { return theme.barSeps.indexOf(gid) >= 0 }
function iconOnly(theme, gid) { return theme.iconOnlyGids.indexOf(gid) >= 0 }

function toggleSep(theme, gid) {
    var a = theme.barSeps.slice()
    var i = a.indexOf(gid)
    if (i >= 0) a.splice(i, 1); else a.push(gid)
    theme.barSeps = a
    if (theme._widgetsLoaded) theme.saveWidgets()
}

function toggleIconOnly(theme, gid) {
    if (gid === "G3") return // Status is an icon-only group by design.
    var a = theme.iconOnlyGids.slice()
    var i = a.indexOf(gid)
    if (i >= 0) a.splice(i, 1); else a.push(gid)
    theme.iconOnlyGids = a
    if (theme._widgetsLoaded) theme.saveWidgets()
}

function parseGidCsv(s) {
    if (!s || s === "-") return []
    var out = []
    var toks = s.split(",")
    for (var i = 0; i < toks.length; i++)
        if (/^G\d{1,2}$/.test(toks[i]) && toks[i] !== "G3") out.push(toks[i])
    return out
}

function widgetGidValid(gid) {
    var m = String(gid || "").match(/^G(\d{1,2})$/)
    if (!m) return false
    var n = Number(m[1])
    return n >= 1 && n <= 18
}

function widgetColorModeValid(mode) {
    return mode === "fill" || mode === "border" || mode === "both"
}

function normalizedWidgetColorMode(mode, colorId) {
    var borderOn = mode === "both" || mode === "border"
    if (!borderOn) return "fill"
    return colorId === "inherit" ? "border" : "both"
}

function widgetToneValid(tone) {
    return tone === "auto" || tone === "background" || tone === "foreground"
}

function widgetColorStyle(theme, gid) {
    var raw = theme.widgetColorStyles[gid]
    var colorId = raw && (raw.color === "inherit" || theme.paletteColorValid(raw.color))
        ? raw.color
        : "inherit"
    return {
        color: colorId,
        mode: raw && theme.widgetColorModeValid(raw.mode)
            ? theme.normalizedWidgetColorMode(raw.mode, colorId)
            : "fill",
        tone: raw && theme.widgetToneValid(raw.tone) ? raw.tone : "auto"
    }
}

function setWidgetColorStyle(theme, gid, colorId, mode, tone) {
    if (!theme.widgetGidValid(gid)) return
    var next = {}
    for (var key in theme.widgetColorStyles) next[key] = theme.widgetColorStyles[key]

    var storedColor = colorId === "inherit"
        ? "inherit"
        : (theme.paletteColorValid(colorId) ? colorId : "color01")
    var storedMode = theme.normalizedWidgetColorMode(mode, storedColor)
    if (storedColor === "inherit" && storedMode !== "border") {
        delete next[gid]
    } else {
        next[gid] = {
            color: storedColor,
            mode: storedMode,
            tone: theme.widgetToneValid(tone) ? tone : "auto"
        }
    }
    theme.widgetColorStyles = next
    if (theme._widgetsLoaded) theme.saveWidgets()
}

function setWidgetPaletteColor(theme, gid, colorId) {
    var style = theme.widgetColorStyle(gid)
    theme.setWidgetColorStyle(gid, colorId, style.mode, style.tone)
}

function setWidgetColorMode(theme, gid, mode) {
    var style = theme.widgetColorStyle(gid)
    theme.setWidgetColorStyle(gid, style.color, mode, style.tone)
}

function setWidgetBorderEnabled(theme, gid, enabled) {
    var style = theme.widgetColorStyle(gid)
    theme.setWidgetColorStyle(gid, style.color,
        enabled ? (style.color === "inherit" ? "border" : "both") : "fill",
        style.tone)
}

function setWidgetTone(theme, gid, tone) {
    var style = theme.widgetColorStyle(gid)
    if (style.color !== "inherit") theme.setWidgetColorStyle(gid, style.color, style.mode, tone)
}

function resetWidgetColor(theme, gid) {
    var style = theme.widgetColorStyle(gid)
    theme.setWidgetColorStyle(gid, "inherit",
        style.mode === "both" || style.mode === "border" ? "border" : "fill",
        "auto")
}

function resetAllWidgetFillColors(theme) {
    var next = {}
    var changed = false

    for (var n = 1; n <= 18; n++) {
        var gid = "G" + n
        var style = theme.widgetColorStyle(gid)

        if (style.color !== "inherit") changed = true
        if (style.mode === "border" || style.mode === "both") {
            next[gid] = {
                color: "inherit",
                mode: "border",
                tone: "auto"
            }
        }
    }

    if (changed) theme.widgetColorStyles = next
    return changed
}

function widgetPaletteId(theme, gid) { return theme.widgetColorStyle(gid).color }
function widgetColorMode(theme, gid) { return theme.widgetColorStyle(gid).mode }
function widgetTone(theme, gid) { return theme.widgetColorStyle(gid).tone }

function widgetHasFill(theme, gid) {
    if (gid === "G9" && theme.mprisDominantColor.a > 0.01 && theme.mprisDominantColor != "#00000000" && theme.mprisDominantColor != "transparent") {
        return true
    }
    var style = theme.widgetColorStyle(gid)
    return style.color !== "inherit"
}

function widgetHasBorder(theme, gid) {
    var style = theme.widgetColorStyle(gid)
    return style.mode === "border" || style.mode === "both"
}

function widgetAssignedColor(theme, gid) {
    if (gid === "G9" && theme.mprisDominantColor.a > 0.01 && theme.mprisDominantColor != "#00000000" && theme.mprisDominantColor != "transparent") {
        return theme.mprisDominantColor
    }
    var id = theme.widgetPaletteId(gid)
    return id === "inherit" ? theme.seal : theme.paletteColor(id)
}

function _linearColorChannel(v) {
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
}

function _relativeLuminance(theme, c) {
    return 0.2126 * theme._linearColorChannel(c.r)
         + 0.7152 * theme._linearColorChannel(c.g)
         + 0.0722 * theme._linearColorChannel(c.b)
}

function _contrastRatio(theme, a, b) {
    var la = theme._relativeLuminance(a)
    var lb = theme._relativeLuminance(b)
    return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

function paletteContrastColor(theme, id) {
    var fill = theme.paletteColor(id)
    return theme._contrastRatio(fill, theme.paper) >= theme._contrastRatio(fill, theme.ink) ? theme.paper : theme.ink
}

function widgetContrastColor(theme, gid) {
    if (gid === "G9" && theme.mprisDominantColor.a > 0.01 && theme.mprisDominantColor != "#00000000" && theme.mprisDominantColor != "transparent") {
        return theme.ink
    }
    var fill = theme.widgetAssignedColor(gid)
    var tone = theme.widgetTone(gid)
    if (tone === "background") return theme.paper
    if (tone === "foreground") return theme.ink
    return theme._contrastRatio(fill, theme.paper) >= theme._contrastRatio(fill, theme.ink) ? theme.paper : theme.ink
}

function widgetContentColor(theme, gid, fallback) {
    return theme.widgetHasFill(gid) ? theme.widgetContrastColor(gid) : fallback
}

function widgetFillColor(theme, gid) {
    if (gid === "G9" && theme.mprisDominantColor.a > 0.01 && theme.mprisDominantColor != "#00000000" && theme.mprisDominantColor != "transparent") {
        var c = theme.mprisDominantColor
        return Qt.rgba(c.r, c.g, c.b, 0.25)
    }
    return theme.widgetHasFill(gid) ? theme.widgetAssignedColor(gid) : Qt.rgba(0, 0, 0, 0)
}

function widgetBorderColor(theme, gid) {
    if (!theme.widgetHasBorder(gid)) return Qt.rgba(0, 0, 0, 0)
    return theme.panelBorder
}

function serializeWidgetColorStyles(theme) {
    var out = []
    for (var n = 1; n <= 18; n++) {
        var gid = "G" + n
        var style = theme.widgetColorStyle(gid)
        if (style.color !== "inherit" || style.mode === "border")
            out.push(gid + "~" + style.color + "~" + style.mode + "~" + style.tone)
    }
    return out.length ? out.join(",") : "-"
}

function parseWidgetColorStyles(theme, raw) {
    var out = {}
    if (!raw || raw === "-") return out
    var entries = String(raw).split(",")
    for (var i = 0; i < entries.length; i++) {
        var fields = entries[i].split("~")
        if (fields.length !== 4 || !theme.widgetGidValid(fields[0])
                || (fields[1] !== "inherit" && !theme.paletteColorValid(fields[1]))
                || !theme.widgetColorModeValid(fields[2])
                || !theme.widgetToneValid(fields[3])) continue
        out[fields[0]] = {
            color: fields[1],
            mode: theme.normalizedWidgetColorMode(fields[2], fields[1]),
            tone: fields[3]
        }
    }
    return out
}

function buildSaveWidgetsLine(theme) {
    return (theme.modMemory    ? "1" : "0") + " "
         + (theme.modBrightness ? "1" : "0") + " "
         + (theme.modClaude    ? "1" : "0") + " "
         + (theme.modPower     ? "1" : "0") + " "
         + (theme.modBluetooth ? "1" : "0") + " "
         + theme.workspaceMode + " "
         + theme.pickerStyle + " "
         + (theme.weatherImperial ? "1" : "0") + " "
         + (theme.clock12h        ? "1" : "0") + " "
         + (theme.modNetwork      ? "1" : "0") + " "
         + "0 "                                     // +5 legacy shadow field (V2 disabled)
         + "0 0 "                                     // +6..+7 retired V2 Style fields
         + theme.workspaceStyle + " "
         + theme.barPosition + " "
         + "1 "                                     // +10 legacy border field (V2 always on)
         + (theme.modStatus ? "1" : "0") + " "          // +11 group pill: status (arch/tray/notif)
         + (theme.modQuick  ? "1" : "0") + " "          // +12 group pill: quick (idle/media/theme)
         + (theme.modCpu    ? "1" : "0") + " "          // +13
         + (theme.modVolume ? "1" : "0") + " "          // +14
         + (theme.modMpris  ? "1" : "0") + " "          // +15 now-playing / mpris
         + theme.aiTool + " "                           // +16 AI tool shown in bar (claude/codex/opencode)
         + "0 "                                     // +17 retired transparent/frost field
         + theme.launcherLogoMode + " "                 // +18 launcher logo mode (text/icon)
         + theme.launcherLogoText + " "                 // +19 text logo id
         + theme.launcherLogoIcon + " "                 // +20 icon logo id
         + (theme.archBadgePackages ? "1" : "0") + " "  // +21 updater package badge
         + (theme.archBadgeThemes   ? "1" : "0") + " "  // +22 updater clean-theme badge
         + "1 1 1 1 1 1 1 1 "                       // +23..+30 legacy compact fields; V2 is always compact
         + (theme.archBadgeShell    ? "1" : "0") + " "  // +31 updater shell badge
         + theme.barColor + " "                            // +32 V2 bar accent source
         + (theme.modGpu            ? "1" : "0") + " "  // +33 GPU load
         + (theme.modCpuTemperature ? "1" : "0") + " "  // +34 CPU temperature
         + (theme.modStorage        ? "1" : "0") + " "  // +35 root-filesystem usage
         + (theme.barSeps.length ? theme.barSeps.join(",") : "-") + " "         // +36 separator gids (CSV, "-" = none)
         + (theme.iconOnlyGids.length ? theme.iconOnlyGids.join(",") : "-") + " " // +37 icon-only gids (CSV, "-" = none)
         + theme.barTemperatureSource + " "                            // +38 temperature sensor shown in bar
         + "0 "                                                  // +39 retired global widget-foreground switch
         + theme.serializeWidgetColorStyles() + " "                   // +40 per-GID palette styles
         + theme.mprisBarStyle + " "                                  // +41 now-playing bar presentation
         + theme.barShellStyle + " "                                  // +42 outer bar shell
         + (theme.barBorderEnabled ? "1" : "0") + " "                 // +43 outer bar border
         + (theme.panelTooltipBorderEnabled ? "1" : "0") + " "        // +44 panel + tooltip outer border
         + (theme.v2AutoHide ? "1" : "0") + " "                       // +45 v2 auto-hide
         + (theme.desktopMenuListMode ? "1" : "0") + " "              // +46 desktop context menu list mode
         + theme.sliderStyle + " "                                   // +47 slider presentation style
         + theme.tileShape1x1 + " "                                  // +48 1x1 tile shape
         + theme.tileShape1x2 + " "                                  // +49 1x2 tile shape
         + theme.tileShape2x2                                        // +50 2x2 tile shape
}

function parseLoadedWidgets(theme, rawText) {
    var parts = String(rawText || "").trim().split(" ")
    if (parts.length >= 4) {
        theme.modMemory    = false
        theme.modBrightness = parts[1] !== "0"
        theme.modClaude    = parts[2] !== "0"
        theme.modPower     = parts[3] !== "0"
    }
    // parts[4] is the bluetooth flag in the new format, but in the OLD
    // format it was the workspace mode ("10"/"5"/"active") — detect which.
    var wsField = -1
    if (parts.length >= 5) {
        if (parts[4] === "5" || parts[4] === "active" || parts[4] === "10") {
            wsField = 4                         // old format: no bluetooth field
        } else {
            theme.modBluetooth = false
            wsField = 5
        }
    }
    if (wsField >= 0 && parts.length > wsField) {
        var m = parts[wsField]
        theme.workspaceMode = (m === "5" || m === "active") ? m : "10"
        // pickerStyle is the field right after the workspace mode
        if (parts.length > wsField + 1) {
            var ps = parts[wsField + 1]
            if (ps === "hearthstone" || ps === "carousel" || ps === "tanzaku" || ps === "gravemind")
                theme.pickerStyle = ps
        }
        // weatherImperial / clock12h follow pickerStyle
        if (parts.length > wsField + 2) theme.weatherImperial = parts[wsField + 2] === "1"
        if (parts.length > wsField + 3) theme.clock12h        = parts[wsField + 3] === "1"
        if (parts.length > wsField + 4) theme.modNetwork      = false
        // style tokens — appended after modNetwork, each guarded
        // +5 is the retired V2 shadow field and is intentionally ignored.
        // +6..+7 are retired V2 Style fields, retained only so older
        // cache layouts keep stable offsets.
        if (parts.length > wsField + 8) {
            var wss = parts[wsField + 8]
            if (wss === "numbers" || wss === "magic" || wss === "kanji"
                    || wss === "rings" || wss === "aurora" || wss === "default")
                theme.workspaceStyle = wss
        }
        if (parts.length > wsField + 9) {
            var bp = parts[wsField + 9]
            if (bp === "top" || bp === "bottom") theme.barPosition = bp
        }
        // +10 is the retired V2 border toggle; structural borders stay on.
        // +11..+15 widget-group toggles (default ON → only an explicit "0"
        // hides; old caches lack these fields → groups stay visible)
        if (parts.length > wsField + 11) theme.modStatus = parts[wsField + 11] !== "0"
        if (parts.length > wsField + 12) theme.modQuick  = parts[wsField + 12] !== "0"
        if (parts.length > wsField + 13) theme.modCpu    = parts[wsField + 13] !== "0"
        if (parts.length > wsField + 14) theme.modVolume = parts[wsField + 14] !== "0"
        if (parts.length > wsField + 15) theme.modMpris  = parts[wsField + 15] !== "0"
        if (parts.length > wsField + 16) {
            var at = parts[wsField + 16]
            if (at === "claude" || at === "codex" || at === "opencode" || at === "agy") theme.aiTool = at
        }
        // +17 is the retired transparent/frost field.
        if (parts.length > wsField + 18) {
            var lm = parts[wsField + 18]
            if (lm === "text" || lm === "icon") {
                theme.launcherLogoMode = lm
                if (parts.length > wsField + 19 && theme.launcherLogoTextValid(parts[wsField + 19]))
                    theme.launcherLogoText = parts[wsField + 19]
                if (parts.length > wsField + 20 && theme.launcherLogoIconValid(parts[wsField + 20]))
                    theme.launcherLogoIcon = parts[wsField + 20]
            } else if (lm === "omarchy" || lm === "hyprland") {
                // Legacy cache field from the first text-logo picker.
                theme.launcherLogoMode = "text"
                theme.launcherLogoText = lm
            }
        }
        if (parts.length > wsField + 21) theme.archBadgePackages = parts[wsField + 21] !== "0"
        if (parts.length > wsField + 22) theme.archBadgeThemes   = parts[wsField + 22] !== "0"
        // +23..+30 are retained only as cache-schema placeholders.
        // V2 has one compact presentation and deliberately ignores them.
        if (parts.length > wsField + 31) theme.archBadgeShell    = parts[wsField + 31] !== "0"
        if (parts.length > wsField + 32 && theme.barColorValid(parts[wsField + 32]))
            theme.barColor = theme.normalizedPaletteId(parts[wsField + 32])
        if (parts.length > wsField + 33) theme.modGpu = parts[wsField + 33] !== "0"
        if (parts.length > wsField + 34) theme.modCpuTemperature = parts[wsField + 34] !== "0"
        if (parts.length > wsField + 35) theme.modStorage = parts[wsField + 35] !== "0"
        if (parts.length > wsField + 36) theme.barSeps      = theme.parseGidCsv(parts[wsField + 36])
        if (parts.length > wsField + 37) theme.iconOnlyGids = theme.parseGidCsv(parts[wsField + 37])
        if (parts.length > wsField + 38 && theme.barTemperatureSourceValid(parts[wsField + 38]))
            theme.barTemperatureSource = parts[wsField + 38]
        // +39 was the retired global foreground override. Bar Color
        // now includes Foreground and per-widget styles provide local overrides.
        theme.widgetIconsForeground = false
        if (parts.length > wsField + 40)
            theme.widgetColorStyles = theme.parseWidgetColorStyles(parts[wsField + 40])
        if (parts.length > wsField + 41) {
            var mbs = parts[wsField + 41]
            if (mbs === "default" || mbs === "full" || mbs === "island") theme.mprisBarStyle = mbs
        }
        if (parts.length > wsField + 42) {
            var bss = parts[wsField + 42]
            if (theme.barShellStyleValid(bss)) theme.barShellStyle = bss
        }
        if (parts.length > wsField + 43)
            theme.barBorderEnabled = parts[wsField + 43] !== "0"
        if (parts.length > wsField + 44)
            theme.panelTooltipBorderEnabled = parts[wsField + 44] !== "0"
        if (parts.length > wsField + 46)
            theme.desktopMenuListMode = parts[wsField + 46] !== "0"
        if (parts.length > wsField + 47) {
            var ss = parts[wsField + 47]
            if (theme.sliderStyleValid(ss)) theme.sliderStyle = ss
        }
        if (parts.length > wsField + 48) {
            var s1 = parts[wsField + 48]
            if (theme.tileShape1x1Valid(s1)) theme.tileShape1x1 = s1
        }
        if (parts.length > wsField + 49) {
            var s2 = parts[wsField + 49]
            if (theme.tileShape1x2Valid(s2)) theme.tileShape1x2 = s2
        }
        if (parts.length > wsField + 50) {
            var s4 = parts[wsField + 50]
            if (theme.tileShape2x2Valid(s4)) theme.tileShape2x2 = s4
        }
    }
    theme._widgetsLoaded = true
}

function launcherLogoTextIndex(theme, id) {
    for (var i = 0; i < theme.launcherLogoTextOptions.length; i++)
        if (theme.launcherLogoTextOptions[i] === id) return i
    return 0
}

function launcherLogoIconIndex(theme, id) {
    for (var i = 0; i < theme.launcherLogoIconOptions.length; i++)
        if (theme.launcherLogoIconOptions[i] === id) return i
    return 0
}

function launcherLogoTextValid(theme, id) {
    return theme.launcherLogoTextIndex(id) >= 0 && theme.launcherLogoTextOptions[theme.launcherLogoTextIndex(id)] === id
}

function launcherLogoIconValid(theme, id) {
    return theme.launcherLogoIconIndex(id) >= 0 && theme.launcherLogoIconOptions[theme.launcherLogoIconIndex(id)] === id
}

function nextLauncherLogoText(theme) {
    theme.launcherLogoText = theme.launcherLogoTextOptions[(theme.launcherLogoTextIndex(theme.launcherLogoText) + 1) % theme.launcherLogoTextOptions.length]
}

function nextLauncherLogoIcon(theme) {
    theme.launcherLogoIcon = theme.launcherLogoIconOptions[(theme.launcherLogoIconIndex(theme.launcherLogoIcon) + 1) % theme.launcherLogoIconOptions.length]
}

function launcherConfigValue(config, a, b, c) {
    if (!config) return undefined
    if (config[a] !== undefined) return config[a]
    if (b && config[b] !== undefined) return config[b]
    if (c && config[c] !== undefined) return config[c]
    return undefined
}

function applyLauncherConfig(theme, config) {
    if (!config) return

    var launcher = config.launcher || config.logo || config
    var mode = theme.launcherConfigValue(launcher, "launcherLogoMode", "logoMode", "mode")
    var text = theme.launcherConfigValue(launcher, "launcherLogoText", "textLogo", "text")
    var icon = theme.launcherConfigValue(launcher, "launcherLogoIcon", "iconLogo", "icon")

    if (mode === "text" || mode === "icon") theme.launcherLogoMode = mode
    if (text !== undefined && theme.launcherLogoTextValid(text)) theme.launcherLogoText = text
    if (icon !== undefined && theme.launcherLogoIconValid(icon)) theme.launcherLogoIcon = icon
}

function launcherLogoLabel(id) {
    if (id === "omarchy") return "Omarchy"
    if (id === "hyprland") return "Hyprland"
    if (id === "arch") return "Arch"
    if (id === "omacom") return "Omacom"
    if (id === "grid") return "Grid"
    if (id === "spark") return "Spark"
    if (id === "power") return "Power"
    if (id === "dragon") return "Dragon"
    if (id === "mark") return "Mark"
    if (id === "nix") return "Nix"
    if (id === "branch") return "Branch"
    if (id === "rebel") return "Rebel"
    return "Omarchy"
}

function launcherLogoIconGlyph(id) {
    if (id === "omarchy") return String.fromCodePoint(0xE900)
    if (id === "hyprland") return ""
    if (id === "arch") return ""
    if (id === "grid") return ""
    if (id === "spark") return ""
    if (id === "power") return ""
    if (id === "dragon") return "⻯"
    if (id === "mark") return ""
    if (id === "nix") return ""
    if (id === "branch") return ""
    if (id === "rebel") return ""
    return String.fromCodePoint(0xE900)
}

function launcherLogoIconFont(theme, id) {
    return id === "omarchy" ? "omarchy" : theme.mono
}

function launcherLogoIconSize(id) {
    if (id === "omarchy") return 15
    if (id === "arch") return 17
    if (id === "dragon") return 16
    return 16
}

function launcherLogoIconXOffset(id) {
    if (id === "omarchy") return 0.5
    if (id === "hyprland") return 0
    if (id === "arch") return 1
    if (id === "grid") return -1
    if (id === "spark") return 0
    if (id === "power") return 0
    if (id === "dragon") return 0
    if (id === "mark") return 0.5
    if (id === "nix") return 0
    if (id === "branch") return 0
    return 0
}

function launcherLogoIconYOffset(id) {
    if (id === "omarchy") return 0
    if (id === "hyprland") return 0
    if (id === "arch") return 0
    if (id === "mark") return 0.5
    if (id === "branch") return 0
    if (id === "dragon") return 0
    return 0
}

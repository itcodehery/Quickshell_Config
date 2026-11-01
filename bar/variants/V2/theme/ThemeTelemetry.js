// Calendar, AI Usage, and Central System Telemetry parsing & formatting helpers
// for Theme.qml.

function computeCalendarCells(theme) {
    theme.calendarTick;
    const now = new Date();
    const first = new Date(now.getFullYear(), now.getMonth() + theme.calendarMonthOffset, 1);
    const year = first.getFullYear();
    const month = first.getMonth();
    const lastDay = new Date(year, month + 1, 0).getDate();
    const startDay = (first.getDay() + 6) % 7;
    const today = new Date();
    const isCurrentMonth = year === today.getFullYear() && month === today.getMonth();
    const cells = [];
    for (let i = 0; i < startDay; i++) cells.push({day: 0, today: false});
    for (let d = 1; d <= lastDay; d++) {
        cells.push({day: d, today: isCurrentMonth && d === today.getDate()});
    }
    while (cells.length < 42) cells.push({day: 0, today: false});
    return cells;
}

function computeCalendarMonthName(theme) {
    const months = ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                    "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"];
    const now = new Date();
    return months[(now.getMonth() + theme.calendarMonthOffset + 12000) % 12];
}

function computeCalendarYear(theme) {
    const now = new Date();
    const d = new Date(now.getFullYear(), now.getMonth() + theme.calendarMonthOffset, 1);
    return String(d.getFullYear());
}

function openCalendar(theme) {
    theme.calendarMonthOffset = 0;
    theme.calendarTick++;
    theme.selectedDay = (new Date()).getDate();
    theme.calendarVisible = true;
}

// F15: clamp an external 0..1 utilization to a 0–100 int (a negative/over-range value would
// otherwise produce wrong text and negative/overwide usage bars)
function aiPct(v) {
    return Math.max(0, Math.min(100, Math.round((parseFloat(v) || 0) * 100)))
}

function aiWindowLabel(minutes) {
    if (minutes === 300) return "5h"
    if (minutes === 10080) return "Weekly"
    if (minutes > 0 && minutes % 1440 === 0) return (minutes / 1440) + "d"
    if (minutes > 0 && minutes % 60 === 0) return (minutes / 60) + "h"
    return minutes > 0 ? minutes + "m" : "window"
}

function aiResetCodexUsage(theme) {
    theme.aiCxHas = false; theme.aiCxFresh = false
    theme.aiCxPct5h = 0; theme.aiCxPct7d = 0
    theme.aiCxPlan = ""; theme.aiCxTokens = ""; theme.aiCxRate = ""; theme.aiCxToday = 0
    theme.aiCxReset5hTs = 0; theme.aiCxReset7dTs = 0
    theme.aiCxBuckets = []; theme.aiCxWindows = []
    theme.aiCxPrimaryPct = 0; theme.aiCxPrimaryLabel = ""; theme.aiCxPrimaryResetTs = 0
    theme.aiCxQuotaPct = 0; theme.aiCxQuotaLabel = ""
    theme.aiCxLimitStatus = ""; theme.aiCxLimitReachedType = ""
}

function aiCodexWindowFromCache(theme, w) {
    w = w || {}
    var minutes = parseInt(w.minutes) || 0
    return {
        kind: String(w.kind || ""),
        minutes: minutes,
        label: String(w.label || theme.aiWindowLabel(minutes)),
        pct: theme.aiPct(w.utilization),
        resetTs: parseInt(w.reset) || 0
    }
}

function aiCodexWindowsFromArray(theme, arr) {
    var out = []
    if (!arr || arr.length === undefined) return out
    for (var i = 0; i < arr.length; i++) {
        out.push(theme.aiCodexWindowFromCache(arr[i]))
    }
    return out
}

function aiCodexLegacyWindowsFromCache(theme, d) {
    var out = []
    if (!d) return out
    var has5 = d["5h-utilization"] !== undefined && String(d["5h-utilization"]) !== ""
    var has7 = d["7d-utilization"] !== undefined && String(d["7d-utilization"]) !== ""
    if (has5 || parseInt(d["5h-reset"]) > 0)
        out.push({ kind: "primary", minutes: 300, label: "5h", pct: theme.aiPct(d["5h-utilization"]), resetTs: parseInt(d["5h-reset"]) || 0 })
    if (has7 || parseInt(d["7d-reset"]) > 0)
        out.push({ kind: "secondary", minutes: 10080, label: "Weekly", pct: theme.aiPct(d["7d-utilization"]), resetTs: parseInt(d["7d-reset"]) || 0 })
    return out
}

function aiCodexBucketsFromCache(theme, d) {
    var buckets = []
    if (d && parseInt(d.schemaVersion) === 3 && d.buckets && d.buckets.length !== undefined) {
        for (var i = 0; i < d.buckets.length; i++) {
            var b = d.buckets[i] || {}
            var windows = theme.aiCodexWindowsFromArray(b.windows)
            if (windows.length === 0) continue
            buckets.push({
                id: String(b.id || ""),
                label: String(b.label || b.id || "Codex"),
                isGeneral: b.isGeneral === true,
                windows: windows,
                plan: String(b.plan || ""),
                rateLimitReachedType: String(b.rateLimitReachedType || "")
            })
        }
    } else if (d && parseInt(d.schemaVersion) === 2 && d.windows && d.windows.length !== undefined) {
        var win2 = theme.aiCodexWindowsFromArray(d.windows)
        if (win2.length > 0)
            buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: win2, plan: String(d._plan || "") })
    } else {
        var legacy = theme.aiCodexLegacyWindowsFromCache(d)
        if (legacy.length > 0)
            buckets.push({ id: "codex", label: "Codex", isGeneral: true, windows: legacy, plan: String((d && d._plan) || "") })
    }
    return buckets
}

function aiCodexGeneralBucket(buckets) {
    for (var i = 0; i < buckets.length; i++) {
        if (buckets[i].isGeneral === true || buckets[i].id === "codex") return buckets[i]
    }
    return { windows: [] }
}

function aiPlanLabel(plan) {
    var p = String(plan || "").toLowerCase()
    if (p === "prolite") return "Pro Lite"
    if (p === "pro") return "Pro"
    if (p === "plus") return "Plus"
    if (p === "team" || p === "business") return "Business"
    if (p === "enterprise") return "Enterprise"
    if (p === "edu") return "Edu"
    if (p === "free") return "Free"
    return String(plan || "")
}

function aiApplyCodexCache(theme, d, ageOk) {
    var buckets = theme.aiCodexBucketsFromCache(d)
    var general = theme.aiCodexGeneralBucket(buckets)
    var windows = general.windows || []
    theme.aiCxHas = windows.length > 0
    theme.aiCxFresh = ageOk && d._source !== "stale"
    theme.aiCxBuckets = buckets
    theme.aiCxWindows = windows
    theme.aiCxPlan = theme.aiPlanLabel(d._plan || general.plan || "")
    theme.aiCxPct5h = 0; theme.aiCxPct7d = 0
    theme.aiCxReset5hTs = 0; theme.aiCxReset7dTs = 0
    theme.aiCxQuotaPct = 0
    theme.aiCxQuotaLabel = ""
    theme.aiCxLimitStatus = String(d.status || "")
    theme.aiCxLimitReachedType = String(d._limit_reached_type || general.rateLimitReachedType || "")
    for (var i = 0; i < windows.length; i++) {
        var w = windows[i]
        if (i === 0) {
            theme.aiCxPrimaryPct = w.pct
            theme.aiCxPrimaryLabel = w.label
            theme.aiCxPrimaryResetTs = w.resetTs
        }
        if (w.minutes === 300) { theme.aiCxPct5h = w.pct; theme.aiCxReset5hTs = w.resetTs }
        else if (w.minutes === 10080) { theme.aiCxPct7d = w.pct; theme.aiCxReset7dTs = w.resetTs }
        if (w.pct > theme.aiCxQuotaPct) {
            theme.aiCxQuotaPct = w.pct
            theme.aiCxQuotaLabel = String(general.label || "Codex") + " " + String(w.label || "window")
        }
    }
    if (windows.length === 0) {
        theme.aiCxPrimaryPct = 0
        theme.aiCxPrimaryLabel = ""
        theme.aiCxPrimaryResetTs = 0
    }
    var cxRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
    theme.aiCxRate = cxRateH > 0 ? cxRateH + "k tok/h" : ""
    theme.aiCxToday = parseInt(d._today_tokens) || 0
    theme.aiCxTokens = ""
}

function aiCodexStatusLabel(status, reachedType) {
    if (status === "rejected")
        return reachedType ? "reached (" + reachedType + ")" : "reached"
    if (status === "allowed_warning") return "warning"
    if (status === "allowed") return "ok (not reached)"
    return "unknown"
}

function aiFmtReset(theme, ts) {
    theme.aiClockTick
    var now = Date.now() / 1000
    if (!(ts > now)) return ""
    var mins = Math.round((ts - now) / 60)
    if (mins < 60) return mins + "m"
    var h = Math.floor(mins / 60), m = mins % 60
    if (h < 24) return h + "h " + m + "m"
    var d = Math.floor(h / 24); return d + "d " + (h % 24) + "h"
}

function aiPad2(n) { return n < 10 ? "0" + n : "" + n }

function aiFmtResetClock(theme, ts) {
    theme.aiClockTick
    if (!(ts > Date.now() / 1000)) return ""
    var d = new Date(ts * 1000)
    var now = new Date()
    var day0 = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    var resetDay0 = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()
    var dayDelta = Math.round((resetDay0 - day0) / 86400000)
    var time = theme.aiPad2(d.getHours()) + ":" + theme.aiPad2(d.getMinutes())
    if (dayDelta <= 0) return time
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    return days[d.getDay()] + " " + time
}

function aiFmtResetDetail(theme, ts) {
    var rel = theme.aiFmtReset(ts)
    var clock = theme.aiFmtResetClock(ts)
    return rel && clock ? rel + " • " + clock : (rel || clock)
}

function barTemperatureSourceValid(source) {
    return source === "cpu" || source === "core" || source === "gpu"
        || source === "nvme" || source === "memory"
}

function barTemperatureSourceLabel(source) {
    if (source === "core") return "Hottest CPU core"
    if (source === "gpu") return "GPU"
    if (source === "nvme") return "NVMe"
    if (source === "memory") return "Memory"
    return "CPU package"
}

function barTemperatureSourceAvailable(theme, source) {
    if (source === "core") return theme.cpuCoreMaxTemperatureC > 0
    if (source === "gpu") return theme.gpuTemperatureC > 0
    if (source === "nvme") return theme.nvmeTemperatureC > 0
    if (source === "memory") return theme.memoryTemperatureC > 0
    return theme.cpuTemperatureC > 0
}

function parseSystemCpu(theme, text) {
    var lines = String(text || "").split("\n")
    if (lines.length === 0 || lines[0].indexOf("cpu ") !== 0) return
    var parts = lines[0].trim().split(/\s+/)
    if (parts.length < 8) return

    function field(index) {
        var value = parseFloat(parts[index])
        return isNaN(value) ? 0 : value
    }
    var user = field(1) + field(2)
    var system = field(3) + field(6) + field(7) + field(8)
    var ioWait = field(5)
    var idle = field(4) + ioWait
    var total = 0
    for (var i = 1; i < parts.length; i++) {
        var v = parseFloat(parts[i])
        if (!isNaN(v)) total += v
    }
    if (isNaN(idle) || isNaN(total) || total <= 0) return

    if (theme._systemCpuPrevTotal >= 0 && total > theme._systemCpuPrevTotal) {
        var totalDelta = total - theme._systemCpuPrevTotal
        var idleDelta = idle - theme._systemCpuPrevIdle
        var busy = totalDelta > 0 ? Math.round((totalDelta - idleDelta) / totalDelta * 100) : 0
        theme.systemCpuPercent = Math.max(0, Math.min(100, busy))
        theme.systemCpuUserPercent = Math.max(0, Math.min(100,
            Math.round((user - theme._systemCpuPrevUser) / totalDelta * 100)))
        theme.systemCpuSystemPercent = Math.max(0, Math.min(100,
            Math.round((system - theme._systemCpuPrevSystem) / totalDelta * 100)))
        theme.systemCpuIoWaitPercent = Math.max(0, Math.min(100,
            Math.round((ioWait - theme._systemCpuPrevIoWait) / totalDelta * 100)))
    }

    theme._systemCpuPrevIdle = idle
    theme._systemCpuPrevTotal = total
    theme._systemCpuPrevUser = user
    theme._systemCpuPrevSystem = system
    theme._systemCpuPrevIoWait = ioWait
}

function parseCpuInfo(theme, text) {
    var blocks = String(text || "").trim().split(/\n\s*\n/)
    var model = ""
    var threads = 0
    var cores = {}
    var fallbackCores = 0

    for (var i = 0; i < blocks.length; i++) {
        var lines = blocks[i].split("\n")
        var physical = "0"
        var core = ""
        var processorFound = false
        for (var j = 0; j < lines.length; j++) {
            var splitAt = lines[j].indexOf(":")
            if (splitAt < 0) continue
            var key = lines[j].slice(0, splitAt).trim()
            var value = lines[j].slice(splitAt + 1).trim()
            if (key === "processor") processorFound = true
            else if ((key === "model name" || key === "Hardware") && model === "") model = value
            else if (key === "physical id") physical = value
            else if (key === "core id") core = value
            else if (key === "cpu cores" && fallbackCores === 0) fallbackCores = parseInt(value) || 0
        }
        if (processorFound) threads++
        if (core !== "") cores[physical + ":" + core] = true
    }

    theme.cpuModelName = model.replace(/\(R\)|\(TM\)/g, "")
        .replace(/\s+CPU\s+@\s+.*$/, "").replace(/\s+/g, " ").trim()
    theme.cpuThreadCount = threads
    var coreKeys = Object.keys(cores)
    theme.cpuCoreCount = coreKeys.length > 0 ? coreKeys.length : fallbackCores
}

function parseSystemLoad(theme, text) {
    var fields = String(text || "").trim().split(/\s+/)
    if (fields.length < 3) return
    theme.systemLoad1 = parseFloat(fields[0]) || 0
    theme.systemLoad5 = parseFloat(fields[1]) || 0
    theme.systemLoad15 = parseFloat(fields[2]) || 0
}

function parseCpuDetail(theme, text) {
    var fields = String(text || "").trim().split("|")
    if (fields.length < 5) return
    theme.cpuClockMHz = Math.max(0, parseInt(fields[0]) || 0)
    theme.cpuMaxClockMHz = Math.max(0, parseInt(fields[1]) || 0)
    theme.cpuEnergyPreference = String(fields[2] || "").trim()
    theme.cpuScalingGovernor = String(fields[3] || "").trim()
    theme.cpuThrottleCount = Math.max(0, parseInt(fields[4]) || 0)
}

function parseCpuTopProcesses(theme, text) {
    var lines = String(text || "").split("\n")
    var processes = []
    for (var i = 0; i < lines.length && processes.length < 3; i++) {
        var match = lines[i].trim().match(/^(.*\S)\s+([0-9]+(?:[.,][0-9]+)?)$/)
        if (!match || match[1] === "ps") continue
        var percent = parseFloat(match[2].replace(",", "."))
        if (isNaN(percent)) continue
        processes.push({ name: match[1], percent: percent })
    }
    theme.cpuTopProcesses = processes
}

function parseSystemMem(theme, text) {
    var total = 0, avail = 0, free = 0, buffers = 0, cached = 0
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].trim().split(/\s+/)
        if (parts.length < 2) continue
        var value = parseInt(parts[1])
        if (isNaN(value)) continue
        if (parts[0] === "MemTotal:") total = value
        else if (parts[0] === "MemAvailable:") avail = value
        else if (parts[0] === "MemFree:") free = value
        else if (parts[0] === "Buffers:") buffers = value
        else if (parts[0] === "Cached:") cached = value
    }
    if (total <= 0) return
    theme.systemMemTotalMiB = Math.round(total / 1024)
    theme.systemMemAvailMiB = Math.round(avail / 1024)
    theme.systemMemFreeMiB = Math.round(free / 1024)
    theme.systemMemBuffersMiB = Math.round(buffers / 1024)
    theme.systemMemCachedMiB = Math.round(cached / 1024)
}

function parseMemoryHardware(theme, text) {
    var raw = String(text || "")
    var matcher = /type:\s*(DDR[0-9]+)\b[^\n]*\bspeed:\s*([0-9]+)\s*MT\/s/gi
    var match
    var type = ""
    var speed = 0
    while ((match = matcher.exec(raw)) !== null) {
        var candidate = parseInt(match[2]) || 0
        if (type === "") type = match[1].toUpperCase()
        if (candidate > 0 && (speed === 0 || candidate < speed)) speed = candidate
    }
    theme.memoryType = type
    theme.memorySpeedMTs = speed
}

function parseGpuTelemetry(theme, text) {
    var fields = String(text || "").trim().split("|")
    if (fields.length < 12 || fields[0] === "none") {
        theme.gpuBackend = ""
        theme.gpuName = ""
        theme.gpuDriverVersion = ""
        theme.gpuPercent = 0
        theme.gpuTemperatureC = 0
        theme.gpuMemoryUsedMiB = 0
        theme.gpuMemoryTotalMiB = 0
        theme.gpuClockMHz = 0
        theme.gpuPowerW = 0
        theme.gpuPowerLimitW = 0
        theme.gpuPerformanceState = ""
        theme.gpuFanPercent = 0
        return
    }

    function clean(value) { return String(value || "").trim() }
    function number(value) {
        var parsed = parseFloat(clean(value))
        return isNaN(parsed) ? 0 : parsed
    }

    theme.gpuBackend = clean(fields[0])
    theme.gpuName = clean(fields[1])
    theme.gpuDriverVersion = clean(fields[2])
    theme.gpuPercent = Math.max(0, Math.min(100, Math.round(number(fields[3]))))
    theme.gpuTemperatureC = Math.max(0, Math.round(number(fields[4])))
    theme.gpuMemoryUsedMiB = Math.max(0, Math.round(number(fields[5])))
    theme.gpuMemoryTotalMiB = Math.max(0, Math.round(number(fields[6])))
    theme.gpuClockMHz = Math.max(0, Math.round(number(fields[7])))
    theme.gpuPowerW = Math.max(0, number(fields[8]))
    theme.gpuPowerLimitW = Math.max(0, number(fields[9]))
    theme.gpuPerformanceState = clean(fields[10])
    theme.gpuFanPercent = Math.max(0, Math.min(100, Math.round(number(fields[11]))))
}

function parseThermalTelemetry(theme, text) {
    var fields = String(text || "").trim().split("|")
    function thermal(index) {
        var value = parseInt(fields[index])
        return isNaN(value) ? 0 : Math.max(0, Math.min(150, value))
    }
    theme.cpuTemperatureC = thermal(0)
    theme.cpuCoreMaxTemperatureC = thermal(1)
    theme.cpuTemperatureMaxC = thermal(2)
    theme.cpuTemperatureCriticalC = thermal(3)
    theme.nvmeTemperatureC = thermal(4)
    theme.nvmeTemperatureMaxC = thermal(5)
    theme.nvmeTemperatureCriticalC = thermal(6)
    theme.memoryTemperatureC = thermal(7)
}

function parseStorageInventory(theme, text) {
    var parsed
    try {
        parsed = JSON.parse(String(text || ""))
    } catch (error) {
        theme.storageInventoryAvailable = false
        theme.storageDrives = []
        return
    }

    var devices = parsed && parsed.blockdevices ? parsed.blockdevices : []
    var drives = []

    function textValue(value) {
        return value === null || value === undefined ? "" : String(value).trim()
    }
    function collectVolumes(node, target) {
        var fs = textValue(node.fstype)
        var mounts = node.mountpoints || []
        var mountedAt = ""
        for (var m = 0; m < mounts.length; m++) {
            var candidate = textValue(mounts[m])
            if (candidate !== "" && candidate !== "[SWAP]") {
                mountedAt = candidate
                break
            }
        }
        if (fs !== "") {
            var pct = parseInt(textValue(node["fsuse%"]).replace("%", ""))
            var freeText = textValue(node.fsavail)
            var freeBytes = freeText === "" ? -1 : Number(freeText)
            var usedText = textValue(node.fsused)
            var usedBytes = usedText === "" ? -1 : Number(usedText)
            target.push({
                fs: fs,
                mount: mountedAt,
                percent: isNaN(pct) ? -1 : Math.max(0, Math.min(100, pct)),
                freeBytes: isNaN(freeBytes) ? -1 : Math.max(0, freeBytes),
                usedBytes: isNaN(usedBytes) ? -1 : Math.max(0, usedBytes)
            })
        }
        var children = node.children || []
        for (var c = 0; c < children.length; c++) collectVolumes(children[c], target)
    }

    for (var i = 0; i < devices.length; i++) {
        var device = devices[i]
        var name = textValue(device.name)
        if (device.type !== "disk" || name.indexOf("loop") === 0
                || name.indexOf("ram") === 0 || name.indexOf("zram") === 0)
            continue

        var volumes = []
        collectVolumes(device, volumes)
        var fileSystems = []
        var mountedAt = ""
        var usage = -1
        var freeBytes = -1
        var usedBytes = -1
        for (var v = 0; v < volumes.length; v++) {
            if (fileSystems.indexOf(volumes[v].fs) < 0) fileSystems.push(volumes[v].fs)
            if (mountedAt === "" && volumes[v].mount !== "") {
                mountedAt = volumes[v].mount
                usage = volumes[v].percent
                freeBytes = volumes[v].freeBytes
                usedBytes = volumes[v].usedBytes
            }
        }

        var transport = textValue(device.tran).toUpperCase()
        var removable = device.rm === true || device.hotplug === true || transport === "USB"
        var driveType = transport === "NVME" ? "nvme"
            : device.rota === true ? "hdd"
            : "ssd"
        var media = removable ? "USB DRIVE"
            : transport === "NVME" ? "NVME SSD"
            : device.rota === true ? (transport !== "" ? transport + " HDD" : "HDD")
            : (transport !== "" ? transport + " SSD" : "SSD")
        var state = mountedAt !== "" ? mountedAt
            : (fileSystems.length > 0 ? "Not mounted" : "No filesystem")

        drives.push({
            name: name,
            model: textValue(device.model) || name,
            size: Number(device.size) || 0,
            driveType: driveType,
            media: media,
            fileSystems: fileSystems.join(" + ").toUpperCase(),
            state: state,
            percent: usage,
            freeBytes: freeBytes,
            usedBytes: usedBytes,
            totalBytes: usedBytes >= 0 && freeBytes >= 0 ? usedBytes + freeBytes : -1
        })
    }

    theme.storageDrives = drives
    theme.storageInventoryAvailable = true
}

function parseStorageTelemetry(theme, text) {
    var fields = String(text || "").trim().split("|")
    if (fields.length < 3) {
        theme.storageAvailable = false
        theme.storagePercent = 0
        theme.storageUsedBytes = 0
        theme.storageTotalBytes = 0
        return
    }

    var percent = parseInt(fields[0])
    var used = parseFloat(fields[1])
    var total = parseFloat(fields[2])
    if (isNaN(percent) || isNaN(used) || isNaN(total) || total <= 0) {
        theme.storageAvailable = false
        return
    }

    theme.storageAvailable = true
    theme.storagePercent = Math.max(0, Math.min(100, percent))
    theme.storageUsedBytes = Math.max(0, used)
    theme.storageTotalBytes = Math.max(0, total)
}

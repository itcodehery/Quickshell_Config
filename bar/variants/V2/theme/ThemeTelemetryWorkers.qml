import QtQuick
import ".."
import Quickshell
import Quickshell.Io

Item {
    id: root
    required property var theme

    Process {
        id: aiReadClaude
        command: ["bash", "-c",
            "f=\"$HOME/.cache/claude-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    root.theme.aiClHas = true
                    root.theme.aiClFresh = ageOk && d._source !== "stale"
                    root.theme.aiClPct5h = root.theme.aiPct(d["5h-utilization"])
                    root.theme.aiClPct7d = root.theme.aiPct(d["7d-utilization"])
                    root.theme.aiClBlocked = d.status === "rejected" || d.status === "blocked"
                    root.theme.aiClReset5hTs = parseInt(d["5h-reset"]) || 0
                    root.theme.aiClReset7dTs = parseInt(d["7d-reset"]) || 0
                    var used = (d["_tokens_used"] || 0), lim = (d["_window_limit"] || 0)
                    root.theme.aiClTokens = used ? (used / 1e6).toFixed(2) + "M / " + (lim / 1e6).toFixed(1) + "M" : ""
                    var rateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    root.theme.aiClRate = rateH > 0 ? rateH + "k tok/h" : ""
                    root.theme.aiClToday = parseInt(d._today_tokens) || 0
                } catch (e) {
                    root.theme.aiClHas = false; root.theme.aiClFresh = false
                    root.theme.aiClPct5h = 0; root.theme.aiClPct7d = 0
                    root.theme.aiClBlocked = false; root.theme.aiClTokens = ""; root.theme.aiClRate = ""
                    root.theme.aiClReset5hTs = 0; root.theme.aiClReset7dTs = 0; root.theme.aiClToday = 0
                }
            }
        }
    }

    Process {
        id: aiReadCodex
        command: ["bash", "-c",
            "f=\"$HOME/.cache/codex-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    root.theme.aiApplyCodexCache(d, ageOk)
                } catch (e) {
                    root.theme.aiResetCodexUsage()
                }
            }
        }
    }

    Process {
        id: aiReadOpenCode
        command: ["bash", "-c",
            "f=\"$HOME/.cache/opencode-usage.json\"; stat -c %Y \"$f\" 2>/dev/null; cat \"$f\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = this.text, nl = raw.indexOf("\n")
                var mtime = nl > 0 ? (parseInt(raw.substring(0, nl)) || 0) : 0
                var ageOk = mtime > 0 && (Date.now() / 1000 - mtime) < 900
                try {
                    var d = JSON.parse((nl > 0 ? raw.substring(nl + 1) : "").trim())
                    root.theme.aiOcHas = true
                    root.theme.aiOcFresh = ageOk && d._source !== "stale"
                    root.theme.aiOcPct5h = root.theme.aiPct(d["5h-utilization"])
                    root.theme.aiOcPct7d = root.theme.aiPct(d["7d-utilization"])
                    root.theme.aiOcPlan = d._plan || ""
                    var ocUsed = (d["_tokens_used"] || 0), ocLim = (d["_window_limit"] || 0)
                    root.theme.aiOcTokens = ocUsed ? (ocUsed / 1e6).toFixed(2) + "M / " + (ocLim / 1e6).toFixed(1) + "M" : ""
                    var ocRateH = Math.round((d["_rate_per_hour"] || 0) / 1000)
                    root.theme.aiOcRate = ocRateH > 0 ? ocRateH + "k tok/h" : ""
                    root.theme.aiOcToday = parseInt(d._today_tokens) || 0
                    root.theme.aiOcModel = d._model || ""
                    root.theme.aiOcModels = d._models instanceof Array ? d._models : []
                } catch (e) {
                    root.theme.aiOcHas = false; root.theme.aiOcFresh = false
                    root.theme.aiOcPct5h = 0; root.theme.aiOcPct7d = 0
                    root.theme.aiOcPlan = ""; root.theme.aiOcTokens = ""; root.theme.aiOcRate = ""; root.theme.aiOcModel = ""
                    root.theme.aiOcToday = 0; root.theme.aiOcModels = []
                }
            }
        }
    }

    Process {
        id: aiReadAgy
        command: ["bash", "-c",
            "sqlite3 -noheader -list ~/.gemini/antigravity-cli/conversation_summaries.db \"SELECT COUNT(*), SUM(step_count) FROM conversation_summaries; SELECT COUNT(*), SUM(step_count) FROM conversation_summaries WHERE last_modified_time > datetime('now', '-1 day');\" 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                if (lines.length >= 2) {
                    var total = lines[0].split("|");
                    var today = lines[1].split("|");
                    root.theme.aiAgyTotalSessions = total[0] || "0";
                    root.theme.aiAgyTotalSteps = total[1] || "0";
                    root.theme.aiAgyTodaySessions = today[0] || "0";
                    root.theme.aiAgyTodaySteps = today[1] || "0";
                    root.theme.aiAgyHas = true;
                }
            }
        }
    }

    function refreshAiUsage(selectedOnly) {
        root.theme.aiClockTick++
        var only = selectedOnly === true
        if (!only || root.theme.aiTool === "claude") {
            aiReadClaude.running = false; aiReadClaude.running = true
        }
        if (!only || root.theme.aiTool === "codex") {
            aiReadCodex.running = false;  aiReadCodex.running = true
        }
        if (!only || root.theme.aiTool === "opencode") {
            aiReadOpenCode.running = false; aiReadOpenCode.running = true
        }
        if (!only || root.theme.aiTool === "agy") {
            aiReadAgy.running = false; aiReadAgy.running = true
        }
    }

    Timer {
        // 30s normally; 5s while the AI panel is open (responsive when looked at)
        interval: root.theme.aiUsageVisible ? 5000 : 30000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.theme.refreshAiUsage(root.theme.aiUsageVisible)
    }

    FileView {
        id: systemCpuFile
        path: "/proc/stat"
        onLoaded: root.theme.parseSystemCpu(systemCpuFile.text())
    }

    FileView {
        id: systemCpuInfoFile
        path: "/proc/cpuinfo"
        onLoaded: root.theme.parseCpuInfo(systemCpuInfoFile.text())
    }

    FileView {
        id: systemLoadFile
        path: "/proc/loadavg"
        onLoaded: root.theme.parseSystemLoad(systemLoadFile.text())
    }

    FileView {
        id: kernelReleaseFile
        path: "/proc/sys/kernel/osrelease"
        onLoaded: root.theme.kernelRelease = String(kernelReleaseFile.text() || "").trim()
    }

    FileView {
        id: systemMemFile
        path: "/proc/meminfo"
        onLoaded: root.theme.parseSystemMem(systemMemFile.text())
    }

    Process {
        id: cpuDetailProc
        command: ["bash", "-c",
            "sum=0; count=0; max=0; epp=''; governor=''; throttle=0; "
            + "for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do [[ -r $f ]] || continue; IFS= read -r v < \"$f\"; "
            + "[[ $v =~ ^[0-9]+$ ]] || continue; sum=$((sum + v)); count=$((count + 1)); done; "
            + "(( count > 0 )) && avg=$((sum / count / 1000)) || avg=0; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && max=$((v / 1000)); }; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference; [[ -r $f ]] && IFS= read -r epp < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor; [[ -r $f ]] && IFS= read -r governor < \"$f\"; "
            + "f=/sys/devices/system/cpu/cpu0/thermal_throttle/package_throttle_count; [[ -r $f ]] && { IFS= read -r v < \"$f\"; [[ $v =~ ^[0-9]+$ ]] && throttle=$v; }; "
            + "printf '%s|%s|%s|%s|%s\\n' \"$avg\" \"$max\" \"$epp\" \"$governor\" \"$throttle\""]
        stdout: StdioCollector { onStreamFinished: root.theme.parseCpuDetail(this.text) }
    }

    Process {
        id: memoryHardwareProc
        command: ["bash", "-c",
            "if command -v inxi >/dev/null 2>&1; then LC_ALL=C inxi -m -c 0 --no-host 2>/dev/null; fi"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.theme.parseMemoryHardware(this.text) }
    }

    Process {
        id: cpuTopProcessesProc
        command: ["ps", "-eo", "comm=,%cpu=", "--sort=-%cpu"]
        stdout: StdioCollector { onStreamFinished: root.theme.parseCpuTopProcesses(this.text) }
    }

    Process {
        id: gpuTelemetryProc
        command: ["bash", "-c",
            "if command -v nvidia-smi >/dev/null 2>&1; then "
            + "IFS=, read -r name driver util temp used total clock power limit pstate fan < <(nvidia-smi --query-gpu=name,driver_version,utilization.gpu,temperature.gpu,memory.used,memory.total,clocks.current.graphics,power.draw,power.limit,pstate,fan.speed --format=csv,noheader,nounits 2>/dev/null | head -n1); "
            + "if [[ $util =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $temp =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $used =~ ^[[:space:]]*[0-9]+[[:space:]]*$ && $total =~ ^[[:space:]]*[0-9]+[[:space:]]*$ ]]; then "
            + "printf 'nvidia|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$name\" \"$driver\" \"$util\" \"$temp\" \"$used\" \"$total\" \"$clock\" \"$power\" \"$limit\" \"$pstate\" \"$fan\"; exit 0; fi; "
            + "fi; "
            + "for busy in /sys/class/drm/card*/device/gpu_busy_percent; do "
            + "[[ -r $busy ]] || continue; read -r util < \"$busy\"; temp=0; "
            + "for sensor in \"${busy%/gpu_busy_percent}\"/hwmon/hwmon*/temp1_input; do "
            + "[[ -r $sensor ]] || continue; read -r raw < \"$sensor\"; temp=$((raw / 1000)); break; done; "
            + "printf 'sysfs|GPU||%s|%s|0|0|0|0|0||0\\n' \"$util\" \"$temp\"; exit 0; done; "
            + "printf 'none|||||||||||\\n'"]
        stdout: StdioCollector { onStreamFinished: root.theme.parseGpuTelemetry(this.text) }
    }

    Process {
        id: cpuTemperatureProc
        command: ["bash", "-c",
            "cpu=0; core=0; cpu_max=0; cpu_crit=0; nvme=0; nvme_max=0; nvme_crit=0; dimm=0; "
            + "for d in /sys/class/hwmon/hwmon*; do [[ -r $d/name ]] || continue; IFS= read -r name < \"$d/name\"; "
            + "case $name in coretemp|k10temp|zenpower|cpu_thermal) "
            + "for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; raw=0; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "label_file=${input%_input}_label; label=''; [[ -r $label_file ]] && IFS= read -r label < \"$label_file\"; value=$((raw / 1000)); "
            + "case $label in 'Package id 0'|Tctl|Tdie|'CPU Package'|CPU) cpu=$value; max_file=${input%_input}_max; crit_file=${input%_input}_crit; "
            + "[[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && cpu_crit=$((v / 1000)); };; "
            + "Core*) (( value > core )) && core=$value;; esac; (( cpu == 0 )) && cpu=$value; done;; "
            + "nvme) for label_file in \"$d\"/temp*_label; do [[ -r $label_file ]] || continue; IFS= read -r label < \"$label_file\"; [[ $label == Composite ]] || continue; "
            + "input=${label_file%_label}_input; [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; nvme=$((raw / 1000)); "
            + "max_file=${input%_input}_max; crit_file=${input%_input}_crit; [[ -r $max_file ]] && { IFS= read -r v < \"$max_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_max=$((v / 1000)); }; "
            + "[[ -r $crit_file ]] && { IFS= read -r v < \"$crit_file\"; [[ $v =~ ^[0-9]+$ ]] && nvme_crit=$((v / 1000)); }; break; done;; "
            + "jc42) for input in \"$d\"/temp*_input; do [[ -r $input ]] || continue; IFS= read -r raw < \"$input\"; [[ $raw =~ ^[0-9]+$ ]] || continue; "
            + "value=$((raw / 1000)); (( value > dimm )) && dimm=$value; done;; esac; done; "
            + "if (( cpu == 0 )); then for zone in /sys/class/thermal/thermal_zone*; do [[ -r $zone/type && -r $zone/temp ]] || continue; "
            + "IFS= read -r type < \"$zone/type\"; case $type in x86_pkg_temp|cpu-thermal|cpu_thermal) IFS= read -r raw < \"$zone/temp\"; "
            + "[[ $raw =~ ^[0-9]+$ ]] && { cpu=$((raw / 1000)); break; };; esac; done; fi; "
            + "printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' \"$cpu\" \"$core\" \"$cpu_max\" \"$cpu_crit\" \"$nvme\" \"$nvme_max\" \"$nvme_crit\" \"$dimm\""]
        stdout: StdioCollector { onStreamFinished: root.theme.parseThermalTelemetry(this.text) }
    }

    Process {
        id: storageTelemetryProc
        command: ["bash", "-c",
            "LC_ALL=C df -P -B1 / 2>/dev/null | awk 'NR == 2 { gsub(/%/, \"\", $5); printf \"%s|%s|%s\\n\", $5, $3, $2 }'"]
        stdout: StdioCollector { onStreamFinished: root.theme.parseStorageTelemetry(this.text) }
    }

    Process {
        id: storageInventoryProc
        command: ["lsblk", "-J", "-b", "-o",
            "NAME,PATH,TYPE,SIZE,FSTYPE,FSUSED,FSAVAIL,FSUSE%,MOUNTPOINTS,MODEL,TRAN,ROTA,RM,HOTPLUG"]
        stdout: StdioCollector { onStreamFinished: root.theme.parseStorageInventory(this.text) }
    }

    Timer {
        interval: root.theme.dashboardExpanded ? 2000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            systemCpuFile.reload()
            systemLoadFile.reload()
            systemMemFile.reload()
        }
    }

    Timer {
        interval: 2500
        running: root.theme.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuDetailProc.running) cpuDetailProc.running = true
    }

    Timer {
        interval: 3000
        running: root.theme.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTopProcessesProc.running) cpuTopProcessesProc.running = true
    }

    Timer {
        interval: 2500
        running: root.theme.gpuVisible || root.theme.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!gpuTelemetryProc.running) gpuTelemetryProc.running = true
    }

    Timer {
        interval: 5000
        running: root.theme.cpuVisible || root.theme.thermalVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cpuTemperatureProc.running) cpuTemperatureProc.running = true
    }

    Timer {
        interval: 30000
        running: root.theme.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageTelemetryProc.running) storageTelemetryProc.running = true
    }

    Timer {
        interval: 5000
        running: root.theme.storageVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!storageInventoryProc.running) storageInventoryProc.running = true
    }
}

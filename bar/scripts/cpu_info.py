#!/usr/bin/env python3
import sys
import os
import json
import subprocess

def get_cpu_info():
    info = {
        "model": "",
        "threads": 0,
        "cores": 0,
        "temp": 0,
        "governor": "",
        "epp": "",
        "load": [0, 0, 0],
        "freqs": [],
        "topProcesses": []
    }
    # Load avg
    try:
        info["load"] = [round(x, 2) for x in os.getloadavg()]
    except Exception:
        pass

    # Model and threads
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if "model name" in line and not info["model"]:
                    info["model"] = line.split(":", 1)[1].strip()
                elif "processor" in line:
                    info["threads"] += 1
                elif "cpu cores" in line and info["cores"] == 0:
                    try:
                        info["cores"] = int(line.split(":", 1)[1].strip())
                    except Exception:
                        pass
    except Exception:
        pass
    if info["cores"] == 0 and info["threads"] > 0:
        info["cores"] = max(1, info["threads"] // 2)

    # Governor & EPP
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor") as f:
            info["governor"] = f.read().strip()
    except Exception:
        pass
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference") as f:
            info["epp"] = f.read().strip()
    except Exception:
        pass

    # Temperature
    for p in [
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
        "/sys/class/hwmon/hwmon1/temp1_input",
        "/sys/class/hwmon/hwmon2/temp1_input",
        "/sys/class/hwmon/hwmon3/temp1_input",
        "/sys/class/hwmon/hwmon4/temp1_input"
    ]:
        if os.path.exists(p):
            try:
                with open(p) as f:
                    t = int(f.read().strip()) // 1000
                    if 20 <= t <= 110:
                        info["temp"] = t
                        break
            except Exception:
                pass

    # Per-core frequencies
    freqs = []
    for i in range(info["threads"]):
        fp = f"/sys/devices/system/cpu/cpu{i}/cpufreq/scaling_cur_freq"
        if os.path.exists(fp):
            try:
                with open(fp) as f:
                    freqs.append(round(int(f.read().strip()) / 1000))
            except Exception:
                freqs.append(0)
    info["freqs"] = freqs

    # Top processes
    try:
        out = subprocess.check_output(
            ["bash", "-c", "ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -n 11 | tail -n 10"],
            text=True
        )
        for line in out.splitlines():
            parts = line.strip().split(None, 3)
            if len(parts) >= 4:
                info["topProcesses"].append({
                    "pid": parts[0],
                    "cpu": parts[1] + "%",
                    "mem": parts[2] + "%",
                    "name": parts[3]
                })
    except Exception:
        pass

    return info

def kill_process(pid):
    if not pid:
        return {"success": False, "error": "No PID"}
    try:
        subprocess.run(["kill", "-9", str(pid)], check=True)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "kill" and len(sys.argv) > 2:
        print(json.dumps(kill_process(sys.argv[2])))
    else:
        print(json.dumps(get_cpu_info()))

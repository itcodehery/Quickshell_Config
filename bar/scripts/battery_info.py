#!/usr/bin/env python3
import sys
import json
import subprocess
import os
import glob

def get_battery_info():
    bats = glob.glob("/sys/class/power_supply/BAT*")
    bat_path = bats[0] if bats else None
    
    bat_id = os.path.basename(bat_path) if bat_path else "BAT1"
    
    def read_val(f, default=""):
        if not bat_path:
            return default
        p = os.path.join(bat_path, f)
        if os.path.exists(p):
            try:
                with open(p, "r") as fp:
                    return fp.read().strip()
            except Exception:
                pass
        return default

    # Capacity
    cap_str = read_val("capacity", "0")
    try:
        percent = int(cap_str)
    except Exception:
        percent = 0

    status = read_val("status", "Unknown")
    
    # Energy in uWh
    energy_now = int(read_val("energy_now", read_val("charge_now", "0")) or 0)
    energy_full = int(read_val("energy_full", read_val("charge_full", "0")) or 0)
    energy_design = int(read_val("energy_full_design", read_val("charge_full_design", "0")) or 0)
    voltage = int(read_val("voltage_now", "0") or 0)
    cycles = int(read_val("cycle_count", "0") or 0)
    model = read_val("model_name", bat_id)
    tech = read_val("technology", "Li-ion")

    # AC online
    ac_online = False
    for a in glob.glob("/sys/class/power_supply/AC*/online"):
        try:
            with open(a) as fp:
                if fp.read().strip() == "1":
                    ac_online = True
                    break
        except Exception:
            pass

    # Health %
    health_pct = 100
    if energy_design > 0 and energy_full > 0:
        health_pct = min(100, round((energy_full / energy_design) * 100))

    # Wh conversion
    energy_now_wh = round(energy_now / 1000000.0, 1)
    energy_full_wh = round(energy_full / 1000000.0, 1)
    energy_design_wh = round(energy_design / 1000000.0, 1)
    voltage_v = round(voltage / 1000000.0, 2)

    # Power rate via upower or sysfs power_now
    power_rate_w = 0.0
    power_now = read_val("power_now", read_val("current_now", "0"))
    if power_now and power_now.isdigit() and int(power_now) > 0:
        power_rate_w = round(int(power_now) / 1000000.0, 1)

    time_remaining_str = ""
    # Try UPower for remaining time estimate
    try:
        up_out = subprocess.check_output(["upower", "-i", f"/org/freedesktop/UPower/devices/battery_{bat_id}"], text=True, timeout=1.5)
        for line in up_out.splitlines():
            if "time to" in line:
                parts = line.strip().split(":", 1)
                if len(parts) == 2:
                    time_remaining_str = parts[1].strip()
            elif "energy-rate" in line and power_rate_w == 0.0:
                parts = line.strip().split()
                if len(parts) >= 2:
                    try:
                        power_rate_w = round(float(parts[1]), 1)
                    except Exception:
                        pass
    except Exception:
        pass

    # Power profile
    active_profile = "balanced"
    try:
        prof_out = subprocess.check_output(["powerprofilesctl", "get"], text=True, timeout=1.0).strip()
        if prof_out:
            active_profile = prof_out
    except Exception:
        pass

    # Top processes by CPU/power drain
    top_procs = []
    try:
        ps_out = subprocess.check_output(["ps", "-eo", "pid,pcpu,comm", "--sort=-pcpu"], text=True, timeout=1.5)
        lines = ps_out.strip().splitlines()
        for line in lines[1:8]:
            p = line.strip().split(None, 2)
            if len(p) >= 3 and p[2] not in ["ps", "grep", "awk", "sed", "python3"]:
                top_procs.append({
                    "pid": p[0],
                    "cpu": f"{p[1]}%",
                    "name": p[2]
                })
    except Exception:
        pass

    return {
        "batteryId": bat_id,
        "percent": percent,
        "status": status,
        "acOnline": ac_online,
        "health": health_pct,
        "health_str": f"{health_pct}%",
        "cycles": cycles,
        "voltage": voltage_v,
        "voltage_str": f"{voltage_v} V",
        "powerRate": power_rate_w,
        "powerRate_str": f"{power_rate_w} W",
        "energyNow_wh": energy_now_wh,
        "energyFull_wh": energy_full_wh,
        "energyDesign_wh": energy_design_wh,
        "timeRemaining": time_remaining_str or ("Fully Charged" if percent >= 98 and ac_online else ("Calculating..." if status == "Discharging" else "")),
        "model": model,
        "technology": tech,
        "profile": active_profile,
        "topProcesses": top_procs
    }

def set_profile(profile_name):
    try:
        subprocess.run(["powerprofilesctl", "set", profile_name], check=True, timeout=2.0)
        return {"success": True, "profile": profile_name}
    except Exception as e:
        return {"success": False, "error": str(e)}

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        print(json.dumps(get_battery_info()))
    elif sys.argv[1] == "set-profile" and len(sys.argv) >= 3:
        print(json.dumps(set_profile(sys.argv[2])))
    else:
        print(json.dumps(get_battery_info()))

if __name__ == "__main__":
    main()

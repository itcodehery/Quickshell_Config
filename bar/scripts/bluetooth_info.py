#!/usr/bin/env python3
import sys
import json
import subprocess
import os

def get_bt_info():
    info = {
        "powered": False,
        "controllerName": "",
        "controllerMac": "",
        "discoverable": False,
        "devices": []
    }
    try:
        show_out = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL)
        for line in show_out.splitlines():
            line = line.strip()
            if line.startswith("Controller"):
                parts = line.split()
                if len(parts) > 1:
                    info["controllerMac"] = parts[1]
            elif line.startswith("Name:"):
                info["controllerName"] = line.split("Name:", 1)[1].strip()
            elif line.startswith("Powered:"):
                info["powered"] = (line.split("Powered:", 1)[1].strip().lower() == "yes")
            elif line.startswith("Discoverable:"):
                info["discoverable"] = (line.split("Discoverable:", 1)[1].strip().lower() == "yes")
    except Exception:
        pass

    if info["powered"]:
        try:
            dev_lines = subprocess.check_output(["bluetoothctl", "devices"], text=True, stderr=subprocess.DEVNULL).splitlines()
            for dl in dev_lines:
                parts = dl.strip().split()
                if len(parts) >= 3 and parts[0] == "Device":
                    mac = parts[1]
                    name = " ".join(parts[2:])
                    dev_data = {
                        "mac": mac,
                        "name": name,
                        "connected": False,
                        "paired": False,
                        "trusted": False,
                        "icon": "bluetooth",
                        "battery": -1
                    }
                    try:
                        dev_info = subprocess.check_output(["bluetoothctl", "info", mac], text=True, stderr=subprocess.DEVNULL)
                        for line in dev_info.splitlines():
                            line = line.strip()
                            if line.startswith("Connected:"):
                                dev_data["connected"] = (line.split("Connected:", 1)[1].strip().lower() == "yes")
                            elif line.startswith("Paired:"):
                                dev_data["paired"] = (line.split("Paired:", 1)[1].strip().lower() == "yes")
                            elif line.startswith("Trusted:"):
                                dev_data["trusted"] = (line.split("Trusted:", 1)[1].strip().lower() == "yes")
                            elif line.startswith("Icon:"):
                                dev_data["icon"] = line.split("Icon:", 1)[1].strip()
                            elif "Battery Percentage:" in line:
                                val = line.split("(")[-1].split(")")[0]
                                if val.isdigit():
                                    dev_data["battery"] = int(val)
                    except Exception:
                        pass
                    info["devices"].append(dev_data)
        except Exception:
            pass

    info["devices"].sort(key=lambda d: (not d["connected"], not d["paired"], d["name"].lower()))
    return info

def connect_device(mac):
    if not mac:
        return {"success": False, "error": "No MAC provided"}
    try:
        res = subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True, timeout=12)
        return {"success": res.returncode == 0 and "Successful" in (res.stdout + res.stderr), "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def disconnect_device(mac):
    if not mac:
        return {"success": False, "error": "No MAC provided"}
    try:
        res = subprocess.run(["bluetoothctl", "disconnect", mac], capture_output=True, text=True, timeout=10)
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def pair_device(mac):
    if not mac:
        return {"success": False, "error": "No MAC provided"}
    try:
        subprocess.run(["bluetoothctl", "trust", mac], capture_output=True, text=True, timeout=5)
        res = subprocess.run(["bluetoothctl", "pair", mac], capture_output=True, text=True, timeout=15)
        subprocess.run(["bluetoothctl", "connect", mac], capture_output=True, text=True, timeout=10)
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def remove_device(mac):
    if not mac:
        return {"success": False, "error": "No MAC provided"}
    try:
        res = subprocess.run(["bluetoothctl", "remove", mac], capture_output=True, text=True, timeout=8)
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def toggle_power():
    try:
        show = subprocess.check_output(["bluetoothctl", "show"], text=True, stderr=subprocess.DEVNULL)
        is_powered = "Powered: yes" in show
        new_state = "off" if is_powered else "on"
        subprocess.run(["bluetoothctl", "power", new_state], check=True, timeout=5)
        return {"success": True, "state": new_state}
    except Exception as e:
        return {"success": False, "error": str(e)}

def scan_now():
    try:
        subprocess.Popen(["bluetoothctl", "--timeout", "10", "scan", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    if action == "status" or action == "all":
        print(json.dumps(get_bt_info()))
    elif action == "connect":
        m = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(connect_device(m)))
    elif action == "disconnect":
        m = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(disconnect_device(m)))
    elif action == "pair":
        m = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(pair_device(m)))
    elif action == "remove":
        m = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(remove_device(m)))
    elif action == "toggle-power":
        print(json.dumps(toggle_power()))
    elif action == "scan":
        print(json.dumps(scan_now()))
    else:
        print(json.dumps(get_bt_info()))

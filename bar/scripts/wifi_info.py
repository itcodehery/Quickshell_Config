#!/usr/bin/env python3
import sys
import json
import subprocess
import os

def get_wifi_status():
    status = {
        "connected": False,
        "ssid": "",
        "ip": "",
        "iface": "",
        "signal": 0,
        "freq": "",
        "linkSpeed": "",
        "ping": "",
        "wifiBlocked": False
    }
    
    # 1. Radio state
    try:
        radio_out = subprocess.check_output(["nmcli", "radio", "wifi"], text=True, stderr=subprocess.DEVNULL).strip()
        status["wifiBlocked"] = (radio_out.lower() != "enabled")
    except Exception:
        pass

    # 2. Interface & IP
    try:
        route_out = subprocess.check_output(["bash", "-c", "ip route get 1.1.1.1 2>/dev/null"], text=True)
        tokens = route_out.split()
        for idx, token in enumerate(tokens):
            if token == "dev" and idx + 1 < len(tokens):
                status["iface"] = tokens[idx + 1]
                break
        
        if status["iface"]:
            ip_out = subprocess.check_output(["bash", "-c", f"ip -o -4 addr show dev {status['iface']} 2>/dev/null"], text=True)
            parts = ip_out.split()
            if len(parts) >= 4:
                status["ip"] = parts[3].split("/")[0]
    except Exception:
        pass

    # 3. Wi-Fi Link info (iw)
    if status["iface"]:
        try:
            link_out = subprocess.check_output(["iw", "dev", status["iface"], "link"], text=True, stderr=subprocess.DEVNULL)
            for line in link_out.splitlines():
                line = line.strip()
                if line.startswith("SSID:"):
                    status["ssid"] = line.split("SSID:", 1)[1].strip()
                    status["connected"] = True
                elif "signal:" in line:
                    sig_val = int(line.split("signal:", 1)[1].split()[0])
                    pct = int((sig_val + 100) * 100 / 70)
                    status["signal"] = max(0, min(100, pct))
                elif "freq:" in line:
                    status["freq"] = line.split("freq:", 1)[1].strip() + " MHz"
                elif "tx bitrate:" in line:
                    status["linkSpeed"] = line.split("tx bitrate:", 1)[1].strip()
        except Exception:
            pass

    # Fallback to nmcli for SSID / signal if iw wasn't available
    if not status["ssid"]:
        try:
            nm_active = subprocess.check_output(
                ["bash", "-c", "nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep 802-11-wireless | cut -d: -f2-"],
                text=True
            ).strip()
            if nm_active:
                status["ssid"] = nm_active
                status["connected"] = True
        except Exception:
            pass

    # 4. Quick ping
    try:
        ping_out = subprocess.check_output(["bash", "-c", "ping -c 1 -W 1 1.1.1.1 2>/dev/null"], text=True)
        for line in ping_out.splitlines():
            if "time=" in line:
                t = line.split("time=", 1)[1].split()[0]
                status["ping"] = f"{t} ms"
                break
    except Exception:
        pass

    return status

def get_networks():
    # 1. Saved connections
    saved = set()
    try:
        saved_out = subprocess.check_output(
            ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"],
            text=True, stderr=subprocess.DEVNULL
        )
        for line in saved_out.splitlines():
            if ":" in line:
                name, ctype = line.split(":", 1)
                if "wireless" in ctype or "802-11" in ctype:
                    saved.add(name.strip())
    except Exception:
        pass

    # 2. Available wifi list
    networks = []
    seen = set()
    try:
        wifi_out = subprocess.check_output(
            ["nmcli", "-t", "-f", "IN-USE,BSSID,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"],
            text=True, stderr=subprocess.DEVNULL
        )
        for line in wifi_out.splitlines():
            if not line:
                continue
            parts = line.replace("\\:", "__COLON__").split(":")
            in_use = parts[0].strip() == "*"
            ssid = parts[2].replace("__COLON__", ":").strip() if len(parts) > 2 else ""
            if not ssid or ssid == "--" or ssid in seen:
                continue
            seen.add(ssid)
            sig = int(parts[3]) if len(parts) > 3 and parts[3].isdigit() else 0
            sec = parts[4].replace("__COLON__", ":").strip() if len(parts) > 4 else "Open"
            networks.append({
                "ssid": ssid,
                "signal": sig,
                "security": sec if sec else "Open",
                "connected": in_use,
                "saved": ssid in saved
            })
    except Exception:
        pass

    # Add saved networks
    saved_list = []
    for s in saved:
        saved_list.append({
            "ssid": s,
            "saved": True,
            "connected": any(n["ssid"] == s and n["connected"] for n in networks),
            "security": "Saved"
        })

    networks.sort(key=lambda x: (not x["connected"], -x["signal"]))
    saved_list.sort(key=lambda x: (not x["connected"], x["ssid"].lower()))

    status = get_wifi_status()

    return {
        "status": status,
        "available": networks,
        "saved": saved_list
    }

def connect_network(ssid, password=None):
    if not ssid:
        return {"success": False, "error": "No SSID provided"}
    try:
        if password:
            res = subprocess.run(
                ["nmcli", "dev", "wifi", "connect", ssid, "password", password],
                capture_output=True, text=True, timeout=20
            )
        else:
            # Try connection up first in case it's saved
            res = subprocess.run(
                ["nmcli", "connection", "up", "id", ssid],
                capture_output=True, text=True, timeout=10
            )
            if res.returncode != 0:
                res = subprocess.run(
                    ["nmcli", "dev", "wifi", "connect", ssid],
                    capture_output=True, text=True, timeout=20
                )
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def disconnect_network(ssid=None):
    try:
        if ssid:
            res = subprocess.run(["nmcli", "connection", "down", "id", ssid], capture_output=True, text=True)
        else:
            res = subprocess.run(["bash", "-c", "IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"dev\"){print $(i+1); exit}}'); [ -n \"$IFACE\" ] && nmcli dev disconnect iface \"$IFACE\""], capture_output=True, text=True)
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def forget_network(ssid):
    if not ssid:
        return {"success": False, "error": "No SSID provided"}
    try:
        res = subprocess.run(["nmcli", "connection", "delete", "id", ssid], capture_output=True, text=True)
        return {"success": res.returncode == 0, "output": res.stdout.strip(), "error": res.stderr.strip()}
    except Exception as e:
        return {"success": False, "error": str(e)}

def toggle_radio():
    try:
        radio = subprocess.check_output(["nmcli", "radio", "wifi"], text=True).strip().lower()
        new_state = "off" if radio == "enabled" else "on"
        subprocess.run(["nmcli", "radio", "wifi", new_state], check=True)
        return {"success": True, "state": new_state}
    except Exception as e:
        return {"success": False, "error": str(e)}

def rescan():
    try:
        subprocess.run(["nmcli", "dev", "wifi", "rescan"], timeout=5)
        return {"success": True}
    except Exception as e:
        return {"success": False, "error": str(e)}

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "all"
    if action == "status":
        print(json.dumps(get_wifi_status()))
    elif action == "scan" or action == "all":
        print(json.dumps(get_networks()))
    elif action == "connect":
        s = sys.argv[2] if len(sys.argv) > 2 else ""
        p = sys.argv[3] if len(sys.argv) > 3 else None
        print(json.dumps(connect_network(s, p)))
    elif action == "disconnect":
        s = sys.argv[2] if len(sys.argv) > 2 else None
        print(json.dumps(disconnect_network(s)))
    elif action == "forget":
        s = sys.argv[2] if len(sys.argv) > 2 else ""
        print(json.dumps(forget_network(s)))
    elif action == "toggle-radio":
        print(json.dumps(toggle_radio()))
    elif action == "rescan":
        print(json.dumps(rescan()))
    else:
        print(json.dumps(get_networks()))

#!/usr/bin/env python3
import os
import sys
import json
import glob
import subprocess

STATE_FILE = os.path.expanduser("~/.local/share/quickshell_recent_apps.json")

_icon_cache = {}

def find_icon(icon_name):
    if not icon_name:
        return ""
    if icon_name in _icon_cache:
        return _icon_cache[icon_name]
    if os.path.isabs(icon_name) and os.path.exists(icon_name):
        res = f"file://{icon_name}"
        _icon_cache[icon_name] = res
        return res
    
    # Check pixmaps
    for ext in ["png", "svg", "xpm"]:
        p = f"/usr/share/pixmaps/{icon_name}.{ext}"
        if os.path.exists(p):
            res = f"file://{p}"
            _icon_cache[icon_name] = res
            return res
            
    # Search hicolor
    for size in ["256x256", "128x128", "scalable", "64x64", "48x48", "32x32"]:
        p1 = f"/usr/share/icons/hicolor/{size}/apps/{icon_name}.png"
        if os.path.exists(p1):
            res = f"file://{p1}"
            _icon_cache[icon_name] = res
            return res
        p2 = f"/usr/share/icons/hicolor/{size}/apps/{icon_name}.svg"
        if os.path.exists(p2):
            res = f"file://{p2}"
            _icon_cache[icon_name] = res
            return res

    # Fast check in other icon themes
    matches = glob.glob(f"/usr/share/icons/*/*/apps/{icon_name}.*")
    if matches:
        res = f"file://{matches[0]}"
        _icon_cache[icon_name] = res
        return res

    matches_user = glob.glob(os.path.expanduser(f"~/.local/share/icons/*/*/apps/{icon_name}.*"))
    if matches_user:
        res = f"file://{matches_user[0]}"
        _icon_cache[icon_name] = res
        return res

    _icon_cache[icon_name] = ""
    return ""

def get_desktop_apps():
    desktop_files = glob.glob("/usr/share/applications/*.desktop") + glob.glob(os.path.expanduser("~/.local/share/applications/*.desktop"))
    app_map = {}
    for p in desktop_files:
        fn = os.path.basename(p)
        name = None
        exec_cmd = None
        icon = None
        nodisplay = False
        startup_wm = None
        with open(p, errors="ignore") as f:
            for line in f:
                line = line.strip()
                if line.startswith("Name=") and not name:
                    name = line.split("=", 1)[1]
                elif line.startswith("Exec=") and not exec_cmd:
                    exec_cmd = line.split("=", 1)[1]
                elif line.startswith("Icon=") and not icon:
                    icon = line.split("=", 1)[1]
                elif line.startswith("StartupWMClass=") and not startup_wm:
                    startup_wm = line.split("=", 1)[1]
                elif line == "NoDisplay=true":
                    nodisplay = True
        if not nodisplay and name and exec_cmd:
            clean_exec = exec_cmd.split("%")[0].strip()
            app_map[fn] = {
                "desktop": fn,
                "name": name,
                "icon": icon or "",
                "exec": clean_exec,
                "wmClass": startup_wm or fn.replace(".desktop", "")
            }
    return app_map

def get_clients():
    try:
        out = subprocess.check_output(["hyprctl", "clients", "-j"], timeout=1)
        return json.loads(out)
    except:
        return []

def list_recent():
    app_map = get_desktop_apps()
    clients = get_clients()

    active_by_class = {}
    for c in clients:
        if c.get("mapped"):
            cls = (c.get("initialClass") or c.get("class") or "").lower()
            if cls:
                active_by_class[cls] = {
                    "address": c.get("address", ""),
                    "title": c.get("title", ""),
                    "isFocused": c.get("focusHistoryID", 999) == 0
                }

    # Load history
    history = []
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE) as f:
                history = json.load(f)
        except:
            history = []

    # Prepend currently active windows by focusHistoryID
    mapped_clients = [c for c in clients if c.get("mapped")]
    mapped_clients.sort(key=lambda x: x.get("focusHistoryID", 999), reverse=True)
    for c in mapped_clients:
        cls = (c.get("initialClass") or c.get("class") or "").lower()
        if not cls:
            continue
        matched_fn = None
        for fn, data in app_map.items():
            if cls == data["wmClass"].lower() or cls == fn.replace(".desktop", "").lower() or cls in data["name"].lower():
                matched_fn = fn
                break
        if not matched_fn:
            synth_fn = f"{cls}.desktop"
            clean_name = (c.get("title") or cls).split("—")[0].split("-")[0].strip()
            app_map[synth_fn] = {
                "desktop": synth_fn,
                "name": clean_name if clean_name else cls.capitalize(),
                "icon": cls,
                "exec": cls,
                "wmClass": cls
            }
            matched_fn = synth_fn

        if matched_fn:
            if matched_fn in history:
                history.remove(matched_fn)
            history.insert(0, matched_fn)

    # Defaults to ensure dock is populated
    defaults = [
        "zen.desktop",
        "kitty.desktop",
        "spotify.desktop",
        "typora.desktop",
        "steam.desktop",
        "Discord.desktop",
        "org.gnome.Nautilus.desktop"
    ]
    for d in defaults:
        if d in app_map and d not in history:
            history.append(d)

    # Save top 20
    history = history[:20]
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(history, f)

    # Build result
    result = []
    for fn in history[:10]:
        if fn in app_map:
            data = app_map[fn]
            cls = data["wmClass"].lower()
            fn_base = fn.replace(".desktop", "").lower()
            open_info = None
            for act_cls, act_data in active_by_class.items():
                if act_cls == cls or act_cls == fn_base or fn_base in act_cls or act_cls in fn_base:
                    open_info = act_data
                    break
            resolved_icon = find_icon(data["icon"]) or data["icon"] or ""
            result.append({
                "desktop": fn,
                "name": data["name"],
                "icon": resolved_icon,
                "exec": data["exec"],
                "isOpen": open_info is not None,
                "address": open_info["address"] if open_info else "",
                "isFocused": open_info["isFocused"] if open_info else False
            })

    print(json.dumps(result))

def activate_app(address, desktop, exec_cmd):
    # 1. If currently open, focus window in Hyprland 0.56 lua API
    if address:
        cmd_lua = f"hl.dsp.focus({{ window = \"address:{address}\" }})"
        res = subprocess.run(["hyprctl", "dispatch", cmd_lua], capture_output=True, text=True)
        if res.returncode == 0 and "not found" not in res.stdout and "not found" not in res.stderr:
            record_recent(desktop)
            return

    # 2. Try focusing by class
    cls = desktop.replace(".desktop", "")
    cmd_class = f"hl.dsp.focus({{ window = \"class:{cls}\" }})"
    res = subprocess.run(["hyprctl", "dispatch", cmd_class], capture_output=True, text=True)
    if res.returncode == 0 and "not found" not in res.stdout and "not found" not in res.stderr:
        record_recent(desktop)
        return

    # 3. If not running, launch app
    record_recent(desktop)
    if desktop:
        subprocess.Popen(["gtk-launch", desktop], start_new_session=True)
    elif exec_cmd:
        subprocess.Popen(exec_cmd, shell=True, start_new_session=True)

def record_recent(desktop):
    if not desktop:
        return
    history = []
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE) as f:
                history = json.load(f)
        except:
            history = []
    if desktop in history:
        history.remove(desktop)
    history.insert(0, desktop)
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(history[:20], f)
    except:
        pass

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "activate":
        addr = sys.argv[2] if len(sys.argv) > 2 else ""
        desk = sys.argv[3] if len(sys.argv) > 3 else ""
        ex = sys.argv[4] if len(sys.argv) > 4 else ""
        activate_app(addr, desk, ex)
    else:
        list_recent()

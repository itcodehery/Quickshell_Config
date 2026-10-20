#!/usr/bin/env python3
import os
import sys
import glob
import json
import subprocess

def get_notifs():
    dnd = 'off'
    try:
        res = subprocess.run(
            ['quickshell', '-p', '/usr/share/omarchy/shell', 'ipc', 'call', 'notifications', 'isDnd'],
            capture_output=True, text=True, timeout=1
        )
        if res.returncode == 0 and res.stdout.strip() in ['on', 'off']:
            dnd = res.stdout.strip()
    except Exception:
        pass

    active = []
    active_files = sorted(glob.glob(os.path.expanduser('~/.local/state/omarchy/notifications/*.json')), reverse=True)
    for f in active_files:
        try:
            with open(f, 'r') as fp:
                data = json.load(fp)
                data['filePath'] = f
                data['isHistory'] = False
                active.append(data)
        except Exception:
            pass

    history = []
    history_files = sorted(glob.glob(os.path.expanduser('~/.local/state/omarchy/notifications/history/*.json')), reverse=True)
    for f in history_files[:50]:
        try:
            with open(f, 'r') as fp:
                data = json.load(fp)
                data['filePath'] = f
                data['isHistory'] = True
                history.append(data)
        except Exception:
            pass

    return {'dnd': dnd, 'active': active, 'history': history}

def dismiss_file(path):
    try:
        if os.path.isfile(path):
            os.remove(path)
    except Exception:
        pass

def clear_all():
    # Remove all active notifications
    for f in glob.glob(os.path.expanduser('~/.local/state/omarchy/notifications/*.json')):
        try:
            os.remove(f)
        except Exception:
            pass
    try:
        subprocess.run(['quickshell', '-p', '/usr/share/omarchy/shell', 'ipc', 'call', 'notifications', 'dismissAll'], timeout=1)
    except Exception:
        pass

def clear_history():
    for f in glob.glob(os.path.expanduser('~/.local/state/omarchy/notifications/history/*.json')):
        try:
            os.remove(f)
        except Exception:
            pass
    try:
        subprocess.run(['quickshell', '-p', '/usr/share/omarchy/shell', 'ipc', 'call', 'notifications', 'clear'], timeout=1)
    except Exception:
        pass

def toggle_dnd():
    try:
        subprocess.run(['quickshell', '-p', '/usr/share/omarchy/shell', 'ipc', 'call', 'notifications', 'toggleDnd'], timeout=1)
    except Exception:
        pass

if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if cmd == 'status':
        print(json.dumps(get_notifs()))
    elif cmd == 'dismiss' and len(sys.argv) > 2:
        dismiss_file(sys.argv[2])
        print(json.dumps({'status': 'ok'}))
    elif cmd == 'clear_all':
        clear_all()
        print(json.dumps({'status': 'ok'}))
    elif cmd == 'clear_history':
        clear_history()
        print(json.dumps({'status': 'ok'}))
    elif cmd == 'toggle_dnd':
        toggle_dnd()
        print(json.dumps(get_notifs()))
    else:
        print(json.dumps(get_notifs()))

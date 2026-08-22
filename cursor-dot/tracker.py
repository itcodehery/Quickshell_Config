#!/usr/bin/env python3
import socket
import os
import time
import json
import sys

def get_sock_path():
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    return f"{xdg}/hypr/{sig}/.socket.sock"

def main():
    sock_path = get_sock_path()
    notif_dir = os.path.expanduser("~/.local/state/omarchy/notifications")
    
    last_x, last_y = -1, -1
    last_notif_count = -1
    
    while True:
        try:
            if os.path.isdir(notif_dir):
                notifs = [f for f in os.listdir(notif_dir) if f.endswith('.json')]
                notif_count = len(notifs)
            else:
                notif_count = 0
        except Exception:
            notif_count = 0

        if notif_count == 0:
            if last_notif_count != 0:
                print("0 0 0", flush=True)
                last_notif_count = 0
            time.sleep(0.15)
            continue

        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            s.sendall(b"j/cursorpos")
            raw = s.recv(1024).decode()
            s.close()
            data = json.loads(raw)
            x, y = data.get("x", 0), data.get("y", 0)
            
            if x != last_x or y != last_y or notif_count != last_notif_count:
                print(f"{x} {y} {notif_count}", flush=True)
                last_x, last_y, last_notif_count = x, y, notif_count
        except Exception:
            pass

        time.sleep(0.016)

if __name__ == "__main__":
    main()

import json
import os
import time
import subprocess
from datetime import date

CACHE_FILE = os.path.expanduser("~/.cache/screentime.json")
SESSION_FILE = os.path.expanduser("~/.cache/screentime_session.txt")

def load_data():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r") as f:
                return json.load(f)
        except:
            pass
    return {}

def save_data(data):
    with open(CACHE_FILE, "w") as f:
        json.dump(data, f)

def main():
    data = load_data()
    session_start = time.time()
    
    while True:
        today = str(date.today())
        if today not in data:
            data[today] = {"total": 0, "apps": {}}
            
        try:
            out = subprocess.check_output(["hyprctl", "activewindow", "-j"]).decode()
            window = json.loads(out)
            app_class = window.get("class", "Unknown")
            if not app_class:
                app_class = "Unknown"
        except:
            app_class = "Unknown"
            
        data[today]["total"] += 2
        data[today]["apps"][app_class] = data[today]["apps"].get(app_class, 0) + 2
        
        save_data(data)
        
        # Use daily total screentime instead of process uptime
        session_time = data[today]["total"]
        with open(SESSION_FILE, "w") as f:
            f.write(str(session_time))
            
        time.sleep(2)

if __name__ == "__main__":
    main()

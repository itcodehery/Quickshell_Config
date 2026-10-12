#!/usr/bin/env python3
import sys
import json
import os
import datetime
import subprocess

def fmt_seconds(s):
    if not s or s <= 0:
        return "0m"
    h = s // 3600
    m = (s % 3600) // 60
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"

def get_screentime_info():
    cache_path = os.path.expanduser("~/.cache/screentime.json")
    session_path = os.path.expanduser("~/.cache/screentime_session.txt")

    data = {}
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r") as f:
                data = json.load(f)
        except Exception:
            pass

    session_sec = 0
    if os.path.exists(session_path):
        try:
            with open(session_path, "r") as f:
                val = f.read().strip()
                if val.isdigit():
                    session_sec = int(val)
        except Exception:
            pass

    today_date = datetime.date.today()
    today_key = today_date.isoformat()
    yesterday_key = (today_date - datetime.timedelta(days=1)).isoformat()

    today_record = data.get(today_key, {"total": 0, "apps": {}})
    yesterday_record = data.get(yesterday_key, {"total": 0, "apps": {}})

    today_total = today_record.get("total", 0)
    yesterday_total = yesterday_record.get("total", 0)

    # Trend calculation
    trend_str = "-"
    if yesterday_total > 0:
        diff = today_total - yesterday_total
        pct = round(abs(diff) / yesterday_total * 100)
        trend_str = f"+{pct}%" if diff >= 0 else f"-{pct}%"
    elif today_total > 0:
        trend_str = "+100%"

    # 7-day rolling history
    rolling_week = []
    max_day_sec = max(1, today_total)
    days_short = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    for i in range(6, -1, -1):
        d = today_date - datetime.timedelta(days=i)
        dk = d.isoformat()
        day_rec = data.get(dk, {})
        t = day_rec.get("total", 0)
        if t > max_day_sec:
            max_day_sec = t

        # Apps for this day
        d_apps = day_rec.get("apps", {})
        sorted_d_apps = sorted(d_apps.items(), key=lambda x: x[1], reverse=True)
        day_top_apps = []
        for name, secs in sorted_d_apps[:14]:
            pct = round((secs / t) * 100) if t > 0 else 0
            day_top_apps.append({
                "name": name,
                "seconds": secs,
                "formatted": fmt_seconds(secs),
                "percent": pct,
                "percent_str": f"{pct}%"
            })

        date_disp = "Today, " + d.strftime("%b %d") if dk == today_key else (
            "Yesterday, " + d.strftime("%b %d") if dk == yesterday_key else d.strftime("%A, %b %d")
        )

        rolling_week.append({
            "dateKey": dk,
            "dateFormatted": date_disp,
            "dayLabel": days_short[d.weekday() if d.weekday() < 6 else 0],
            "dayLetter": ["M", "T", "W", "T", "F", "S", "S"][d.weekday()],
            "total": t,
            "formatted": fmt_seconds(t),
            "isToday": dk == today_key,
            "apps": day_top_apps
        })

    for item in rolling_week:
        item["ratio"] = round(item["total"] / max_day_sec, 2)

    # Top Apps for today
    today_apps = rolling_week[-1]["apps"] if rolling_week else []

    # Active window
    active_app = ""
    active_title = ""
    try:
        hypr_out = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True, timeout=1.0)
        win = json.loads(hypr_out)
        active_app = win.get("class", "")
        active_title = win.get("title", "")
    except Exception:
        pass

    return {
        "today_key": today_key,
        "today_date_str": today_date.strftime("%A, %b %d"),
        "today_total": today_total,
        "today_formatted": fmt_seconds(today_total),
        "session_seconds": session_sec,
        "session_formatted": fmt_seconds(session_sec),
        "yesterday_formatted": fmt_seconds(yesterday_total),
        "trend": trend_str,
        "rollingWeek": rolling_week,
        "topApps": today_apps,
        "activeApp": active_app,
        "activeTitle": active_title
    }

def main():
    info = get_screentime_info()
    print(json.dumps(info))

if __name__ == "__main__":
    main()

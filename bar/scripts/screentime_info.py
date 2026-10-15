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

    days_short = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    days_letters = ["M", "T", "W", "T", "F", "S", "S"] # Mon..Sun (weekday 0..6)

    def process_apps(d_apps, t):
        sorted_d_apps = sorted(d_apps.items(), key=lambda x: x[1], reverse=True)
        day_top_apps = []
        for name, secs in sorted_d_apps[:50]:
            pct = round((secs / t) * 100) if t > 0 else 0
            day_top_apps.append({
                "name": name,
                "seconds": secs,
                "formatted": fmt_seconds(secs),
                "percent": pct,
                "percent_str": f"{pct}%"
            })
        return day_top_apps

    # Build allHistory: sorted newest first
    all_dates_keys = sorted(data.keys(), reverse=True)
    all_history = []
    max_history_sec = max([data[k].get("total", 0) for k in data.keys()] + [1])
    for dk in all_dates_keys:
        try:
            d = datetime.date.fromisoformat(dk)
        except Exception:
            continue
        rec = data.get(dk, {})
        t = rec.get("total", 0)
        d_apps = rec.get("apps", {})
        top_apps = process_apps(d_apps, t)
        top_app_name = top_apps[0]["name"] if top_apps else "None"
        top_app_formatted = top_apps[0]["formatted"] if top_apps else "0m"

        date_disp = "Today, " + d.strftime("%b %d") if dk == today_key else (
            "Yesterday, " + d.strftime("%b %d") if dk == yesterday_key else d.strftime("%a, %b %d")
        )

        all_history.append({
            "dateKey": dk,
            "dateFormatted": date_disp,
            "dateSubtitle": d.strftime("%B %d, %Y"),
            "dayLabel": days_short[d.weekday()],
            "dayLetter": days_letters[d.weekday()],
            "total": t,
            "formatted": fmt_seconds(t),
            "ratio": round(t / max_history_sec, 2),
            "isToday": dk == today_key,
            "isYesterday": dk == yesterday_key,
            "topAppName": top_app_name,
            "topAppFormatted": top_app_formatted,
            "apps": top_apps
        })

    # Build Calendar Weeks (Image 2 design: Monday to Sunday per week)
    today_monday = today_date - datetime.timedelta(days=today_date.weekday())
    parsed_dates = [datetime.date.fromisoformat(k) for k in data.keys() if k]
    earliest = min(parsed_dates) if parsed_dates else today_date
    earliest_monday = earliest - datetime.timedelta(days=earliest.weekday())

    num_weeks = max(1, (today_monday - earliest_monday).days // 7 + 1)
    weeks = []

    for w in range(num_weeks):
        mon = today_monday - datetime.timedelta(weeks=w)
        sun = mon + datetime.timedelta(days=6)
        week_days = []
        week_total = 0
        active_days_count = 0
        week_max_sec = 1

        for i in range(7):
            d = mon + datetime.timedelta(days=i)
            dk = d.isoformat()
            rec = data.get(dk, {})
            t = rec.get("total", 0)
            is_today = (dk == today_key)
            is_yesterday = (dk == yesterday_key)
            is_future = (d > today_date)

            if t > week_max_sec:
                week_max_sec = t
            week_total += t
            if t > 0:
                active_days_count += 1

            d_apps = rec.get("apps", {})
            top_apps = process_apps(d_apps, t)

            date_disp = "Today, " + d.strftime("%b %d") if is_today else (
                "Yesterday, " + d.strftime("%b %d") if is_yesterday else d.strftime("%a, %b %d")
            )

            week_days.append({
                "dayIndex": i,
                "dateKey": dk,
                "dateFormatted": date_disp,
                "dateShort": d.strftime("%a %d"),
                "dayLetter": days_letters[i],
                "dayLabel": days_short[i],
                "total": t,
                "formatted": fmt_seconds(t),
                "isToday": is_today,
                "isYesterday": is_yesterday,
                "isFuture": is_future,
                "hasData": t > 0,
                "apps": top_apps
            })

        # Calculate peak day in this week
        peak_idx = -1
        max_t = 0
        for idx, day in enumerate(week_days):
            if day["total"] > max_t:
                max_t = day["total"]
                peak_idx = idx

        # Set ratio and isHighlight / isPeak
        for idx, day in enumerate(week_days):
            day["ratio"] = round(day["total"] / week_max_sec, 2) if week_max_sec > 0 else 0.05
            day["isPeak"] = (idx == peak_idx and max_t > 0)
            day["isHighlight"] = day["isPeak"]

        avg_sec = week_total // max(1, active_days_count) if active_days_count > 0 else 0
        week_label = "This week" if w == 0 else (
            "Last week" if w == 1 else f"{mon.strftime('%b %d')} – {sun.strftime('%b %d')}"
        )

        weeks.append({
            "weekIndex": w,
            "weekLabel": week_label,
            "dateRangeStr": f"{mon.strftime('%b %d')} – {sun.strftime('%b %d, %Y')}",
            "totalSec": week_total,
            "totalFormatted": fmt_seconds(week_total),
            "avgPerDaySec": avg_sec,
            "avgPerDayFormatted": fmt_seconds(avg_sec),
            "activeDaysCount": active_days_count,
            "peakDayIndex": peak_idx,
            "goalSummary": f"Logged on {active_days_count} of 7 days. Total {fmt_seconds(week_total)}.",
            "days": week_days
        })

    # Rolling 7-day week for legacy compatibility
    rolling_week = []
    max_day_sec = max(1, today_total)
    for i in range(6, -1, -1):
        d = today_date - datetime.timedelta(days=i)
        dk = d.isoformat()
        day_rec = data.get(dk, {})
        t = day_rec.get("total", 0)
        if t > max_day_sec:
            max_day_sec = t
        d_apps = day_rec.get("apps", {})
        day_top_apps = process_apps(d_apps, t)
        date_disp = "Today, " + d.strftime("%b %d") if dk == today_key else (
            "Yesterday, " + d.strftime("%b %d") if dk == yesterday_key else d.strftime("%A, %b %d")
        )
        rolling_week.append({
            "dateKey": dk,
            "dateFormatted": date_disp,
            "dayLabel": days_short[d.weekday()],
            "dayLetter": days_letters[d.weekday()],
            "total": t,
            "formatted": fmt_seconds(t),
            "isToday": dk == today_key,
            "apps": day_top_apps
        })
    for item in rolling_week:
        item["ratio"] = round(item["total"] / max_day_sec, 2)

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
        "weeks": weeks,
        "allHistory": all_history,
        "rollingWeek": rolling_week,
        "topApps": rolling_week[-1]["apps"] if rolling_week else [],
        "activeApp": active_app,
        "activeTitle": active_title
    }

def main():
    info = get_screentime_info()
    print(json.dumps(info))

if __name__ == "__main__":
    main()

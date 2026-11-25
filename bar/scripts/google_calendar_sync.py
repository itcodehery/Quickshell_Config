#!/usr/bin/env python3
"""Read-only Google Calendar & Google Tasks sync helper for Quickshell.

Uses only the Python standard library (OAuth 2.0 Desktop App flow + REST).
Reads credentials from:
  ~/.config/quickshell/google_calendar_credentials.json
  (fallback: ~/.local/state/quickshell_google_credentials.json)
Stores OAuth tokens in:
  ~/.local/state/quickshell_google_calendar_token.json
Writes cached agenda by date (YYYY-MM-DD) to:
  ~/.local/state/quickshell_google_calendar.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import http.server
import json
import os
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from typing import Any

HOME = os.path.expanduser("~")
CONFIG_DIR = os.path.join(HOME, ".config", "quickshell")
STATE_DIR = os.path.join(HOME, ".local", "state")

CREDENTIAL_PATHS = [
    os.path.join(CONFIG_DIR, "google_calendar_credentials.json"),
    os.path.join(STATE_DIR, "quickshell_google_credentials.json"),
]
TOKEN_PATH = os.path.join(STATE_DIR, "quickshell_google_calendar_token.json")
CACHE_PATH = os.path.join(STATE_DIR, "quickshell_google_calendar.json")
BOOT_NOTIF_MARKER = "/tmp/quickshell_calendar_boot_notified"

SCOPES = [
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/tasks.readonly",
]

AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_URL = "https://oauth2.googleapis.com/token"
CALENDAR_BASE = "https://www.googleapis.com/calendar/v3"
TASKS_BASE = "https://tasks.googleapis.com/tasks/v1"


def ensure_dirs() -> None:
    os.makedirs(CONFIG_DIR, exist_ok=True)
    os.makedirs(STATE_DIR, exist_ok=True)


def write_cache(payload: dict[str, Any]) -> None:
    ensure_dirs()
    tmp_path = CACHE_PATH + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    os.replace(tmp_path, CACHE_PATH)


def find_credentials() -> dict[str, Any] | None:
    for path in CREDENTIAL_PATHS:
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            if "installed" in data:
                return data["installed"]
            if "web" in data:
                return data["web"]
            if "client_id" in data:
                return data
    return None


def load_token() -> dict[str, Any] | None:
    if not os.path.isfile(TOKEN_PATH):
        return None
    try:
        with open(TOKEN_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def save_token(token_data: dict[str, Any]) -> None:
    ensure_dirs()
    tmp_path = TOKEN_PATH + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(token_data, f, ensure_ascii=False, indent=2)
    os.chmod(tmp_path, 0o600)
    os.replace(tmp_path, TOKEN_PATH)


def http_post_form(url: str, params: dict[str, str]) -> dict[str, Any]:
    body = urllib.parse.urlencode(params).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def http_get_json(url: str, access_token: str) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        headers={"Authorization": f"Bearer {access_token}"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def run_oauth_flow(creds: dict[str, Any]) -> dict[str, Any]:
    auth_result: dict[str, Any] = {}
    done_event = threading.Event()

    class CallbackHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            qs = urllib.parse.parse_qs(parsed.query)
            if "code" in qs:
                auth_result["code"] = qs["code"][0]
                msg = b"<html><body style='font-family:sans-serif;padding:24px'><h2>Quickshell Calendar connected!</h2><p>You can close this tab and return to your desktop.</p></body></html>"
                self.send_response(200)
            else:
                auth_result["error"] = qs.get("error", ["unknown_error"])[0]
                msg = b"<html><body style='font-family:sans-serif;padding:24px'><h2>Authorization failed</h2><p>Please check Quickshell logs and try again.</p></body></html>"
                self.send_response(400)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            done_event.set()

        def log_message(self, format: str, *args: Any) -> None:
            return

    server = http.server.HTTPServer(("127.0.0.1", 0), CallbackHandler)
    port = server.server_address[1]
    redirect_uri = f"http://127.0.0.1:{port}"

    params = {
        "client_id": creds["client_id"],
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": " ".join(SCOPES),
        "access_type": "offline",
        "prompt": "consent",
    }
    url = f"{AUTH_URL}?{urllib.parse.urlencode(params)}"

    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    print(f"Opening browser for Google authorization:\n{url}", flush=True)
    webbrowser.open(url)

    if not done_event.wait(timeout=300):
        server.shutdown()
        raise RuntimeError("Timed out waiting for Google OAuth callback (300s).")

    server.shutdown()
    server.server_close()

    if "error" in auth_result:
        raise RuntimeError(f"OAuth error: {auth_result['error']}")

    token_resp = http_post_form(
        TOKEN_URL,
        {
            "code": auth_result["code"],
            "client_id": creds["client_id"],
            "client_secret": creds["client_secret"],
            "redirect_uri": redirect_uri,
            "grant_type": "authorization_code",
        },
    )
    token_resp["expires_at"] = time.time() + int(token_resp.get("expires_in", 3600)) - 60
    save_token(token_resp)
    return token_resp


def get_valid_access_token(creds: dict[str, Any], token: dict[str, Any]) -> str:
    now = time.time()
    if token.get("access_token") and token.get("expires_at", 0) > now:
        return token["access_token"]

    refresh_token = token.get("refresh_token")
    if not refresh_token:
        raise RuntimeError("Missing refresh_token; re-run with --auth.")

    refreshed = http_post_form(
        TOKEN_URL,
        {
            "client_id": creds["client_id"],
            "client_secret": creds["client_secret"],
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        },
    )
    token["access_token"] = refreshed["access_token"]
    token["expires_at"] = time.time() + int(refreshed.get("expires_in", 3600)) - 60
    if "refresh_token" in refreshed:
        token["refresh_token"] = refreshed["refresh_token"]
    save_token(token)
    return token["access_token"]


def classify_event(event: dict[str, Any], cal: dict[str, Any]) -> str:
    ev_type = event.get("eventType", "default")
    cal_id = cal.get("id", "").lower()
    cal_summary = cal.get("summary", "").lower()

    if ev_type == "birthday" or "contacts@group.v.calendar.google.com" in cal_id or "birthday" in cal_summary:
        return "birthday"
    if ev_type == "outOfOffice":
        return "ooo"
    if ev_type == "focusTime":
        return "focus"
    if "holiday@group.v.calendar.google.com" in cal_id:
        return "holiday"
    return "event"


def parse_event_dates(event: dict[str, Any]) -> tuple[list[str], bool, str, str]:
    start = event.get("start", {})
    end = event.get("end", {})

    if "date" in start:
        start_d = dt.date.fromisoformat(start["date"])
        end_d = dt.date.fromisoformat(end.get("date", start["date"]))
        # Google all-day end.date is exclusive
        if end_d > start_d:
            end_d = end_d - dt.timedelta(days=1)
        days: list[str] = []
        cur = start_d
        # Cap expansion at 31 days to avoid huge spans cluttering the cache
        while cur <= end_d and len(days) < 31:
            days.append(cur.isoformat())
            cur += dt.timedelta(days=1)
        return days, True, "", ""

    start_dt_str = start.get("dateTime", "")
    end_dt_str = end.get("dateTime", "")
    if not start_dt_str:
        return [], True, "", ""

    start_dt = dt.datetime.fromisoformat(start_dt_str.replace("Z", "+00:00")).astimezone()
    end_dt = (
        dt.datetime.fromisoformat(end_dt_str.replace("Z", "+00:00")).astimezone()
        if end_dt_str
        else start_dt
    )

    start_time = start_dt.strftime("%H:%M")
    end_time = end_dt.strftime("%H:%M")

    days = []
    cur = start_dt.date()
    end_date = end_dt.date()
    # If an event ends exactly at 00:00 the next day, don't spill onto the next day
    if end_date > cur and end_dt.hour == 0 and end_dt.minute == 0 and end_dt.second == 0:
        end_date = end_date - dt.timedelta(days=1)

    while cur <= end_date and len(days) < 31:
        days.append(cur.isoformat())
        cur += dt.timedelta(days=1)

    return days, False, start_time, end_time


def fetch_all_calendar_events(access_token: str) -> dict[str, list[dict[str, Any]]]:
    by_date: dict[str, list[dict[str, Any]]] = {}

    now_local = dt.datetime.now().astimezone()
    time_min = (now_local - dt.timedelta(days=60)).isoformat()
    time_max = (now_local + dt.timedelta(days=120)).isoformat()

    cal_list_url = f"{CALENDAR_BASE}/users/me/calendarList?maxResults=250"
    cal_list = http_get_json(cal_list_url, access_token)
    calendars = cal_list.get("items", [])

    for cal in calendars:
        if cal.get("selected") is False and not cal.get("primary"):
            continue
        cal_id = cal.get("id", "")
        if not cal_id:
            continue

        cal_name = cal.get("summaryOverride") or cal.get("summary") or "Calendar"
        cal_color = cal.get("backgroundColor") or "#4285f4"
        encoded_id = urllib.parse.quote(cal_id, safe="")

        page_token = None
        while True:
            params = {
                "singleEvents": "true",
                "orderBy": "startTime",
                "timeMin": time_min,
                "timeMax": time_max,
                "maxResults": "250",
            }
            if page_token:
                params["pageToken"] = page_token
            ev_url = f"{CALENDAR_BASE}/calendars/{encoded_id}/events?{urllib.parse.urlencode(params)}"
            try:
                ev_data = http_get_json(ev_url, access_token)
            except urllib.error.HTTPError:
                break

            for ev in ev_data.get("items", []):
                if ev.get("status") == "cancelled":
                    continue
                days, all_day, start_time, end_time = parse_event_dates(ev)
                if not days:
                    continue
                kind = classify_event(ev, cal)
                title = ev.get("summary") or "(No title)"
                entry = {
                    "id": f"gcal_{ev.get('id', '')}",
                    "kind": kind,
                    "title": title,
                    "calendarName": cal_name,
                    "color": cal_color,
                    "allDay": all_day,
                    "startTime": start_time,
                    "endTime": end_time,
                    "location": ev.get("location", ""),
                    "done": False,
                    "htmlLink": ev.get("htmlLink", ""),
                }
                for d_key in days:
                    by_date.setdefault(d_key, []).append(entry)

            page_token = ev_data.get("nextPageToken")
            if not page_token:
                break

    return by_date


def fetch_google_tasks(access_token: str, by_date: dict[str, list[dict[str, Any]]]) -> None:
    try:
        lists_resp = http_get_json(f"{TASKS_BASE}/users/@me/lists?maxResults=100", access_token)
    except urllib.error.HTTPError:
        # Tasks API may not be enabled in the Cloud project; skip gracefully
        return

    for task_list in lists_resp.get("items", []):
        list_id = task_list.get("id")
        list_title = task_list.get("title") or "Tasks"
        if not list_id:
            continue

        page_token = None
        while True:
            params = {
                "showCompleted": "true",
                "showHidden": "true",
                "maxResults": "100",
            }
            if page_token:
                params["pageToken"] = page_token
            url = f"{TASKS_BASE}/lists/{urllib.parse.quote(list_id, safe='')}/tasks?{urllib.parse.urlencode(params)}"
            try:
                tasks_resp = http_get_json(url, access_token)
            except urllib.error.HTTPError:
                break

            for task in tasks_resp.get("items", []):
                if task.get("deleted") or task.get("hidden"):
                    continue
                due_str = task.get("due")
                if not due_str:
                    continue
                due_date = due_str[:10]
                title = (task.get("title") or "").strip()
                if not title:
                    continue
                by_date.setdefault(due_date, []).append(
                    {
                        "id": f"gtask_{task.get('id', '')}",
                        "kind": "task",
                        "title": title,
                        "calendarName": list_title,
                        "color": "#34a853",
                        "allDay": True,
                        "startTime": "",
                        "endTime": "",
                        "location": "",
                        "done": task.get("status") == "completed",
                        "htmlLink": task.get("webViewLink", ""),
                    }
                )

            page_token = tasks_resp.get("nextPageToken")
            if not page_token:
                break


def sort_day_entries(by_date: dict[str, list[dict[str, Any]]]) -> None:
    kind_order = {
        "birthday": 0,
        "holiday": 1,
        "ooo": 2,
        "event": 3,
        "focus": 4,
        "task": 5,
    }
    for d_key, items in by_date.items():
        items.sort(
            key=lambda x: (
                kind_order.get(x.get("kind", "event"), 9),
                0 if x.get("allDay") else 1,
                x.get("startTime", ""),
                x.get("title", "").lower(),
            )
        )


def sync() -> int:
    creds = find_credentials()
    if not creds:
        write_cache(
            {
                "status": "needs_credentials",
                "error": f"Place OAuth credentials JSON at {CREDENTIAL_PATHS[0]}",
                "lastSync": dt.datetime.now().astimezone().isoformat(),
                "byDate": {},
            }
        )
        return 0

    token = load_token()
    if not token:
        write_cache(
            {
                "status": "needs_auth",
                "error": "Google account not connected yet.",
                "lastSync": dt.datetime.now().astimezone().isoformat(),
                "byDate": {},
            }
        )
        return 0

    try:
        access_token = get_valid_access_token(creds, token)
        by_date = fetch_all_calendar_events(access_token)
        fetch_google_tasks(access_token, by_date)
        sort_day_entries(by_date)
        write_cache(
            {
                "status": "ok",
                "error": "",
                "lastSync": dt.datetime.now().astimezone().isoformat(),
                "byDate": by_date,
            }
        )
        return 0
    except Exception as exc:
        # Preserve existing cached events if offline / transient error
        existing_by_date: dict[str, Any] = {}
        if os.path.isfile(CACHE_PATH):
            try:
                with open(CACHE_PATH, "r", encoding="utf-8") as f:
                    existing_by_date = json.load(f).get("byDate", {})
            except Exception:
                existing_by_date = {}
        write_cache(
            {
                "status": "error",
                "error": str(exc),
                "lastSync": dt.datetime.now().astimezone().isoformat(),
                "byDate": existing_by_date,
            }
        )
        return 1


def notify_today(force: bool = False) -> int:
    if not force and os.path.isfile(BOOT_NOTIF_MARKER):
        return 0

    # Try syncing fresh data first; if offline, cached events still work
    sync()

    if not os.path.isfile(CACHE_PATH):
        return 0

    try:
        with open(CACHE_PATH, "r", encoding="utf-8") as f:
            cache = json.load(f)
    except Exception:
        return 1

    today_key = dt.date.today().isoformat()
    raw_items = cache.get("byDate", {}).get(today_key, [])

    seen_ids: set[str] = set()
    seen_sigs: set[tuple[str, str, str]] = set()
    unique_items: list[dict[str, Any]] = []

    for item in raw_items:
        kind = item.get("kind", "event")
        if kind == "task" and item.get("done"):
            continue
        item_id = str(item.get("id") or "")
        title = (item.get("title") or "").strip()
        start_time = str(item.get("startTime") or "")
        sig = (kind, title.lower(), start_time)
        if (item_id and item_id in seen_ids) or sig in seen_sigs:
            continue
        if item_id:
            seen_ids.add(item_id)
        seen_sigs.add(sig)
        unique_items.append(item)

    app_map = {
        "birthday": ("Birthday", "cake"),
        "task": ("Google Tasks", "task_alt"),
        "ooo": ("Out of Office", "beach_access"),
        "focus": ("Focus Time", "psychology"),
        "holiday": ("Holiday", "celebration"),
        "event": ("Google Calendar", "event"),
    }

    for idx, item in enumerate(unique_items):
        kind = item.get("kind", "event")
        app_name, icon_name = app_map.get(kind, ("Google Calendar", "event"))
        title = item.get("title") or "(No title)"

        parts: list[str] = []
        if kind == "task":
            parts.append(item.get("calendarName") or "Due today")
        elif item.get("allDay"):
            parts.append("All day")
        elif item.get("startTime"):
            s = item["startTime"]
            e = item.get("endTime")
            parts.append(f"{s} – {e}" if e else s)

        if item.get("location"):
            parts.append(item["location"])
        elif kind == "event" and item.get("calendarName"):
            parts.append(item["calendarName"])

        body = "  •  ".join(parts) if parts else "Today"

        subprocess.run(
            ["notify-send", "-a", app_name, "-i", icon_name, title, body],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if idx < len(unique_items) - 1:
            time.sleep(0.35)

    try:
        with open(BOOT_NOTIF_MARKER, "w", encoding="utf-8") as f:
            f.write(today_key)
    except Exception:
        pass

    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Google Calendar & Tasks (read-only) for Quickshell.")
    parser.add_argument("--auth", action="store_true", help="Run interactive OAuth 2.0 browser login.")
    parser.add_argument("--sync", action="store_true", help="Sync events and tasks to local cache.")
    parser.add_argument("--notify-today", action="store_true", help="Send desktop notifications for today's unique events/tasks (once per boot).")
    parser.add_argument("--force", action="store_true", help="Force --notify-today even if already notified this boot.")
    args = parser.parse_args()

    if args.notify_today:
        return notify_today(force=args.force)

    if args.auth:
        creds = find_credentials()
        if not creds:
            print(f"Error: OAuth credentials not found at {CREDENTIAL_PATHS[0]}", file=sys.stderr)
            write_cache(
                {
                    "status": "needs_credentials",
                    "error": f"Place OAuth credentials JSON at {CREDENTIAL_PATHS[0]}",
                    "lastSync": dt.datetime.now().astimezone().isoformat(),
                    "byDate": {},
                }
            )
            return 1
        run_oauth_flow(creds)
        return sync()

    return sync()


if __name__ == "__main__":
    sys.exit(main())

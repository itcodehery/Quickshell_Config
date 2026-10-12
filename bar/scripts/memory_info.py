#!/usr/bin/env python3
import sys
import json
import subprocess
import os

def get_memory_info():
    meminfo = {}
    try:
        with open("/proc/meminfo", "r") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) == 2:
                    k = parts[0].strip()
                    val_str = parts[1].strip().split()[0]
                    meminfo[k] = int(val_str) * 1024  # convert kB to bytes
    except Exception:
        pass

    total = meminfo.get("MemTotal", 1)
    free = meminfo.get("MemFree", 0)
    avail = meminfo.get("MemAvailable", free)
    buffers = meminfo.get("Buffers", 0)
    cached = meminfo.get("Cached", 0) + meminfo.get("SReclaimable", 0)
    shmem = meminfo.get("Shmem", 0)
    used = max(0, total - avail)
    active = meminfo.get("Active", 0)
    inactive = meminfo.get("Inactive", 0)

    swap_total = meminfo.get("SwapTotal", 0)
    swap_free = meminfo.get("SwapFree", 0)
    swap_used = max(0, swap_total - swap_free)

    pct = round((used / total) * 100) if total > 0 else 0
    swap_pct = round((swap_used / swap_total) * 100) if swap_total > 0 else 0

    gib = 1024 ** 3
    mib = 1024 ** 2

    # Top memory processes
    procs = []
    try:
        # ps -eo pid,pmem,rss,comm --sort=-rss
        out = subprocess.check_output(
            ["ps", "-eo", "pid,pmem,rss,comm", "--sort=-rss"],
            text=True,
            timeout=2.0
        )
        lines = out.strip().split("\n")
        # Header is line 0
        for line in lines[1:13]:
            parts = line.strip().split(None, 3)
            if len(parts) >= 4:
                pid = parts[0]
                pmem = parts[1]
                rss_kb = int(parts[2])
                name = parts[3].strip()
                rss_mb = round(rss_kb / 1024, 1)
                
                # Human-readable format
                if rss_mb >= 1024:
                    rss_str = f"{round(rss_mb / 1024, 2)} GB"
                else:
                    rss_str = f"{int(rss_mb)} MB"

                procs.append({
                    "pid": pid,
                    "name": name,
                    "pmem": f"{pmem}%",
                    "pmem_val": float(pmem) if pmem.replace('.', '', 1).isdigit() else 0.0,
                    "rss_mb": rss_mb,
                    "rss_human": rss_str
                })
    except Exception:
        pass

    return {
        "percent": pct,
        "used_bytes": used,
        "total_bytes": total,
        "free_bytes": free,
        "avail_bytes": avail,
        "cached_bytes": cached,
        "buffers_bytes": buffers,
        "shmem_bytes": shmem,
        "active_bytes": active,
        "inactive_bytes": inactive,
        "used_gib": round(used / gib, 2),
        "total_gib": round(total / gib, 1),
        "free_gib": round(free / gib, 2),
        "avail_gib": round(avail / gib, 2),
        "cached_gib": round(cached / gib, 2),
        "buffers_gib": round(buffers / gib, 2),
        "swap_percent": swap_pct,
        "swap_total_gib": round(swap_total / gib, 1),
        "swap_used_gib": round(swap_used / gib, 2),
        "swap_free_gib": round(swap_free / gib, 2),
        "topProcesses": procs
    }

def kill_process(pid):
    try:
        subprocess.run(["kill", "-15", str(pid)], check=True)
        return {"success": True, "message": f"Sent SIGTERM to {pid}"}
    except Exception as e:
        try:
            subprocess.run(["kill", "-9", str(pid)], check=True)
            return {"success": True, "message": f"Sent SIGKILL to {pid}"}
        except Exception as e2:
            return {"success": False, "error": str(e2)}

def main():
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        info = get_memory_info()
        print(json.dumps(info))
    elif sys.argv[1] == "kill" and len(sys.argv) >= 3:
        res = kill_process(sys.argv[2])
        print(json.dumps(res))
    else:
        print(json.dumps(get_memory_info()))

if __name__ == "__main__":
    main()

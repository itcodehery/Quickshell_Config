#!/bin/bash
pkill -f screentime_daemon.py
nohup python3 /home/hery/.config/quickshell/bar/variants/V2/scripts/screentime_daemon.py > /dev/null 2>&1 &

#!/usr/bin/env python3
import socket
import os
import time
import json
import math
import sys

def get_sock_path():
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig:
        sock = os.path.join(xdg, "hypr", sig, ".socket.sock")
        if os.path.exists(sock):
            return sock
    # Fallback to finding active socket in xdg/hypr
    hypr_dir = os.path.join(xdg, "hypr")
    if os.path.isdir(hypr_dir):
        candidates = []
        for entry in os.listdir(hypr_dir):
            sp = os.path.join(hypr_dir, entry, ".socket.sock")
            if os.path.exists(sp):
                candidates.append((os.path.getmtime(sp), sp))
        if candidates:
            candidates.sort(reverse=True)
            return candidates[0][1]
    return f"{xdg}/hypr/{sig or ''}/.socket.sock"

class ShakeDetector:
    """
    Detects rapid back-and-forth mouse oscillations (shaking to locate cursor).
    Similar to macOS accessibility shake-to-find algorithm:
    - Analyzes movement direction vectors and speed over time.
    - Requires high-speed direction reversals with minimum stroke distance.
    - Requires continuous shaking for at least min_shake_duration (1.2 - 1.5s)
      before triggering, suppressing normal mouse gestures and brief wiggles.
    - Smoothly decays scale back to 1.0 when shaking ceases.
    """
    def __init__(self,
                 min_speed=700.0,            # px/sec threshold (reduced false positives)
                 min_stroke_dist=25.0,       # min distance traveled before reversal counts
                 min_reversals=5,            # minimum direction reversals needed
                 min_shake_duration=1.25,    # continuous shaking required for at least 1-2s
                 max_reversal_gap=0.38,      # max time between reversals before shake streak resets
                 cooldown_sec=0.28,          # time without shake before returning to normal
                 max_scale=3.8):             # peak enlarged scale
        self.min_speed = min_speed
        self.min_stroke_dist = min_stroke_dist
        self.min_reversals = min_reversals
        self.min_shake_duration = min_shake_duration
        self.max_reversal_gap = max_reversal_gap
        self.cooldown_sec = cooldown_sec
        self.max_scale = max_scale

        self.history = []
        self.reversals = []
        self.shake_start_time = None
        self.stroke_dx = 0.0
        self.stroke_dy = 0.0
        self.last_dir = None
        self.is_shaking = False
        self.last_shake_time = 0.0

    def update(self, t, x, y):
        if not self.history:
            self.history.append((t, x, y))
            return False, 1.0

        last_t, last_x, last_y = self.history[-1]
        dt = t - last_t

        if dt > 0:
            dx = x - last_x
            dy = y - last_y
            dist = math.hypot(dx, dy)
            speed = dist / dt

            # Keep short history for speed calculation
            self.history = [(ht, hx, hy) for (ht, hx, hy) in self.history if t - ht <= 0.5]
            self.history.append((t, x, y))

            # Prune reversals older than 2.5 seconds
            self.reversals = [rt for rt in self.reversals if t - rt <= 2.5]

            # Check if previous shake streak expired due to inactivity gap
            if self.reversals and (t - self.reversals[-1] > self.max_reversal_gap):
                self.reversals.clear()
                self.shake_start_time = None

            if dist > 1.0:
                if self.last_dir is not None:
                    ldx, ldy, ldist = self.last_dir
                    dot = (dx * ldx + dy * ldy) / (dist * ldist) if (dist * ldist) > 0 else 0
                    stroke_len = math.hypot(self.stroke_dx, self.stroke_dy)

                    # Direction reversal detected (dot < -0.3 corresponds to sharp reversal > ~107 deg)
                    if dot < -0.3 and stroke_len >= self.min_stroke_dist and speed >= self.min_speed:
                        self.reversals.append(t)
                        self.stroke_dx = dx
                        self.stroke_dy = dy
                        self.last_dir = (dx, dy, dist)

                        if self.shake_start_time is None:
                            self.shake_start_time = t

                        # Check if continuous shaking has lasted >= min_shake_duration
                        shake_elapsed = t - self.shake_start_time
                        if len(self.reversals) >= self.min_reversals and shake_elapsed >= self.min_shake_duration:
                            self.is_shaking = True
                            self.last_shake_time = t
                    else:
                        self.stroke_dx += dx
                        self.stroke_dy += dy
                        if dot > 0.2:
                            self.last_dir = (self.stroke_dx, self.stroke_dy, math.hypot(self.stroke_dx, self.stroke_dy))
                        # Keep active while still moving fast during shake
                        if self.is_shaking and speed >= (self.min_speed * 0.45):
                            self.last_shake_time = t
                else:
                    self.stroke_dx += dx
                    self.stroke_dy += dy
                    stroke_len = math.hypot(self.stroke_dx, self.stroke_dy)
                    if stroke_len >= self.min_stroke_dist:
                        self.last_dir = (self.stroke_dx, self.stroke_dy, stroke_len)

        # Cooldown check
        if self.is_shaking and (t - self.last_shake_time > self.cooldown_sec):
            self.is_shaking = False
            self.shake_start_time = None
            self.reversals.clear()

        if self.is_shaking:
            rev_count = len(self.reversals)
            intensity = min(1.0, (rev_count - self.min_reversals + 1) / 4.0)
            target_scale = 3.0 + intensity * (self.max_scale - 3.0)
        else:
            target_scale = 1.0

        return self.is_shaking, target_scale

def main():
    sock_path = get_sock_path()
    notif_dir = os.path.expanduser("~/.local/state/omarchy/notifications")

    detector = ShakeDetector()

    last_x, last_y = -1, -1
    last_notif_count = -1
    last_is_shaking = 0
    last_scale = 1.0
    last_move_time = time.monotonic()
    last_notif_check = 0.0

    notif_count = 0

    while True:
        now = time.monotonic()

        # Throttled notification check every ~150ms to minimize filesystem calls
        if now - last_notif_check >= 0.15:
            last_notif_check = now
            try:
                if os.path.isdir(notif_dir):
                    notifs = [f for f in os.listdir(notif_dir) if f.endswith('.json')]
                    notif_count = len(notifs)
                else:
                    notif_count = 0
            except Exception:
                notif_count = 0

        # Query cursor position from Hyprland IPC
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
            s.sendall(b"j/cursorpos")
            raw = s.recv(1024).decode()
            s.close()
            data = json.loads(raw)
            x, y = data.get("x", 0), data.get("y", 0)
        except Exception:
            # If socket fails briefly, wait and retry
            time.sleep(0.05)
            continue

        shaking, scale = detector.update(now, x, y)
        is_shaking_int = 1 if shaking else 0

        # Print output when cursor moved, notifications changed, or shake state changed
        if (x != last_x or y != last_y or
            notif_count != last_notif_count or
            is_shaking_int != last_is_shaking or
            (shaking and abs(scale - last_scale) > 0.05)):

            print(f"{x} {y} {notif_count} {is_shaking_int} {scale:.2f}", flush=True)
            last_x, last_y = x, y
            last_notif_count = notif_count
            last_is_shaking = is_shaking_int
            last_scale = scale
            last_move_time = now

        # Dynamic sleep: 10ms when moving/shaking (100Hz responsiveness); 25ms when idle
        if (now - last_move_time) < 0.20 or shaking:
            time.sleep(0.010)
        else:
            time.sleep(0.025)

if __name__ == "__main__":
    main()

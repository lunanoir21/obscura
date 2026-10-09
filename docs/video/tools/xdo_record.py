#!/usr/bin/env python3
"""Record a scripted mouse session on a PRIVATE X display and write what happened when.

    xdo_record.py --display :77 --size 1280x720 --out clip.mp4 --events events.json steps.json

steps.json is a list of steps:
    ["wait", seconds]
    ["goto", x, y]                       jump (no animation)
    ["glide", x, y, seconds]             eased mouse move
    ["click"]                            left click
    ["mark", "name"]                     record the current time under that name
    ["place", "window title part", x, y] wait for the window, then move it
    ["key", "ctrl+s"]                    xdotool key

Never aim this at the user's real display: it moves that display's pointer.
"""
import argparse, json, math, os, signal, subprocess, sys, time

ap = argparse.ArgumentParser()
ap.add_argument("steps")
ap.add_argument("--display", required=True)
ap.add_argument("--size", default="1280x720")
ap.add_argument("--fps", type=int, default=30)
ap.add_argument("--out", required=True)
ap.add_argument("--events", required=True)
a = ap.parse_args()
env = dict(os.environ, DISPLAY=a.display)
if a.display in (os.environ.get("WAYLAND_DISPLAY"), ":0", ":1"):
    sys.exit("refusing to drive a display that may be the real desktop")

def xdo(*args):
    return subprocess.run(["xdotool", *map(str, args)], env=env, check=True, capture_output=True).stdout.decode()

def pointer():
    out = xdo("getmouselocation", "--shell")
    d = dict(l.split("=") for l in out.split())
    return int(d["X"]), int(d["Y"])

steps = json.load(open(a.steps))
ff = subprocess.Popen(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "x11grab", "-draw_mouse", "1", "-framerate", str(a.fps),
     "-video_size", a.size, "-i", a.display, "-c:v", "libx264", "-preset", "veryfast", "-crf", "12", "-pix_fmt", "yuv420p", a.out],
    stdin=subprocess.PIPE, env=env)
time.sleep(0.6)          # ffmpeg needs a moment before the first frame
t0 = time.time()
events = {}
now = lambda: round(time.time() - t0, 3)
ease = lambda k: k * k * (3 - 2 * k)

for st in steps:
    op = st[0]
    if op == "wait":
        time.sleep(st[1])
    elif op == "goto":
        xdo("mousemove", st[1], st[2])
    elif op == "glide":
        x0, y0 = pointer(); x1, y1, dur = st[1], st[2], st[3]
        n = max(2, int(dur * 60))
        for i in range(1, n + 1):
            k = ease(i / n)
            xdo("mousemove", round(x0 + (x1 - x0) * k), round(y0 + (y1 - y0) * k))
            time.sleep(dur / n)
    elif op == "click":
        events.setdefault("clicks", []).append(now())
        xdo("click", 1)
    elif op == "mark":
        events[st[1]] = now()
    elif op == "place":
        wid = xdo("search", "--sync", "--onlyvisible", "--name", st[1]).split()[0]
        xdo("windowmove", wid, st[2], st[3])
    elif op == "key":
        xdo("key", st[1])
    else:
        sys.exit("unknown step " + op)

events["end"] = now()
ff.stdin.write(b"q"); ff.stdin.flush()
ff.wait(timeout=30)
json.dump(events, open(a.events, "w"), indent=1)
print(json.dumps(events))

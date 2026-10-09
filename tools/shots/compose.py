#!/usr/bin/env python3
"""Trims each raw screenshot to its content on a black margin, and builds docs/cover.png.

    compose.py <dir of raw pngs> <docs dir>
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

raws, docs = sys.argv[1], sys.argv[2]
cache = os.environ["SHOTS_CACHE"]
PAD = 72  # px at 2x
THEMES = {
    "black": dict(bg=(0, 0, 0), ink=(237, 237, 237), mid=(163, 163, 163), low=(110, 110, 110), out="screenshots", cover="cover.png"),
    "white": dict(bg=(255, 255, 255), ink=(17, 17, 19), mid=(85, 85, 92), low=(138, 138, 146), out="screenshots/light", cover="cover-light.png"),
}


def trim(img, bg, pad=PAD):
    a = np.abs(np.asarray(img.convert("RGB")).astype(int) - np.array(bg)).max(axis=2)
    ys, xs = np.where(a > 14)
    box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad, img.width), min(ys.max() + pad, img.height))
    return img.crop(box)


for theme, t in THEMES.items():
    raw = os.path.join(raws, theme)
    shots = {}
    for name in sorted(os.listdir(raw)):
        if name.endswith(".png"):
            im = trim(Image.open(os.path.join(raw, name)).convert("RGB"), t["bg"])
            im.save(os.path.join(docs, t["out"], name), optimize=True)
            shots[name[:-4]] = im

    W, H = 2400, 1260
    cover = Image.new("RGB", (W, H), t["bg"])
    d = ImageDraw.Draw(cover)
    serif = ImageFont.truetype(os.path.join(cache, "instrument-serif-italic.ttf"), 188)
    sans = ImageFont.truetype(os.path.join(cache, "instrument-sans-500.ttf"), 56)
    small = ImageFont.truetype(os.path.join(cache, "instrument-sans-500.ttf"), 40)

    panel = shots["panel-control"]
    ph = H - 160
    panel = panel.resize((int(panel.width * ph / panel.height), ph), Image.LANCZOS)
    cover.paste(panel, (W - panel.width - 90, (H - ph) // 2))

    logo = Image.open(os.path.join(docs, "assets", "logo-512.png")).convert("RGBA").resize((176, 176), Image.LANCZOS)
    cover.paste(logo, (130, 150), logo)
    d.text((130, 360), "obscura", font=serif, fill=t["ink"])
    d.text((136, 590), "Recording is one quiet button.", font=sans, fill=t["mid"])
    d.text((136, 664), "OBS Studio · Quickshell · Hyprland", font=small, fill=t["low"])

    y = 760
    for key in ("bar-recording", "bar-idle"):
        im = shots[key]
        s = 0.92
        im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
        cover.paste(im, (60, y))
        y += im.height - 60
    cover.save(os.path.join(docs, t["cover"]), optimize=True)
    print(theme, "cover", cover.size)

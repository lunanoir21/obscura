#!/usr/bin/env python3
"""Trims each raw screenshot to its content on a black margin, and builds docs/cover.png.

    compose.py <dir of raw pngs> <docs dir>
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

raw, docs = sys.argv[1], sys.argv[2]
cache = os.environ["SHOTS_CACHE"]
PAD = 72  # px at 2x


def trim(img, pad=PAD):
    a = np.asarray(img.convert("RGB")).max(axis=2)
    ys, xs = np.where(a > 14)
    box = (max(xs.min() - pad, 0), max(ys.min() - pad, 0), min(xs.max() + pad, img.width), min(ys.max() + pad, img.height))
    return img.crop(box)


shots = {}
for name in sorted(os.listdir(raw)):
    if name.endswith(".png"):
        im = trim(Image.open(os.path.join(raw, name)).convert("RGB"))
        im.save(os.path.join(docs, "screenshots", name), optimize=True)
        shots[name[:-4]] = im

W, H = 2400, 1260
cover = Image.new("RGB", (W, H), (0, 0, 0))
d = ImageDraw.Draw(cover)
serif = ImageFont.truetype(os.path.join(cache, "instrument-serif-italic.ttf"), 188)
sans = ImageFont.truetype(os.path.join(cache, "instrument-sans-500.ttf"), 56)
small = ImageFont.truetype(os.path.join(cache, "instrument-sans-500.ttf"), 40)

# the panel on the right, as tall as the cover allows
panel = shots["panel-control"]
ph = H - 160
panel = panel.resize((int(panel.width * ph / panel.height), ph), Image.LANCZOS)
cover.paste(panel, (W - panel.width - 90, (H - ph) // 2))

# logo, title, line, then the pill states on the left
logo = Image.open(os.path.join(docs, "assets", "logo-512.png")).convert("RGBA").resize((176, 176), Image.LANCZOS)
cover.paste(logo, (130, 150), logo)
d.text((130, 360), "obscura", font=serif, fill=(237, 237, 237))
d.text((136, 590), "Recording is one quiet button.", font=sans, fill=(163, 163, 163))
d.text((136, 664), "OBS Studio · Quickshell · Hyprland", font=small, fill=(110, 110, 110))

y = 760
for key in ("bar-recording", "bar-idle"):
    im = shots[key]
    # the bar shots carry a Meet and a media pill; keep the left half, which is the obscura pill
    s = 0.92
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    cover.paste(im, (60, y))
    y += im.height - 60
cover.save(os.path.join(docs, "cover.png"), optimize=True)
print("cover", cover.size)

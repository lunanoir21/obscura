#!/usr/bin/env python3
"""Builds install.svg: an animated terminal that types the install steps.

    python3 gen-install-svg.py                 > install.svg
    python3 gen-install-svg.py --freeze 12.5   > frame.svg   (one still frame, for checking)

Why a generator: the SVG has to run as a plain <img> on GitHub (no script, no web
fonts), so every line's timing is baked into CSS keyframes, and each line's width is
pinned with textLength so the typing never drifts from the cursor on any monospace font.
"""
import sys

CW = 8.4          # one character, px, at 14px
LH = 24           # line height
X0 = 28           # text left
Y0 = 92           # first baseline
W = 780
BG, INK, DIM, OUT, GOOD, RED, LINE = "#0b0b0b", "#ededed", "#6e6e6e", "#a3a3a3", "#9dd6a4", "#f08a82", "#1c1c1d"
TYPE = 0.045      # seconds per typed character
FONT = 'ui-monospace, "JetBrains Mono", "SF Mono", Menlo, Consolas, "DejaVu Sans Mono", monospace'

# kind: c = typed command, o = output line, d = dim comment (appears at once)
# parts: [(text, colour)]
SCRIPT = [
    ("d", [("# 1  OBS: Tools > WebSocket Server Settings > Enable", DIM)], 0.5),
    ("c", "git clone https://github.com/lunanoir21/obscura", 0.5),
    ("o", [("Cloning into 'obscura'...", OUT)], 0.9),
    ("c", "cd obscura && cargo build --release", 0.5),
    ("o", [("   Compiling obscura-core v0.1.0", OUT)], 0.9),
    ("o", [("   Compiling obscura v0.1.0", OUT)], 1.2),
    ("o", [("    Finished `release` profile [optimized] target(s) in 14.81s", OUT)], 0.5),
    ("c", 'ln -s "$PWD/target/release/obscura" ~/.local/bin/obscura', 0.5),
    ("c", "obscura doctor", 0.6),
    ("o", [("target      ", OUT), ("127.0.0.1:4455", INK)], 0.15),
    ("o", [("password    ", OUT), ("found", INK)], 0.15),
    ("o", [("connection  ", OUT), ("ok", GOOD)], 0.15),
    ("o", [("recording   ", OUT), ("false", INK)], 0.9),
    ("c", "obscura toggle        # start", 1.6),
    ("c", "obscura toggle        # stop", 0.5),
    ("o", [('{"path":"/home/you/Videos/obscura/2026-10-09 22-20-14.mkv"}', INK)], 0.6),
]

def build():
    t = 0.6
    rows = []
    for i, (kind, body, gap) in enumerate(SCRIPT):
        y = Y0 + i * LH
        if kind == "c":
            n = len(body)
            rows.append(dict(kind=kind, y=y, text=body, n=n, t0=t, dur=n * TYPE))
            t += n * TYPE + gap
        else:
            n = sum(len(p) for p, _ in body)
            rows.append(dict(kind=kind, y=y, parts=body, n=n, t0=t, dur=0))
            t += gap
    return rows, t

def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

def main():
    freeze = None
    if "--freeze" in sys.argv:
        freeze = float(sys.argv[sys.argv.index("--freeze") + 1])
    rows, end = build()
    HOLD = 4.5
    T = end + HOLD
    H = Y0 + len(rows) * LH + 30
    css, body = [], []

    def pct(sec):
        return max(0.0, min(100.0, sec / T * 100))

    def at(row_t):  # state of this row at the frozen time
        return freeze is not None and freeze >= row_t

    for i, r in enumerate(rows):
        y, k = r["y"], f"r{i}"
        # row visibility
        if freeze is None:
            css.append(f".{k}{{animation:{k} {T:.2f}s infinite}}@keyframes {k}{{0%,{pct(r['t0']-0.001):.3f}%{{opacity:0}}{pct(r['t0']):.3f}%,{pct(T-0.5):.3f}%{{opacity:1}}100%{{opacity:0}}}}")
            style = f'class="{k}"'
        else:
            style = f'opacity="{1 if at(r["t0"]) else 0}"'
        g = [f'<g {style}>']
        if r["kind"] == "c":
            g.append(f'<text x="{X0}" y="{y}" fill="{DIM}">$</text>')
            tx = X0 + 2 * CW
            g.append(f'<text x="{tx}" y="{y}" fill="{INK}" textLength="{r["n"] * CW:.1f}" lengthAdjust="spacing" xml:space="preserve">{esc(r["text"])}</text>')
            # cover for the not-yet-typed part, shrinking left to right
            w = r["n"] * CW
            if freeze is None:
                ov = f"v{i}"
                css.append(f".{ov}{{transform-box:fill-box;transform-origin:100% 50%;animation:{ov} {T:.2f}s infinite}}@keyframes {ov}{{0%,{pct(r['t0']):.3f}%{{transform:scaleX(1);animation-timing-function:steps({r['n']},end)}}{pct(r['t0']+r['dur']):.3f}%,100%{{transform:scaleX(0)}}}}")
                g.append(f'<rect class="{ov}" x="{tx}" y="{y-15}" width="{w:.1f}" height="21" fill="{BG}"/>')
                cu = f"u{i}"
                css.append(f".{cu}{{animation:{cu} {T:.2f}s infinite}}@keyframes {cu}{{0%,{pct(r['t0']-0.001):.3f}%{{opacity:0;transform:translateX(0)}}{pct(r['t0']):.3f}%{{opacity:1;transform:translateX(0);animation-timing-function:steps({r['n']},end)}}{pct(r['t0']+r['dur']):.3f}%{{opacity:1;transform:translateX({w:.1f}px)}}{pct(r['t0']+r['dur']+0.45):.3f}%,100%{{opacity:0;transform:translateX({w:.1f}px)}}}}")
                g.append(f'<rect class="{cu}" x="{tx}" y="{y-14}" width="{CW:.1f}" height="19" fill="{INK}" opacity="0"/>')
            else:
                typed = max(0.0, min(1.0, (freeze - r["t0"]) / r["dur"])) if r["dur"] else 1.0
                shown = round(typed * r["n"])
                g.append(f'<rect x="{tx + shown*CW:.1f}" y="{y-15}" width="{(r["n"]-shown)*CW:.1f}" height="21" fill="{BG}"/>')
                if 0 < typed < 1 or (freeze is not None and abs(freeze - (r["t0"] + r["dur"])) < 0.4 and typed >= 1):
                    g.append(f'<rect x="{tx + shown*CW:.1f}" y="{y-14}" width="{CW:.1f}" height="19" fill="{INK}"/>')
        elif r["kind"] == "d":
            x = X0
            for part, col in r["parts"]:
                g.append(f'<text x="{x}" y="{y}" fill="{col}" textLength="{len(part) * CW:.1f}" lengthAdjust="spacing" xml:space="preserve">{esc(part)}</text>')
                x += len(part) * CW
        else:
            x = X0
            for part, col in r["parts"]:
                g.append(f'<text x="{x}" y="{y}" fill="{col}" textLength="{len(part) * CW:.1f}" lengthAdjust="spacing" xml:space="preserve">{esc(part)}</text>')
                x += len(part) * CW
        g.append("</g>")
        body.append("".join(g))

    # final blinking cursor on the last row's next line
    last_y = Y0 + len(rows) * LH
    if freeze is None:
        css.append(f".end{{animation:end {T:.2f}s infinite}}@keyframes end{{0%,{pct(end-0.2):.3f}%{{opacity:0}}{pct(end):.3f}%,{pct(T-0.5):.3f}%{{opacity:1}}100%{{opacity:0}}}}")
        css.append(".blink{animation:bl 1.1s steps(1) infinite}@keyframes bl{0%{opacity:1}50%{opacity:0}}")
        tail = f'<g class="end"><text x="{X0}" y="{last_y}" fill="{DIM}">$</text><rect class="blink" x="{X0 + 2*CW}" y="{last_y-14}" width="{CW:.1f}" height="19" fill="{INK}"/></g>'
    else:
        tail = f'<g opacity="{1 if freeze >= end else 0}"><text x="{X0}" y="{last_y}" fill="{DIM}">$</text></g>'

    mark = ('<g transform="translate(24 15) scale(.2)" fill="none"><circle cx="50" cy="50" r="38" stroke="#ededed" stroke-width="7"/>'
            '<polygon points="50,34 63.9,42 63.9,58 50,66 36.1,58 36.1,42" stroke="#ededed" stroke-width="7" stroke-linejoin="round"/>'
            f'<circle cx="50" cy="50" r="7" fill="{RED}"/></g>')
    reduced = "@media (prefers-reduced-motion:reduce){text,g,rect{animation:none!important}.end{opacity:1!important}}" if freeze is None else ""
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" '
           f'aria-label="Terminal: git clone, cargo build, obscura doctor, obscura toggle">'
           f'<style>text{{font:14px {FONT}}}{"".join(css)}{reduced}</style>'
           f'<rect width="{W}" height="{H}" rx="18" fill="{BG}"/><rect x=".5" y=".5" width="{W-1}" height="{H-1}" rx="17.5" fill="none" stroke="#2a2a2c"/>'
           f'<rect x="1" y="52" width="{W-2}" height="1" fill="{LINE}"/>{mark}'
           f'<text x="52" y="33" fill="{DIM}" style="font-size:13px" textLength="{len("obscura - install")*7.8:.1f}" lengthAdjust="spacing">obscura - install</text>'
           f'{"".join(body)}{tail}</svg>')
    print(svg)

main()

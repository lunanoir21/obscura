#!/bin/sh
# The one way obscura's screenshots are made.
#
# obscura's own QML is drawn with no compositor and no OBS at all (Qt's offscreen
# platform, at 2x), in a made-up world (harness/shell.qml sets every value shown), on a
# black background. Nothing on the desktop, in your config or in OBS is read or touched,
# so the pictures never show a real window title, file name or setting.
#
#   tools/shots/shots.sh            → docs/screenshots/*.png (English, black), docs/screenshots/light/ (English, white), docs/screenshots/tr/ and tr/light/ (Turkish)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cache="${XDG_CACHE_HOME:-$HOME/.cache}/obscura-shots"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

command -v qs >/dev/null 2>&1 || { echo "shots.sh: qs (Quickshell) is needed" >&2; exit 1; }
mkdir -p "$cache" "$work/out" "$repo/docs/screenshots/light" "$repo/docs/screenshots/tr/light"
[ -s "$cache/space-mono-400.ttf" ] || curl -fsSL -o "$cache/space-mono-400.ttf" \
    "https://cdn.jsdelivr.net/fontsource/fonts/space-mono@latest/latin-400-normal.ttf"

for lang in en tr; do for theme in black white; do
mkdir -p "$work/out/$lang/$theme"
(
    cd "$here/harness"
    # a private home: the module reads ~/.config/obscura, and must not read the real one
    export HOME="$work/home" XDG_CONFIG_HOME="$work/cfg" XDG_STATE_HOME="$work/state" XDG_DATA_HOME="$work/data"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_DATA_HOME"
    unset HYPRLAND_INSTANCE_SIGNATURE
    OBSCURA_BIN="$here/mock/obscura" FONT_MONO="$cache/space-mono-400.ttf" SHOTLANG="$lang" THEME="$theme" OUT="$work/out/$lang/$theme" \
        QT_QPA_PLATFORM=offscreen QT_SCALE_FACTOR=2 timeout 90 qs -p "$here/harness/shell.qml"
) >"$work/run-$lang-$theme.log" 2>&1 || true
count=$(find "$work/out/$lang/$theme" -name '*.png' | wc -l)
if [ "$count" -lt 12 ]; then
    cat "$work/run-$lang-$theme.log" >&2
    echo "shots.sh: only $count of 12 $lang/$theme shots were drawn" >&2
    exit 1
fi
done; done
for f in "instrument-serif-italic.ttf instrument-serif@latest/latin-400-italic.ttf" "instrument-sans-500.ttf instrument-sans@latest/latin-500-normal.ttf"; do
    set -- $f
    [ -s "$cache/$1" ] || curl -fsSL -o "$cache/$1" "https://cdn.jsdelivr.net/fontsource/fonts/$2"
done
python3 -c "import PIL, numpy" 2>/dev/null || { echo "shots.sh: python3 needs Pillow and numpy" >&2; exit 1; }
SHOTS_CACHE="$cache" python3 "$here/compose.py" "$work/out" "$repo/docs"
echo "wrote English and Turkish screenshots in both themes to docs/screenshots/, and the covers"

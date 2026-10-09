import QtQuick
import Quickshell
import "ui" as O

// Draws obscura's own components into PNGs, one after another, with no compositor
// and no OBS: run by shots.sh under QT_QPA_PLATFORM=offscreen. Every value the
// widget shows is set here, so the pictures contain nothing from the real desktop.
// OUT names the output directory.
ShellRoot {
    id: root

    readonly property string out: Quickshell.env("OUT")
    property int step: -1

    readonly property bool tr: Quickshell.env("SHOTLANG") === "tr"
    readonly property bool light: Quickshell.env("THEME") === "white"
    readonly property color bg: light ? "#ffffff" : "#000000"

    QtObject {
        id: pal
        property color crust: root.light ? "#e4e4e8" : "#080808"
        property color mantle: root.light ? "#f7f7f8" : "#101010"
        property color base: root.light ? "#eeeef1" : "#0e0e0e"
        property color surface0: root.light ? "#ececef" : "#1a1a1a"
        property color surface1: root.light ? "#dcdce0" : "#262626"
        property color surface2: root.light ? "#c9c9cf" : "#343434"
        property color overlay0: root.light ? "#8a8a92" : "#6e6e6e"
        property color overlay1: root.light ? "#6a6a72" : "#8c8c8c"
        property color overlay2: root.light ? "#55555c" : "#a8a8a8"
        property color subtext0: root.light ? "#4a4a50" : "#949494"
        property color subtext1: root.light ? "#38383d" : "#bdbdbd"
        property color text: root.light ? "#111113" : "#eaeaea"
        property color red: root.light ? "#d4574c" : "#f08a82"
        property color green: root.light ? "#3f8f56" : "#9dd6a4"
        property color yellow: root.light ? "#a87a14" : "#e3cd92"
    }

    FontLoader {
        source: "file://" + Quickshell.env("FONT_MONO")
    }

    // What the panel would be told by OBS.
    readonly property var infoBase: ({
            scenes: root.tr ? ["Masaüstü", "Oyun", "Kamera"] : ["Desktop", "Game", "Camera"],
            scene: root.tr ? "Masaüstü" : "Desktop",
            inputs: [{ name: root.tr ? "Masaüstü Ses" : "Desktop Audio", muted: false }, { name: "Mic/Aux", muted: false }],
            video: { fps: 60, base_w: 1920, base_h: 1080, out_w: 1920, out_h: 1080 },
            record: { dir: "/home/you/Videos/obscura", filename: "%CCYY-%MM-%DD %hh-%mm-%ss", format: "mkv", mode: "SimpleOutput", example: "2026-10-09 22-20-14.mkv", exists: false, overwrite: false },
            replay: { enabled: true, active: true, seconds: 30 },
            limits: { max_fps: 144 }
        })

    function world(state, extra) {
        const S = O.ObscuraStore;
        S.state = state;
        S.baseMs = state === "recording" || state === "paused" ? 252000 : 0;
        S.since = Date.now();
        S.tick = S.since;
        S.justSaved = false;
        S.browsing = false;
        S.info = Object.assign({}, root.infoBase, extra || {});
        const lv = {};
        lv[root.infoBase.inputs[0].name] = 0.62;
        lv["Mic/Aux"] = 0.3;
        S.levels = lv;
        S.cfg = { timer_font: "Space Mono", timer_size: 18, button_style: "circle", notify_saved: true, copy_path: false, obs_port: 0, language: root.tr ? "tr" : "en" };
    }

    readonly property var shots: [
        { name: "bar-idle", item: barShot, before: () => root.world("idle") },
        { name: "bar-recording", item: barShot, before: () => root.world("recording") },
        { name: "bar-paused", item: barShot, before: () => root.world("paused") },
        { name: "bar-saved", item: barShot, before: () => { root.world("idle"); O.ObscuraStore.justSaved = true; } },
        { name: "bar-server-off", item: barShot, before: () => root.world("disabled") },
        { name: "panel-control", item: panelShot, before: () => { root.world("recording"); O.ObscuraStore.panelTab = 0; } },
        { name: "panel-control-idle", item: panelShot, before: () => { root.world("idle"); O.ObscuraStore.panelTab = 0; } },
        { name: "panel-record", item: panelShot, before: () => { root.world("idle", { record: Object.assign({}, root.infoBase.record, { exists: true }) }); O.ObscuraStore.panelTab = 1; } },
        { name: "panel-look", item: panelShot, before: () => { root.world("idle"); O.ObscuraStore.panelTab = 2; } },
        { name: "picker-screens", item: pickerShot, before: () => { pickerCard.tab = 0; pickerCard.remember = false; } },
        { name: "picker-windows", item: pickerShot, before: () => { pickerCard.tab = 1; pickerCard.remember = true; } },
        { name: "panel-folder", item: panelShot, before: () => {
                root.world("idle");
                O.ObscuraStore.panelTab = 1;
                O.ObscuraStore.browseData = { path: "/home/you/Videos", parent: "/home/you", writable: true, dirs: ["obscura", "Screencasts", "Streams", "Tutorials", "Work"] };
                O.ObscuraStore.browsing = true;
            } }
    ]

    Timer {
        interval: 1200
        running: true
        onTriggered: next.start()
    }
    Timer {
        id: next
        interval: 300
        onTriggered: {
            root.step += 1;
            if (root.step >= root.shots.length) {
                Qt.quit();
                return;
            }
            root.shots[root.step].before();
            settle.start();
        }
    }
    Timer {
        id: settle
        interval: 2200
        onTriggered: {
            const shot = root.shots[root.step];
            pill.blink = true;   // the recording dot is caught lit, not mid-blink
            O.ObscuraStore.tick = O.ObscuraStore.since;   // and the clock stays on 04:12
            shot.item.grabToImage(result => {
                result.saveToFile(root.out + "/" + shot.name + ".png");
                console.log("saved", shot.name);
                next.start();
            });
        }
    }
    Timer {
        interval: 60000
        running: true
        onTriggered: {
            console.warn("gave up waiting");
            Qt.quit();
        }
    }

    component Ghost: Rectangle {
        property alias label: t.text
        property bool round: false
        height: 48
        width: round ? 48 : row.implicitWidth + 28
        radius: 14
        color: Qt.rgba(pal.base.r, pal.base.g, pal.base.b, 0.75)
        border.width: 1
        border.color: Qt.rgba(pal.text.r, pal.text.g, pal.text.b, 0.08)
        opacity: 0.7
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            Text {
                id: t
                visible: !round
                anchors.verticalCenter: parent.verticalCenter
                color: pal.text
                font.family: "Bricolage Grotesque"
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: round
                width: 16
                height: 16
                radius: 8
                color: pal.green
            }
        }
    }

    FloatingWindow {
        implicitWidth: 560
        implicitHeight: 140
        color: root.bg
        Rectangle {
            id: barShot
            color: root.bg
            width: 560
            height: 140
            Row {
                anchors.centerIn: parent
                spacing: 8
                O.ObscuraPill {
                    id: pill
                    pal: pal
                    u: 1
                }
                Ghost { label: "Meet  2" }
                Ghost { round: true }
            }
        }
    }

    FloatingWindow {
        implicitWidth: 480
        implicitHeight: 760
        color: root.bg
        Rectangle {
            id: panelShot
            color: root.bg
            width: 480
            height: card.height + 80
            O.ObscuraPanelCard {
                id: card
                x: 40
                y: 40
                pal: pal
                u: 1
                uiFont: "Bricolage Grotesque"
                anim: true
            }
        }
    }

    FloatingWindow {
        implicitWidth: 760
        implicitHeight: 800
        color: root.bg
        Rectangle {
            id: pickerShot
            color: root.bg
            width: 760
            height: 800
            O.ObscuraPickerCard {
                id: pickerCard
                pal: pal
                u: 1
                uiFont: "Bricolage Grotesque"
                windows: [
                    { handle: "1", class: "kitty", title: "Terminal: project" },
                    { handle: "2", class: "firefox", title: "Documentation: Mozilla Firefox" },
                    { handle: "3", class: "obsidian", title: "Notes" },
                    { handle: "4", class: "Spotify", title: "Music" },
                    { handle: "5", class: "figma-linux", title: "Design review" }
                ]
                screens: [{ name: "eDP-1", width: 1920, height: 1080 }, { name: "DP-2", width: 2560, height: 1440 }]
            }
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Runs `obscura watch` for the recording state and `obscura toggle/pause` for
// actions. The state comes only from OBS events, so the pill never shows
// "recording" before OBS says it started.
Singleton {
    id: root

    // offline, disabled, auth, idle, starting, recording, paused, stopping
    property string state: "offline"
    property real baseMs: 0
    property real since: Date.now()
    property real tick: Date.now()
    // True for a moment after a recording was saved.
    property bool justSaved: false
    property string savedPath: ""

    readonly property bool recording: state === "recording"
    readonly property bool paused: state === "paused"
    readonly property bool active: recording || paused
    readonly property real elapsedMs: baseMs + (recording ? Math.max(0, tick - since) : 0)
    readonly property string clock: {
        const total = Math.floor(elapsedMs / 1000);
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        const two = n => (n < 10 ? "0" : "") + n;
        return h > 0 ? h + ":" + two(m) + ":" + two(s) : two(m) + ":" + two(s);
    }

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string moduleDir: {
        const dir = decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, ""));
        return dir.endsWith("/") ? dir : dir + "/";
    }
    // Quickshell started by the compositor may not inherit the login PATH, so
    // the build beside this module and the usual install dirs are tried too.
    readonly property var candidates: [moduleDir + "../target/release/obscura", "obscura", homeDir + "/.local/bin/obscura", homeDir + "/.cargo/bin/obscura"]
    readonly property string resolver: 'for c in ' + candidates.map(c => "'" + c.replace(/'/g, "'\\''") + "'").join(" ")
        + '; do case $c in */*) [ -x "$c" ] || continue ;; *) command -v "$c" >/dev/null 2>&1 || continue ;; esac; exec "$c" "$@"; done; echo "obscura binary not found" >&2; exit 127'

    // `args` is an array: ["toggle"], ["set", "fps", "60"], ...
    function command(args) {
        return ["sh", "-c", root.resolver, "sh"].concat(args);
    }

    function handle(line) {
        if (!line)
            return; // heartbeat
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        root.baseMs = msg.elapsed_ms || 0;
        root.since = Date.now();
        root.tick = root.since;
        if (msg.saved) {
            root.savedPath = msg.saved;
            root.justSaved = true;
            savedTimer.restart();
        }
        root.state = msg.state;
    }

    function toggle() {
        if (state === "offline") {
            launcher.running = true;
        } else if (state === "idle" || active) {
            act(["toggle"]);
        }
    }

    function pause() {
        if (active) {
            act(["pause"]);
        }
    }

    // ---- panel data ----------------------------------------------------------
    // What `obscura info` last said: scenes, audio inputs, video, recording
    // settings, replay buffer. Empty until the panel has been opened once.
    property var info: ({})
    property string error: ""
    readonly property bool hasInfo: info.scenes !== undefined

    function refreshInfo() {
        if (infoProc.running)
            return;
        infoProc.command = command(["info"]);
        infoProc.running = true;
    }

    // Runs one obscura command, then asks for the info again. Several clicks in
    // a row queue up, so none is lost and they never overlap.
    property var queue: []
    function act(args) {
        root.queue = root.queue.concat([args]);
        pump();
    }
    function pump() {
        if (ctl.running || root.queue.length === 0)
            return;
        const next = root.queue[0];
        root.queue = root.queue.slice(1);
        ctl.command = command(next);
        ctl.running = true;
    }

    function shot() {
        act(["shot"]);
    }

    // Audio levels (0..1 per input), streamed only while the panel shows them.
    property var levels: ({})
    property bool wantMeters: false
    onWantMetersChanged: {
        if (!wantMeters)
            levels = ({});
    }

    Process {
        id: meterProc
        command: root.command(["meters"])
        running: root.wantMeters
        stdout: SplitParser {
            onRead: line => {
                if (!line)
                    return;
                try {
                    root.levels = JSON.parse(line);
                } catch (e) {
                }
            }
        }
    }

    // ---- widget settings -------------------------------------------------------
    property var cfg: ({})
    readonly property string timerFont: cfg.timer_font || "Space Mono"
    readonly property int timerSize: cfg.timer_size || 18
    readonly property string buttonStyle: cfg.button_style || "circle"

    function loadConfig() {
        cfgProc.command = command(["config", "get"]);
        cfgProc.running = true;
    }
    function setConfig(key, value) {
        const next = Object.assign({}, root.cfg);
        next[key] = value;
        root.cfg = next; // show it at once; the file follows
        act(["config", "set", key, String(value)]);
    }

    Component.onCompleted: loadConfig()

    function openFolder() {
        const p = root.savedPath;
        if (p)
            openDir(p.substring(0, p.lastIndexOf("/")));
    }
    function openDir(dir) {
        if (!dir)
            return;
        opener.command = ["xdg-open", dir];
        opener.running = true;
    }

    // True while the panel is open: state changes then refresh its data.
    property bool wantInfo: false
    onStateChanged: if (wantInfo)
        refreshInfo()

    Process {
        id: watcher
        command: root.command(["watch"])
        running: true
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        stderr: SplitParser {
            onRead: line => console.warn("obscura watch:", line)
        }
        onRunningChanged: if (!running)
            restart.start()
    }

    // Brings the watcher back if it ever stops.
    Timer {
        id: restart
        interval: 5000
        onTriggered: watcher.running = true
    }

    // Counts seconds only while a recording runs.
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.tick = Date.now()
    }

    Timer {
        id: savedTimer
        interval: 2500
        onTriggered: root.justSaved = false
    }

    Process {
        id: ctl
        stderr: StdioCollector {
            id: ctlErr
        }
        onExited: code => {
            root.error = code === 0 ? "" : ctlErr.text.trim().replace(/^obscura: /, "");
            if (root.wantInfo)
                root.refreshInfo();
            root.pump();
        }
    }

    Process {
        id: infoProc
        stdout: StdioCollector {
            id: infoOut
            onStreamFinished: {
                try {
                    root.info = JSON.parse(infoOut.text);
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: cfgProc
        stdout: StdioCollector {
            id: cfgOut
            onStreamFinished: {
                try {
                    root.cfg = JSON.parse(cfgOut.text);
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: opener
    }

    // OBS closed: open it minimised and start recording, as the pill asks.
    Process {
        id: launcher
        command: ["obs", "--minimize-to-tray", "--startrecording"]
    }
}

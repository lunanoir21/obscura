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
    // Quickshell started by the compositor may not inherit the login PATH.
    readonly property var candidates: [moduleDir + "../target/release/obscura", "obscura", homeDir + "/.local/bin/obscura", homeDir + "/.cargo/bin/obscura"]
    readonly property string resolver: 'for c in "$@"; do '
        + '  case $c in */*) [ -x "$c" ] || continue ;; *) command -v "$c" >/dev/null 2>&1 || continue ;; esac; '
        + '  exec "$c" $MODE; '
        + 'done; exit 127'

    function command(mode) {
        return ["env", "MODE=" + mode, "sh", "-c", root.resolver, "sh"].concat(root.candidates);
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
            ctl.command = command("toggle");
            ctl.running = true;
        }
    }

    function pause() {
        if (active) {
            ctl.command = command("pause");
            ctl.running = true;
        }
    }

    function openFolder() {
        const p = root.savedPath;
        if (!p)
            return;
        opener.command = ["xdg-open", p.substring(0, p.lastIndexOf("/"))];
        opener.running = true;
    }

    Process {
        id: watcher
        command: root.command("watch")
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

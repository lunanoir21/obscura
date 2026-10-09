import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// The screen-share picker. `obscura picker`, which xdg-desktop-portal-hyprland
// runs in place of its own dialog, connects to a socket here and hands over the
// open windows; this draws the choice on the focused monitor and sends the
// answer back. Nothing in this file is needed for screen sharing to work: with
// no listener, the stock dialog appears instead.
Scope {
    id: host

    property var pal: ({
            base: "#0e0e0e",
            mantle: "#101010",
            surface0: "#1a1a1a",
            surface1: "#262626",
            surface2: "#343434",
            overlay0: "#6e6e6e",
            overlay1: "#8c8c8c",
            text: "#eaeaea"
        })
    property string uiFont: "Bricolage Grotesque"
    property string monoFont: "JetBrains Mono"

    property var conn: null
    property var windows: []
    property bool remember: false
    property int tab: 0
    readonly property bool open: conn !== null

    function send(sock, obj) {
        sock.write(JSON.stringify(obj) + "\n");
        sock.flush();
    }

    function accept(sock, line) {
        if (host.conn !== null) {
            sock.connected = false; // one picker at a time; the caller falls back
            return;
        }
        let req;
        try {
            req = JSON.parse(line);
        } catch (e) {
            sock.connected = false;
            return;
        }
        host.windows = req.windows || [];
        host.tab = 0;
        host.remember = false;
        host.conn = sock;
        host.send(sock, {
            ack: true
        });
    }

    function choose(kind, value) {
        if (!host.conn)
            return;
        host.send(host.conn, {
            kind: kind,
            value: String(value),
            remember: host.remember
        });
        host.close();
    }
    function cancel() {
        if (!host.conn)
            return;
        host.send(host.conn, {
            cancel: true
        });
        host.close();
    }
    function close() {
        const c = host.conn;
        host.conn = null;
        if (c)
            c.connected = false;
    }

    // Clear a socket file left by a crash, then listen.
    Process {
        command: ["sh", "-c", 'd="$XDG_RUNTIME_DIR/obscura"; mkdir -p "$d" && rm -f "$d/picker.sock"']
        running: true
        onExited: server.active = true
    }
    SocketServer {
        id: server
        active: false
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/obscura/picker.sock"
        handler: Socket {
            id: sock
            parser: SplitParser {
                onRead: line => host.accept(sock, line)
            }
            onConnectedChanged: if (!connected && host.conn === sock)
                host.conn = null
        }
    }

    Variants {
        // No windows exist until a request arrives.
        model: host.open ? Quickshell.screens : []
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            readonly property bool focused: {
                const m = Hyprland.focusedMonitor;
                return m ? m.name === modelData.name : modelData === Quickshell.screens[0];
            }
            visible: host.open && focused
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "obscura-picker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            readonly property real u: Math.max(1, modelData.height / 1080)

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.5)
                opacity: win.visible ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: host.cancel()
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: host.cancel()

                ObscuraPickerCard {
                    pal: host.pal
                    u: win.u
                    uiFont: host.uiFont
                    monoFont: host.monoFont
                    windows: host.windows
                    screens: Quickshell.screens
                    tab: host.tab
                    remember: host.remember
                    shown: win.visible
                    onChose: (kind, value) => host.choose(kind, value)
                    onCancelled: host.cancel()
                    onTabPicked: index => host.tab = index
                    onRememberToggled: host.remember = !host.remember
                }
            }
        }
    }
}

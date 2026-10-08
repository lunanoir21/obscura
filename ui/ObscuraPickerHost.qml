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

                Rectangle {
                    id: card
                    anchors.centerIn: parent
                    width: 560 * win.u
                    height: Math.min(parent.height - 120 * win.u, body.implicitHeight + 40 * win.u)
                    radius: 22 * win.u
                    color: host.pal.mantle
                    border.width: 1
                    border.color: host.pal.surface1
                    scale: win.visible ? 1 : 0.94
                    opacity: win.visible ? 1 : 0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }
                    MouseArea {
                        anchors.fill: parent // keeps clicks on the card from closing it
                    }

                    Column {
                        id: body
                        x: 20 * win.u
                        y: 20 * win.u
                        width: parent.width - 40 * win.u
                        spacing: 16 * win.u

                        Column {
                            spacing: 4 * win.u
                            Text {
                                text: "Ne paylaşılsın?"
                                color: host.pal.text
                                font.family: host.uiFont
                                font.pixelSize: 17 * win.u
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "Bir uygulama ekranını görmek istiyor. Birini seç."
                                color: host.pal.overlay1
                                font.family: host.uiFont
                                font.pixelSize: 12.5 * win.u
                            }
                        }

                        ObscuraSeg {
                            width: parent.width
                            pal: host.pal
                            u: win.u
                            uiFont: host.uiFont
                            options: [
                                {
                                    label: "Ekranlar",
                                    value: 0
                                },
                                {
                                    label: "Pencereler (" + host.windows.length + ")",
                                    value: 1
                                }
                            ]
                            current: host.tab
                            onPicked: v => host.tab = v
                        }

                        // Screens
                        Column {
                            width: parent.width
                            spacing: 8 * win.u
                            visible: host.tab === 0
                            Repeater {
                                model: Quickshell.screens
                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 64 * win.u
                                    radius: 14 * win.u
                                    color: screenArea.containsMouse ? host.pal.surface1 : host.pal.surface0
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: 16 * win.u
                                        spacing: 14 * win.u
                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 34 * win.u
                                            height: 22 * win.u
                                            radius: 4 * win.u
                                            color: "transparent"
                                            border.width: 1.6 * win.u
                                            border.color: host.pal.overlay1
                                        }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 2 * win.u
                                            Text {
                                                text: "Tüm ekran · " + modelData.name
                                                color: host.pal.text
                                                font.family: host.uiFont
                                                font.pixelSize: 14 * win.u
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                text: modelData.width + " × " + modelData.height
                                                color: host.pal.overlay1
                                                font.family: host.monoFont
                                                font.pixelSize: 11.5 * win.u
                                            }
                                        }
                                    }
                                    MouseArea {
                                        id: screenArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: host.choose("screen", modelData.name)
                                    }
                                }
                            }
                        }

                        // Windows
                        ListView {
                            id: list
                            width: parent.width
                            height: Math.min(contentHeight, 360 * win.u)
                            visible: host.tab === 1
                            clip: true
                            spacing: 6 * win.u
                            model: host.windows
                            boundsBehavior: Flickable.StopAtBounds
                            delegate: Rectangle {
                                required property var modelData
                                width: list.width
                                height: 52 * win.u
                                radius: 14 * win.u
                                color: winArea.containsMouse ? host.pal.surface1 : host.pal.surface0
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                                Rectangle {
                                    id: badge
                                    x: 12 * win.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 30 * win.u
                                    height: width
                                    radius: 9 * win.u
                                    color: host.pal.surface2
                                    Text {
                                        anchors.centerIn: parent
                                        text: (modelData.class || "?").charAt(0).toUpperCase()
                                        color: host.pal.text
                                        font.family: host.uiFont
                                        font.pixelSize: 13 * win.u
                                        font.weight: Font.Bold
                                    }
                                }
                                Column {
                                    anchors.left: badge.right
                                    anchors.leftMargin: 12 * win.u
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14 * win.u
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2 * win.u
                                    Text {
                                        width: parent.width
                                        text: modelData.title || modelData.class
                                        elide: Text.ElideRight
                                        color: host.pal.text
                                        font.family: host.uiFont
                                        font.pixelSize: 13.5 * win.u
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        width: parent.width
                                        text: modelData.class
                                        elide: Text.ElideRight
                                        color: host.pal.overlay1
                                        font.family: host.monoFont
                                        font.pixelSize: 11 * win.u
                                    }
                                }
                                MouseArea {
                                    id: winArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: host.choose("window", modelData.handle)
                                }
                            }
                        }
                        Text {
                            visible: host.tab === 1 && host.windows.length === 0
                            text: "Açık pencere yok."
                            color: host.pal.overlay1
                            font.family: host.uiFont
                            font.pixelSize: 13 * win.u
                        }

                        Row {
                            width: parent.width
                            spacing: 12 * win.u
                            ObscuraSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                pal: host.pal
                                u: win.u
                                on: host.remember
                                onToggled: host.remember = !host.remember
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30 * win.u - 12 * win.u - 12 * win.u - 90 * win.u
                                text: "Bu seçimi hatırla (bir daha sorma)"
                                elide: Text.ElideRight
                                color: host.pal.overlay1
                                font.family: host.uiFont
                                font.pixelSize: 12.5 * win.u
                            }
                            ObscuraButton {
                                width: 90 * win.u
                                height: 36 * win.u
                                pal: host.pal
                                u: win.u
                                uiFont: host.uiFont
                                label: "İptal"
                                onClicked: host.cancel()
                            }
                        }
                    }
                }
            }
        }
    }
}

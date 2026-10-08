import QtQuick

// The recording pill for the top bar (direction A, "Nabız"): a quiet circle
// while idle that opens into a pill with a dot, the time and a stop button
// while recording. Sized and timed like the other pills on the bar:
// 14 px radius, 400 ms OutExpo width, hairline border that brightens on hover.
//
// `pal` is the bar's colour object, `u` its scale unit (barWindow.s(1)).
Item {
    id: root

    property var pal
    property real u: 1
    property string timerFont: "Space Mono"
    // Doto is a dot matrix: it needs weight and size to stay legible in a bar.
    readonly property bool dotFont: timerFont === "Doto"
    property string uiFont: "Bricolage Grotesque"

    readonly property string mode: {
        const s = ObscuraStore.state;
        if (ObscuraStore.justSaved)
            return "saved";
        if (s === "recording")
            return "rec";
        if (s === "paused")
            return "paused";
        if (s === "disabled" || s === "auth")
            return "problem";
        return "idle";
    }
    readonly property bool hovered: hh.hovered
    readonly property bool dim: ObscuraStore.state === "offline" || ObscuraStore.state === "starting" || ObscuraStore.state === "stopping"

    width: body.width
    height: 48 * u

    HoverHandler {
        id: hh
    }

    Rectangle {
        id: body
        height: 48 * root.u
        radius: 14 * root.u
        clip: true
        width: {
            switch (root.mode) {
            case "rec":
            case "paused":
                return recRow.implicitWidth + 22 * root.u;
            case "saved":
                return savedRow.implicitWidth + 28 * root.u;
            case "problem":
                return problemRow.implicitWidth + 28 * root.u;
            default:
                return 48 * root.u;
            }
        }
        color: Qt.rgba(root.pal.base.r, root.pal.base.g, root.pal.base.b, 0.75)
        border.width: 1
        border.color: Qt.rgba(root.pal.text.r, root.pal.text.g, root.pal.text.b, root.hovered ? 0.15 : 0.08)
        Behavior on width {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutExpo
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: 200
            }
        }

        // ---- idle: ring with a dot ------------------------------------------
        Item {
            anchors.fill: parent
            opacity: root.mode === "idle" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 18 * root.u
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1.6 * root.u
                border.color: root.pal.overlay1
                opacity: root.dim ? 0.45 : (root.hovered ? 1 : 0.8)
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 6 * root.u
                    height: width
                    radius: width / 2
                    color: root.hovered && !root.dim ? root.pal.red : root.pal.overlay1
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                }
            }
        }

        // ---- recording / paused ---------------------------------------------
        Item {
            anchors.fill: parent
            opacity: root.mode === "rec" || root.mode === "paused" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Row {
                id: recRow
                x: 14 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * root.u

                Item {
                    width: 12 * root.u
                    height: 12 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.centerIn: parent
                        visible: root.mode === "rec"
                        width: 9 * root.u
                        height: width
                        radius: width / 2
                        color: root.pal.red
                        SequentialAnimation on opacity {
                            running: root.mode === "rec"
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 0.35
                                duration: 600
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 1
                                duration: 600
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                    Row {
                        anchors.centerIn: parent
                        visible: root.mode === "paused"
                        spacing: 2.4 * root.u
                        Repeater {
                            model: 2
                            Rectangle {
                                width: 3 * root.u
                                height: 10 * root.u
                                radius: 1 * root.u
                                color: root.pal.yellow
                            }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ObscuraStore.clock
                    color: root.mode === "paused" ? root.pal.overlay2 : root.pal.text
                    font.family: root.timerFont
                    font.pixelSize: (root.dotFont ? 18 : 15) * root.u
                    font.weight: root.dotFont ? Font.Black : Font.Medium
                    font.letterSpacing: 0.3 * root.u
                }
                Rectangle {
                    id: stopBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * root.u
                    height: 30 * root.u
                    radius: 9 * root.u
                    color: stopArea.containsMouse ? root.pal.surface2 : root.pal.surface1
                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 10 * root.u
                        height: width
                        radius: 2 * root.u
                        color: root.pal.text
                    }
                    MouseArea {
                        id: stopArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ObscuraStore.toggle()
                    }
                }
            }
        }

        // ---- saved ----------------------------------------------------------
        Item {
            anchors.fill: parent
            opacity: root.mode === "saved" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Row {
                id: savedRow
                x: 14 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.u
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✓"
                    color: root.pal.green
                    font.pixelSize: 15 * root.u
                    font.weight: Font.Bold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Kaydedildi"
                    color: root.pal.text
                    font.family: root.uiFont
                    font.pixelSize: 14 * root.u
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ObscuraStore.openFolder()
            }
        }

        // ---- problem: server off / password ---------------------------------
        Item {
            anchors.fill: parent
            opacity: root.mode === "problem" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Row {
                id: problemRow
                x: 14 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.u
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8 * root.u
                    height: width
                    radius: width / 2
                    color: root.pal.yellow
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ObscuraStore.state === "auth" ? "Parola gerekli" : "OBS sunucusu kapalı"
                    color: root.pal.text
                    font.family: root.uiFont
                    font.pixelSize: 13 * root.u
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // One click target for idle (start) and right click anywhere (pause).
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.mode === "idle" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                ObscuraStore.pause();
            else if (root.mode === "idle")
                ObscuraStore.toggle();
        }
    }
}

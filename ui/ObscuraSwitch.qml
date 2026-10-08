import QtQuick

Rectangle {
    id: root

    property var pal
    property real u: 1
    property bool on: false
    signal toggled

    width: 30 * u
    height: 18 * u
    radius: height / 2
    color: on ? pal.text : pal.surface2
    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    Rectangle {
        y: 2 * root.u
        x: (root.on ? root.width - width - 2 : 2) * root.u
        width: 14 * root.u
        height: width
        radius: width / 2
        color: root.on ? root.pal.base : root.pal.overlay1
        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}

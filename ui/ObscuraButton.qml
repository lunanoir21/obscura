import QtQuick

Rectangle {
    id: root

    property var pal
    property real u: 1
    property string uiFont: "Bricolage Grotesque"
    property string label: ""
    property bool primary: false
    property bool dim: false
    signal clicked

    height: 40 * u
    radius: 12 * u
    color: primary ? (area.containsMouse ? pal.subtext1 : pal.text) : (area.containsMouse ? pal.surface1 : pal.surface0)
    opacity: dim ? 0.4 : 1
    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.primary ? root.pal.base : root.pal.text
        font.family: root.uiFont
        font.pixelSize: 13 * root.u
        font.weight: Font.DemiBold
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.dim
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick

// A row of choices, one selected. `options` is [{label, value}].
Rectangle {
    id: root

    property var pal
    property real u: 1
    property string uiFont: "Bricolage Grotesque"
    property var options: []
    property var current
    property bool locked: false
    signal picked(var value)

    height: 34 * u
    radius: 11 * u
    color: pal.surface0

    Row {
        anchors.fill: parent
        anchors.margins: 3 * root.u
        spacing: 2 * root.u
        Repeater {
            model: root.options
            Rectangle {
                required property var modelData
                readonly property bool on: root.current === modelData.value
                width: (root.width - 6 * root.u - (root.options.length - 1) * 2 * root.u) / root.options.length
                height: root.height - 6 * root.u
                radius: 8 * root.u
                color: on ? root.pal.surface1 : "transparent"
                opacity: root.locked ? 0.45 : 1
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: parent.on ? root.pal.text : root.pal.overlay1
                    font.family: root.uiFont
                    font.pixelSize: 12.5 * root.u
                    font.weight: Font.Medium
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !root.locked
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(modelData.value)
                }
            }
        }
    }
}

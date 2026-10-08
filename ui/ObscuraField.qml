import QtQuick

// A one-line text field that reports its value when Enter is pressed or focus
// leaves, never on every keystroke.
Rectangle {
    id: root

    property var pal
    property real u: 1
    property string monoFont: "JetBrains Mono"
    property alias text: input.text
    property bool locked: false
    signal committed(string value)

    height: 38 * u
    radius: 11 * u
    color: pal.surface0
    border.width: 1
    border.color: input.activeFocus ? pal.overlay0 : pal.surface1
    opacity: locked ? 0.45 : 1

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12 * root.u
        anchors.rightMargin: 12 * root.u
        verticalAlignment: TextInput.AlignVCenter
        color: root.pal.text
        selectionColor: root.pal.surface2
        font.family: root.monoFont
        font.pixelSize: 12.5 * root.u
        clip: true
        readOnly: root.locked
        selectByMouse: true
        onEditingFinished: root.committed(text)
    }
}

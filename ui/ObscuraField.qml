import QtQuick

// A one-line text field for a setting that lives elsewhere (`source`).
//
// What you type is kept: the field follows `source` only while you are not
// editing, so a refresh triggered by changing some other setting never wipes
// half-typed text. The value is reported when Enter is pressed, when focus
// leaves, and a moment after you stop typing.
Rectangle {
    id: root

    property var pal
    property real u: 1
    property string monoFont: "JetBrains Mono"
    property string source: ""
    property bool locked: false
    property alias text: input.text
    // Digits only, for a port.
    property bool numeric: false
    // Typed but not yet reported.
    property bool dirty: false
    signal committed(string value)

    function commit() {
        pause.stop();
        if (!dirty)
            return;
        dirty = false;
        root.committed(input.text);
        settle.restart();
    }

    height: 38 * u
    radius: 11 * u
    color: pal.surface0
    border.width: 1
    border.color: input.activeFocus ? pal.overlay0 : pal.surface1
    opacity: locked ? 0.45 : 1

    onSourceChanged: if (!dirty && !input.activeFocus)
        input.text = source
    Component.onCompleted: input.text = source

    // After a commit, whatever OBS made of it is the truth: if it refused the
    // value the field goes back to the real one.
    Timer {
        id: settle
        interval: 1500
        onTriggered: if (!root.dirty && !input.activeFocus)
            input.text = root.source
    }

    Timer {
        id: pause
        interval: 700
        onTriggered: root.commit()
    }

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
        inputMethodHints: root.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
        validator: root.numeric ? digits : null
        onTextEdited: {
            root.dirty = text !== root.source;
            pause.restart();
        }
        onEditingFinished: root.commit()
        // Leaving the field with something typed reports it.
        onActiveFocusChanged: if (!activeFocus)
            root.commit()
    }
    IntValidator {
        id: digits
        bottom: 0
        top: 65535
    }
}

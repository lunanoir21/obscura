import QtQuick

// The picker card: screens and windows to choose from, "remember", cancel.
// ObscuraPickerHost puts it on an overlay; the screenshot harness draws it alone.
Rectangle {
    id: root

    property var pal
    property real u: 1
    property string uiFont: "Bricolage Grotesque"
    property string monoFont: "JetBrains Mono"
    property var windows: []
    property var screens: []
    property int tab: 0
    property bool remember: false
    property bool shown: true
    signal chose(string kind, var value)
    signal cancelled
    signal tabPicked(int index)
    signal rememberToggled

    anchors.centerIn: parent
    width: 560 * root.u
    height: Math.min(parent.height - 120 * root.u, body.implicitHeight + 40 * root.u)
    radius: 22 * root.u
    color: root.pal.mantle
    border.width: 1
    border.color: root.pal.surface1
    scale: root.shown ? 1 : 0.94
    opacity: root.shown ? 1 : 0
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
        x: 20 * root.u
        y: 20 * root.u
        width: parent.width - 40 * root.u
        spacing: 16 * root.u

        Column {
            spacing: 4 * root.u
            Text {
                text: ObscuraStrings.t("pick.title")
                color: root.pal.text
                font.family: root.uiFont
                font.pixelSize: 17 * root.u
                font.weight: Font.DemiBold
            }
            Text {
                text: ObscuraStrings.t("pick.sub")
                color: root.pal.overlay1
                font.family: root.uiFont
                font.pixelSize: 12.5 * root.u
            }
        }

        ObscuraSeg {
            width: parent.width
            pal: root.pal
            u: root.u
            uiFont: root.uiFont
            options: [
                {
                    label: ObscuraStrings.t("pick.screens"),
                    value: 0
                },
                {
                    label: ObscuraStrings.t("pick.windows", root.windows.length),
                    value: 1
                }
            ]
            current: root.tab
            onPicked: v => root.tabPicked(v)
        }

        // Screens
        Column {
            width: parent.width
            spacing: 8 * root.u
            visible: root.tab === 0
            Repeater {
                model: root.screens
                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 64 * root.u
                    radius: 14 * root.u
                    color: screenArea.containsMouse ? root.pal.surface1 : root.pal.surface0
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 16 * root.u
                        spacing: 14 * root.u
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34 * root.u
                            height: 22 * root.u
                            radius: 4 * root.u
                            color: "transparent"
                            border.width: 1.6 * root.u
                            border.color: root.pal.overlay1
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2 * root.u
                            Text {
                                text: ObscuraStrings.t("pick.fullscreen", modelData.name)
                                color: root.pal.text
                                font.family: root.uiFont
                                font.pixelSize: 14 * root.u
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: modelData.width + " × " + modelData.height
                                color: root.pal.overlay1
                                font.family: root.monoFont
                                font.pixelSize: 11.5 * root.u
                            }
                        }
                    }
                    MouseArea {
                        id: screenArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chose("screen", modelData.name)
                    }
                }
            }
        }

        // Windows
        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 360 * root.u)
            visible: root.tab === 1
            clip: true
            spacing: 6 * root.u
            model: root.windows
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 52 * root.u
                radius: 14 * root.u
                color: winArea.containsMouse ? root.pal.surface1 : root.pal.surface0
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Rectangle {
                    id: badge
                    x: 12 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * root.u
                    height: width
                    radius: 9 * root.u
                    color: root.pal.surface2
                    Text {
                        anchors.centerIn: parent
                        text: (modelData.class || "?").charAt(0).toUpperCase()
                        color: root.pal.text
                        font.family: root.uiFont
                        font.pixelSize: 13 * root.u
                        font.weight: Font.Bold
                    }
                }
                Column {
                    anchors.left: badge.right
                    anchors.leftMargin: 12 * root.u
                    anchors.right: parent.right
                    anchors.rightMargin: 14 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.u
                    Text {
                        width: parent.width
                        text: modelData.title || modelData.class
                        elide: Text.ElideRight
                        color: root.pal.text
                        font.family: root.uiFont
                        font.pixelSize: 13.5 * root.u
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        text: modelData.class
                        elide: Text.ElideRight
                        color: root.pal.overlay1
                        font.family: root.monoFont
                        font.pixelSize: 11 * root.u
                    }
                }
                MouseArea {
                    id: winArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chose("window", modelData.handle)
                }
            }
        }
        Text {
            visible: root.tab === 1 && root.windows.length === 0
            text: ObscuraStrings.t("pick.noWindows")
            color: root.pal.overlay1
            font.family: root.uiFont
            font.pixelSize: 13 * root.u
        }

        Row {
            width: parent.width
            spacing: 12 * root.u
            ObscuraSwitch {
                anchors.verticalCenter: parent.verticalCenter
                pal: root.pal
                u: root.u
                on: root.remember
                onToggled: root.rememberToggled()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30 * root.u - 12 * root.u - 12 * root.u - 90 * root.u
                text: ObscuraStrings.t("pick.remember")
                elide: Text.ElideRight
                color: root.pal.overlay1
                font.family: root.uiFont
                font.pixelSize: 12.5 * root.u
            }
            ObscuraButton {
                width: 90 * root.u
                height: 36 * root.u
                pal: root.pal
                u: root.u
                uiFont: root.uiFont
                label: ObscuraStrings.t("btn.cancel")
                onClicked: root.cancelled()
            }
        }
    }
}

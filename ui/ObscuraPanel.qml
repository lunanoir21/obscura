import QtQuick
import Quickshell
import Quickshell.Hyprland

// The panel that opens under the pill: Kontrol (what is happening now),
// Kayıt (where and how it is saved) and Görünüm (the widget itself).
// Settings are written to OBS or obscura's config on the spot; there is no
// apply button.
Item {
    id: root

    property var pal
    property real u: 1
    property Item anchorItem
    property bool open: false
    property string uiFont: "Bricolage Grotesque"
    property string monoFont: "JetBrains Mono"
    signal closeRequested

    property bool shown: false
    property bool anim: false
    property int tab: 0

    readonly property var info: ObscuraStore.info
    readonly property var video: info.video || ({})
    readonly property var record: info.record || ({})
    readonly property var replay: info.replay || ({})
    readonly property bool active: ObscuraStore.active
    readonly property bool connected: ["idle", "starting", "recording", "paused", "stopping"].indexOf(ObscuraStore.state) >= 0

    Component.onCompleted: if (open)
        openChanged()

    onOpenChanged: {
        if (open) {
            shown = true;
            openTimer.restart();
            ObscuraStore.wantInfo = true;
            ObscuraStore.refreshInfo();
        } else {
            anim = false;
            closeTimer.restart();
            ObscuraStore.wantInfo = false;
        }
    }
    Timer {
        id: openTimer
        interval: 30
        onTriggered: root.anim = true
    }
    Timer {
        id: closeTimer
        interval: 320
        onTriggered: if (!root.open)
            root.shown = false
    }

    component Cap: Text {
        color: root.pal.overlay0
        font.family: root.monoFont
        font.pixelSize: 10 * root.u
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.4 * root.u
    }
    component Hint: Text {
        width: parent ? parent.width : implicitWidth
        wrapMode: Text.WordWrap
        color: root.pal.overlay0
        font.family: root.uiFont
        font.pixelSize: 11.5 * root.u
        lineHeight: 1.25
    }

    HyprlandFocusGrab {
        windows: [popup]
        active: root.open
        onCleared: root.closeRequested()
    }

    PopupWindow {
        id: popup
        readonly property real pad: 24 * root.u
        visible: root.shown
        color: "transparent"
        anchor.item: root.anchorItem
        anchor.rect: Qt.rect(root.anchorItem ? root.anchorItem.width + pad : 0, root.anchorItem ? root.anchorItem.height + 8 * root.u - pad : 0, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Left
        implicitWidth: card.width + 2 * pad
        implicitHeight: card.height + 2 * pad

        Rectangle {
            id: card
            x: popup.pad
            y: popup.pad + (root.anim ? 0 : -8 * root.u)
            width: 400 * root.u
            height: (root.tab === 0 ? c0.height : root.tab === 1 ? c1.height : c2.height) + tabs.y + tabs.height + 36 * root.u
            radius: 22 * root.u
            color: root.pal.mantle
            border.width: 1
            border.color: root.pal.surface1
            clip: true
            transformOrigin: Item.TopRight
            scale: root.anim ? 1 : 0.88
            opacity: root.anim ? 1 : 0
            Behavior on scale {
                NumberAnimation {
                    duration: root.anim ? 380 : 260
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: root.anim ? 380 : 260
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: root.anim ? 160 : 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutQuint
                }
            }

            // ---- tabs --------------------------------------------------------
            Row {
                id: tabs
                x: 20 * root.u
                y: 18 * root.u
                spacing: 20 * root.u
                height: 28 * root.u
                Repeater {
                    model: ["Kontrol", "Kayıt", "Görünüm"]
                    Item {
                        required property string modelData
                        required property int index
                        width: tabText.width
                        height: 28 * root.u
                        Text {
                            id: tabText
                            text: modelData
                            color: root.tab === index ? root.pal.text : root.pal.overlay0
                            font.family: root.uiFont
                            font.pixelSize: 13.5 * root.u
                            font.weight: Font.DemiBold
                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2 * root.u
                            radius: 1
                            color: root.pal.text
                            opacity: root.tab === index ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 140
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = index
                        }
                    }
                }
            }
            Cap {
                anchors.right: parent.right
                anchors.rightMargin: 20 * root.u
                y: 24 * root.u
                text: root.connected ? "OBS · bağlı" : (ObscuraStore.state === "disabled" ? "sunucu kapalı" : ObscuraStore.state === "auth" ? "parola gerekli" : "OBS kapalı")
            }

            // ---- Kontrol -----------------------------------------------------
            Column {
                id: c0
                x: 20 * root.u
                y: tabs.y + tabs.height + 16 * root.u
                width: parent.width - 40 * root.u
                spacing: 16 * root.u
                visible: root.tab === 0
                opacity: visible ? 1 : 0

                Row {
                    spacing: 10 * root.u
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9 * root.u
                        height: width
                        radius: width / 2
                        color: ObscuraStore.recording ? root.pal.red : ObscuraStore.paused ? root.pal.yellow : root.pal.overlay0
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ObscuraStore.recording ? "Kaydediliyor" : ObscuraStore.paused ? "Duraklatıldı" : root.connected ? "Hazır" : "Bağlı değil"
                        color: root.pal.text
                        font.family: root.uiFont
                        font.pixelSize: 13.5 * root.u
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    spacing: 14 * root.u
                    Text {
                        anchors.baseline: infoText.baseline
                        text: ObscuraStore.active ? ObscuraStore.clock : "00:00"
                        color: ObscuraStore.paused ? root.pal.overlay2 : root.pal.text
                        font.family: ObscuraStore.timerFont
                        font.pixelSize: Math.round(ObscuraStore.timerSize * 1.9) * root.u
                        font.weight: ObscuraStore.timerFont === "Doto" ? Font.Black : Font.Normal
                    }
                    Text {
                        id: infoText
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4 * root.u
                        text: root.video.out_h ? root.video.out_h + "p · " + root.video.fps + " fps" : ""
                        color: root.pal.overlay1
                        font.family: root.monoFont
                        font.pixelSize: 12 * root.u
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8 * root.u
                    ObscuraButton {
                        visible: !root.active
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        primary: true
                        dim: !root.connected
                        label: "Kaydı başlat"
                        onClicked: ObscuraStore.toggle()
                    }
                    ObscuraButton {
                        visible: root.active
                        width: (parent.width - 8 * root.u) / 2
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        label: ObscuraStore.paused ? "Devam" : "Duraklat"
                        onClicked: ObscuraStore.pause()
                    }
                    ObscuraButton {
                        visible: root.active
                        width: (parent.width - 8 * root.u) / 2
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        primary: true
                        label: "Durdur"
                        onClicked: ObscuraStore.toggle()
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    visible: (root.info.scenes || []).length > 1
                    Cap {
                        text: "Sahne"
                    }
                    Flow {
                        width: parent.width
                        spacing: 6 * root.u
                        Repeater {
                            model: root.info.scenes || []
                            Rectangle {
                                required property string modelData
                                readonly property bool on: root.info.scene === modelData
                                width: sceneText.width + 24 * root.u
                                height: 32 * root.u
                                radius: 10 * root.u
                                color: on ? root.pal.surface1 : root.pal.surface0
                                Text {
                                    id: sceneText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: parent.on ? root.pal.text : root.pal.overlay1
                                    font.family: root.uiFont
                                    font.pixelSize: 12.5 * root.u
                                    font.weight: Font.Medium
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ObscuraStore.act(["scene", modelData])
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4 * root.u
                    Cap {
                        text: "Ses kaynakları"
                    }
                    Repeater {
                        model: root.info.inputs || []
                        Row {
                            required property var modelData
                            height: 36 * root.u
                            spacing: 12 * root.u
                            ObscuraSwitch {
                                anchors.verticalCenter: parent.verticalCenter
                                pal: root.pal
                                u: root.u
                                on: !modelData.muted
                                onToggled: ObscuraStore.act(["mute", modelData.name])
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: modelData.muted ? root.pal.overlay1 : root.pal.text
                                font.family: root.uiFont
                                font.pixelSize: 13 * root.u
                            }
                        }
                    }
                    Hint {
                        visible: (root.info.inputs || []).length === 0
                        text: root.connected ? "OBS'te ses kaynağı yok." : "OBS bağlanınca burada görünür."
                    }
                }

                Row {
                    width: parent.width
                    spacing: 8 * root.u
                    ObscuraButton {
                        width: parent.width - 2 * (80 * root.u + 8 * root.u)
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        dim: !root.replay.active
                        label: root.replay.active ? "Son " + (root.replay.seconds || 30) + " sn'yi kaydet" : "Replay kapalı"
                        onClicked: ObscuraStore.act(["replay", "save"])
                    }
                    ObscuraButton {
                        width: 80 * root.u
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        dim: !root.connected
                        label: "Ekran"
                        onClicked: ObscuraStore.shot()
                    }
                    ObscuraButton {
                        width: 80 * root.u
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        label: "Klasör"
                        onClicked: ObscuraStore.openDir(root.record.dir)
                    }
                }
                Hint {
                    visible: ObscuraStore.error !== ""
                    text: ObscuraStore.error
                    color: root.pal.yellow
                }
            }

            // ---- Kayıt -------------------------------------------------------
            Column {
                id: c1
                x: 20 * root.u
                y: tabs.y + tabs.height + 16 * root.u
                width: parent.width - 40 * root.u
                spacing: 16 * root.u
                visible: root.tab === 1

                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Kayıt klasörü"
                    }
                    ObscuraField {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        monoFont: root.monoFont
                        text: root.record.dir || ""
                        onCommitted: v => {
                            if (v !== root.record.dir)
                                ObscuraStore.act(["set", "dir", v]);
                        }
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Dosya adı"
                    }
                    ObscuraField {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        monoFont: root.monoFont
                        text: root.record.filename || ""
                        onCommitted: v => {
                            if (v !== root.record.filename)
                                ObscuraStore.act(["set", "filename", v]);
                        }
                    }
                    Hint {
                        text: "%CCYY yıl  %MM ay  %DD gün  %hh saat  %mm dakika  %ss saniye"
                        font.family: root.monoFont
                        font.pixelSize: 10.5 * root.u
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Kare hızı"
                    }
                    ObscuraSeg {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        locked: root.active
                        options: [{label: "24", value: 24}, {label: "30", value: 30}, {label: "60", value: 60}, {label: "120", value: 120}]
                        current: root.video.fps
                        onPicked: v => ObscuraStore.act(["set", "fps", String(v)])
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Çözünürlük"
                    }
                    ObscuraSeg {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        locked: root.active
                        options: [{label: "720p", value: 720}, {label: "1080p", value: 1080}, {label: "1440p", value: 1440}, {label: "Yerel", value: -1}]
                        current: [720, 1080, 1440].indexOf(root.video.out_h) >= 0 ? root.video.out_h : (root.video.out_h === root.video.base_h ? -1 : 0)
                        onPicked: v => ObscuraStore.act(["set", "resolution", v < 0 ? "native" : String(v)])
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Biçim"
                    }
                    ObscuraSeg {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        locked: root.active
                        options: [{label: "MKV", value: "mkv"}, {label: "MP4", value: "mp4"}, {label: "MOV", value: "mov"}]
                        current: root.record.format
                        onPicked: v => ObscuraStore.act(["set", "format", v])
                    }
                    Hint {
                        text: "MKV kayıt yarıda kesilse bile dosyayı korur."
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Replay buffer"
                    }
                    Row {
                        spacing: 12 * root.u
                        height: 30 * root.u
                        ObscuraSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            pal: root.pal
                            u: root.u
                            on: root.replay.active === true
                            opacity: root.replay.enabled ? 1 : 0.4
                            onToggled: if (root.replay.enabled)
                                ObscuraStore.act(["replay", root.replay.active ? "stop" : "start"])
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.replay.enabled ? (root.replay.active ? "Açık" : "Kapalı") : "OBS ayarlarında etkin değil"
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
                        options: [{label: "15 sn", value: 15}, {label: "30 sn", value: 30}, {label: "60 sn", value: 60}, {label: "120 sn", value: 120}]
                        current: root.replay.seconds
                        onPicked: v => ObscuraStore.act(["set", "replay-seconds", String(v)])
                    }
                }
                Hint {
                    visible: root.active
                    text: "Kayıt sürerken kare hızı, çözünürlük ve biçim kilitli; klasör ve ad sonraki kayıttan geçerli olur."
                }
                Hint {
                    visible: ObscuraStore.error !== ""
                    text: ObscuraStore.error
                    color: root.pal.yellow
                }
            }

            // ---- Görünüm -----------------------------------------------------
            Column {
                id: c2
                x: 20 * root.u
                y: tabs.y + tabs.height + 16 * root.u
                width: parent.width - 40 * root.u
                spacing: 16 * root.u
                visible: root.tab === 2

                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Süre yazısı"
                    }
                    ObscuraSeg {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        options: [{label: "Space Mono", value: "Space Mono"}, {label: "Doto", value: "Doto"}]
                        current: ObscuraStore.timerFont
                        onPicked: v => ObscuraStore.setConfig("timer_font", v)
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Yazı boyutu"
                    }
                    Row {
                        width: parent.width
                        spacing: 10 * root.u
                        ObscuraButton {
                            width: 44 * root.u
                            pal: root.pal
                            u: root.u
                            uiFont: root.uiFont
                            label: "−"
                            dim: ObscuraStore.timerSize <= 10
                            onClicked: ObscuraStore.setConfig("timer_size", ObscuraStore.timerSize - 1)
                        }
                        Item {
                            width: parent.width - 2 * (44 + 10) * root.u
                            height: 40 * root.u
                            Text {
                                anchors.centerIn: parent
                                text: ObscuraStore.timerSize + " px"
                                color: root.pal.text
                                font.family: root.monoFont
                                font.pixelSize: 13 * root.u
                            }
                        }
                        ObscuraButton {
                            width: 44 * root.u
                            pal: root.pal
                            u: root.u
                            uiFont: root.uiFont
                            label: "+"
                            dim: ObscuraStore.timerSize >= 32
                            onClicked: ObscuraStore.setConfig("timer_size", ObscuraStore.timerSize + 1)
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 64 * root.u
                        radius: 14 * root.u
                        color: root.pal.base
                        border.width: 1
                        border.color: root.pal.surface1
                        Row {
                            anchors.centerIn: parent
                            spacing: 10 * root.u
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 9 * root.u
                                height: width
                                radius: width / 2
                                color: root.pal.red
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "04:12"
                                color: root.pal.text
                                font.family: ObscuraStore.timerFont
                                font.pixelSize: ObscuraStore.timerSize * root.u
                                font.weight: ObscuraStore.timerFont === "Doto" ? Font.Black : Font.Normal
                            }
                        }
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8 * root.u
                    Cap {
                        text: "Düğme biçimi"
                    }
                    ObscuraSeg {
                        width: parent.width
                        pal: root.pal
                        u: root.u
                        uiFont: root.uiFont
                        options: [{label: "Daire", value: "circle"}, {label: "Hap", value: "pill"}, {label: "Yalnız simge", value: "icon"}]
                        current: ObscuraStore.buttonStyle
                        onPicked: v => ObscuraStore.setConfig("button_style", v)
                    }
                }
            }
        }
    }
}

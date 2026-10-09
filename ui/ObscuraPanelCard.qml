import QtQuick

// The panel itself: Kontrol (what is happening now), Kayıt (where and how it is
// saved) and Görünüm (the widget itself). ObscuraPanel puts it in a popup under
// the pill; the screenshot harness draws it on its own.
Rectangle {
    id: root

    property var pal
    property real u: 1
    property string uiFont: "Bricolage Grotesque"
    property string monoFont: "JetBrains Mono"
    // The wrapper animates the card in and out; drawn alone (screenshots) it simply sits there.
    property bool anim: true
    property bool animating: false

    readonly property int tab: ObscuraStore.panelTab
    readonly property var info: ObscuraStore.info
    readonly property var video: info.video || ({})
    readonly property var record: info.record || ({})
    readonly property var replay: info.replay || ({})
    readonly property bool active: ObscuraStore.active
    // The screen's refresh rate is the ceiling: a capture cannot be smoother.
    readonly property int maxFps: (info.limits && info.limits.max_fps) || 0
    readonly property var fpsOptions: {
        const base = [24, 30, 60, 120];
        // The screen's own rate (144, 165, ...) is worth offering when it is not a listed one.
        if (maxFps > 60 && base.indexOf(maxFps) < 0)
            base.push(maxFps);
        return base.map(f => ({
                    label: String(f),
                    value: f,
                    disabled: maxFps > 0 && f > maxFps
                }));
    }
    readonly property bool connected: ["idle", "starting", "recording", "paused", "stopping"].indexOf(ObscuraStore.state) >= 0
    readonly property real chrome: tabs.y + tabs.height + 36 * u
    readonly property real maxCardHeight: Math.max(c0.height, c1.height, c2.height, browser.height) + chrome

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
    width: 400 * root.u
    height: (root.tab === 0 ? c0.height : root.tab === 1 ? (ObscuraStore.browsing ? browser.height : c1.height) : c2.height) + root.chrome
    radius: 22 * root.u
    color: root.pal.mantle
    border.width: 1
    border.color: root.pal.surface1
    clip: true
    layer.enabled: root.animating
    layer.smooth: true
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
                    onClicked: ObscuraStore.panelTab = index
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
                dim: ObscuraStore.state === "disabled" || ObscuraStore.state === "auth" || ObscuraStore.launching
                label: root.connected ? "Kaydı başlat" : ObscuraStore.launching ? "OBS açılıyor…" : ObscuraStore.state === "offline" ? "OBS'i aç" : "OBS ayarı gerekli"
                onClicked: root.connected ? ObscuraStore.toggle() : ObscuraStore.openObs()
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
                Item {
                    id: srcRow
                    required property var modelData
                    width: parent.width
                    height: 36 * root.u
                    readonly property real lvl: modelData.muted ? 0 : (ObscuraStore.levels[modelData.name] || 0)
                    Row {
                        spacing: 12 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        ObscuraSwitch {
                            anchors.verticalCenter: parent.verticalCenter
                            pal: root.pal
                            u: root.u
                            on: !srcRow.modelData.muted
                            onToggled: ObscuraStore.act(["mute", srcRow.modelData.name])
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: srcRow.modelData.name
                            color: srcRow.modelData.muted ? root.pal.overlay1 : root.pal.text
                            font.family: root.uiFont
                            font.pixelSize: 13 * root.u
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 84 * root.u
                        height: 4 * root.u
                        radius: height / 2
                        color: root.pal.surface1
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * srcRow.lvl
                            color: srcRow.lvl > 0.92 ? root.pal.yellow : root.pal.text
                            Behavior on width {
                                NumberAnimation {
                                    duration: 90
                                }
                            }
                        }
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
        visible: root.tab === 1 && !ObscuraStore.browsing

        Column {
            width: parent.width
            spacing: 8 * root.u
            Cap {
                text: "Kayıt klasörü"
            }
            Row {
                width: parent.width
                spacing: 8 * root.u
                ObscuraField {
                    width: parent.width - 76 * root.u - 8 * root.u
                    pal: root.pal
                    u: root.u
                    monoFont: root.monoFont
                    source: root.record.dir || ""
                    onCommitted: v => {
                        if (v !== root.record.dir)
                            ObscuraStore.act(["set", "dir", v]);
                    }
                }
                ObscuraButton {
                    width: 76 * root.u
                    height: 38 * root.u
                    pal: root.pal
                    u: root.u
                    uiFont: root.uiFont
                    dim: !root.connected
                    label: "Seç"
                    onClicked: ObscuraStore.openBrowser()
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
                source: root.record.filename || ""
                onCommitted: v => {
                    if (v !== root.record.filename)
                        ObscuraStore.act(["set", "filename", v]);
                }
            }
            Hint {
                visible: !!root.record.example
                text: "Sonraki dosya: " + root.record.example
                color: root.pal.overlay1
                font.family: root.monoFont
                font.pixelSize: 11 * root.u
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
            }
            Hint {
                visible: root.record.exists === true
                text: root.record.overwrite === true ? "Bu adla bir dosya zaten var ve üzerine yazılacak." : "Bu adla bir dosya zaten var; OBS yenisinin sonuna (1) ekleyerek kaydeder."
                color: root.record.overwrite === true ? root.pal.red : root.pal.yellow
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
                options: root.fpsOptions
                current: root.video.fps
                onPicked: v => ObscuraStore.act(["set", "fps", String(v)])
            }
            Hint {
                visible: root.maxFps > 0
                text: "Ekranın " + root.maxFps + " Hz; bundan yüksek kare hızı aynı kareyi tekrarlar, bu yüzden seçilemiyor."
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

    // ---- Klasör seçici -----------------------------------------------
    Item {
        id: browser
        x: 20 * root.u
        y: tabs.y + tabs.height + 16 * root.u
        width: parent.width - 40 * root.u
        height: Math.max(c1.height, 480 * root.u)
        visible: root.tab === 1 && ObscuraStore.browsing

        Row {
            id: browserHead
            width: parent.width
            height: 38 * root.u
            spacing: 8 * root.u
            ObscuraButton {
                width: 44 * root.u
                height: 38 * root.u
                pal: root.pal
                u: root.u
                uiFont: root.uiFont
                label: "↑"
                dim: !ObscuraStore.browseData.parent
                onClicked: ObscuraStore.browse(ObscuraStore.browseData.parent)
            }
            Rectangle {
                width: parent.width - 44 * root.u - 8 * root.u
                height: 38 * root.u
                radius: 11 * root.u
                color: root.pal.surface0
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12 * root.u
                    anchors.rightMargin: 12 * root.u
                    verticalAlignment: Text.AlignVCenter
                    text: ObscuraStore.browseData.path || "…"
                    elide: Text.ElideLeft
                    color: root.pal.text
                    font.family: root.monoFont
                    font.pixelSize: 12 * root.u
                }
            }
        }

        ListView {
            id: folderList
            anchors.top: browserHead.bottom
            anchors.topMargin: 10 * root.u
            anchors.bottom: browserFoot.top
            anchors.bottomMargin: 10 * root.u
            width: parent.width
            clip: true
            spacing: 4 * root.u
            boundsBehavior: Flickable.StopAtBounds
            model: ObscuraStore.browseData.dirs || []
            delegate: Rectangle {
                required property string modelData
                width: folderList.width
                height: 38 * root.u
                radius: 10 * root.u
                color: rowArea.containsMouse ? root.pal.surface1 : root.pal.surface0
                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }
                // A small folder glyph.
                Item {
                    x: 12 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * root.u
                    height: 14 * root.u
                    Rectangle {
                        width: 8 * root.u
                        height: 4 * root.u
                        radius: 1.5 * root.u
                        color: root.pal.overlay1
                    }
                    Rectangle {
                        y: 3 * root.u
                        width: parent.width
                        height: 11 * root.u
                        radius: 3 * root.u
                        color: "transparent"
                        border.width: 1.4 * root.u
                        border.color: root.pal.overlay1
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 40 * root.u
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.u
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData
                    elide: Text.ElideRight
                    color: root.pal.text
                    font.family: root.uiFont
                    font.pixelSize: 13 * root.u
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ObscuraStore.enterFolder(modelData)
                }
            }
            Text {
                visible: folderList.count === 0
                anchors.centerIn: parent
                text: ObscuraStore.browseError !== "" ? ObscuraStore.browseError : "Alt klasör yok."
                color: ObscuraStore.browseError !== "" ? root.pal.yellow : root.pal.overlay1
                font.family: root.uiFont
                font.pixelSize: 12.5 * root.u
            }
        }

        Row {
            id: browserFoot
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 8 * root.u
            ObscuraButton {
                width: (parent.width - 8 * root.u) * 0.4
                pal: root.pal
                u: root.u
                uiFont: root.uiFont
                label: "İptal"
                onClicked: ObscuraStore.closeBrowser()
            }
            ObscuraButton {
                width: (parent.width - 8 * root.u) * 0.6
                pal: root.pal
                u: root.u
                uiFont: root.uiFont
                primary: true
                dim: ObscuraStore.browseData.writable === false
                label: ObscuraStore.browseData.writable === false ? "Yazılamaz" : "Bu klasörü seç"
                onClicked: ObscuraStore.chooseBrowsed()
            }
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
            spacing: 4 * root.u
            Cap {
                text: "Kayıt bitince"
            }
            Row {
                height: 34 * root.u
                spacing: 12 * root.u
                ObscuraSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    pal: root.pal
                    u: root.u
                    on: ObscuraStore.cfg.notify_saved !== false
                    onToggled: ObscuraStore.setConfig("notify_saved", !(ObscuraStore.cfg.notify_saved !== false))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bildirim göster"
                    color: root.pal.text
                    font.family: root.uiFont
                    font.pixelSize: 13 * root.u
                }
            }
            Row {
                height: 34 * root.u
                spacing: 12 * root.u
                ObscuraSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    pal: root.pal
                    u: root.u
                    on: ObscuraStore.cfg.copy_path === true
                    onToggled: ObscuraStore.setConfig("copy_path", !(ObscuraStore.cfg.copy_path === true))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Dosya yolunu panoya kopyala"
                    color: root.pal.text
                    font.family: root.uiFont
                    font.pixelSize: 13 * root.u
                }
            }
        }
        Column {
            width: parent.width
            spacing: 8 * root.u
            Cap {
                text: "OBS bağlantısı"
            }
            Row {
                width: parent.width
                spacing: 10 * root.u
                ObscuraField {
                    width: 110 * root.u
                    pal: root.pal
                    u: root.u
                    monoFont: root.monoFont
                    numeric: true
                    source: ObscuraStore.cfg.obs_port > 0 ? String(ObscuraStore.cfg.obs_port) : ""
                    onCommitted: v => ObscuraStore.setConfig("obs_port", v === "" ? 0 : parseInt(v))
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 110 * root.u - 10 * root.u
                    wrapMode: Text.WordWrap
                    text: ObscuraStore.cfg.obs_port > 0 ? "Port " + ObscuraStore.cfg.obs_port + " kullanılıyor." : "Boş: OBS'in kendi ayarı kullanılır (WebSocket Server Settings)."
                    color: root.pal.overlay1
                    font.family: root.uiFont
                    font.pixelSize: 11.5 * root.u
                }
            }
            Hint {
                visible: ObscuraStore.error !== ""
                text: ObscuraStore.error
                color: root.pal.yellow
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

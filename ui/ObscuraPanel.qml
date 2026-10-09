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
    readonly property int tab: ObscuraStore.panelTab

    readonly property bool connected: ["idle", "starting", "recording", "paused", "stopping"].indexOf(ObscuraStore.state) >= 0

    Component.onCompleted: if (open)
        openChanged()

    onOpenChanged: {
        animating = true;
        animTimer.restart();
        if (open) {
            shown = true;
            openTimer.restart();
            ObscuraStore.wantInfo = true;
            ObscuraStore.refreshInfo();
        } else {
            anim = false;
            closeTimer.restart();
            ObscuraStore.closeBrowser();
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

    // True while the card scales in or out: it is then drawn once into a
    // texture instead of being re-rendered, text and all, every frame.
    property bool animating: false
    Timer {
        id: animTimer
        interval: 460
        onTriggered: root.animating = false
    }

    Binding {
        target: ObscuraStore
        property: "wantMeters"
        value: root.open && root.tab === 0 && root.connected
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
        // The window is as tall as the tallest tab and never resizes while the
        // card animates inside it; a window resize per frame is what made the
        // panel stutter. Clicks outside the card pass through.
        implicitWidth: card.width + 2 * pad
        implicitHeight: card.maxCardHeight + 2 * pad
        mask: Region {
            item: card
        }

        ObscuraPanelCard {
            id: card
            x: popup.pad
            y: popup.pad + (root.anim ? 0 : -8 * root.u)
            pal: root.pal
            u: root.u
            uiFont: root.uiFont
            monoFont: root.monoFont
            anim: root.anim
            animating: root.animating
        }
    }
}

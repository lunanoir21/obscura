// Frame-time bench: opens the pill's panel in a plain window and cycles the tabs,
// so QSG_RENDER_TIMING can report how long frames take.
//   QSG_RENDER_TIMING=1 qs -p bench.qml
import QtQuick
import Quickshell
import "ui" as O

ShellRoot {
    QtObject {
        id: pal
        property color crust: "#080808"
        property color mantle: "#101010"
        property color base: "#0e0e0e"
        property color surface0: "#1a1a1a"
        property color surface1: "#262626"
        property color surface2: "#343434"
        property color overlay0: "#6e6e6e"
        property color overlay1: "#8c8c8c"
        property color overlay2: "#a8a8a8"
        property color subtext1: "#bdbdbd"
        property color text: "#eaeaea"
        property color red: "#f08a82"
        property color green: "#9dd6a4"
        property color yellow: "#e3cd92"
    }

    FloatingWindow {
        id: win
        implicitWidth: 900
        implicitHeight: 900
        color: "#a9ada1"

        O.ObscuraPill {
            id: pill
            visible: Quickshell.env("BENCH_NOPILL") !== "1"
            x: 600
            y: 20
            pal: pal
            u: 1
        }
    }

    property int step: 0
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            step++;
            if (Quickshell.env("BENCH_NOPANEL") === "1") {
                if (step === 6)
                    Qt.quit();
            } else if (step === 1)
                pill.panelOpen = true;
            else if (step < 14)
                O.ObscuraStore.panelTab = (step - 1) % 3;
            else if (step === 14)
                pill.panelOpen = false;
            else if (step === 16)
                Qt.quit();
        }
    }
}

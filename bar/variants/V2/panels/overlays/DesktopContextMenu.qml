import QtQuick
import ".."
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../modules"

PanelWindow {
    id: desktopMenu
    required property var root
    required property var targetScreen

    screen: targetScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "omarchy-desktop-menu"

    property bool menuVisible: false
    property real menuX: 0
    property real menuY: 0

    property string currentRefresh: "Unknown"
    property string currentQuote: "Keep pushing forward."
    property string currentGreeting: "Hello"

    MprisSelect { id: mprisSel }
    MprisArtwork { id: mprisArt; player: mprisSel.player; root: desktopMenu.root }

    Process {
        id: refreshProc
        command: ["bash", "-c", "hyprctl monitors | awk -F'[@.]' '/[0-9]+x[0-9]+@/ {print $2\"Hz\"; exit}'"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let r = String(this.text || "").trim()
                if (r.length > 0) desktopMenu.currentRefresh = r
            }
        }
    }

    Process {
        id: quoteProc
        command: ["bash", "-c", "shuf -n 1 \"$HOME/.config/quickshell/bar/assets/data/quotes.txt\" 2>/dev/null || echo 'Stay positive.'"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let q = String(this.text || "").trim()
                if (q.length > 0) desktopMenu.currentQuote = q
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.LeftButton
        hoverEnabled: true

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                menuX = mouse.x
                menuY = mouse.y

                let hour = new Date().getHours()
                if (hour < 12) currentGreeting = "Good Morning"
                else if (hour < 18) currentGreeting = "Good Afternoon"
                else currentGreeting = "Good Evening"

                quoteProc.running = false
                quoteProc.running = true

                refreshProc.running = false
                refreshProc.running = true

                menuVisible = true
            } else {
                menuVisible = false
                if (root.dashboardExpanded) {
                    root.dashboardDetail = ""
                    root.dashboardExpanded = false
                }
            }
        }
    }

    DesktopContextMenuListCard {
        id: listMenuCard
        desktopMenu: desktopMenu
        root: desktopMenu.root
        mprisSel: mprisSel
        mprisArt: mprisArt
    }
}

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

ShellRoot {
    Component.onCompleted: {
        var p = Mpris.players[0]
        if (p) {
            console.log("Pos: " + p.position)
        }
        Qt.quit()
    }
}

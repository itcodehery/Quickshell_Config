import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: {
        var p = Mpris.players[0]
        if (p) {
            console.log("Player trackUrl: " + p.trackUrl)
            console.log("Player name: " + p.name)
            console.log("KEYS:")
            for (var k in p) {
                console.log(k)
            }
        }
        Qt.quit()
    }
}

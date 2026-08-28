import QtQuick
import Quickshell
import Quickshell.Services.Mpris

ShellRoot {
    Component.onCompleted: {
        var p = Mpris.players.values
        if (p.length > 0) {
            console.log("has seek: " + typeof p[0].seek)
            console.log("has setPosition: " + typeof p[0].setPosition)
        } else {
            console.log("no players")
        }
        Quickshell.exit(0)
    }
}

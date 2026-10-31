import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Single source of truth for "which player is active".
// The bar widget and the panel both instantiate this, so they can never
// disagree about the current player.
//
// playerctld (and the dead apps it proxies) can leave ghost entries that
// report Stopped or carry no metadata. Treat those as "no player".
QtObject {
    id: sel

    // playerctld is an aggregator proxy: it mirrors the last player and
    // freezes its state (often "Playing") once that player quits, leaving a
    // ghost entry. Real players always appear under their own bus name too,
    // so skip the proxy entirely and let the real entry win.
    function isProxy(p) {
        var n = (p.dbusName || "") + " " + (p.identity || "")
        return /playerctld/i.test(n)
    }

    function isReal(p) {
        if (!p) return false
        if (isProxy(p)) return false
        if (p.playbackState === MprisPlaybackState.Stopped) return false
        var hasMeta = (p.trackTitle && p.trackTitle.length > 0)
        return hasMeta || p.playbackState === MprisPlaybackState.Playing
    }

    // Multi-player tracking
    property int selectedIndex: 0
    property string manualSelectedId: ""

    readonly property var playersList: {
        var vals = Mpris.players.values
        var list = []
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (isReal(p)) list.push(p)
        }
        return list
    }

    readonly property int count: playersList.length

    function selectPlayer(idx) {
        if (idx >= 0 && idx < playersList.length) {
            selectedIndex = idx
            manualSelectedId = playersList[idx].dbusName || playersList[idx].identity || ""
        }
    }

    function nextPlayer() {
        if (playersList.length <= 1) return
        selectPlayer((selectedIndex + 1) % playersList.length)
    }

    function prevPlayer() {
        if (playersList.length <= 1) return
        selectPlayer((selectedIndex - 1 + playersList.length) % playersList.length)
    }

    readonly property var player: {
        if (playersList.length === 0) return null
        if (manualSelectedId !== "") {
            for (var k = 0; k < playersList.length; k++) {
                var cand = playersList[k]
                var candId = cand.dbusName || cand.identity || ""
                if (candId === manualSelectedId) {
                    return cand
                }
            }
        }
        for (var i = 0; i < playersList.length; i++) {
            if (playersList[i].playbackState === MprisPlaybackState.Playing) {
                return playersList[i]
            }
        }
        var targetIdx = Math.max(0, Math.min(playersList.length - 1, selectedIndex))
        return playersList[targetIdx]
    }

    onPlayerChanged: {
        if (!player || playersList.length === 0) {
            selectedIndex = 0
            return
        }
        var pId = player.dbusName || player.identity || ""
        for (var m = 0; m < playersList.length; m++) {
            var candId = playersList[m].dbusName || playersList[m].identity || ""
            if (candId === pId) {
                if (selectedIndex !== m) selectedIndex = m
                break
            }
        }
    }

    readonly property bool active:  player !== null
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
}

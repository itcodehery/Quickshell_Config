import QtQuick
import Quickshell.Services.Mpris

// Lightweight non-UI MPRIS state, position tracking, and synced-lyrics service.
// Replaces the removed MprisPanel popup window while keeping the shared API
// consumed by the bar, Island Dock dashboard, and PrivacyDots.
Item {
    id: mprisService
    required property var root

    visible: false
    width: 0
    height: 0

    MprisSelect { id: sel }
    readonly property var  player:  sel.player
    readonly property bool active:  sel.active
    readonly property bool playing: sel.playing
    MprisArtwork { id: artwork; player: mprisService.player; root: mprisService.root }

    readonly property string playerName: {
        if (!player) return ""
        var n = player.identity || player.dbusName || ""
        return n.replace(/^org\.mpris\.MediaPlayer2\./, "")
    }

    // ── lyrics state ────────────────────────────────────────────────
    readonly property int maxLyricsRetries: 4
    property var lyricsList: []
    property int currentLyricIndex: -1
    property bool showingLyrics: false
    property string lyricsTrackId: ""
    property string _lastAttemptedTrackId: ""
    property int _lyricsFetchSeq: 0
    property bool _isFetchingLyrics: false
    property int _lyricsRetryCount: 0
    property var _lyricsCache: ({})

    readonly property string currentTrackId: {
        if (!player) return ""
        var t = player.trackTitle || ""
        var a = player.trackArtist || ""
        return (t || a) ? (t.trim() + "||" + a.trim()) : ""
    }

    Connections {
        target: mprisService.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { mprisService.triggerLyricsRefresh() }
        function onTrackArtistChanged() { mprisService.triggerLyricsRefresh() }
    }

    onPlayerChanged: {
        _lastRead = -1
        syncPositionNow()
        triggerLyricsRefresh()
    }
    onCurrentTrackIdChanged: triggerLyricsRefresh()

    function triggerLyricsRefresh() {
        var trackId = mprisService.currentTrackId
        if (trackId === "") {
            lyricsList = []
            currentLyricIndex = -1
            lyricsTrackId = ""
            _lastAttemptedTrackId = ""
            _lyricsRetryCount = 0
            _isFetchingLyrics = false
            return
        }
        if (_lyricsCache[trackId]) {
            lyricsTrackId = trackId
            _lastAttemptedTrackId = trackId
            lyricsList = _lyricsCache[trackId]
            syncLyricIndex()
            _lyricsRetryCount = 0
            _isFetchingLyrics = false
            return
        }
        if (_lastAttemptedTrackId !== trackId) {
            lyricsList = []
            currentLyricIndex = -1
            lyricsTrackId = ""
            _lastAttemptedTrackId = trackId
            _lyricsRetryCount = 0
            _isFetchingLyrics = false
        }
        fetchLyrics()
    }

    Timer {
        id: lyricsPollTimer
        interval: mprisService._lyricsRetryCount < 4 ? 3000 : 6000
        repeat: true
        running: mprisService.active
                 && mprisService.currentTrackId !== ""
                 && mprisService.lyricsTrackId !== mprisService.currentTrackId
                 && mprisService._lyricsRetryCount < mprisService.maxLyricsRetries
        onTriggered: {
            if (!mprisService._isFetchingLyrics) {
                mprisService.fetchLyrics()
            }
        }
    }

    function syncLyricIndex() {
        if (!lyricsList || lyricsList.length === 0) {
            if (currentLyricIndex !== -1) currentLyricIndex = -1
            return
        }
        var pos = mprisService.curPos
        var idx = -1
        for (var i = 0; i < lyricsList.length; i++) {
            if (pos >= lyricsList[i].time) {
                idx = i
            } else {
                break
            }
        }
        if (idx !== currentLyricIndex) {
            currentLyricIndex = idx
        }
    }

    function cleanTrackTitle(str) {
        if (!str) return ""
        return str.replace(/\s*[\(\[](feat\.|ft\.|remaster|live|official|deluxe|bonus|version|radio|edit|mono|stereo|anniversary).*?[\)\]]/gi, "")
                  .replace(/\s*-\s*(remaster|live|radio|deluxe|bonus|anniversary).*$/gi, "")
                  .trim()
    }

    function parseLrc(lrcText) {
        if (!lrcText || typeof lrcText !== "string") return []
        var parsed = []
        var offsetSec = 0
        var offsetMatch = /\[offset:\s*([+-]?\d+)\]/i.exec(lrcText)
        if (offsetMatch) {
            offsetSec = (parseFloat(offsetMatch[1]) || 0) / 1000.0
        }

        var lines = lrcText.split('\n')
        var tagRegex = /\[(\d{1,2}):(\d{2}(?:\.\d+)?)\]/g
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line || /^\[[a-zA-Z]+:/.test(line)) continue
            var timestamps = []
            var match
            tagRegex.lastIndex = 0
            while ((match = tagRegex.exec(line)) !== null) {
                var m = parseFloat(match[1])
                var s = parseFloat(match[2])
                timestamps.push((m * 60) + s)
            }
            if (timestamps.length > 0) {
                var txt = line.replace(/\[\d{1,2}:\d{2}(?:\.\d+)?\]/g, "").trim()
                if (txt.length > 0) {
                    for (var t = 0; t < timestamps.length; t++) {
                        var adjustedTime = Math.max(0, timestamps[t] + offsetSec)
                        parsed.push({ time: adjustedTime, text: txt })
                    }
                }
            }
        }
        parsed.sort(function(a, b) { return a.time - b.time })
        return parsed
    }

    function fetchLyrics() {
        var p = mprisService.player
        var title = p ? (p.trackTitle || "").trim() : ""
        var artist = p ? (p.trackArtist || "").trim() : ""
        var album = p ? (p.trackAlbum || "").trim() : ""
        var dur = Math.round(p ? (p.length || mprisService.curLen || 0) : (mprisService.curLen || 0))
        var trackId = (title || artist) ? (title + "||" + artist) : ""

        if (!p || title === "" || trackId === "") {
            _isFetchingLyrics = false
            return
        }

        if (_lyricsCache[trackId]) {
            lyricsTrackId = trackId
            lyricsList = _lyricsCache[trackId]
            syncLyricIndex()
            _isFetchingLyrics = false
            return
        }

        if (_isFetchingLyrics || _lyricsRetryCount >= maxLyricsRetries) return
        _lastAttemptedTrackId = trackId
        _isFetchingLyrics = true
        var seq = ++_lyricsFetchSeq
        _lyricsRetryCount++

        var cleaned = cleanTrackTitle(title)
        var targetTitle = cleaned !== "" ? cleaned : title

        function finish(success, parsed) {
            _isFetchingLyrics = false
            if (seq !== mprisService._lyricsFetchSeq || mprisService.currentTrackId !== trackId) return
            if (success && parsed && parsed.length > 0) {
                mprisService._lyricsCache[trackId] = parsed
                mprisService.lyricsTrackId = trackId
                mprisService.lyricsList = parsed
                mprisService.syncLyricIndex()
            }
        }

        function pickBestResult(resp) {
            if (!resp) return null
            if (!Array.isArray(resp) && resp.syncedLyrics) {
                return parseLrc(resp.syncedLyrics)
            }
            if (Array.isArray(resp) && resp.length > 0) {
                var candidates = []
                for (var i = 0; i < resp.length; i++) {
                    var item = resp[i]
                    if (item && item.syncedLyrics && typeof item.syncedLyrics === "string" && item.syncedLyrics.trim().length > 0) {
                        var diff = dur > 0 && item.duration ? Math.abs(item.duration - dur) : 9999
                        candidates.push({ item: item, diff: diff })
                    }
                }
                if (candidates.length === 0) return null
                candidates.sort(function(a, b) { return a.diff - b.diff })
                return parseLrc(candidates[0].item.syncedLyrics)
            }
            return null
        }

        function query(url, nextFallback) {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, true)
            xhr.setRequestHeader("User-Agent", "Quickshell-Lyrics/2.0 (Linux)")
            xhr.timeout = 5000
            xhr.ontimeout = function() { if (nextFallback) nextFallback(); else finish(false, null); }
            xhr.onerror = function() { if (nextFallback) nextFallback(); else finish(false, null); }
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (seq !== mprisService._lyricsFetchSeq || mprisService.currentTrackId !== trackId) {
                        _isFetchingLyrics = false
                        return
                    }
                    if (xhr.status === 200) {
                        try {
                            var resp = JSON.parse(xhr.responseText)
                            var parsed = pickBestResult(resp)
                            if (parsed && parsed.length > 0) {
                                finish(true, parsed)
                                return
                            }
                        } catch(e) {}
                    }
                    if (nextFallback) nextFallback()
                    else finish(false, null)
                }
            }
            xhr.send()
        }

        var getUrl = dur > 0
            ? ("https://lrclib.net/api/get?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist) + (album ? "&album_name=" + encodeURIComponent(album) : "") + "&duration=" + dur)
            : ""
        var searchUrl1 = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(targetTitle) + "&artist_name=" + encodeURIComponent(artist)
        var searchUrl2 = "https://lrclib.net/api/search?q=" + encodeURIComponent(targetTitle + " " + artist)

        if (getUrl !== "") {
            query(getUrl, function() {
                query(searchUrl1, function() {
                    query(searchUrl2, null)
                })
            })
        } else {
            query(searchUrl1, function() {
                query(searchUrl2, null)
            })
        }
    }

    onCurPosChanged: syncLyricIndex()

    // ── live position tracking ──────────────────────────────────────
    property real curPos: 0
    property real curLen: 0
    property real _lastRead: -1

    function syncPositionNow() {
        if (!mprisService.player) {
            curPos = 0
            curLen = 0
            return
        }
        var p = mprisService.player.position || 0
        curLen = mprisService.player.length || 0
        if (Math.abs(p - _lastRead) > 0.05) {
            curPos = p
            _lastRead = p
        } else if (mprisService.playing) {
            var cap = curLen > 0 ? curLen : p + 1e9
            curPos = Math.min(cap, curPos + 0.25)
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: mprisService.active && mprisService.playing
        triggeredOnStart: true
        onTriggered: mprisService.syncPositionNow()
    }

    onPlayingChanged: {
        _lastRead = -1
        syncPositionNow()
    }

    Component.onCompleted: {
        syncPositionNow()
        fetchLyrics()
    }
}

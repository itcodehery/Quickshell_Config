// ── MPRIS Live Synced Lyrics Helper Logic ──

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

function fetchLyrics(root) {
    var p = root.activePlayer
    var title = p ? (p.trackTitle || "").trim() : ""
    var artist = p ? (p.trackArtist || "").trim() : ""
    var album = p ? (p.trackAlbum || "").trim() : ""
    var dur = Math.round(p ? (p.length || root.curLen || 0) : (root.curLen || 0))
    var trackId = (title || artist) ? (title + "||" + artist) : ""

    if (!p || title === "" || trackId === "") {
        root._isFetchingLyrics = false
        return
    }

    if (root._lyricsCache[trackId]) {
        root.lyricsTrackId = trackId
        root.lyricsList = root._lyricsCache[trackId]
        root.syncLyricIndex()
        root._isFetchingLyrics = false
        return
    }

    if (root._isFetchingLyrics) return
    root._isFetchingLyrics = true
    var seq = ++root._lyricsFetchSeq
    root._lyricsRetryCount++

    var cleaned = root.cleanTrackTitle(title)
    var targetTitle = cleaned !== "" ? cleaned : title

    function finish(success, parsed) {
        root._isFetchingLyrics = false
        if (seq !== root._lyricsFetchSeq || root.currentTrackId !== trackId) return
        if (success && parsed && parsed.length > 0) {
            root._lyricsCache[trackId] = parsed
            root.lyricsTrackId = trackId
            root.lyricsList = parsed
            root.syncLyricIndex()
        }
    }

    function pickBestResult(resp) {
        if (!resp) return null
        if (!Array.isArray(resp) && resp.syncedLyrics) {
            return root.parseLrc(resp.syncedLyrics)
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
            return root.parseLrc(candidates[0].item.syncedLyrics)
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
                if (seq !== root._lyricsFetchSeq || root.currentTrackId !== trackId) {
                    root._isFetchingLyrics = false
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

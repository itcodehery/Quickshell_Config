import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "ImagePickerModel.js" as Model
import "../modules"

Item {
    id: switcher
    anchors.fill: parent
    focus: true

    required property var root
    property var panel: null
    property string activeMode: "theme"   // "theme" or "wallpaper"
    signal closeRequested()

    readonly property bool isThemeMode: activeMode === "theme"
    readonly property string currentPickerStyle: (root && root.pickerStyle) ? root.pickerStyle : "carousel"

    property var imageArray: []
    property var filtered: []
    property int selFilt: 0
    property string currentImage: ""
    property string filterText: ""
    property bool imagesLoaded: false
    property bool justApplied: false
    property var metaCache: ({})
    property int thumbEpoch: 0
    property string readyThumbUrl: ""

    readonly property var focusedEntry: (filtered.length > 0 && selFilt >= 0 && selFilt < filtered.length)
        ? filtered[selFilt] : null
    readonly property var selMeta: (focusedEntry && focusedEntry.dir && metaCache[focusedEntry.dir])
        ? metaCache[focusedEntry.dir] : null

    // Helper for high-contrast text inside dynamic button backgrounds
    function contrastText(bg, darkCol, lightCol) {
        if (!bg) return lightCol || "#ffffff"
        var luma = 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b
        return luma > 0.55 ? (darkCol || "#101014") : (lightCol || "#ffffff")
    }

    // ── Keyboard Navigation ──
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            moveSel(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            moveSel(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            applySelected()
            event.accepted = true
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            setMode(activeMode === "theme" ? "wallpaper" : "theme")
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            if (filterText.length > 0) {
                filterText = ""
            } else {
                switcher.closeRequested()
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Backspace) {
            if (filterText.length > 0) filterText = filterText.slice(0, -1)
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            setMode(activeMode === "theme" ? "wallpaper" : "theme")
            event.accepted = true
        } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32
                   && event.text.charCodeAt(0) !== 127
                   && (event.modifiers === Qt.NoModifier || event.modifiers === Qt.ShiftModifier)) {
            filterText += event.text
            event.accepted = true
        }
    }

    Component.onCompleted: {
        forceActiveFocus()
        loadCurrent()
    }

    onVisibleChanged: if (visible) forceActiveFocus()

    onActiveModeChanged: {
        filterText = ""
        loadCurrent()
    }

    onFilterTextChanged: updateFiltered()

    function setMode(newMode) {
        if (activeMode === newMode) return
        activeMode = newMode
        if (root) {
            root.imagePickerMode = newMode
            root.dashboardDetail = newMode
        }
    }

    function setStyle(styleName) {
        if (root) root.pickerStyle = styleName
    }

    function moveSel(delta) {
        if (filtered.length === 0) return
        selFilt = Math.max(0, Math.min(filtered.length - 1, selFilt + delta))
    }

    function applySelected() {
        if (!imagesLoaded || filtered.length === 0) return
        if (selFilt < 0 || selFilt >= filtered.length) return
        var item = filtered[selFilt]
        if (!item || !item.filePath) return

        if (isThemeMode) {
            var themeName = Model.nameForPath(item.filePath)
            if (root && root.applyTheme) root.applyTheme(themeName)
            else Quickshell.execDetached(["bash", "-c", "OMARCHY_PATH='" + (root.omarchyInstallRoot || Quickshell.env("HOME") + "/.local/share/omarchy") + "' omarchy-theme-set '" + themeName.replace(/'/g, "'\\''") + "'"])
        } else {
            if (root && root.applyWallpaper) root.applyWallpaper(item.filePath)
            else Quickshell.execDetached(["bash", "-c", "omarchy-theme-bg-set '" + item.filePath.replace(/'/g, "'\\''") + "'"])
        }
        currentImage = item.filePath
        justApplied = true
        appliedTimer.restart()

        // Close dashboard immediately on applying theme or wallpaper
        if (root) {
            root.dashboardExpanded = false
            root.dashboardDetail = ""
        }
        switcher.closeRequested()
    }

    Timer {
        id: appliedTimer
        interval: 1800
        repeat: false
        onTriggered: switcher.justApplied = false
    }

    // ── Scanning & Data Loading ──
    readonly property string scanCachePath: Quickshell.env("HOME") + "/.cache/quickshell-scan-" + (isThemeMode ? "theme" : "wallpaper")
    property string _lastScan: ""

    function shq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function wallpaperFindRoots() {
        var paths = (root && root.wallpaperSourcePaths) ? root.wallpaperSourcePaths : []
        var args = []
        for (var i = 0; i < paths.length; i++) {
            if (paths[i]) args.push(shq(paths[i]))
        }
        if (args.length === 0) args.push(shq(Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/backgrounds"))
        return args.join(" ")
    }

    function paletteReadCmd(pathExpr) {
        return "awk -F'\"' 'function valid(v){ return v ~ /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/ } { k=$1; gsub(/[[:space:]=]/,\"\",k); if (valid($2)) c[k]=$2 } END { split(\"color1 red color2 green color3 yellow color4 blue color5 magenta color6 cyan\", a, \" \"); for (i=1; i<=6; i++) { p=a[i*2-1]; q=a[i*2]; v=c[p]; if (v == \"\") v=c[q]; if (v != \"\") { if (out != \"\") out=out \",\"; out=out v } } print out }' " + pathExpr + " 2>/dev/null"
    }

    function buildScanCmd() {
        if (isThemeMode) {
            return ["bash", "-c", [
                "shopt -s nullglob nocaseglob;",
                "CACHE=$HOME/.cache/quickshell-theme-picker; mkdir -p \"$CACHE\";",
                "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\";",
                "HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\";",
                "hash_for() { local s=\"$1\" r m key h tmp; r=$(readlink -f \"$s\" 2>/dev/null || printf '%s' \"$s\"); m=$(stat -Lc '%s:%Y:%Z' \"$s\" 2>/dev/null) || return 1; key=\"$r|$m\"; h=$(awk -F '\\t' -v k=\"$key\" '$1 == k { v=$2 } END { print v }' \"$HASHCACHE\" 2>/dev/null); if [ -z \"$h\" ]; then h=$(sha256sum \"$s\" 2>/dev/null | cut -d' ' -f1); [ -n \"$h\" ] || return 1; tmp=\"$HASHCACHE.$$\"; { awk -F '\\t' -v k=\"$key\" '$1 != k' \"$HASHCACHE\" 2>/dev/null; printf '%s\\t%s\\n' \"$key\" \"$h\"; } > \"$tmp\" && mv -f \"$tmp\" \"$HASHCACHE\"; fi; printf '%s' \"$h\"; };",
                "thumb_for() { local s=\"$1\" k; k=$(hash_for \"$s\") || return 1; printf '%s/%s-512.jpg' \"$D\" \"$k\"; };",
                "for d in ~/.local/share/omarchy/themes/* ~/.config/omarchy/themes/* /usr/share/omarchy/themes/*; do",
                "  [ -d \"$d\" ] || continue;",
                "  name=$(basename \"$d\");",
                "  prev=\"\";",
                "  for c in \"$d\"/preview.png \"$d\"/preview.jpg \"$d\"/preview.jpeg; do [ -f \"$c\" ] && { prev=\"$c\"; break; }; done;",
                "  if [ -z \"$prev\" ]; then bgs=(\"$d\"/backgrounds/*.jpg \"$d\"/backgrounds/*.jpeg \"$d\"/backgrounds/*.png \"$d\"/backgrounds/*.webp); prev=\"${bgs[0]}\"; fi;",
                "  [ -z \"$prev\" ] && continue;",
                "  ext=\"${prev##*.}\"; link=\"$CACHE/$name.$ext\";",
                "  [ -L \"$link\" ] || ln -sf \"$prev\" \"$link\";",
                "  thumb=$(thumb_for \"$link\") || continue;",
                "  printf '%s\\t%s\\t%s\\n' \"$link\" \"$thumb\" \"$d\";",
                "done | sort -u"
            ].join(" ")]
        } else {
            return ["bash", "-c", [
                "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\";",
                "HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\";",
                "hash_for() { local s=\"$1\" r m key h tmp; r=$(readlink -f \"$s\" 2>/dev/null || printf '%s' \"$s\"); m=$(stat -Lc '%s:%Y:%Z' \"$s\" 2>/dev/null) || return 1; key=\"$r|$m\"; h=$(awk -F '\\t' -v k=\"$key\" '$1 == k { v=$2 } END { print v }' \"$HASHCACHE\" 2>/dev/null); if [ -z \"$h\" ]; then h=$(sha256sum \"$s\" 2>/dev/null | cut -d' ' -f1); [ -n \"$h\" ] || return 1; tmp=\"$HASHCACHE.$$\"; { awk -F '\\t' -v k=\"$key\" '$1 != k' \"$HASHCACHE\" 2>/dev/null; printf '%s\\t%s\\n' \"$key\" \"$h\"; } > \"$tmp\" && mv -f \"$tmp\" \"$HASHCACHE\"; fi; printf '%s' \"$h\"; };",
                "thumb_for() { local s=\"$1\" k; k=$(hash_for \"$s\") || return 1; printf '%s/%s-512.jpg' \"$D\" \"$k\"; };",
                "find -L " + wallpaperFindRoots() + " -maxdepth 1 -type f " +
                "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \\) " +
                "2>/dev/null | sort | while IFS= read -r f; do thumb=$(thumb_for \"$f\") || continue; printf '%s\\t%s\\n' \"$f\" \"$thumb\"; done"
            ].join(" ")]
        }
    }

    Process {
        id: currentProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                switcher.currentImage = this.text.trim()
                cacheProc.running = false
                cacheProc.running = true
                var cmd = switcher.buildScanCmd()
                cmd[2] = cmd[2] + " | tee " + switcher.shq(switcher.scanCachePath)
                scanProc.command = cmd
                scanProc.running = false
                scanProc.running = true
            }
        }
    }

    Process {
        id: cacheProc
        command: ["cat", switcher.scanCachePath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: switcher.applyScan(this.text, true)
        }
    }

    Process {
        id: scanProc
        command: []
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: switcher.applyScan(this.text, false)
        }
    }

    function loadCurrent() {
        imagesLoaded = false
        currentProc.command = isThemeMode
            ? ["bash", "-c",
               "CACHE=$HOME/.cache/quickshell-theme-picker; " +
               "name=$(cat $HOME/.local/state/omarchy/current/theme.name 2>/dev/null || cat " + shq(root.themeNamePath) + " 2>/dev/null || true); " +
               "for ext in png jpg jpeg webp; do f=\"$CACHE/$name.$ext\"; [ -L \"$f\" ] && echo \"$f\" && exit 0; done; echo ''"]
            : ["bash", "-c", "readlink -f $HOME/.local/state/omarchy/current/background 2>/dev/null || readlink -f " + shq(root.currentBackgroundPath) + " 2>/dev/null || true"]
        currentProc.running = false
        currentProc.running = true
    }

    function applyScan(text, fromCache) {
        var t = String(text || "")
        if (fromCache && !t.trim()) return
        if (!fromCache && t.trim() === _lastScan.trim() && imagesLoaded) {
            warmVisible()
            return
        }
        _lastScan = t
        var images = Model.loadRows(t)
        imageArray = images
        imagesLoaded = images.length > 0
        updateFiltered()

        if (isThemeMode) warmMeta()
        warmVisible()
    }

    function updateFiltered() {
        var out = []
        for (var i = 0; i < imageArray.length; i++) {
            if (!Model.itemMatches(imageArray, i, filterText)) continue
            var path = imageArray[i].filePath
            out.push({
                idx: i,
                filePath: path,
                thumb: (imageArray[i].thumbnailPath && imageArray[i].thumbnailPath !== path)
                    ? ("file://" + imageArray[i].thumbnailPath)
                    : ("file://" + path),
                label: Model.labelForPath(path),
                dir: imageArray[i].dir || "",
                current: path === currentImage
            })
        }
        filtered = out
        // Select matching current image if possible
        var curIdx = 0
        for (var k = 0; k < out.length; k++) {
            if (out[k].current) { curIdx = k; break }
        }
        selFilt = curIdx
    }

    // ── Metadata Pre-Warming (Theme Author, Repo, Palette) ──
    Process {
        id: metaWarmProc
        command: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text || "").split("\n")
                var m = switcher.metaCache
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i]) continue
                    var p = lines[i].split("\t")
                    if (p[0] && !m[p[0]]) {
                        m[p[0]] = { author: p[1] || "", repo: p[2] || "", palette: p[3] || "" }
                    }
                }
                switcher.metaCache = m
            }
        }
    }

    function warmMeta() {
        if (!isThemeMode) return
        var dirs = []
        for (var i = 0; i < imageArray.length; i++) {
            if (imageArray[i].dir) dirs.push(imageArray[i].dir)
        }
        if (dirs.length === 0) return
        metaWarmProc.command = ["bash", "-c",
            "for d in \"$@\"; do repo=''; author='';" +
            "if [ -f \"$d/.git/config\" ]; then repo=$(sed -nE 's#^[[:space:]]*url = (.*)$#\\1#p' \"$d/.git/config\" | head -1);" +
            "author=$(printf '%s' \"$repo\" | sed -nE 's#.*github\\.com[:/]+([^/]+)/.*#\\1#p'); fi;" +
            "pal=$(" + paletteReadCmd("\"$d/colors.toml\"") + ");" +
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$d\" \"$author\" \"$repo\" \"$pal\"; done",
            "warm"].concat(dirs)
        metaWarmProc.running = false
        metaWarmProc.running = true
    }

    function warmVisible() {
        var visiblePaths = []
        for (var i = Math.max(0, selFilt - 3); i <= Math.min(filtered.length - 1, selFilt + 3); i++) {
            if (filtered[i]) visiblePaths.push(filtered[i].filePath)
        }
        if (visiblePaths.length > 0) {
            warmProc.command = ["bash", "-c",
                "D=$HOME/.cache/quickshell-img-thumbs; mkdir -p \"$D\"; command -v magick >/dev/null 2>&1 || exit 0; " +
                "HASHCACHE=$HOME/.cache/quickshell-img-thumb-hashes.tsv; touch \"$HASHCACHE\"; " +
                "tmp=$(mktemp); trap 'rm -f \"$tmp\"' EXIT; " +
                "hash_for() { local s=\"$1\" r m key h t; r=$(readlink -f \"$s\" 2>/dev/null || printf '%s' \"$s\"); m=$(stat -Lc '%s:%Y:%Z' \"$s\" 2>/dev/null) || return 1; key=\"$r|$m\"; h=$(awk -F '\\t' -v k=\"$key\" '$1 == k { v=$2 } END { print v }' \"$HASHCACHE\" 2>/dev/null); if [ -z \"$h\" ]; then h=$(sha256sum \"$s\" 2>/dev/null | cut -d' ' -f1); [ -n \"$h\" ] || return 1; t=\"$HASHCACHE.$$\"; { awk -F '\\t' -v k=\"$key\" '$1 != k' \"$HASHCACHE\" 2>/dev/null; printf '%s\\t%s\\n' \"$key\" \"$h\"; } > \"$t\" && mv -f \"$t\" \"$HASHCACHE\"; fi; printf '%s' \"$h\"; }; " +
                "for s in \"$@\"; do k=$(hash_for \"$s\") || continue; " +
                "o=\"$D/$k-512.jpg\"; [ -s \"$o\" ] && continue; printf '%s\\n%s\\n' \"$s\" \"$o\" >> \"$tmp\"; done; " +
                "if [ -s \"$tmp\" ]; then nice -n 10 xargs -d '\\n' -P 3 -n 2 sh -c 'magick -define jpeg:size=1024x1024 \"$0[0]\" -auto-orient -strip -thumbnail 512x512^ -quality 82 \"$1\" >/dev/null 2>&1 || true; [ -s \"$1\" ] && printf \"%s\\n\" \"$1\"; exit 0' < \"$tmp\"; fi",
                "warm"].concat(visiblePaths)
            warmProc.running = false
            warmProc.running = true
        }
    }

    Process {
        id: warmProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var p = String(line || "").trim()
                if (p) {
                    switcher.readyThumbUrl = "file://" + p
                    switcher.thumbEpoch++
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // ── TOP HEADER BAR: Mode Tabs, Style Pills, Search ───────
    // ─────────────────────────────────────────────────────────
    Item {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        z: 30

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            // Mode Tabs: [ Themes | Wallpapers ]
            PillTabs {
                anchors.verticalCenter: parent.verticalCenter
                theme: root
                tabHeight: 28
                model: [
                    { id: "theme", label: "Themes", icon: "palette" },
                    { id: "wallpaper", label: "Wallpapers", icon: "image" }
                ]
                current: switcher.isThemeMode ? "theme" : "wallpaper"
                onActivated: (id) => switcher.setMode(id)
            }

            // Style Selector: [ 3D Fan | Hearthstone | Coverflow ]
            PillTabs {
                anchors.verticalCenter: parent.verticalCenter
                theme: root
                variant: "tonal"
                tabHeight: 24
                fontSize: 10
                model: [
                    { id: "tanzaku", label: "3D Fan", icon: "view_carousel" },
                    { id: "hearthstone", label: "Hearthstone", icon: "style" },
                    { id: "carousel", label: "Coverflow", icon: "view_array" },
                    { id: "gravemind", label: "Gravemind", icon: "layers" }
                ]
                current: switcher.currentPickerStyle === "" ? "tanzaku" : switcher.currentPickerStyle
                onActivated: (id) => switcher.setStyle(id)
            }
        }

        // Right side: Filter Search Pill
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 28
            width: Math.min(220, Math.max(140, filterRow.implicitWidth + 24))
            radius: 14
            color: root.fillIdle
            border.color: switcher.filterText ? root.seal : root.frameWeak
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Row {
                id: filterRow
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconText {
                    text: "search"
                    font.pixelSize: 13
                    color: switcher.filterText ? root.seal : root.ink
                    opacity: 0.75
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: switcher.filterText ? switcher.filterText : "Type to filter..."
                    font.family: root.barFont
                    font.pixelSize: 11
                    font.italic: !switcher.filterText
                    color: root.ink
                    opacity: switcher.filterText ? 0.95 : 0.45
                    elide: Text.ElideRight
                    width: parent.width - 20 - (switcher.filterText ? 18 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Clear button
                Rectangle {
                    visible: switcher.filterText !== ""
                    width: 16; height: 16; radius: 8
                    color: clearMa.containsMouse ? root.fillHover : "transparent"
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        font.pixelSize: 11
                        color: root.ink
                    }

                    MouseArea {
                        id: clearMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcher.filterText = ""
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // ── STAGE CARD CONTAINER: Recessed rounded gallery card ───
    // ─────────────────────────────────────────────────────────
    Rectangle {
        id: stageContainer
        anchors.top: headerBar.bottom
        anchors.topMargin: 8
        anchors.bottom: footerBar.top
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        radius: 20
        color: Qt.rgba(0.04, 0.04, 0.07, 0.65)
        border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.12)
        border.width: 1
        clip: true

        MouseArea {
            anchors.fill: parent
            onWheel: function(wheel) {
                switcher.moveSel(wheel.angleDelta.y < 0 ? 1 : -1)
            }
        }

        // Empty state
        Text {
            visible: switcher.imagesLoaded && switcher.filtered.length === 0
            anchors.centerIn: parent
            text: "No matches for \"" + switcher.filterText + "\"\nPress Backspace or Esc to clear"
            horizontalAlignment: Text.AlignHCenter
            color: root.ink
            opacity: 0.7
            font.family: root.barFont
            font.pixelSize: 13
        }

        // Loading state
        Item {
            visible: !switcher.imagesLoaded
            anchors.centerIn: parent
            width: 120; height: 30

            Row {
                anchors.centerIn: parent
                spacing: 8
                IconText {
                    text: "sync"
                    font.pixelSize: 16
                    color: root.seal
                    anchors.verticalCenter: parent.verticalCenter
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1200
                    }
                }
                Text {
                    text: "Loading..."
                    font.family: root.barFont
                    font.pixelSize: 12
                    color: root.ink
                    opacity: 0.7
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ═════════════════════════════════════════════════════
        // STYLE 1: TANZAKU (3D Fan / Sumi-e Filmstrip)
        // ═════════════════════════════════════════════════════
        Item {
            id: tanzakuStage
            visible: switcher.currentPickerStyle === "tanzaku" || switcher.currentPickerStyle === ""
            anchors.fill: parent

            readonly property int focusedW: 390
            readonly property int focusedH: 220
            readonly property int peekW: 68
            readonly property int stripW: 22
            readonly property int gap: 8

            function stripWidthFor(d) {
                if (d <= 0) return focusedW
                if (d === 1) return peekW
                return stripW
            }

            readonly property real cx: width / 2
            readonly property real fLeft: cx - focusedW / 2
            readonly property real fRight: cx + focusedW / 2

            function xForRel(r) {
                if (r === 0) return fLeft
                var x
                if (r < 0) {
                    x = fLeft
                    for (var k = -1; k >= r; k--) x = x - gap - stripWidthFor(-k)
                    return x
                }
                x = fRight + gap
                for (var j = 1; j < r; j++) x = x + stripWidthFor(j) + gap
                return x
            }

            Repeater {
                model: switcher.filtered.length

                delegate: Item {
                    id: tCard
                    required property int index
                    readonly property var entry: switcher.filtered[index] || null
                    readonly property int relIdx: index - switcher.selFilt
                    readonly property bool focused: relIdx === 0
                    readonly property bool near: Math.abs(relIdx) <= 8

                    width: tanzakuStage.stripWidthFor(Math.abs(relIdx))
                    height: tanzakuStage.focusedH
                    anchors.verticalCenter: parent.verticalCenter
                    x: tanzakuStage.xForRel(relIdx)
                    z: focused ? 100 : 50 - Math.min(Math.abs(relIdx), 30)
                    visible: near
                    opacity: near ? 1 : 0

                    Behavior on x     { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: "#16161c"
                        border.width: focused ? 2.5 : 1
                        border.color: focused ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)

                        // Strict rounded clipping masks images & overlays cleanly
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: focused ? 2.5 : 1
                            radius: 14
                            color: "#16161c"

                            Image {
                                anchors.fill: parent
                                source: (tCard.near && tCard.entry && tCard.entry.thumb) ? tCard.entry.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            // Wash overlay for non-focused cards
                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: tCard.focused ? 0 : (Math.abs(tCard.relIdx) === 1 ? 0.35 : 0.60)
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // Gradient shadow on focused card
                            Rectangle {
                                visible: tCard.focused
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 56
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                                }
                            }

                            // Theme/Wallpaper title on focused card
                            Text {
                                visible: tCard.focused
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                text: tCard.entry ? tCard.entry.label : ""
                                color: "#ECECEE"
                                font.family: root.barFont
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            // Label overlay on peek cards
                            Rectangle {
                                visible: Math.abs(tCard.relIdx) === 1
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 28
                                color: Qt.rgba(0, 0, 0, 0.72)
                                Text {
                                    anchors.centerIn: parent
                                    text: tCard.entry ? tCard.entry.label : ""
                                    color: "#ECECEE"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width - 6
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }

                    // Red seal stroke under focused card
                    Rectangle {
                        visible: tCard.focused
                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 52; height: 3; radius: 1.5
                        color: root.seal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (tCard.focused) switcher.applySelected()
                            else switcher.selFilt = index
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        // STYLE 2: HEARTHSTONE (Curved Arc Hand of Cards)
        // ═════════════════════════════════════════════════════
        Item {
            id: hsStage
            visible: switcher.currentPickerStyle === "hearthstone"
            anchors.fill: parent

            readonly property int cardW: 148
            readonly property int cardH: 210
            readonly property int stepX: 96
            readonly property real spreadDeg: 3.8
            readonly property int focusLift: 28
            readonly property real focusScale: 1.16

            Repeater {
                model: switcher.filtered.length

                delegate: Item {
                    id: hCard
                    required property int index
                    readonly property var entry: switcher.filtered[index] || null
                    readonly property int relIdx: index - switcher.selFilt
                    readonly property bool focused: relIdx === 0
                    readonly property bool nearby: Math.abs(relIdx) <= 7
                    readonly property real dim: focused ? 0.0 : Math.min(0.60, 0.28 + Math.abs(relIdx) * 0.06)

                    width: hsStage.cardW
                    height: hsStage.cardH
                    visible: nearby
                    transformOrigin: Item.Bottom

                    x: (hsStage.width - hsStage.cardW) / 2 + relIdx * hsStage.stepX
                    y: (hsStage.height - hsStage.cardH) - (focused ? hsStage.focusLift : 0) - 8
                    rotation: relIdx * hsStage.spreadDeg
                    scale: focused ? hsStage.focusScale : 1.0
                    z: focused ? 1000 : 500 - Math.min(Math.abs(relIdx), 40)

                    Behavior on x        { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
                    Behavior on y        { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
                    Behavior on rotation { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }
                    Behavior on scale    { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.18 } }

                    // Card contents strictly clipped to card outer radius (18px)
                    ClippingRectangle {
                        anchors.fill: parent
                        radius: 18
                        color: "#141418"

                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            anchors.margins: 6
                            source: (hCard.nearby && hCard.entry && hCard.entry.thumb) ? hCard.entry.thumb : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }

                        // Gradient shadow at bottom of card
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 64
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.80) }
                            }
                        }

                        // Theme/Wallpaper title on the card
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            text: hCard.entry ? hCard.entry.label : ""
                            color: "#ECECEE"
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // Dim overlay on non-focused cards
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: hCard.dim
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }
                    }

                    // Passepartout Shape - CurveRenderer with OddEvenFill outer/inner cutouts
                    Shape {
                        id: frameShape
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        readonly property real w: hCard.width
                        readonly property real h: hCard.height
                        readonly property real ro: 18    // outer radius
                        readonly property real m: 7      // mat width
                        readonly property real ri: 11    // inner (photo) radius

                        ShapePath {
                            fillRule: ShapePath.OddEvenFill
                            fillColor: "#141418"
                            strokeColor: "transparent"
                            strokeWidth: 0

                            // outer rounded rect
                            startX: frameShape.ro; startY: 0
                            PathLine { x: frameShape.w - frameShape.ro; y: 0 }
                            PathArc  { x: frameShape.w; y: frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                            PathLine { x: frameShape.w; y: frameShape.h - frameShape.ro }
                            PathArc  { x: frameShape.w - frameShape.ro; y: frameShape.h; radiusX: frameShape.ro; radiusY: frameShape.ro }
                            PathLine { x: frameShape.ro; y: frameShape.h }
                            PathArc  { x: 0; y: frameShape.h - frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                            PathLine { x: 0; y: frameShape.ro }
                            PathArc  { x: frameShape.ro; y: 0; radiusX: frameShape.ro; radiusY: frameShape.ro }

                            // inner rounded hole (photo cut-out)
                            PathMove { x: frameShape.m + frameShape.ri; y: frameShape.m }
                            PathLine { x: frameShape.w - frameShape.m - frameShape.ri; y: frameShape.m }
                            PathArc  { x: frameShape.w - frameShape.m; y: frameShape.m + frameShape.ri; radiusX: frameShape.ri; radiusY: frameShape.ri }
                            PathLine { x: frameShape.w - frameShape.m; y: frameShape.h - frameShape.m - frameShape.ri }
                            PathArc  { x: frameShape.w - frameShape.m - frameShape.ri; y: frameShape.h - frameShape.m; radiusX: frameShape.ri; radiusY: frameShape.ri }
                            PathLine { x: frameShape.m + frameShape.ri; y: frameShape.h - frameShape.m }
                            PathArc  { x: frameShape.m; y: frameShape.h - frameShape.m - frameShape.ri; radiusX: frameShape.ri; radiusY: frameShape.ri }
                            PathLine { x: frameShape.m; y: frameShape.m + frameShape.ri }
                            PathArc  { x: frameShape.m + frameShape.ri; y: frameShape.m; radiusX: frameShape.ri; radiusY: frameShape.ri }
                        }

                        // Focused accent border — glowing white border when focused
                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: hCard.focused ? "#ffffff" : Qt.rgba(1, 1, 1, 0.12)
                            strokeWidth: hCard.focused ? 2.5 : 1
                            Behavior on strokeColor { ColorAnimation { duration: 160 } }

                            startX: frameShape.ro; startY: 0
                            PathLine { x: frameShape.w - frameShape.ro; y: 0 }
                            PathArc  { x: frameShape.w; y: frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                            PathLine { x: frameShape.w; y: frameShape.h - frameShape.ro }
                            PathArc  { x: frameShape.w - frameShape.ro; y: frameShape.h; radiusX: frameShape.ro; radiusY: frameShape.ro }
                            PathLine { x: frameShape.ro; y: frameShape.h }
                            PathArc  { x: 0; y: frameShape.h - frameShape.ro; radiusX: frameShape.ro; radiusY: frameShape.ro }
                            PathLine { x: 0; y: frameShape.ro }
                            PathArc  { x: frameShape.ro; y: 0; radiusX: frameShape.ro; radiusY: frameShape.ro }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (hCard.focused) switcher.applySelected()
                            else switcher.selFilt = index
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        // STYLE 3: CAROUSEL (Coverflow with Dead-Center Hero Card)
        // ═════════════════════════════════════════════════════
        Item {
            id: cfStage
            visible: switcher.currentPickerStyle === "carousel"
            anchors.fill: parent

            readonly property int expandedW: 380
            readonly property int expandedH: 214
            readonly property int sliceW: 84
            readonly property int sliceH: 184
            readonly property real itemStep: 68

            readonly property real centerX: (width - expandedW) / 2

            Repeater {
                model: switcher.filtered.length

                delegate: Item {
                    id: cfSlice
                    required property int index
                    readonly property var entry: switcher.filtered[index] || null
                    readonly property int relIdx: index - switcher.selFilt
                    readonly property bool selected: relIdx === 0
                    readonly property bool nearby: Math.abs(relIdx) <= 7

                    visible: nearby
                    width: selected ? cfStage.expandedW : cfStage.sliceW
                    height: selected ? cfStage.expandedH : cfStage.sliceH

                    // Dead-center vertically:
                    y: (cfStage.height - height) / 2

                    // Dead-center horizontally for selected card, cascading out for side cards:
                    x: selected
                        ? cfStage.centerX
                        : (relIdx < 0
                            ? (cfStage.centerX - 20 - cfStage.sliceW - (Math.abs(relIdx) - 1) * cfStage.itemStep)
                            : (cfStage.centerX + cfStage.expandedW + 20 + (relIdx - 1) * cfStage.itemStep))
                    z: selected ? 100 : 50 - Math.min(Math.abs(relIdx), 30)

                    Behavior on x      { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on y      { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on width  { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: selected ? 16 : 10
                        color: "#16161c"
                        border.width: selected ? 2.5 : 1
                        border.color: selected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.15)

                        // Strict rounded clipping masks image and overlays cleanly
                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: selected ? 2.5 : 1
                            radius: selected ? 14 : 9
                            color: "#16161c"

                            Image {
                                anchors.fill: parent
                                source: (cfSlice.nearby && cfSlice.entry && cfSlice.entry.thumb) ? cfSlice.entry.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            // Dim overlay on side slices
                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: cfSlice.selected ? 0 : 0.50
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // Gradient shadow on selected card
                            Rectangle {
                                visible: cfSlice.selected
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 56
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                                }
                            }

                            // Theme/Wallpaper title on selected card
                            Text {
                                visible: cfSlice.selected
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 10
                                text: cfSlice.entry ? cfSlice.entry.label : ""
                                color: "#ECECEE"
                                font.family: root.barFont
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Red seal stroke under selected card
                    Rectangle {
                        visible: cfSlice.selected
                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 52; height: 3; radius: 1.5
                        color: root.seal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (cfSlice.selected) switcher.applySelected()
                            else switcher.selFilt = index
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════
        // STYLE 4: GRAVEMIND (Spatial 3D Capsule Coverflow)
        // ═════════════════════════════════════════════════════
        Item {
            id: gravemindStage
            visible: switcher.currentPickerStyle === "gravemind"
            anchors.fill: parent

            readonly property int cardW: 200
            readonly property int cardH: 200
            readonly property int cardRadius: 22
            readonly property real itemStep: 46
            readonly property real centerGap: 92
            readonly property real centerX: (width - cardW) / 2
            readonly property real centerY: (height - cardH) / 2

            // Capsule black dock backdrop (matches reference image)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 24
                color: "#08080b"
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
            }

            Repeater {
                model: switcher.filtered.length

                delegate: Item {
                    id: gmCard
                    required property int index
                    readonly property var entry: switcher.filtered[index] || null
                    readonly property int relIdx: index - switcher.selFilt
                    readonly property bool focused: relIdx === 0
                    readonly property bool nearby: Math.abs(relIdx) <= 7

                    visible: nearby
                    width: gravemindStage.cardW
                    height: gravemindStage.cardH

                    // Vertical centering
                    y: gravemindStage.centerY

                    // Horizontal 3D placement:
                    x: focused
                        ? gravemindStage.centerX
                        : (relIdx < 0
                            ? (gravemindStage.centerX - gravemindStage.centerGap - (Math.abs(relIdx) - 1) * gravemindStage.itemStep)
                            : (gravemindStage.centerX + gravemindStage.centerGap + (relIdx - 1) * gravemindStage.itemStep))

                    // Center card on top, outer cards stacked behind
                    z: focused ? 100 : 50 - Math.min(Math.abs(relIdx), 30)

                    // 3D Perspective Rotation around Y axis
                    // Left cards angle inward facing right (-44 deg)
                    // Right cards angle inward facing left (44 deg)
                    property real targetRotY: focused ? 0 : (relIdx < 0 ? -44 : 44)
                    property real targetScale: focused ? 1.0 : Math.max(0.82, 0.96 - Math.abs(relIdx) * 0.035)

                    Behavior on x           { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on targetRotY  { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on targetScale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    transform: [
                        Rotation {
                            origin.x: gmCard.width / 2
                            origin.y: gmCard.height / 2
                            axis { x: 0; y: 1; z: 0 }
                            angle: gmCard.targetRotY
                        },
                        Scale {
                            origin.x: gmCard.width / 2
                            origin.y: gmCard.height / 2
                            xScale: gmCard.targetScale
                            yScale: gmCard.targetScale
                        }
                    ]

                    // Smooth card frame with rounded corners
                    Rectangle {
                        anchors.fill: parent
                        radius: gravemindStage.cardRadius
                        color: "#121216"
                        border.width: gmCard.focused ? 2 : 1
                        border.color: gmCard.focused ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.12)
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: gmCard.focused ? 2 : 1
                            radius: gravemindStage.cardRadius - 1
                            color: "#121216"

                            Image {
                                anchors.fill: parent
                                source: (gmCard.nearby && gmCard.entry && gmCard.entry.thumb) ? gmCard.entry.thumb : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            // Progressive depth shading on receding side cards
                            Rectangle {
                                anchors.fill: parent
                                color: "black"
                                opacity: gmCard.focused ? 0.0 : Math.min(0.82, 0.28 + Math.abs(gmCard.relIdx) * 0.16)
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }

                            // Bottom gradient shadow for typography on center card
                            Rectangle {
                                visible: gmCard.focused
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 74
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.45) }
                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
                                }
                            }

                            // Typography: Title and Subtitle matching the reference image layout
                            Column {
                                visible: gmCard.focused
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 14
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: gmCard.entry ? gmCard.entry.label : ""
                                    color: "#FFFFFF"
                                    font.family: root.barFont
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: {
                                        if (!gmCard.entry) return ""
                                        if (switcher.isThemeMode) {
                                            let meta = (gmCard.entry.dir && switcher.metaCache[gmCard.entry.dir]) ? switcher.metaCache[gmCard.entry.dir] : null
                                            return meta && meta.author ? ("@" + meta.author) : "Theme"
                                        }
                                        return "Wallpaper"
                                    }
                                    color: Qt.rgba(1, 1, 1, 0.75)
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Theme accent line indicator under focused card
                    Rectangle {
                        visible: gmCard.focused
                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48
                        height: 3
                        radius: 1.5
                        color: root.seal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (gmCard.focused) switcher.applySelected()
                            else switcher.selFilt = index
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // ── FOOTER BAR: Metadata (Author/Repo/Palette), Counter ───
    // ─────────────────────────────────────────────────────────
    Item {
        id: footerBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        z: 30

        // Left: Metadata Pill (Author & Repo)
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // Author Pill
            Item {
                visible: switcher.isThemeMode && switcher.selMeta && switcher.selMeta.author
                height: 22
                width: metaRow.implicitWidth
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: metaRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        height: 22
                        width: authorTxt.implicitWidth + 14
                        radius: 11
                        color: root.fillIdle
                        border.color: root.frameWeak; border.width: 1

                        Text {
                            id: authorTxt
                            anchors.centerIn: parent
                            text: "@" + (switcher.selMeta ? switcher.selMeta.author : "")
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: root.ink
                            opacity: 0.85
                        }
                    }

                    // Clickable Repo link
                    Rectangle {
                        visible: switcher.selMeta && switcher.selMeta.repo
                        height: 22
                        width: repoRow.implicitWidth + 12
                        radius: 11
                        color: repoMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: root.frameWeak; border.width: 1

                        Row {
                            id: repoRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "code"
                                font.pixelSize: 12
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Repo"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: repoMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (switcher.selMeta && switcher.selMeta.repo) {
                                    var url = String(switcher.selMeta.repo)
                                        .replace(/^git@github\.com:/, "https://github.com/")
                                        .replace(/\.git$/, "")
                                    Quickshell.execDetached(["xdg-open", url])
                                }
                            }
                        }
                    }
                }
            }

            // Palette Swatch Dots (Theme mode only)
            Row {
                visible: switcher.isThemeMode && switcher.selMeta && switcher.selMeta.palette
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                readonly property var colors: (switcher.selMeta && switcher.selMeta.palette)
                    ? switcher.selMeta.palette.split(",") : []

                Repeater {
                    model: parent.colors

                    delegate: Rectangle {
                        required property string modelData
                        width: 12; height: 12; radius: 6
                        color: modelData
                        border.color: Qt.rgba(0, 0, 0, 0.35)
                        border.width: 1
                    }
                }
            }

            // Wallpaper mode: file info
            Text {
                visible: !switcher.isThemeMode && switcher.focusedEntry
                text: switcher.focusedEntry ? switcher.focusedEntry.filePath.split("/").pop() : ""
                font.family: root.barFont
                font.pixelSize: 11
                color: root.ink
                opacity: 0.60
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Center: Subtle Keyboard Navigation Hint
        Text {
            anchors.centerIn: parent
            text: "← → navigate   Tab switch   ↵ apply   Esc back   type to filter"
            font.family: root.barFont
            font.pixelSize: 10
            color: root.ink
            opacity: 0.40
        }

        // Right: Item counter and Apply Button
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // Counter (e.g. "4 / 30")
            Text {
                visible: switcher.filtered.length > 0
                text: (switcher.selFilt + 1) + " / " + switcher.filtered.length
                font.family: root.barFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: root.ink
                opacity: 0.60
                anchors.verticalCenter: parent.verticalCenter
            }

            // Apply Button
            Rectangle {
                id: applyBtn
                height: 32
                width: applyRow.implicitWidth + 22
                radius: 16
                color: switcher.justApplied ? "#22c55e" : (applyMa.containsMouse ? Qt.lighter(root.seal, 1.10) : root.seal)
                scale: applyMa.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 180 } }

                readonly property color btnTextCol: switcher.justApplied
                    ? "#ffffff"
                    : switcher.contrastText(applyBtn.color, "#101014", "#ffffff")

                Row {
                    id: applyRow
                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        text: switcher.justApplied ? "check" : (switcher.isThemeMode ? "palette" : "wallpaper")
                        font.pixelSize: 14
                        color: applyBtn.btnTextCol
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: switcher.justApplied
                            ? "Applied ✓"
                            : (switcher.isThemeMode ? "Apply Theme (↵)" : "Apply Wallpaper (↵)")
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: applyBtn.btnTextCol
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: switcher.applySelected()
                }
            }
        }
    }
}

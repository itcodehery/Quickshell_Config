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

    // ── Keyboard Navigation ──
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            moveSel(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            moveSel(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            applySelected()
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
            if (event.text !== " " || (filterText.length > 0 && !filterText.endsWith(" "))) {
                filterText += event.text
            }
            event.accepted = true
        }
    }

    Component.onCompleted: {
        forceActiveFocus()
        loadCurrent()
    }

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
        // Thumbnail generator runner if magick exists
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
    // ── TOP HEADER BAR: Back, Mode Tabs, Style Pills, Search ─
    // ─────────────────────────────────────────────────────────
    Item {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 36
        z: 20

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            // Back Button
            Rectangle {
                width: backRow.width + 16
                height: 28
                radius: 14
                color: backMa.containsMouse ? root.fillHover : root.fillIdle
                scale: backMa.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: 4
                    IconText {
                        text: "arrow_back"
                        font.pixelSize: 14
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Back"
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: backMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: switcher.closeRequested()
                }
            }

            // Mode Tabs: [ Themes | Wallpapers ]
            Rectangle {
                height: 28
                width: modeRow.width + 8
                radius: 14
                color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.45)
                border.color: root.frameWeak
                border.width: 1

                Row {
                    id: modeRow
                    anchors.centerIn: parent
                    spacing: 4

                    // Themes Tab
                    Rectangle {
                        width: themeTabRow.width + 16
                        height: 22
                        radius: 11
                        color: switcher.isThemeMode ? root.seal : (themeTabMa.containsMouse ? root.fillHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: themeTabRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "palette"
                                font.pixelSize: 12
                                color: switcher.isThemeMode ? "#ffffff" : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Themes"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: switcher.isThemeMode ? Font.Bold : Font.Medium
                                color: switcher.isThemeMode ? "#ffffff" : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: themeTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switcher.setMode("theme")
                        }
                    }

                    // Wallpapers Tab
                    Rectangle {
                        width: wpTabRow.width + 16
                        height: 22
                        radius: 11
                        color: !switcher.isThemeMode ? root.seal : (wpTabMa.containsMouse ? root.fillHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: wpTabRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "image"
                                font.pixelSize: 12
                                color: !switcher.isThemeMode ? "#ffffff" : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Wallpapers"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: !switcher.isThemeMode ? Font.Bold : Font.Medium
                                color: !switcher.isThemeMode ? "#ffffff" : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: wpTabMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switcher.setMode("wallpaper")
                        }
                    }
                }
            }

            // Style Selector: [ 3D Fan | Hearthstone | Coverflow ]
            Rectangle {
                height: 28
                width: styleRow.width + 8
                radius: 14
                color: Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.45)
                border.color: root.frameWeak
                border.width: 1

                Row {
                    id: styleRow
                    anchors.centerIn: parent
                    spacing: 3

                    // Tanzaku (3D Fan)
                    Rectangle {
                        property bool sel: switcher.currentPickerStyle === "tanzaku" || switcher.currentPickerStyle === ""
                        width: tanzakuTabRow.width + 14
                        height: 22
                        radius: 11
                        color: sel ? root.fillHover : (tanzakuMa.containsMouse ? root.fillIdle : "transparent")
                        border.color: sel ? root.seal : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: tanzakuTabRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "view_carousel"
                                font.pixelSize: 12
                                color: parent.parent.sel ? root.seal : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "3D Fan"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: parent.parent.sel ? Font.Bold : Font.Normal
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: tanzakuMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switcher.setStyle("tanzaku")
                        }
                    }

                    // Hearthstone
                    Rectangle {
                        property bool sel: switcher.currentPickerStyle === "hearthstone"
                        width: hsTabRow.width + 14
                        height: 22
                        radius: 11
                        color: sel ? root.fillHover : (hsMa.containsMouse ? root.fillIdle : "transparent")
                        border.color: sel ? root.seal : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: hsTabRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "style"
                                font.pixelSize: 12
                                color: parent.parent.sel ? root.seal : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Hearthstone"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: parent.parent.sel ? Font.Bold : Font.Normal
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: hsMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switcher.setStyle("hearthstone")
                        }
                    }

                    // Carousel (Coverflow)
                    Rectangle {
                        property bool sel: switcher.currentPickerStyle === "carousel"
                        width: cfTabRow.width + 14
                        height: 22
                        radius: 11
                        color: sel ? root.fillHover : (cfMa.containsMouse ? root.fillIdle : "transparent")
                        border.color: sel ? root.seal : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            id: cfTabRow
                            anchors.centerIn: parent
                            spacing: 4
                            IconText {
                                text: "view_array"
                                font.pixelSize: 12
                                color: parent.parent.sel ? root.seal : root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Coverflow"
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: parent.parent.sel ? Font.Bold : Font.Normal
                                color: root.ink
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: cfMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: switcher.setStyle("carousel")
                        }
                    }
                }
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
                    opacity: 0.7
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
    // ── MAIN STAGE AREA: Hosting the 3 visual switchers ──────
    // ─────────────────────────────────────────────────────────
    Item {
        id: stageContainer
        anchors.top: headerBar.bottom
        anchors.topMargin: 4
        anchors.bottom: footerBar.top
        anchors.bottomMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
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

            readonly property int focusedW: 340
            readonly property int focusedH: 192
            readonly property int peekW: 56
            readonly property int stripW: 18
            readonly property int gap: 6

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
                    readonly property bool near: Math.abs(relIdx) <= 6

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
                        radius: 8
                        color: root.frameWeak
                        border.width: focused ? 2 : 1
                        border.color: focused ? root.seal : root.frameWeak
                        clip: true

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
                            color: root.paper
                            opacity: tCard.focused ? 0 : (Math.abs(tCard.relIdx) === 1 ? 0.32 : 0.55)
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        // Label overlay on peek cards
                        Rectangle {
                            visible: Math.abs(tCard.relIdx) === 1
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 24
                            color: Qt.rgba(0, 0, 0, 0.6)
                            Text {
                                anchors.centerIn: parent
                                text: tCard.entry ? tCard.entry.label : ""
                                color: "#ffffff"
                                font.family: root.barFont
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                width: parent.width - 6
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // Red seal stroke under focused card
                    Rectangle {
                        visible: tCard.focused
                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 48; height: 3; radius: 1.5
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

            readonly property int cardW: 130
            readonly property int cardH: 180
            readonly property int stepX: 46
            readonly property real spreadDeg: 4.5
            readonly property int focusLift: 18
            readonly property real focusScale: 1.12

            Repeater {
                model: switcher.filtered.length

                delegate: Item {
                    id: hCard
                    required property int index
                    readonly property var entry: switcher.filtered[index] || null
                    readonly property int relIdx: index - switcher.selFilt
                    readonly property bool focused: relIdx === 0
                    readonly property bool nearby: Math.abs(relIdx) <= 5

                    width: hsStage.cardW
                    height: hsStage.cardH
                    visible: nearby
                    transformOrigin: Item.Bottom

                    x: (hsStage.width - hsStage.cardW) / 2 + relIdx * hsStage.stepX
                    y: (hsStage.height - hsStage.cardH) - (focused ? hsStage.focusLift : 0) - 10
                    rotation: relIdx * hsStage.spreadDeg
                    scale: focused ? hsStage.focusScale : 1.0
                    z: focused ? 100 : 50 - Math.min(Math.abs(relIdx), 30)

                    Behavior on x        { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on y        { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on scale    { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "#18181b"
                        border.width: focused ? 2.5 : 1
                        border.color: focused ? root.seal : root.frameWeak
                        clip: true

                        Image {
                            anchors.fill: parent
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
                            height: 48
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.78) }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            text: hCard.entry ? hCard.entry.label : ""
                            color: "#ffffff"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        // Dim overlay on non-focused cards
                        Rectangle {
                            anchors.fill: parent
                            color: "black"
                            opacity: hCard.focused ? 0 : Math.min(0.55, 0.25 + Math.abs(hCard.relIdx) * 0.08)
                            Behavior on opacity { NumberAnimation { duration: 180 } }
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
        // STYLE 3: CAROUSEL (Coverflow with Skewed Side Slices)
        // ═════════════════════════════════════════════════════
        Item {
            id: cfStage
            visible: switcher.currentPickerStyle === "carousel"
            anchors.fill: parent

            readonly property int expandedW: 340
            readonly property int expandedH: 192
            readonly property int sliceW: 58
            readonly property int sliceH: 172
            readonly property int sliceGap: -16
            readonly property int skew: 18

            readonly property real previewX: (width - expandedW) / 2
            readonly property real itemStep: sliceW + sliceGap

            Repeater {
                model: switcher.filtered.length

                delegate: Item {
                    id: cfSlice
                    required property int index
                    readonly property var entry: switcher.filtered[index] || null
                    readonly property int relIdx: index - switcher.selFilt
                    readonly property bool selected: relIdx === 0
                    readonly property bool nearby: Math.abs(relIdx) <= 6

                    visible: nearby
                    width: selected ? cfStage.expandedW : cfStage.sliceW
                    height: selected ? cfStage.expandedH : cfStage.sliceH
                    anchors.verticalCenter: parent.verticalCenter
                    x: relIdx === 0
                        ? cfStage.previewX
                        : (relIdx < 0
                            ? cfStage.previewX - (Math.abs(relIdx) * cfStage.itemStep)
                            : cfStage.previewX + cfStage.expandedW + cfStage.sliceGap + (relIdx - 1) * cfStage.itemStep)
                    z: selected ? 100 : 50 - Math.min(Math.abs(relIdx), 30)

                    Behavior on x     { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

                    readonly property real skAbs: Math.abs(cfStage.skew)
                    readonly property real topLeft: cfStage.skew >= 0 ? skAbs : 0
                    readonly property real topRight: cfStage.skew >= 0 ? width : width - skAbs
                    readonly property real botRight: cfStage.skew >= 0 ? width - skAbs : width
                    readonly property real botLeft: cfStage.skew >= 0 ? 0 : skAbs

                    Rectangle {
                        anchors.fill: parent
                        radius: selected ? 8 : 4
                        color: root.frameWeak
                        border.width: selected ? 2.5 : 1
                        border.color: selected ? root.seal : root.frameWeak
                        clip: true

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
                            color: root.paper
                            opacity: cfSlice.selected ? 0 : 0.45
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
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

        // ── Floating Left & Right Chevrons ──
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: leftChevMa.containsMouse ? root.fillHover : root.fillIdle
            border.color: root.frameWeak; border.width: 1
            opacity: leftChevMa.containsMouse ? 1.0 : 0.6
            z: 200

            IconText {
                anchors.centerIn: parent
                text: "chevron_left"
                font.pixelSize: 20
                color: root.ink
            }

            MouseArea {
                id: leftChevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switcher.moveSel(-1)
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: rightChevMa.containsMouse ? root.fillHover : root.fillIdle
            border.color: root.frameWeak; border.width: 1
            opacity: rightChevMa.containsMouse ? 1.0 : 0.6
            z: 200

            IconText {
                anchors.centerIn: parent
                text: "chevron_right"
                font.pixelSize: 20
                color: root.ink
            }

            MouseArea {
                id: rightChevMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: switcher.moveSel(1)
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // ── BOTTOM INFO & APPLY BAR ──────────────────────────────
    // ─────────────────────────────────────────────────────────
    Item {
        id: footerBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 38
        z: 20

        // Left: Title, Author/Repo, Palette Swatches
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // Name
            Text {
                text: switcher.focusedEntry ? switcher.focusedEntry.label : ""
                font.family: root.barFont
                font.pixelSize: 14
                font.weight: Font.Bold
                color: root.ink
                anchors.verticalCenter: parent.verticalCenter
            }

            // Theme metadata: Author & Repo
            Item {
                visible: switcher.isThemeMode && switcher.selMeta && switcher.selMeta.author
                width: metaRow.implicitWidth
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: metaRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        height: 20
                        width: authorTxt.implicitWidth + 12
                        radius: 10
                        color: root.fillIdle
                        border.color: root.frameWeak; border.width: 1

                        Text {
                            id: authorTxt
                            anchors.centerIn: parent
                            text: "@" + (switcher.selMeta ? switcher.selMeta.author : "")
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.ink
                            opacity: 0.8
                        }
                    }

                    // Clickable Repo link
                    Rectangle {
                        visible: switcher.selMeta && switcher.selMeta.repo
                        height: 20
                        width: repoRow.implicitWidth + 10
                        radius: 10
                        color: repoMa.containsMouse ? root.fillHover : root.fillIdle
                        border.color: root.frameWeak; border.width: 1

                        Row {
                            id: repoRow
                            anchors.centerIn: parent
                            spacing: 3
                            IconText {
                                text: "code"
                                font.pixelSize: 11
                                color: root.seal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Repo"
                                font.family: root.barFont
                                font.pixelSize: 10
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
                spacing: 4

                readonly property var colors: (switcher.selMeta && switcher.selMeta.palette)
                    ? switcher.selMeta.palette.split(",") : []

                Repeater {
                    model: parent.colors

                    delegate: Rectangle {
                        required property string modelData
                        width: 11; height: 11; radius: 5.5
                        color: modelData
                        border.color: Qt.rgba(0, 0, 0, 0.25)
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
                opacity: 0.55
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Right: Item counter and Apply Button
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            // Counter (e.g. "4 / 22")
            Text {
                visible: switcher.filtered.length > 0
                text: (switcher.selFilt + 1) + " / " + switcher.filtered.length
                font.family: root.barFont
                font.pixelSize: 11
                color: root.ink
                opacity: 0.5
                anchors.verticalCenter: parent.verticalCenter
            }

            // Apply Button
            Rectangle {
                id: applyBtn
                height: 30
                width: applyRow.implicitWidth + 20
                radius: 15
                color: switcher.justApplied ? "#22c55e" : (applyMa.containsMouse ? Qt.lighter(root.seal, 1.12) : root.seal)
                scale: applyMa.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 180 } }

                Row {
                    id: applyRow
                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        text: switcher.justApplied ? "check" : (switcher.isThemeMode ? "palette" : "wallpaper")
                        font.pixelSize: 14
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: switcher.justApplied
                            ? "Applied ✓"
                            : (switcher.isThemeMode ? "Apply Theme (↵)" : "Apply Wallpaper (↵)")
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: "#ffffff"
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

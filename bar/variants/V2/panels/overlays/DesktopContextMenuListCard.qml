import QtQuick
import ".."
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../modules"
import "../../motion"

// ── UNIFIED BORDERLESS M3 EXPRESSIVE DESKTOP CONTEXT MENU ──
Rectangle {
    id: listMenuCard

    required property var desktopMenu
    required property var root
    required property var mprisSel
    required property var mprisArt

    readonly property color paperCol: (root && root.paper) ? root.paper : "#111318"
    readonly property color inkCol: (root && root.ink) ? root.ink : "#ffffff"
    readonly property color sealCol: (root && root.seal) ? root.seal : "#22d3ee"
    readonly property color bgCol: (root && root.bg) ? root.bg : "#141818"
    readonly property string barFontFam: (root && root.barFont) ? root.barFont : "Google Sans"
    readonly property color onSealCol: {
        var luma = sealCol.r * 0.299 + sealCol.g * 0.587 + sealCol.b * 0.114
        return luma > 0.55 ? "#121212" : "#ffffff"
    }

    x: Math.max(20, Math.min(desktopMenu.menuX, desktopMenu.width - width - 20))
    y: Math.max(20, Math.min(desktopMenu.menuY, desktopMenu.height - height - 20))
    width: 288
    height: menuCol.implicitHeight + 24
    radius: 26
    border.width: 0
    antialiasing: true
    color: bgCol

    property real menuReveal: desktopMenu.menuVisible ? 1.0 : 0.0
    opacity: menuReveal
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    property real staggeredReveal: desktopMenu.menuVisible ? 5 : 0
    Behavior on staggeredReveal {
        NumberAnimation { duration: desktopMenu.menuVisible ? 220 : 0 }
    }

    PillShadow { theme: root }

    property var wallpaperList: []
    property string activeWallpaper: ""

    Process {
        command: ["bash", "-c", "readlink -f " + (root.currentBackgroundPath || "")]
        stdout: StdioCollector {
            onStreamFinished: { listMenuCard.activeWallpaper = this.text.trim() }
        }
        running: desktopMenu.menuVisible
    }

    Process {
        id: wpScanProc
        command: ["bash", "-c",
                "find -L " + (root.wallpaperSourcePaths || []).join(" ") + " -maxdepth 1 -type f " +
                "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
                "-exec stat -c '%Y %n' {} + 2>/dev/null | sort -nr | cut -d' ' -f2-"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split('\n').map(s => s.trim()).filter(s => s.length > 0)
                listMenuCard.wallpaperList = lines
            }
        }
        running: desktopMenu.menuVisible
    }

    // Swallow clicks on the card background so it doesn't dismiss
    MouseArea {
        anchors.fill: parent
        onClicked: {}
    }

    Column {
        id: menuCol
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        // ══════════════════════════════════════════════════════════════
        // ── 1. HERO HEADER (Media Atmospheric Banner OR Greeting) ────
        // ══════════════════════════════════════════════════════════════
        ClippingRectangle {
            id: heroSection
            property int staggerIndex: 0
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: heroSection.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: mprisSel.active ? 76 : (greetingCol.implicitHeight + 20)
            radius: 18
            border.width: 0
            color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, 0.055)

            readonly property string artSrc: (mprisArt && mprisArt.source)
                ? mprisArt.source
                : ((mprisSel.player && mprisSel.player.trackArtUrl) ? mprisSel.player.trackArtUrl : "")

            // Blurred album art backdrop when media is active
            Image {
                anchors.fill: parent
                visible: mprisSel.active && heroSection.artSrc !== ""
                source: heroSection.artSrc
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: 0.45
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.85
                    blurMax: 40
                    brightness: -0.25
                }
            }

            // Greeting + Quote when no media is active
            Column {
                id: greetingCol
                visible: !mprisSel.active
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 4

                Text {
                    width: parent.width
                    text: desktopMenu.currentGreeting.toUpperCase()
                    color: listMenuCard.sealCol
                    font.family: listMenuCard.barFontFam
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: desktopMenu.currentQuote
                    color: listMenuCard.inkCol
                    opacity: 0.85
                    font.family: listMenuCard.barFontFam
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Media Hero Row when media is active
            Item {
                visible: mprisSel.active
                anchors.fill: parent
                anchors.margins: 10

                ClippingRectangle {
                    id: heroArt
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 52
                    radius: 13
                    color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, 0.12)

                    Image {
                        anchors.fill: parent
                        source: heroSection.artSrc
                        fillMode: Image.PreserveAspectCrop
                        visible: heroSection.artSrc !== ""
                        asynchronous: true
                    }

                    IconText {
                        anchors.centerIn: parent
                        visible: heroSection.artSrc === ""
                        text: "music_note"
                        color: listMenuCard.sealCol
                        font.pixelSize: 22
                    }
                }

                Column {
                    anchors.left: heroArt.right
                    anchors.leftMargin: 10
                    anchors.right: heroControls.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: mprisSel.player ? (mprisSel.player.trackTitle || "Unknown Track") : ""
                        color: listMenuCard.inkCol
                        font.family: listMenuCard.barFontFam
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: mprisSel.player ? (mprisSel.player.trackArtist || "Unknown Artist") : ""
                        color: listMenuCard.inkCol
                        opacity: 0.72
                        font.family: listMenuCard.barFontFam
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: heroControls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        border.width: 0
                        color: prevMa.containsMouse
                            ? Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, 0.16)
                            : "transparent"
                        SpringPress { pressScale: 0.86; pushReach: 60; pushDistance: 4 }
                        IconText { anchors.centerIn: parent; text: "skip_previous"; color: listMenuCard.inkCol; font.pixelSize: 16 }
                        MouseArea { id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (mprisSel.player) mprisSel.player.previous() }
                    }

                    Rectangle {
                        width: 32; height: 32; radius: mprisSel.playing ? 11 : 16
                        anchors.verticalCenter: parent.verticalCenter
                        border.width: 0
                        color: listMenuCard.sealCol
                        Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                        SpringPress { pressScale: 0.88; pushReach: 70; pushDistance: 5 }
                        IconText { anchors.centerIn: parent; text: mprisSel.playing ? "pause" : "play_arrow"; color: listMenuCard.onSealCol; font.pixelSize: 18 }
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (mprisSel.player) mprisSel.player.togglePlaying() }
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        anchors.verticalCenter: parent.verticalCenter
                        border.width: 0
                        color: nextMa.containsMouse
                            ? Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, 0.16)
                            : "transparent"
                        SpringPress { pressScale: 0.86; pushReach: 60; pushDistance: 4 }
                        IconText { anchors.centerIn: parent; text: "skip_next"; color: listMenuCard.inkCol; font.pixelSize: 16 }
                        MouseArea { id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (mprisSel.player) mprisSel.player.next() }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // ── 2. AI ASSISTANTS DUO (Gemini + Claude) ───────────────────
        // ══════════════════════════════════════════════════════════════
        Row {
            id: aiRowBlock
            property int staggerIndex: 1
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: aiRowBlock.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: 38
            spacing: 8

            Repeater {
                model: [
                    { id: "gemini", name: "Gemini", brand: "#4285F4", url: "https://gemini.google.com", icon: Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/gemini_final.svg" },
                    { id: "claude", name: "Claude", brand: "#D97757", url: "https://claude.ai", icon: Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/claude.svg" }
                ]
                delegate: Rectangle {
                    id: aiBtn
                    required property var modelData
                    width: Math.floor((parent.width - 8) / 2)
                    height: 38
                    radius: aiBtnMa.pressed ? 12 : (aiBtnMa.containsMouse ? 14 : 18)
                    border.width: 0
                    antialiasing: true
                    color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, aiBtnMa.containsMouse ? 0.12 : 0.055)
                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SpringPress { pressScale: 0.92; pushReach: 120; pushDistance: 7 }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 15; height: 15
                            fillMode: Image.PreserveAspectFit
                            source: aiBtn.modelData.icon
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: aiBtnMa.containsMouse ? aiBtn.modelData.brand : listMenuCard.inkCol
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: aiBtn.modelData.name
                            color: listMenuCard.inkCol
                            font.family: listMenuCard.barFontFam
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        id: aiBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            desktopMenu.menuVisible = false
                            Quickshell.execDetached(["xdg-open", aiBtn.modelData.url])
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // ── 3. QUICK APPS DOCK (5 Expressive Morphing Orbs) ──────────
        // ══════════════════════════════════════════════════════════════
        Row {
            id: appsRow
            property int staggerIndex: 2
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: appsRow.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: 40
            spacing: 8

            Repeater {
                model: [
                    { id: "files", name: "Files", mIcon: "folder", svg: "", brand: "#60a5fa", cmd: ["nautilus"] },
                    { id: "zen", name: "Zen Browser", mIcon: "", svg: Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/zen.svg", brand: "#E85D04", cmd: ["zen-browser"] },
                    { id: "whatsapp", name: "WhatsApp", mIcon: "", svg: Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/whatsapp.svg", brand: "#25D366", cmd: ["omarchy-launch-webapp", "https://web.whatsapp.com/"] },
                    { id: "spotify", name: "Spotify", mIcon: "", svg: Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/spotify.svg", brand: "#1DB954", cmd: ["spotify"] },
                    { id: "localsend", name: "LocalSend", mIcon: "share", svg: "", brand: "#22d3ee", cmd: ["localsend"] }
                ]
                delegate: Rectangle {
                    id: appBtn
                    required property var modelData
                    width: Math.floor((appsRow.width - 32) / 5)
                    height: 40
                    radius: appBtnMa.pressed ? 11 : (appBtnMa.containsMouse ? 14 : 20)
                    border.width: 0
                    antialiasing: true
                    color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, appBtnMa.containsMouse ? 0.13 : 0.055)
                    Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    SpringPress { pressScale: 0.86; pushReach: 100; pushDistance: 6 }

                    IconText {
                        anchors.centerIn: parent
                        visible: appBtn.modelData.mIcon !== ""
                        text: appBtn.modelData.mIcon
                        color: appBtnMa.containsMouse ? appBtn.modelData.brand : listMenuCard.inkCol
                        font.pixelSize: 18
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Image {
                        anchors.centerIn: parent
                        visible: appBtn.modelData.svg !== ""
                        width: 17; height: 17
                        fillMode: Image.PreserveAspectFit
                        source: appBtn.modelData.svg
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            colorizationColor: appBtnMa.containsMouse ? appBtn.modelData.brand : listMenuCard.inkCol
                        }
                    }

                    TooltipMixin {
                        id: appTip
                        root: desktopMenu.root
                        owner: appBtn
                        text: appBtn.modelData.name
                    }

                    MouseArea {
                        id: appBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: appTip.show()
                        onExited: appTip.hide()
                        onClicked: {
                            appTip.hide()
                            desktopMenu.menuVisible = false
                            Quickshell.execDetached(appBtn.modelData.cmd)
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // ── 4. WALLPAPER CAROUSEL STRIP (Borderless Morphing Capsules) ─
        // ══════════════════════════════════════════════════════════════
        Rectangle {
            id: wpSection
            property int staggerIndex: 3
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: wpSection.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: 76
            radius: 18
            border.width: 0
            color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, 0.055)
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: wpRow.implicitWidth
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: wpRow
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: listMenuCard.visible ? listMenuCard.wallpaperList : []
                        ClippingRectangle {
                            required property string modelData
                            readonly property bool isCurrent: {
                                var currentBase = listMenuCard.activeWallpaper.split('/').pop()
                                var thisBase = modelData.split('/').pop()
                                return currentBase === thisBase && currentBase !== undefined && currentBase.length > 0
                            }

                            width: isCurrent ? 96 : 34
                            height: 60
                            radius: isCurrent ? 14 : 17
                            color: "transparent"

                            Behavior on width { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.5 } }
                            Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }

                            Image {
                                anchors.fill: parent
                                source: "file://" + modelData
                                sourceSize.width: 192
                                sourceSize.height: 120
                                asynchronous: true
                                cache: false
                                fillMode: Image.PreserveAspectCrop
                            }

                            Rectangle {
                                visible: isCurrent
                                anchors.centerIn: parent
                                width: 26; height: 26; radius: 13
                                border.width: 0
                                color: listMenuCard.sealCol
                                IconText {
                                    anchors.centerIn: parent
                                    text: "check"
                                    color: listMenuCard.onSealCol
                                    font.pixelSize: 15
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    listMenuCard.activeWallpaper = modelData
                                    Quickshell.execDetached(["bash", "-c", "omarchy-theme-bg-set '" + modelData.replace(/'/g, "'\\''") + "'"])
                                }
                            }
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // ── 5. SYSTEM ACTIONS FOOTER (Theme + Refresh Rate) ──────────
        // ══════════════════════════════════════════════════════════════
        Row {
            id: sysRow
            property int staggerIndex: 4
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: sysRow.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: 40
            spacing: 8

            // Theme Picker Pill
            Rectangle {
                width: Math.round((parent.width - 8) * 0.56)
                height: 40
                radius: themeMa.pressed ? 12 : (themeMa.containsMouse ? 14 : 18)
                border.width: 0
                antialiasing: true
                color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, themeMa.containsMouse ? 0.12 : 0.055)
                Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                SpringPress { pressScale: 0.92; pushReach: 120; pushDistance: 7 }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 8

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "palette"
                        color: listMenuCard.sealCol
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 24
                        text: (function(str){
                            if (!str) return "Theme"
                            return str.replace(/[-_]+/g, " ").replace(/\b\w/g, function(l){ return l.toUpperCase() })
                        })(root ? root.currentThemeName : "")
                        color: listMenuCard.inkCol
                        font.family: listMenuCard.barFontFam
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: themeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        desktopMenu.menuVisible = false
                        if (root) root.ipcOpenPicker("theme")
                    }
                }
            }

            // Refresh Rate Pill
            Rectangle {
                width: parent.width - Math.round((parent.width - 8) * 0.56) - 8
                height: 40
                radius: hzMa.pressed ? 12 : (hzMa.containsMouse ? 14 : 18)
                border.width: 0
                antialiasing: true
                color: Qt.rgba(listMenuCard.inkCol.r, listMenuCard.inkCol.g, listMenuCard.inkCol.b, hzMa.containsMouse ? 0.12 : 0.055)
                Behavior on radius { SpringAnimation { spring: Motion.spatialFastSpring; damping: Motion.spatialFastDamping; epsilon: 0.1 } }
                Behavior on color { ColorAnimation { duration: 150 } }

                SpringPress { pressScale: 0.92; pushReach: 120; pushDistance: 7 }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "speed"
                        color: listMenuCard.sealCol
                        font.pixelSize: 16
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: desktopMenu.currentRefresh
                        color: listMenuCard.inkCol
                        font.family: listMenuCard.barFontFam
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }

                MouseArea {
                    id: hzMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        desktopMenu.menuVisible = false
                        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/bin/toggle-refresh-rate"])
                    }
                }
            }
        }
    }
}

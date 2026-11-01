import QtQuick
import ".."
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import "../../modules"

Item {
    id: listMenuCard

    required property var desktopMenu
    required property var root
    required property var mprisSel

    x: Math.max(20, Math.min(desktopMenu.menuX, desktopMenu.width - width - 20))
    y: Math.max(20, Math.min(desktopMenu.menuY, desktopMenu.height - height - 20))
    width: 250
    height: listMenuColumn.implicitHeight
    
    property real listReveal: desktopMenu.menuVisible ? 1 : 0
    Behavior on listReveal { NumberAnimation { duration: 350 } }
    visible: listReveal > 0.001 && desktopMenu.isListMode
    
    property real staggeredReveal: desktopMenu.menuVisible ? 5 : 0
    Behavior on staggeredReveal {
        NumberAnimation { duration: desktopMenu.menuVisible ? 200 : 0 }
    }
    
    property bool aiExpanded: false
    property bool appsExpanded: false
    
    property var wallpaperList: []
    property string activeWallpaper: ""
    
    Process {
        command: ["bash", "-c", "readlink -f " + (root.currentBackgroundPath || "")]
        stdout: StdioCollector {
            onStreamFinished: { listMenuCard.activeWallpaper = this.text.trim(); }
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
                listMenuCard.wallpaperList = lines;
            }
        }
        running: desktopMenu.menuVisible
    }

    Column {
        id: listMenuColumn
        width: parent.width
        spacing: 3

        // Top Pill: Quote / Media Section (staggerIndex 0)
        Rectangle {
            id: quotePill
            property int staggerIndex: 0
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: quotePill.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: listQuoteLayout.implicitHeight + 24
            topLeftRadius: 24
            topRightRadius: 24
            bottomLeftRadius: 8
            bottomRightRadius: 8
            color: root.bg
            border.color: root.panelOuterBorderColor
            border.width: root.panelOuterBorderW
            PillShadow { theme: root }

            Column {
                id: listQuoteLayout
                anchors.top: parent.top
                anchors.topMargin: 12
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                spacing: 6
                
                UiText {
                    text: mprisSel.active ? (mprisSel.player.trackTitle || "Unknown Track") : desktopMenu.currentGreeting
                    color: root.ink
                    font.family: "Genova"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    width: parent.width
                    wrapMode: mprisSel.active ? Text.NoWrap : Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                UiText {
                    text: mprisSel.active ? (mprisSel.player.trackArtist || "Unknown Artist") : desktopMenu.currentQuote
                    color: root.sumiHi
                    font.family: "Genova"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    width: parent.width
                    wrapMode: mprisSel.active ? Text.NoWrap : Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 24
                    visible: mprisSel.active
                    topPadding: 8
                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "skip_previous"
                        font.pixelSize: 16
                        color: root.ink
                        opacity: listPrevMouse.containsMouse ? 1 : 0.6
                        MouseArea { id: listPrevMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (mprisSel.player) mprisSel.player.previous() }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44; height: 24; radius: 12
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, listPlayMouse.containsMouse ? 0.12 : 0.06)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        IconText {
                            anchors.centerIn: parent
                            text: mprisSel.playing ? "pause" : "play_arrow"
                            font.pixelSize: 16
                            color: root.ink
                        }
                        MouseArea { id: listPlayMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (mprisSel.player) mprisSel.player.togglePlaying() }
                    }
                    IconText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "skip_next"
                        font.pixelSize: 16
                        color: root.ink
                        opacity: listNextMouse.containsMouse ? 1 : 0.6
                        MouseArea { id: listNextMouse; anchors.fill: parent; hoverEnabled: true; onClicked: if (mprisSel.player) mprisSel.player.next() }
                    }
                }
            }
        }

        // AI Pill (staggerIndex 1)
        Rectangle {
            id: aiPill
            property int staggerIndex: 1
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: aiPill.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: 48
            clip: true
            topLeftRadius: 8; topRightRadius: 8; bottomLeftRadius: 8; bottomRightRadius: 8
            color: root.bg; border.color: root.panelOuterBorderColor; border.width: root.panelOuterBorderW
            
            PillShadow { theme: root }

            Row {
                id: aiRow
                anchors.centerIn: parent
                width: parent.width - 16
                height: 32
                spacing: 8

                Repeater {
                    model: [5, 6]
                    Rectangle {
                        id: aiBtn
                        required property int modelData
                        readonly property int idx: modelData
                        readonly property string appName: idx === 5 ? "Gemini" : "Claude"
                        readonly property string brandColor: idx === 5 ? "#4285F4" : "#D97757"

                        width: Math.floor((aiRow.width - aiRow.spacing) / 2)
                        height: 32
                        radius: 8
                        color: aiBtnMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                        scale: aiBtnMouse.pressed ? 0.95 : (aiBtnMouse.containsMouse ? 1.02 : 1.0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Item {
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    fillMode: Image.PreserveAspectFit
                                    source: idx === 5 
                                        ? Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/gemini_final.svg" 
                                        : Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/claude.svg"
                                    layer.enabled: true
                                    layer.effect: MultiEffect { 
                                        colorization: 1.0
                                        colorizationColor: aiBtnMouse.containsMouse ? aiBtn.brandColor : root.ink
                                    }
                                }
                            }

                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: aiBtn.appName
                                color: root.ink
                                font.family: "Genova"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                            }
                        }

                        TooltipMixin {
                            id: aiTip
                            root: desktopMenu.root
                            owner: aiBtn
                            text: aiBtn.appName
                        }

                        MouseArea {
                            id: aiBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: aiTip.show()
                            onExited: aiTip.hide()
                            onClicked: {
                                aiTip.hide()
                                desktopMenu.menuVisible = false
                                Quickshell.execDetached(["xdg-open", idx === 5 ? "https://gemini.google.com" : "https://claude.ai"])
                            }
                        }
                    }
                }
            }
        }

        // Quick Apps Pill (staggerIndex 2)
        Rectangle {
            id: appsPill
            property int staggerIndex: 2
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: appsPill.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: 48
            clip: true
            topLeftRadius: 8; topRightRadius: 8; bottomLeftRadius: 8; bottomRightRadius: 8
            color: root.bg; border.color: root.panelOuterBorderColor; border.width: root.panelOuterBorderW
            
            PillShadow { theme: root }

            Row {
                id: appsRow
                anchors.centerIn: parent
                width: parent.width - 16
                height: 32
                spacing: 6

                Repeater {
                    model: [10, 9, 0, 1, 2]
                    Rectangle {
                        id: appBtn
                        required property int modelData
                        readonly property int idx: modelData

                        readonly property string appName: {
                            switch(idx) {
                                case 0: return "WhatsApp"
                                case 1: return "Spotify"
                                case 2: return "LocalSend"
                                case 9: return "Zen Browser"
                                case 10: return "Files"
                                default: return ""
                            }
                        }

                        readonly property string brandColor: {
                            switch(idx) {
                                case 0: return "#25D366"
                                case 1: return "#1DB954"
                                case 2: return (root && root.color06) ? root.color06 : "#22d3ee"
                                case 9: return "#E85D04"
                                case 10: return (root && root.color04) ? root.color04 : "#60a5fa"
                                default: return root.ink
                            }
                        }

                        width: Math.floor((appsRow.width - (5 - 1) * appsRow.spacing) / 5)
                        height: 32
                        radius: 8
                        color: appBtnMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                        scale: appBtnMouse.pressed ? 0.92 : (appBtnMouse.containsMouse ? 1.08 : 1.0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Item {
                            anchors.centerIn: parent
                            width: 18
                            height: 18

                            IconText {
                                anchors.centerIn: parent
                                visible: idx === 2 || idx === 10
                                text: idx === 2 ? "share" : (idx === 10 ? "folder" : "")
                                color: appBtnMouse.containsMouse ? appBtn.brandColor : root.ink
                                font.pixelSize: 17
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Image {
                                anchors.centerIn: parent
                                visible: idx === 0 || idx === 1 || idx === 9
                                width: 16
                                height: 16
                                fillMode: Image.PreserveAspectFit
                                source: idx === 0 
                                    ? Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/whatsapp.svg" 
                                    : (idx === 1 
                                        ? Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/spotify.svg" 
                                        : Quickshell.env("HOME") + "/.config/quickshell/bar/assets/icons/zen.svg")
                                layer.enabled: true
                                layer.effect: MultiEffect { 
                                    colorization: 1.0
                                    colorizationColor: appBtnMouse.containsMouse ? appBtn.brandColor : root.ink
                                }
                            }
                        }

                        TooltipMixin {
                            id: appTip
                            root: desktopMenu.root
                            owner: appBtn
                            text: appBtn.appName
                        }

                        MouseArea {
                            id: appBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: appTip.show()
                            onExited: appTip.hide()
                            onClicked: {
                                appTip.hide()
                                desktopMenu.menuVisible = false
                                switch(idx) {
                                    case 0: Quickshell.execDetached(["omarchy-launch-webapp", "https://web.whatsapp.com/"]); break;
                                    case 1: Quickshell.execDetached(["spotify"]); break;
                                    case 2: Quickshell.execDetached(["localsend"]); break;
                                    case 9: Quickshell.execDetached(["zen-browser"]); break;
                                    case 10: Quickshell.execDetached(["nautilus"]); break;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Wallpaper Picker Pill (staggerIndex 3)
        Rectangle {
            id: wpPill
            property int staggerIndex: 3
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: wpPill.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: wpCol.implicitHeight + 16
            clip: true
            topLeftRadius: 8; topRightRadius: 8; bottomLeftRadius: 8; bottomRightRadius: 8
            color: root.bg; border.color: root.panelOuterBorderColor; border.width: root.panelOuterBorderW
            
            PillShadow { theme: root }

            Column {
                id: wpCol
                anchors.top: parent.top; anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16
                // removed spacing and title
                
                Flickable {
                    width: parent.width - 16 // slightly wider area
                    height: 64
                    anchors.horizontalCenter: parent.horizontalCenter
                    contentWidth: wpRow.implicitWidth
                    clip: true
                    interactive: true

                    Row {
                        id: wpRow
                        spacing: 8
                        anchors.verticalCenter: parent.verticalCenter
                        
                        Repeater {
                            model: listMenuCard.visible ? listMenuCard.wallpaperList : []
                            ClippingRectangle {
                                width: isCurrent ? 96 : 32
                                height: 64
                                radius: isCurrent ? 14 : 16
                                color: "transparent"
                                
                                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                                Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                                
                                required property string modelData
                                property bool isCurrent: {
                                    var currentBase = listMenuCard.activeWallpaper.split('/').pop();
                                    var thisBase = modelData.split('/').pop();
                                    return currentBase === thisBase && currentBase !== undefined && currentBase.length > 0;
                                }
                                
                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData
                                    sourceSize.width: 192
                                    sourceSize.height: 128
                                    asynchronous: true
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                    opacity: 1.0
                                }
                                
                                Rectangle {
                                    visible: isCurrent
                                    anchors.centerIn: parent
                                    width: 28; height: 28; radius: 14
                                    color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.85)
                                    IconText {
                                        anchors.centerIn: parent
                                        text: "check"
                                        color: root.ink
                                        font.pixelSize: 16
                                    }
                                }
                                
                                MouseArea {
                                    id: wpItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        listMenuCard.activeWallpaper = modelData; // visually update instantly
                                        Quickshell.execDetached(["bash", "-c", "omarchy-theme-bg-set '" + modelData.replace(/'/g, "'\\''") + "'"])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // System Pill (staggerIndex 4)
        Rectangle {
            id: sysPill
            property int staggerIndex: 4
            property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
            opacity: isRevealed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            scale: isRevealed ? 1 : 0.95
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            property real yOffset: isRevealed ? 0 : -15
            Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
            transform: Translate { y: sysPill.yOffset }
            transformOrigin: Item.Top

            width: parent.width
            height: sysCol.implicitHeight + 16
            clip: true
            topLeftRadius: 8; topRightRadius: 8; bottomLeftRadius: 24; bottomRightRadius: 24
            color: root.bg; border.color: root.panelOuterBorderColor; border.width: root.panelOuterBorderW
            
            PillShadow { theme: root }

            Column {
                id: sysCol
                anchors.top: parent.top; anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 16

                Repeater {
                    model: [3, 8, 7]
                    Rectangle {
                        id: sysItem
                        required property int modelData; property int idx: modelData
                        width: parent.width; height: 32; radius: 10
                        color: sysItemMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            Item {
                                width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                                IconText {
                                    anchors.centerIn: parent
                                    text: idx === 3 ? "palette" : (idx === 8 ? "speed" : "radio_button_checked")
                                    color: root.ink; font.pixelSize: 16
                                }
                            }
                            UiText { 
                                anchors.verticalCenter: parent.verticalCenter; color: root.ink; font.family: "Genova"; font.pixelSize: 11; font.weight: Font.Medium 
                                text: idx === 3 ? "Theme" : (idx === 8 ? "Refresh Rate" : "Radial Menu")
                            }
                        }
                        
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: idx === 8 || idx === 3
                            width: statusText.implicitWidth + 16
                            height: 20
                            radius: 10
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            
                            UiText {
                                id: statusText
                                anchors.centerIn: parent
                                text: idx === 8 ? desktopMenu.currentRefresh : (idx === 3 ? (function(str){
                                    if(!str) return "";
                                    return str.replace(/[-_]+/g, " ").replace(/\b\w/g, function(l){ return l.toUpperCase(); });
                                })(root.currentThemeName) : "")
                                color: root.ink
                                font.family: "Genova"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                        }
                        
                        MouseArea {
                            id: sysItemMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                if (idx === 7) {
                                    if (root) root.desktopMenuListMode = false;
                                    desktopMenu.isListMode = false;
                                    return;
                                }
                                desktopMenu.menuVisible = false;
                                switch(idx) {
                                    case 3: root.ipcOpenPicker("theme"); break;
                                    case 8: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/bin/toggle-refresh-rate"]); break;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

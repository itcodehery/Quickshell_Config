import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io
import "../modules"

PanelWindow {
    id: desktopMenu
    required property var root
    required property var targetScreen

    screen: targetScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "omarchy-desktop-menu"

    property bool menuVisible: false
    property bool isListMode: false
    property real menuX: 0
    property real menuY: 0
    
    property real reveal: menuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: menuVisible ? 160 : 120
            easing.type: menuVisible ? Easing.OutCubic : Easing.InCubic
        }
    }

    property real animatedReveal: 0
    Behavior on animatedReveal {
        NumberAnimation {
            duration: menuVisible ? 400 : 0
            easing.type: Easing.OutBack; easing.overshoot: 1.2
        }
    }

    property string currentRefresh: "Unknown"
    property string currentQuote: "Keep pushing forward."
    property string currentGreeting: "Hello"
    
    property var levels: [0,0,0,0,0,0,0,0,0,0,0]
    
    MprisSelect { id: mprisSel }
    readonly property bool playing: mprisSel.playing

    Process {
        id: cavaProc
        running: desktopMenu.menuVisible && desktopMenu.playing
        command: ["bash", "-c",
            "command -v cava >/dev/null 2>&1 || exit 0; " +
            "exec cava -p <(printf '%s\\n' " +
            "'[general]' 'bars = 11' 'framerate = 30' 'autosens = 1' 'sleep_timer = 0' " +
            "'[input]' 'method = pipewire' 'source = auto' 'channels = mono' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'[smoothing]' 'monstercat = 0' 'waves = 0' 'noise_reduction = 20')"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (!desktopMenu.playing) return
                var parts = line.split(";")
                var previous = desktopMenu.levels
                var out = []
                for (var i = 0; i < 11; i++) {
                    var v = parseInt(parts[i]); v = isNaN(v) ? 0 : Math.min(1, v / 100)
                    var current = previous[i] === undefined ? 0 : previous[i]
                    if (v < current) v = current - 0.08
                    out.push(Math.max(0, Math.min(1, v)))
                }
                desktopMenu.levels = out
            }
        }
    }

    Process {
        id: refreshProc
        command: ["bash", "-c", "hyprctl monitors | awk -F'[@.]' '/[0-9]+x[0-9]+@/ {print $2\"Hz\"; exit}'"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let r = String(this.text || "").trim()
                if (r.length > 0) desktopMenu.currentRefresh = r
            }
        }
    }

    Process {
        id: quoteProc
        command: ["bash", "-c", "shuf -n 1 \"$HOME/.config/quickshell/bar/quotes.txt\" 2>/dev/null || echo 'Stay positive.'"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                let q = String(this.text || "").trim()
                if (q.length > 0) desktopMenu.currentQuote = q
            }
        }
    }

    // --- Clock hover zone detection ---
    // The HomescreenClockPanel sits behind this full-screen surface on the
    // same WlrLayer.Bottom, so it never receives mouse events directly.
    // We detect the cursor entering the clock pill area here and toggle
    // root.dashboardExpanded accordingly.
    readonly property real clockZoneWidth: 260   // ~pill width + small margin
    readonly property real clockZoneHeight: 100   // pill + bottom margin

    function cursorInClockZone(mx, my) {
        var cx = desktopMenu.width / 2
        var bottom = desktopMenu.height
        return mx >= cx - clockZoneWidth / 2
            && mx <= cx + clockZoneWidth / 2
            && my >= bottom - clockZoneHeight - 30
            && my <= bottom - 30
    }

    // When the dashboard is expanded, the bgRect grows to ~70% width and ~55% height.
    // Keep it alive while cursor stays inside that larger region.
    function cursorInExpandedZone(mx, my) {
        var cx = desktopMenu.width / 2
        var ew = desktopMenu.width * 0.7
        var eh = desktopMenu.height * 0.55
        var bottom = desktopMenu.height
        return mx >= cx - ew / 2
            && mx <= cx + ew / 2
            && my >= bottom - eh - 20
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.LeftButton
        hoverEnabled: true

        onPositionChanged: (mouse) => {
            if (!root.dashboardExpanded && desktopMenu.cursorInClockZone(mouse.x, mouse.y)) {
                root.dashboardExpanded = true
            }
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                menuX = Math.min(Math.max(mouse.x, 130), parent.width - 130)
                // Ensure there's space for the quote bubble below
                menuY = Math.min(Math.max(mouse.y, 130), parent.height - 230)
                
                let hour = new Date().getHours()
                if (hour < 12) currentGreeting = "Good Morning"
                else if (hour < 18) currentGreeting = "Good Afternoon"
                else currentGreeting = "Good Evening"
                
                quoteProc.running = false
                quoteProc.running = true
                
                refreshProc.running = false
                refreshProc.running = true
                
                Quickshell.execDetached(["pw-play", Quickshell.env("HOME") + "/.config/quickshell/bar/pop.wav"])
                
                menuVisible = true
                animatedReveal = 12
            } else {
                menuVisible = false
                animatedReveal = 0
                root.dashboardExpanded = false
            }
        }
    }

    Rectangle {
        id: quoteCard
        x: menuCard.x + menuCard.width / 2 - width / 2
        y: menuCard.y + menuCard.height - 14
        width: 220
        height: quoteLayout.implicitHeight + 24
        radius: root.panelRadius
        color: root.bg
        border.color: root.panelOuterBorderColor
        border.width: root.panelOuterBorderW
        opacity: desktopMenu.reveal
        scale: 0.8 + (0.2 * desktopMenu.reveal)
        visible: desktopMenu.reveal > 0.001 && !desktopMenu.isListMode
        
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        PillShadow { theme: root }

        Column {
            id: quoteLayout
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 6
            
            Item {
                width: parent.width
                height: titleText.implicitHeight
                clip: true

                UiText {
                    id: titleText
                    text: mprisSel.active ? (mprisSel.player.trackTitle || "Unknown Track") : desktopMenu.currentGreeting
                    color: root.ink
                    font.family: "DM Sans"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    width: mprisSel.active ? implicitWidth : parent.width
                    wrapMode: mprisSel.active ? Text.NoWrap : Text.WordWrap
                    horizontalAlignment: mprisSel.active ? Text.AlignLeft : Text.AlignHCenter
                    
                    x: (!mprisSel.active || implicitWidth <= parent.width) ? (parent.width - width) / 2 : titleAnim.currentX
                    
                    SequentialAnimation {
                        id: titleAnim
                        running: titleText.implicitWidth > titleText.parent.width && mprisSel.active
                        loops: Animation.Infinite
                        property real currentX: 0
                        
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { 
                            target: titleAnim; property: "currentX"
                            from: 0; to: -(titleText.implicitWidth - titleText.parent.width)
                            duration: Math.max(0, (titleText.implicitWidth - titleText.parent.width) * 30)
                        }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { 
                            target: titleAnim; property: "currentX"
                            from: -(titleText.implicitWidth - titleText.parent.width); to: 0
                            duration: Math.max(0, (titleText.implicitWidth - titleText.parent.width) * 30)
                        }
                    }
                }
            }
            
            Item {
                width: parent.width
                height: artistText.implicitHeight
                clip: true

                UiText {
                    id: artistText
                    text: mprisSel.active ? (mprisSel.player.trackArtist || "Unknown Artist") : desktopMenu.currentQuote
                    color: root.sumiHi
                    font.family: "DM Sans"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    width: mprisSel.active ? implicitWidth : parent.width
                    wrapMode: mprisSel.active ? Text.NoWrap : Text.WordWrap
                    horizontalAlignment: mprisSel.active ? Text.AlignLeft : Text.AlignHCenter
                    
                    x: (!mprisSel.active || implicitWidth <= parent.width) ? (parent.width - width) / 2 : artistAnim.currentX
                    
                    SequentialAnimation {
                        id: artistAnim
                        running: artistText.implicitWidth > artistText.parent.width && mprisSel.active
                        loops: Animation.Infinite
                        property real currentX: 0
                        
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { 
                            target: artistAnim; property: "currentX"
                            from: 0; to: -(artistText.implicitWidth - artistText.parent.width)
                            duration: Math.max(0, (artistText.implicitWidth - artistText.parent.width) * 30)
                        }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { 
                            target: artistAnim; property: "currentX"
                            from: -(artistText.implicitWidth - artistText.parent.width); to: 0
                            duration: Math.max(0, (artistText.implicitWidth - artistText.parent.width) * 30)
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24
                visible: mprisSel.active
                topPadding: 8

                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "skip_previous"
                    font.pixelSize: 18
                    color: root.ink
                    opacity: prevMouse.containsMouse ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mprisSel.player) mprisSel.player.previous()
                    }
                }
                
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 28
                    radius: 14
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, playMouse.containsMouse ? 0.12 : 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    IconText {
                        anchors.centerIn: parent
                        text: mprisSel.playing ? "pause" : "play_arrow"
                        font.pixelSize: 18
                        color: root.ink
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mprisSel.player) mprisSel.player.togglePlaying()
                    }
                }
                
                IconText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "skip_next"
                    font.pixelSize: 18
                    color: root.ink
                    opacity: nextMouse.containsMouse ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mprisSel.player) mprisSel.player.next()
                    }
                }
            }
        }
    }

    Rectangle {
        id: menuCard
        x: menuX - width / 2
        y: menuY - height / 2
        width: 320
        height: 320
        radius: width / 2
        color: "transparent"
        opacity: desktopMenu.reveal
        scale: 0.8 + (0.2 * desktopMenu.reveal)
        visible: desktopMenu.reveal > 0.001 && !desktopMenu.isListMode
        
        property real outerRadius: 130
        property real innerRadius: 50
        property int hoveredIndex: -1
        
        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutBack }
        }

        Repeater {
            model: 11
            Canvas {
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                
                property int hIndex: menuCard.hoveredIndex
                property color bgColor: root.bg
                property color hoverFg: root.ink
                property real outRad: menuCard.outerRadius
                property real inRad: menuCard.innerRadius
                
                property color opaqueBg: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 1.0)
                property color opaqueHover: Qt.rgba(
                    bgColor.r * 0.85 + hoverFg.r * 0.15,
                    bgColor.g * 0.85 + hoverFg.g * 0.15,
                    bgColor.b * 0.85 + hoverFg.b * 0.15,
                    1.0
                )

                opacity: (desktopMenu.animatedReveal > index ? 1 : 0) * bgColor.a
                Behavior on opacity { NumberAnimation { duration: 150 } }

                property real eqLevel: desktopMenu.playing ? (desktopMenu.levels[index] || 0) : 0
                onEqLevelChanged: requestPaint()

                onHIndexChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    
                    let angleStep = (2 * Math.PI) / 11;
                    let offset = -Math.PI / 2;

                    let baseStart = offset + index * angleStep;
                    let baseEnd = baseStart + angleStep;

                    let eq = desktopMenu.playing ? (desktopMenu.levels[index] || 0) : 0;
                    let rOut = outRad - 5 + (eq * 20);
                    let rIn = inRad + 5;
                    
                    let pOut = 9 / rOut;
                    let pIn = 9 / rIn;
                    
                    if (baseEnd - baseStart <= (pOut + pIn)) return;

                    ctx.beginPath();
                    ctx.arc(width/2, height/2, rOut, baseStart + pOut, baseEnd - pOut);
                    ctx.arc(width/2, height/2, rIn, baseEnd - pIn, baseStart + pIn, true);
                    ctx.closePath();

                    ctx.lineJoin = "round";

                    // 1. Draw the outer border stroke (thickest)
                    if (root.panelOuterBorderW > 0) {
                        ctx.lineWidth = 10 + (root.panelOuterBorderW * 2);
                        ctx.strokeStyle = root.panelOuterBorderColor;
                        ctx.stroke();
                    }

                    // 2. Draw the inner rounding stroke to mask the border
                    ctx.lineWidth = 10;
                    if (index === hIndex) {
                        ctx.fillStyle = opaqueHover;
                        ctx.strokeStyle = opaqueHover;
                    } else {
                        ctx.fillStyle = opaqueBg;
                        ctx.strokeStyle = opaqueBg;
                    }
                    
                    ctx.stroke();
                    ctx.fill();
                }
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: menuCard.innerRadius * 2 - 8
            height: width
            radius: width / 2
            color: root.bg
            
            property string centerText: {
                switch(menuCard.hoveredIndex) {
                    case 0: return "WhatsApp";
                    case 1: return "Spotify";
                    case 2: return "LocalSend";
                    case 3: return "Theme";
                    case 4: return "Wallpaper";
                    case 5: return "Gemini";
                    case 6: return "Claude";
                    case 7: return "List Menu";
                    case 8: return desktopMenu.currentRefresh;
                    case 9: return "Zen Browser";
                    case 10: return "Files";
                    default: return "";
                }
            }

            UiText {
                anchors.centerIn: parent
                text: parent.centerText
                visible: text !== ""
                color: root.ink
                font.family: "DM Sans"
                font.pixelSize: 10
                font.weight: Font.DemiBold
                width: parent.width - 4
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            IconText {
                anchors.centerIn: parent
                text: "close"
                visible: parent.centerText === ""
                color: root.sumiHi
                font.pixelSize: 20
            }
        }

        Repeater {
            model: 11
            Item {
                id: delegateItem
                width: 24
                height: 24
                property real angle: -Math.PI / 2 + (index + 0.5) * (2 * Math.PI / 11)
                property real radiusCenter: (menuCard.outerRadius + menuCard.innerRadius) / 2
                x: menuCard.width / 2 + Math.cos(angle) * radiusCenter - width / 2
                y: menuCard.height / 2 + Math.sin(angle) * radiusCenter - height / 2
                
                opacity: desktopMenu.animatedReveal > index ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                property string iconTxt: {
                    switch(index) {
                        case 2: return "share";
                        case 3: return "palette";
                        case 4: return "image";
                        case 7: return "list";
                        case 8: return "speed";
                        case 10: return "folder";
                        default: return "";
                    }
                }
                
                property string iconSrc: {
                    switch(index) {
                        case 0: return Quickshell.env("HOME") + "/.config/quickshell/bar/whatsapp.svg";
                        case 1: return Quickshell.env("HOME") + "/.config/quickshell/bar/spotify.svg";
                        case 5: return Quickshell.env("HOME") + "/.config/quickshell/bar/gemini_final.svg";
                        case 6: return Quickshell.env("HOME") + "/.config/quickshell/bar/claude.svg";
                        case 9: return Quickshell.env("HOME") + "/.config/quickshell/bar/zen.svg";
                        default: return "";
                    }
                }
                
                property color itemColor: {
                    if (index === 5 && menuCard.hoveredIndex === 5) return "#4285F4";
                    if (index === 6 && menuCard.hoveredIndex === 6) return "#D97757";
                    return menuCard.hoveredIndex === index ? root.seal : root.ink;
                }

                IconText {
                    anchors.centerIn: parent
                    text: parent.iconTxt
                    visible: text !== "" && parent.iconSrc === ""
                    color: parent.itemColor
                    font.pixelSize: 16
                }

                Image {
                    id: customIcon
                    anchors.centerIn: parent
                    source: parent.iconSrc
                    visible: parent.iconSrc !== ""
                    width: 16; height: 16
                    fillMode: Image.PreserveAspectFit
                    sourceSize.width: 16; sourceSize.height: 16
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        colorization: 1.0
                        colorizationColor: delegateItem.itemColor
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: (mouse) => {
                let dx = mouse.x - width / 2;
                let dy = mouse.y - height / 2;
                let dist = Math.sqrt(dx*dx + dy*dy);
                if (dist >= menuCard.innerRadius && dist <= menuCard.outerRadius) {
                    let angle = Math.atan2(dy, dx);
                    angle = angle + Math.PI / 2;
                    if (angle < 0) angle += 2 * Math.PI;
                    let targetIndex = Math.floor(angle / (2 * Math.PI / 11));
                    
                    if (desktopMenu.animatedReveal > targetIndex) {
                        menuCard.hoveredIndex = targetIndex;
                    } else {
                        menuCard.hoveredIndex = -1;
                    }
                } else {
                    menuCard.hoveredIndex = -1;
                }
            }
            onExited: menuCard.hoveredIndex = -1
            onClicked: (mouse) => {
                desktopMenu.menuVisible = false;
                desktopMenu.animatedReveal = 0;
                if (menuCard.hoveredIndex === 99) {
                    return; // Just close menu
                }
                if (menuCard.hoveredIndex !== -1) {
                    switch(menuCard.hoveredIndex) {
                        case 0: Quickshell.execDetached(["omarchy-launch-webapp", "https://web.whatsapp.com/"]); break;
                        case 1: Quickshell.execDetached(["spotify"]); break;
                        case 2: Quickshell.execDetached(["localsend"]); break;
                        case 3: root.ipcOpenPicker("theme"); break;
                        case 4: root.ipcOpenPicker("wallpaper"); break;
                        case 5: Quickshell.execDetached(["xdg-open", "https://gemini.google.com"]); break;
                        case 6: Quickshell.execDetached(["xdg-open", "https://claude.ai"]); break;
                        case 7: desktopMenu.isListMode = true; break;
                        case 8: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/bin/toggle-refresh-rate"]); break;
                        case 9: Quickshell.execDetached(["zen-browser"]); break;
                        case 10: Quickshell.execDetached(["nautilus"]); break;
                    }
                }
            }
        }
    }

    Item {
        id: listMenuCard
        x: Math.max(20, Math.min(menuX, desktopMenu.width - width - 20))
        y: Math.max(20, Math.min(menuY, desktopMenu.height - height - 20))
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
                transform: Translate { y: yOffset }
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
                        font.family: "DM Sans"
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
                        font.family: "DM Sans"
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
                property int staggerIndex: 1
                property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
                opacity: isRevealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                scale: isRevealed ? 1 : 0.95
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                property real yOffset: isRevealed ? 0 : -15
                Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                transform: Translate { y: yOffset }
                transformOrigin: Item.Top

                width: parent.width
                height: aiCol.implicitHeight + 16
                clip: true
                topLeftRadius: 8; topRightRadius: 8; bottomLeftRadius: 8; bottomRightRadius: 8
                color: root.bg; border.color: root.panelOuterBorderColor; border.width: root.panelOuterBorderW
                
                PillShadow { theme: root }

                Rectangle {
                    visible: listMenuCard.aiExpanded
                    width: 2; radius: 1; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    anchors.left: aiCol.left; anchors.leftMargin: 19
                    anchors.top: aiCol.top; anchors.topMargin: 36
                    anchors.bottom: aiCol.bottom; anchors.bottomMargin: 4
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                Column {
                    id: aiCol
                    anchors.top: parent.top; anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 16

                    Rectangle {
                        width: parent.width; height: 32; radius: 10
                        color: aiHeaderMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            Item {
                                width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                                IconText { anchors.centerIn: parent; text: "auto_awesome"; color: root.ink; font.pixelSize: 16 }
                            }
                            UiText { anchors.verticalCenter: parent.verticalCenter; text: "AI"; color: root.ink; font.family: "DM Sans"; font.pixelSize: 11; font.weight: Font.Medium }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 20; radius: 10; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            IconText { anchors.centerIn: parent; text: listMenuCard.aiExpanded ? "expand_less" : "expand_more"; color: root.sumiHi; font.pixelSize: 16 }
                        }
                        MouseArea { id: aiHeaderMouse; anchors.fill: parent; hoverEnabled: true; onClicked: listMenuCard.aiExpanded = !listMenuCard.aiExpanded }
                    }

                    Repeater {
                        model: [5, 6]
                        Rectangle {
                            id: aiItem
                            required property int modelData; property int idx: modelData
                            property bool showItem: listMenuCard.aiExpanded
                            width: parent.width; height: showItem ? 32 : 0; opacity: showItem ? 1 : 0
                            visible: height > 0 || opacity > 0
                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
                            radius: 10; color: aiItemMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 38; anchors.rightMargin: 12; spacing: 12
                                Item {
                                    width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                                    Image {
                                        anchors.centerIn: parent; width: 14; height: 14; fillMode: Image.PreserveAspectFit
                                        source: idx === 5 ? Quickshell.env("HOME") + "/.config/quickshell/bar/gemini_final.svg" : Quickshell.env("HOME") + "/.config/quickshell/bar/claude.svg"
                                        layer.enabled: true
                                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: (idx === 5 && aiItemMouse.containsMouse) ? "#4285F4" : ((idx === 6 && aiItemMouse.containsMouse) ? "#D97757" : root.ink) }
                                    }
                                }
                                UiText { anchors.verticalCenter: parent.verticalCenter; text: idx === 5 ? "Gemini" : "Claude"; color: root.ink; font.family: "DM Sans"; font.pixelSize: 11; font.weight: Font.Medium }
                            }
                            MouseArea {
                                id: aiItemMouse; anchors.fill: parent; hoverEnabled: true
                                onClicked: { desktopMenu.menuVisible = false; Quickshell.execDetached(["xdg-open", idx === 5 ? "https://gemini.google.com" : "https://claude.ai"]); }
                            }
                        }
                    }
                }
            }

            // Quick Apps Pill (staggerIndex 2)
            Rectangle {
                property int staggerIndex: 2
                property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
                opacity: isRevealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                scale: isRevealed ? 1 : 0.95
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                property real yOffset: isRevealed ? 0 : -15
                Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                transform: Translate { y: yOffset }
                transformOrigin: Item.Top

                width: parent.width
                height: appsCol.implicitHeight + 16
                clip: true
                topLeftRadius: 8; topRightRadius: 8; bottomLeftRadius: 8; bottomRightRadius: 8
                color: root.bg; border.color: root.panelOuterBorderColor; border.width: root.panelOuterBorderW
                
                PillShadow { theme: root }

                Rectangle {
                    visible: listMenuCard.appsExpanded
                    width: 2; radius: 1; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    anchors.left: appsCol.left; anchors.leftMargin: 19
                    anchors.top: appsCol.top; anchors.topMargin: 36
                    anchors.bottom: appsCol.bottom; anchors.bottomMargin: 4
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                }

                Column {
                    id: appsCol
                    anchors.top: parent.top; anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 16

                    Rectangle {
                        width: parent.width; height: 32; radius: 10
                        color: appsHeaderMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Row {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            Item {
                                width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                                IconText { anchors.centerIn: parent; text: "apps"; color: root.ink; font.pixelSize: 16 }
                            }
                            UiText { anchors.verticalCenter: parent.verticalCenter; text: "Quick Apps"; color: root.ink; font.family: "DM Sans"; font.pixelSize: 11; font.weight: Font.Medium }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            width: 32; height: 20; radius: 10; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                            IconText { anchors.centerIn: parent; text: listMenuCard.appsExpanded ? "expand_less" : "expand_more"; color: root.sumiHi; font.pixelSize: 16 }
                        }
                        MouseArea { id: appsHeaderMouse; anchors.fill: parent; hoverEnabled: true; onClicked: listMenuCard.appsExpanded = !listMenuCard.appsExpanded }
                    }

                    Repeater {
                        model: [10, 9, 0, 1, 2]
                        Rectangle {
                            id: appsItem
                            required property int modelData; property int idx: modelData
                            property bool showItem: listMenuCard.appsExpanded
                            width: parent.width; height: showItem ? 32 : 0; opacity: showItem ? 1 : 0
                            visible: height > 0 || opacity > 0
                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
                            radius: 10; color: appsItemMouse.containsMouse ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 38; anchors.rightMargin: 12; spacing: 12
                                Item {
                                    width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter
                                    IconText {
                                        anchors.centerIn: parent; visible: idx === 2 || idx === 10
                                        text: idx === 2 ? "share" : (idx === 10 ? "folder" : "")
                                        color: root.ink; font.pixelSize: 16
                                    }
                                    Image {
                                        anchors.centerIn: parent; visible: idx === 0 || idx === 1 || idx === 9; width: 14; height: 14; fillMode: Image.PreserveAspectFit
                                        source: idx === 0 ? Quickshell.env("HOME") + "/.config/quickshell/bar/whatsapp.svg" : (idx === 1 ? Quickshell.env("HOME") + "/.config/quickshell/bar/spotify.svg" : Quickshell.env("HOME") + "/.config/quickshell/bar/zen.svg")
                                        layer.enabled: true
                                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: root.ink }
                                    }
                                }
                                UiText { 
                                    anchors.verticalCenter: parent.verticalCenter; color: root.ink; font.family: "DM Sans"; font.pixelSize: 11; font.weight: Font.Medium 
                                    text: idx === 0 ? "WhatsApp" : (idx === 1 ? "Spotify" : (idx === 2 ? "LocalSend" : (idx === 9 ? "Zen Browser" : "Files")))
                                }
                            }
                            MouseArea {
                                id: appsItemMouse; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    desktopMenu.menuVisible = false;
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
                property int staggerIndex: 3
                property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
                opacity: isRevealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                scale: isRevealed ? 1 : 0.95
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                property real yOffset: isRevealed ? 0 : -15
                Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                transform: Translate { y: yOffset }
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
                                model: listMenuCard.wallpaperList
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
                property int staggerIndex: 4
                property bool isRevealed: listMenuCard.staggeredReveal > staggerIndex
                opacity: isRevealed ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                scale: isRevealed ? 1 : 0.95
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                property real yOffset: isRevealed ? 0 : -15
                Behavior on yOffset { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                transform: Translate { y: yOffset }
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
                                    anchors.verticalCenter: parent.verticalCenter; color: root.ink; font.family: "DM Sans"; font.pixelSize: 11; font.weight: Font.Medium 
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
                                    font.family: "DM Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                            }
                            
                            MouseArea {
                                id: sysItemMouse; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    if (idx === 7) { desktopMenu.isListMode = false; return; }
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
}

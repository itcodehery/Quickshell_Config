import QtQuick
import QtQuick.Effects
import Quickshell
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton | Qt.LeftButton
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
        visible: desktopMenu.reveal > 0.001
        
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
                    font.family: root.mono
                    font.pixelSize: 13
                    font.weight: Font.Bold
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
                            duration: (titleText.implicitWidth - titleText.parent.width) * 30
                        }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { 
                            target: titleAnim; property: "currentX"
                            from: -(titleText.implicitWidth - titleText.parent.width); to: 0
                            duration: (titleText.implicitWidth - titleText.parent.width) * 30
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
                    font.family: root.mono
                    font.pixelSize: 11
                    font.italic: true
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
                            duration: (artistText.implicitWidth - artistText.parent.width) * 30
                        }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { 
                            target: artistAnim; property: "currentX"
                            from: -(artistText.implicitWidth - artistText.parent.width); to: 0
                            duration: (artistText.implicitWidth - artistText.parent.width) * 30
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
                
                IconText {
                    text: mprisSel.playing ? "pause" : "play_arrow"
                    font.pixelSize: 18
                    color: root.ink
                    opacity: playMouse.containsMouse ? 1 : 0.6
                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (mprisSel.player) mprisSel.player.togglePlaying()
                    }
                }
                
                IconText {
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
        visible: desktopMenu.reveal > 0.001
        
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
                    ctx.lineWidth = 10;
                    ctx.fillStyle = (index === hIndex) ? opaqueHover : opaqueBg;
                    ctx.strokeStyle = ctx.fillStyle;
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
                    case 0: return "System Monitor";
                    case 1: return "Spotify";
                    case 2: return "LocalSend";
                    case 3: return "Theme";
                    case 4: return "Wallpaper";
                    case 5: return "Gemini";
                    case 6: return "Claude";
                    case 7: return root.barHidden ? "Show Bar" : "Hide Bar";
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
                font.pixelSize: 11
                font.weight: Font.Bold
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
                        case 0: return "memory";
                        case 2: return "share";
                        case 3: return "palette";
                        case 4: return "image";
                        case 7: return root.barHidden ? "visibility" : "visibility_off";
                        case 8: return "speed";
                        case 10: return "folder";
                        default: return "";
                    }
                }
                
                property string iconSrc: {
                    switch(index) {
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
                        case 0: Quickshell.execDetached(["kitty", "-e", "btop"]); break;
                        case 1: Quickshell.execDetached(["spotify"]); break;
                        case 2: Quickshell.execDetached(["localsend"]); break;
                        case 3: root.ipcOpenPicker("theme"); break;
                        case 4: root.ipcOpenPicker("wallpaper"); break;
                        case 5: Quickshell.execDetached(["xdg-open", "https://gemini.google.com"]); break;
                        case 6: Quickshell.execDetached(["xdg-open", "https://claude.ai"]); break;
                        case 7: root.barHidden = !root.barHidden; break;
                        case 8: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/bin/toggle-refresh-rate"]); break;
                        case 9: Quickshell.execDetached(["zen-browser"]); break;
                        case 10: Quickshell.execDetached(["nautilus"]); break;
                    }
                }
            }
        }
    }
}

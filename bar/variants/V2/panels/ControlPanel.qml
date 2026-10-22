import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../modules"

PanelWindow {
    id: ctrlPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-control"
    // no mask → whole overlay is interactive (modal): click-outside + ESC work

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    // power sub-menu starts CLOSED — no destructive tile is ever pre-shown
    property bool powerOpen: false
    property bool wsOpen: false   // Workspaces collapsible inside the WW fly-out
    readonly property string barctlPath: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-barctl"

    // ── System info card ──────────────────────────────────────────────────────
    property string siHostname: ""
    property string siModel: ""
    property string siCpu: ""
    property string siRam: ""
    property string siGpu: ""
    property string siDisplay: ""
    property string siOs: ""
    property string siKernel: ""
    property bool siFetched: false

    Process {
        id: siFetchProc
        command: ["bash", "-c",
            "hostname=$(hostname); " +
            "model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo ''); " +
            "cpu=$(grep 'model name' /proc/cpuinfo | head -1 | sed 's/.*: //' | sed 's/ with.*//'); " +
            "ram=$(awk '/MemTotal/{printf \"%.0f GB\", $2/1024/1024}' /proc/meminfo); " +
            "gpu=$(glxinfo 2>/dev/null | grep 'OpenGL renderer' | sed 's/OpenGL renderer string: //' | sed 's/\\/PCIe.*//' || echo 'N/A'); " +
            "display=$(hyprctl monitors -j 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(', '.join(str(m['width']) + 'x' + str(m['height']) + ' @' + str(int(m['refreshRate'])) + 'Hz' for m in d))\"); " +
            "os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'); " +
            "kernel=$(uname -r); " +
            "printf '%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s' \"$hostname\" \"$model\" \"$cpu\" \"$ram\" \"$gpu\" \"$display\" \"$os\" \"$kernel\""
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                ctrlPanel.siHostname = lines[0] || ""
                ctrlPanel.siModel    = lines[1] || ""
                ctrlPanel.siCpu      = lines[2] || ""
                ctrlPanel.siRam      = lines[3] || ""
                ctrlPanel.siGpu      = lines[4] || ""
                ctrlPanel.siDisplay  = lines[5] || ""
                ctrlPanel.siOs       = lines[6] || ""
                ctrlPanel.siKernel   = lines[7] || ""
                ctrlPanel.siFetched  = true
            }
        }
    }
    // Fetch once when the panel first opens
    onVisibleChanged: { if (visible && !ctrlPanel.siFetched) siFetchProc.running = true }

    // Same toggle path as NotificationSilenceWidget; state comes back via
    // root.notifSilenced once the status indicators are refreshed.
    Process {
        id: dndProc
        command: ["bash", "-c", "if command -v omarchy-toggle-notification-silencing >/dev/null 2>&1; then exec omarchy-toggle-notification-silencing; fi; exec omarchy toggle notification silencing"]
        onExited: root.refreshStatusIndicators()
    }

    // ── pretty spec strings: split raw names into a short model + vendor chip ──
    function _vendorOf(str) {
        var m = /^(NVIDIA|AMD|Intel|Apple|Qualcomm)\b/i.exec(str || "")
        return m ? (m[1].toUpperCase() === "NVIDIA" ? "NVIDIA" : m[1].toUpperCase() === "AMD" ? "AMD"
                    : m[1].charAt(0).toUpperCase() + m[1].slice(1).toLowerCase()) : ""
    }
    function cpuModel(str) {
        return (str || "")
            .replace(/\((R|TM)\)/gi, "")
            .replace(/^(AMD|Intel)\s+/i, "")
            .replace(/\s+(\d+-Core\s+)?(Processor|CPU)\b.*$/i, "")
            .replace(/\s+@.*$/, "")
            .replace(/\s+/g, " ").trim()
    }
    function gpuModel(str) {
        return (str || "")
            .replace(/\s*\(.*\)\s*$/, "")
            .replace(/^(NVIDIA|AMD|Intel)\s+(Corporation\s+)?/i, "")
            .replace(/\b(GeForce|Radeon(?=\s+RX))\s+/i, "")
            .replace(/\s*(Laptop|Mobile|Max-Q)\b/gi, "")
            .replace(/\s*(GPU|Graphics)$/i, "")
            .replace(/\s+/g, " ").trim()
    }
    function gpuChip(str) {
        var v = _vendorOf(str)
        var mobile = /\b(Laptop|Mobile|Max-Q)\b/i.test(str || "")
        return mobile ? (v !== "" ? v + " · Laptop" : "Laptop") : v
    }
    function displayModel(str) {
        var first = (str || "").split(",")[0]
        return first.replace(/\s*@.*$/, "").replace("x", " × ").trim()
    }
    function displayChip(str) {
        var parts = (str || "").split(",")
        var m = /@\s*(\d+)\s*Hz/i.exec(parts[0] || "")
        var hz = m ? m[1] + " Hz" : ""
        return parts.length > 1 ? (hz !== "" ? hz + " · +" + (parts.length - 1) : "+" + (parts.length - 1)) : hz
    }

    function switchBar(version) {
        root.controlVisible = false
        if (root.variantHost)
            root.variantHost.requestSwitch(version)
        else
            Quickshell.execDetached([barctlPath, "switch", version])
    }

    property real reveal: root.controlVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.controlVisible ? 280 : 160
            easing.type: root.controlVisible ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 1.15
        }
    }
    visible: reveal > 0.001
    onRevealChanged: if (reveal < 0.01) {
        powerOpen = false
        wsOpen = false
        root.wwSubVisible = false
    }
    WlrLayershell.keyboardFocus: root.controlVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── Android-shade surface tokens ──────────────────────────────────────────
    // No borders anywhere: hierarchy comes purely from background tone.
    //   panel bg  →  card (cardBg)  →  chip on card (chipBg / chipHover)
    //   "on" state = solid accent fill with paper-coloured content.
    readonly property int   cardRadius: 18
    readonly property int   cardPad: 12
    readonly property color cardBg:    root.fillIdle
    readonly property color chipBg:    Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.07)
    readonly property color chipHover: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.13)

    // ── rounded section card (replaces separator lines) ──
    component Card: Rectangle {
        id: _card
        default property alias content: _cardBody.data
        property string title: ""
        property string trailing: ""
        width: parent ? parent.width : 0
        implicitHeight: _cardHead.height + (_cardHead.visible ? 8 : 0) + _cardBody.implicitHeight + ctrlPanel.cardPad * 2
        height: implicitHeight
        radius: ctrlPanel.cardRadius
        color: ctrlPanel.cardBg

        Item {
            id: _cardHead
            visible: _card.title !== ""
            x: ctrlPanel.cardPad + 2
            y: ctrlPanel.cardPad
            width: _card.width - ctrlPanel.cardPad * 2 - 4
            height: visible ? 16 : 0
            UiText {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                text: _card.title
                color: root.sumiHi; font.family: root.barFont
                font.pixelSize: 11; font.weight: Font.Medium
            }
            UiText {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: _card.trailing
                visible: text !== ""
                color: root.sumi; font.family: root.barFont; font.pixelSize: 10
            }
        }
        Column {
            id: _cardBody
            x: ctrlPanel.cardPad
            y: ctrlPanel.cardPad + _cardHead.height + (_cardHead.visible ? 8 : 0)
            width: _card.width - ctrlPanel.cardPad * 2
            spacing: 6
        }
    }

    // ── pill button: tonal chip by default, solid accent when active ──
    component Tile: Rectangle {
        id: _tile
        property string label
        property string icon: ""
        property color accent: root.seal
        property bool active: false
        // false when the tile sits directly on the panel (not inside a Card)
        property bool onCard: true
        signal activated()
        readonly property color fg: active ? root.paper : root.ink
        height: 30
        radius: height / 2
        opacity: enabled ? 1.0 : 0.4          // built-in `enabled` also blocks input
        color: active
            ? (_ma.containsMouse ? Qt.lighter(accent, 1.12) : accent)
            : (_ma.containsMouse ? ctrlPanel.chipHover : (onCard ? ctrlPanel.chipBg : ctrlPanel.cardBg))
        Behavior on color { ColorAnimation { duration: 140 } }
        Row {
            anchors.centerIn: parent
            spacing: 6
            IconText {
                visible: _tile.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: _tile.icon
                fill: _tile.active ? 1 : 0
                color: _tile.fg
                font.pixelSize: 15
            }
            UiText {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, _tile.width - 20 - (_tile.icon !== "" ? 21 : 0))
                elide: Text.ElideRight
                text: _tile.label
                color: _tile.fg
                font.family: root.barFont; font.pixelSize: 11
                font.weight: _tile.active ? Font.Medium : Font.Normal
            }
        }
        MouseArea {
            id: _ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: _tile.activated()
        }
    }

    // ── big Android quick-settings tile (icon squircle + title/subtitle) ──
    component QuickTile: Rectangle {
        id: _qt
        property string icon
        property string title
        property string subtitle: ""
        property bool active: false
        property color accent: root.seal
        signal activated()
        readonly property color fg: active ? root.paper : root.ink
        height: 56
        radius: height / 2
        color: active
            ? (_qma.containsMouse ? Qt.lighter(accent, 1.12) : accent)
            : (_qma.containsMouse ? ctrlPanel.chipHover : ctrlPanel.cardBg)
        Behavior on color { ColorAnimation { duration: 160 } }

        Rectangle {
            id: _qtIcon
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 14
            color: _qt.active ? Qt.rgba(root.paper.r, root.paper.g, root.paper.b, 0.18) : ctrlPanel.chipBg
            Behavior on color { ColorAnimation { duration: 160 } }
            IconText {
                anchors.centerIn: parent
                text: _qt.icon
                fill: _qt.active ? 1 : 0
                color: _qt.fg
                font.pixelSize: 19
            }
        }
        Column {
            anchors.left: _qtIcon.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            UiText {
                width: parent.width
                text: _qt.title
                elide: Text.ElideRight
                color: _qt.fg
                font.family: root.barFont; font.pixelSize: 12; font.weight: Font.DemiBold
            }
            UiText {
                width: parent.width
                visible: text !== ""
                text: _qt.subtitle
                elide: Text.ElideRight
                color: _qt.fg; opacity: 0.7
                font.family: root.barFont; font.pixelSize: 10
            }
        }
        MouseArea {
            id: _qma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: _qt.activated()
        }
    }

    // ── round palette swatch; selection = check glyph + slight grow ──
    component Swatch: Rectangle {
        id: _sw
        property string paletteId
        property bool selected: false
        signal picked()
        height: width
        radius: width / 2
        color: root.paletteColor(paletteId)
        scale: _swMa.containsMouse ? 1.08 : (selected ? 1.0 : 0.9)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
        IconText {
            anchors.centerIn: parent
            visible: _sw.selected
            text: "check"
            color: root.paletteContrastColor(_sw.paletteId)
            font.pixelSize: Math.round(_sw.width * 0.55)
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: _swMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: _sw.picked()
        }
    }

    // ── segmented pill row (single choice) ──
    component Segmented: Row {
        id: _seg
        property var options: []          // [{ label, value }]
        property string current: ""
        signal chosen(string value)
        spacing: 4
        Repeater {
            model: _seg.options
            delegate: Tile {
                required property var modelData
                width: root.evenW((_seg.width - _seg.spacing * (_seg.options.length - 1)) / _seg.options.length)
                label: modelData.label
                active: _seg.current === modelData.value
                onActivated: _seg.chosen(modelData.value)
            }
        }
    }



    // ── system spec tile: tinted icon squircle + vendor chip, label, short value ──
    component InfoTile: Rectangle {
        id: _it
        property string icon
        property string label
        property string value
        property string chip: ""
        height: 88
        radius: 16
        color: ctrlPanel.chipBg

        Rectangle {
            id: _itIcon
            x: 10; y: 10
            width: 30; height: 30; radius: 11
            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, root.fillActiveAlpha)
            IconText {
                anchors.centerIn: parent
                text: _it.icon
                color: root.seal
                font.pixelSize: 17
            }
        }
        Rectangle {
            visible: _it.chip !== ""
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: _itIcon.verticalCenter
            width: Math.min(_itChip.implicitWidth + 14, _it.width - _itIcon.width - 30)
            height: 20; radius: 10
            color: ctrlPanel.chipBg
            UiText {
                id: _itChip
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 14)
                elide: Text.ElideRight
                text: _it.chip
                color: root.sumiHi; font.family: root.barFont
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 0.3
            }
        }
        Column {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.bottom: parent.bottom; anchors.bottomMargin: 11
            spacing: 1
            UiText {
                text: _it.label
                color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10
            }
            UiText {
                width: parent.width
                text: _it.value !== "" ? _it.value : "—"
                elide: Text.ElideRight
                color: root.ink; font.family: root.barFont
                font.pixelSize: 13; font.weight: Font.DemiBold
            }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.controlVisible = false }

    Rectangle {
        id: card
        width: 396
        height: col.implicitHeight + 24
        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        radius: ctrlPanel.reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: ctrlPanel.root
            ownerActive: ctrlPanel.root.controlVisible
            targetX: ctrlPanel.root.launcherBarX
            reveal: ctrlPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.launcherBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + Math.round(20 * (1 - ctrlPanel.reveal))
            : (barBottom + gap) - Math.round(20 * (1 - ctrlPanel.reveal))
        scale: 0.94 + 0.06 * ctrlPanel.reveal
        transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
        opacity: Math.min(1.0, ctrlPanel.reveal * 1.2)
        focus: root.controlVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.controlVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header: logo squircle · host / OS · close ──
            Item {
                width: parent.width
                height: 44

                Rectangle {
                    id: logoChip
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42; height: 42; radius: 15
                    color: root.seal
                    Text {
                        anchors.centerIn: parent
                        text: "\uE900"
                        color: root.paper
                        font.family: "omarchy"
                        font.pixelSize: 22
                    }
                }
                Column {
                    anchors.left: logoChip.right; anchors.leftMargin: 10
                    anchors.right: closeBtn.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    UiText {
                        width: parent.width
                        text: ctrlPanel.siHostname !== "" ? ctrlPanel.siHostname : "Control"
                        elide: Text.ElideRight
                        color: root.ink; font.family: root.barFont
                        font.pixelSize: 14; font.weight: Font.DemiBold
                    }
                    UiText {
                        width: parent.width
                        text: ctrlPanel.siOs !== "" ? ctrlPanel.siOs + "  ·  " + ctrlPanel.siKernel : "Control center"
                        elide: Text.ElideRight
                        color: root.sumiHi; font.family: root.barFont; font.pixelSize: 10
                    }
                }
                Rectangle {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15
                    color: closeMa.containsMouse ? ctrlPanel.chipHover : ctrlPanel.cardBg
                    Behavior on color { ColorAnimation { duration: 120 } }
                    IconText {
                        anchors.centerIn: parent
                        text: "close"
                        color: closeMa.containsMouse ? root.seal : root.ink
                        font.pixelSize: 16
                    }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controlVisible = false }
                }
            }

            // ── quick settings tiles ──
            QuickTile {
                width: parent.width
                icon: "data_object"
                title: "GitHub Heatmap"
                subtitle: "View contribution activity"
                onActivated: {
                    root.controlVisible = false
                    root.githubHeatmapVisible = true
                }
            }

            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 6
                rowSpacing: 6
                readonly property real tileW: root.evenW((width - columnSpacing) / 2)

                QuickTile {
                    width: parent.tileW
                    icon: root.barPosition === "bottom" ? "vertical_align_bottom" : "vertical_align_top"
                    title: "Position"
                    subtitle: root.barPosition === "bottom" ? "Bottom" : "Top"
                    onActivated: root.barPosition = root.barPosition === "bottom" ? "top" : "bottom"
                }
                QuickTile {
                    width: parent.tileW
                    icon: root.notifSilenced ? "notifications_off" : "notifications"
                    title: "Do not disturb"
                    subtitle: root.notifSilenced ? "Silenced" : "Alerts on"
                    active: root.notifSilenced
                    onActivated: { dndProc.running = false; dndProc.running = true }
                }
                QuickTile {
                    width: parent.tileW
                    icon: "border_outer"
                    title: "Bar border"
                    subtitle: root.barBorderEnabled ? "On" : "Off"
                    active: root.barBorderEnabled
                    onActivated: root.barBorderEnabled = !root.barBorderEnabled
                }
                QuickTile {
                    width: parent.tileW
                    icon: "select_window"
                    title: "Panel border"
                    subtitle: root.panelTooltipBorderEnabled ? "On" : "Off"
                    active: root.panelTooltipBorderEnabled
                    onActivated: root.panelTooltipBorderEnabled = !root.panelTooltipBorderEnabled
                }
            }

            // ── BAR COLOR: round swatches ──
            Card {
                title: "Bar color"
                trailing: root.barColorLabel(root.barColor)
                Grid {
                    id: barSwatches
                    width: parent.width
                    columns: 8
                    readonly property int size: Math.floor((width - 7 * 4) / 8)
                    columnSpacing: Math.floor((width - size * 8) / 7)
                    Repeater {
                        model: root.barColorOptions
                        delegate: Swatch {
                            required property string modelData
                            width: barSwatches.size
                            paletteId: modelData
                            selected: root.barColor === modelData
                            onPicked: root.barColor = modelData
                        }
                    }
                }
            }

            // ── PICKER style (theme/wallpaper/screenshot/video picker visual) ──
            Card {
                title: "Picker style"
                Segmented {
                    width: parent.width
                    options: [
                        { label: "Tanzaku",     value: "tanzaku"     },
                        { label: "Hearthstone", value: "hearthstone" },
                        { label: "Carousel",    value: "carousel"    }
                    ]
                    current: root.pickerStyle
                    onChosen: (v) => root.pickerStyle = v
                }
            }

            // ── SYSTEM INFO ──
            Card {
                title: "System"
                Grid {
                    id: specGrid
                    width: parent.width
                    columns: 2
                    spacing: 6
                    readonly property real tileW: root.evenW((width - spacing) / 2)
                    InfoTile { width: specGrid.tileW; icon: "developer_board"; label: "Processor"; value: ctrlPanel.cpuModel(ctrlPanel.siCpu);         chip: ctrlPanel._vendorOf(ctrlPanel.siCpu) }
                    InfoTile { width: specGrid.tileW; icon: "memory";          label: "Memory";    value: "16 GB";                                     chip: "RAM" }
                    InfoTile { width: specGrid.tileW; icon: "videogame_asset"; label: "Graphics";  value: ctrlPanel.gpuModel(ctrlPanel.siGpu);         chip: ctrlPanel.gpuChip(ctrlPanel.siGpu) }
                    InfoTile { width: specGrid.tileW; icon: "desktop_windows"; label: "Display";   value: ctrlPanel.displayModel(ctrlPanel.siDisplay); chip: ctrlPanel.displayChip(ctrlPanel.siDisplay) }
                }
            }
        }
    }

    // ── BAR FUNCTIONS sub-panel ──
    Rectangle {
        id: wwCard
        visible: root.controlVisible && root.wwSubVisible
        width: 372
        height: wwCol.implicitHeight + 24
        Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        radius: (root.controlVisible && root.wwSubVisible) ? root.panelRadius : 0
        color: root.bg
        border.color: root.panelOuterBorderColor
        border.width: root.panelOuterBorderW
        PillShadow { theme: root }
        // open to the right of the card, or to the left if there is no room
        x: (card.x + card.width + ctrlPanel.gap + width <= parent.width - 6)
           ? card.x + card.width + ctrlPanel.gap
           : card.x - ctrlPanel.gap - width
        y: root.barPosition === "bottom" ? card.y + card.height - height : card.y
        scale: 0.94 + 0.06 * ctrlPanel.reveal
        transformOrigin: root.barPosition === "bottom" ? Item.Bottom : Item.Top
        opacity: Math.min(1.0, ctrlPanel.reveal * 1.2)

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: wwCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── LAYOUT ──
            Card {
                title: "Layout"
                Tile {
                    width: parent.width
                    icon: "restart_alt"
                    label: "Default layout"
                    onActivated: if (root.fnDefaultLayout) root.fnDefaultLayout()
                }
            }

            // ── WIDGETS: toggle on/off for visibility ──
            Card {
                id: widgetsCard
                title: "Widgets"
                trailing: "tap to toggle"
                Grid {
                    id: widgetGrid
                    width: parent.width
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 4
                    readonly property real tileW: root.evenW((width - columnSpacing) / 2)

                    Tile {
                        width: widgetGrid.tileW
                        icon: "info"
                        label: "Status"
                        active: root.modStatus
                        onActivated: root.modStatus = !root.modStatus
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "notifications"
                        label: "Notifications"
                        active: root.modNotif
                        onActivated: root.modNotif = !root.modNotif
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "music_note"
                        label: "Now playing"
                        active: root.modMpris
                        onActivated: root.modMpris = !root.modMpris
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "data_object"
                        label: "GH Heatmap"
                        active: root.modGithubHeatmap
                        onActivated: root.modGithubHeatmap = !root.modGithubHeatmap
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "sticky_note_2"
                        label: "Notes"
                        active: root.modNotes
                        onActivated: root.modNotes = !root.modNotes
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "battery_charging_full"
                        label: "Battery"
                        visible: root.hasBattery
                        active: root.modBattery
                        onActivated: root.modBattery = !root.modBattery
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "hourglass_top"
                        label: "Screentime"
                        active: root.modScreentime
                        onActivated: root.modScreentime = !root.modScreentime
                    }
                    Tile {
                        width: widgetGrid.tileW
                        icon: "thermostat"
                        label: "Weather"
                        active: root.modWeather
                        onActivated: root.modWeather = !root.modWeather
                    }
                }
            }

            // ── WORKSPACES (collapsible card) ──
            Card {
                id: wsCard
                Item {
                    width: parent.width
                    height: 22
                    UiText {
                        anchors.left: parent.left; anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Workspaces"
                        color: root.sumiHi; font.family: root.barFont
                        font.pixelSize: 11; font.weight: Font.Medium
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 22; radius: 11
                        color: ctrlPanel.wsOpen ? root.seal : (wsHeadMa.containsMouse ? ctrlPanel.chipHover : ctrlPanel.chipBg)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        IconText {
                            anchors.centerIn: parent
                            text: "expand_more"
                            rotation: ctrlPanel.wsOpen ? 180 : 0
                            color: ctrlPanel.wsOpen ? root.paper : root.ink
                            font.pixelSize: 16
                            Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                    MouseArea {
                        id: wsHeadMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctrlPanel.wsOpen = !ctrlPanel.wsOpen
                    }
                }

                // display mode: persist 10 / persist 5 / active
                Segmented {
                    width: parent.width
                    visible: ctrlPanel.wsOpen
                    options: [
                        { label: "Persist 10", value: "10"     },
                        { label: "Persist 5",  value: "5"      },
                        { label: "Active",     value: "active" }
                    ]
                    current: root.workspaceMode
                    onChosen: (v) => root.workspaceMode = v
                }

                // Six compact workspace treatments; three columns keep every
                // label legible without widening the control fly-out.
                Grid {
                    id: wsStyleRow
                    width: parent.width
                    visible: ctrlPanel.wsOpen
                    columns: 3
                    spacing: 4
                    readonly property var opts: [
                        { label: "Default", mode: "default" },
                        { label: "Numbers", mode: "numbers" },
                        { label: "Magic",   mode: "magic"   },
                        { label: "Kanji",   mode: "kanji"   },
                        { label: "Frame",   mode: "rings"   },
                        { label: "Aurora",  mode: "aurora"  }
                    ]
                    Repeater {
                        model: wsStyleRow.opts
                        delegate: Tile {
                            required property var modelData
                            width: root.evenW((wsStyleRow.width - wsStyleRow.spacing * (wsStyleRow.columns - 1)) / wsStyleRow.columns)
                            label: modelData.label
                            active: root.workspaceStyle === modelData.mode
                            onActivated: root.workspaceStyle = modelData.mode
                        }
                    }
                }
            }


            // ── LOGO (launcher text/icon variant) ──
            Card {
                title: "Logo"
                trailing: "tap again to cycle"
                Row {
                    width: parent.width
                    spacing: 4
                    Tile {
                        width: root.evenW((parent.width - 4) / 2)
                        icon: "title"
                        label: root.launcherLogoLabel(root.launcherLogoText)
                        active: root.launcherLogoMode === "text"
                        onActivated: {
                            if (root.launcherLogoMode === "text") root.nextLauncherLogoText()
                            else root.launcherLogoMode = "text"
                        }
                    }
                    Tile {
                        width: root.evenW((parent.width - 4) / 2)
                        icon: "category"
                        label: root.launcherLogoLabel(root.launcherLogoIcon)
                        active: root.launcherLogoMode === "icon"
                        onActivated: {
                            if (root.launcherLogoMode === "icon") root.nextLauncherLogoIcon()
                            else root.launcherLogoMode = "icon"
                        }
                    }
                }
            }
        }
    }
}

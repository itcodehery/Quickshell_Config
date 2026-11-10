import QtQuick
import ".."
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../../modules"
import "../../modules/common"
import "../../motion"

Item {
    id: settingsSection
    anchors.fill: parent

    property var root: null
    property var panel: null
    property var dashboardContent: null

    // Robust theme fallback bindings (never throws TypeError even if bound asynchronously)
    readonly property var themeRoot: (root && root.ink) ? root : (dashboardContent && dashboardContent.root ? dashboardContent.root : null)
    readonly property color inkCol: (themeRoot && themeRoot.ink) ? themeRoot.ink : "#ded0bc"
    readonly property color paperCol: (themeRoot && themeRoot.paper) ? themeRoot.paper : "#181715"
    readonly property color sealCol: (themeRoot && themeRoot.seal) ? themeRoot.seal : "#de7e3b"
    readonly property color fillIdleCol: (themeRoot && themeRoot.fillIdle) ? themeRoot.fillIdle : Qt.rgba(0, 0, 0, 0.12)
    readonly property color fillHoverCol: (themeRoot && themeRoot.fillHover) ? themeRoot.fillHover : Qt.rgba(sealCol.r, sealCol.g, sealCol.b, 0.16)
    readonly property color cardBgCol: Qt.rgba(paperCol.r, paperCol.g, paperCol.b, 0.75)
    readonly property color cardBorderCol: "transparent"
    readonly property string fontFam: (themeRoot && themeRoot.barFont) ? themeRoot.barFont : "Genova"

    readonly property bool isBarPill: themeRoot ? themeRoot.isBarPill : true
    readonly property bool isBarNotch: themeRoot ? themeRoot.isBarNotch : false
    readonly property string currentSliderStyle: (themeRoot && themeRoot.sliderStyle) ? themeRoot.sliderStyle : "android17"
    property real demoSliderVal: 65

    readonly property string currentTileShape1x1: (themeRoot && themeRoot.tileShape1x1) ? themeRoot.tileShape1x1 : "circle"
    readonly property string currentTileShape1x2: (themeRoot && themeRoot.tileShape1x2) ? themeRoot.tileShape1x2 : "capsule"
    readonly property string currentTileShape2x2: (themeRoot && themeRoot.tileShape2x2) ? themeRoot.tileShape2x2 : "rounded"
    property string activeTileShapeTab: "1x1" // "presets", "1x1", "1x2", "2x2"

    function setShellStyle(style) {
        if (themeRoot) {
            themeRoot.barShellStyle = style
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setSliderStyle(style) {
        if (themeRoot) {
            themeRoot.sliderStyle = style
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setTileShape1x1(shape) {
        if (themeRoot) {
            themeRoot.tileShape1x1 = shape
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setTileShape1x2(shape) {
        if (themeRoot) {
            themeRoot.tileShape1x2 = shape
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setTileShape2x2(shape) {
        if (themeRoot) {
            themeRoot.tileShape2x2 = shape
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function applyTilePreset(preset) {
        if (themeRoot) {
            themeRoot.setTileShapePreset(preset)
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setBarPosition(pos) {
        if (themeRoot) {
            themeRoot.barPosition = pos
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function toggleBarBorder() {
        if (themeRoot) {
            themeRoot.barBorderEnabled = !themeRoot.barBorderEnabled
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function toggleTooltipBorder() {
        if (themeRoot) {
            themeRoot.panelTooltipBorderEnabled = !themeRoot.panelTooltipBorderEnabled
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setClock12h(val) {
        if (themeRoot) {
            themeRoot.clock12h = val
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function setWeatherImperial(val) {
        if (themeRoot) {
            themeRoot.weatherImperial = val
            if (typeof themeRoot.saveWidgets === "function") themeRoot.saveWidgets()
        }
    }

    function openThemes() {
        if (dashboardContent) dashboardContent.activeDetailView = "theme"
        if (themeRoot) themeRoot.dashboardDetail = "theme"
    }

    function openWallpapers() {
        if (dashboardContent) dashboardContent.activeDetailView = "wallpaper"
        if (themeRoot) themeRoot.dashboardDetail = "wallpaper"
    }

    signal closeRequested()

    property string selectedCat: "bar_style" // "bar_style", "layout", "appearance", "dashboard", "about"
    property string searchQuery: ""

    focus: visible
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_X) {
            closeRequested()
            event.accepted = true
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN SETTINGS LAYOUT (Android / Material 3 Expressive Design) ──
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: CATEGORIES GROUPED LIST WITH ADAPTIVE CORNERS ──────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: 270
            height: columnsRow.height
            radius: 20
            color: settingsSection.cardBgCol
            border.width: 0
            border.color: "transparent"
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // ── Search Settings Bar (Pill with icon) ──
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 17
                    color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.06)
                    border.width: 0
                    border.color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        IconText {
                            text: "search"
                            font.pixelSize: 15
                            color: searchInput.activeFocus ? settingsSection.sealCol : settingsSection.inkCol
                            opacity: searchInput.activeFocus ? 1.0 : 0.6
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        TextInput {
                            id: searchInput
                            width: parent.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: settingsSection.fontFam
                            font.pixelSize: 11
                            color: settingsSection.inkCol
                            clip: true
                            onTextChanged: settingsSection.searchQuery = text.trim().toLowerCase()

                            Text {
                                anchors.fill: parent
                                visible: !searchInput.text && !searchInput.activeFocus
                                text: "Search settings"
                                font.family: settingsSection.fontFam
                                font.pixelSize: 11
                                color: settingsSection.inkCol
                                opacity: 0.45
                            }
                        }
                    }
                }

                // ── Categories Scrollable List ──
                Flickable {
                    id: categoriesFlickable
                    width: parent.width
                    height: parent.height - 34 - parent.spacing
                    contentHeight: categoriesCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: categoriesCol
                        width: parent.width
                        spacing: 8

                        // ── GROUP 1: SHELL & BAR (Bar Style, Position & Layout) ──
                        Column {
                            width: parent.width
                            spacing: 2
                            visible: settingsSection.searchQuery === "" || "bar style notch frame pill position layout edge slider ios android minimal block".indexOf(settingsSection.searchQuery) >= 0

                            // Item 1: Bar Style (Top of Group 1)
                            CategoryTile {
                                catId: "bar_style"
                                catTitle: "Bar Style"
                                catSubtitle: settingsSection.isBarNotch ? "Notch" : "Pill"
                                catIcon: "view_quilt"
                                iconTint: settingsSection.sealCol
                                isFirstInGroup: true
                                isLastInGroup: false
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("bar_style")
                            }

                            // Item 2: Slider Style (Middle of Group 1)
                            CategoryTile {
                                catId: "slider_style"
                                catTitle: "Slider Style"
                                catSubtitle: {
                                    switch (settingsSection.currentSliderStyle) {
                                        case "android17": return "Android 17"
                                        case "ios": return "iOS Capsule"
                                        case "android12": return "Android 12"
                                        case "minimal": return "Minimal"
                                        case "blocky": return "Cyber Block"
                                        default: return "Android 17"
                                    }
                                }
                                catIcon: "tune"
                                iconTint: (settingsSection.themeRoot && settingsSection.themeRoot.color02) ? settingsSection.themeRoot.color02 : "#60a5fa"
                                isFirstInGroup: false
                                isLastInGroup: false
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("slider_style")
                            }

                            // Item 3: Position & Borders (Bottom of Group 1)
                            CategoryTile {
                                catId: "layout"
                                catTitle: "Position & Borders"
                                catSubtitle: ((settingsSection.themeRoot ? settingsSection.themeRoot.barPosition : "top") === "top" ? "Top" : "Bottom") + ", borders"
                                catIcon: "dock_to_bottom"
                                iconTint: (settingsSection.themeRoot && settingsSection.themeRoot.color01) ? settingsSection.themeRoot.color01 : "#fbbf24"
                                isFirstInGroup: false
                                isLastInGroup: true
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("layout")
                            }
                        }

                        // ── GROUP 2: APPEARANCE (Wallpapers, Themes, Colors) ──
                        Column {
                            width: parent.width
                            spacing: 2
                            visible: settingsSection.searchQuery === "" || "wallpaper themes colors appearance scheme".indexOf(settingsSection.searchQuery) >= 0

                            CategoryTile {
                                catId: "appearance"
                                catTitle: "Wallpaper & Style"
                                catSubtitle: "Themes, colors, wallpaper"
                                catIcon: "palette"
                                iconTint: (settingsSection.themeRoot && settingsSection.themeRoot.color06) ? settingsSection.themeRoot.color06 : "#f472b6"
                                isFirstInGroup: true
                                isLastInGroup: true
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("appearance")
                            }
                        }

                        // ── GROUP 3: DASHBOARD & TILES (Grid, Widgets & Shapes) ──
                        Column {
                            width: parent.width
                            spacing: 2
                            visible: settingsSection.searchQuery === "" || "dashboard tiles grid clock format widgets temperature shapes shape 1x1 1x2 2x2 squircle leaf chamfer ticket".indexOf(settingsSection.searchQuery) >= 0

                            // Item 1: Tile Shapes
                            CategoryTile {
                                catId: "tile_shapes"
                                catTitle: "Tile Shapes"
                                catSubtitle: settingsSection.currentTileShape1x1 + " • " + settingsSection.currentTileShape1x2
                                catIcon: "category"
                                iconTint: (settingsSection.themeRoot && settingsSection.themeRoot.color03) ? settingsSection.themeRoot.color03 : "#10b981"
                                isFirstInGroup: true
                                isLastInGroup: false
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("tile_shapes")
                            }

                            // Item 2: Dashboard & Tiles Grid
                            CategoryTile {
                                catId: "dashboard"
                                catTitle: "Dashboard & Tiles"
                                catSubtitle: ((settingsSection.themeRoot ? settingsSection.themeRoot.clock12h : false) ? "12h" : "24h") + ", tiles grid"
                                catIcon: "grid_view"
                                iconTint: (settingsSection.themeRoot && settingsSection.themeRoot.color04) ? settingsSection.themeRoot.color04 : "#a78bfa"
                                isFirstInGroup: false
                                isLastInGroup: true
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("dashboard")
                            }
                        }

                        // ── GROUP 4: ABOUT SYSTEM ──
                        Column {
                            width: parent.width
                            spacing: 2
                            visible: settingsSection.searchQuery === "" || "about system desktop device shell specs".indexOf(settingsSection.searchQuery) >= 0

                            CategoryTile {
                                catId: "about"
                                catTitle: "About Shell"
                                catSubtitle: "Wayland, Quickshell V2"
                                catIcon: "info"
                                iconTint: (settingsSection.themeRoot && settingsSection.themeRoot.color04) ? settingsSection.themeRoot.color04 : "#34d399"
                                isFirstInGroup: true
                                isLastInGroup: true
                                currentSelectedCat: settingsSection.selectedCat
                                onTileClicked: settingsSection.selectCategory("about")
                            }
                        }
                    }
                }
            }
        } // end leftColContainer

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: SETTINGS OPTIONS & DETAIL CARDS ───────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: columnsRow.width - leftColContainer.width - columnsRow.spacing
            height: columnsRow.height
            radius: 20
            color: settingsSection.cardBgCol
            border.width: 0
            border.color: "transparent"
            clip: true

            // Top Header Bar
            Item {
                id: rightTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                height: 28

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: {
                            switch (settingsSection.selectedCat) {
                                case "bar_style": return "Bar Presentation Style"
                                case "slider_style": return "Slider Appearance Style"
                                case "tile_shapes": return "Tile Shapes & Geometry"
                                case "layout": return "Position & Structural Borders"
                                case "appearance": return "Wallpaper & Color Scheme"
                                case "dashboard": return "Dashboard & Tiles Customization"
                                case "about": return "About Shell & Desktop"
                                default: return "Settings"
                            }
                        }
                        font.family: settingsSection.fontFam
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: settingsSection.inkCol
                    }
                }

                // Done / Apply Pill
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: doneRow.implicitWidth + 18
                    radius: 13
                    color: doneMa.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.15)
                    scale: doneMa.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: doneRow
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: "check"
                            font.pixelSize: 12
                            color: settingsSection.sealCol
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Done"
                            font.family: settingsSection.fontFam
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: settingsSection.sealCol
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: doneMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsSection.closeRequested()
                    }
                }
            }

            // Options Body Container with Spring Page Transition
            Item {
                id: rightContentArea
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 6
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                clip: true

                // Spring transition animation when switching category
                transform: Translate {
                    id: catSlideTrans
                    y: 0
                }

                ParallelAnimation {
                    id: catSwitchAnim
                    NumberAnimation { target: rightContentArea; property: "opacity"; from: 0.1; to: 1.0; duration: 220; easing.type: Easing.OutQuad }
                    NumberAnimation { target: rightContentArea; property: "scale"; from: 0.97; to: 1.0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
                    NumberAnimation { target: catSlideTrans; property: "y"; from: 12; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY 1: BAR PRESENTATION STYLE (Pill / Notch / Frame) 
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "bar_style"
                    contentHeight: barStyleCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: barStyleCol
                        width: parent.width
                        spacing: 8

                        // ── Pill Card (Floating Island) ──
                        StyleOptionCard {
                            title: "Pill (Floating Island)"
                            subtitle: "Signature centered floating pill with rounded borders"
                            badgeText: "Floating"
                            isSelected: settingsSection.isBarPill
                            onCardClicked: settingsSection.setShellStyle("pill")

                            // Preview box: floating pill
                            Rectangle {
                                width: 70; height: 38; radius: 6
                                color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08)
                                border.width: 0; border.color: "transparent"
                                clip: true
                                Rectangle {
                                    anchors.top: parent.top; anchors.topMargin: 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 38; height: 7; radius: 3.5
                                    color: settingsSection.isBarPill ? settingsSection.sealCol : settingsSection.inkCol
                                }
                            }
                        }

                        // ── Notch Card (Attached Bezel) ──
                        StyleOptionCard {
                            title: "Notch (Attached Bezel)"
                            subtitle: "Flush against monitor edge with rounded bottom curves"
                            badgeText: "Bezel"
                            isSelected: settingsSection.isBarNotch
                            onCardClicked: settingsSection.setShellStyle("notch")

                            // Preview box: top notch flush to edge
                            Rectangle {
                                width: 70; height: 38; radius: 6
                                color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08)
                                border.width: 0; border.color: "transparent"
                                clip: true
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 44; height: 9
                                    color: settingsSection.isBarNotch ? settingsSection.sealCol : settingsSection.inkCol
                                    bottomLeftRadius: 5; bottomRightRadius: 5
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY: SLIDER APPEARANCE STYLE (Android 17, iOS, Android 12, etc.)
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "slider_style"
                    contentHeight: sliderStyleCol.implicitHeight + 20
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: sliderStyleCol
                        width: parent.width
                        spacing: 8

                        // ── Interactive Live Preview Box ──
                        Rectangle {
                            width: parent.width
                            height: 82
                            radius: 14
                            color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.25)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Item {
                                    width: parent.width
                                    height: 16

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6
                                        IconText {
                                            text: "tune"
                                            font.pixelSize: 13
                                            color: settingsSection.sealCol
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Interactive Live Preview"
                                            font.family: settingsSection.fontFam
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: settingsSection.inkCol
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(settingsSection.demoSliderVal) + "%"
                                        font.family: settingsSection.fontFam
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: settingsSection.sealCol
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 34

                                    StyledSliderTrack {
                                        id: liveDemoTrack
                                        anchors.fill: parent
                                        root: settingsSection.themeRoot
                                        value: settingsSection.demoSliderVal
                                        sliding: liveDemoMa.pressed
                                        accentColor: settingsSection.sealCol
                                        style: settingsSection.currentSliderStyle
                                    }

                                    MouseArea {
                                        id: liveDemoMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        function updateVal(mouse) {
                                            var pct = Math.max(0, Math.min(100, Math.round((mouse.x / width) * 100)))
                                            settingsSection.demoSliderVal = pct
                                        }

                                        onPressed: (mouse) => updateVal(mouse)
                                        onPositionChanged: (mouse) => { if (pressed) updateVal(mouse) }
                                    }
                                }
                            }
                        }

                        // ── Style 1: Android 17 (Default Split Track) ──
                        StyleOptionCard {
                            title: "Android 17"
                            subtitle: "Modern split track with dynamic gap and taller accent pill handle"
                            badgeText: "Default"
                            isSelected: settingsSection.currentSliderStyle === "android17"
                            onCardClicked: settingsSection.setSliderStyle("android17")

                            Item {
                                anchors.centerIn: parent
                                width: 66
                                height: 26

                                StyledSliderTrack {
                                    anchors.fill: parent
                                    root: settingsSection.themeRoot
                                    value: 65
                                    accentColor: settingsSection.sealCol
                                    style: "android17"
                                }
                            }
                        }

                        // ── Style 2: iOS Fluid Capsule ──
                        StyleOptionCard {
                            title: "iOS Fluid Capsule"
                            subtitle: "Full-bleed continuous pill fill with spring dynamic expansion when touched"
                            badgeText: "Fluid"
                            isSelected: settingsSection.currentSliderStyle === "ios"
                            onCardClicked: settingsSection.setSliderStyle("ios")

                            Item {
                                anchors.centerIn: parent
                                width: 66
                                height: 26

                                StyledSliderTrack {
                                    anchors.fill: parent
                                    root: settingsSection.themeRoot
                                    value: 65
                                    accentColor: settingsSection.sealCol
                                    style: "ios"
                                }
                            }
                        }

                        // ── Style 3: Android 12 (Material You) ──
                        StyleOptionCard {
                            title: "Android 12 (Material You)"
                            subtitle: "Bold continuous thick track with recessed contrasting thumb pill indicator"
                            badgeText: "Material"
                            isSelected: settingsSection.currentSliderStyle === "android12"
                            onCardClicked: settingsSection.setSliderStyle("android12")

                            Item {
                                anchors.centerIn: parent
                                width: 66
                                height: 26

                                StyledSliderTrack {
                                    anchors.fill: parent
                                    root: settingsSection.themeRoot
                                    value: 65
                                    accentColor: settingsSection.sealCol
                                    style: "android12"
                                }
                            }
                        }

                        // ── Style 4: Minimal Hairline ──
                        StyleOptionCard {
                            title: "Minimal Hairline"
                            subtitle: "Ultra-clean slim 4px track with a sleek floating circular thumb"
                            badgeText: "Slim"
                            isSelected: settingsSection.currentSliderStyle === "minimal"
                            onCardClicked: settingsSection.setSliderStyle("minimal")

                            Item {
                                anchors.centerIn: parent
                                width: 66
                                height: 26

                                StyledSliderTrack {
                                    anchors.fill: parent
                                    root: settingsSection.themeRoot
                                    value: 65
                                    accentColor: settingsSection.sealCol
                                    style: "minimal"
                                }
                            }
                        }

                        // ── Style 5: Cyber Block ──
                        StyleOptionCard {
                            title: "Cyber Block"
                            subtitle: "Industrial chamfered rail with geometric block handle and accent center core"
                            badgeText: "Futuristic"
                            isSelected: settingsSection.currentSliderStyle === "blocky"
                            onCardClicked: settingsSection.setSliderStyle("blocky")

                            Item {
                                anchors.centerIn: parent
                                width: 66
                                height: 26

                                StyledSliderTrack {
                                    anchors.fill: parent
                                    root: settingsSection.themeRoot
                                    value: 65
                                    accentColor: settingsSection.sealCol
                                    style: "blocky"
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY: TILE SHAPES & GEOMETRY (1x1, 1x2, 2x2 & Presets) 
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "tile_shapes"
                    contentHeight: tileShapesCol.implicitHeight + 20
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: tileShapesCol
                        width: parent.width
                        spacing: 10

                        // ── Interactive Live Preview Header Card ──
                        Rectangle {
                            width: parent.width
                            height: 100
                            radius: 16
                            color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.25)

                            Column {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Row {
                                    width: parent.width
                                    spacing: 6

                                    IconText {
                                        text: "category"
                                        font.pixelSize: 14
                                        color: settingsSection.sealCol
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: "Live Tile Preview"
                                        font.family: settingsSection.fontFam
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: settingsSection.inkCol
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Item { width: 8; height: 1 }
                                    Text {
                                        text: "1x1: " + settingsSection.currentTileShape1x1 + "  •  1x2: " + settingsSection.currentTileShape1x2 + "  •  2x2: " + settingsSection.currentTileShape2x2
                                        font.family: settingsSection.fontFam
                                        font.pixelSize: 10
                                        color: settingsSection.inkCol
                                        opacity: 0.65
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 14

                                    // 1x1 Sample Tile
                                    Item {
                                        width: 48
                                        height: 48

                                        StyledTileShape {
                                            root: settingsSection.themeRoot
                                            span: 1
                                            shapeType: settingsSection.currentTileShape1x1
                                            fillColor: settingsSection.sealCol
                                        }

                                        IconText {
                                            anchors.centerIn: parent
                                            text: "wifi"
                                            font.pixelSize: 20
                                            color: "#ffffff"
                                        }
                                    }

                                    // 1x2 Sample Tile
                                    Item {
                                        width: 120
                                        height: 48

                                        StyledTileShape {
                                            root: settingsSection.themeRoot
                                            span: 2
                                            shapeType: settingsSection.currentTileShape1x2
                                            fillColor: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.10)
                                            borderColor: (settingsSection.themeRoot && settingsSection.themeRoot.isLightMode) ? Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08) : "transparent"
                                            borderWidth: (settingsSection.themeRoot && settingsSection.themeRoot.isLightMode) ? 1 : 0
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8
                                            IconText {
                                                text: "bluetooth"
                                                font.pixelSize: 18
                                                color: settingsSection.sealCol
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 26
                                                spacing: 1
                                                Text {
                                                    text: "Bluetooth"
                                                    font.family: settingsSection.fontFam
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: settingsSection.inkCol
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                                Text {
                                                    text: "Connected"
                                                    font.family: settingsSection.fontFam
                                                    font.pixelSize: 9
                                                    color: settingsSection.inkCol
                                                    opacity: 0.6
                                                    elide: Text.ElideRight
                                                    width: parent.width
                                                }
                                            }
                                        }
                                    }

                                    // 2x2 Sample Mini Tile
                                    Item {
                                        width: 48
                                        height: 48

                                        StyledTileShape {
                                            root: settingsSection.themeRoot
                                            span: 4
                                            shapeType: settingsSection.currentTileShape2x2
                                            fillColor: Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.22)
                                        }

                                        IconText {
                                            anchors.centerIn: parent
                                            text: "bolt"
                                            font.pixelSize: 22
                                            color: settingsSection.sealCol
                                        }
                                    }
                                }
                            }
                        }

                        // ── Segmented Size Switcher Tabs ──
                        Row {
                            width: parent.width
                            spacing: 6

                            // Presets Tab
                            Rectangle {
                                width: (parent.width - 18) / 4
                                height: 28
                                radius: 14
                                color: settingsSection.activeTileShapeTab === "presets"
                                    ? settingsSection.sealCol
                                    : (tabMaPre.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08))
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "✨ Presets"
                                    font.family: settingsSection.fontFam
                                    font.pixelSize: 10
                                    font.weight: settingsSection.activeTileShapeTab === "presets" ? Font.Bold : Font.Normal
                                    color: settingsSection.activeTileShapeTab === "presets" ? "#ffffff" : settingsSection.inkCol
                                }

                                MouseArea {
                                    id: tabMaPre
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsSection.activeTileShapeTab = "presets"
                                }
                            }

                            // 1x1 Tab
                            Rectangle {
                                width: (parent.width - 18) / 4
                                height: 28
                                radius: 14
                                color: settingsSection.activeTileShapeTab === "1x1"
                                    ? settingsSection.sealCol
                                    : (tabMa1.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08))
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "1x1 Tiles"
                                    font.family: settingsSection.fontFam
                                    font.pixelSize: 10
                                    font.weight: settingsSection.activeTileShapeTab === "1x1" ? Font.Bold : Font.Normal
                                    color: settingsSection.activeTileShapeTab === "1x1" ? "#ffffff" : settingsSection.inkCol
                                }

                                MouseArea {
                                    id: tabMa1
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsSection.activeTileShapeTab = "1x1"
                                }
                            }

                            // 1x2 Tab
                            Rectangle {
                                width: (parent.width - 18) / 4
                                height: 28
                                radius: 14
                                color: settingsSection.activeTileShapeTab === "1x2"
                                    ? settingsSection.sealCol
                                    : (tabMa2.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08))
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "1x2 Tiles"
                                    font.family: settingsSection.fontFam
                                    font.pixelSize: 10
                                    font.weight: settingsSection.activeTileShapeTab === "1x2" ? Font.Bold : Font.Normal
                                    color: settingsSection.activeTileShapeTab === "1x2" ? "#ffffff" : settingsSection.inkCol
                                }

                                MouseArea {
                                    id: tabMa2
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsSection.activeTileShapeTab = "1x2"
                                }
                            }

                            // 2x2 Tab
                            Rectangle {
                                width: (parent.width - 18) / 4
                                height: 28
                                radius: 14
                                color: settingsSection.activeTileShapeTab === "2x2"
                                    ? settingsSection.sealCol
                                    : (tabMa4.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08))
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "2x2 Tiles"
                                    font.family: settingsSection.fontFam
                                    font.pixelSize: 10
                                    font.weight: settingsSection.activeTileShapeTab === "2x2" ? Font.Bold : Font.Normal
                                    color: settingsSection.activeTileShapeTab === "2x2" ? "#ffffff" : settingsSection.inkCol
                                }

                                MouseArea {
                                    id: tabMa4
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsSection.activeTileShapeTab = "2x2"
                                }
                            }
                        }

                        // ═════════════════════════════════════════════════════
                        // ── TAB VIEW 0: PRESET COMBINATIONS ──────────────────
                        // ═════════════════════════════════════════════════════
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: settingsSection.activeTileShapeTab === "presets"

                            StyleOptionCard {
                                title: "Material You Classic"
                                subtitle: "Circle (1x1), Stadium Capsule (1x2), Super-Card (2x2)"
                                badgeText: "Default"
                                isSelected: settingsSection.currentTileShape1x1 === "circle" && settingsSection.currentTileShape1x2 === "capsule" && settingsSection.currentTileShape2x2 === "rounded"
                                onCardClicked: settingsSection.applyTilePreset("default")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "capsule"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Continuous Squircle"
                                subtitle: "Unified modern Apple / Material 3 super-ellipse geometry"
                                badgeText: "Unified"
                                isSelected: settingsSection.currentTileShape1x1 === "squircle" && settingsSection.currentTileShape1x2 === "squircle" && settingsSection.currentTileShape2x2 === "squircle"
                                onCardClicked: settingsSection.applyTilePreset("squircle")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "squircle"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Organic Leaf"
                                subtitle: "Fluid asymmetric diagonal curves with natural teardrop tension"
                                badgeText: "Organic"
                                isSelected: settingsSection.currentTileShape1x1 === "leaf" && settingsSection.currentTileShape1x2 === "leaf" && settingsSection.currentTileShape2x2 === "leaf"
                                onCardClicked: settingsSection.applyTilePreset("leaf")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "leaf"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Cyber Chamfer"
                                subtitle: "Futuristic 45° cut corners with high-tech industrial aesthetic"
                                badgeText: "Cyberpunk"
                                isSelected: settingsSection.currentTileShape1x1 === "chamfer" && settingsSection.currentTileShape1x2 === "chamfer" && settingsSection.currentTileShape2x2 === "chamfer"
                                onCardClicked: settingsSection.applyTilePreset("chamfer")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "chamfer"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Retro Ticket"
                                subtitle: "Stylized transit pass with side notches and stamp corners"
                                badgeText: "Retro"
                                isSelected: settingsSection.currentTileShape1x1 === "ticket" && settingsSection.currentTileShape1x2 === "ticket" && settingsSection.currentTileShape2x2 === "ticket"
                                onCardClicked: settingsSection.applyTilePreset("ticket")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "ticket"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Neo-Block Minimal"
                                subtitle: "Crisp Braun / Teenage Engineering tight 6px technical frames"
                                badgeText: "Minimal"
                                isSelected: settingsSection.currentTileShape1x1 === "block" && settingsSection.currentTileShape1x2 === "block" && settingsSection.currentTileShape2x2 === "block"
                                onCardClicked: settingsSection.applyTilePreset("block")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "block"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Geometric Crest"
                                subtitle: "Diamond (1x1), Folder Tab (1x2), and Heraldic Shield (2x2)"
                                badgeText: "Heraldic"
                                isSelected: settingsSection.currentTileShape1x1 === "diamond" && settingsSection.currentTileShape1x2 === "tab" && settingsSection.currentTileShape2x2 === "shield"
                                onCardClicked: settingsSection.applyTilePreset("crest")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 32
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "tab"; fillColor: settingsSection.sealCol }
                                }
                            }
                        }

                        // ═════════════════════════════════════════════════════
                        // ── TAB VIEW 1: 1x1 TILE SHAPE OPTIONS ──────────────
                        // ═════════════════════════════════════════════════════
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: settingsSection.activeTileShapeTab === "1x1"

                            StyleOptionCard {
                                title: "Circle / Pebble"
                                subtitle: "Pure spherical curve with maximum softness"
                                badgeText: "Classic"
                                isSelected: settingsSection.currentTileShape1x1 === "circle"
                                onCardClicked: settingsSection.setTileShape1x1("circle")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "circle"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Continuous Squircle"
                                subtitle: "Refined super-ellipse with balanced continuous curvature"
                                badgeText: "Squircle"
                                isSelected: settingsSection.currentTileShape1x1 === "squircle"
                                onCardClicked: settingsSection.setTileShape1x1("squircle")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "squircle"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Organic Leaf"
                                subtitle: "Dynamic diagonal asymmetric teardrop silhouette"
                                badgeText: "Fluid"
                                isSelected: settingsSection.currentTileShape1x1 === "leaf"
                                onCardClicked: settingsSection.setTileShape1x1("leaf")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "leaf"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Cyber Octagon"
                                subtitle: "Diagonal 45° chamfered cuts on all four corners"
                                badgeText: "Cyber"
                                isSelected: settingsSection.currentTileShape1x1 === "chamfer"
                                onCardClicked: settingsSection.setTileShape1x1("chamfer")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "chamfer"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Diamond Emblem"
                                subtitle: "Rounded rhombus crest with expressive geometric vertices"
                                badgeText: "Emblem"
                                isSelected: settingsSection.currentTileShape1x1 === "diamond"
                                onCardClicked: settingsSection.setTileShape1x1("diamond")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "diamond"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Ticket Stamp"
                                subtitle: "Scalloped inward circular corner cutouts"
                                badgeText: "Stamp"
                                isSelected: settingsSection.currentTileShape1x1 === "ticket"
                                onCardClicked: settingsSection.setTileShape1x1("ticket")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "ticket"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Neo-Block"
                                subtitle: "Ultra-clean tight 6px radius with architectural precision"
                                badgeText: "Technical"
                                isSelected: settingsSection.currentTileShape1x1 === "block"
                                onCardClicked: settingsSection.setTileShape1x1("block")

                                Item {
                                    anchors.centerIn: parent; width: 34; height: 34
                                    StyledTileShape { root: settingsSection.themeRoot; span: 1; shapeType: "block"; fillColor: settingsSection.sealCol }
                                }
                            }
                        }

                        // ═════════════════════════════════════════════════════
                        // ── TAB VIEW 2: 1x2 TILE SHAPE OPTIONS ──────────────
                        // ═════════════════════════════════════════════════════
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: settingsSection.activeTileShapeTab === "1x2"

                            StyleOptionCard {
                                title: "Stadium Capsule"
                                subtitle: "Seamless full-radius ends for a signature floating pill"
                                badgeText: "Pill"
                                isSelected: settingsSection.currentTileShape1x2 === "capsule"
                                onCardClicked: settingsSection.setTileShape1x2("capsule")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "capsule"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Squircle Card"
                                subtitle: "Continuous super-ellipse card with balanced modern corners"
                                badgeText: "Card"
                                isSelected: settingsSection.currentTileShape1x2 === "squircle"
                                onCardClicked: settingsSection.setTileShape1x2("squircle")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "squircle"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Asymmetric Leaf"
                                subtitle: "Dynamic opposite-corner curve ratio with directional flair"
                                badgeText: "Organic"
                                isSelected: settingsSection.currentTileShape1x2 === "leaf"
                                onCardClicked: settingsSection.setTileShape1x2("leaf")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "leaf"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Cyber Chamfer"
                                subtitle: "Angled chamfered corners evoking tactical UI panels"
                                badgeText: "Hex-Cut"
                                isSelected: settingsSection.currentTileShape1x2 === "chamfer"
                                onCardClicked: settingsSection.setTileShape1x2("chamfer")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "chamfer"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Transit Ticket"
                                subtitle: "Circular notch scallops cut into left and right flanks"
                                badgeText: "Ticket"
                                isSelected: settingsSection.currentTileShape1x2 === "ticket"
                                onCardClicked: settingsSection.setTileShape1x2("ticket")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "ticket"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Folder Tab"
                                subtitle: "Rounded upper corners and crisp lower anchors"
                                badgeText: "Tabbed"
                                isSelected: settingsSection.currentTileShape1x2 === "tab"
                                onCardClicked: settingsSection.setTileShape1x2("tab")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "tab"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Neo-Block"
                                subtitle: "Crisp 6px radius card with sharp modernist structure"
                                badgeText: "Industrial"
                                isSelected: settingsSection.currentTileShape1x2 === "block"
                                onCardClicked: settingsSection.setTileShape1x2("block")

                                Item {
                                    anchors.centerIn: parent; width: 66; height: 28
                                    StyledTileShape { root: settingsSection.themeRoot; span: 2; shapeType: "block"; fillColor: settingsSection.sealCol }
                                }
                            }
                        }

                        // ═════════════════════════════════════════════════════
                        // ── TAB VIEW 3: 2x2 TILE SHAPE OPTIONS ──────────────
                        // ═════════════════════════════════════════════════════
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: settingsSection.activeTileShapeTab === "2x2"

                            StyleOptionCard {
                                title: "Super-Card"
                                subtitle: "Generous 28px modern rounded corner box"
                                badgeText: "Default"
                                isSelected: settingsSection.currentTileShape2x2 === "rounded"
                                onCardClicked: settingsSection.setTileShape2x2("rounded")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "rounded"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Continuous Squircle"
                                subtitle: "Smooth continuous curvature super-ellipse container"
                                badgeText: "Squircle"
                                isSelected: settingsSection.currentTileShape2x2 === "squircle"
                                onCardClicked: settingsSection.setTileShape2x2("squircle")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "squircle"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Organic Pebble"
                                subtitle: "Asymmetric diagonal curves creating natural organic flow"
                                badgeText: "Pebble"
                                isSelected: settingsSection.currentTileShape2x2 === "leaf"
                                onCardClicked: settingsSection.setTileShape2x2("leaf")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "leaf"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Cyber Fortress"
                                subtitle: "Aggressive diagonal 45° cuts evoking reinforced plating"
                                badgeText: "Cyber"
                                isSelected: settingsSection.currentTileShape2x2 === "chamfer"
                                onCardClicked: settingsSection.setTileShape2x2("chamfer")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "chamfer"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Event Ticket"
                                subtitle: "Decorative inward scallops on all four corner quadrants"
                                badgeText: "Ticket"
                                isSelected: settingsSection.currentTileShape2x2 === "ticket"
                                onCardClicked: settingsSection.setTileShape2x2("ticket")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "ticket"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Heraldic Shield"
                                subtitle: "Curved heraldic crest profile tapering down toward the base"
                                badgeText: "Shield"
                                isSelected: settingsSection.currentTileShape2x2 === "shield"
                                onCardClicked: settingsSection.setTileShape2x2("shield")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "shield"; fillColor: settingsSection.sealCol }
                                }
                            }

                            StyleOptionCard {
                                title: "Neo-Block"
                                subtitle: "Crisp 8px technical frame with clean industrial borders"
                                badgeText: "Technical"
                                isSelected: settingsSection.currentTileShape2x2 === "block"
                                onCardClicked: settingsSection.setTileShape2x2("block")

                                Item {
                                    anchors.centerIn: parent; width: 38; height: 38
                                    StyledTileShape { root: settingsSection.themeRoot; span: 4; shapeType: "block"; fillColor: settingsSection.sealCol }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY 2: POSITION & STRUCTURAL BORDERS 
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "layout"
                    contentHeight: layoutCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: layoutCol
                        width: parent.width
                        spacing: 8

                        // Setting: Bar Screen Edge
                        SettingsOptionRow {
                            title: "Bar Edge Position"
                            description: "Anchor the bar and frame to the top or bottom of the screen"
                            Row {
                                spacing: 4

                                BouncyPillButton {
                                    label: "Top"
                                    isActive: (settingsSection.themeRoot ? settingsSection.themeRoot.barPosition : "top") === "top"
                                    onClicked: settingsSection.setBarPosition("top")
                                }
                                BouncyPillButton {
                                    label: "Bottom"
                                    isActive: (settingsSection.themeRoot ? settingsSection.themeRoot.barPosition : "top") === "bottom"
                                    onClicked: settingsSection.setBarPosition("bottom")
                                }
                            }
                        }

                        // Setting: Outer Bar Border
                        SettingsOptionRow {
                            title: "Outer Bar Border"
                            description: "Draw a crisp contrasting border line around the bar surface"
                            BouncySwitch {
                                checked: settingsSection.themeRoot ? settingsSection.themeRoot.barBorderEnabled : true
                                onToggled: settingsSection.toggleBarBorder()
                            }
                        }

                        // Setting: Panel & Tooltip Border
                        SettingsOptionRow {
                            title: "Panel & Tooltip Borders"
                            description: "Draw structural perimeter borders around popup cards and menus"
                            BouncySwitch {
                                checked: settingsSection.themeRoot ? settingsSection.themeRoot.panelTooltipBorderEnabled : true
                                onToggled: settingsSection.toggleTooltipBorder()
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY 3: WALLPAPER & COLOR SCHEME 
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "appearance"
                    contentHeight: appearanceCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: appearanceCol
                        width: parent.width
                        spacing: 8

                        // Setting: Themes Switcher
                        SettingsOptionRow {
                            title: "Color Schemes & Palettes"
                            description: "Switch active palette, accents, and contrast"
                            BouncyPillButton {
                                label: "Open Themes"
                                isActive: true
                                onClicked: settingsSection.openThemes()
                            }
                        }

                        // Setting: Wallpaper Gallery
                        SettingsOptionRow {
                            title: "Wallpaper Gallery"
                            description: "Browse and set desktop backgrounds with live transitions"
                            BouncyPillButton {
                                label: "Wallpapers"
                                isActive: true
                                onClicked: settingsSection.openWallpapers()
                            }
                        }

                        // Color Palette Swatches Preview Card
                        Rectangle {
                            width: parent.width
                            height: 48
                            radius: 12
                            color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05)
                            border.width: 0
                            border.color: "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    text: "Current Accent Palette"
                                    font.family: settingsSection.fontFam
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: settingsSection.inkCol
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: Math.max(1, parent.width - 200 - swatchesRow.implicitWidth); height: 1 }

                                Row {
                                    id: swatchesRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            settingsSection.sealCol,
                                            (settingsSection.themeRoot && settingsSection.themeRoot.color01) ? settingsSection.themeRoot.color01 : "#d15842",
                                            (settingsSection.themeRoot && settingsSection.themeRoot.color03) ? settingsSection.themeRoot.color03 : "#dca85b",
                                            (settingsSection.themeRoot && settingsSection.themeRoot.color04) ? settingsSection.themeRoot.color04 : "#55889e",
                                            (settingsSection.themeRoot && settingsSection.themeRoot.color06) ? settingsSection.themeRoot.color06 : "#de7e3b"
                                        ]
                                        delegate: Rectangle {
                                            width: 18; height: 18; radius: 9
                                            color: modelData
                                            border.width: 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY 4: DASHBOARD & TILES CUSTOMIZATION 
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "dashboard"
                    contentHeight: dashboardCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: dashboardCol
                        width: parent.width
                        spacing: 8

                        // Setting: Clock Time Format
                        SettingsOptionRow {
                            title: "Clock Time Format"
                            description: "Select 12-hour AM/PM vs 24-hour military format"
                            Row {
                                spacing: 4

                                BouncyPillButton {
                                    label: "12h"
                                    isActive: settingsSection.themeRoot ? settingsSection.themeRoot.clock12h : false
                                    onClicked: settingsSection.setClock12h(true)
                                }
                                BouncyPillButton {
                                    label: "24h"
                                    isActive: !(settingsSection.themeRoot ? settingsSection.themeRoot.clock12h : false)
                                    onClicked: settingsSection.setClock12h(false)
                                }
                            }
                        }

                        // Setting: Temperature Unit
                        SettingsOptionRow {
                            title: "Temperature Scale"
                            description: "Format for weather forecast and thermal sensors"
                            Row {
                                spacing: 4

                                BouncyPillButton {
                                    label: "°C"
                                    isActive: !(settingsSection.themeRoot ? settingsSection.themeRoot.weatherImperial : false)
                                    onClicked: settingsSection.setWeatherImperial(false)
                                }
                                BouncyPillButton {
                                    label: "°F"
                                    isActive: settingsSection.themeRoot ? settingsSection.themeRoot.weatherImperial : false
                                    onClicked: settingsSection.setWeatherImperial(true)
                                }
                            }
                        }

                        // Setting: Tile Grid Management
                        SettingsOptionRow {
                            title: "Dashboard Tiles Grid"
                            description: "Rearrange tiles, resize spans, or restore default arrangement"
                            Row {
                                spacing: 6

                                BouncyPillButton {
                                    label: "Edit Layout"
                                    isActive: true
                                    onClicked: {
                                        if (dashboardContent) {
                                            dashboardContent.activeDetailView = ""
                                            dashboardContent.editTilesMode = true
                                        }
                                        settingsSection.closeRequested()
                                    }
                                }
                                BouncyPillButton {
                                    label: "Reset"
                                    isActive: false
                                    onClicked: {
                                        if (dashboardContent) dashboardContent.resetTilesLayout()
                                    }
                                }
                            }
                        }
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // ── CATEGORY 5: ABOUT SHELL (Reference Image Googlebook Style) 
                // ─────────────────────────────────────────────────────────────
                Flickable {
                    anchors.fill: parent
                    visible: settingsSection.selectedCat === "about"
                    contentHeight: aboutCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    Column {
                        id: aboutCol
                        width: parent.width
                        spacing: 8

                        // Section Tag: Shell details
                        Text {
                            text: "Shell & Environment Details"
                            font.family: settingsSection.fontFam
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: settingsSection.sealCol
                        }

                        // Grouped Info Card (Matches reference image 'Device details' container)
                        Rectangle {
                            width: parent.width
                            height: aboutInfoCol.implicitHeight + 16
                            radius: 14
                            color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05)
                            border.width: 0
                            border.color: "transparent"

                            Column {
                                id: aboutInfoCol
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Row {
                                    width: parent.width
                                    Text { width: 140; text: "Desktop Shell"; font.family: settingsSection.fontFam; font.pixelSize: 11; font.weight: Font.DemiBold; color: settingsSection.inkCol }
                                    Text { text: "Quickshell V2 (Wayland)"; font.family: settingsSection.fontFam; font.pixelSize: 11; color: settingsSection.inkCol; opacity: 0.75 }
                                }
                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08) }

                                Row {
                                    width: parent.width
                                    Text { width: 140; text: "Active Bar Style"; font.family: settingsSection.fontFam; font.pixelSize: 11; font.weight: Font.DemiBold; color: settingsSection.inkCol }
                                    Text { text: settingsSection.isBarNotch ? "Notch (Attached Bezel)" : "Pill (Floating Island)"; font.family: settingsSection.fontFam; font.pixelSize: 11; font.weight: Font.Bold; color: settingsSection.sealCol }
                                }
                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08) }

                                Row {
                                    width: parent.width
                                    Text { width: 140; text: "Compositor"; font.family: settingsSection.fontFam; font.pixelSize: 11; font.weight: Font.DemiBold; color: settingsSection.inkCol }
                                    Text { text: "Hyprland Wayland Compositor"; font.family: settingsSection.fontFam; font.pixelSize: 11; color: settingsSection.inkCol; opacity: 0.75 }
                                }
                                Rectangle { width: parent.width; height: 1; color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08) }

                                Row {
                                    width: parent.width
                                    Text { width: 140; text: "Bar Position"; font.family: settingsSection.fontFam; font.pixelSize: 11; font.weight: Font.DemiBold; color: settingsSection.inkCol }
                                    Text { text: (settingsSection.themeRoot ? settingsSection.themeRoot.barPosition : "top") === "top" ? "Top Monitor Edge" : "Bottom Monitor Edge"; font.family: settingsSection.fontFam; font.pixelSize: 11; color: settingsSection.inkCol; opacity: 0.75 }
                                }
                            }
                        }
                    }
                }
            } // end rightContentArea
        } // end rightColContainer
    } // end Row

    function selectCategory(cat) {
        if (selectedCat !== cat) {
            selectedCat = cat
            catSwitchAnim.restart()
        }
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── INLINE COMPONENTS: CATEGORY TILE WITH ADAPTIVE CORNER SHAPING ────────
    // ═════════════════════════════════════════════════════════════════════════
    component CategoryTile: Item {
        id: tileItem
        width: parent.width
        height: 48

        required property string catId
        required property string catTitle
        required property string catSubtitle
        required property string catIcon
        required property color iconTint
        required property bool isFirstInGroup
        required property bool isLastInGroup
        required property string currentSelectedCat

        signal tileClicked()

        readonly property bool isSelected: currentSelectedCat === catId

        // Target Radii: Fully rounded all around (22px) when selected, flatter (4px) on adjacent edges when unselected
        readonly property real targetTopR: isSelected ? 22 : ((isFirstInGroup && isLastInGroup) ? 22 : (isFirstInGroup ? 22 : 4))
        readonly property real targetBotR: isSelected ? 22 : ((isFirstInGroup && isLastInGroup) ? 22 : (isLastInGroup ? 22 : 4))

        property real topR: targetTopR
        Behavior on topR {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }

        property real botR: targetBotR
        Behavior on botR {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }

        // Press Scale Feedback (no hover scale up)
        scale: tileMa.pressed ? 0.96 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutQuad
            }
        }

        // Shape with Dynamic Corner Radii
        Shape {
            id: tileShape
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            readonly property real w: width
            readonly property real h: height
            readonly property real tr: tileItem.topR
            readonly property real br: tileItem.botR

            ShapePath {
                strokeColor: "transparent"
                strokeWidth: 0
                fillColor: tileItem.isSelected
                    ? Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.22)
                    : (tileMa.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05))

                startX: tileShape.tr; startY: 0
                PathLine { x: tileShape.w - tileShape.tr; y: 0 }
                PathArc { x: tileShape.w; y: tileShape.tr; radiusX: tileShape.tr; radiusY: tileShape.tr }
                PathLine { x: tileShape.w; y: tileShape.h - tileShape.br }
                PathArc { x: tileShape.w - tileShape.br; y: tileShape.h; radiusX: tileShape.br; radiusY: tileShape.br }
                PathLine { x: tileShape.br; y: tileShape.h }
                PathArc { x: 0; y: tileShape.h - tileShape.br; radiusX: tileShape.br; radiusY: tileShape.br }
                PathLine { x: 0; y: tileShape.tr }
                PathArc { x: tileShape.tr; y: 0; radiusX: tileShape.tr; radiusY: tileShape.tr }
            }
        }

        // Tile Content
        Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            // Pastel/Tinted Circle Container with Icon (Matches reference image)
            Rectangle {
                width: 30
                height: 30
                radius: 15
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(tileItem.iconTint.r, tileItem.iconTint.g, tileItem.iconTint.b, tileItem.isSelected ? 0.35 : 0.18)
                Behavior on color { ColorAnimation { duration: 150 } }

                IconText {
                    anchors.centerIn: parent
                    text: tileItem.catIcon
                    font.pixelSize: 15
                    color: tileItem.iconTint
                }
            }

            // Title and Subtitle
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30 - 10
                spacing: 2

                Text {
                    text: tileItem.catTitle
                    font.family: settingsSection.fontFam
                    font.pixelSize: 11
                    font.weight: tileItem.isSelected ? Font.Bold : Font.DemiBold
                    color: settingsSection.inkCol
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: tileItem.catSubtitle
                    font.family: settingsSection.fontFam
                    font.pixelSize: 9
                    color: settingsSection.inkCol
                    opacity: tileItem.isSelected ? 0.85 : 0.55
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tileItem.tileClicked()
        }
    }

    // ── Option Card for Bar Style Selection ──
    component StyleOptionCard: Rectangle {
        id: styleCard
        width: parent.width
        height: 56
        radius: 14

        required property string title
        required property string subtitle
        required property string badgeText
        required property bool isSelected
        default property alias contentData: previewContainer.data

        signal cardClicked()

        color: isSelected
            ? Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.22)
            : (styleCardMa.containsMouse ? settingsSection.fillHoverCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05))
        border.width: 0
        border.color: "transparent"

        // Press scale feedback only (hovering does NOT scale)
        scale: styleCardMa.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            Item {
                id: previewContainer
                width: 70
                height: 38
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 70 - 12 - 28
                spacing: 3

                Row {
                    spacing: 6
                    Text {
                        text: styleCard.title
                        font.family: settingsSection.fontFam
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: settingsSection.inkCol
                    }
                    Rectangle {
                        height: 14
                        radius: 7
                        width: badgeTextItem.implicitWidth + 8
                        color: styleCard.isSelected ? Qt.rgba(settingsSection.sealCol.r, settingsSection.sealCol.g, settingsSection.sealCol.b, 0.25) : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08)
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: badgeTextItem
                            anchors.centerIn: parent
                            text: styleCard.badgeText
                            font.family: settingsSection.fontFam
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: styleCard.isSelected ? settingsSection.sealCol : settingsSection.inkCol
                            opacity: styleCard.isSelected ? 1.0 : 0.7
                        }
                    }
                }

                Text {
                    text: styleCard.subtitle
                    font.family: settingsSection.fontFam
                    font.pixelSize: 10
                    color: settingsSection.inkCol
                    opacity: 0.65
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            // Radio check indicator with lively bounce
            Rectangle {
                width: 20
                height: 20
                radius: 10
                anchors.verticalCenter: parent.verticalCenter
                color: styleCard.isSelected ? settingsSection.sealCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.12)
                border.width: 0

                IconText {
                    anchors.centerIn: parent
                    text: "check"
                    font.pixelSize: 13
                    color: settingsSection.paperCol
                    visible: styleCard.isSelected
                    scale: styleCard.isSelected ? 1.0 : 0.0
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }
                }
            }
        }

        MouseArea {
            id: styleCardMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: styleCard.cardClicked()
        }
    }

    // ── Row Container for Generic Settings ──
    component SettingsOptionRow: Rectangle {
        id: optRow
        width: parent.width
        height: 44
        radius: 12
        color: Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.05)
        border.width: 0
        border.color: "transparent"

        required property string title
        required property string description
        default property alias trailingContent: trailingSlot.data

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - trailingSlot.width - 16
                spacing: 2

                Text {
                    text: optRow.title
                    font.family: settingsSection.fontFam
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: settingsSection.inkCol
                }
                Text {
                    text: optRow.description
                    font.family: settingsSection.fontFam
                    font.pixelSize: 9
                    color: settingsSection.inkCol
                    opacity: 0.6
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            Item {
                id: trailingSlot
                anchors.verticalCenter: parent.verticalCenter
                width: childrenRect.width
                height: childrenRect.height
            }
        }
    }

    // ── Bouncy Segmented Pill Button ──
    component BouncyPillButton: Rectangle {
        id: pillBtn
        height: 26
        width: btnText.implicitWidth + 18
        radius: 13

        required property string label
        required property bool isActive

        signal clicked()

        color: isActive ? settingsSection.sealCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.08)
        Behavior on color { ColorAnimation { duration: 150 } }

        scale: pillBtnMa.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: pillBtn.label
            font.family: settingsSection.fontFam
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: pillBtn.isActive ? settingsSection.paperCol : settingsSection.inkCol
        }

        MouseArea {
            id: pillBtnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pillBtn.clicked()
        }
    }

    // ── Bouncy Toggle Switch ──
    component BouncySwitch: Rectangle {
        id: switchRoot
        width: 38
        height: 20
        radius: 10

        required property bool checked
        signal toggled()

        color: checked ? settingsSection.sealCol : Qt.rgba(settingsSection.inkCol.r, settingsSection.inkCol.g, settingsSection.inkCol.b, 0.16)
        Behavior on color { ColorAnimation { duration: 150 } }

        scale: switchMa.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

        Rectangle {
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: switchRoot.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
            color: settingsSection.paperCol
        }

        MouseArea {
            id: switchMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: switchRoot.toggled()
        }
    }
}

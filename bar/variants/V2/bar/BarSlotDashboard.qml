import QtQuick
import ".."
import Quickshell
import Quickshell.Io
import "../modules"
import "../panels"
import "../motion"

// ── In-place expanded Island Dock dashboard ──
Item {
    id: expandedDashboardContainer
    required property var barSlot

    clip: true
    opacity: expandedDashboardContainer.barSlot.isDashboardActive ? 1.0 : 0.0
    scale: expandedDashboardContainer.barSlot.isDashboardActive ? 1.0 : 0.97
    transform: Translate {
        y: expandedDashboardContainer.barSlot.isDashboardActive ? 0 : (expandedDashboardContainer.barSlot.root.barPosition === "bottom" ? 14 : -14)
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
    }
    visible: opacity > 0.001
    enabled: expandedDashboardContainer.barSlot.isDashboardActive
    Behavior on opacity {
        NumberAnimation {
            duration: expandedDashboardContainer.barSlot.isDashboardActive ? 250 : 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: expandedDashboardContainer.barSlot.isDashboardActive ? 250 : 160
            easing.type: Easing.OutCubic
        }
    }

    property date now: new Date()
    Timer {
        interval: 1000
        running: expandedDashboardContainer.barSlot.isDashboardActive
        repeat: true
        onTriggered: expandedDashboardContainer.now = new Date()
    }

    function pad(n) { return n < 10 ? "0" + n : String(n) }

    readonly property string hourStr: {
        var h = expandedDashboardContainer.barSlot.root.clock12h ? now.getHours() % 12 : now.getHours()
        if (expandedDashboardContainer.barSlot.root.clock12h && h === 0) h = 12
        return pad(h)
    }
    readonly property string minStr: pad(now.getMinutes())
    readonly property string amPmStr: expandedDashboardContainer.barSlot.root.clock12h ? (now.getHours() < 12 ? "AM" : "PM") : ""

    readonly property var months: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    readonly property var days: ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    readonly property var shortDays: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
    readonly property string dateStr: days[now.getDay()] + ", " + now.getDate() + " " + months[now.getMonth()]
    readonly property string dateShortStr: shortDays[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate()

    QtObject {
        id: dashboardAdapter
        property bool expanded: expandedDashboardContainer.barSlot.root.dashboardExpanded
        onExpandedChanged: {
            if (expandedDashboardContainer.barSlot.root.dashboardExpanded !== expanded) {
                expandedDashboardContainer.barSlot.root.dashboardExpanded = expanded
            }
        }
        property bool searchOpen: false
        function toggleSearch() {
            searchOpen = !searchOpen
            if (searchOpen) {
                petSearch.open()
            } else {
                petSearch.close()
            }
        }
        function toggleSearchEngine() {
            if (petSearch) petSearch.toggleEngine()
        }
    }

    Timer {
        id: dashboardCloseTimer
        interval: 220
        repeat: false
        onTriggered: {
            expandedDashboardContainer.barSlot.isDashboardClosing = false
            if (dashboardLoader.item) {
                dashboardLoader.item.activeDetailView = ""
                dashboardLoader.item.selectCategoryByIndex(0)
            }
            expandedDashboardContainer.barSlot.root.dashboardDetail = ""
        }
    }

    Connections {
        target: expandedDashboardContainer.barSlot
        function onIsDashboardActiveChanged() {
            if (expandedDashboardContainer.barSlot.isDashboardActive) {
                dashboardCloseTimer.stop()
                expandedDashboardContainer.barSlot.isDashboardClosing = false
                expandedDashboardContainer.barSlot.dashboardEverActivated = true
                if (dashboardLoader.item) {
                    if (!expandedDashboardContainer.barSlot.root.dashboardDetail) {
                        dashboardLoader.item.activeDetailView = ""
                        dashboardLoader.item.selectCategoryByIndex(0)
                    } else {
                        dashboardLoader.item.activeDetailView = expandedDashboardContainer.barSlot.root.dashboardDetail
                    }
                    dashboardLoader.item.forceActiveFocus()
                }
            } else {
                dashboardAdapter.searchOpen = false
                if (petSearch) petSearch.close()
                expandedDashboardContainer.barSlot.isDashboardClosing = true
                dashboardCloseTimer.restart()
            }
        }
    }

    // ── WHOLE DASHBOARD SUB-PAGE NAVIGATION SIDEBAR ──
    Rectangle {
        id: subPageSidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: expandedDashboardContainer.barSlot.isSubPageOpen ? 46 : 0
        clip: true
        visible: width > 0.5 || opacity > 0.01
        opacity: expandedDashboardContainer.barSlot.isSubPageOpen ? 1.0 : 0.0
        z: 30

        topLeftRadius: expandedDashboardContainer.barSlot.dashboardTopRadius
        bottomLeftRadius: expandedDashboardContainer.barSlot.dashboardBottomRadius
        topRightRadius: 0
        bottomRightRadius: 0

        color: Qt.darker(expandedDashboardContainer.barSlot.root.barBg, 1.35)

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        readonly property var subPagesList: [
            { id: "wifi",          name: "Wi-Fi & Network",    icon: "wifi" },
            { id: "bluetooth",     name: "Bluetooth",         icon: "bluetooth" },
            { id: "volume",        name: "Sound & Volume",    icon: "volume_up" },
            { id: "battery",       name: "Battery & Power",   icon: "battery_charging_full" },
            { id: "screentime",    name: "Screen Time",       icon: "schedule" },
            { id: "notifications", name: "Notifications",     icon: "notifications" },
            { id: "calendar",      name: "Calendar & Notes",  icon: "calendar_month" },
            { id: "notes",         name: "Notes",             icon: "edit_note" },
            { id: "theme",         name: "Themes",            icon: "palette" },
            { id: "wallpaper",     name: "Wallpapers",        icon: "wallpaper" },
            { id: "system",        name: "System & Power",    icon: "power_settings_new" },
            { id: "plugins",       name: "Omarchy Plugins",   icon: "extension" },
            { id: "updates",       name: "Software Updates",  icon: "system_update" }
        ]

        function isSubPageActive(pageId) {
            if (expandedDashboardContainer.barSlot.root.dashboardDetail === pageId) return true
            if (pageId === "updates" && expandedDashboardContainer.barSlot.root.dashboardDetail === "packages") return true
            return false
        }

        // Top: Omarchy Logo Home Button
        Rectangle {
            id: sidebarHomeBtn
            width: 34
            height: 34
            radius: 12
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            color: sidebarHomeMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: expandedDashboardContainer.barSlot.root.launcherLogoIconGlyph(expandedDashboardContainer.barSlot.root.launcherLogoIcon)
                font.family: expandedDashboardContainer.barSlot.root.launcherLogoIconFont(expandedDashboardContainer.barSlot.root.launcherLogoIcon)
                font.pixelSize: 18
                color: sidebarHomeMa.containsMouse ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink
                renderType: Text.QtRendering
            }

            SpringPress {}

            TooltipMixin {
                root: expandedDashboardContainer.barSlot.root
                owner: parent
                text: "Omarchy (Home)"
            }

            MouseArea {
                id: sidebarHomeMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                    if (dashboardLoader.item) {
                        dashboardLoader.item.activeDetailView = ""
                        dashboardLoader.item.selectCategoryByIndex(0)
                    }
                }
            }
        }

        // Separator under back button
        Rectangle {
            id: sidebarSep
            anchors.top: sidebarHomeBtn.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 24
            height: 1
            color: Qt.rgba(expandedDashboardContainer.barSlot.root.ink.r, expandedDashboardContainer.barSlot.root.ink.g, expandedDashboardContainer.barSlot.root.ink.b, 0.14)
        }

        // Scrollable list of sub-pages
        Flickable {
            id: sidebarFlick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sidebarSep.bottom
            anchors.topMargin: 6
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            clip: true
            contentHeight: sidebarCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                target: sidebarFlick
                onWheel: function(event) {
                    sidebarFlick.contentY = Math.max(0, Math.min(Math.max(0, sidebarFlick.contentHeight - sidebarFlick.height), sidebarFlick.contentY - event.angleDelta.y))
                }
            }

            Column {
                id: sidebarCol
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                width: parent.width

                Repeater {
                    model: subPageSidebar.subPagesList
                    delegate: Rectangle {
                        id: subPageBtn
                        required property var modelData
                        required property int index
                        width: 34
                        height: 34
                        radius: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        readonly property bool isSelected: subPageSidebar.isSubPageActive(modelData.id)

                        color: isSelected
                            ? expandedDashboardContainer.barSlot.root.seal
                            : (subPageMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        IconText {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: {
                                if (subPageBtn.isSelected) {
                                    var luma = expandedDashboardContainer.barSlot.root.seal.r * 0.299 + expandedDashboardContainer.barSlot.root.seal.g * 0.587 + expandedDashboardContainer.barSlot.root.seal.b * 0.114
                                    return luma > 0.5 ? "#121212" : "#ffffff"
                                }
                                return subPageMa.containsMouse ? expandedDashboardContainer.barSlot.root.ink : Qt.rgba(expandedDashboardContainer.barSlot.root.ink.r, expandedDashboardContainer.barSlot.root.ink.g, expandedDashboardContainer.barSlot.root.ink.b, 0.72)
                            }
                            font.pixelSize: 18
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        SpringPress {}

                        TooltipMixin {
                            root: expandedDashboardContainer.barSlot.root
                            owner: parent
                            text: modelData.name
                        }

                        MouseArea {
                            id: subPageMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = modelData.id
                                if (dashboardLoader.item) {
                                    dashboardLoader.item.activeDetailView = modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Main Dashboard Area (Shifts right when sidebar is open)
    Rectangle {
        id: dashboardMainContent
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: expandedDashboardContainer.barSlot.isSubPageOpen ? subPageSidebar.right : parent.left
        anchors.leftMargin: 0

        topLeftRadius: expandedDashboardContainer.barSlot.isSubPageOpen ? 24 : expandedDashboardContainer.barSlot.dashboardTopRadius
        bottomLeftRadius: expandedDashboardContainer.barSlot.isSubPageOpen ? 24 : expandedDashboardContainer.barSlot.dashboardBottomRadius
        topRightRadius: expandedDashboardContainer.barSlot.dashboardTopRadius
        bottomRightRadius: expandedDashboardContainer.barSlot.dashboardBottomRadius

        color: expandedDashboardContainer.barSlot.isSubPageOpen ? expandedDashboardContainer.barSlot.root.barBg : "transparent"
        border.width: 0
        clip: true

        // Unified Top Header Bar
        Item {
            id: topHeaderBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 28
            anchors.topMargin: 14
            height: 32
            z: 10

            // Left Side: System Pet + Cute Search Bar + Clock Pill + Battery Pill
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                SystemPet {
                    id: systemPet
                    root: expandedDashboardContainer.barSlot.root
                    curious: dashboardAdapter.searchOpen
                    height: 32
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: dashboardAdapter.toggleSearch()
                }

                Timer {
                    id: searchCollapseTimer
                    interval: 750
                    onTriggered: expandedDashboardContainer.barSlot.root.dashboardExpanded = false
                }

                PetSearchBar {
                    id: petSearch
                    root: expandedDashboardContainer.barSlot.root
                    isOpen: dashboardAdapter.searchOpen
                    maxContentWidth: Math.max(160, Math.min(260, topHeaderBar.width - systemPet.width - topHeaderRightRow.width - 24))
                    anchors.verticalCenter: parent.verticalCenter
                    onFocusLostOrClosed: {
                        dashboardAdapter.searchOpen = false
                        if (dashboardLoader.item) dashboardLoader.item.forceActiveFocus()
                    }
                    onSearchSubmitted: {
                        // Let the cat celebrate for a moment before the dashboard collapses
                        systemPet.celebrate()
                        searchCollapseTimer.restart()
                    }
                }

                // Battery Pill
                Rectangle {
                    id: batteryPill
                    height: 28
                    readonly property bool shouldShow: !dashboardAdapter.searchOpen && battLoader.item && battLoader.item.shown
                    width: shouldShow ? battLoader.item.implicitWidth : 0
                    opacity: shouldShow ? 1.0 : 0.0
                    radius: 14
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "battery"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                        : (batteryPillMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: expandedDashboardContainer.barSlot.root.dashboardDetail === "battery" ? 1.5 : 0
                    border.color: expandedDashboardContainer.barSlot.root.seal
                    clip: true
                    visible: width > 0.1 || opacity > 0.01
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Loader {
                        id: battLoader
                        anchors.centerIn: parent
                        active: expandedDashboardContainer.barSlot.dashboardEverActivated
                        sourceComponent: BatteryWidget { root: expandedDashboardContainer.barSlot.root }
                    }

                    MouseArea {
                        id: batteryPillMa
                        anchors.fill: parent
                        z: 10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (expandedDashboardContainer.barSlot.root.dashboardDetail === "battery") {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                            } else {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = "battery"
                            }
                        }
                    }
                }

                // DateTime Pill
                Rectangle {
                    id: dateTimePill
                    height: 28
                    readonly property bool displayClockActive: (dashboardLoader.item && !dashboardLoader.item.showMediaPlayer && expandedDashboardContainer.barSlot.root.dashboardDetail === "")
                    readonly property bool shouldShow: !dashboardAdapter.searchOpen && !displayClockActive
                    width: shouldShow ? dateTimeRow.implicitWidth + 20 : 0
                    opacity: shouldShow ? 1.0 : 0.0
                    radius: 14
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                        : (dateTimeMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar" ? 1.5 : 0
                    border.color: expandedDashboardContainer.barSlot.root.seal
                    clip: true
                    visible: width > 0.1 || opacity > 0.01
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: dateTimeRow
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            text: "schedule"
                            color: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar" ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink
                            font.pixelSize: 13
                            opacity: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar" ? 1.0 : 0.75
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: dateTimeTxt
                            text: expandedDashboardContainer.dateShortStr + "  •  " + expandedDashboardContainer.hourStr + ":" + expandedDashboardContainer.minStr + (expandedDashboardContainer.amPmStr !== "" ? " " + expandedDashboardContainer.amPmStr : "")
                            color: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar" ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink
                            opacity: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar" ? 1.0 : 0.85
                            font.family: expandedDashboardContainer.barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar" ? Font.Bold : Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: dateTimeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar") {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                            } else {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = "calendar"
                            }
                        }
                    }
                }
            }

            // Right Side: Screentime/Uptime Pill + Restart Button + Power Off Button
            Row {
                id: topHeaderRightRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Process {
                    id: uptimeProc
                    command: ["bash", "-c", "awk '{print int($1/3600)\"h \"int(($1%3600)/60)\"m\"}' /proc/uptime"]
                    running: expandedDashboardContainer.barSlot.isDashboardActive
                    stdout: StdioCollector {
                        onStreamFinished: {
                            uptimeTxt.text = this.text.trim()
                        }
                    }
                }
                Timer {
                    interval: 60000; repeat: true; running: expandedDashboardContainer.barSlot.isDashboardActive
                    onTriggered: { uptimeProc.running = false; uptimeProc.running = true }
                }

                // Pinned Plugin Icon Buttons (Placed to the left of the Screentime Pill)
                Repeater {
                    model: expandedDashboardContainer.barSlot.root.pinnedPluginsData || []
                    delegate: Rectangle {
                        id: pinnedPlugBtn
                        required property var modelData

                        height: 28
                        width: 28
                        radius: 14
                        anchors.verticalCenter: parent.verticalCenter
                        color: pinnedPlugMa.containsMouse
                            ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.25)
                            : expandedDashboardContainer.barSlot.root.fillIdle
                        border.width: pinnedPlugMa.containsMouse ? 1.5 : 0
                        border.color: expandedDashboardContainer.barSlot.root.seal

                        scale: pinnedPlugMa.pressed ? 0.92 : (pinnedPlugMa.containsMouse ? 1.06 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        IconText {
                            anchors.centerIn: parent
                            text: modelData.icon || "extension"
                            color: pinnedPlugMa.containsMouse ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink
                            font.pixelSize: 15
                        }

                        TooltipMixin {
                            id: pinnedPlugTip
                            root: expandedDashboardContainer.barSlot.root
                            owner: pinnedPlugBtn
                            text: (modelData.name || modelData.id) + " (Right-click to unpin)"
                        }

                        MouseArea {
                            id: pinnedPlugMa
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: pinnedPlugTip.show()
                            onExited: pinnedPlugTip.hide()
                            onClicked: (mouse) => {
                                pinnedPlugTip.hide()
                                if (mouse.button === Qt.RightButton) {
                                    expandedDashboardContainer.barSlot.root.togglePinPlugin(modelData.id)
                                } else {
                                    expandedDashboardContainer.barSlot.root.dashboardExpanded = false
                                    Quickshell.execDetached(["omarchy-shell", "shell", "summon", modelData.id])
                                }
                            }
                        }
                    }
                }

                // Screentime / Uptime Pill
                Rectangle {
                    height: 28
                    width: uptimeRow.implicitWidth + 20
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "screentime"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                        : (uptimeMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: expandedDashboardContainer.barSlot.root.dashboardDetail === "screentime" ? 1.5 : 0
                    border.color: expandedDashboardContainer.barSlot.root.seal
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: uptimeRow
                        anchors.centerIn: parent
                        spacing: 5

                        IconText {
                            text: "timelapse"
                            color: expandedDashboardContainer.barSlot.root.ink
                            font.pixelSize: 13
                            opacity: 0.75
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: uptimeTxt
                            text: "--"
                            color: expandedDashboardContainer.barSlot.root.ink
                            opacity: 0.85
                            font.family: expandedDashboardContainer.barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: uptimeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (expandedDashboardContainer.barSlot.root.dashboardDetail === "screentime") {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                            } else {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = "screentime"
                            }
                        }
                    }
                }

                // Voice Dictation Button (Top Header Bar)
                Rectangle {
                    id: dictationHeaderBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: expandedDashboardContainer.barSlot.root.dictationActive
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.28)
                        : (dictationHeaderMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: expandedDashboardContainer.barSlot.root.dictationActive ? 1.5 : 0
                    border.color: expandedDashboardContainer.barSlot.accent
                    scale: dictationHeaderMa.pressed ? 0.92 : (dictationHeaderMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: expandedDashboardContainer.barSlot.root.dictationState === "transcribing" ? "auto_awesome" : "mic"
                        color: expandedDashboardContainer.barSlot.root.dictationActive ? expandedDashboardContainer.barSlot.accent : expandedDashboardContainer.barSlot.root.ink
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: dictationHeaderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            expandedDashboardContainer.barSlot.root.dashboardExpanded = false
                            expandedDashboardContainer.barSlot.root.toggleDictation()
                        }
                    }
                }

                // Notification Center Button
                Rectangle {
                    id: notifHeaderBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "notifications"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                        : (notifHeaderMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: expandedDashboardContainer.barSlot.root.dashboardDetail === "notifications" ? 1.5 : 0
                    border.color: expandedDashboardContainer.barSlot.root.seal
                    scale: notifHeaderMa.pressed ? 0.92 : (notifHeaderMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: expandedDashboardContainer.barSlot.root.notifSilenced ? "\uE7F6" : (expandedDashboardContainer.barSlot.root.notifCount > 0 ? "notifications_active" : "\uE7F4")
                        color: expandedDashboardContainer.barSlot.root.dashboardDetail === "notifications"
                            ? expandedDashboardContainer.barSlot.root.seal
                            : (expandedDashboardContainer.barSlot.root.notifCount > 0 ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink)
                        font.pixelSize: 15
                    }

                    // Unread badge dot
                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        width: 6
                        height: 6
                        radius: 3
                        color: expandedDashboardContainer.barSlot.root.seal
                        visible: expandedDashboardContainer.barSlot.root.notifCount > 0 && expandedDashboardContainer.barSlot.root.dashboardDetail !== "notifications"
                    }

                    MouseArea {
                        id: notifHeaderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                Quickshell.execDetached(["quickshell", "-p", "/usr/share/omarchy/shell", "ipc", "call", "notifications", "toggleDnd"])
                                expandedDashboardContainer.barSlot.root.notifSilenced = !expandedDashboardContainer.barSlot.root.notifSilenced
                            } else {
                                if (expandedDashboardContainer.barSlot.root.dashboardDetail === "notifications") {
                                    expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                                } else {
                                    expandedDashboardContainer.barSlot.root.dashboardDetail = "notifications"
                                }
                            }
                        }
                    }
                }

                // System / Power Settings Button
                Rectangle {
                    id: systemBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "system"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                        : (systemBtnMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: expandedDashboardContainer.barSlot.root.dashboardDetail === "system" ? 1.5 : 0
                    border.color: expandedDashboardContainer.barSlot.root.seal
                    scale: systemBtnMa.pressed ? 0.92 : (systemBtnMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        color: expandedDashboardContainer.barSlot.root.dashboardDetail === "system" ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: systemBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (expandedDashboardContainer.barSlot.root.dashboardDetail === "system") {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                            } else {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = "system"
                            }
                        }
                    }
                }
            }
        }

        // Expanded Dashboard Content
        Loader {
            id: dashboardLoader
            anchors.top: topHeaderBar.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 28
            height: Math.round(expandedDashboardContainer.barSlot.dashboardExpandedHeight - 32 - 12 - 14 - 14)
            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            active: expandedDashboardContainer.barSlot.dashboardEverActivated
            focus: expandedDashboardContainer.barSlot.isDashboardActive
            source: Qt.resolvedUrl("../panels/homescreen/HomescreenDashboardContent.qml")
            z: 5

            onLoaded: {
                item.root = expandedDashboardContainer.barSlot.root
                item.panel = dashboardAdapter
                item.mprisPanel = expandedDashboardContainer.barSlot.mprisPanel
                if (!expandedDashboardContainer.barSlot.root.dashboardDetail) {
                    item.activeDetailView = ""
                    item.selectCategoryByIndex(0)
                } else {
                    item.activeDetailView = expandedDashboardContainer.barSlot.root.dashboardDetail
                }
                if (expandedDashboardContainer.barSlot.isDashboardActive) item.forceActiveFocus()
            }
        }
    } // end dashboardMainContent
}

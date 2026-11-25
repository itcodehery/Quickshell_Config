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
    readonly property bool isMediaShown: Boolean(dashboardLoader.item && dashboardLoader.item.showMediaPlayer)
    readonly property bool isMediaExpanded: Boolean(dashboardLoader.item && dashboardLoader.item.isMediaExpanded)
    readonly property bool isPomodoroShown: Boolean(dashboardLoader.item && dashboardLoader.item.showPomodoroDock)
    readonly property bool isPomodoroExpanded: Boolean(dashboardLoader.item && dashboardLoader.item.isPomodoroExpanded)

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

    // Display Projection / Mirroring state (via qs-project-ctl)
    readonly property string projectctlPath: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-project-ctl"
    property string projectMode: "extend"
    property string projectLabel: "Extend"
    property string projectIcon: "splitscreen"
    property bool projectActive: false

    function applyProjectPayload(rawText) {
        try {
            var data = JSON.parse(rawText.trim())
            projectMode = data.mode || "extend"
            projectLabel = data.label || "Extend"
            projectIcon = data.icon || "splitscreen"
            projectActive = (data.active === true)
        } catch (e) {}
    }

    Process {
        id: projectStatusProc
        command: [expandedDashboardContainer.projectctlPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: expandedDashboardContainer.applyProjectPayload(this.text)
        }
    }
    Process {
        id: projectCycleProc
        command: [expandedDashboardContainer.projectctlPath, "cycle"]
        stdout: StdioCollector {
            onStreamFinished: expandedDashboardContainer.applyProjectPayload(this.text)
        }
    }
    Process {
        id: projectPrevProc
        command: [expandedDashboardContainer.projectctlPath, "prev"]
        stdout: StdioCollector {
            onStreamFinished: expandedDashboardContainer.applyProjectPayload(this.text)
        }
    }

    Connections {
        target: expandedDashboardContainer.barSlot
        function onIsDashboardActiveChanged() {
            if (expandedDashboardContainer.barSlot.isDashboardActive) {
                projectStatusProc.running = false
                projectStatusProc.running = true
            }
        }
    }
    Component.onCompleted: projectStatusProc.running = true
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

    // ── FLOATING SUB-PAGE MATERIAL 3 EXPRESSIVE NAVIGATION RAIL ──
    Rectangle {
        id: subPageSidebar
        anchors.left: parent.left
        anchors.leftMargin: expandedDashboardContainer.barSlot.isSubPageOpen ? 8 : 0
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: expandedDashboardContainer.barSlot.isSubPageOpen ? 60 : 0
        clip: true
        visible: width > 0.5 || opacity > 0.01
        opacity: expandedDashboardContainer.barSlot.isSubPageOpen ? 1.0 : 0.0
        z: 30

        radius: 28
        border.width: 0
        color: Qt.rgba(expandedDashboardContainer.barSlot.root.paper.r, expandedDashboardContainer.barSlot.root.paper.g, expandedDashboardContainer.barSlot.root.paper.b, expandedDashboardContainer.barSlot.root.isLightMode ? 0.88 : 0.72)

        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        readonly property var subPagesList: [
            { id: "wifi",          name: "Wi-Fi",          icon: "wifi" },
            { id: "bluetooth",     name: "Bluetooth",      icon: "bluetooth" },
            { id: "volume",        name: "Audio",          icon: "volume_up" },
            { id: "battery",       name: "Battery",        icon: "battery_charging_full" },
            { id: "screentime",    name: "Screen Time",    icon: "schedule" },
            { id: "notifications", name: "Notifications",  icon: "notifications" },
            { id: "calendar",      name: "Calendar",       icon: "calendar_month" },
            { id: "notes",         name: "Notes",          icon: "edit_note" },
            { id: "github",        name: "GitHub",         icon: "code" },
            { id: "theme",         name: "Themes",         icon: "palette" },
            { id: "wallpaper",     name: "Wallpapers",     icon: "wallpaper" },
            { id: "plugins",       name: "Plugins",        icon: "extension" },
            { id: "updates",       name: "Updates",        icon: "system_update" }
        ]

        function isSubPageActive(pageId) {
            if (expandedDashboardContainer.barSlot.root.dashboardDetail === pageId) return true
            if (pageId === "updates" && expandedDashboardContainer.barSlot.root.dashboardDetail === "packages") return true
            return false
        }

        // Top: Compact Icon-Only Back to Watch Dashboard Pill
        Rectangle {
            id: sidebarHomeBtn
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: 40
            height: 40
            radius: 20
            color: sidebarHomeMa.containsMouse
                ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                : expandedDashboardContainer.barSlot.root.fillIdle
            Behavior on color { ColorAnimation { duration: 150 } }

            IconText {
                anchors.centerIn: parent
                text: "arrow_back"
                font.pixelSize: 18
                color: sidebarHomeMa.containsMouse ? expandedDashboardContainer.barSlot.root.seal : expandedDashboardContainer.barSlot.root.ink
            }

            SpringPress {}

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

        // Scrollable list of compact icon-only sub-page pills
        Flickable {
            id: sidebarFlick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.top: sidebarHomeBtn.bottom
            anchors.topMargin: 10
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
                spacing: 6
                width: parent.width

                Repeater {
                    model: subPageSidebar.subPagesList
                    delegate: Rectangle {
                        id: subPageBtn
                        required property var modelData
                        required property int index
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 40
                        radius: isSelected ? 20 : 12

                        readonly property bool isSelected: subPageSidebar.isSubPageActive(modelData.id)
                        readonly property color onSealCol: {
                            var luma = expandedDashboardContainer.barSlot.root.seal.r * 0.299 + expandedDashboardContainer.barSlot.root.seal.g * 0.587 + expandedDashboardContainer.barSlot.root.seal.b * 0.114
                            return luma > 0.5 ? "#121212" : "#ffffff"
                        }

                        color: isSelected
                            ? expandedDashboardContainer.barSlot.root.seal
                            : (subPageMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on radius { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        IconText {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: subPageBtn.isSelected
                                ? subPageBtn.onSealCol
                                : (subPageMa.containsMouse ? expandedDashboardContainer.barSlot.root.ink : Qt.rgba(expandedDashboardContainer.barSlot.root.ink.r, expandedDashboardContainer.barSlot.root.ink.g, expandedDashboardContainer.barSlot.root.ink.b, 0.72))
                            font.pixelSize: 19
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        SpringPress {}

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
        anchors.leftMargin: expandedDashboardContainer.barSlot.isSubPageOpen ? 16 : 0

        topLeftRadius: expandedDashboardContainer.barSlot.dashboardTopRadius
        bottomLeftRadius: expandedDashboardContainer.barSlot.dashboardBottomRadius
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
            width: parent.width - 40
            anchors.topMargin: 16
            height: 32
            z: 10

            // Left Side: System Pet + Battery Pill + DateTime Pill
            Row {
                id: leftHeaderRow
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

                PetSearchBar {
                    id: petSearch
                    root: expandedDashboardContainer.barSlot.root
                    isOpen: dashboardAdapter.searchOpen
                    contentHeight: 30
                    anchors.verticalCenter: parent.verticalCenter
                    onFocusLostOrClosed: {
                        dashboardAdapter.searchOpen = false
                        if (dashboardLoader.item) dashboardLoader.item.forceActiveFocus()
                    }
                    onSearchSubmitted: {
                        systemPet.celebrate()
                        searchCollapseTimer.restart()
                    }
                }

                Timer {
                    id: searchCollapseTimer
                    interval: 750
                    onTriggered: expandedDashboardContainer.barSlot.root.dashboardExpanded = false
                }

                // DateTime Pill
                Rectangle {
                    id: dateTimePill
                    height: 28
                    readonly property bool displayClockActive: (dashboardLoader.item && !dashboardLoader.item.showMediaPlayer && expandedDashboardContainer.barSlot.root.dashboardDetail === "")
                    readonly property bool shouldShow: !displayClockActive
                    width: shouldShow ? dateTimeRow.implicitWidth + 20 : 0
                    opacity: shouldShow ? 1.0 : 0.0
                    radius: 14
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "calendar"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.22)
                        : (dateTimeMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: 0
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
                        border.width: 0
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

                // Display Projection / Screen Mirror Pill
                Rectangle {
                    id: projectHeaderPill
                    height: 28
                    width: projectPillRow.implicitWidth + 20
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property color onSealCol: {
                        var s = expandedDashboardContainer.barSlot.root.seal
                        var l = 0.299 * s.r + 0.587 * s.g + 0.114 * s.b
                        return l > 0.55 ? "#121212" : "#ffffff"
                    }
                    color: expandedDashboardContainer.projectActive
                        ? (projectPillMa.containsMouse ? Qt.lighter(expandedDashboardContainer.barSlot.root.seal, 1.1) : expandedDashboardContainer.barSlot.root.seal)
                        : (projectPillMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: 0
                    scale: projectPillMa.pressed ? 0.94 : (projectPillMa.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        id: projectPillRow
                        anchors.centerIn: parent
                        spacing: 5

                        IconText {
                            text: expandedDashboardContainer.projectIcon || "cast"
                            color: expandedDashboardContainer.projectActive ? projectHeaderPill.onSealCol : expandedDashboardContainer.barSlot.root.ink
                            font.pixelSize: 13
                            opacity: expandedDashboardContainer.projectActive ? 1.0 : 0.78
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: expandedDashboardContainer.projectLabel || "Extend"
                            color: expandedDashboardContainer.projectActive ? projectHeaderPill.onSealCol : expandedDashboardContainer.barSlot.root.ink
                            opacity: expandedDashboardContainer.projectActive ? 1.0 : 0.85
                            font.family: expandedDashboardContainer.barSlot.root.barFont
                            font.pixelSize: 11
                            font.weight: expandedDashboardContainer.projectActive ? Font.Bold : Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    TooltipMixin {
                        id: projectPillTip
                        root: expandedDashboardContainer.barSlot.root
                        owner: projectHeaderPill
                        text: "Display: " + expandedDashboardContainer.projectLabel + " (Left-click: next · Right-click: prev)"
                    }

                    MouseArea {
                        id: projectPillMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onEntered: projectPillTip.show()
                        onExited: projectPillTip.hide()
                        onClicked: (mouse) => {
                            projectPillTip.hide()
                            if (mouse.button === Qt.RightButton) {
                                projectPrevProc.running = false
                                projectPrevProc.running = true
                            } else {
                                projectCycleProc.running = false
                                projectCycleProc.running = true
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
                    border.width: 0
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

                // Settings Button (Replaces Voice Dictation Button in Top Header Bar)
                Rectangle {
                    id: settingsHeaderBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: expandedDashboardContainer.barSlot.root.dashboardDetail === "settings"
                        ? Qt.rgba(expandedDashboardContainer.barSlot.root.seal.r, expandedDashboardContainer.barSlot.root.seal.g, expandedDashboardContainer.barSlot.root.seal.b, 0.28)
                        : (settingsHeaderMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle)
                    border.width: 0
                    border.color: expandedDashboardContainer.barSlot.accent
                    scale: settingsHeaderMa.pressed ? 0.90 : (settingsHeaderMa.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "settings"
                        color: expandedDashboardContainer.barSlot.root.dashboardDetail === "settings" ? expandedDashboardContainer.barSlot.accent : expandedDashboardContainer.barSlot.root.ink
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: settingsHeaderMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (expandedDashboardContainer.barSlot.root.dashboardDetail === "settings") {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = ""
                            } else {
                                expandedDashboardContainer.barSlot.root.dashboardDetail = "settings"
                            }
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
                    border.width: 0
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

                // Power Menu Button (closes dashboard and expands the bar power peek)
                Rectangle {
                    id: systemBtn
                    height: 28
                    width: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: systemBtnMa.containsMouse ? expandedDashboardContainer.barSlot.root.fillHover : expandedDashboardContainer.barSlot.root.fillIdle
                    border.width: 0
                    scale: systemBtnMa.pressed ? 0.92 : (systemBtnMa.containsMouse ? 1.06 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    IconText {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        color: expandedDashboardContainer.barSlot.root.ink
                        font.pixelSize: 15
                    }

                    MouseArea {
                        id: systemBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            expandedDashboardContainer.barSlot.root.dashboardExpanded = false
                            expandedDashboardContainer.barSlot.root.powerPeekActive = true
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
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 0
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 48
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

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: stSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    property var stObj: ({
        today_key: "",
        today_date_str: "Today",
        today_total: 0,
        today_formatted: "0m",
        session_seconds: 0,
        session_formatted: "0m",
        yesterday_formatted: "0m",
        trend: "-",
        weeks: [],
        allHistory: [],
        rollingWeek: [],
        topApps: [],
        activeApp: "",
        activeTitle: ""
    })

    property int selectedWeekIndex: 0
    property int currentTab: 0 // 0: Week (Image 2 style), 1: All History, 2: Apps
    property int previousTab: 0

    readonly property var currentWeekData: {
        if (stObj && stObj.weeks && stObj.weeks.length > selectedWeekIndex && selectedWeekIndex >= 0) {
            return stObj.weeks[selectedWeekIndex]
        }
        return null
    }

    readonly property int totalWeeks: (stObj && stObj.weeks) ? stObj.weeks.length : 1

    property var selectedDay: null

    ListModel { id: appModel }
    ListModel { id: weekDaysModel }
    ListModel { id: weekListModel }
    ListModel { id: historyModel }

    function getAppIcon(appName) {
        if (!appName) return "apps"
        var lower = appName.toLowerCase()
        if (lower.indexOf("firefox") >= 0 || lower.indexOf("chrome") >= 0 || lower.indexOf("browser") >= 0 || lower.indexOf("zen") >= 0) return "travel_explore"
        if (lower.indexOf("code") >= 0 || lower.indexOf("sublime") >= 0 || lower.indexOf("helix") >= 0) return "code"
        if (lower.indexOf("term") >= 0 || lower.indexOf("kitty") >= 0 || lower.indexOf("alacritty") >= 0) return "terminal"
        if (lower.indexOf("discord") >= 0 || lower.indexOf("slack") >= 0 || lower.indexOf("telegram") >= 0 || lower.indexOf("whatsapp") >= 0) return "forum"
        if (lower.indexOf("music") >= 0 || lower.indexOf("spotify") >= 0) return "music_note"
        if (lower.indexOf("video") >= 0 || lower.indexOf("mpv") >= 0 || lower.indexOf("vlc") >= 0) return "movie"
        if (lower.indexOf("file") >= 0 || lower.indexOf("thunar") >= 0 || lower.indexOf("nautilus") >= 0) return "folder"
        if (lower.indexOf("game") >= 0 || lower.indexOf("steam") >= 0 || lower.indexOf("minecraft") >= 0) return "sports_esports"
        return "apps"
    }

    function findDayData(dateKey) {
        if (!stObj || !dateKey) return null
        if (stObj.allHistory) {
            for (var i = 0; i < stObj.allHistory.length; i++) {
                if (stObj.allHistory[i].dateKey === dateKey) {
                    return stObj.allHistory[i]
                }
            }
        }
        if (stObj.weeks) {
            for (var w = 0; w < stObj.weeks.length; w++) {
                var days = stObj.weeks[w].days || []
                for (var d = 0; d < days.length; d++) {
                    if (days[d].dateKey === dateKey) {
                        return days[d]
                    }
                }
            }
        }
        return null
    }

    function selectDay(dayData, switchTab) {
        if (!dayData) return
        var k = dayData.dateKey || ""
        if (k) {
            selectDayByKey(k, switchTab)
        } else {
            stSection.selectedDay = dayData
            loadAppsForDay(dayData)
            if (switchTab) {
                if (stSection.currentTab !== 2) stSection.previousTab = stSection.currentTab
                stSection.currentTab = 2
            }
        }
    }

    function selectDayByKey(dateKey, switchTab) {
        if (!dateKey) return
        var dayObj = findDayData(dateKey)
        if (!dayObj) return
        stSection.selectedDay = dayObj
        loadAppsForDay(dayObj)
        if (switchTab) {
            if (stSection.currentTab !== 2) stSection.previousTab = stSection.currentTab
            stSection.currentTab = 2
        }
    }

    function loadAppsForDay(dayData) {
        appModel.clear()
        if (!dayData) return

        var resolved = dayData
        if (dayData.dateKey) {
            var raw = findDayData(dayData.dateKey)
            if (raw) resolved = raw
        }

        var apps = resolved.apps
        if (!apps) return

        if (Array.isArray(apps) || apps.length !== undefined) {
            for (var i = 0; i < apps.length; i++) {
                var item = apps[i]
                if (item) {
                    appModel.append({
                        name: item.name || "",
                        seconds: item.seconds || 0,
                        formatted: item.formatted || "0m",
                        percent: item.percent || 0,
                        percent_str: item.percent_str || "0%"
                    })
                }
            }
        } else if (apps.count !== undefined) {
            for (var j = 0; j < apps.count; j++) {
                var gItem = apps.get(j)
                if (gItem) {
                    appModel.append({
                        name: gItem.name || "",
                        seconds: gItem.seconds || 0,
                        formatted: gItem.formatted || "0m",
                        percent: gItem.percent || 0,
                        percent_str: gItem.percent_str || "0%"
                    })
                }
            }
        }
    }

    function updateWeekData() {
        weekDaysModel.clear()
        weekListModel.clear()
        if (!currentWeekData || !currentWeekData.days) return

        var days = currentWeekData.days
        for (var i = 0; i < days.length; i++) {
            weekDaysModel.append(days[i])
        }

        // For breakdown list below chart, show elapsed days newest-first
        for (var j = days.length - 1; j >= 0; j--) {
            if (!days[j].isFuture || days[j].hasData) {
                weekListModel.append(days[j])
            }
        }
    }

    function updateHistoryData() {
        historyModel.clear()
        if (!stObj || !stObj.allHistory) return
        var hist = stObj.allHistory
        for (var i = 0; i < hist.length; i++) {
            historyModel.append(hist[i])
        }
    }

    onCurrentWeekDataChanged: {
        updateWeekData()
    }

    function nextSubOption() {
        if (currentTab < 2) {
            currentTab++
            return true
        }
        return false
    }

    function prevSubOption() {
        if (currentTab > 0) {
            currentTab--
            return true
        }
        return false
    }

    Process {
        id: stStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/screentime_info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(this.text.trim())
                    stSection.stObj = d

                    stSection.updateWeekData()
                    stSection.updateHistoryData()

                    // Default selected day to today if not set
                    if (!stSection.selectedDay && d.allHistory && d.allHistory.length > 0) {
                        stSection.selectedDay = d.allHistory[0]
                        stSection.loadAppsForDay(stSection.selectedDay)
                    } else if (stSection.selectedDay && stSection.selectedDay.dateKey) {
                        var currentKey = stSection.selectedDay.dateKey
                        var fresh = stSection.findDayData(currentKey)
                        if (fresh) {
                            stSection.selectedDay = fresh
                            if (stSection.currentTab === 2) {
                                stSection.loadAppsForDay(fresh)
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: stPollTimer
        interval: 3000
        repeat: true
        running: stSection.visible
        triggeredOnStart: true
        onTriggered: {
            if (!stStatusProc.running) stStatusProc.running = true
        }
    }

    onVisibleChanged: {
        if (visible && !stStatusProc.running) stStatusProc.running = true
    }

    // ================= MAIN CONTENT VIEWS =================
    Item {
        id: viewStackContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomTabRow.top
        anchors.bottomMargin: 8
        clip: true

        // ---------------- TAB 0: WEEK VIEW (Image 2 style) ----------------
        Item {
            id: weekViewPage
            anchors.fill: parent
            visible: stSection.currentTab === 0

            Column {
                anchors.fill: parent
                spacing: 12

                // Top Period Header & Navigation (< >)
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: currentWeekData ? currentWeekData.weekLabel : "This week"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    // < > Navigation Controls
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        // Previous Week (<)
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: prevWkMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            opacity: stSection.selectedWeekIndex < stSection.totalWeeks - 1 ? 1.0 : 0.25

                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                color: root.ink
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: prevWkMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: stSection.selectedWeekIndex < stSection.totalWeeks - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (stSection.selectedWeekIndex < stSection.totalWeeks - 1) {
                                        stSection.selectedWeekIndex++
                                    }
                                }
                            }
                        }

                        // Next Week (>)
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: nextWkMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            opacity: stSection.selectedWeekIndex > 0 ? 1.0 : 0.25

                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                color: root.ink
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: nextWkMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: stSection.selectedWeekIndex > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (stSection.selectedWeekIndex > 0) {
                                        stSection.selectedWeekIndex--
                                    }
                                }
                            }
                        }
                    }
                }

                // Big Average Display (Image 2: "5,586 steps per day (avg)")
                Column {
                    id: bigStatCol
                    width: parent.width
                    spacing: 2

                    Row {
                        spacing: 6

                        Text {
                            id: bigStatText
                            text: currentWeekData ? currentWeekData.avgPerDayFormatted : (stSection.stObj.today_formatted || "0m")
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "per day (avg)"
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Normal
                            anchors.bottom: bigStatText.bottom
                            anchors.bottomMargin: 4
                        }
                    }

                    Text {
                        text: currentWeekData ? currentWeekData.goalSummary : ""
                        color: root.ink
                        opacity: 0.5
                        font.family: root.barFont
                        font.pixelSize: 11
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }

                // Bar Chart (Image 2: Capsule Bars with Emerald Peak & Circular Badge)
                Item {
                    id: chartContainer
                    width: parent.width
                    height: 126

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 10

                        Repeater {
                            model: weekDaysModel
                            delegate: Item {
                                id: dayBarCol
                                width: 34
                                height: parent.height

                                readonly property bool isSelected: stSection.selectedDay && stSection.selectedDay.dateKey === model.dateKey

                                MouseArea {
                                    id: barMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        stSection.selectDay(model, false)
                                    }
                                    onDoubleClicked: {
                                        stSection.selectDay(model, true)
                                    }
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 4

                                    // Capsule Pill Bar Area
                                    Item {
                                        id: barTrackArea
                                        width: parent.width
                                        height: parent.height - 24

                                        // Capsule Pill Bar
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: dayBarCol.isSelected ? 34 : 32
                                            height: Math.max(12, Math.round((barTrackArea.height - 4) * (model.ratio || 0.05)))
                                            radius: width / 2 // fully rounded capsule / pill

                                            color: {
                                                if (!model.hasData) return Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                                if (model.isPeak || model.isHighlight) return (root.color02 ? root.color02 : root.seal)
                                                return root.seal
                                            }

                                            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on width { NumberAnimation { duration: 120 } }

                                            // Circular Emblem Badge on top of peak bar (as in Image 2)
                                            Rectangle {
                                                visible: (model.isPeak || model.isHighlight) && model.hasData && parent.height >= 26
                                                anchors.top: parent.top
                                                anchors.topMargin: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 18
                                                height: 18
                                                radius: 9
                                                color: root.paper

                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "verified"
                                                    color: (root.color02 ? root.color02 : root.seal)
                                                    font.pixelSize: 11
                                                }
                                            }

                                            // Selection highlight ring
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: -2
                                                radius: parent.radius + 2
                                                color: "transparent"
                                                border.width: 1.5
                                                border.color: root.seal
                                                visible: dayBarCol.isSelected
                                            }
                                        }
                                    }

                                    // Day of Week Letter (M, T, W, T, F, S, S)
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: model.dayLetter || "D"
                                        color: (model.isPeak || model.isHighlight) ? (root.color02 ? root.color02 : root.seal) : (model.isToday ? root.seal : root.ink)
                                        opacity: model.hasData ? 1.0 : 0.35
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: (model.isToday || model.isPeak) ? Font.Bold : Font.Normal
                                    }

                                    // Indicator Dot below letter
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: model.hasData
                                            ? ((model.isPeak || model.isHighlight) ? (root.color02 ? root.color02 : root.seal) : root.seal)
                                            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15)
                                    }
                                }
                            }
                        }
                    }
                }

                // Thin Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                // Day-by-Day Breakdown List (Image 2: Today, Yesterday, Days)
                ListView {
                    id: weekDaysListView
                    width: parent.width
                    height: parent.height - 28 - bigStatCol.height - chartContainer.height - 1 - (12 * 4)
                    clip: true
                    spacing: 6
                    model: weekListModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: dayRowRect
                        width: weekDaysListView.width
                        height: 38
                        radius: 10
                        color: dayRowMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: (stSection.selectedDay && stSection.selectedDay.dateKey === model.dateKey)
                            ? root.seal
                            : (dayRowMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04))

                        MouseArea {
                            id: dayRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                stSection.selectDay(model, true)
                            }
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            // Day label (e.g. Today, Yesterday, Wed, Oct 14)
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: model.dateFormatted || model.dateShort
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 12
                                font.weight: model.isToday ? Font.Bold : Font.DemiBold
                            }

                            // Right Side: Green Star Emblem + Screentime Value + Chevron
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                // Star Badge (for peak day, matching Image 2)
                                Rectangle {
                                    visible: model.isPeak || model.isHighlight
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(root.color02.r, root.color02.g, root.color02.b, 0.18)

                                    IconText {
                                        anchors.centerIn: parent
                                        text: "star"
                                        color: (root.color02 ? root.color02 : root.seal)
                                        font.pixelSize: 12
                                    }
                                }

                                // Formatted Duration
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.formatted || "0m"
                                    color: (model.isPeak || model.isHighlight) ? (root.color02 ? root.color02 : root.seal) : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "chevron_right"
                                    color: root.ink
                                    opacity: 0.35
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------- TAB 1: ALL HISTORY VIEW ----------------
        Item {
            id: historyViewPage
            anchors.fill: parent
            visible: stSection.currentTab === 1

            Column {
                anchors.fill: parent
                spacing: 8

                // Header Row
                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ALL RECORDED HISTORY (" + historyModel.count + " days)"
                        color: root.ink
                        opacity: 0.6
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Tap to inspect apps"
                        color: root.ink
                        opacity: 0.4
                        font.family: root.barFont
                        font.pixelSize: 10
                    }
                }

                // Full History Scrollable List
                ListView {
                    id: histListView
                    width: parent.width
                    height: parent.height - 32
                    clip: true
                    spacing: 6
                    model: historyModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: histItemRect
                        width: histListView.width
                        height: 52
                        radius: 12
                        color: histItemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: (stSection.selectedDay && stSection.selectedDay.dateKey === model.dateKey)
                            ? root.seal
                            : (histItemMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04))

                        MouseArea {
                            id: histItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                stSection.selectDay(model, true)
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 9
                            spacing: 4

                            // Top row: Date + Duration
                            Item {
                                width: parent.width
                                height: 16

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.dateFormatted || model.dateKey
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 12
                                    font.weight: model.isToday ? Font.Bold : Font.DemiBold
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: model.formatted || "0m"
                                    color: root.seal
                                    font.family: root.barFont
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                }
                            }

                            // Relative Progress Bar
                            Rectangle {
                                width: parent.width
                                height: 3
                                radius: 1.5
                                color: Qt.rgba(1, 1, 1, 0.08)

                                Rectangle {
                                    width: Math.max(4, parent.width * Math.min(1.0, (model.ratio || 0.05)))
                                    height: parent.height
                                    radius: 1.5
                                    color: model.isToday ? root.seal : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.70)
                                }
                            }

                            // Bottom row: Top app + Arrow
                            Item {
                                width: parent.width
                                height: 13

                                Row {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4

                                    IconText {
                                        text: stSection.getAppIcon(model.topAppName)
                                        color: root.ink
                                        opacity: 0.5
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Top: " + (model.topAppName || "None") + " (" + (model.topAppFormatted || "0m") + ")"
                                        color: root.ink
                                        opacity: 0.6
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                IconText {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "chevron_right"
                                    color: root.ink
                                    opacity: 0.4
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------------- TAB 2: APPS USAGE VIEW ----------------
        Item {
            id: appsViewPage
            anchors.fill: parent
            visible: stSection.currentTab === 2

            Column {
                anchors.fill: parent
                spacing: 8

                // Header with Back button + Day title + count
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        // Back Button
                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: appBackMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.06)

                            IconText {
                                anchors.centerIn: parent
                                text: "arrow_back"
                                color: root.ink
                                font.pixelSize: 14
                            }

                            MouseArea {
                                id: appBackMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: stSection.currentTab = (stSection.previousTab !== undefined ? stSection.previousTab : 0)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (stSection.selectedDay ? stSection.selectedDay.dateFormatted : "Today") + " Usage"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: appModel.count + " apps"
                        color: root.ink
                        opacity: 0.5
                        font.family: root.barFont
                        font.pixelSize: 11
                    }
                }

                // Empty state
                Item {
                    visible: appModel.count === 0
                    width: parent.width
                    height: parent.height - 36

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        IconText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "hourglass_disabled"
                            color: root.ink
                            opacity: 0.3
                            font.pixelSize: 32
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "No application usage logged for this day"
                            color: root.ink
                            opacity: 0.4
                            font.family: root.barFont
                            font.pixelSize: 12
                        }
                    }
                }

                // App List
                ListView {
                    id: stAppListView
                    visible: appModel.count > 0
                    width: parent.width
                    height: parent.height - 36
                    clip: true
                    spacing: 6
                    model: appModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: stAppListView.width
                        height: 44
                        radius: 12
                        color: stItemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: stItemMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04)

                        MouseArea {
                            id: stItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            // App Icon
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: stSection.getAppIcon(model.app || model.name)
                                    color: root.seal
                                    font.pixelSize: 15
                                }
                            }

                            // Name & Progress Bar
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 - 110 - 20
                                spacing: 3

                                Text {
                                    text: model.displayName || model.name || model.app || "App"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                // Mini Usage Bar
                                Rectangle {
                                    width: parent.width
                                    height: 3
                                    radius: 1.5
                                    color: Qt.rgba(1, 1, 1, 0.08)

                                    Rectangle {
                                        width: parent.width * Math.max(0.02, Math.min(1.0, (model.percent || 0) / 100))
                                        height: parent.height
                                        radius: 1.5
                                        color: root.seal
                                    }
                                }
                            }

                            // Badges: Duration & Percentage
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                // Duration badge
                                Rectangle {
                                    width: 58
                                    height: 22
                                    radius: 6
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.formatted || "0m"
                                        color: root.seal
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }
                                }

                                // Percentage badge
                                Rectangle {
                                    width: 38
                                    height: 22
                                    radius: 6
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.percent_str || (model.percent + "%")
                                        color: root.ink
                                        opacity: 0.8
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ================= BOTTOM SEGMENTED SWITCHER (Image 2 style) =================
    Rectangle {
        id: bottomTabRow
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 34
        radius: 17
        color: root.fillIdle
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Row {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 4

            // Tab 0: Week View
            Rectangle {
                width: (parent.width - 8) / 3
                height: parent.height
                radius: 14
                color: stSection.currentTab === 0 ? root.seal : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    IconText {
                        text: "bar_chart"
                        color: stSection.currentTab === 0 ? root.paper : root.ink
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Week"
                        color: stSection.currentTab === 0 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: stSection.currentTab === 0 ? Font.Bold : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stSection.currentTab = 0
                }
            }

            // Tab 1: All History View
            Rectangle {
                width: (parent.width - 8) / 3
                height: parent.height
                radius: 14
                color: stSection.currentTab === 1 ? root.seal : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    IconText {
                        text: "history"
                        color: stSection.currentTab === 1 ? root.paper : root.ink
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "All History"
                        color: stSection.currentTab === 1 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: stSection.currentTab === 1 ? Font.Bold : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stSection.currentTab = 1
                }
            }

            // Tab 2: Apps View
            Rectangle {
                width: (parent.width - 8) / 3
                height: parent.height
                radius: 14
                color: stSection.currentTab === 2 ? root.seal : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    IconText {
                        text: "apps"
                        color: stSection.currentTab === 2 ? root.paper : root.ink
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "Apps"
                        color: stSection.currentTab === 2 ? root.paper : root.ink
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: stSection.currentTab === 2 ? Font.Bold : Font.Normal
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!stSection.selectedDay && stObj && stObj.allHistory && stObj.allHistory.length > 0) {
                            stSection.selectedDay = stObj.allHistory[0]
                        }
                        if (stSection.selectedDay) {
                            stSection.loadAppsForDay(stSection.selectedDay)
                        }
                        if (stSection.currentTab !== 2) stSection.previousTab = stSection.currentTab
                        stSection.currentTab = 2
                    }
                }
            }
        }
    }
}

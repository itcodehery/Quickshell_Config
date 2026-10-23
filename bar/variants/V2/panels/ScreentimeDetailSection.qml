import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

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

    readonly property var currentWeekData: {
        if (stObj && stObj.weeks && stObj.weeks.length > selectedWeekIndex && selectedWeekIndex >= 0) {
            return stObj.weeks[selectedWeekIndex]
        }
        return null
    }

    readonly property int totalWeeks: (stObj && stObj.weeks) ? stObj.weeks.length : 1

    property var selectedDay: null

    // The selected day, if it belongs to the week being viewed (null otherwise)
    readonly property var todayDay: {
        if (!currentWeekData || !currentWeekData.days || !selectedDay) return null
        for (var i = 0; i < currentWeekData.days.length; i++)
            if (currentWeekData.days[i].dateKey === selectedDay.dateKey) return currentWeekData.days[i]
        return null
    }

    ListModel { id: appModel }
    ListModel { id: weekDaysModel }
    ListModel { id: weekListModel }

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

    function selectDay(dayData) {
        if (!dayData) return
        var k = dayData.dateKey || ""
        if (k) {
            selectDayByKey(k)
        } else {
            stSection.selectedDay = dayData
            loadAppsForDay(dayData)
        }
    }

    function selectDayByKey(dateKey) {
        if (!dateKey) return
        var dayObj = findDayData(dateKey)
        if (!dayObj) return
        stSection.selectedDay = dayObj
        loadAppsForDay(dayObj)
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

    onCurrentWeekDataChanged: {
        updateWeekData()
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

                    // Default selected day to today if not set
                    if (!stSection.selectedDay && d.allHistory && d.allHistory.length > 0) {
                        stSection.selectedDay = d.allHistory[0]
                        stSection.loadAppsForDay(stSection.selectedDay)
                    } else if (stSection.selectedDay && stSection.selectedDay.dateKey) {
                        var currentKey = stSection.selectedDay.dateKey
                        var fresh = stSection.findDayData(currentKey)
                        if (fresh) {
                            stSection.selectedDay = fresh
                            stSection.loadAppsForDay(fresh)
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

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Seamless, matches Calendar widget) ──────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: WEEKLY CHART & DAY SELECTOR ─────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Top Bar
            Item {
                id: leftTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 28

                // Week Navigator (< Week Label >)
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // Previous Week (<)
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: prevWkMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        opacity: stSection.selectedWeekIndex < stSection.totalWeeks - 1 ? 1.0 : 0.25

                        IconText {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        SpringPress {}
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

                    // Week Label Badge
                    Rectangle {
                        height: 24
                        radius: 12
                        width: weekLabelText.implicitWidth + 16
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Text {
                            id: weekLabelText
                            anchors.centerIn: parent
                            text: currentWeekData ? currentWeekData.weekLabel : "This week"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // Next Week (>)
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: nextWkMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        opacity: stSection.selectedWeekIndex > 0 ? 1.0 : 0.25

                        IconText {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        SpringPress {}
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

                // Top Right: Jump to Today (if navigated back) & Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // "This Week" reset button
                    Rectangle {
                        visible: stSection.selectedWeekIndex > 0
                        height: 24
                        radius: 12
                        width: resetWkText.implicitWidth + 14
                        color: resetWkMa.containsMouse ? root.fillHover : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                        border.width: 1
                        border.color: root.seal

                        Text {
                            id: resetWkText
                            anchors.centerIn: parent
                            text: "Current"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.seal
                        }

                        SpringPress {}
                        MouseArea {
                            id: resetWkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: stSection.selectedWeekIndex = 0
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: closeLeftMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        SpringPress {}
                        MouseArea {
                            id: closeLeftMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: stSection.closeRequested()
                        }
                    }
                }
            }

            // Left Column Body Content
            Column {
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                spacing: 8

                // 1. Overview Stat Row (Daily Avg + Total)
                Item {
                    width: parent.width
                    height: 38

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Row {
                            spacing: 6
                            Text {
                                text: stSection.todayDay ? (stSection.todayDay.formatted || "0m")
                                    : (currentWeekData ? currentWeekData.avgPerDayFormatted : (stSection.stObj.today_formatted || "0m"))
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: stSection.todayDay
                                    ? (stSection.todayDay.isToday ? "today" : (stSection.todayDay.dateFormatted || ""))
                                    : "per day avg"
                                color: root.ink
                                opacity: 0.55
                                font.family: root.barFont
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: !currentWeekData ? ""
                                : (stSection.todayDay
                                    ? (currentWeekData.avgPerDayFormatted + " per day avg  \u2022  " + currentWeekData.totalFormatted + " this week")
                                    : (currentWeekData.totalFormatted + " total this week"))
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                // 2. Weekly Capsule Bar Chart
                Item {
                    id: chartContainer
                    width: parent.width
                    height: 110

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 8

                        Repeater {
                            model: weekDaysModel
                            delegate: Item {
                                id: dayBarCol
                                width: 34
                                height: parent.height

                                readonly property bool isSelected: stSection.selectedDay && stSection.selectedDay.dateKey === model.dateKey

                                SpringPress {}
                                MouseArea {
                                    id: barMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: stSection.selectDay(model)
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 3

                                    // Capsule Bar Area
                                    Item {
                                        id: barTrackArea
                                        width: parent.width
                                        height: parent.height - 24

                                        // Capsule Bar
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: dayBarCol.isSelected ? 32 : 28
                                            height: Math.max(10, Math.round((barTrackArea.height - 4) * (model.ratio || 0.05)))
                                            radius: width / 2

                                            color: {
                                                if (!model.hasData) return Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                                                if (dayBarCol.isSelected) return root.seal
                                                if (model.isPeak || model.isHighlight) return (root.color02 ? root.color02 : root.seal)
                                                return Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.65)
                                            }

                                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on width { NumberAnimation { duration: 100 } }

                                            // Peak Emblem Badge
                                            Rectangle {
                                                visible: (model.isPeak || model.isHighlight) && model.hasData && parent.height >= 26
                                                anchors.top: parent.top
                                                anchors.topMargin: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 16
                                                height: 16
                                                radius: 8
                                                color: root.paper

                                                IconText {
                                                    anchors.centerIn: parent
                                                    text: "verified"
                                                    color: (root.color02 ? root.color02 : root.seal)
                                                    font.pixelSize: 10
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

                                    // Day Letter (M, T, W, T, F, S, S)
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: model.dayLetter || "D"
                                        color: dayBarCol.isSelected ? root.seal : ((model.isToday) ? root.seal : root.ink)
                                        opacity: model.hasData ? 1.0 : 0.35
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: (model.isToday || dayBarCol.isSelected) ? Font.Bold : Font.Normal
                                    }

                                    // Indicator Dot below letter
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: dayBarCol.isSelected 
                                            ? root.seal 
                                            : (model.hasData ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.15))
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
                    color: Qt.rgba(1, 1, 1, 0.05)
                }

                // 3. Week Days Quick Breakdown List
                ListView {
                    id: weekDaysListView
                    width: parent.width
                    height: parent.height - 38 - chartContainer.height - 1 - 24
                    clip: true
                    spacing: 4
                    model: weekListModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: dayRowRect
                        width: weekDaysListView.width
                        height: 34
                        radius: 10

                        readonly property bool isCurrentDaySelected: stSection.selectedDay && stSection.selectedDay.dateKey === model.dateKey

                        color: isCurrentDaySelected 
                            ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.18) 
                            : (dayRowMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03))
                        border.width: 1
                        border.color: isCurrentDaySelected 
                            ? root.seal 
                            : (dayRowMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04))

                        SpringPress {}
                        MouseArea {
                            id: dayRowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: stSection.selectDay(model)
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Day badge pill
                            Rectangle {
                                width: 34; height: 20; radius: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: isCurrentDaySelected ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: model.dayLabel || "Day"
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: isCurrentDaySelected ? root.paper : root.ink
                                }
                            }

                            // Day title & top app
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 34 - rightTimeCol.width - 24
                                spacing: 1
                                clip: true

                                Text {
                                    text: model.dateFormatted || model.dateKey || ""
                                    color: isCurrentDaySelected ? root.seal : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: isCurrentDaySelected ? Font.Bold : Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    visible: model.topAppName !== undefined && model.topAppName !== ""
                                    text: "Top: " + (model.topAppName || "")
                                    color: root.ink
                                    opacity: 0.45
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            // Total Time Right
                            Row {
                                id: rightTimeCol
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: model.formatted || "0m"
                                    color: isCurrentDaySelected ? root.seal : root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                IconText {
                                    text: "chevron_right"
                                    font.pixelSize: 12
                                    color: isCurrentDaySelected ? root.seal : root.ink
                                    opacity: 0.4
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: SELECTED DAY APPS USAGE BREAKDOWN ──────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: columnsRow.width - leftColContainer.width - columnsRow.spacing
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // Top Bar
            Item {
                id: rightTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 28

                // Top Left: Selected Day title & Day Total pill
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        text: "schedule"
                        font.pixelSize: 14
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: (stSection.selectedDay ? (stSection.selectedDay.dateFormatted || "Today") : "Today")
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Total day time pill
                    Rectangle {
                        height: 22
                        radius: 11
                        width: dayTotalText.implicitWidth + 14
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.2)
                        border.width: 1
                        border.color: root.seal
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: dayTotalText
                            anchors.centerIn: parent
                            text: stSection.selectedDay ? (stSection.selectedDay.formatted || "0m") : "0m"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: root.seal
                        }
                    }
                }

                // Top Right: Apps count badge & Close Button
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        height: 24
                        radius: 12
                        width: appCountText.implicitWidth + 14
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Text {
                            id: appCountText
                            anchors.centerIn: parent
                            text: appModel.count + " apps"
                            font.family: root.barFont
                            font.pixelSize: 10
                            color: root.ink
                            opacity: 0.6
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: closeRightMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            font.pixelSize: 14
                            color: root.ink
                        }

                        SpringPress {}
                        MouseArea {
                            id: closeRightMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: stSection.closeRequested()
                        }
                    }
                }
            }

            // Apps List Content Area
            Item {
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                clip: true

                // Empty state
                Column {
                    anchors.centerIn: parent
                    visible: appModel.count === 0
                    spacing: 6

                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "hourglass_disabled"
                        font.pixelSize: 32
                        color: root.ink
                        opacity: 0.3
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No application usage logged for this day"
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: root.ink
                        opacity: 0.4
                    }
                }

                // Apps ListView
                ListView {
                    id: stAppListView
                    anchors.fill: parent
                    clip: true
                    spacing: 5
                    boundsBehavior: Flickable.StopAtBounds
                    model: appModel

                    delegate: Rectangle {
                        id: appItemRect
                        width: stAppListView.width
                        height: 42
                        radius: 10
                        color: appItemMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: appItemMa.containsMouse ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(1, 1, 1, 0.04)

                        MouseArea {
                            id: appItemMa
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // App Icon box
                            Rectangle {
                                width: 28; height: 28; radius: 8
                                color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: stSection.getAppIcon(model.name)
                                    color: root.seal
                                    font.pixelSize: 14
                                }
                            }

                            // App Name & Progress Bar
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 28 - rightAppStats.width - 20
                                spacing: 3
                                clip: true

                                Text {
                                    text: model.name || "App"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                // Mini Usage Bar
                                Rectangle {
                                    width: parent.width
                                    height: 3
                                    radius: 1.5
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                    Rectangle {
                                        width: Math.max(2, parent.width * Math.max(0.01, Math.min(1.0, (model.percent || 0) / 100)))
                                        height: parent.height
                                        radius: 1.5
                                        color: root.seal
                                    }
                                }
                            }

                            // Right Stats: Duration & Percent Pill
                            Row {
                                id: rightAppStats
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Text {
                                    text: model.formatted || "0m"
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    height: 18
                                    radius: 9
                                    width: pctText.implicitWidth + 10
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        id: pctText
                                        anchors.centerIn: parent
                                        text: model.percent_str || (model.percent + "%")
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: root.seal
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

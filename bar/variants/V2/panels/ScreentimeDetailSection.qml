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
        rollingWeek: [],
        topApps: [],
        activeApp: "",
        activeTitle: ""
    })

    property var rawDays: []
    property int selectedDayIndex: -1

    readonly property var selectedDayData: (rawDays && rawDays.length > 0 && selectedDayIndex >= 0 && selectedDayIndex < rawDays.length)
        ? rawDays[selectedDayIndex]
        : null

    ListModel { id: appModel }
    ListModel { id: weekModel }

    function getAppIcon(appName) {
        if (!appName) return "apps"
        var lower = appName.toLowerCase()
        if (lower.indexOf("firefox") >= 0 || lower.indexOf("chrome") >= 0 || lower.indexOf("browser") >= 0 || lower.indexOf("zen") >= 0) return "travel_explore"
        if (lower.indexOf("code") >= 0 || lower.indexOf("sublime") >= 0) return "code"
        if (lower.indexOf("term") >= 0 || lower.indexOf("kitty") >= 0 || lower.indexOf("alacritty") >= 0) return "terminal"
        if (lower.indexOf("discord") >= 0 || lower.indexOf("slack") >= 0 || lower.indexOf("telegram") >= 0) return "forum"
        if (lower.indexOf("music") >= 0 || lower.indexOf("spotify") >= 0) return "music_note"
        if (lower.indexOf("video") >= 0 || lower.indexOf("mpv") >= 0 || lower.indexOf("vlc") >= 0) return "movie"
        if (lower.indexOf("file") >= 0 || lower.indexOf("thunar") >= 0 || lower.indexOf("nautilus") >= 0) return "folder"
        if (lower.indexOf("game") >= 0 || lower.indexOf("steam") >= 0) return "sports_esports"
        return "apps"
    }

    function selectDay(idx) {
        if (!rawDays || rawDays.length === 0) return
        if (idx < 0) idx = 0
        if (idx >= rawDays.length) idx = rawDays.length - 1
        stSection.selectedDayIndex = idx
        loadSelectedDayApps()
    }

    function nextSubOption() {
        if (rawDays && rawDays.length > 0 && selectedDayIndex < rawDays.length - 1) {
            selectDay(selectedDayIndex + 1)
            return true
        }
        return false
    }

    function prevSubOption() {
        if (selectedDayIndex > 0) {
            selectDay(selectedDayIndex - 1)
            return true
        }
        return false
    }

    function loadSelectedDayApps() {
        appModel.clear()
        if (!rawDays || rawDays.length === 0) return
        let idx = selectedDayIndex
        if (idx < 0 || idx >= rawDays.length) idx = rawDays.length - 1
        let day = rawDays[idx]
        if (!day) return
        let apps = day.apps || []
        for (let i = 0; i < apps.length; i++) {
            appModel.append(apps[i])
        }
    }

    Process {
        id: stStatusProc
        command: ["python3", "/home/hery/.config/quickshell/bar/scripts/screentime_info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim())
                    stSection.stObj = d

                    let wk = d.rollingWeek || []
                    stSection.rawDays = wk

                    weekModel.clear()
                    for (let i = 0; i < wk.length; i++) {
                        weekModel.append(wk[i])
                    }

                    // Default to today if not selected or out of range
                    if (stSection.selectedDayIndex < 0 || stSection.selectedDayIndex >= wk.length) {
                        stSection.selectedDayIndex = wk.length > 0 ? (wk.length - 1) : 0
                    }

                    stSection.loadSelectedDayApps()
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

    Column {
        anchors.fill: parent
        spacing: 10

        // ================= HEADER BAR (outside any container) =================
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: root.seal
                    anchors.verticalCenter: parent.verticalCenter

                    IconText {
                        anchors.centerIn: parent
                        text: "hourglass_empty"
                        color: root.paper
                        font.pixelSize: 18
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        text: "SCREEN TIME"
                        color: root.ink
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }

                    Row {
                        spacing: 6
                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: "#38bdf8"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: selectedDayData 
                                ? (selectedDayData.dateFormatted + " • " + selectedDayData.formatted)
                                : (stSection.stObj.today_date_str + " • " + stSection.stObj.today_formatted)
                            color: root.ink
                            opacity: 0.6
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            // Top action buttons
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // Jump to Today Pill (visible if viewing a past day)
                Rectangle {
                    visible: rawDays.length > 0 && selectedDayIndex !== rawDays.length - 1
                    width: 68
                    height: 28
                    radius: 14
                    color: todayMa.containsMouse ? root.fillHover : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                    border.width: 1
                    border.color: root.seal

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: "today"
                            color: root.seal
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Today"
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: todayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: stSection.selectDay(stSection.rawDays.length - 1)
                    }
                }

                // Refresh Button Pill
                Rectangle {
                    width: 80
                    height: 28
                    radius: 14
                    color: stRefMa.containsMouse ? root.fillHover : root.fillIdle
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: "refresh"
                            color: root.ink
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Refresh"
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: stRefMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!stStatusProc.running) stStatusProc.running = true
                        }
                    }
                }
            }
        }

        // ================= DUAL CARD CONTENT (borderless) =================
        Row {
            width: parent.width
            height: parent.height - 46
            spacing: 12

            // ---------------- CARD 1: ANALYTICS & 7-DAY INTERACTIVE CHART (46%) ----------------
            Rectangle {
                width: Math.round((parent.width - 12) * 0.46)
                height: parent.height
                radius: 20
                color: root.fillIdle
                border.width: 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 11

                    // SUBHEADER: Day Navigation
                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DAILY SUMMARY"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }

                        // Day navigation arrows
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            // Previous Day Button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: prevDayMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                opacity: stSection.selectedDayIndex > 0 ? 1.0 : 0.3

                                IconText {
                                    anchors.centerIn: parent
                                    text: "chevron_left"
                                    color: root.ink
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: prevDayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: stSection.selectedDayIndex > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (stSection.selectedDayIndex > 0) {
                                            stSection.selectDay(stSection.selectedDayIndex - 1)
                                        }
                                    }
                                }
                            }

                            // Next Day Button
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: nextDayMa.containsMouse ? root.fillHover : Qt.rgba(1, 1, 1, 0.04)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                opacity: (stSection.rawDays.length > 0 && stSection.selectedDayIndex < stSection.rawDays.length - 1) ? 1.0 : 0.3

                                IconText {
                                    anchors.centerIn: parent
                                    text: "chevron_right"
                                    color: root.ink
                                    font.pixelSize: 14
                                }

                                MouseArea {
                                    id: nextDayMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: (stSection.rawDays.length > 0 && stSection.selectedDayIndex < stSection.rawDays.length - 1) ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (stSection.rawDays.length > 0 && stSection.selectedDayIndex < stSection.rawDays.length - 1) {
                                            stSection.selectDay(stSection.selectedDayIndex + 1)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Big Stat Block
                    Row {
                        width: parent.width
                        spacing: 10

                        Column {
                            width: parent.width - 85
                            spacing: 1

                            Text {
                                text: selectedDayData ? selectedDayData.formatted : (stSection.stObj.today_formatted || "0m")
                                color: root.seal
                                font.family: root.barFont
                                font.pixelSize: 30
                                font.weight: Font.Bold
                            }

                            Text {
                                text: (selectedDayData && selectedDayData.isToday)
                                    ? ("Session: " + (stSection.stObj.session_formatted || "0m") + " • Yesterday: " + (stSection.stObj.yesterday_formatted || "0m"))
                                    : ((selectedDayData ? selectedDayData.dateFormatted : "") + " total screentime")
                                color: root.ink
                                opacity: 0.6
                                font.family: root.barFont
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        // Trend Badge (if today) OR Day Badge
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 75
                            height: 26
                            radius: 13
                            color: (selectedDayData && selectedDayData.isToday)
                                ? (stSection.stObj.trend.indexOf("+") === 0 ? Qt.rgba(0.9, 0.3, 0.3, 0.2) : Qt.rgba(0.2, 0.8, 0.4, 0.2))
                                : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                            border.width: 1
                            border.color: (selectedDayData && selectedDayData.isToday)
                                ? (stSection.stObj.trend.indexOf("+") === 0 ? "#f87171" : "#4ade80")
                                : root.seal

                            Row {
                                anchors.centerIn: parent
                                spacing: 3
                                IconText {
                                    text: (selectedDayData && selectedDayData.isToday)
                                        ? (stSection.stObj.trend.indexOf("+") === 0 ? "trending_up" : "trending_down")
                                        : "event"
                                    color: (selectedDayData && selectedDayData.isToday)
                                        ? (stSection.stObj.trend.indexOf("+") === 0 ? "#f87171" : "#4ade80")
                                        : root.seal
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: (selectedDayData && selectedDayData.isToday)
                                        ? stSection.stObj.trend
                                        : ("Day " + (stSection.selectedDayIndex + 1))
                                    color: (selectedDayData && selectedDayData.isToday)
                                        ? (stSection.stObj.trend.indexOf("+") === 0 ? "#f87171" : "#4ade80")
                                        : root.seal
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    // SUBHEADER: 7-Day Activity
                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "7-DAY ACTIVITY"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Tap bar to inspect"
                            color: root.ink
                            opacity: 0.4
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }

                    // 7-Day Rolling Interactive Bar Chart
                    Rectangle {
                        width: parent.width
                        height: 98
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.05)

                        Row {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: (width - 7 * 28) / 6

                            Repeater {
                                model: weekModel
                                delegate: Item {
                                    id: barColItem
                                    width: 28
                                    height: parent.height
                                    readonly property bool isSelected: index === stSection.selectedDayIndex

                                    MouseArea {
                                        id: barMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: stSection.selectDay(index)
                                    }

                                    Column {
                                        anchors.fill: parent
                                        spacing: 4

                                        // Bar Container
                                        Item {
                                            width: parent.width
                                            height: parent.height - 22

                                            // Highlight capsule behind bar if selected
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                visible: barColItem.isSelected || barMa.containsMouse
                                                color: barColItem.isSelected ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12) : Qt.rgba(1, 1, 1, 0.04)
                                                border.width: barColItem.isSelected ? 1 : 0
                                                border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.3)
                                            }

                                            // Actual Usage Bar
                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.bottomMargin: 3
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: barColItem.isSelected ? 14 : 12
                                                height: Math.max(5, (parent.height - 6) * (model.ratio || 0.05))
                                                radius: 6
                                                color: barColItem.isSelected 
                                                    ? root.seal 
                                                    : (model.isToday ? Qt.lighter(root.seal, 1.2) : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.35))
                                                Behavior on height { NumberAnimation { duration: 300 } }
                                                Behavior on width { NumberAnimation { duration: 150 } }
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                        }

                                        // Day Letter Label
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: model.dayLetter || "D"
                                            color: barColItem.isSelected ? root.seal : (model.isToday ? root.seal : root.ink)
                                            opacity: barColItem.isSelected ? 1.0 : (model.isToday ? 0.9 : 0.5)
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: barColItem.isSelected ? Font.Bold : (model.isToday ? Font.DemiBold : Font.Normal)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // Active App Focus Row
                    Column {
                        width: parent.width
                        spacing: 6

                        Text {
                            text: "CURRENT ACTIVE WINDOW"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }

                        Rectangle {
                            width: parent.width
                            height: 38
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.04)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                IconText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "tab"
                                    color: root.seal
                                    font.pixelSize: 16
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (stSection.stObj.activeApp || "Desktop") + " — " + (stSection.stObj.activeTitle || "Active")
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    width: parent.width - 32
                                }
                            }
                        }
                    }
                }
            }

            // ---------------- CARD 2: APPLICATION USAGE (54%) ----------------
            Rectangle {
                width: Math.round((parent.width - 12) * 0.54)
                height: parent.height
                radius: 20
                color: root.fillIdle
                border.width: 0
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // SUBHEADER: Day Apps
                    Item {
                        width: parent.width
                        height: 16
                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "APPLICATION USAGE"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (selectedDayData ? selectedDayData.dateFormatted : "Today") + " (" + appModel.count + " apps)"
                            color: root.ink
                            opacity: 0.5
                            font.family: root.barFont
                            font.pixelSize: 10
                        }
                    }

                    // Divider
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }

                    // Empty state if no apps
                    Item {
                        visible: appModel.count === 0
                        width: parent.width
                        height: parent.height - 34

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
                        height: parent.height - 34
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
    }
}

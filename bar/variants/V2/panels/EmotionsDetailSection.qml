import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../modules"
import "../motion"

Item {
    id: emotionsSection
    anchors.fill: parent

    required property var root
    property var panel: null
    property var emotionsManager: null

    signal closeRequested()
    signal requestCheckin()

    property int selectedWeekOffset: 0 // 0 = current week, 1 = last week...
    property var weekDays: emotionsManager ? emotionsManager.getWeekDays(selectedWeekOffset) : []

    property var selectedDay: null

    function reloadWeek() {
        if (!emotionsManager) return
        weekDays = emotionsManager.getWeekDays(selectedWeekOffset) || []
        // Default select today if in current week, else select latest day with data
        if (selectedWeekOffset === 0 && weekDays) {
            for (var i = 0; i < weekDays.length; i++) {
                if (weekDays[i].isToday) {
                    selectedDay = weekDays[i]
                    return
                }
            }
        }
        if (weekDays && weekDays.length > 0) {
            selectedDay = weekDays[0]
        }
    }

    Component.onCompleted: {
        reloadWeek()
        forceActiveFocus()
    }

    Connections {
        target: emotionsSection.emotionsManager
        ignoreUnknownSignals: true
        function onDataMapChanged() {
            reloadWeek()
        }
    }

    // Two-Column Layout (Matching Screentime exactly)
    Row {
        id: columnsRow
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: WEEKLY CHART & STATS ────────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.floor((columnsRow.width - columnsRow.spacing) * 0.52)
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

                // Week Navigator: < This week >
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: prevWkMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                emotionsSection.selectedWeekOffset++
                                emotionsSection.reloadWeek()
                            }
                        }
                    }

                    Rectangle {
                        height: 24
                        radius: 12
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        width: weekLabelText.implicitWidth + 18

                        Text {
                            id: weekLabelText
                            anchors.centerIn: parent
                            text: emotionsSection.selectedWeekOffset === 0 ? "This week" : (emotionsSection.selectedWeekOffset === 1 ? "Last week" : (emotionsSection.selectedWeekOffset + " wks ago"))
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.ink
                        }
                    }

                    Rectangle {
                        width: 24; height: 24; radius: 12
                        visible: emotionsSection.selectedWeekOffset > 0
                        color: nextWkMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (emotionsSection.selectedWeekOffset > 0) {
                                    emotionsSection.selectedWeekOffset--
                                    emotionsSection.reloadWeek()
                                }
                            }
                        }
                    }
                }

                // Action Buttons: Current Week + Close
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        visible: emotionsSection.selectedWeekOffset !== 0
                        height: 24
                        radius: 12
                        color: resetWkMa.containsMouse ? root.fillHover : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.15)
                        width: resetWkText.implicitWidth + 14

                        Text {
                            id: resetWkText
                            anchors.centerIn: parent
                            text: "Current"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.seal
                        }

                        SpringPress {}
                        MouseArea {
                            id: resetWkMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                emotionsSection.selectedWeekOffset = 0
                                emotionsSection.reloadWeek()
                            }
                        }
                    }

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
                            onClicked: emotionsSection.closeRequested()
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

                // 1. Overview Stat Row (Selected Day Mood + Subtitle)
                Item {
                    width: parent.width
                    height: 38

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Row {
                            spacing: 8
                            Text {
                                text: emotionsSection.selectedDay && emotionsSection.selectedDay.entry
                                    ? emotionsSection.selectedDay.entry.levelName
                                    : (emotionsSection.selectedDay && emotionsSection.selectedDay.isToday ? "Not logged yet" : "No entry")
                                color: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj
                                    ? emotionsSection.selectedDay.levelObj.color
                                    : root.ink
                                font.family: root.barFont
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            Text {
                                text: emotionsSection.selectedDay
                                    ? (emotionsSection.selectedDay.isToday ? "today" : emotionsSection.selectedDay.dateShort)
                                    : ""
                                color: root.ink
                                opacity: 0.55
                                font.family: root.barFont
                                font.pixelSize: 10
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: {
                                var count = 0
                                if (emotionsSection.weekDays && emotionsSection.weekDays.length) {
                                    for (var i = 0; i < emotionsSection.weekDays.length; i++) {
                                        if (emotionsSection.weekDays[i] && emotionsSection.weekDays[i].hasData) count++
                                    }
                                }
                                return count + " check-in" + (count === 1 ? "" : "s") + " this week"
                            }
                            color: root.seal
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Medium
                        }
                    }
                }

                // 2. Weekly Capsule Bar Chart (7 vertical capsules like Screentime)
                Item {
                    id: chartContainer
                    width: parent.width
                    height: 108

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        spacing: 8

                        Repeater {
                            model: emotionsSection.weekDays
                            delegate: Item {
                                id: dayBarCol
                                width: 34
                                height: parent.height

                                required property var modelData
                                readonly property bool isSelected: emotionsSection.selectedDay && emotionsSection.selectedDay.dateKey === modelData.dateKey

                                SpringPress {}
                                MouseArea {
                                    id: barMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: emotionsSection.selectedDay = dayBarCol.modelData
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 4

                                    // Capsule Bar Area
                                    Item {
                                        width: parent.width
                                        height: parent.height - 24

                                        // Capsule Pill
                                        Rectangle {
                                            id: capsuleBar
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 30
                                            // Height: if hasData, taller capsule based on mood level (50px to 80px), else low indicator
                                            height: dayBarCol.modelData.hasData
                                                ? Math.round(48 + (dayBarCol.modelData.level * 5))
                                                : (dayBarCol.modelData.isToday ? 20 : 12)
                                            radius: width / 2

                                            color: dayBarCol.modelData.hasData
                                                ? dayBarCol.modelData.levelObj.color
                                                : (dayBarCol.modelData.isToday ? Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.25) : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08))

                                            border.width: dayBarCol.isSelected ? 2 : 0
                                            border.color: root.seal

                                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation { duration: 180 } }

                                            // Emotion icon inside capsule
                                            IconText {
                                                anchors.centerIn: parent
                                                visible: dayBarCol.modelData.hasData
                                                text: dayBarCol.modelData.hasData ? dayBarCol.modelData.levelObj.icon : ""
                                                font.pixelSize: 15
                                                color: "#121214"
                                            }
                                        }
                                    }

                                    // Day of week label below capsule (M, T, W, T, F, S, S)
                                    Column {
                                        width: parent.width
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 2

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: dayBarCol.modelData.dayLetter
                                            font.family: root.barFont
                                            font.pixelSize: 10
                                            font.weight: (dayBarCol.modelData.isToday || dayBarCol.isSelected) ? Font.DemiBold : Font.Normal
                                            color: dayBarCol.isSelected ? root.seal : (dayBarCol.modelData.isToday ? root.seal : root.ink)
                                            opacity: (dayBarCol.modelData.hasData || dayBarCol.modelData.isToday) ? 1.0 : 0.45
                                        }

                                        // Today indicator dot
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: root.seal
                                            visible: dayBarCol.modelData.isToday
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Bottom Action Pill: Check-in / Log Mood
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 14
                    color: logActionMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "sentiment_satisfied"
                            font.pixelSize: 13
                            color: root.paper
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (emotionsSection.emotionsManager && emotionsSection.emotionsManager.hasLoggedToday) ? "Update Today's Emotion" : "Check In Today"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.paper
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: logActionMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: emotionsSection.requestCheckin()
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: SELECTED DAY DETAILED VIEW ─────────────────────────
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

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconText {
                        text: "spa"
                        font.pixelSize: 14
                        color: root.seal
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: emotionsSection.selectedDay ? emotionsSection.selectedDay.dateFormatted : "Today"
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Mood level badge
                    Rectangle {
                        visible: !!(emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj)
                        height: 20
                        radius: 10
                        width: badgeTxt.implicitWidth + 12
                        color: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj
                            ? Qt.rgba(emotionsSection.selectedDay.levelObj.color.r, emotionsSection.selectedDay.levelObj.color.g, emotionsSection.selectedDay.levelObj.color.b, 0.25)
                            : "transparent"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: badgeTxt
                            anchors.centerIn: parent
                            text: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj ? emotionsSection.selectedDay.levelObj.name : ""
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj ? emotionsSection.selectedDay.levelObj.color : root.ink
                        }
                    }
                }

                // Log / Check-in button in top right
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    radius: 12
                    color: rightLogMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    width: rightLogTxt.implicitWidth + 16

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        IconText {
                            text: "edit"
                            font.pixelSize: 11
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            id: rightLogTxt
                            text: "Check In"
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.ink
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    SpringPress {}
                    MouseArea {
                        id: rightLogMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: emotionsSection.requestCheckin()
                    }
                }
            }

            // Body: Day Detail
            Item {
                anchors.top: rightTopBar.bottom
                anchors.topMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8

                // Case A: Has Entry
                Column {
                    anchors.fill: parent
                    spacing: 8
                    visible: !!(emotionsSection.selectedDay && emotionsSection.selectedDay.entry)

                    // Hero Mood Capsule Display
                    Rectangle {
                        width: parent.width
                        height: 72
                        radius: 14
                        color: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj
                            ? Qt.rgba(emotionsSection.selectedDay.levelObj.color.r, emotionsSection.selectedDay.levelObj.color.g, emotionsSection.selectedDay.levelObj.color.b, 0.15)
                            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)

                        Row {
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj ? emotionsSection.selectedDay.levelObj.color : root.seal
                                anchors.verticalCenter: parent.verticalCenter

                                IconText {
                                    anchors.centerIn: parent
                                    text: emotionsSection.selectedDay && emotionsSection.selectedDay.levelObj ? emotionsSection.selectedDay.levelObj.icon : "sentiment_satisfied"
                                    font.pixelSize: 24
                                    color: "#121214"
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: emotionsSection.selectedDay && emotionsSection.selectedDay.entry ? emotionsSection.selectedDay.entry.levelName : ""
                                    font.family: root.barFont
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    color: root.ink
                                }

                                Text {
                                    text: emotionsSection.selectedDay && emotionsSection.selectedDay.entry ? ("Logged at " + emotionsSection.selectedDay.entry.time + " (" + emotionsSection.selectedDay.entry.mode + ")") : ""
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: root.sumi
                                }
                            }
                        }
                    }

                    // Feelings Tags
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "FEELINGS"
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: root.sumi
                        }

                        Row {
                            spacing: 5
                            Repeater {
                                model: (emotionsSection.selectedDay && emotionsSection.selectedDay.entry) ? emotionsSection.selectedDay.entry.tags : []
                                delegate: Rectangle {
                                    required property string modelData
                                    height: 20
                                    radius: 10
                                    width: tagT.implicitWidth + 12
                                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                                    Text {
                                        id: tagT
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        color: root.ink
                                    }
                                }
                            }
                        }
                    }

                    // Context Tags
                    Column {
                        width: parent.width
                        spacing: 4

                        Text {
                            text: "CONTEXT"
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: root.sumi
                        }

                        Row {
                            spacing: 5
                            Repeater {
                                model: (emotionsSection.selectedDay && emotionsSection.selectedDay.entry) ? emotionsSection.selectedDay.entry.context : []
                                delegate: Rectangle {
                                    required property string modelData
                                    height: 20
                                    radius: 10
                                    width: ctxT.implicitWidth + 12
                                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.16)

                                    Text {
                                        id: ctxT
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        color: root.seal
                                    }
                                }
                            }
                        }
                    }
                }

                // Case B: No Entry for Selected Day
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: !(emotionsSection.selectedDay && emotionsSection.selectedDay.entry)

                    IconText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "wb_twilight"
                        font.pixelSize: 32
                        color: root.sumi
                        opacity: 0.5
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No emotion check-in for this day"
                        font.family: root.barFont
                        font.pixelSize: 12
                        color: root.sumi
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: emptyBtnTxt.implicitWidth + 24
                        height: 28
                        radius: 14
                        color: emptyLogMa.containsMouse ? root.fillHover : Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.20)

                        Text {
                            id: emptyBtnTxt
                            anchors.centerIn: parent
                            text: "Check In Now"
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: root.seal
                        }

                        SpringPress {}
                        MouseArea {
                            id: emptyLogMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: emotionsSection.requestCheckin()
                        }
                    }
                }
            }
        }
    }
}

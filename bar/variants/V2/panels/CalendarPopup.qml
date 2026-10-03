import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: calPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-calendar"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property real reveal: root.calendarVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.calendarVisible ? 160 : 120
            easing.type: root.calendarVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = false
    }

    // ── Live time & date state ──────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: calPopup.visible
        repeat: true
        onTriggered: calPopup.now = new Date()
    }

    function pad(n) { return n < 10 ? "0" + n : String(n); }

    readonly property string nowTimeStr: {
        var h = now.getHours();
        var m = pad(now.getMinutes());
        var s = pad(now.getSeconds());
        if (root.clock12h) {
            var ampm = h < 12 ? "AM" : "PM";
            var h12 = h % 12;
            if (h12 === 0) h12 = 12;
            return pad(h12) + ":" + m + ":" + s + " " + ampm;
        }
        return pad(h) + ":" + m + ":" + s;
    }

    function getDayOfYear(d) {
        var start = new Date(d.getFullYear(), 0, 1);
        var diff = (d - start) + ((start.getTimezoneOffset() - d.getTimezoneOffset()) * 60000);
        return Math.floor(diff / 86400000) + 1;
    }
    readonly property int currentDayOfYear: getDayOfYear(now)
    readonly property int totalDaysInYear: ((now.getFullYear() % 4 === 0 && now.getFullYear() % 100 !== 0) || (now.getFullYear() % 400 === 0)) ? 366 : 365
    readonly property real yearProgress: Math.min(1.0, currentDayOfYear / totalDaysInYear)
    readonly property string quarterStr: "Q" + (Math.floor(now.getMonth() / 3) + 1)

    function getISOWeek(d) {
        var date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        var dayNum = date.getUTCDay() || 7;
        date.setUTCDate(date.getUTCDate() + 4 - dayNum);
        var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
        return Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
    }
    readonly property int currentWeekNum: getISOWeek(now)

    readonly property var viewDate: new Date(now.getFullYear(), now.getMonth() + root.calendarMonthOffset, 1)
    readonly property int viewYear: viewDate.getFullYear()
    readonly property int viewMonth: viewDate.getMonth()

    property int selYear: now.getFullYear()
    property int selMonth: now.getMonth()
    property int selDay: now.getDate()

    readonly property var months: ["JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
                                   "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"]
    readonly property var monthsShort: ["JAN","FEB","MAR","APR","MAY","JUN",
                                        "JUL","AUG","SEP","OCT","NOV","DEC"]
    readonly property var daysShort: ["SUN","MON","TUE","WED","THU","FRI","SAT"]

    function dateKey(y, m, d) {
        var mm = (m + 1) < 10 ? "0" + (m + 1) : String(m + 1);
        var dd = d < 10 ? "0" + d : String(d);
        return y + "-" + mm + "-" + dd;
    }

    readonly property string selectedKey: dateKey(selYear, selMonth, selDay)
    readonly property var selectedDateObj: new Date(selYear, selMonth, selDay)

    readonly property string selectedDayLabel: {
        var d = selectedDateObj;
        var dow = daysShort[d.getDay()];
        var m = monthsShort[d.getMonth()];
        return dow + ", " + pad(selDay) + " " + m + " " + selYear;
    }

    readonly property string selectedRelativeStr: {
        var today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        var target = new Date(selYear, selMonth, selDay);
        var diff = Math.round((target - today) / 86400000);
        if (diff === 0) return "TODAY";
        if (diff === 1) return "TOMORROW";
        if (diff === -1) return "YESTERDAY";
        if (diff > 1) return "IN " + diff + " DAYS";
        return Math.abs(diff) + " DAYS AGO";
    }

    Connections {
        target: root
        function onCalendarVisibleChanged() {
            if (root.calendarVisible) {
                calPopup.now = new Date();
                calPopup.selYear = calPopup.now.getFullYear();
                calPopup.selMonth = calPopup.now.getMonth();
                calPopup.selDay = calPopup.now.getDate();
            }
        }
    }

    // ── Persistent Notes & Reminders per date ────────────────────────────
    property var notesMap: ({})

    FileView {
        id: notesFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell_calendar_notes.json"
        watchChanges: true
        onLoaded: {
            try {
                var txt = notesFile.text().trim();
                calPopup.notesMap = txt.length > 0 ? JSON.parse(txt) : {};
            } catch(e) {
                calPopup.notesMap = {};
            }
        }
    }

    Process {
        id: saveNotesProc
        property string jsonPayload: "{}"
        command: ["python3", "-c", 
            "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])", 
            Quickshell.env("HOME") + "/.local/state/quickshell_calendar_notes.json", 
            jsonPayload
        ]
    }

    function saveNotes() {
        saveNotesProc.jsonPayload = JSON.stringify(notesMap);
        saveNotesProc.running = false;
        saveNotesProc.running = true;
    }

    function addNote(key, text) {
        if (!text || text.trim() === "") return;
        var map = Object.assign({}, notesMap);
        if (!map[key]) map[key] = [];
        map[key].push({ id: Date.now().toString(), text: text.trim(), done: false });
        notesMap = map;
        saveNotes();
    }

    function toggleNote(key, id) {
        var map = Object.assign({}, notesMap);
        if (!map[key]) return;
        for (var i = 0; i < map[key].length; i++) {
            if (map[key][i].id === id) {
                map[key][i].done = !map[key][i].done;
                break;
            }
        }
        notesMap = map;
        saveNotes();
    }

    function deleteNote(key, id) {
        var map = Object.assign({}, notesMap);
        if (!map[key]) return;
        var updated = [];
        for (var i = 0; i < map[key].length; i++) {
            if (map[key][i].id !== id) updated.push(map[key][i]);
        }
        if (updated.length > 0) {
            map[key] = updated;
        } else {
            delete map[key];
        }
        notesMap = map;
        saveNotes();
    }

    function hasNotes(key) {
        if (!key || !notesMap) return false;
        return Boolean(notesMap[key] && notesMap[key].length > 0);
    }

    readonly property var currentDayNotes: (notesMap && notesMap[selectedKey]) ? notesMap[selectedKey] : []

    // ── Grid & ISO Week calculation ─────────────────────────────────────
    readonly property var gridData: {
        var y = viewYear;
        var m = viewMonth;
        var firstDay = new Date(y, m, 1);
        var startDay = (firstDay.getDay() + 6) % 7; // 0 = Mon ... 6 = Sun
        var daysInMonth = new Date(y, m + 1, 0).getDate();
        var prevMonthDays = new Date(y, m, 0).getDate();
        
        var today = now;
        var tY = today.getFullYear();
        var tM = today.getMonth();
        var tD = today.getDate();
        
        var cells = [];
        // Leading days from previous month
        for (var i = startDay - 1; i >= 0; i--) {
            var dPrev = prevMonthDays - i;
            var prevDate = new Date(y, m - 1, dPrev);
            var pY = prevDate.getFullYear();
            var pM = prevDate.getMonth();
            cells.push({
                day: dPrev,
                year: pY,
                month: pM,
                isCurrentMonth: false,
                isToday: (pY === tY && pM === tM && dPrev === tD),
                key: dateKey(pY, pM, dPrev),
                dateObj: prevDate
            });
        }
        // Current month days
        for (var d = 1; d <= daysInMonth; d++) {
            var curDate = new Date(y, m, d);
            cells.push({
                day: d,
                year: y,
                month: m,
                isCurrentMonth: true,
                isToday: (y === tY && m === tM && d === tD),
                key: dateKey(y, m, d),
                dateObj: curDate
            });
        }
        // Trailing days from next month
        var nextD = 1;
        while (cells.length < 42) {
            var nextDate = new Date(y, m + 1, nextD);
            var nY = nextDate.getFullYear();
            var nM = nextDate.getMonth();
            cells.push({
                day: nextD,
                year: nY,
                month: nM,
                isCurrentMonth: false,
                isToday: (nY === tY && nM === tM && nextD === tD),
                key: dateKey(nY, nM, nextD),
                dateObj: nextDate
            });
            nextD++;
        }
        return cells;
    }

    readonly property var weekNumbers: {
        var g = gridData;
        if (!g || g.length < 42) return [0,0,0,0,0,0];
        return [
            getISOWeek(g[3].dateObj),
            getISOWeek(g[10].dateObj),
            getISOWeek(g[17].dateObj),
            getISOWeek(g[24].dateObj),
            getISOWeek(g[31].dateObj),
            getISOWeek(g[38].dateObj)
        ];
    }

    // ── Main Brutalist Card ─────────────────────────────────────────────
    Rectangle {
        id: card
        width: 350
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: calPopup.root
            ownerActive: calPopup.root.calendarVisible
            targetX: calPopup.root.calendarBarX
            reveal: calPopup.reveal
        }

        x: root.calendarBarX > 0
            ? Math.round(Math.max(12, Math.min(root.calendarBarX - width / 2, parent.width - width - 12)))
            : Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - calPopup.reveal)
            : (barBottom + gap) - 2 * (1 - calPopup.reveal)
        opacity: calPopup.reveal
        focus: root.calendarVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (noteInput.activeFocus) {
                    card.focus = true;
                } else {
                    root.calendarVisible = false;
                }
                event.accepted = true;
            } else if (!noteInput.activeFocus) {
                if (event.key === Qt.Key_Left) {
                    root.calendarMonthOffset--;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.calendarMonthOffset++;
                    event.accepted = true;
                } else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) {
                    root.calendarMonthOffset = 0;
                    calPopup.selYear = calPopup.now.getFullYear();
                    calPopup.selMonth = calPopup.now.getMonth();
                    calPopup.selDay = calPopup.now.getDate();
                    event.accepted = true;
                }
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── TOP BRUTALIST HEADER: Navigation & Status ───────────────
            Item {
                width: parent.width
                height: 24

                // [ ‹ PREV ]
                Rectangle {
                    id: prevBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 22
                    radius: 8
                    border.width: 0
                    border.color: prevMa.containsMouse ? root.seal : root.sep
                    color: prevMa.containsMouse ? root.fillHover : root.fillIdle
                    UiText {
                        anchors.centerIn: parent
                        text: "‹"
                        color: prevMa.containsMouse ? root.seal : root.ink
                        font.family: root.barFont
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarMonthOffset--
                    }
                }

                // Month + Year Title (clickable to return to today)
                Item {
                    anchors.centerIn: parent
                    width: monthTitleTxt.implicitWidth + 12
                    height: 22

                    UiText {
                        id: monthTitleTxt
                        anchors.centerIn: parent
                        text: calPopup.months[calPopup.viewMonth] + " " + calPopup.viewYear
                        color: monthMa.containsMouse && root.calendarMonthOffset !== 0 ? root.seal : root.ink
                        font.family: root.barFont
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: monthMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.calendarMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.calendarMonthOffset = 0;
                            calPopup.selYear = calPopup.now.getFullYear();
                            calPopup.selMonth = calPopup.now.getMonth();
                            calPopup.selDay = calPopup.now.getDate();
                        }
                    }
                }

                // [ TODAY ] badge (shows when navigated away) + [ NEXT › ]
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        height: 22
                        width: todayBadgeTxt.implicitWidth + 8
                        radius: 8
                        border.width: 0
                        border.color: root.seal
                        color: todayBadgeMa.containsMouse ? root.fillActive : root.fillIdle
                        visible: root.calendarMonthOffset !== 0
                        UiText {
                            id: todayBadgeTxt
                            anchors.centerIn: parent
                            text: "TODAY"
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                            color: root.seal
                        }
                        MouseArea {
                            id: todayBadgeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.calendarMonthOffset = 0;
                                calPopup.selYear = calPopup.now.getFullYear();
                                calPopup.selMonth = calPopup.now.getMonth();
                                calPopup.selDay = calPopup.now.getDate();
                            }
                        }
                    }

                    Rectangle {
                        id: nextBtn
                        width: 26; height: 22
                        radius: 8
                        border.width: 0
                        border.color: nextMa.containsMouse ? root.seal : root.sep
                        color: nextMa.containsMouse ? root.fillHover : root.fillIdle
                        UiText {
                            anchors.centerIn: parent
                            text: "›"
                            color: nextMa.containsMouse ? root.seal : root.ink
                            font.family: root.barFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                        }
                        MouseArea {
                            id: nextMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.calendarMonthOffset++
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Live digital clock with seconds
                    Rectangle {
                        height: 20
                        width: timeTxt.implicitWidth + 10
                        radius: 8
                        border.width: 0
                        border.color: root.sep
                        color: root.fillIdle
                        UiText {
                            id: timeTxt
                            anchors.centerIn: parent
                            text: calPopup.nowTimeStr
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                    }

                    // ISO Week Number
                    Rectangle {
                        height: 20
                        width: wkTxt.implicitWidth + 8
                        radius: 8
                        border.width: 0
                        border.color: root.sep
                        color: root.fillIdle
                        UiText {
                            id: wkTxt
                            anchors.centerIn: parent
                            text: "WK " + calPopup.currentWeekNum
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                    }

                    // Day of year counter
                    Rectangle {
                        height: 20
                        width: doyTxt.implicitWidth + 8
                        radius: 8
                        border.width: 0
                        border.color: root.sep
                        color: root.fillIdle
                        UiText {
                            id: doyTxt
                            anchors.centerIn: parent
                            text: "DAY " + calPopup.currentDayOfYear + "/" + calPopup.totalDaysInYear
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                    }
                }

                // Quarter badge
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: qTxt.implicitWidth + 8
                    radius: 8
                    border.width: 0
                    border.color: root.seal
                    color: root.fillActive
                    UiText {
                        id: qTxt
                        anchors.centerIn: parent
                        text: calPopup.quarterStr
                        color: root.seal
                        font.family: root.barFont
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                    }
                }
            }

            // Year progress bar
            Item {
                width: parent.width
                height: 3

                Rectangle {
                    anchors.fill: parent
                    radius: 4.5
                    color: root.sep
                }

                Rectangle {
                    height: parent.height
                    width: Math.round(parent.width * calPopup.yearProgress)
                    radius: 4.5
                    color: root.seal
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── CALENDAR MATRIX HEADER: WK + Weekdays ────────────────────
            Row {
                width: parent.width
                spacing: 6

                // Week column header
                UiText {
                    width: 26
                    text: "WK"
                    horizontalAlignment: Text.AlignHCenter
                    color: root.sumi
                    font.family: root.barFont
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }

                Rectangle { width: 1; height: 14; color: root.sep; anchors.verticalCenter: parent.verticalCenter }

                // 7 weekday columns
                Row {
                    width: parent.width - 34
                    Repeater {
                        model: ["MO","TU","WE","TH","FR","SA","SU"]
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width: (parent.width - 12) / 7
                            height: 16
                            UiText {
                                anchors.centerIn: parent
                                text: modelData
                                color: index >= 5 ? root.seal : root.inkDeep
                                opacity: index >= 5 ? 0.9 : 0.7
                                font.family: root.barFont
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }

            // ── CALENDAR MATRIX BODY: Week numbers + 6x7 Grid ────────────
            Row {
                width: parent.width
                spacing: 6

                // Week numbers column
                Column {
                    width: 26
                    spacing: 2
                    Repeater {
                        model: calPopup.weekNumbers
                        delegate: Item {
                            required property int modelData
                            width: parent.width
                            height: 24
                            UiText {
                                anchors.centerIn: parent
                                text: modelData > 0 ? ("W" + modelData) : ""
                                color: modelData === calPopup.currentWeekNum ? root.seal : root.sumi
                                opacity: modelData === calPopup.currentWeekNum ? 0.95 : 0.45
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: modelData === calPopup.currentWeekNum ? Font.Bold : Font.Normal
                                font.letterSpacing: 0.5
                            }
                        }
                    }
                }

                Rectangle {
                    width: 1
                    height: 6 * 26 - 2
                    color: root.sep
                    anchors.verticalCenter: parent.verticalCenter
                }

                // 42-cell Grid (6 rows x 7 days)
                Grid {
                    id: gridView
                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2
                    width: parent.width - 34

                    Repeater {
                        model: calPopup.gridData
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: (gridView.width - 12) / 7
                            height: 24

                            readonly property int dayOfWeek: index % 7
                            readonly property bool isCurrentMonth: modelData ? Boolean(modelData.isCurrentMonth) : false
                            readonly property bool isToday: modelData ? Boolean(modelData.isToday) : false
                            readonly property bool isSelected: modelData ? Boolean(modelData.year === calPopup.selYear && modelData.month === calPopup.selMonth && modelData.day === calPopup.selDay) : false
                            readonly property bool dayHasNotes: (modelData && modelData.key) ? calPopup.hasNotes(modelData.key) : false

                            readonly property color textColor: {
                                if (isToday) return root.seal.hsvValue < 0.5 ? root.ink : root.paper;
                                if (!isCurrentMonth) return root.sumi;
                                if (isSelected) return root.seal;
                                return dayOfWeek >= 5 ? root.seal : root.ink;
                            }

                            // Brutalist Tile Box
                            Rectangle {
                                id: tileBox
                                anchors.fill: parent
                                radius: 8
                                border.width: 0
                                border.color: isToday 
                                    ? root.seal 
                                    : (isSelected 
                                        ? root.seal 
                                        : (cellMa.containsMouse ? root.sep : "transparent"))
                                color: isToday 
                                    ? root.seal 
                                    : (isSelected 
                                        ? root.fillActive 
                                        : (cellMa.containsMouse ? root.fillHover : root.fillIdle))

                                // Day number
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    color: textColor
                                    opacity: isCurrentMonth ? 1.0 : 0.35
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.weight: (isToday || isSelected) ? Font.Bold : Font.Normal
                                }

                                // Note marker pip (brutalist square)
                                Rectangle {
                                    width: 3; height: 3; radius: 4
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: isToday ? (root.seal.hsvValue < 0.5 ? root.ink : root.paper) : root.seal
                                    visible: dayHasNotes
                                }
                            }

                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    calPopup.selYear = modelData.year;
                                    calPopup.selMonth = modelData.month;
                                    calPopup.selDay = modelData.day;
                                    if (!modelData.isCurrentMonth) {
                                        if (modelData.month < calPopup.viewMonth) {
                                            root.calendarMonthOffset--;
                                        } else {
                                            root.calendarMonthOffset++;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── SELECTED DAY INSPECTOR & QUICK NOTES ────────────────────
            Column {
                width: parent.width
                spacing: 6

                // Selected day header + relative badge
                Row {
                    width: parent.width
                    spacing: 6

                    UiText {
                        text: calPopup.selectedDayLabel.toUpperCase()
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2
                        color: root.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1 }

                    Rectangle {
                        height: 18
                        width: relTxt.implicitWidth + 8
                        radius: 8
                        border.width: 0
                        border.color: calPopup.selectedRelativeStr === "TODAY" ? root.seal : root.sep
                        color: calPopup.selectedRelativeStr === "TODAY" ? root.fillActive : root.fillIdle
                        anchors.verticalCenter: parent.verticalCenter
                        UiText {
                            id: relTxt
                            anchors.centerIn: parent
                            text: calPopup.selectedRelativeStr
                            font.family: root.barFont
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: calPopup.selectedRelativeStr === "TODAY" ? root.seal : root.sumi
                        }
                    }
                }

                // Notes List for selected date
                Column {
                    width: parent.width
                    spacing: 4
                    visible: calPopup.currentDayNotes.length > 0

                    Repeater {
                        model: calPopup.currentDayNotes
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 24
                            radius: 8
                            color: noteRowMa.containsMouse ? root.fillHover : root.fillIdle
                            border.width: 0
                            border.color: root.sep

                            MouseArea {
                                id: noteRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                // Checkbox toggle
                                Rectangle {
                                    width: 14; height: 14; radius: 8
                                    border.width: 0
                                    border.color: modelData.done ? root.seal : root.sumi
                                    color: modelData.done ? root.seal : root.fillIdle
                                    anchors.verticalCenter: parent.verticalCenter
                                    UiText {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        font.family: root.barFont
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        color: root.paper
                                        visible: modelData.done
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calPopup.toggleNote(calPopup.selectedKey, modelData.id)
                                    }
                                }

                                // Note text
                                UiText {
                                    text: modelData.text
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.strikeout: modelData.done
                                    color: modelData.done ? root.sumi : root.ink
                                    opacity: modelData.done ? 0.6 : 1.0
                                    elide: Text.ElideRight
                                    width: parent.width - 48
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Delete button
                                Rectangle {
                                    width: 16; height: 16; radius: 8
                                    color: delMa.containsMouse ? root.seal : root.fillIdle
                                    visible: noteRowMa.containsMouse
                                    anchors.verticalCenter: parent.verticalCenter
                                    UiText {
                                        anchors.centerIn: parent
                                        text: "×"
                                        font.family: root.barFont
                                        font.pixelSize: 13
                                        color: delMa.containsMouse ? root.paper : root.sumi
                                    }
                                    MouseArea {
                                        id: delMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calPopup.deleteNote(calPopup.selectedKey, modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }

                // Add note inline input
                Rectangle {
                    width: parent.width
                    height: 26
                    radius: 8
                    color: root.fillIdle
                    border.width: 0
                    border.color: noteInput.activeFocus ? root.seal : root.sep

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 6

                        TextInput {
                            id: noteInput
                            width: parent.width - 32
                            height: parent.height
                            verticalAlignment: TextInput.AlignVCenter
                            color: root.ink
                            font.family: root.barFont
                            font.pixelSize: 11
                            clip: true
                            selectByMouse: true

                            UiText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "+ Add note / reminder (press Enter)..."
                                font.family: root.barFont
                                font.pixelSize: 11
                                color: root.sumi
                                opacity: 0.6
                                visible: noteInput.text === "" && !noteInput.activeFocus
                            }

                            onAccepted: {
                                if (noteInput.text.trim() !== "") {
                                    calPopup.addNote(calPopup.selectedKey, noteInput.text);
                                    noteInput.text = "";
                                }
                            }
                        }

                        Rectangle {
                            width: 20
                            height: 18
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            border.width: 0
                            border.color: addBtnMa.containsMouse ? root.seal : root.sep
                            color: addBtnMa.containsMouse ? root.fillActive : root.fillIdle
                            visible: noteInput.text.trim() !== ""
                            UiText {
                                anchors.centerIn: parent
                                text: "↵"
                                font.family: root.barFont
                                font.pixelSize: 11
                                color: addBtnMa.containsMouse ? root.seal : root.sumi
                            }
                            MouseArea {
                                id: addBtnMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (noteInput.text.trim() !== "") {
                                        calPopup.addNote(calPopup.selectedKey, noteInput.text);
                                        noteInput.text = "";
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

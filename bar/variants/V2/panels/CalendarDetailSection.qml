import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../modules"

Item {
    id: calSection
    anchors.fill: parent

    required property var root
    property var panel: null

    signal closeRequested()

    // ── Live time & date state ──────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: calSection.visible
        repeat: true
        onTriggered: calSection.now = new Date()
    }

    function pad(n) { return n < 10 ? "0" + n : String(n); }

    property int selYear: now.getFullYear()
    property int selMonth: now.getMonth()
    property int selDay: now.getDate()

    readonly property var months: ["January","February","March","April","May","June",
                                   "July","August","September","October","November","December"]
    readonly property var monthsShort: ["Jan","Feb","Mar","Apr","May","Jun",
                                        "Jul","Aug","Sep","Oct","Nov","Dec"]
    readonly property var daysShort: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

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
        return dow + ", " + pad(selDay) + " " + m;
    }

    readonly property string selectedDayFullLabel: {
        var d = selectedDateObj;
        var dow = daysShort[d.getDay()];
        var m = monthsShort[d.getMonth()];
        return dow + ", " + pad(selDay) + " " + m + " " + selYear;
    }

    readonly property bool isSelectedToday: (selYear === now.getFullYear() && selMonth === now.getMonth() && selDay === now.getDate())

    property string viewMode: "weekly" // "weekly" or "monthly"

    readonly property bool isInputFocused: noteTextInput.activeFocus

    onVisibleChanged: {
        if (visible) {
            calSection.now = new Date();
            calSection.selYear = calSection.now.getFullYear();
            calSection.selMonth = calSection.now.getMonth();
            calSection.selDay = calSection.now.getDate();
            if (curvedWeekView) {
                curvedWeekView.scrollOffset = 0;
                curvedWeekView.targetOffset = 0;
            }
            notesFile.reload();
        }
    }

    onViewModeChanged: {
        if (viewMode === "monthly" && curvedWeekView) {
            curvedWeekView.stopScrollAnim();
        }
    }

    function jumpToToday() {
        calSection.now = new Date();
        calSection.selYear = calSection.now.getFullYear();
        calSection.selMonth = calSection.now.getMonth();
        calSection.selDay = calSection.now.getDate();
        if (curvedWeekView) {
            curvedWeekView.stopScrollAnim();
        }
    }

    function stepDay(delta) {
        var d = new Date(selYear, selMonth, selDay + delta);
        selYear = d.getFullYear();
        selMonth = d.getMonth();
        selDay = d.getDate();
    }

    function stepMonth(delta) {
        var d = new Date(selYear, selMonth + delta, 1);
        var maxDays = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
        var day = Math.min(selDay, maxDays);
        selYear = d.getFullYear();
        selMonth = d.getMonth();
        selDay = day;
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
                calSection.notesMap = txt.length > 0 ? JSON.parse(txt) : {};
            } catch(e) {
                calSection.notesMap = {};
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

    // ── Helper to retrieve dates for the curved day positions ──
    function getWeekDayItem(offset) {
        var d = new Date(selYear, selMonth, selDay + offset);
        var y = d.getFullYear();
        var m = d.getMonth();
        var dayNum = d.getDate();
        var key = dateKey(y, m, dayNum);
        var isToday = (y === now.getFullYear() && m === now.getMonth() && dayNum === now.getDate());
        return {
            dateObj: d,
            year: y,
            month: m,
            day: dayNum,
            dayName: daysShort[d.getDay()],
            key: key,
            isToday: isToday,
            hasNotes: hasNotes(key),
            offset: offset
        };
    }

    // ── 42-day Month Grid calculation for Monthly view ──
    readonly property var monthGridData: {
        var y = selYear;
        var m = selMonth;
        var firstDay = new Date(y, m, 1);
        var startDay = (firstDay.getDay() + 6) % 7; // 0 = Mon ... 6 = Sun
        var daysInMonth = new Date(y, m + 1, 0).getDate();
        var prevMonthDays = new Date(y, m, 0).getDate();
        
        var tY = now.getFullYear();
        var tM = now.getMonth();
        var tD = now.getDate();
        
        var cells = [];
        for (var i = startDay - 1; i >= 0; i--) {
            var dPrev = prevMonthDays - i;
            var prevDate = new Date(y, m - 1, dPrev);
            var pY = prevDate.getFullYear();
            var pM = prevDate.getMonth();
            var pKey = dateKey(pY, pM, dPrev);
            cells.push({
                day: dPrev,
                year: pY,
                month: pM,
                isCurrentMonth: false,
                isToday: (pY === tY && pM === tM && dPrev === tD),
                key: pKey,
                hasNotes: hasNotes(pKey)
            });
        }
        for (var d = 1; d <= daysInMonth; d++) {
            var cKey = dateKey(y, m, d);
            cells.push({
                day: d,
                year: y,
                month: m,
                isCurrentMonth: true,
                isToday: (y === tY && m === tM && d === tD),
                key: cKey,
                hasNotes: hasNotes(cKey)
            });
        }
        var nextD = 1;
        while (cells.length < 42) {
            var nextDate = new Date(y, m + 1, nextD);
            var nY = nextDate.getFullYear();
            var nM = nextDate.getMonth();
            var nKey = dateKey(nY, nM, nextD);
            cells.push({
                day: nextD,
                year: nY,
                month: nM,
                isCurrentMonth: false,
                isToday: (nY === tY && nM === tM && nextD === tD),
                key: nKey,
                hasNotes: hasNotes(nKey)
            });
            nextD++;
        }
        return cells;
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ── TWO-COLUMN DASHBOARD LAYOUT (Seamless, No Outer Borders) ─────────────
    // ═════════════════════════════════════════════════════════════════════════
    Row {
        id: columnsRow
        anchors.fill: parent
        spacing: 12

        // ═════════════════════════════════════════════════════════════════════
        // ── LEFT COLUMN: CURVED CALENDAR WIDGET ──────────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: leftColContainer
            width: Math.round((columnsRow.width - columnsRow.spacing) / 2)
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            // 1. TOP BAR: [ Weekly | Monthly ] & Action Buttons
            Item {
                id: leftTopBar
                anchors.top: parent.top
                anchors.topMargin: 9
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26

                // Segmented Pill [ Weekly | Monthly ]
                Rectangle {
                    id: tabPill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 136
                    height: 26
                    radius: 13
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    border.width: 0

                    // Sliding active highlight pill
                    Rectangle {
                        id: activeTabHighlight
                        width: 66
                        height: 22
                        radius: 11
                        y: 2
                        x: calSection.viewMode === "weekly" ? 2 : 68
                        color: root.seal
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }

                    Row {
                        anchors.fill: parent

                        // Weekly Tab
                        Item {
                            width: 68
                            height: parent.height
                            UiText {
                                anchors.centerIn: parent
                                text: "Weekly"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: calSection.viewMode === "weekly" ? Font.Bold : Font.Medium
                                color: calSection.viewMode === "weekly" 
                                    ? (root.seal.hsvValue < 0.5 ? root.ink : root.paper) 
                                    : root.ink
                                opacity: calSection.viewMode === "weekly" ? 1.0 : 0.65
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calSection.viewMode = "weekly"
                            }
                        }

                        // Monthly Tab
                        Item {
                            width: 68
                            height: parent.height
                            UiText {
                                anchors.centerIn: parent
                                text: "Monthly"
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: calSection.viewMode === "monthly" ? Font.Bold : Font.Medium
                                color: calSection.viewMode === "monthly" 
                                    ? (root.seal.hsvValue < 0.5 ? root.ink : root.paper) 
                                    : root.ink
                                opacity: calSection.viewMode === "monthly" ? 1.0 : 0.65
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calSection.viewMode = "monthly"
                            }
                        }
                    }
                }

                // Top Right Action Buttons: Jump to Today + Close
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Jump to Today Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: todayBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 120 } }

                        IconText {
                            anchors.centerIn: parent
                            text: "today"
                            color: root.ink
                            opacity: 0.85
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: todayBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calSection.jumpToToday()
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: closeBtnMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: 120 } }

                        IconText {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.ink
                            opacity: 0.85
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: closeBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calSection.closeRequested()
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // ── WEEKLY VIEW CONTENT ──────────────────────────────────────────
            // ═════════════════════════════════════════════════════════════════

            // 2A. HERO DATE ROW: Month Name (left) & Day Number (right) - ONLY IN WEEKLY VIEW
            Item {
                id: heroDateRow
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                height: 32
                visible: calSection.viewMode === "weekly"

                // Month Name (e.g. "October")
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: calSection.months[calSection.selMonth]
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.4
                }

                // Day Number (e.g. "18")
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: calSection.selDay
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.4
                }
            }

            // 3A. CURVED DAYS BAND (WEEKLY VIEW) WITH PHYSICAL GLIDE ANIMATION
            Item {
                id: curvedWeekView
                anchors.top: heroDateRow.bottom
                anchors.topMargin: 2
                anchors.left: parent.left
                anchors.right: parent.right
                height: 86
                visible: calSection.viewMode === "weekly"
                clip: true

                readonly property real archHeight: 12.0
                readonly property real ribbonBaseY: 42.0
                readonly property real ribbonThickness: 32.0
                readonly property real sidePad: 10.0
                readonly property real trackWidth: width - (sidePad * 2)

                function archOffsetY(t) {
                    return 4.0 * archHeight * t * (1.0 - t);
                }

                property real scrollOffset: 0.0
                property real targetOffset: 0.0

                function stopScrollAnim() {
                    if (scrollAnim.running) scrollAnim.stop();
                    scrollOffset = 0;
                    targetOffset = 0;
                }

                NumberAnimation {
                    id: scrollAnim
                    target: curvedWeekView
                    property: "scrollOffset"
                    duration: 200
                    easing.type: Easing.OutCubic
                    onFinished: {
                        var delta = Math.round(curvedWeekView.scrollOffset);
                        if (delta !== 0) {
                            calSection.stepDay(delta);
                            curvedWeekView.scrollOffset = 0;
                            curvedWeekView.targetOffset = 0;
                        }
                    }
                }

                function scrollBy(delta) {
                    targetOffset = Math.round(targetOffset) + delta;
                    targetOffset = Math.max(-4, Math.min(4, targetOffset));
                    scrollAnim.stop();
                    scrollAnim.from = scrollOffset;
                    scrollAnim.to = targetOffset;
                    scrollAnim.duration = Math.max(180, Math.min(280, 150 + Math.abs(targetOffset - scrollOffset) * 40));
                    scrollAnim.start();
                }

                // Upward Curved Background Ribbon Shape
                Shape {
                    id: curveShape
                    anchors.fill: parent
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeColor: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10)
                        strokeWidth: 1
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        fillColor: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.08)

                        startX: curvedWeekView.sidePad
                        startY: curvedWeekView.ribbonBaseY

                        PathQuad {
                            x: curvedWeekView.sidePad + curvedWeekView.trackWidth
                            y: curvedWeekView.ribbonBaseY
                            controlX: curvedWeekView.sidePad + (curvedWeekView.trackWidth / 2)
                            controlY: curvedWeekView.ribbonBaseY - (curvedWeekView.archHeight * 2)
                        }

                        PathLine {
                            x: curvedWeekView.sidePad + curvedWeekView.trackWidth
                            y: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness
                        }

                        PathQuad {
                            x: curvedWeekView.sidePad
                            y: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness
                            controlX: curvedWeekView.sidePad + (curvedWeekView.trackWidth / 2)
                            controlY: curvedWeekView.ribbonBaseY + curvedWeekView.ribbonThickness - (curvedWeekView.archHeight * 2)
                        }

                        PathLine {
                            x: curvedWeekView.sidePad
                            y: curvedWeekView.ribbonBaseY
                        }
                    }
                }

                // Fixed Summit Center Circular Badge at the peak of the curve
                Rectangle {
                    id: summitCenterBadge
                    width: 30
                    height: 30
                    radius: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(curvedWeekView.ribbonBaseY - curvedWeekView.archHeight + (curvedWeekView.ribbonThickness / 2) - 15)
                    color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.32)
                    border.width: 1.5
                    border.color: root.seal
                    z: 1
                }

                // Global Wheel Handler over the curved week view
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            curvedWeekView.scrollBy(1);
                        } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            curvedWeekView.scrollBy(-1);
                        }
                    }
                }

                // Dynamic sliding day items along the custom curve (-6 to +6)
                Repeater {
                    model: [-6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6]
                    delegate: Item {
                        id: dayDelegate
                        required property int modelData
                        required property int index

                        readonly property var itemData: calSection.getWeekDayItem(modelData)
                        readonly property real u: modelData - curvedWeekView.scrollOffset
                        readonly property real t: (u + 3.5) / 7.0
                        readonly property real posX: curvedWeekView.sidePad + (t * curvedWeekView.trackWidth)
                        readonly property real clampedT: Math.max(0.0, Math.min(1.0, t))
                        readonly property real curveH: curvedWeekView.archOffsetY(clampedT)
                        readonly property real posY: curvedWeekView.ribbonBaseY - curveH + (curvedWeekView.ribbonThickness / 2)

                        readonly property real dist: Math.abs(u)
                        readonly property bool isCenter: dist < 0.4
                        readonly property real itemOpacity: {
                            if (dist <= 0.4) return 1.0;
                            if (dist >= 3.5) return 0.0;
                            return Math.max(0.0, 1.0 - (dist / 3.5) * 0.75);
                        }

                        visible: itemOpacity > 0.01
                        z: 2

                        x: Math.round(posX - (width / 2))
                        y: 0
                        width: Math.round(curvedWeekView.trackWidth / 7.2)
                        height: curvedWeekView.height

                        // Day Name sitting clearly ABOVE the circular badge & ribbon (NO CLIPPING)
                        UiText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(posY - (isCenter ? 34 : 32))
                            text: itemData.dayName
                            font.family: root.barFont
                            font.pixelSize: 10
                            font.weight: isCenter ? Font.Bold : Font.Normal
                            color: isCenter ? root.ink : root.sumi
                            opacity: dayDelegate.itemOpacity
                        }

                        // Day Number sitting INSIDE the ribbon / summit badge along the curve
                        UiText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(posY - (height / 2))
                            text: itemData.day
                            font.family: root.barFont
                            font.pixelSize: isCenter ? 13 : 11
                            font.weight: isCenter ? Font.Bold : Font.Medium
                            color: root.ink
                            opacity: dayDelegate.itemOpacity
                        }

                        // Marker dot for days with active notes / reminders
                        Rectangle {
                            visible: itemData.hasNotes && dayDelegate.itemOpacity > 0.1
                            width: 4
                            height: 4
                            radius: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: Math.round(posY + (isCenter ? 17 : 14))
                            color: root.seal
                            opacity: dayDelegate.itemOpacity
                        }

                        // Click to slide date to center & scroll to step dates
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var targetDelta = Math.round(u);
                                if (targetDelta !== 0) {
                                    curvedWeekView.scrollBy(targetDelta);
                                }
                            }
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
                                    curvedWeekView.scrollBy(1);
                                } else if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
                                    curvedWeekView.scrollBy(-1);
                                }
                            }
                        }
                    }
                }
            }

            // 4A. BOTTOM NAVIGATION STRIP - ONLY IN WEEKLY VIEW
            Item {
                id: leftBottomBar
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 26
                visible: calSection.viewMode === "weekly"

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    // Prev Day Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: prevDayMa.containsMouse ? root.fillHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        IconText {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            font.pixelSize: 16
                            color: root.ink
                            opacity: 0.7
                        }
                        MouseArea {
                            id: prevDayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: curvedWeekView.scrollBy(-1)
                        }
                    }

                    // Selected Date Pill
                    Rectangle {
                        height: 24
                        width: dateSummaryTxt.implicitWidth + 16
                        radius: 12
                        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.06)
                        anchors.verticalCenter: parent.verticalCenter

                        UiText {
                            id: dateSummaryTxt
                            anchors.centerIn: parent
                            text: calSection.selectedDayLabel
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: root.ink
                        }
                    }

                    // Next Day Button
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: nextDayMa.containsMouse ? root.fillHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        IconText {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            font.pixelSize: 16
                            color: root.ink
                            opacity: 0.7
                        }
                        MouseArea {
                            id: nextDayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: curvedWeekView.scrollBy(1)
                        }
                    }
                }
            }

            // ═════════════════════════════════════════════════════════════════
            // ── MONTHLY VIEW CONTENT (Clean Month Header & Full Height Grid) ─
            // ═════════════════════════════════════════════════════════════════

            // 2B. MONTH SWITCHER HEADER ROW - ONLY IN MONTHLY VIEW
            Item {
                id: monthlyHeaderRow
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: 28
                visible: calSection.viewMode === "monthly"

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    // Prev Month
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: prevMonMa.containsMouse ? root.fillHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        IconText {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            font.pixelSize: 16
                            color: root.ink
                            opacity: 0.8
                        }
                        MouseArea {
                            id: prevMonMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calSection.stepMonth(-1)
                        }
                    }

                    // Month & Year Label: e.g. "October 2026"
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: calSection.months[calSection.selMonth] + " " + calSection.selYear
                        font.family: root.barFont
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: root.ink
                    }

                    // Next Month
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: nextMonMa.containsMouse ? root.fillHover : "transparent"
                        anchors.verticalCenter: parent.verticalCenter
                        IconText {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            font.pixelSize: 16
                            color: root.ink
                            opacity: 0.8
                        }
                        MouseArea {
                            id: nextMonMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: calSection.stepMonth(1)
                        }
                    }
                }
            }

            // 3B. MONTHLY GRID - EXPANDED TO FULL AVAILABLE HEIGHT
            Item {
                id: monthlyGridView
                anchors.top: monthlyHeaderRow.bottom
                anchors.topMargin: 4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                height: parent.height - monthlyHeaderRow.y - monthlyHeaderRow.height - 16
                visible: calSection.viewMode === "monthly"
                clip: true

                // Wheel scroll over month grid to step months
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y < 0 || event.angleDelta.x > 0) {
                            calSection.stepMonth(1);
                        } else if (event.angleDelta.y > 0 || event.angleDelta.x < 0) {
                            calSection.stepMonth(-1);
                        }
                    }
                }

                Column {
                    anchors.fill: parent
                    spacing: 2

                    // Weekday letter headers
                    Row {
                        width: parent.width
                        height: 14
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            delegate: Item {
                                width: parent.width / 7
                                height: 14
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: root.sumi
                                    opacity: 0.7
                                }
                            }
                        }
                    }

                    // 42-day complete month grid (6 rows of 7 days)
                    Grid {
                        width: parent.width
                        height: parent.height - 16
                        columns: 7
                        rowSpacing: 1
                        columnSpacing: 1

                        Repeater {
                            model: calSection.monthGridData
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelectedCell: (modelData.year === calSection.selYear && modelData.month === calSection.selMonth && modelData.day === calSection.selDay)

                                width: Math.floor((monthlyGridView.width - 6) / 7)
                                height: Math.floor((parent.height - 5) / 6)
                                radius: 4
                                color: isSelectedCell 
                                    ? root.seal
                                    : (mCellMa.containsMouse ? root.fillHover : "transparent")

                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    font.weight: (modelData.isToday || isSelectedCell) ? Font.Bold : Font.Normal
                                    color: isSelectedCell
                                        ? root.paper
                                        : (modelData.isCurrentMonth ? root.ink : root.sumi)
                                    opacity: isSelectedCell ? 1.0 : (modelData.isCurrentMonth ? 1.0 : 0.35)
                                }

                                // Dot for days with notes
                                Rectangle {
                                    visible: modelData.hasNotes
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 1
                                    color: isSelectedCell ? root.paper : root.seal
                                }

                                MouseArea {
                                    id: mCellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        calSection.selYear = modelData.year;
                                        calSection.selMonth = modelData.month;
                                        calSection.selDay = modelData.day;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: DATE NOTE & EVENT DETAILS ──────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        Rectangle {
            id: rightColContainer
            width: columnsRow.width - leftColContainer.width - columnsRow.spacing
            height: columnsRow.height
            radius: 20
            color: root.fillIdle
            border.width: 0
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // 1. Right Header: Selected Date Title + Today/Count Badges
                Item {
                    width: parent.width
                    height: 24

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "event_note"
                            font.pixelSize: 15
                            color: root.seal
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: calSection.selectedDayFullLabel
                            font.family: root.barFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.ink
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        // "TODAY" badge
                        Rectangle {
                            height: 18
                            width: todayBadgeTxt.implicitWidth + 10
                            radius: 9
                            color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.22)
                            border.width: 1
                            border.color: root.seal
                            visible: calSection.isSelectedToday

                            UiText {
                                id: todayBadgeTxt
                                anchors.centerIn: parent
                                text: "TODAY"
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Bold
                                color: root.seal
                            }
                        }

                        // Notes count badge
                        Rectangle {
                            height: 18
                            width: noteCountBadgeTxt.implicitWidth + 10
                            radius: 9
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                            UiText {
                                id: noteCountBadgeTxt
                                anchors.centerIn: parent
                                text: calSection.currentDayNotes.length + (calSection.currentDayNotes.length === 1 ? " note" : " notes")
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: root.sumi
                            }
                        }
                    }
                }

                // 2. Add Note Input Box
                Rectangle {
                    id: addNoteBox
                    width: parent.width
                    height: 28
                    radius: 14
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)
                    border.width: noteTextInput.activeFocus ? 1 : 0
                    border.color: root.seal

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 4
                        spacing: 6

                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "add"
                            font.pixelSize: 15
                            color: noteTextInput.activeFocus ? root.seal : root.sumi
                            opacity: 0.8
                        }

                        Item {
                            width: parent.width - 20 - 24
                            height: parent.height

                            TextInput {
                                id: noteTextInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                clip: true
                                selectByMouse: true

                                onAccepted: {
                                    if (noteTextInput.text.trim() !== "") {
                                        calSection.addNote(calSection.selectedKey, noteTextInput.text);
                                        noteTextInput.text = "";
                                    }
                                }

                                Keys.onEscapePressed: {
                                    noteTextInput.text = "";
                                    noteTextInput.focus = false;
                                }
                            }

                            UiText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Add note or reminder..."
                                font.family: root.barFont
                                font.pixelSize: 11
                                color: root.sumi
                                opacity: 0.55
                                visible: noteTextInput.text === "" && !noteTextInput.activeFocus
                            }
                        }

                        // Submit Button
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            color: noteTextInput.text.trim() !== "" ? root.seal : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            IconText {
                                anchors.centerIn: parent
                                text: "arrow_forward"
                                font.pixelSize: 13
                                color: noteTextInput.text.trim() !== "" ? root.paper : root.sumi
                                opacity: noteTextInput.text.trim() !== "" ? 1.0 : 0.4
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: noteTextInput.text.trim() !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (noteTextInput.text.trim() !== "") {
                                        calSection.addNote(calSection.selectedKey, noteTextInput.text);
                                        noteTextInput.text = "";
                                    }
                                }
                            }
                        }
                    }
                }

                // 3. Scrollable List of Notes / Events for Selected Date
                Item {
                    width: parent.width
                    height: parent.height - 24 - 8 - 28 - 8
                    clip: true

                    ListView {
                        id: notesListView
                        anchors.fill: parent
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: calSection.currentDayNotes

                        delegate: Rectangle {
                            id: noteDelegateItem
                            width: notesListView.width
                            height: 28
                            radius: 8
                            color: noteItemMa.containsMouse ? root.fillHover : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.04)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            MouseArea {
                                id: noteItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                // Custom Checkbox (Toggle Done)
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    border.width: 1
                                    border.color: modelData.done ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.25)
                                    color: modelData.done ? root.seal : "transparent"

                                    UiText {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        font.family: root.barFont
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: root.paper
                                        visible: modelData.done
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calSection.toggleNote(calSection.selectedKey, modelData.id)
                                    }
                                }

                                // Note Text (Strikethrough when done)
                                UiText {
                                    text: modelData.text
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    font.strikeout: modelData.done
                                    color: modelData.done ? root.sumi : root.ink
                                    opacity: modelData.done ? 0.50 : 1.0
                                    elide: Text.ElideRight
                                    width: parent.width - 56
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Delete Button
                                IconText {
                                    text: "close"
                                    color: root.sumi
                                    font.pixelSize: 13
                                    opacity: delNoteMa.containsMouse ? 1.0 : 0.6
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: noteItemMa.containsMouse

                                    MouseArea {
                                        id: delNoteMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calSection.deleteNote(calSection.selectedKey, modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    // Empty State when no notes for selected date
                    Item {
                        anchors.fill: parent
                        visible: calSection.currentDayNotes.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            IconText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "event_available"
                                font.pixelSize: 24
                                color: root.sumi
                                opacity: 0.35
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "No notes for " + calSection.monthsShort[calSection.selMonth] + " " + calSection.selDay
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: root.sumi
                                opacity: 0.65
                            }

                            UiText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Type above and press Enter to save"
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.sumi
                                opacity: 0.40
                            }
                        }
                    }
                }
            }
        }
    }
}

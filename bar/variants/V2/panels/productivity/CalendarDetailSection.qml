import QtQuick
import ".."
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../../modules"
import "../../motion"

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

    readonly property bool isInputFocused: rightColContainer.isInputFocused

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
            border.width: root.isLightMode ? 1 : 0
            border.color: root.cardBorderColor
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

                // Tab switcher [ Weekly | Monthly ]
                PillTabs {
                    id: tabPill
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root
                    model: [ { id: "weekly", label: "Weekly" }, { id: "monthly", label: "Monthly" } ]
                    current: calSection.viewMode
                    onActivated: (id) => calSection.viewMode = id
                }

                // Month Switcher (centered in available space between tab switcher and action buttons)
                Item {
                    id: monthSwitcherContainer
                    anchors.left: tabPill.right
                    anchors.right: rightActionButtons.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    visible: calSection.viewMode === "monthly"

                    Row {
                        id: monthSwitcherRow
                        anchors.centerIn: parent
                        spacing: 6

                        // Prev Month
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: prevMonMa.containsMouse ? root.fillHover : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.pixelSize: 15
                                color: root.ink
                                opacity: 0.8
                            }
                            SpringPress {}
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
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.ink
                        }

                        // Next Month
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: nextMonMa.containsMouse ? root.fillHover : "transparent"
                            anchors.verticalCenter: parent.verticalCenter
                            IconText {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                font.pixelSize: 15
                                color: root.ink
                                opacity: 0.8
                            }
                            SpringPress {}
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

                // Top Right Action Buttons: Jump to Today + Close
                Row {
                    id: rightActionButtons
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

                        SpringPress {}
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

                        SpringPress {}
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
                        SpringPress {}
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
                        SpringPress {}
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
            // ── MONTHLY VIEW CONTENT (Expanded Full Height Grid) ──────────────
            // ═════════════════════════════════════════════════════════════════

            // 2B. MONTHLY GRID - EXPANDED TO FULL AVAILABLE HEIGHT (Header is in top bar)
            CalendarDetailMonthlyGrid {
                id: monthlyGridView
                root: calSection.root
                calSection: calSection
                anchors.top: leftTopBar.bottom
                anchors.topMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
            }
        }

        // ═════════════════════════════════════════════════════════════════════
        // ── RIGHT COLUMN: DATE NOTE & EVENT DETAILS ──────────────────────────
        // ═════════════════════════════════════════════════════════════════════
        CalendarDetailNotesColumn {
            id: rightColContainer
            root: calSection.root
            calSection: calSection
            width: columnsRow.width - leftColContainer.width - columnsRow.spacing
            height: columnsRow.height
        }
    }
}

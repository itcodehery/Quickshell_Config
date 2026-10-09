import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import "../modules"

PanelWindow {
    id: stPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-screentime"

    property real reveal: root.screentimeVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.screentimeVisible ? 160 : 120
            easing.type: root.screentimeVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.screentimeVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.screentimeVisible = false
    }

    // --- State and Data Logic ---
    property var stData: ({})
    property var pieColors: [root.color01, root.color02, root.color03, root.color04, root.color05, root.color06, root.color07]

    FileView {
        id: stFile
        path: Quickshell.env("HOME") + "/.cache/screentime.json"
        watchChanges: true
        onLoaded: {
            try {
                let txt = stFile.text().trim();
                if (txt.length > 0) {
                    stPanel.stData = JSON.parse(txt);
                    if (typeof pieChart !== "undefined") pieChart.requestPaint();
                }
            } catch(e) {}
        }
    }

    property date now: new Date()
    property date selectedDateObj: new Date()
    
    Connections {
        target: root
        function onScreentimeVisibleChanged() {
            if (root.screentimeVisible) {
                stPanel.now = new Date();
                stPanel.selectedDateObj = new Date();
                if (typeof pieChart !== "undefined") pieChart.requestPaint();
            }
        }
    }

    function pad(n) { return n < 10 ? "0" + n : String(n); }
    function dateKey(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
    
    readonly property string selectedDateKey: dateKey(selectedDateObj)
    readonly property string todayDateKey: dateKey(now)
    readonly property bool isToday: selectedDateKey === todayDateKey

    readonly property var monthsShort: ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
    readonly property var daysShort: ["SUN","MON","TUE","WED","THU","FRI","SAT"]

    readonly property string selectedDayLabel: {
        return daysShort[selectedDateObj.getDay()] + ", " + pad(selectedDateObj.getDate()) + " " + monthsShort[selectedDateObj.getMonth()] + " " + selectedDateObj.getFullYear();
    }

    function formatTime(secs) {
        if (!secs || secs === 0) return "0s";
        let h = Math.floor(secs / 3600);
        let m = Math.floor((secs % 3600) / 60);
        let s = secs % 60;
        if (h > 0) return h + "h " + m + "m";
        if (m > 0) return m + "m";
        return s + "s";
    }

    readonly property var selectedApps: {
        if (stData[selectedDateKey] && stData[selectedDateKey].apps) {
            let arr = [];
            for (let app in stData[selectedDateKey].apps) {
                arr.push({ name: app, time: stData[selectedDateKey].apps[app] });
            }
            arr.sort((a, b) => b.time - a.time);
            return arr;
        }
        return [];
    }
    
    readonly property real currentTotal: stData[selectedDateKey] ? (stData[selectedDateKey].total || 0) : 0
    
    readonly property string trendStr: {
        var prevDate = new Date(selectedDateObj);
        prevDate.setDate(prevDate.getDate() - 1);
        var prevTotal = stData[dateKey(prevDate)] ? (stData[dateKey(prevDate)].total || 0) : 0;
        
        if (prevTotal === 0 && currentTotal === 0) return "-";
        if (prevTotal === 0) return "↑ 100%";
        
        var diff = currentTotal - prevTotal;
        var pct = Math.abs(Math.round((diff / prevTotal) * 100));
        return diff >= 0 ? ("↑ " + pct + "%") : ("↓ " + pct + "%");
    }

    readonly property var rollingWeek: {
        var hist = [];
        var mt = 0;
        for (var i = 6; i >= 0; i--) {
            var d = new Date(selectedDateObj);
            d.setDate(d.getDate() - i);
            var dk = dateKey(d);
            var t = stData[dk] ? (stData[dk].total || 0) : 0;
            if (t > mt) mt = t;
            hist.push({ dateKey: dk, label: daysShort[d.getDay()], total: t, dateObj: d });
        }
        return { hist: hist, maxTotal: mt };
    }

    // --- UI Structure ---
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
            root: stPanel.root
            ownerActive: stPanel.root.screentimeVisible
            targetX: parent.width / 2
            reveal: stPanel.reveal
        }

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom"
            ? (parent.height - root.v2BarHeight - 6 - height) + 2 * (1 - stPanel.reveal)
            : (root.v2BarHeight + 6) - 2 * (1 - stPanel.reveal)
        opacity: stPanel.reveal
        focus: root.screentimeVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.screentimeVisible = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                var dL = new Date(selectedDateObj);
                dL.setDate(dL.getDate() - 1);
                stPanel.selectedDateObj = dL;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                var dR = new Date(selectedDateObj);
                dR.setDate(dR.getDate() + 1);
                stPanel.selectedDateObj = dR;
                event.accepted = true;
            } else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) {
                stPanel.selectedDateObj = stPanel.now;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── TOP BRUTALIST HEADER: Navigation ───────────────
            Item {
                width: parent.width
                height: 24

                Rectangle {
                    id: prevBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 22; radius: 8; border.width: 0
                    color: prevMa.containsMouse ? root.fillHover : root.fillIdle
                    UiText { anchors.centerIn: parent; text: "‹"; color: root.ink; font.family: root.barFont; font.pixelSize: 14; font.weight: Font.Bold }
                    MouseArea {
                        id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { var d = new Date(selectedDateObj); d.setDate(d.getDate() - 1); stPanel.selectedDateObj = d; }
                    }
                }

                UiText {
                    anchors.centerIn: parent
                    text: stPanel.selectedDayLabel.toUpperCase()
                    color: root.ink
                    font.family: root.barFont
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Bold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        height: 22
                        width: todayBadgeTxt.implicitWidth + 8
                        radius: 8; border.width: 0
                        border.color: root.seal
                        color: todayBadgeMa.containsMouse ? root.fillActive : root.fillIdle
                        visible: !stPanel.isToday
                        UiText { id: todayBadgeTxt; anchors.centerIn: parent; text: "TODAY"; font.family: root.barFont; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1; color: root.seal }
                        MouseArea {
                            id: todayBadgeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: stPanel.selectedDateObj = stPanel.now
                        }
                    }

                    Rectangle {
                        id: nextBtn
                        width: 26; height: 22; radius: 8; border.width: 0
                        color: nextMa.containsMouse ? root.fillHover : root.fillIdle
                        UiText { anchors.centerIn: parent; text: "›"; color: root.ink; font.family: root.barFont; font.pixelSize: 14; font.weight: Font.Bold }
                        MouseArea {
                            id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { var d = new Date(selectedDateObj); d.setDate(d.getDate() + 1); stPanel.selectedDateObj = d; }
                        }
                    }
                }
            }

            // ── LIVE STATS HEADER ───────────────
            Item {
                width: parent.width
                height: 20

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        height: 20
                        width: timeTxt.implicitWidth + 12
                        radius: 8; color: root.fillIdle; border.width: 0
                        UiText {
                            id: timeTxt; anchors.centerIn: parent
                            text: "TOTAL " + stPanel.formatTime(stPanel.currentTotal)
                            color: root.ink; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8
                        }
                    }
                    
                    Rectangle {
                        height: 20
                        width: Math.min(120, topAppTxt.implicitWidth + 12)
                        radius: 8; color: root.fillIdle; border.width: 0
                        clip: true
                        UiText {
                            id: topAppTxt; anchors.centerIn: parent
                            text: stPanel.selectedApps.length > 0 ? "TOP " + stPanel.selectedApps[0].name.toUpperCase() : "NO APPS"
                            color: root.ink; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8
                        }
                    }
                }
                
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20
                    width: trendTxt.implicitWidth + 12
                    radius: 8; color: root.fillActive; border.color: root.seal; border.width: 0
                    UiText {
                        id: trendTxt; anchors.centerIn: parent
                        text: stPanel.trendStr
                        color: root.seal; font.family: root.barFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8
                    }
                }
            }
            
            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── 7-DAY ROLLING BAR CHART ───────────────
            Item {
                width: parent.width
                height: 110
                
                Rectangle { width: parent.width; height: 1; y: 90; color: root.sep }
                
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: (parent.width - (7 * 32)) / 6
                    
                    Repeater {
                        model: stPanel.rollingWeek.hist
                        delegate: Item {
                            width: 32
                            height: 110
                            
                            readonly property real barMaxH: 86
                            property real h: stPanel.rollingWeek.maxTotal > 0 ? (modelData.total / stPanel.rollingWeek.maxTotal) * barMaxH : 0
                            
                            Rectangle {
                                anchors.bottom: parent.top
                                anchors.bottomMargin: -90
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 24
                                height: Math.max(4, h)
                                radius: 6
                                color: modelData.dateKey === stPanel.selectedDateKey ? root.seal : (barMa.containsMouse ? root.fillHover : root.fillIdle)
                                border.width: modelData.dateKey === stPanel.selectedDateKey ? 0 : 1
                                border.color: root.sep
                                
                                TooltipMixin {
                                    id: dayTip
                                    root: stPanel.root
                                    owner: parent
                                    text: modelData.dateKey + " - " + stPanel.formatTime(modelData.total)
                                }
                            }
                            
                            UiText {
                                text: modelData.label
                                y: 96
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: modelData.dateKey === stPanel.selectedDateKey ? root.seal : root.sumi
                                font.family: root.barFont
                                font.pixelSize: 9
                                font.weight: modelData.dateKey === stPanel.selectedDateKey ? Font.Bold : Font.Normal
                                font.letterSpacing: 1
                            }
                            
                            MouseArea {
                                id: barMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: dayTip.show()
                                onExited: dayTip.hide()
                                onClicked: stPanel.selectedDateObj = modelData.dateObj
                            }
                        }
                    }
                }
            }

            // ── PIE CHART & APPS LIST ───────────────
            Rectangle {
                width: parent.width
                height: Math.max(144, Math.min(260, appCol.implicitHeight + 24))
                radius: 8
                color: root.fillIdle
                border.width: 1
                border.color: root.sep
                clip: true
                
                Column {
                    id: appCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    
                    Row {
                        width: parent.width
                        height: stPanel.selectedApps.length > 0 ? 120 : 0
                        visible: stPanel.selectedApps.length > 0
                        spacing: 12
                        
                        Canvas {
                            id: pieChart
                            width: 120
                            height: 120
                            renderTarget: Canvas.FramebufferObject
                            
                            property var model: stPanel.selectedApps
                            property real totalTime: stPanel.currentTotal
                            property color holeColor: root.fillIdle
                            
                            onModelChanged: requestPaint()
                            Connections {
                                target: stPanel
                                function onSelectedDateKeyChanged() { pieChart.requestPaint() }
                            }
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                if (totalTime <= 0 || model.length === 0) return;
                                
                                var cx = width / 2;
                                var cy = height / 2;
                                var r = 55;
                                var startAngle = -Math.PI / 2;
                                
                                for (var i = 0; i < model.length; i++) {
                                    var sliceAngle = (model[i].time / totalTime) * 2 * Math.PI;
                                    ctx.beginPath();
                                    ctx.moveTo(cx, cy);
                                    ctx.arc(cx, cy, r, startAngle, startAngle + sliceAngle);
                                    ctx.closePath();
                                    
                                    ctx.fillStyle = stPanel.pieColors[i % stPanel.pieColors.length];
                                    ctx.fill();
                                    
                                    startAngle += sliceAngle;
                                }
                                
                                ctx.beginPath();
                                ctx.arc(cx, cy, 35, 0, 2 * Math.PI);
                                ctx.fillStyle = holeColor;
                                ctx.fill();
                            }
                            
                            UiText {
                                anchors.centerIn: parent
                                text: stPanel.formatTime(stPanel.currentTotal)
                                color: root.ink
                                font.family: root.barFont
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }
                        }
                        
                        ListView {
                            width: parent.width - 132
                            height: 120
                            clip: true
                            spacing: 6
                            model: stPanel.selectedApps
                            delegate: Item {
                                width: ListView.view.width
                                height: 24
                                
                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: stPanel.pieColors[index % stPanel.pieColors.length]
                                }
                                
                                UiText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: root.ink
                                    font.family: root.barFont
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    width: parent.width - 66
                                }
                                
                                UiText {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: stPanel.formatTime(modelData.time)
                                    color: root.sumiHi
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                    
                    Item {
                        width: parent.width
                        height: stPanel.selectedApps.length === 0 ? 120 : 0
                        visible: stPanel.selectedApps.length === 0
                        
                        UiText {
                            anchors.centerIn: parent
                            text: "NO SCREENTIME DATA"
                            color: root.sumiHi
                            font.family: root.barFont
                            font.pixelSize: 11
                            font.letterSpacing: 1
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }
}

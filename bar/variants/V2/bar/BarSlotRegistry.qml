import QtQuick
import ".."
import "../modules"

Item {
    id: registryRoot
    required property var barSlot
    required property var island
    visible: false

    // ─────────────────────────── group registry ───────────────────────────
    Component {
        id: compLauncher
        LauncherWidget {
            root: registryRoot.barSlot.root
            readonly property real barContentLeftInset: logoPadding / 2
            readonly property real barContentRightInset: logoPadding / 2
        }
    }
    Component {
        id: compWorkspace
        WorkspaceWidget {
            root: registryRoot.barSlot.root
            readonly property real barContentLeftInset: 0
            readonly property real barContentRightInset: 0
        }
    }
    Component {
        id: compStatus                                   // G3: arch · tray · notif
        Item {
            id: statusGroup
            readonly property real barContentLeftInset: registryRoot.barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: registryRoot.barSlot.root.v2IconGroupPadding
            readonly property real archCaretX: statusRow.x + archWidget.x + archWidget.width / 2
            readonly property real trayCaretX: statusRow.x + statusTrayRow.x + trayWidget.x + trayWidget.width / 2
            visible: implicitWidth > 0.5
            implicitWidth: registryRoot.barSlot.root.modStatus
                ? Math.round(statusRow.implicitWidth) + 2 * registryRoot.barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: registryRoot.barSlot.root.modStatus ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: registryRoot.barSlot.root.v2InlineSpacing
                ArchUpdaterWidget  { id: archWidget; root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    id: statusTrayRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: registryRoot.barSlot.root.v2IconClusterSpacing
                    TrayWidget         { id: trayWidget; root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Component {
        id: compNotification                                   // G22: notif
        Item {
            id: notifGroup
            readonly property real barContentLeftInset: registryRoot.barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: registryRoot.barSlot.root.v2IconGroupPadding
            readonly property real notifCaretX: notifRow.x + notifWidget.x + notifWidget.width / 2
            visible: implicitWidth > 0.5
            implicitWidth: registryRoot.barSlot.root.modNotif
                ? Math.round(notifRow.implicitWidth) + 2 * registryRoot.barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: registryRoot.barSlot.root.modNotif ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Row {
                id: notifRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: registryRoot.barSlot.root.v2InlineSpacing
                NotificationWidget { id: notifWidget; root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Component {
        id: compShellFallbackUpdater
        Item {
            width: 26
            height: 24
            ArchUpdaterWidget {
                root: registryRoot.barSlot.root
                colorGid: "G8"
                preferShell: true
                anchors.centerIn: parent
            }
        }
    }

    Component {
        id: compCenter                                   // G8: weather·clock·date·indicators
        Item {
            id: g8
            width: implicitWidth
            height: implicitHeight
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
            readonly property color contentColor:
                registryRoot.barSlot.root.widgetContentColor("G8", registryRoot.barSlot.root.ink)
            readonly property real weatherCaretX:
                centerRow.x + weatherSlot.x + weatherSlot.width / 2
            readonly property real calendarCaretX:
                centerRow.x + dateSlot.x + dateSlot.width / 2
            implicitWidth: Math.round(centerRow.implicitWidth) + 18
            implicitHeight: 24

            // ── responsive stage (narrow-monitor overlap fix) ──
            // Presentation-only inside G8 — never touches root.mod* user toggles.
            // Mutable state with hysteresis, NOT a computed property: downshift when
            // the CURRENT stage no longer fits (24px slack), upshift only when the
            // LARGER stage would fit with 48px slack — measured against that stage's
            // own needed width, else minimal⇄compact oscillates.
            property int stage: 0                        // 0 normal · 1 compact · 2 minimal
            readonly property bool showWeather: stage <= 1
            readonly property bool showDate:    stage === 0
            readonly property bool showIcons:   iconsRow.hasActive
            // needed widths per stage: reactive bindings over the UNCOLLAPSED content
            // (the stage-gated wrapper widths shrink and would mislead the upshift
            // decision). 18 = pill padding, 8 = row spacing per visible neighbour.
            readonly property real needMinimal: 18 + clock.implicitWidth
                + (showIcons && iconsRow.implicitWidth > 0.5 ? 8 + iconsRow.implicitWidth : 0)
            readonly property real needCompact: needMinimal
                + (weather.implicitWidth > 0.5 ? 8 + weather.implicitWidth : 0)
            readonly property real needNormal: needCompact
                + (dateLabel.implicitWidth > 0.5 ? 8 + dateLabel.implicitWidth : 0)
            function updateStage() {
                // compact only while G8 actually occupies the center slot: after a
                // drag swap G8 can sit in a SIDE row — its own width then feeds the
                // very side-row width that centerAvail is measured from, and the
                // stage delta (~weather+date) exceeds the 24/48px hysteresis window
                // → boundary-width flutter. As a side widget G8 stays at normal.
                if (!registryRoot.barSlot.modelContains(registryRoot.barSlot.centerModel, "G8")) {
                    if (stage !== 0) stage = 0
                    return
                }
                if (!registryRoot.island) return
                var avail = registryRoot.island.g8AvailableWidth
                var s = stage
                if (s === 0 && needNormal  + 24 > avail) s = 1
                if (s === 1 && needCompact + 24 > avail) s = 2
                if (s === 2 && needCompact + 48 <= avail) s = 1
                if (s === 1 && needNormal  + 48 <= avail) s = 0
                if (s !== stage) stage = s
            }
            // publish the clock + status-icon floor width for the side-row budget
            Binding { target: registryRoot.island; property: "g8FloorWidth"; value: g8.needMinimal }
            // 80ms one-shot coalesces width flutter (track changes, tray churn)
            Timer { id: restageTimer; interval: 80; repeat: false; onTriggered: g8.updateStage() }
            onNeedNormalChanged:  restageTimer.restart()
            onNeedCompactChanged: restageTimer.restart()
            Connections { target: registryRoot.island; function onG8AvailableWidthChanged() { restageTimer.restart() } }
            Component.onCompleted: restageTimer.restart()

            Row {
                id: centerRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)   // integer center → sharp text
                height: 24
                spacing: registryRoot.barSlot.root.v2SectionSpacing
                Item {                                   // weather wrapper (stage-gated)
                    id: weatherSlot
                    visible: width > 0.5
                    width: g8.showWeather ? weather.implicitWidth : 0
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    opacity: g8.showWeather ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    WeatherWidget {
                        id: weather
                        anchors.fill: parent
                        root: registryRoot.barSlot.root
                    }
                }
                ClockWidget {
                    id: clock
                    root: registryRoot.barSlot.root
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item {                                   // date (stage-gated)
                    id: dateSlot
                    visible: width > 0.5
                    width: g8.showDate ? dateLabel.implicitWidth : 0
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    opacity: g8.showDate ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    UiText {
                        id: dateLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            clock.now;
                            var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                            var d = new Date();
                            return days[d.getDay()] + " " + d.getDate();
                        }
                        color: Qt.rgba(g8.contentColor.r, g8.contentColor.g, g8.contentColor.b, 0.5)
                        font.family: registryRoot.barSlot.root.barFont
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            registryRoot.barSlot.root.activatePopupScreen(registryRoot.barSlot.screen)
                            if (registryRoot.barSlot.root.dashboardExpanded && registryRoot.barSlot.root.dashboardDetail === "calendar") {
                                registryRoot.barSlot.root.dashboardExpanded = false
                                registryRoot.barSlot.root.dashboardDetail = ""
                            } else {
                                registryRoot.barSlot.root.calendarVisible = false
                                registryRoot.barSlot.root.dashboardDetail = "calendar"
                                registryRoot.barSlot.root.dashboardExpanded = true
                            }
                        }
                    }
                }
                Item {                                   // indicator icons wrapper (stage-gated)
                    visible: g8.showIcons || width > 0.5
                    width: g8.showIcons ? iconsRow.implicitWidth : 0
                    height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    opacity: g8.showIcons ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Row {
                        id: iconsRow
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        spacing: registryRoot.barSlot.root.v2InlineSpacing
                        readonly property bool shellFallbackActive: !registryRoot.barSlot.root.modStatus
                            && (registryRoot.barSlot.root.shellUpdateBehind > 0 || registryRoot.barSlot.root.shellUpdateProgressVisible)
                        readonly property bool hasActive: idleInd.awake
                            || dndInd.silenced
                            || screenRecInd.recording
                            || voxInd.state === "recording"
                            || voxInd.state === "transcribing"
                            || omarchyUpdateInd.updateAvailable
                            || shellFallbackActive
                        IdleWidget               { id: idleInd;          root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        NotificationSilenceWidget{ id: dndInd;           root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        ScreenRecordWidget       { id: screenRecInd;     root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        VoxtypeWidget            { id: voxInd;           root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        UpdateWidget             { id: omarchyUpdateInd; root: registryRoot.barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        Loader {
                            visible: iconsRow.shellFallbackActive || width > 0.5
                            active: iconsRow.shellFallbackActive
                            width: iconsRow.shellFallbackActive ? 26 : 0
                            height: 24
                            anchors.verticalCenter: parent.verticalCenter
                            sourceComponent: compShellFallbackUpdater
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: compMpris
        MprisWidget {
            root: registryRoot.barSlot.root
            readonly property real barContentLeftInset: active ? 9 : 8
            readonly property real barContentRightInset: active ? 9 : 8
        }
    }
    Component {
        id: compGithubHeatmap
        GithubHeatmapWidget {
            root: registryRoot.barSlot.root
        }
    }
    Component {
        id: compBattery
        BatteryWidget {
            root: registryRoot.barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compNotes
        NotesWidget {
            root: registryRoot.barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }

    Component {
        id: compScreentime
        ScreentimeWidget {
            root: registryRoot.barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }

    readonly property var map: ({
        "G1": compLauncher, "G2": compWorkspace, "G3": compStatus,
        "G8": compCenter,
        "G9": compMpris,
        "G12": compBattery,
        "G19": compGithubHeatmap, "G20": compNotes, "G21": compScreentime, "G22": compNotification
    })
}

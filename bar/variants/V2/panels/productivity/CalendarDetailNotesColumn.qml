import QtQuick
import ".."
import "../../modules"
import "../../motion"

// ═════════════════════════════════════════════════════════════════════
// ── RIGHT COLUMN: DATE NOTE & EVENT DETAILS ──────────────────────────
// ═════════════════════════════════════════════════════════════════════
Rectangle {
    id: rightColContainer

    required property var root
    required property var calSection

    readonly property bool isInputFocused: noteTextInput.activeFocus

    radius: 20
    color: root.fillIdle
    border.width: root.isLightMode ? 1 : 0
    border.color: root.cardBorderColor
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

                // Events & Notes count badge
                Rectangle {
                    height: 18
                    width: noteCountBadgeTxt.implicitWidth + 10
                    radius: 9
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08)

                    UiText {
                        id: noteCountBadgeTxt
                        anchors.centerIn: parent
                        text: {
                            var gCount = calSection.currentDayGoogleItems.length;
                            var nCount = calSection.currentDayNotes.length;
                            if (gCount === 0 && nCount === 0) return "0 items";
                            var parts = [];
                            if (gCount > 0) parts.push(gCount + (gCount === 1 ? " event" : " events"));
                            if (nCount > 0) parts.push(nCount + (nCount === 1 ? " note" : " notes"));
                            return parts.join(" • ");
                        }
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

                    SpringPress {}
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

        // 3. Scrollable List of Google Events/Tasks/Birthdays + Local Notes
        Item {
            id: agendaContainer
            width: parent.width
            height: parent.height - 24 - 8 - 28 - 8
            clip: true

            readonly property bool showStatusBanner: calSection.googleSyncStatus === "needs_auth"
                || calSection.googleSyncStatus === "needs_credentials"
                || calSection.googleSyncStatus === "error"

            Flickable {
                id: agendaFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: agendaCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: agendaCol
                    width: agendaFlickable.width
                    spacing: 5

                    // Optional Google Calendar Connection / Setup Banner
                    Rectangle {
                        visible: agendaContainer.showStatusBanner
                        width: parent.width
                        height: statusRow.implicitHeight + 10
                        radius: 10
                        color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(root.seal.r, root.seal.g, root.seal.b, 0.30)

                        Row {
                            id: statusRow
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            IconText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: calSection.googleSyncStatus === "error" ? "warning" : "calendar_add_on"
                                font.pixelSize: 14
                                color: root.seal
                            }

                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20 - (connectBtn.visible ? connectBtn.width + 6 : 0)
                                text: {
                                    if (calSection.googleSyncStatus === "needs_credentials")
                                        return "Add google_calendar_credentials.json in ~/.config/quickshell/ to sync Google Calendar.";
                                    if (calSection.googleSyncStatus === "needs_auth")
                                        return "Google credentials found. Connect your account to view events.";
                                    return "Google sync error: " + calSection.googleSyncError;
                                }
                                font.family: root.barFont
                                font.pixelSize: 10
                                color: root.ink
                                wrapMode: Text.Wrap
                            }

                            Rectangle {
                                id: connectBtn
                                visible: calSection.googleSyncStatus === "needs_auth"
                                width: connectBtnTxt.implicitWidth + 12
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: connectBtnMa.containsMouse ? Qt.lighter(root.seal, 1.1) : root.seal

                                UiText {
                                    id: connectBtnTxt
                                    anchors.centerIn: parent
                                    text: calSection.googleSyncing ? "..." : "Connect"
                                    font.family: root.barFont
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: root.paper
                                }

                                MouseArea {
                                    id: connectBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: calSection.connectGoogleCalendar()
                                }
                            }
                        }
                    }

                    // Google Calendar Items (Read-Only, Distinctly Styled by Kind)
                    Repeater {
                        model: calSection.currentDayGoogleItems

                        delegate: Rectangle {
                            id: gItemCard
                            required property var modelData
                            readonly property string itemKind: modelData.kind || "event"
                            readonly property color accentColor: {
                                if (itemKind === "birthday") return "#f06292";
                                if (itemKind === "task") return "#34a853";
                                if (itemKind === "ooo") return "#fbbc04";
                                if (itemKind === "focus") return "#a142f4";
                                if (itemKind === "holiday") return "#24c1e0";
                                return modelData.color || "#4285f4";
                            }
                            readonly property string kindIcon: {
                                if (itemKind === "birthday") return "cake";
                                if (itemKind === "task") return modelData.done ? "task_alt" : "radio_button_unchecked";
                                if (itemKind === "ooo") return "beach_access";
                                if (itemKind === "focus") return "psychology";
                                if (itemKind === "holiday") return "celebration";
                                return "event";
                            }
                            readonly property string kindBadge: {
                                if (itemKind === "birthday") return "Birthday";
                                if (itemKind === "task") return "Task";
                                if (itemKind === "ooo") return "OOO";
                                if (itemKind === "focus") return "Focus";
                                if (itemKind === "holiday") return "Holiday";
                                return "";
                            }

                            width: agendaCol.width
                            height: gItemContent.implicitHeight + 10
                            radius: 9
                            color: gItemMa.containsMouse
                                ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.16)
                                : Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.08)
                            border.width: 1
                            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
                            Behavior on color { ColorAnimation { duration: 100 } }

                            // Left color stripe
                            Rectangle {
                                width: 3
                                height: parent.height - 8
                                radius: 1.5
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: gItemCard.accentColor
                            }

                            Column {
                                id: gItemContent
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Row {
                                    width: parent.width
                                    spacing: 6

                                    IconText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: gItemCard.kindIcon
                                        font.pixelSize: 13
                                        color: gItemCard.accentColor
                                    }

                                    UiText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 19 - (kindPill.visible ? kindPill.width + 6 : 0)
                                        text: gItemCard.modelData.title || ""
                                        font.family: root.barFont
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        font.strikeout: gItemCard.itemKind === "task" && Boolean(gItemCard.modelData.done)
                                        color: root.ink
                                        opacity: (gItemCard.itemKind === "task" && Boolean(gItemCard.modelData.done)) ? 0.5 : 1.0
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        id: kindPill
                                        visible: gItemCard.kindBadge !== ""
                                        height: 15
                                        width: kindPillTxt.implicitWidth + 8
                                        radius: 7.5
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Qt.rgba(gItemCard.accentColor.r, gItemCard.accentColor.g, gItemCard.accentColor.b, 0.20)

                                        UiText {
                                            id: kindPillTxt
                                            anchors.centerIn: parent
                                            text: gItemCard.kindBadge
                                            font.family: root.barFont
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: gItemCard.accentColor
                                        }
                                    }
                                }

                                // Subtitle row: time / all-day + calendar name or location
                                UiText {
                                    width: parent.width
                                    leftPadding: 19
                                    text: {
                                        var d = gItemCard.modelData;
                                        var parts = [];
                                        if (gItemCard.itemKind === "task") {
                                            parts.push(d.calendarName || "Tasks");
                                        } else if (d.allDay) {
                                            parts.push("All day");
                                        } else if (d.startTime) {
                                            parts.push(d.endTime ? (d.startTime + " – " + d.endTime) : d.startTime);
                                        }
                                        if (d.location) parts.push(d.location);
                                        else if (gItemCard.itemKind !== "task" && d.calendarName && gItemCard.itemKind !== "birthday")
                                            parts.push(d.calendarName);
                                        return parts.join("  •  ");
                                    }
                                    font.family: root.barFont
                                    font.pixelSize: 10
                                    color: root.sumi
                                    opacity: 0.78
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: gItemMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: gItemCard.modelData.htmlLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (gItemCard.modelData.htmlLink) {
                                        Qt.openUrlExternally(gItemCard.modelData.htmlLink);
                                    }
                                }
                            }
                        }
                    }

                    // Divider label when both Google items and local notes are present
                    UiText {
                        visible: calSection.currentDayGoogleItems.length > 0 && calSection.currentDayNotes.length > 0
                        text: "LOCAL NOTES"
                        font.family: root.barFont
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        font.letterSpacing: 0.8
                        color: root.sumi
                        opacity: 0.55
                        topPadding: 3
                        leftPadding: 2
                    }

                    // Local Notes (Editable)
                    Repeater {
                        model: calSection.currentDayNotes

                        delegate: Rectangle {
                            id: noteDelegateItem
                            required property var modelData
                            width: agendaCol.width
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

                                    SpringPress {}
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

                                    SpringPress {}
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
                }
            }

            // Empty State when no Google items and no local notes for selected date
            Item {
                anchors.fill: parent
                visible: calSection.currentDayGoogleItems.length === 0 && calSection.currentDayNotes.length === 0 && !agendaContainer.showStatusBanner

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
                        text: "No events or notes for " + calSection.monthsShort[calSection.selMonth] + " " + calSection.selDay
                        font.family: root.barFont
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: root.sumi
                        opacity: 0.65
                    }

                    UiText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Type above and press Enter to save a note"
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
